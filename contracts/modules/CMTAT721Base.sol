// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import {IRuleEngine} from "../../vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol";
import {IERC1643} from "../../vendor/CMTAT/contracts/interfaces/engine/IDocumentEngine.sol";
import {IAllowlistModule} from "../../vendor/CMTAT/contracts/interfaces/modules/IAllowlistModule.sol";
import {ICMTATConstructor} from "../../vendor/CMTAT/contracts/interfaces/technical/ICMTATConstructor.sol";
import {IERC3643ComplianceRead} from "../../vendor/CMTAT/contracts/interfaces/tokenization/IERC3643Partial.sol";
import {IERC7551Compliance} from "../../vendor/CMTAT/contracts/interfaces/tokenization/draft-IERC7551.sol";
import {Errors} from "../../vendor/CMTAT/contracts/libraries/Errors.sol";
import {ICMTAT721Constructor} from "../interfaces/ICMTAT721Constructor.sol";
import {ITokenIdEngine} from "../interfaces/ITokenIdEngine.sol";

import {ValidationModule} from "../../vendor/CMTAT/contracts/modules/wrapper/controllers/ValidationModule.sol";
import {EnforcementModule} from "../../vendor/CMTAT/contracts/modules/wrapper/core/EnforcementModule.sol";
import {PauseModule} from "../../vendor/CMTAT/contracts/modules/wrapper/core/PauseModule.sol";
import {AllowlistModule} from "../../vendor/CMTAT/contracts/modules/wrapper/options/AllowlistModule.sol";
import {CMTATBaseGeneric} from "../../vendor/CMTAT/contracts/modules/0_CMTATBaseGeneric.sol";
import {ValidationModuleRuleEngineInternal} from "../../vendor/CMTAT/contracts/modules/internal/ValidationModuleRuleEngineInternal.sol";

/**
 * @notice Selects who controls mint-time token ID input.
 */
enum TokenIdManagementMode {
    /// @notice Minter provides token IDs to mint functions.
    MINTER_INPUT,
    /// @notice End user provides token IDs through `mintByUser`.
    USER_INPUT
}

/**
 * @title CMTAT721 Base
 * @notice ERC721 adaptation of CMTAT v3.1.0 modules with allowlist, rule engine, and token ID engine support.
 * @dev Supports standalone and proxy deployments through initializer-based setup.
 */
contract CMTAT721Base is
    ERC721Upgradeable,
    CMTATBaseGeneric,
    AllowlistModule,
    ValidationModuleRuleEngineInternal,
    IERC3643ComplianceRead,
    IERC7551Compliance
{
    /// @notice Reverts when attempting to set the same rule engine address.
    error CMTAT_ValidationModule_SameValue();
    /// @notice Reverts when input array lengths do not match.
    error CMTAT_InvalidLength();
    /// @notice Reverts when calling a mint entry point not allowed by current mint mode.
    error CMTAT_InvalidMintMode();
    /// @notice Reverts when attempting to set the same base URI value.
    error CMTAT_BaseURI_SameValue();
    /// @notice Reverts when attempting to set the same token ID engine address.
    error CMTAT_TokenIdEngine_SameValue();
    /// @notice Reverts when token ID engine is failing and degraded fallback mode is disabled.
    error CMTAT_TokenIdEngineUnavailable();
    /// @notice Reverts when a `nonReentrant` function is re-entered.
    error CMTAT_ReentrancyGuard_ReentrantCall();

    /// @notice Role allowed to mint in `MINTER_INPUT` mode.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice Role allowed to burn tokens.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    /// @notice Role allowed to toggle degraded fallback mode for token ID engine failures.
    bytes32 public constant TOKEN_ID_ENGINE_GUARDIAN_ROLE = keccak256("TOKEN_ID_ENGINE_GUARDIAN_ROLE");

    /// @dev Reentrancy guard state: not entered.
    uint256 private constant _NOT_ENTERED = 1;
    /// @dev Reentrancy guard state: entered.
    uint256 private constant _ENTERED = 2;
    /// @dev Unit value forwarded to CMTAT rule engines for ERC721 transfers.
    uint256 internal constant UNIT_TRANSFER_VALUE = 1;
    /// @dev Current mint-time token ID management mode.
    TokenIdManagementMode internal _tokenIdManagementMode;
    /// @dev Optional ERC721 base URI used to build `tokenURI(tokenId)`.
    string private _baseTokenURI;
    /// @dev Current status of the custom reentrancy guard.
    uint256 private _reentrancyGuardStatus;
    /// @dev Optional external token ID engine.
    ITokenIdEngine private _tokenIdEngine;
    /// @dev Whether fallback to caller-provided token IDs is allowed when the engine reverts.
    bool private _tokenIdEngineDegradedMode;

    /**
     * @notice Emitted on successful mint.
     * @param minter Caller that executed mint.
     * @param account Mint recipient.
     * @param tokenId Minted token ID.
     * @param data Opaque mint payload.
     */
    event Mint(address indexed minter, address indexed account, uint256 tokenId, bytes data);
    /**
     * @notice Emitted on successful burn.
     * @param burner Caller that executed burn.
     * @param account Burned token owner.
     * @param tokenId Burned token ID.
     * @param data Opaque burn payload.
     */
    event Burn(address indexed burner, address indexed account, uint256 tokenId, bytes data);
    /**
     * @notice Emitted on successful forced transfer (enforcement path).
     * @param enforcer Caller that executed forced transfer.
     * @param account Source account.
     * @param amount Transfer amount (token ID value in this ERC721 implementation).
     * @param data Opaque payload.
     */
    event Enforcement(address indexed enforcer, address indexed account, uint256 amount, bytes data);
    /**
     * @notice Emitted when base URI configuration changes.
     * @param operator Caller that changed the base URI.
     * @param newBaseURI New base URI value.
     */
    event BaseURISet(address indexed operator, string newBaseURI);
    /**
     * @notice Emitted when token ID engine configuration changes.
     * @param operator Caller that changed the engine.
     * @param oldTokenIdEngine Previous engine address.
     * @param newTokenIdEngine New engine address.
     */
    event TokenIdEngineSet(address indexed operator, address indexed oldTokenIdEngine, address indexed newTokenIdEngine);
    /**
     * @notice Emitted when degraded fallback mode for engine failures is toggled.
     * @param operator Caller that changed the mode.
     * @param enabled New degraded mode value.
     */
    event TokenIdEngineDegradedModeSet(address indexed operator, bool enabled);
    /**
     * @notice Emitted whenever caller-provided fallback token ID is used.
     * @param operator Caller that initiated mint.
     * @param account Mint recipient account.
     * @param fallbackTokenId Caller-provided fallback token ID used for minting.
     * @param tokenIdEngine Token ID engine address at decision time (`address(0)` when no engine configured).
     * @param dueToEngineError True when fallback is due to engine failure, false when no engine is configured.
     */
    event TokenIdFallbackUsed(
        address indexed operator,
        address indexed account,
        uint256 fallbackTokenId,
        address indexed tokenIdEngine,
        bool dueToEngineError
    );

    /**
     * @dev Prevents nested calls to protected functions.
     */
    modifier nonReentrant() {
        if (_reentrancyGuardStatus == _ENTERED) {
            revert CMTAT_ReentrancyGuard_ReentrantCall();
        }
        _reentrancyGuardStatus = _ENTERED;
        _;
        _reentrancyGuardStatus = _NOT_ENTERED;
    }

    /**
     * @notice Initializes CMTAT721 with explicit ERC721 name and symbol.
     * @param admin Default admin role holder.
     * @param name_ ERC721 token name.
     * @param symbol_ ERC721 token symbol.
     * @param extraInformationAttributes_ CMTAT metadata attributes.
     * @param documentEngine_ Document engine address.
     * @param ruleEngine_ Rule engine address (optional).
     * @param tokenIdEngine_ Token ID engine address (optional, can be `address(0)`).
     * @param tokenIdManagementMode_ Mint-time token ID management mode.
     */
    function initialize(
        address admin,
        string memory name_,
        string memory symbol_,
        ICMTATConstructor.ExtraInformationAttributes memory extraInformationAttributes_,
        IERC1643 documentEngine_,
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode tokenIdManagementMode_
    ) public virtual initializer {
        _initialize(
            admin,
            name_,
            symbol_,
            extraInformationAttributes_,
            documentEngine_,
            ruleEngine_,
            tokenIdEngine_,
            tokenIdManagementMode_
        );
    }

    /**
     * @notice Initializes CMTAT721 using an ERC721 attribute struct.
     * @param admin Default admin role holder.
     * @param ERC721Attributes_ ERC721 metadata attributes.
     * @param extraInformationAttributes_ CMTAT metadata attributes.
     * @param documentEngine_ Document engine address.
     * @param ruleEngine_ Rule engine address (optional).
     * @param tokenIdEngine_ Token ID engine address (optional, can be `address(0)`).
     * @param tokenIdManagementMode_ Mint-time token ID management mode.
     */
    function initializeWithERC721Attributes(
        address admin,
        ICMTAT721Constructor.ERC721Attributes memory ERC721Attributes_,
        ICMTATConstructor.ExtraInformationAttributes memory extraInformationAttributes_,
        IERC1643 documentEngine_,
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode tokenIdManagementMode_
    ) public virtual initializer {
        _initialize(
            admin,
            ERC721Attributes_.name,
            ERC721Attributes_.symbol,
            extraInformationAttributes_,
            documentEngine_,
            ruleEngine_,
            tokenIdEngine_,
            tokenIdManagementMode_
        );
    }

    /**
     * @dev Shared internal initializer entry point.
     */
    function _initialize(
        address admin,
        string memory name_,
        string memory symbol_,
        ICMTATConstructor.ExtraInformationAttributes memory extraInformationAttributes_,
        IERC1643 documentEngine_,
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode tokenIdManagementMode_
    ) internal virtual {
        __CMTAT721_init(
            admin,
            name_,
            symbol_,
            extraInformationAttributes_,
            documentEngine_,
            ruleEngine_,
            tokenIdEngine_,
            tokenIdManagementMode_
        );
    }

    /**
     * @dev Runs the full CMTAT721 initialization sequence.
     */
    function __CMTAT721_init(
        address admin,
        string memory name_,
        string memory symbol_,
        ICMTATConstructor.ExtraInformationAttributes memory extraInformationAttributes_,
        IERC1643 documentEngine_,
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode tokenIdManagementMode_
    ) internal virtual {
        __ERC721_init_unchained(name_, symbol_);
        __CMTAT_init(admin, extraInformationAttributes_, documentEngine_);
        __CMTAT721_internal_init_unchained(ruleEngine_, tokenIdEngine_, tokenIdManagementMode_);
        __CMTAT721_modules_init_unchained();
    }

    /**
     * @dev Initializes internal modules and state not handled by inherited CMTAT base initializer.
     */
    function __CMTAT721_internal_init_unchained(
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode tokenIdManagementMode_
    ) internal virtual {
        __ValidationRuleEngine_init_unchained(ruleEngine_);
        __TokenIdEngine_init_unchained(tokenIdEngine_);
        _setTokenIdManagementMode(tokenIdManagementMode_);
        _tokenIdEngineDegradedMode = false;
        _reentrancyGuardStatus = _NOT_ENTERED;
    }

    /**
     * @dev Initializes token ID engine storage.
     * @param tokenIdEngine_ Token ID engine address. `address(0)` keeps fallback mode active.
     */
    function __TokenIdEngine_init_unchained(ITokenIdEngine tokenIdEngine_) internal virtual onlyInitializing {
        if (address(tokenIdEngine_) != address(0)) {
            _setTokenIdEngine(tokenIdEngine_);
        }
    }

    /**
     * @dev Initializes optional modules for this variant.
     */
    function __CMTAT721_modules_init_unchained() internal virtual {
        __Allowlist_init_unchained();
    }

    /**
     * @notice Mints one token when `MINTER_INPUT` mode is enabled.
     * @param account Recipient account.
     * @param tokenId Requested token ID (fallback if engine unavailable).
     * @param data Opaque payload forwarded to events and token ID engine.
     */
    function mint(address account, uint256 tokenId, bytes calldata data) public virtual nonReentrant onlyRole(MINTER_ROLE) {
        if (_tokenIdManagementMode != TokenIdManagementMode.MINTER_INPUT) {
            revert CMTAT_InvalidMintMode();
        }
        _mintWithChecks(account, _resolveTokenId(account, tokenId, data), data);
    }

    /**
     * @notice Mints one token to `msg.sender` when `USER_INPUT` mode is enabled.
     * @param tokenId Requested token ID (fallback if engine unavailable).
     * @param data Opaque payload forwarded to events and token ID engine.
     */
    function mintByUser(uint256 tokenId, bytes calldata data) public virtual nonReentrant {
        if (_tokenIdManagementMode != TokenIdManagementMode.USER_INPUT) {
            revert CMTAT_InvalidMintMode();
        }
        _mintWithChecks(_msgSender(), _resolveTokenId(_msgSender(), tokenId, data), data);
    }

    /**
     * @notice Batch mints tokens when `MINTER_INPUT` mode is enabled.
     * @param accounts Recipient accounts.
     * @param tokenIds Requested token IDs (fallback values if engine unavailable).
     * @param data Opaque payload forwarded to events and token ID engine.
     */
    function batchMint(address[] calldata accounts, uint256[] calldata tokenIds, bytes calldata data)
        public
        virtual
        nonReentrant
        onlyRole(MINTER_ROLE)
    {
        if (_tokenIdManagementMode != TokenIdManagementMode.MINTER_INPUT) {
            revert CMTAT_InvalidMintMode();
        }
        if (accounts.length != tokenIds.length) {
            revert CMTAT_InvalidLength();
        }
        for (uint256 i = 0; i < accounts.length; ++i) {
            _mintWithChecks(accounts[i], _resolveTokenId(accounts[i], tokenIds[i], data), data);
        }
    }

    /**
     * @notice Burns a token owned by `account`.
     * @param account Current owner of the token.
     * @param tokenId Token ID to burn.
     * @param data Opaque payload emitted in `Burn`.
     */
    function burn(address account, uint256 tokenId, bytes calldata data) public virtual onlyRole(BURNER_ROLE) {
        if (ownerOf(tokenId) != account) {
            revert Errors.CMTAT_InvalidTransfer(account, address(0), tokenId);
        }
        _checkTransferAllowed(address(0), account, address(0), tokenId);
        _burn(tokenId);
        _notifyRuleEngine(address(0), account, address(0));
        emit Burn(_msgSender(), account, tokenId, data);
    }

    /**
     * @notice Burns multiple tokens.
     * @param accounts Owners of tokens to burn.
     * @param tokenIds Token IDs to burn.
     * @param data Opaque payload emitted for each burn.
     */
    function batchBurn(address[] calldata accounts, uint256[] calldata tokenIds, bytes calldata data)
        public
        virtual
        onlyRole(BURNER_ROLE)
    {
        if (accounts.length != tokenIds.length) {
            revert CMTAT_InvalidLength();
        }
        for (uint256 i = 0; i < accounts.length; ++i) {
            burn(accounts[i], tokenIds[i], data);
        }
    }

    /**
     * @notice Forces a transfer as an admin enforcement action.
     * @dev Bypasses allowlist/rule checks by design and still notifies rule engine.
     * @param from Source account.
     * @param to Destination account.
     * @param tokenId Token ID to transfer.
     * @param data Opaque payload emitted in `Enforcement`.
     * @return success Always `true` on success.
     */
    function forcedTransfer(address from, address to, uint256 tokenId, bytes calldata data)
        public
        virtual
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        _transfer(from, to, tokenId);
        _notifyRuleEngine(_msgSender(), from, to);
        emit Enforcement(_msgSender(), from, tokenId, data);
        return true;
    }

    /**
     * @notice Sets a new rule engine.
     * @param ruleEngine_ New rule engine address.
     */
    function setRuleEngine(IRuleEngine ruleEngine_) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        if (ruleEngine_ == ruleEngine()) {
            revert CMTAT_ValidationModule_SameValue();
        }
        _setRuleEngine(ruleEngine_);
    }

    /**
     * @notice Sets a new token ID engine.
     * @param tokenIdEngine_ New token ID engine address.
     */
    function setTokenIdEngine(ITokenIdEngine tokenIdEngine_) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokenIdEngine_ == _tokenIdEngine) {
            revert CMTAT_TokenIdEngine_SameValue();
        }
        _setTokenIdEngine(tokenIdEngine_);
    }

    /**
     * @notice Enables/disables degraded fallback mode for token ID engine failures.
     * @dev When disabled, engine reverts propagate and minting reverts.
     * @param enabled New degraded mode value.
     */
    function setTokenIdEngineDegradedMode(bool enabled) public virtual onlyRole(TOKEN_ID_ENGINE_GUARDIAN_ROLE) {
        _tokenIdEngineDegradedMode = enabled;
        emit TokenIdEngineDegradedModeSet(_msgSender(), enabled);
    }

    /**
     * @notice Sets ERC721 base URI used for `tokenURI`.
     * @param baseURI_ New base URI prefix.
     */
    function setBaseURI(string calldata baseURI_) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        if (keccak256(bytes(baseURI_)) == keccak256(bytes(_baseTokenURI))) {
            revert CMTAT_BaseURI_SameValue();
        }
        _baseTokenURI = baseURI_;
        emit BaseURISet(_msgSender(), baseURI_);
    }

    /**
     * @notice Returns active mint-time token ID management mode.
     * @return mode Current mode value.
     */
    function tokenIdManagementMode() public view returns (TokenIdManagementMode) {
        return _tokenIdManagementMode;
    }

    /**
     * @notice Returns configured token ID engine.
     * @return engine Current token ID engine address.
     */
    function tokenIdEngine() public view returns (ITokenIdEngine) {
        return _tokenIdEngine;
    }

    /**
     * @notice Returns whether degraded fallback mode is enabled for engine failures.
     * @return enabled True when engine failures fallback to caller-provided token IDs.
     */
    function tokenIdEngineDegradedMode() public view returns (bool) {
        return _tokenIdEngineDegradedMode;
    }

    /**
     * @notice Returns ERC721 base URI used for metadata resolution.
     * @return uri Base URI string.
     */
    function baseURI() public view returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @inheritdoc IERC3643ComplianceRead
     */
    function canTransfer(address from, address to, uint256)
        public
        view
        virtual
        override(IERC3643ComplianceRead)
        returns (bool)
    {
        return _canTransferByAllModules(address(0), from, to);
    }

    /**
     * @inheritdoc IERC7551Compliance
     */
    function canTransferFrom(address spender, address from, address to, uint256)
        public
        view
        virtual
        override(IERC7551Compliance)
        returns (bool)
    {
        return _canTransferByAllModules(spender, from, to);
    }

    /**
     * @inheritdoc ERC721Upgradeable
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        _checkTransferAllowed(_msgSender(), from, to, tokenId);
        ERC721Upgradeable.transferFrom(from, to, tokenId);
        _notifyRuleEngine(_msgSender(), from, to);
    }

    /**
     * @inheritdoc ERC721Upgradeable
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {
        ERC721Upgradeable.safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * @inheritdoc AccessControlUpgradeable
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IAllowlistModule).interfaceId
            || interfaceId == type(IERC3643ComplianceRead).interfaceId
            || interfaceId == type(IERC7551Compliance).interfaceId
            || ERC721Upgradeable.supportsInterface(interfaceId)
            || AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    /**
     * @dev Authorizes `pause` and `unpause`.
     */
    function _authorizePause() internal virtual override(PauseModule) onlyRole(PAUSER_ROLE) {}

    /**
     * @dev Authorizes irreversible contract deactivation.
     */
    function _authorizeDeactivate() internal virtual override(PauseModule) onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @dev Authorizes freeze/unfreeze operations.
     */
    function _authorizeFreeze() internal virtual override(EnforcementModule) onlyRole(ENFORCER_ROLE) {}

    /**
     * @dev Authorizes allowlist management operations.
     */
    function _authorizeAllowlistManagement() internal virtual override(AllowlistModule) onlyRole(ALLOWLIST_ROLE) {}

    /**
     * @dev Aggregates transfer checks from generic validation, allowlist, and rule engine.
     * @return allowed `true` when all enabled checks pass.
     */
    function _canTransferByAllModules(address spender, address from, address to) internal view returns (bool) {
        if (!ValidationModule._canTransferGenericByModule(spender, from, to)) {
            return false;
        }

        if (_isAllowlistEnabled()) {
            bool spenderRestricted = spender != address(0) && !_isAllowlisted(spender);
            bool fromRestricted = from != address(0) && !_isAllowlisted(from);
            bool toRestricted = to != address(0) && !_isAllowlisted(to);
            if (spenderRestricted || fromRestricted || toRestricted) {
                return false;
            }
        }

        IRuleEngine ruleEngine_ = ruleEngine();
        if (address(ruleEngine_) == address(0)) {
            return true;
        }

        if (spender == address(0)) {
            return ruleEngine_.canTransfer(from, to, UNIT_TRANSFER_VALUE);
        }

        return ruleEngine_.canTransferFrom(spender, from, to, UNIT_TRANSFER_VALUE);
    }

    /**
     * @dev Reverts if transfer is not allowed by active modules.
     */
    function _checkTransferAllowed(address spender, address from, address to, uint256 tokenId) internal view {
        if (!_canTransferByAllModules(spender, from, to)) {
            revert Errors.CMTAT_InvalidTransfer(from, to, tokenId);
        }
    }

    /**
     * @dev Performs transfer checks, mints, notifies rule engine, and emits `Mint`.
     */
    function _mintWithChecks(address account, uint256 tokenId, bytes memory data) internal {
        _checkTransferAllowed(address(0), address(0), account, tokenId);
        _mint(account, tokenId);
        _notifyRuleEngine(address(0), address(0), account);
        emit Mint(_msgSender(), account, tokenId, data);
    }

    /**
     * @dev Sets mint-time token ID management mode.
     */
    function _setTokenIdManagementMode(TokenIdManagementMode tokenIdManagementMode_) internal {
        _tokenIdManagementMode = tokenIdManagementMode_;
    }

    /**
     * @dev Updates token ID engine and emits configuration event.
     */
    function _setTokenIdEngine(ITokenIdEngine tokenIdEngine_) internal {
        emit TokenIdEngineSet(_msgSender(), address(_tokenIdEngine), address(tokenIdEngine_));
        _tokenIdEngine = tokenIdEngine_;
    }

    /**
     * @dev Returns ERC721 base URI for OpenZeppelin `tokenURI`.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Resolves the token ID to mint.
     * @param account Mint recipient.
     * @param fallbackTokenId Token ID provided by caller and used as fallback.
     * @param data Opaque payload forwarded to token ID engine.
     * @return tokenId_ Resolved token ID (engine result or fallback).
     */
    function _resolveTokenId(address account, uint256 fallbackTokenId, bytes memory data) internal returns (uint256) {
        ITokenIdEngine tokenIdEngine_ = _tokenIdEngine;
        if (address(tokenIdEngine_) == address(0)) {
            emit TokenIdFallbackUsed(_msgSender(), account, fallbackTokenId, address(0), false);
            return fallbackTokenId;
        }
        try tokenIdEngine_.getTokenId(_msgSender(), account, data) returns (uint256 tokenId_) {
            return tokenId_;
        } catch {
            if (!_tokenIdEngineDegradedMode) {
                revert CMTAT_TokenIdEngineUnavailable();
            }
            emit TokenIdFallbackUsed(_msgSender(), account, fallbackTokenId, address(tokenIdEngine_), true);
            return fallbackTokenId;
        }
    }

    /**
     * @dev Notifies rule engine callback hooks when configured.
     */
    function _notifyRuleEngine(address spender, address from, address to) internal {
        IRuleEngine ruleEngine_ = ruleEngine();
        if (address(ruleEngine_) == address(0)) {
            return;
        }

        if (spender == address(0)) {
            ruleEngine_.transferred(from, to, UNIT_TRANSFER_VALUE);
        } else {
            ruleEngine_.transferred(spender, from, to, UNIT_TRANSFER_VALUE);
        }
    }
}

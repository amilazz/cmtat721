// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IDocumentEngine} from "../../vendor/CMTAT/contracts/interfaces/engine/IDocumentEngine.sol";

/**
 * @title Document Engine Mock
 * @notice Test double for CMTAT document storage.
 */
contract DocumentEngineMock is IDocumentEngine {
    /// @dev Documents keyed by their logical name.
    mapping(string => Document) private documents;
    /// @dev Ordered list of inserted document names.
    string[] private documentNames;

    /**
     * @notice Emitted when a document is created or updated.
     * @param name Document name key.
     * @param doc Stored document payload.
     */
    event DocumentUpdated(string indexed name, Document doc);

    /**
     * @notice Creates or updates a document.
     * @param name Document name key.
     * @param uri Off-chain location of the document.
     * @param documentHash Integrity hash of the document content.
     */
    function setDocument(string calldata name, string calldata uri, bytes32 documentHash) external {
        Document storage doc = documents[name];
        if (doc.lastModified == 0) {
            documentNames.push(name);
        }
        doc.uri = uri;
        doc.documentHash = documentHash;
        doc.lastModified = block.timestamp;
        emit DocumentUpdated(name, doc);
    }

    /**
     * @notice Returns a document by name.
     * @param name Document name key.
     * @return doc Stored document payload.
     */
    function getDocument(string memory name) external view override returns (Document memory doc) {
        return documents[name];
    }

    /**
     * @notice Returns all known document names.
     * @return names Array of document keys.
     */
    function getAllDocuments() external view override returns (string[] memory names) {
        return documentNames;
    }
}

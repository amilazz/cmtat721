const { expect } = require('chai')
const { ethers } = require('hardhat')
const {
  MODE_MINTER_INPUT,
  MODE_USER_INPUT,
  EMPTY_BYTES,
  buildExtraInfo,
  fixture,
  loadFixture,
  deployCMTAT721Standalone,
  deployCMTAT721StandaloneWithERC721Attributes,
  deployInitHarness,
  deployTokenIdEngine
} = require('../deploymentUtils')

describe('CMTAT721 - Deployment', function () {
  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture))
    const deployed = await deployCMTAT721Standalone(this.admin.address)
    this.token = deployed.token
    this.documentEngine = deployed.documentEngine
  })

  it('testKeepCoreInformationAndDefaults', async function () {
    expect(await this.token.name()).to.equal('CMTAT 721')
    expect(await this.token.symbol()).to.equal('C721')
    expect(await this.token.version()).to.equal('3.1.0')
    expect(await this.token.tokenId()).to.equal('CH0000NFT721')
    expect(await this.token.information()).to.equal('CMTAT 721 compatible token')
    expect(await this.token.isAllowlistEnabled()).to.equal(true)
    expect(await this.token.tokenIdEngine()).to.equal(ethers.ZeroAddress)

    const terms = await this.token.terms()
    expect(terms.name).to.equal('terms')
    expect(terms.doc.uri).to.equal('ipfs://terms')
    expect(terms.doc.documentHash).to.equal(ethers.id('terms-hash'))
    expect(terms.doc.lastModified).to.not.equal(0)

    await this.documentEngine.setDocument('prospectus', 'ipfs://prospectus', ethers.id('doc-hash'))
    const storedDoc = await this.token.getDocument('prospectus')
    expect(storedDoc.uri).to.equal('ipfs://prospectus')
    expect(storedDoc.documentHash).to.equal(ethers.id('doc-hash'))
  })

  it('testCannotReinitialize', async function () {
    await expect(
      this.token.connect(this.admin).initialize(
        this.admin.address,
        'x',
        'x',
        buildExtraInfo(),
        await this.documentEngine.getAddress(),
        ethers.ZeroAddress,
        ethers.ZeroAddress,
        MODE_MINTER_INPUT
      )
    ).to.be.reverted
  })

  it('testSupportsInterfaces', async function () {
    const helperFactory = await ethers.getContractFactory('InterfaceIdHelper')
    const helper = await helperFactory.deploy()
    await helper.waitForDeployment()

    expect(await this.token.supportsInterface('0x80ac58cd')).to.equal(true)
    expect(await this.token.supportsInterface('0x7965db0b')).to.equal(true)
    expect(await this.token.supportsInterface(await helper.allowlistId())).to.equal(true)
    expect(await this.token.supportsInterface(await helper.complianceReadId())).to.equal(true)
    expect(await this.token.supportsInterface(await helper.complianceId())).to.equal(true)
    expect(await this.token.supportsInterface('0xffffffff')).to.equal(false)
  })

  it('testDeployUserManagedMode', async function () {
    const deployed = await deployCMTAT721Standalone(this.admin.address, {
      name: 'CMTAT 721 UserManaged',
      symbol: 'C721U',
      mode: MODE_USER_INPUT
    })

    await deployed.token.batchSetAddressAllowlist(
      [this.admin.address, this.address1.address],
      [true, true]
    )

    await expect(deployed.token.mint(this.address1.address, 1, EMPTY_BYTES)).to.be.revertedWithCustomError(
      deployed.token,
      'CMTAT_InvalidMintMode'
    )
    await expect(deployed.token.batchMint([this.address1.address], [1], EMPTY_BYTES)).to.be.revertedWithCustomError(
      deployed.token,
      'CMTAT_InvalidMintMode'
    )

    await expect(deployed.token.connect(this.address1).mintByUser(1, EMPTY_BYTES))
      .to.emit(deployed.token, 'TokenIdFallbackUsed')
      .withArgs(this.address1.address, this.address1.address, 1, ethers.ZeroAddress, false)
    expect(await deployed.token.ownerOf(1)).to.equal(this.address1.address)
    expect(await deployed.token.tokenIdManagementMode()).to.equal(MODE_USER_INPUT)
  })

  it('testDeployWithERC721AttributesStruct', async function () {
    const deployed = await deployCMTAT721StandaloneWithERC721Attributes(this.admin.address, {
      name: 'CMTAT 721 Struct',
      symbol: 'C721S'
    })

    expect(await deployed.token.name()).to.equal('CMTAT 721 Struct')
    expect(await deployed.token.symbol()).to.equal('C721S')
    expect(await deployed.token.tokenId()).to.equal('CH0000NFT721')
  })

  it('testInitializeTokenIdEngineAtDeployment', async function () {
    const tokenIdEngine = await deployTokenIdEngine(5000)
    const deployed = await deployCMTAT721Standalone(this.admin.address, {
      tokenIdEngine: await tokenIdEngine.getAddress()
    })

    expect(await deployed.token.tokenIdEngine()).to.equal(await tokenIdEngine.getAddress())

    await deployed.token.batchSetAddressAllowlist(
      [this.admin.address, this.address1.address],
      [true, true]
    )
    await deployed.token.mint(this.address1.address, 1, EMPTY_BYTES)
    expect(await deployed.token.ownerOf(5000)).to.equal(this.address1.address)
  })

  it('testBaseURIAndTokenURI', async function () {
    await this.token.batchSetAddressAllowlist(
      [this.admin.address, this.address1.address],
      [true, true]
    )
    await this.token.mint(this.address1.address, 1, EMPTY_BYTES)

    expect(await this.token.baseURI()).to.equal('')
    expect(await this.token.tokenURI(1)).to.equal('')

    await expect(this.token.connect(this.address1).setBaseURI('ipfs://meta/')).to.be.reverted
    await this.token.setBaseURI('ipfs://meta/')
    await expect(this.token.setBaseURI('ipfs://meta/')).to.be.revertedWithCustomError(
      this.token,
      'CMTAT_BaseURI_SameValue'
    )

    expect(await this.token.baseURI()).to.equal('ipfs://meta/')
    expect(await this.token.tokenURI(1)).to.equal('ipfs://meta/1')
  })

  it('testCMTATStyleInitFlowEntryPoints', async function () {
    const harness = await deployInitHarness()
    const extraInfo = buildExtraInfo()

    await expect(
      harness.callInitializeInternal(
        this.admin.address,
        'X',
        'X',
        extraInfo,
        ethers.ZeroAddress,
        ethers.ZeroAddress,
        ethers.ZeroAddress,
        MODE_MINTER_INPUT
      )
    ).to.be.reverted

    await expect(
      harness.callCMTAT721Init(
        this.admin.address,
        'X',
        'X',
        extraInfo,
        ethers.ZeroAddress,
        ethers.ZeroAddress,
        ethers.ZeroAddress,
        MODE_MINTER_INPUT
      )
    ).to.be.reverted

    await expect(
      harness.callCMTAT721InternalInit(ethers.ZeroAddress, ethers.ZeroAddress, MODE_MINTER_INPUT)
    ).to.be.reverted
    await expect(harness.callCMTAT721ModulesInit()).to.be.reverted
    await expect(harness.callTokenIdEngineInit(ethers.ZeroAddress)).to.be.reverted
  })
})

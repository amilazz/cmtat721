const { expect } = require('chai')
const { ethers } = require('hardhat')
const {
  EMPTY_BYTES,
  fixture,
  loadFixture,
  deployCMTAT721Standalone,
  deployDocumentEngine
} = require('../../deploymentUtils')

describe('CMTAT721 - Standard Modules', function () {
  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture))
    const deployed = await deployCMTAT721Standalone(this.admin.address)
    this.token = deployed.token
  })

  it('testRestrictedModuleOperations', async function () {
    await expect(this.token.connect(this.address1).pause()).to.be.reverted
    await expect(this.token.connect(this.address1).deactivateContract()).to.be.reverted
    await expect(this.token.connect(this.address1).setAddressFrozen(this.address1.address, true)).to.be.reverted
    await expect(this.token.connect(this.address1).setAddressAllowlist(this.address1.address, true)).to.be.reverted
    await expect(this.token.connect(this.address1).setDocumentEngine(ethers.ZeroAddress)).to.be.reverted
    await expect(this.token.connect(this.address1).setTokenId('X')).to.be.reverted
    await expect(this.token.connect(this.address1).mint(this.address1.address, 1, EMPTY_BYTES)).to.be.reverted
    await expect(this.token.connect(this.address1).batchMint([this.address1.address], [1], EMPTY_BYTES)).to.be.reverted
    await expect(this.token.connect(this.address1).burn(this.address1.address, 1, EMPTY_BYTES)).to.be.reverted
    await expect(this.token.connect(this.address1).batchBurn([this.address1.address], [1], EMPTY_BYTES)).to.be.reverted
    await expect(this.token.connect(this.address1).mintByUser(1, EMPTY_BYTES)).to.be.revertedWithCustomError(
      this.token,
      'CMTAT_InvalidMintMode'
    )
    await expect(this.token.connect(this.address1).setRuleEngine(ethers.ZeroAddress)).to.be.reverted
    await expect(this.token.connect(this.address1).setTokenIdEngine(ethers.ZeroAddress)).to.be.reverted

    await this.token.pause()
    await expect(this.token.unpause()).to.not.be.reverted

    await this.token.setAddressFrozen(this.address1.address, true)
    expect(await this.token.isFrozen(this.address1.address)).to.equal(true)
    await this.token.batchSetAddressFrozen([this.address1.address], [false])
    expect(await this.token.isFrozen(this.address1.address)).to.equal(false)

    await this.token.setAddressAllowlist(this.address1.address, true)
    expect(await this.token.isAllowlisted(this.address1.address)).to.equal(true)
    await this.token.batchSetAddressAllowlist([this.address1.address], [false])
    expect(await this.token.isAllowlisted(this.address1.address)).to.equal(false)

    await this.token.setTokenId('NEW-ID')
    expect(await this.token.tokenId()).to.equal('NEW-ID')

    await this.token.setInformation('updated-info')
    expect(await this.token.information()).to.equal('updated-info')

    await this.token.setTerms({
      name: 'new-terms',
      uri: 'ipfs://new-terms',
      documentHash: ethers.id('new-terms')
    })

    const terms = await this.token.terms()
    expect(terms.name).to.equal('new-terms')
    expect(terms.doc.uri).to.equal('ipfs://new-terms')

    const newDocumentEngine = await deployDocumentEngine()
    await this.token.setDocumentEngine(await newDocumentEngine.getAddress())
    expect(await this.token.documentEngine()).to.equal(await newDocumentEngine.getAddress())

    await this.token.enableAllowlist(false)
    await this.token.mint(this.admin.address, 99, EMPTY_BYTES)
    await this.token.mint(this.address1.address, 100, EMPTY_BYTES)
    await this.token.enableAllowlist(true)
    await expect(this.token.mint(this.address1.address, 101, EMPTY_BYTES)).to.be.reverted

    await this.token.pause()
    await this.token.deactivateContract()
    expect(await this.token.deactivated()).to.equal(true)
    await expect(this.token.unpause()).to.be.reverted
    await expect(this.token.mint(this.admin.address, 102, EMPTY_BYTES)).to.be.reverted
  })

  it('testAllowlistTransferValidation', async function () {
    await expect(this.token.mint(this.address1.address, 1, EMPTY_BYTES)).to.be.reverted

    await this.token.batchSetAddressAllowlist(
      [this.admin.address, this.address1.address, this.address2.address],
      [true, true, true]
    )

    await this.token.mint(this.address1.address, 1, EMPTY_BYTES)

    expect(await this.token.canTransfer(this.address1.address, this.address2.address, 999)).to.equal(true)
    expect(await this.token.canTransfer(this.outsider.address, this.address2.address, 1)).to.equal(false)
    expect(await this.token.canTransfer(this.address1.address, this.outsider.address, 1)).to.equal(false)
    expect(await this.token.canTransferFrom(this.outsider.address, this.address1.address, this.address2.address, 1)).to.equal(false)

    await this.token.enableAllowlist(false)
    expect(await this.token.canTransfer(this.outsider.address, this.address2.address, 1)).to.equal(true)
    await this.token.mint(this.address2.address, 2, EMPTY_BYTES)
  })

  it('testBatchMintAndBurn', async function () {
    await this.token.batchSetAddressAllowlist(
      [this.admin.address, this.address1.address, this.address2.address],
      [true, true, true]
    )

    await expect(this.token.batchMint([this.address1.address], [1, 2], EMPTY_BYTES)).to.be.revertedWithCustomError(
      this.token,
      'CMTAT_InvalidLength'
    )

    await this.token.batchMint([this.address1.address, this.address2.address], [1, 2], EMPTY_BYTES)
    expect(await this.token.ownerOf(1)).to.equal(this.address1.address)
    expect(await this.token.ownerOf(2)).to.equal(this.address2.address)

    await expect(this.token.batchBurn([this.address1.address], [1, 2], EMPTY_BYTES)).to.be.revertedWithCustomError(
      this.token,
      'CMTAT_InvalidLength'
    )

    await this.token.batchBurn([this.address1.address, this.address2.address], [1, 2], EMPTY_BYTES)
    await expect(this.token.ownerOf(1)).to.be.revertedWithCustomError(this.token, 'ERC721NonexistentToken')
    await expect(this.token.ownerOf(2)).to.be.revertedWithCustomError(this.token, 'ERC721NonexistentToken')
  })

  it('testPauseAndFreezeRestrictions', async function () {
    await this.token.batchSetAddressAllowlist(
      [this.admin.address, this.address1.address, this.address2.address],
      [true, true, true]
    )

    await this.token.mint(this.address1.address, 1, EMPTY_BYTES)
    await expect(this.token.burn(this.address2.address, 1, EMPTY_BYTES)).to.be.reverted

    await this.token.connect(this.address1).approve(this.address1.address, 1)

    await this.token.pause()
    await expect(this.token.connect(this.address1).transferFrom(this.address1.address, this.address2.address, 1)).to.be.reverted
    await this.token.unpause()

    await this.token.connect(this.address1).transferFrom(this.address1.address, this.address2.address, 1)
    expect(await this.token.ownerOf(1)).to.equal(this.address2.address)

    await this.token.setAddressFrozen(this.address2.address, true)
    await expect(this.token.burn(this.address2.address, 1, EMPTY_BYTES)).to.be.reverted
    await this.token.setAddressFrozen(this.address2.address, false)
    await this.token.burn(this.address2.address, 1, EMPTY_BYTES)
  })
})

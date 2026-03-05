const { expect } = require('chai')
const {
  MODE_USER_INPUT,
  EMPTY_BYTES,
  fixture,
  loadFixture,
  deployCMTAT721Standalone,
  deployTokenIdEngine
} = require('../../deploymentUtils')

describe('CMTAT721 - TokenIdEngine Module', function () {
  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture))
    const deployed = await deployCMTAT721Standalone(this.admin.address)
    this.token = deployed.token
  })

  it('testSetTokenIdEngineAndFallback', async function () {
    const tokenIdEngine = await deployTokenIdEngine(777)

    await expect(this.token.connect(this.address1).setTokenIdEngine(await tokenIdEngine.getAddress())).to.be.reverted

    await expect(this.token.setTokenIdEngine(await tokenIdEngine.getAddress()))
      .to.emit(this.token, 'TokenIdEngineSet')
      .withArgs(this.admin.address, '0x0000000000000000000000000000000000000000', await tokenIdEngine.getAddress())

    await expect(this.token.setTokenIdEngine(await tokenIdEngine.getAddress())).to.be.revertedWithCustomError(
      this.token,
      'CMTAT_TokenIdEngine_SameValue'
    )

    await this.token.batchSetAddressAllowlist(
      [this.admin.address, this.address1.address],
      [true, true]
    )

    await this.token.mint(this.address1.address, 1, EMPTY_BYTES)
    expect(await this.token.ownerOf(777)).to.equal(this.address1.address)
    await expect(this.token.ownerOf(1)).to.be.revertedWithCustomError(this.token, 'ERC721NonexistentToken')

    await tokenIdEngine.setShouldRevert(true)
    await this.token.mint(this.address1.address, 2, EMPTY_BYTES)
    expect(await this.token.ownerOf(2)).to.equal(this.address1.address)

    await tokenIdEngine.setShouldRevert(false)
    await this.token.grantRole(await this.token.MINTER_ROLE(), await tokenIdEngine.getAddress())

    await tokenIdEngine.setTokenIdToReturn(1001)
    await tokenIdEngine.configureReentrancy(
      await this.token.getAddress(),
      this.address1.address,
      1200,
      EMPTY_BYTES,
      2
    )
    await this.token.mint(this.address1.address, 3, EMPTY_BYTES)
    expect(await tokenIdEngine.reentrancyBlocked()).to.equal(true)
    expect(await this.token.ownerOf(1001)).to.equal(this.address1.address)
    await expect(this.token.ownerOf(1200)).to.be.revertedWithCustomError(this.token, 'ERC721NonexistentToken')

    await tokenIdEngine.setTokenIdToReturn(1002)
    await tokenIdEngine.configureReentrancy(
      await this.token.getAddress(),
      this.address1.address,
      1300,
      EMPTY_BYTES,
      3
    )
    await this.token.batchMint([this.address1.address], [4], EMPTY_BYTES)
    expect(await tokenIdEngine.reentrancyBlocked()).to.equal(true)
    expect(await this.token.ownerOf(1002)).to.equal(this.address1.address)
    await expect(this.token.ownerOf(1300)).to.be.revertedWithCustomError(this.token, 'ERC721NonexistentToken')
  })

  it('testUserModeReentrancyBlock', async function () {
    const deployed = await deployCMTAT721Standalone(this.admin.address, {
      name: 'CMTAT 721 UserManaged',
      symbol: 'C721U',
      mode: MODE_USER_INPUT
    })

    const tokenIdEngine = await deployTokenIdEngine(888)

    await deployed.token.batchSetAddressAllowlist(
      [this.admin.address, this.address1.address],
      [true, true]
    )

    await deployed.token.setTokenIdEngine(await tokenIdEngine.getAddress())
    await tokenIdEngine.configureReentrancy(
      await deployed.token.getAddress(),
      this.address1.address,
      999,
      EMPTY_BYTES,
      1
    )

    await deployed.token.connect(this.address1).mintByUser(7, EMPTY_BYTES)

    expect(await tokenIdEngine.reentrancyBlocked()).to.equal(true)
    expect(await deployed.token.ownerOf(888)).to.equal(this.address1.address)
    await expect(deployed.token.ownerOf(999)).to.be.revertedWithCustomError(deployed.token, 'ERC721NonexistentToken')

    await tokenIdEngine.setShouldRevert(true)
    await deployed.token.connect(this.address1).mintByUser(11, EMPTY_BYTES)
    expect(await deployed.token.ownerOf(11)).to.equal(this.address1.address)
  })
})

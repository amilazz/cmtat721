const { expect } = require('chai')
const { ethers, upgrades } = require('hardhat')
const {
  MODE_MINTER_INPUT,
  EMPTY_BYTES,
  fixture,
  loadFixture,
  deployCMTAT721UUPSProxy,
  deployCMTAT721UUPSProxyWithERC721Attributes
} = require('../deploymentUtils')

describe('CMTAT721 - Deployment UUPS', function () {
  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture))
    const deployed = await deployCMTAT721UUPSProxy(this.admin.address)
    this.token = deployed.token
  })

  it('testDeployUUPSProxyAndMint', async function () {
    await this.token.batchSetAddressAllowlist(
      [this.admin.address, this.address1.address],
      [true, true]
    )

    await this.token.mint(this.address1.address, 1, EMPTY_BYTES)
    expect(await this.token.ownerOf(1)).to.equal(this.address1.address)
    expect(await this.token.version()).to.equal('3.1.0')
    expect(await this.token.name()).to.equal('CMTAT 721 Proxy')
    expect(await this.token.tokenIdManagementMode()).to.equal(MODE_MINTER_INPUT)
  })

  it('testUUPSUpgradeAccessControl', async function () {
    const v2Factory = await ethers.getContractFactory('CMTAT721UpgradeableV2')
    const upgradeOpts = {
      kind: 'uups',
      unsafeAllow: ['missing-initializer', 'missing-initializer-call']
    }

    await expect(
      upgrades.upgradeProxy(await this.token.getAddress(), v2Factory.connect(this.address1), upgradeOpts)
    ).to.be.reverted

    const upgraded = await upgrades.upgradeProxy(
      await this.token.getAddress(),
      v2Factory.connect(this.admin),
      upgradeOpts
    )

    expect(await upgraded.mockVersion2()).to.equal('2')
  })

  it('testDeployUUPSProxyWithERC721AttributesStruct', async function () {
    const deployed = await deployCMTAT721UUPSProxyWithERC721Attributes(this.admin.address, {
      name: 'CMTAT 721 Proxy Struct',
      symbol: 'C721PS'
    })

    expect(await deployed.token.name()).to.equal('CMTAT 721 Proxy Struct')
    expect(await deployed.token.symbol()).to.equal('C721PS')
  })
})

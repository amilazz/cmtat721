const { expect } = require('chai')
const {
  EMPTY_BYTES,
  fixture,
  loadFixture,
  deployCMTAT721Standalone,
  deployRuleEngine
} = require('../../deploymentUtils')

describe('CMTAT721 - RuleEngine Module', function () {
  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture))
    const deployed = await deployCMTAT721Standalone(this.admin.address)
    this.token = deployed.token
  })

  it('testRuleEngineValidationAndCallbacks', async function () {
    const ruleEngine = await deployRuleEngine()

    await this.token.batchSetAddressAllowlist(
      [this.admin.address, this.address1.address, this.address2.address],
      [true, true, true]
    )

    await this.token.setRuleEngine(await ruleEngine.getAddress())
    await expect(this.token.setRuleEngine(await ruleEngine.getAddress())).to.be.revertedWithCustomError(
      this.token,
      'CMTAT_ValidationModule_SameValue'
    )

    await this.token.mint(this.address1.address, 1, EMPTY_BYTES)
    expect(await ruleEngine.transferredNoSpenderCount()).to.equal(1)

    expect(await this.token.canTransfer(this.address1.address, this.address2.address, 17)).to.equal(true)

    await ruleEngine.setTransfersAllowed(false)
    expect(await this.token.canTransfer(this.address1.address, this.address2.address, 17)).to.equal(false)
    await expect(this.token.mint(this.address2.address, 2, EMPTY_BYTES)).to.be.reverted

    await ruleEngine.setTransfersAllowed(true)
    await this.token.mint(this.address2.address, 2, EMPTY_BYTES)

    await ruleEngine.setTransferFromAllowed(false)
    await expect(this.token.connect(this.address1).transferFrom(this.address1.address, this.address2.address, 1)).to.be.reverted

    await ruleEngine.setTransferFromAllowed(true)
    await this.token.connect(this.address1).transferFrom(this.address1.address, this.address2.address, 1)
    expect(await ruleEngine.transferredWithSpenderCount()).to.equal(1)

    await this.token.connect(this.address2)['safeTransferFrom(address,address,uint256,bytes)'](
      this.address2.address,
      this.address1.address,
      1,
      EMPTY_BYTES
    )
    expect(await ruleEngine.transferredWithSpenderCount()).to.equal(2)
    expect(await this.token.ownerOf(1)).to.equal(this.address1.address)
  })

  it('testForcedTransferWithRuleEngine', async function () {
    const ruleEngine = await deployRuleEngine()

    await this.token.batchSetAddressAllowlist(
      [this.admin.address, this.address1.address],
      [true, true]
    )

    await this.token.setRuleEngine(await ruleEngine.getAddress())
    await this.token.mint(this.address1.address, 1, EMPTY_BYTES)

    await this.token.pause()
    await this.token.setAddressFrozen(this.address1.address, true)

    await expect(
      this.token.connect(this.outsider).forcedTransfer(this.address1.address, this.address2.address, 1, EMPTY_BYTES)
    ).to.be.reverted

    await expect(this.token.forcedTransfer(this.address1.address, this.address2.address, 1, EMPTY_BYTES))
      .to.emit(this.token, 'Enforcement')
      .withArgs(this.admin.address, this.address1.address, 1, EMPTY_BYTES)

    expect(await this.token.ownerOf(1)).to.equal(this.address2.address)
    expect(await ruleEngine.transferredWithSpenderCount()).to.equal(1)
  })
})

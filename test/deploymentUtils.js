const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers')
const { ethers, upgrades } = require('hardhat')

const EMPTY_BYTES = '0x'
const MODE_MINTER_INPUT = 0
const MODE_USER_INPUT = 1

function buildERC721Attributes(name = 'CMTAT 721', symbol = 'C721') {
  return { name, symbol }
}

function buildExtraInfo() {
  return {
    tokenId: 'CH0000NFT721',
    terms: {
      name: 'terms',
      uri: 'ipfs://terms',
      documentHash: ethers.id('terms-hash')
    },
    information: 'CMTAT 721 compatible token'
  }
}

async function fixture() {
  const [admin, address1, address2, address3, deployerAddress, outsider] = await ethers.getSigners()
  return {
    _: admin,
    admin,
    address1,
    address2,
    address3,
    deployerAddress,
    outsider
  }
}

async function deployDocumentEngine() {
  const documentEngineFactory = await ethers.getContractFactory('DocumentEngineMock')
  const documentEngine = await documentEngineFactory.deploy()
  await documentEngine.waitForDeployment()
  return documentEngine
}

async function deployCMTAT721Standalone(admin, options = {}) {
  const {
    name = 'CMTAT 721',
    symbol = 'C721',
    ruleEngine = ethers.ZeroAddress,
    tokenIdEngine = ethers.ZeroAddress,
    mode = MODE_MINTER_INPUT
  } = options

  const documentEngine = await deployDocumentEngine()
  const standaloneFactory = await ethers.getContractFactory('CMTAT721Standalone')
  const token = await standaloneFactory.deploy(
    admin,
    name,
    symbol,
    buildExtraInfo(),
    await documentEngine.getAddress(),
    ruleEngine,
    tokenIdEngine,
    mode
  )
  await token.waitForDeployment()

  return { token, documentEngine }
}

async function deployCMTAT721StandaloneWithERC721Attributes(admin, options = {}) {
  const {
    name = 'CMTAT 721',
    symbol = 'C721',
    ruleEngine = ethers.ZeroAddress,
    tokenIdEngine = ethers.ZeroAddress,
    mode = MODE_MINTER_INPUT
  } = options

  const documentEngine = await deployDocumentEngine()
  const standaloneFactory = await ethers.getContractFactory('CMTAT721StandaloneWithERC721Attributes')
  const token = await standaloneFactory.deploy(
    admin,
    buildERC721Attributes(name, symbol),
    buildExtraInfo(),
    await documentEngine.getAddress(),
    ruleEngine,
    tokenIdEngine,
    mode
  )
  await token.waitForDeployment()

  return { token, documentEngine }
}

async function deployCMTAT721UUPSProxy(admin, options = {}) {
  const {
    name = 'CMTAT 721 Proxy',
    symbol = 'C721P',
    ruleEngine = ethers.ZeroAddress,
    tokenIdEngine = ethers.ZeroAddress,
    mode = MODE_MINTER_INPUT
  } = options

  const documentEngine = await deployDocumentEngine()
  const upgradeableFactory = await ethers.getContractFactory('CMTAT721Upgradeable')
  const token = await upgrades.deployProxy(
    upgradeableFactory,
    [
      admin,
      name,
      symbol,
      buildExtraInfo(),
      await documentEngine.getAddress(),
      ruleEngine,
      tokenIdEngine,
      mode
    ],
    {
      kind: 'uups',
      initializer: 'initialize',
      unsafeAllow: ['constructor', 'missing-initializer', 'missing-initializer-call']
    }
  )
  await token.waitForDeployment()

  return { token, documentEngine }
}

async function deployCMTAT721UUPSProxyWithERC721Attributes(admin, options = {}) {
  const {
    name = 'CMTAT 721 Proxy',
    symbol = 'C721P',
    ruleEngine = ethers.ZeroAddress,
    tokenIdEngine = ethers.ZeroAddress,
    mode = MODE_MINTER_INPUT
  } = options

  const documentEngine = await deployDocumentEngine()
  const upgradeableFactory = await ethers.getContractFactory('CMTAT721Upgradeable')
  const token = await upgrades.deployProxy(
    upgradeableFactory,
    [
      admin,
      buildERC721Attributes(name, symbol),
      buildExtraInfo(),
      await documentEngine.getAddress(),
      ruleEngine,
      tokenIdEngine,
      mode
    ],
    {
      kind: 'uups',
      initializer: 'initializeWithERC721Attributes',
      unsafeAllow: ['constructor', 'missing-initializer', 'missing-initializer-call']
    }
  )
  await token.waitForDeployment()

  return { token, documentEngine }
}

async function deployRuleEngine() {
  const ruleEngineFactory = await ethers.getContractFactory('RuleEngine721Mock')
  const ruleEngine = await ruleEngineFactory.deploy()
  await ruleEngine.waitForDeployment()
  return ruleEngine
}

async function deployTokenIdEngine(tokenId) {
  const tokenIdEngineFactory = await ethers.getContractFactory('TokenIdEngineMock')
  const tokenIdEngine = await tokenIdEngineFactory.deploy(tokenId)
  await tokenIdEngine.waitForDeployment()
  return tokenIdEngine
}

async function deployInitHarness() {
  const harnessFactory = await ethers.getContractFactory('CMTAT721InitHarness')
  const harness = await harnessFactory.deploy()
  await harness.waitForDeployment()
  return harness
}

module.exports = {
  EMPTY_BYTES,
  MODE_MINTER_INPUT,
  MODE_USER_INPUT,
  buildERC721Attributes,
  buildExtraInfo,
  fixture,
  loadFixture,
  deployDocumentEngine,
  deployCMTAT721Standalone,
  deployCMTAT721StandaloneWithERC721Attributes,
  deployCMTAT721UUPSProxy,
  deployCMTAT721UUPSProxyWithERC721Attributes,
  deployRuleEngine,
  deployTokenIdEngine,
  deployInitHarness
}

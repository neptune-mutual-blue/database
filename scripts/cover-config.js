// @ts-check

import path from 'path'
import { fileURLToPath } from 'url'

import { utils, initialize } from '@neptunemutual/sdk'
import { ethers } from 'ethers'
import { saveToDiskRaw } from '../src/util/io.js'

const __dirname = fileURLToPath(new URL('.', import.meta.url))

const covers = [
  // obtained using SELECT chain_id, cover_key FROM cover.cover_created
  // on both mainnet and testnet
  { chainId: 42161, coverKey: '0x7072696d65000000000000000000000000000000000000000000000000000000' },
  { chainId: 42161, coverKey: '0x62696e616e636500000000000000000000000000000000000000000000000000' },
  { chainId: 42161, coverKey: '0x6f6b780000000000000000000000000000000000000000000000000000000000' },
  { chainId: 42161, coverKey: '0x706f70756c61722d646566692d61707073000000000000000000000000000000' },
  { chainId: 1, coverKey: '0x7072696d65000000000000000000000000000000000000000000000000000000' },
  { chainId: 1, coverKey: '0x62696e616e636500000000000000000000000000000000000000000000000000' },
  { chainId: 1, coverKey: '0x6f6b780000000000000000000000000000000000000000000000000000000000' },
  { chainId: 1, coverKey: '0x706f70756c61722d646566692d61707073000000000000000000000000000000' },
  { chainId: 56, coverKey: '0x706f70756c61722d646566692d61707073000000000000000000000000000000' },
  { chainId: 56, coverKey: '0x62696e616e636500000000000000000000000000000000000000000000000000' },
  { chainId: 80001, coverKey: '0x6465666900000000000000000000000000000000000000000000000000000000' },
  { chainId: 80001, coverKey: '0x7072696d65000000000000000000000000000000000000000000000000000000' },
  { chainId: 80001, coverKey: '0x62696e616e636500000000000000000000000000000000000000000000000000' },
  { chainId: 80001, coverKey: '0x636f696e62617365000000000000000000000000000000000000000000000000' },
  { chainId: 80001, coverKey: '0x68756f6269000000000000000000000000000000000000000000000000000000' },
  { chainId: 80001, coverKey: '0x6f6b780000000000000000000000000000000000000000000000000000000000' },
  { chainId: 80001, coverKey: '0x61746c6173737761702d76310000000000000000000000000000000000000000' }
]

const rpcs = {
  1: 'https://ethereum.publicnode.com',
  42161: 'https://arb1.arbitrum.io/rpc',
  56: 'https://bsc-dataseed.bnbchain.org',
  80001: 'https://rpc-mumbai.maticvigil.com'
}
// const rpcs = {
//   "1": "https://eth.llamarpc.com",
//   "42161": "https://arbitrum.llamarpc.com",
//   "56": "https://binance.llamarpc.com",
//   "80001": "https://polygon.llamarpc.com",
// }

initialize({
  store: {
    1: '0x6579dF8f986e4A982F200DAfa0c1b955A438f620',
    56: '0x6579dF8f986e4A982F200DAfa0c1b955A438f620',
    42161: '0x6579dF8f986e4A982F200DAfa0c1b955A438f620',
    80001: '0xBDD990Cf47c7938346e67240471cf8D40693C360'
  }
})

const selectStatements = []
let maxValueLengthTillNow = 0

const getSelectStatement = async (chainId, coverKey) => {
  const rpc = rpcs[chainId]
  const provider = new ethers.providers.JsonRpcProvider(rpc)

  console.log('Fetching', chainId, coverKey)

  const data = await utils.store.readStorage(chainId, [
    {
      returns: 'bool',
      property: 'isValidCover',
      fn: 'getBool',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER, coverKey]
        )
      ]
    },
    {
      returns: 'bool',
      property: 'supportsProducts',
      fn: 'getBool',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_SUPPORTS_PRODUCTS, coverKey]
        )
      ]
    },
    {
      returns: 'bool',
      property: 'requiresWhitelist',
      fn: 'getBool',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_REQUIRES_WHITELIST, coverKey]
        )
      ]
    },
    {
      returns: 'address',
      property: 'coverCreator',
      fn: 'getAddress',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_OWNER, coverKey]
        )
      ]
    },
    {
      returns: 'string',
      property: 'coverInfo',
      fn: 'getString',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_INFO, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'reassuranceWeight',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_REASSURANCE_WEIGHT, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'coverCreationFee',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_CREATION_FEE_EARNING, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'coverCreationDate',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_CREATION_DATE, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'minimum_first_reporting_stake',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.GOVERNANCE_REPORTING_MIN_FIRST_STAKE, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'global_coverage_lag',
      fn: 'getUint',
      args: [utils.keyUtil.PROTOCOL.NS.COVERAGE_LAG]
    },
    {
      returns: 'uint256',
      property: 'coverage_lag',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVERAGE_LAG, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'reporting_period',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.GOVERNANCE_REPORTING_PERIOD, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'cooldownPeriod',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.RESOLUTION_COOL_DOWN_PERIOD, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'claim_period',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.CLAIM_PERIOD, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'policy_floor',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_POLICY_RATE_FLOOR, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'policy_ceiling',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_POLICY_RATE_CEILING, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'reassuranceRate',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_REASSURANCE_RATE, coverKey]
        )
      ]
    },
    {
      returns: 'uint256',
      property: 'leverageFactor',
      fn: 'getUint',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_LEVERAGE_FACTOR, coverKey]
        )
      ]
    },
    {
      returns: 'string',
      property: 'products',
      fn: 'getBytes32Array',
      args: [
        ethers.utils.solidityKeccak256(
          ['bytes32', 'bytes32'],
          [utils.keyUtil.PROTOCOL.NS.COVER_PRODUCT, coverKey]
        )
      ]
    }
  ], provider)

  // list of products
  // console.log(data.products);

  const values = [
    { columnName: 'chain_id', value: chainId },
    {
      columnName: 'cover_key',
      value: `string_to_bytes32('${ethers.utils.parseBytes32String(
        coverKey
      )}')`
    },
    { columnName: 'leverage', value: data.leverageFactor.toNumber() },
    { columnName: 'policy_floor', value: data.policy_floor.toNumber() },
    { columnName: 'policy_ceiling', value: data.policy_ceiling.toNumber() },
    { columnName: 'reporting_period', value: data.reporting_period.toNumber() },
    {
      columnName: 'coverage_lag',
      value:
        data.coverage_lag.toNumber() > 0
          ? data.coverage_lag.toNumber()
          : data.global_coverage_lag.toNumber() > 0
            ? data.global_coverage_lag.toNumber()
            : 24 * 60 * 60
    },
    {
      columnName: 'minimum_first_reporting_stake',
      value: data.minimum_first_reporting_stake.toString()
    }
  ]

  const maxValueLength = values.map(x => String(x.value).length + 2).reduce((prev, len) => len > prev ? len : prev, 0)
  const maxLengthToUse = maxValueLengthTillNow > maxValueLength ? maxValueLengthTillNow : maxValueLength
  maxValueLengthTillNow = maxLengthToUse

  const query = [
    'SELECT',
    values.map(val => `  ${String(val.value).padEnd(maxLengthToUse, ' ')} AS ${val.columnName}`).join(',\n')
  ]

  return query.join('\n')
}

export async function updateCoverConfigView () {
  for (let i = 0; i < covers.length; i++) {
    const { coverKey, chainId } = covers[i]
    try {
      const st = await getSelectStatement(chainId, coverKey)
      selectStatements.push(st)
    } catch (error) {
      console.error('Error: %s %s', chainId, coverKey, error)
    }
  }

  const content =
`DROP VIEW IF EXISTS config_cover_view CASCADE;

CREATE VIEW config_cover_view
AS
${selectStatements.join('\nUNION ALL\n')};\n`

  saveToDiskRaw(path.resolve(__dirname, '../sql/base/000-config/0.config_cover_view.sql'), content)
  saveToDiskRaw(path.resolve(__dirname, '../sql/base/001-config/0.config_cover_view.sql'), content)
}

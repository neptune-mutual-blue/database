// @ts-check

import path from 'path'
import { fileURLToPath } from 'url'

import { saveToDiskRaw } from '../src/util/io.js'

const __dirname = fileURLToPath(new URL('.', import.meta.url))

// WITH result
// AS
// (
//   SELECT info FROM cover.cover_created UNION ALL
//   SELECT info FROM cover.product_created UNION ALL
//   SELECT info FROM cover.product_updated UNION ALL
//   SELECT info FROM cover.cover_updated UNION ALL
//   SELECT info FROM consensus.reported UNION ALL
//   SELECT info FROM ve.liquidity_gauge_pool_initialized UNION ALL
//   SELECT info FROM ve.liquidity_gauge_pool_set UNION ALL
//   SELECT info FROM consensus.disputed
// )
// SELECT DISTINCT info
// FROM result
// ORDER BY info;

const hashes = [
  'QmaADrtP13cZKwz5pdipXhU5F8WWXenBTZrUFp2MK4yVf2',
  'Qmac3pwFj4YirygAdqhEiyezzb5TUQFNCsD43R6ETo67ZV',
  'QmagNBTagrbtG9EZhNFPXPiRAL1Cfq2cyT3WCzrqaJStt1',
  'QmaiakyFf99GsvJ3aD4JTPBmMhbVCjmdiCA6UqMyv2GuTp',
  'QmaKba8ZJdvVHTxXDD8ycajgzXwG1zSbGHD5fvnhHyyHJx',
  'Qmb8DRD8qE1irpj9YHTdkNks5BhLGyE1h8T86amhef77re',
  'Qmbije1EuhbETvUqcA1WR5Gt8QNrmwVM2diE5utX4LoLbX',
  'QmbQNn4ZstkW6aeaVeZ4DnBqx3Cg7pvoopsERFVmW9pwEB',
  'Qmbuk5Bz1WFL7N3fPiPeofXrjdTH9owa97QXVstDrCYg8v',
  'QmcFbX3fHrnjLqtJbMLMJk2njFga6RPq2SysG3owZF6ziY',
  'QmcGnscy5Mfdu6sc8sLWdHTMgjEuXS5rMZbc3MzWEV3yJq',
  'QmchsMM8GzKQUain63VW2shmZu319E3wFcs4uosGhDq3rM',
  'QmcK1pTGGqa7RHwxZtid5EL6ncSXR8Trnbc7yDCuC8vj1H',
  'QmctEE6U5BS63FvkU6QD8eSR91K1g7G6owRoKfLYLG61zo',
  'QmcTj2zcuHRfxx2HKiVMumy35SCiYHiJD6Xe14rKNjuGe4',
  'QmcyCnFeKwM7mnvz4w3x7cvcjJ1HD9uHGrTv8bdZWc1rDi',
  'Qmd8p5a5eUXFF9XofGCi9EWD8dnQayfPfANfRB4vGUtXqt',
  'QmdDBBpGVParKgMGYTYzPs6edjcogByjJhRJ77guvUEukP',
  'QmdpPqKV1QVxjq21FHa4UP7Hn4urWAK23BWaYxyWoLvUkP',
  'QmdVzaJvHjZ9aqkV86cbJH2zihhME8MF22QegZm8C3r7qc',
  'QmdYHrqdRPAwBg32HCYMiG5RtdJ4Gb71igoGUrHfDzVeqq',
  'Qme5v1qf7tBZWASYpBMBzQ3shB61KXJwAKrDEuFcyrjSAn',
  'Qme8nonYp95gD5e7K7VFP1SdaR82v8vTHVPKjbZ9gjRtVX',
  'Qmeu6eZfyQt25bW6JWWqwWPVBGythbBnFZEFytwY23iRgc',
  'QmeUY4Lo9VuRL2Fr5aftCv21rLGbuDMB8tg7LkiTpUeaKX',
  'QmfD3Pp6tockqnhzzDLT1TDiZJZ7B4o56QY6aSepYGduDP',
  'QmfDdLWy3DdY5GAqnWJ8VoXD24Uv9AAssQeHrrnk6uu1Ve',
  'QmfEViRmvDaE8GaGWrgEjkAHsTx9Dmcsiwtu2TTYfi8M9Y',
  'QmNcZcTr28zvyHMWjBoumzUq5E6HqnLujVcYADiMBpMUgw',
  'QmNkoMt274zKMXFz5cKzNUNvfXNFpBgm3nZTTFKA47wmDu',
  'QmNrtsqPhdDwNZwsxyjPjgFzD1XM2VvLPhEiTMu9uiikXM',
  'QmNTWRJnb1Luk4PwbqGZ3XY78bGRHeU7vw95HqmoySDnQa',
  'QmP4BGgYVb8ZQyLDeAfk8oyszCRo2BPcqUYfh6uCeZDAMz',
  'QmPabWcVa6t6tDjjTo6zneeaaub4EfoCnbNCkqFaX3LFKE',
  'QmPEPkdEWPhfoQtX1XuFAerpZLDVtbbCYgiFiioMvHLwuo',
  'QmPiKWDUPVUJuW7bpqVpXRUyeC1rr3HNu9cUFrCE114BSB',
  'QmPiUWSq5P3JAChY4so6R7kQy33bVghBaS5dWNmg3ZQ5Ew',
  'QmPJHouJz6vx1JWX4ZG93CSLTp9wuM1JS6cQJz7tzsE4fd',
  'QmPmBngN7neCy2ZGJyvu64drGscBjptF4x1QNWgRQiZCuF',
  'QmPoihzcsB7P1gjFmm8XQKt7ydnNnLgiWhjWnjaMJnHhiQ',
  'QmPUaeCC6Di4SEz8jJApvrqeThUchCXXBgBZ4EHbWFzcyv',
  'QmPuZBJ4CDXs71KmQaUtBLWTLHD4kWBH9N79mGgoZXkQNK',
  'QmQVtftRbnz7imWHAkc1q8jiZbRMDeB5kkiXXf8swWQf61',
  'QmQY5QPMmz2kizsV6WDZC5pzMsHF9rVFJyWLS5irTRyF9T',
  'QmRmw7C2sHCLraMjByQec9xN7PXf3kTafdsc7gpTw7BrYa',
  'QmS5qnWfiHLkGhr78yyTBaa671x5M6TkpFHvVUyUR2mXjC',
  'QmSFTdPE2EhHECWk17WwjWKRCXdEDGjxLPYKzUwCfK5Rz8',
  'QmSHNAZysPGjv81FEE9RRY1WVhPp7cpGNxv4GpjRb5keT4',
  'QmT6ukCFSBUPrP61Dz1i6Z71u3xRSWtRvQZR6FEfmPhnCA',
  'QmTGMmPURT6opok7qJUjSGtibVTvpPGcrd9gUdV2ucMpUn',
  'QmThidT7SXTdi6a4LkszZfWgAhVPc8x7ub6fbsMuL3S23R',
  'QmTwXYSsMjEZFCCcsJx7JS89Rs4gezQvgqEhf7rb7tm3z1',
  'QmUsRg5QKE7sAtJwchZdiVKXpaXAv98xpwsNxPbvhUYQJf',
  'QmVSGRGf2xrCN9U76G8S7BN9bhZbi74wX9gkDnujCixasS',
  'QmVUkJHNaFbHnULoVGscDAiW7P5WhLfRSXuxCxB73537Kf',
  'QmVVwLMVUvTYTCkLXWrGSYz2eegpcjfcfeD9ebCHkSS84G',
  'QmW1bzN7xkWX5jkoZLUskeBGdzmE7VC2v59kpXhTX22fn6',
  'QmWBQG45NLNiWoQYFA2RYs6fF8PQiQG8E9Xd5kgHY8jReg',
  'QmWC9UhJVSX3C5xCVNJSMqev3cSTB4pyeqMS3BLkVsRZQn',
  'QmWcy6Vhi85gDXBEDzSSQMhV8md1T6e9tEZnxemgdBf26B',
  'QmWJjgxNEJ1Ue3mHqGeiaHn91EDJW4JBaKsvFhdCHHsWBK',
  'QmWRdPnZKhxhPfd5rqK4FwvbQ7uCd1q6JWuk9v4h9WTrFX',
  'QmX5ssdLHSpsQwu3YVGbS1CTUZG2XVgTXxyKVC2Fcyf8Rr',
  'QmXFX5NCii3nwPtVw5Ax7q73JeTS5oZnpqGPCnz33TGC2Y',
  'QmXfy1Az9Y2FKXKDVkHgc3ThfLLQUatP5qQGbeqgQrfZ6B',
  'QmXPkuacaiXrh9aUdiMybBmTjJbZjSEgqq7CnetQuTywVG',
  'QmYHbEJEQek15WwiC283ihf1RCpcfTQeqGXHkTstWA7o3y',
  'QmYvtFvKNFM8ZhfiHGyPnWYq5rsqjcRgjJixFK2w1RytNt',
  'QmYyjCcdjmRAB21EjAVPBWe2GAuNWGeMa9M7L23DzQ3f3y',
  'QmYzbk1mWWodnUtCZ8uUwMuLosDXuoMjKpKBECf9D8UF4t',
  'QmZ9cjxk8ye3qui8JEgPjxDaFF48CbxNswtCfBMTLKnaj6',
  'QmZXDq4Cn9ZnEGhm68UN7HLpuxduesH5cx6QrhWuRccJLY'
]

const selectStatements = []

const getIpfsDetails = async (hash, i) => {
  console.log('Fetching', hash)
  const res = await fetch(`https://ipfs.neptunemutual.net/ipfs/${hash}`)
  const result = await res.json()
  const text = JSON.stringify(result).replace("'", "''")

  if (i === 0) {
    return `SELECT '${hash}' AS ipfs_hash, '${text}' AS ipfs_details`
  }

  return `SELECT '${hash}', '${text}'`
}

export async function updateIpfsConfigView () {
  const sorted = Array.from(new Set(hashes)).sort((a, b) => a.localeCompare(b))

  for (let i = 0; i < sorted.length; i++) {
    const hash = sorted[i]

    try {
      const st = await getIpfsDetails(hash, i)

      if (!st) {
        console.error(Error('Invalid hash'))
        continue
      }
      selectStatements.push(st)
    } catch (error) {
      console.error('Error: %s %s', hash, error)
    }
  }

  const content = (
`CREATE OR REPLACE VIEW config_known_ipfs_hashes_view
AS
${selectStatements.join(' UNION ALL\n')};\n`
  )

  saveToDiskRaw(path.resolve(__dirname, '../sql/base/000-config/0.config_known_ipfs_view.sql'), content)
  saveToDiskRaw(path.resolve(__dirname, '../sql/base/001-config/0.config_known_ipfs_view.sql'), content)
}

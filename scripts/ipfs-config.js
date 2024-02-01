// @ts-check

import path from 'path'
import { fileURLToPath } from 'url'

import { saveToDiskRaw } from '../src/util/io.js'

const __dirname = fileURLToPath(new URL('.', import.meta.url))

const hashes = [
  'QmeUY4Lo9VuRL2Fr5aftCv21rLGbuDMB8tg7LkiTpUeaKX',
  'QmVUkJHNaFbHnULoVGscDAiW7P5WhLfRSXuxCxB73537Kf',
  'QmXFX5NCii3nwPtVw5Ax7q73JeTS5oZnpqGPCnz33TGC2Y',
  'QmNTWRJnb1Luk4PwbqGZ3XY78bGRHeU7vw95HqmoySDnQa',
  'QmRmw7C2sHCLraMjByQec9xN7PXf3kTafdsc7gpTw7BrYa',
  'QmdpPqKV1QVxjq21FHa4UP7Hn4urWAK23BWaYxyWoLvUkP',
  'QmPiKWDUPVUJuW7bpqVpXRUyeC1rr3HNu9cUFrCE114BSB',
  'QmTwXYSsMjEZFCCcsJx7JS89Rs4gezQvgqEhf7rb7tm3z1',
  'QmcyCnFeKwM7mnvz4w3x7cvcjJ1HD9uHGrTv8bdZWc1rDi',
  'QmPJHouJz6vx1JWX4ZG93CSLTp9wuM1JS6cQJz7tzsE4fd',
  'QmQY5QPMmz2kizsV6WDZC5pzMsHF9rVFJyWLS5irTRyF9T',
  'Qme5v1qf7tBZWASYpBMBzQ3shB61KXJwAKrDEuFcyrjSAn',
  'Qmbuk5Bz1WFL7N3fPiPeofXrjdTH9owa97QXVstDrCYg8v',
  'QmfD3Pp6tockqnhzzDLT1TDiZJZ7B4o56QY6aSepYGduDP',
  'QmWBQG45NLNiWoQYFA2RYs6fF8PQiQG8E9Xd5kgHY8jReg',
  'QmXPkuacaiXrh9aUdiMybBmTjJbZjSEgqq7CnetQuTywVG',
  'QmPEPkdEWPhfoQtX1XuFAerpZLDVtbbCYgiFiioMvHLwuo',
  'QmYyjCcdjmRAB21EjAVPBWe2GAuNWGeMa9M7L23DzQ3f3y',
  'QmaKba8ZJdvVHTxXDD8ycajgzXwG1zSbGHD5fvnhHyyHJx',
  'QmT6ukCFSBUPrP61Dz1i6Z71u3xRSWtRvQZR6FEfmPhnCA',
  'QmP4BGgYVb8ZQyLDeAfk8oyszCRo2BPcqUYfh6uCeZDAMz',
  'Qme8nonYp95gD5e7K7VFP1SdaR82v8vTHVPKjbZ9gjRtVX',
  'QmctEE6U5BS63FvkU6QD8eSR91K1g7G6owRoKfLYLG61zo',
  'QmVSGRGf2xrCN9U76G8S7BN9bhZbi74wX9gkDnujCixasS',
  'QmTGMmPURT6opok7qJUjSGtibVTvpPGcrd9gUdV2ucMpUn',
  'QmNkoMt274zKMXFz5cKzNUNvfXNFpBgm3nZTTFKA47wmDu',
  'QmcGnscy5Mfdu6sc8sLWdHTMgjEuXS5rMZbc3MzWEV3yJq',
  'QmWJjgxNEJ1Ue3mHqGeiaHn91EDJW4JBaKsvFhdCHHsWBK',
  'Qmeu6eZfyQt25bW6JWWqwWPVBGythbBnFZEFytwY23iRgc',
  'QmcTj2zcuHRfxx2HKiVMumy35SCiYHiJD6Xe14rKNjuGe4',
  'QmPuZBJ4CDXs71KmQaUtBLWTLHD4kWBH9N79mGgoZXkQNK',
  'QmYzbk1mWWodnUtCZ8uUwMuLosDXuoMjKpKBECf9D8UF4t',
  'QmfEViRmvDaE8GaGWrgEjkAHsTx9Dmcsiwtu2TTYfi8M9Y',
  'QmPiUWSq5P3JAChY4so6R7kQy33bVghBaS5dWNmg3ZQ5Ew',
  'QmNrtsqPhdDwNZwsxyjPjgFzD1XM2VvLPhEiTMu9uiikXM',
  'QmPoihzcsB7P1gjFmm8XQKt7ydnNnLgiWhjWnjaMJnHhiQ',
  'QmcFbX3fHrnjLqtJbMLMJk2njFga6RPq2SysG3owZF6ziY',
  'QmThidT7SXTdi6a4LkszZfWgAhVPc8x7ub6fbsMuL3S23R',
  'QmchsMM8GzKQUain63VW2shmZu319E3wFcs4uosGhDq3rM',
  'QmfDdLWy3DdY5GAqnWJ8VoXD24Uv9AAssQeHrrnk6uu1Ve',
  'QmXfy1Az9Y2FKXKDVkHgc3ThfLLQUatP5qQGbeqgQrfZ6B',
  'Qmac3pwFj4YirygAdqhEiyezzb5TUQFNCsD43R6ETo67ZV',
  'QmYHbEJEQek15WwiC283ihf1RCpcfTQeqGXHkTstWA7o3y',
  'QmdVzaJvHjZ9aqkV86cbJH2zihhME8MF22QegZm8C3r7qc',
  'QmcK1pTGGqa7RHwxZtid5EL6ncSXR8Trnbc7yDCuC8vj1H',
  'QmaiakyFf99GsvJ3aD4JTPBmMhbVCjmdiCA6UqMyv2GuTp',
  'QmSFTdPE2EhHECWk17WwjWKRCXdEDGjxLPYKzUwCfK5Rz8',
  'Qmb8DRD8qE1irpj9YHTdkNks5BhLGyE1h8T86amhef77re',
  'QmSHNAZysPGjv81FEE9RRY1WVhPp7cpGNxv4GpjRb5keT4',
  'QmZXDq4Cn9ZnEGhm68UN7HLpuxduesH5cx6QrhWuRccJLY',
  'QmdYHrqdRPAwBg32HCYMiG5RtdJ4Gb71igoGUrHfDzVeqq',
  'QmYvtFvKNFM8ZhfiHGyPnWYq5rsqjcRgjJixFK2w1RytNt',
  'QmbQNn4ZstkW6aeaVeZ4DnBqx3Cg7pvoopsERFVmW9pwEB',
  'QmW1bzN7xkWX5jkoZLUskeBGdzmE7VC2v59kpXhTX22fn6',
  'Qmd8p5a5eUXFF9XofGCi9EWD8dnQayfPfANfRB4vGUtXqt',
  'QmZ9cjxk8ye3qui8JEgPjxDaFF48CbxNswtCfBMTLKnaj6',
  'QmUsRg5QKE7sAtJwchZdiVKXpaXAv98xpwsNxPbvhUYQJf',
  'QmWcy6Vhi85gDXBEDzSSQMhV8md1T6e9tEZnxemgdBf26B',
  'QmWRdPnZKhxhPfd5rqK4FwvbQ7uCd1q6JWuk9v4h9WTrFX',
  'QmS5qnWfiHLkGhr78yyTBaa671x5M6TkpFHvVUyUR2mXjC',
  'QmWC9UhJVSX3C5xCVNJSMqev3cSTB4pyeqMS3BLkVsRZQn',
  'QmPmBngN7neCy2ZGJyvu64drGscBjptF4x1QNWgRQiZCuF',
  'QmagNBTagrbtG9EZhNFPXPiRAL1Cfq2cyT3WCzrqaJStt1',
  'Qmbije1EuhbETvUqcA1WR5Gt8QNrmwVM2diE5utX4LoLbX',
  'QmQVtftRbnz7imWHAkc1q8jiZbRMDeB5kkiXXf8swWQf61'
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
`DROP VIEW IF EXISTS config_known_ipfs_hashes_view CASCADE;

CREATE VIEW config_known_ipfs_hashes_view
AS
${selectStatements.join(' UNION ALL\n')};\n`
  )

  saveToDiskRaw(path.resolve(__dirname, '../sql/base/000-config/0.config_known_ipfs_view.sql'), content)
  saveToDiskRaw(path.resolve(__dirname, '../sql/base/001-config/0.config_known_ipfs_view.sql'), content)
}

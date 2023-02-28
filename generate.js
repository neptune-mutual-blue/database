import path from 'path'

import {
  findFiles,
  readFile,
  saveToDiskRaw
} from './src/util/io'

const getType = () => {
  const last = process.argv.pop() ?? ''

  if (!last.startsWith('--type')) {
    return 'sql'
  }

  const type = last.split('=').pop()
  console.log(type)
  return type
}

const main = async () => {
  const type = getType()
  const destination = path.join(process.cwd(), 'build', `${type}.sql`)

  try {
    const root = path.join(process.cwd(), 'sql', type)
    const files = await findFiles('sql', root)
    const sql = []

    for (const file of files) {
      const contents = await readFile(file)
      sql.push(contents)
    }

    await saveToDiskRaw(destination, sql.join('\n'))
    console.log('Done', destination)
  } catch (error) {
    console.error(error)
  }
}

main().catch(console.error)

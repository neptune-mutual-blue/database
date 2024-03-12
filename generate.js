import { exec } from 'child_process'
import path from 'path'
import { promisify } from 'util'

import {
  findFiles,
  readFile,
  saveToDiskRaw
} from './src/util/io.js'

const execAsync = promisify(exec)

const getArgument = (argumentName, fallbackValue) => {
  const argument = process.argv.find((arg) => arg.startsWith(`--${argumentName}`))

  if (!argument) {
    return fallbackValue
  }

  const argumentValue = argument.split('=').pop()
  return argumentValue
}

const buildSQLFile = async (type) => {
  console.log('Building', type)

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

const concatenateFiles = (types, name) => {
  const outputFileName = `build/${name}.sql`

  console.log('Building concatenated file:', outputFileName)

  const command = `cat sql/rds.sql sql/rds.nft.sql ${types.map((type) => `build/${type}.sql`).join(' ')} > ${outputFileName}`

  const { stderr } = execAsync(command)

  if (stderr) {
    throw new Error(stderr)
  }

  console.log('Done', outputFileName)
}

const main = async () => {
  const type = getArgument('type')
  const name = getArgument('name')

  if (!type) {
    throw new Error('Missing --type argument')
  }

  const types = type.split(',').map((t) => t.trim())

  if (types.length === 1 && name) {
    throw new Error('Cannot use --name with single type')
  }

  if (types.length > 1 && !name) {
    throw new Error('Must use --name with multiple types')
  }

  for (const type of types) {
    await buildSQLFile(type)
  }

  if (name) {
    await concatenateFiles(types, name)
  }
}

main().catch(console.error)

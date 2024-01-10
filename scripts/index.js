import { updateCoverConfigView } from './cover-config.js'
import { updateProductConfigView } from './product-config.js'

async function main () {
  await updateCoverConfigView()
  await updateProductConfigView()
}

main()

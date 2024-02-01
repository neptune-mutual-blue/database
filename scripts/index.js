import { updateCoverConfigView } from './cover-config.js'
import { updateIpfsConfigView } from './ipfs-config.js'
import { updateProductConfigView } from './product-config.js'

async function main () {
  await updateIpfsConfigView()
  await updateCoverConfigView()
  await updateProductConfigView()
}

main()

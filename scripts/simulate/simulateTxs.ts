require('dotenv').config()
import { runTenderlySimulation } from '../../hardhat/utils/tenderly'

// Dummy TX data
const dummyTx = {
  to: '0x0000000000000000000000000000000000000000',
  data: '0x',
}

async function script() {
  const tx = {
    from: '0x6c905b4108A87499CEd1E0498721F2B831c6Ab13',
    to: dummyTx.to,
    input: dummyTx.data,
    gas_price: 5e9,
    gas: 80e6,
  }
  const config = {
    network_id: '56',
    save: true,
    simulation_type: 'quick' as 'quick' | 'full',
  }
  const simulation = await runTenderlySimulation(tx, config)

  console.dir({ simulation }, { depth: 5 })
}

;(async function () {
  try {
    await script()
    console.log('🎉')
    process.exit(0)
  } catch (e) {
    console.error('Error running script.')
    console.dir(e)
    process.exit(1)
  }
})()

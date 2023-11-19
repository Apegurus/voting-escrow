import axios from 'axios'

export interface SimulationConfig {
  save?: boolean
  save_if_fails?: boolean
  simulation_type?: 'quick' | 'full'
  network_id: string | number
}

export interface TenderlyEVMTransaction {
  from: string
  to: string
  input: string
  gas?: number
  gas_price: number
  value?: number
}

export async function runTenderlySimulation(
  transaction: TenderlyEVMTransaction,
  config: SimulationConfig
): Promise<void> {
  const { TENDERLY_USER, TENDERLY_PROJECT, TENDERLY_ACCESS_KEY } = process.env
  if (!TENDERLY_USER || !TENDERLY_PROJECT || !TENDERLY_ACCESS_KEY) {
    throw new Error(
      'runTenderlySimulation: Missing one or more of TENDERLY_USER, TENDERLY_PROJECT or TENDERLY_ACCESS_KEY'
    )
  }

  try {
    const resp = await axios.post(
      `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/simulate`,
      // the transaction
      {
        /* Simulation Configuration */
        save: false, // if true simulation is saved and shows up in the dashboard
        save_if_fails: false, // if true, reverting simulations show up in the dashboard
        simulation_type: 'quick', // full or quick (full is default)
        ...config, // Overwrite the defaults above

        /* Standard EVM Transaction object */
        gas: 8000000,
        //   gas_price: 0,
        value: 0,
        ...transaction,
      },
      {
        headers: {
          'X-Access-Key': TENDERLY_ACCESS_KEY as string,
        },
      }
    )

    const transactionResult = resp.data.transaction
    console.log(JSON.stringify(transactionResult, null, 2))
  } catch (error: any) {
    console.error('Error running simulation:')
    console.dir(error.response.data, { depth: 5 })
  }
}

import * as readline from 'readline'

const printOptions = (options: string[], selectedIndex: number) => {
  console.log('\n')
  options.forEach((option, index) => {
    if (index === selectedIndex) {
      console.log(`${index}. > ${option}`)
    } else {
      console.log(`${index}.   ${option}`)
    }
  })
  console.log('\nEnter a number or use arrow keys:')
}

export const arrowKeyPrompt = async (message: string, options: string[]): Promise<string> => {
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: true,
    })

    let selectedIndex = 0

    console.log(`${message}`)
    printOptions(options, selectedIndex)

    const onKeyPress = (str: string, key: readline.Key) => {
      if (key.name === 'up' && selectedIndex > 0) {
        selectedIndex--
      } else if (key.name === 'down' && selectedIndex < options.length - 1) {
        selectedIndex++
      } else if (key.name === 'return') {
        rl.close()
        resolve(options[selectedIndex])
        return
      } else {
        return
      }

      readline.cursorTo(process.stdout, 0)
      readline.moveCursor(process.stdout, 0, -options.length - 1)
      readline.clearScreenDown(process.stdout)

      printOptions(options, selectedIndex)
    }

    const onLine = (input: string) => {
      const choice = parseInt(input, 10)
      if (choice >= 0 && choice <= options.length) {
        selectedIndex = choice
        rl.close()
        resolve(options[selectedIndex])
      } else {
        console.log('Invalid choice. Please try again.')
      }
    }

    process.stdin.on('keypress', onKeyPress)
    rl.on('line', onLine)
    rl.on('close', () => {
      process.stdin.removeListener('keypress', onKeyPress)
    })
  })
}

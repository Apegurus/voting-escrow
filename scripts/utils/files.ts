import fs from 'fs'
import path from 'path'

/**
 * Function to get the current date as a string in the format YYYYMMDD.
 * This is used for generating unique file names for deployment scripts.
 *
 * @returns {string} The current date as a string in the format YYYYMMDD.
 */
export const getDateString = () => new Date().toISOString().slice(0, 10).replace(/-/g, '') // e.g. 20230330

/**
 * Save a JS object to a local .ts file as an exported constant.
 *
 * @param fileName Name of the file (Do not include '.ts')
 * @param constName Name of the exported constant
 * @param data Object to write to file
 */
export const writeObjectToTsFile = async (fileName: string, constName: string, data: {}): Promise<boolean> => {
  try {
    const formattedData = `export const ${constName} = ${JSON.stringify(data, null, 2)};`
    await fs.promises.writeFile(fileName + '.ts', formattedData)
    return true
  } catch (e) {
    console.error(`${writeObjectToTsFile.name}:: Error writing ${fileName}: ${e}`)
    return false
  }
}

/**
 * Save a JS object to a local json file.
 *
 * @param fileName Name of the file (Do not include '.json')
 * @param data Object to write to file
 */
export const writeJSONToFile = async (fileName: string, data: {}): Promise<void> => {
  try {
    await fs.promises.writeFile(fileName + '.json', JSON.stringify(data, null, 4))
  } catch (e) {
    console.error(`Error writing ${fileName}: ${e}`)
  }
}

/**
 * Read a json file from local storage by providing a path, file name and file extension.
 *
 * @param filePath
 * @returns
 */
export const readJSONFile = async (filePath: string): Promise<Buffer> => {
  try {
    const buffer = await fs.promises.readFile(filePath, 'utf8')
    return JSON.parse(buffer)
  } catch (e: any) {
    throw new Error(`Error reading ${filePath}: ${e}`)
  }
}

/**
 * Searches for local files in the specified directory and returns an array of file names.
 * @param {string} dirPath - The directory path to search for files.
 * @param {string[]} fileExtensions - An array of file extensions to filter the results.
 * @returns {Promise<string[]>} A promise that resolves to an array of file names.
 */
export async function searchLocalFiles(dirPath: string, fileExtensions: string[] = ['.ts', '.js']): Promise<string[]> {
  return new Promise((resolve, reject) => {
    fs.readdir(dirPath, (error, files) => {
      if (error) {
        reject(error)
      } else {
        const filteredFiles = files.filter((file) => fileExtensions.includes(path.extname(file)))
        resolve(filteredFiles)
      }
    })
  })
}

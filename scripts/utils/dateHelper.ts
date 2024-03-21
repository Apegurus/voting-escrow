const toISOStringNoHyphens = (date: Date) => date.toISOString().replace(/-/g, '')

/**
 * Gets the current date as a string in the format YYYYMMDD.
 * This can be used for generating file names or any other date-based identifiers.
 * Example output: '20230330'
 *
 * @param {Date} date (optional) The date to convert to a string in the format YYYYMMDD. Defaults to the current date.
 * @returns {string} The current date as a string in the format YYYYMMDD.
 */
export const getDateDayString = (date = new Date()) => toISOStringNoHyphens(date).slice(0, 8)

/**
 * Gets the current date and time as a string in the format YYYYMMDDTHH:MM.
 * Useful for timestamping events to the nearest minute.
 * Example output: '202303301210' for 12:10 on March 30, 2023.
 *
 * @param {Date} date (optional) The date to convert to a string in the format YYYYMMDDTHH:MM. Defaults to the current date.
 * @returns {string} The current date and time as a string in the format YYYYMMDDTHH:MM.
 */
export const getDateMinuteString = (date = new Date()) => toISOStringNoHyphens(date).slice(0, 14)

export const getDaysAgo = (dateString: string): number => {
  const date = new Date(dateString)
  const currentDate = new Date()
  const timeDiff = currentDate.getTime() - date.getTime()
  const daysAgo = Math.floor(timeDiff / (1000 * 3600 * 24))
  return daysAgo
}

export const getUnixTimestampAndNextDay = (dateStringOrTimestamp: string | number): [number, number] => {
  let timestamp: number
  if (typeof dateStringOrTimestamp === 'string') {
    timestamp = Math.floor(new Date(dateStringOrTimestamp).getTime() / 1000)
  } else {
    timestamp = dateStringOrTimestamp
  }
  const nextDayTimestamp = timestamp + 24 * 3600 // Add 24 hours in seconds
  return [timestamp, nextDayTimestamp]
}

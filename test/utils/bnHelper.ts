import { BigNumber, BigNumberish } from 'ethers'

export function addBNStr(a: BigNumberish, b: BigNumberish) {
  return BigNumber.from(a).add(BigNumber.from(b)).toString()
}

export function subBNStr(a: BigNumberish, b: BigNumberish) {
  return BigNumber.from(a).sub(BigNumber.from(b)).toString()
}

export function mulBNStr(a: BigNumberish, b: BigNumberish) {
  return BigNumber.from(a).mul(BigNumber.from(b)).toString()
}

export function divBNStr(a: BigNumberish, b: BigNumberish) {
  return BigNumber.from(a).div(BigNumber.from(b)).toString()
}

/**
 * Pass BN object, BN, or string returned from a smart contract and convert all BN values to strings to easily read them.
 *
 * @param {*} bigNumberObject BN, Object of BNs or string
 * @returns All values are converted to a string
 */
export function formatBNValueToString(value: any) {
  if (typeof value === 'string' || typeof value == 'number' || (value as BigNumber)._isBigNumber) {
    return value.toString()
  } else if (typeof value === 'object') {
    // Functions with multiple returns can't be updated. A new object is used instead.
    const replacementValue: any = {}
    Object.keys(value).forEach((key) => {
      replacementValue[key] = formatBNValueToString(value[key])
    })
    return replacementValue
  }
  return value
}

/**
 * Check that a BN/BN String is within a percentage tolerance of another big number
 *
 * @param {*} bnToCheck BN or string of the value to check
 * @param {*} bnExpected BN or string of the value to compare against
 * @param {*} tolerancePercentage (1% = 1e4) Percentage to add/subtract from expected value to check tolerance
 * @returns boolean
 */
export function isWithinLimit(bnToCheck: BigNumberish, bnExpected: BigNumberish, tolerancePercentage = 1e4) {
  bnToCheck = BigNumber.from(bnToCheck)
  bnExpected = BigNumber.from(bnExpected)
  const tolerance = bnExpected.mul(BigNumber.from(tolerancePercentage)).div(BigNumber.from(1e6))
  let withinTolerance = true
  if (bnToCheck.gt(bnExpected.add(tolerance))) {
    console.error(
      `bnHelper::isWithinLimit - ${bnToCheck.toString()} gte upper tolerance limit of ${tolerancePercentage}% to a value of ${bnExpected
        .add(tolerance)
        .toString()}`
    )
    withinTolerance = false
  }

  if (bnToCheck.lt(bnExpected.sub(tolerance))) {
    console.error(
      `bnHelper::isWithinLimit - ${bnToCheck.toString()} lte lower tolerance limit of ${tolerancePercentage}% to a value of ${bnExpected
        .sub(tolerance)
        .toString()}`
    )
    withinTolerance = false
  }

  return withinTolerance
}

/**
 * Check that a BN/BN String is within a range of another big number.
 *
 * @param {*} bnToCheck BN or string of the value to check
 * @param {*} bnExpected BN or string of the value to compare against
 * @param {*} tolerance Wei amount within limits
 * @returns boolean
 */
export function isWithinWeiLimit(bnToCheck: BigNumberish, bnExpected: BigNumberish, tolerance = BigNumber.from(0)) {
  bnToCheck = BigNumber.from(bnToCheck)
  bnExpected = BigNumber.from(bnExpected)
  let withinTolerance = true
  if (bnToCheck.gte(bnExpected.add(tolerance))) {
    console.error(
      `bnHelper::isWithinWeiLimit - ${bnToCheck.toString()} gte upper tolerance limit of ${tolerance} wei to a value of ${bnExpected
        .add(tolerance)
        .toString()}`
    )
    withinTolerance = false
  }

  if (bnToCheck.lte(bnExpected.sub(tolerance))) {
    console.error(
      `bnHelper::isWithinWeiLimit - ${bnToCheck.toString()} lte lower tolerance limit of ${tolerance} wei to a value of ${bnExpected
        .sub(tolerance)
        .toString()}`
    )
    withinTolerance = false
  }

  return withinTolerance
}

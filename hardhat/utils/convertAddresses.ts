import { getExplorerUrlForNetwork } from '../../hardhat.config'
import { Networks } from '../networks'

export const isAddress = (address?: string) =>
  address ? (address.length === 42 && address.slice(0, 2) === '0x' ? true : false) : false

/**
 * Iterates through an object and converts any address strings to block explorer links passed
 *
 * @param {Object<any>} addressObject Object to iterate through looking for possible addresses to convert
 * @param {Networks} networkName The current hardhat network name
 * @param {boolean} detailedInfo If `true` will instead turn an address string into an object {address: string, explorer: string}
 * @returns parsedAddressObject
 */
export function convertAddressesToExplorerLinksByNetwork(
  addressObject: any,
  networkName: Networks,
  detailedInfo = false
) {
  const getExplorerLink = getExplorerUrlForNetwork(networkName)
  return convertAddressesToExplorerLinks(addressObject, getExplorerLink, detailedInfo)
}

/**
 * Iterates through an object and converts any address strings to block explorer links passed
 *
 * @param {Object<any>} addressObject Object to iterate through looking for possible addresses to convert
 * @param {(address: string) => string} getLink Function which takes an address and converts to an explorer link
 * @param {boolean} detailedInfo If `true` will instead turn an address string into an object {address: string, explorer: string}
 * @returns parsedAddressObject
 */
export function convertAddressesToExplorerLinks(
  addressObject: any,
  getLink: (address: string) => string,
  detailedInfo = false
) {
  // Using an internal function to allow for deep copying before
  function _convertAddressesToExplorerLinks(
    _addressObject: any,
    _getLink: (address: string) => string,
    _detailedInfo = false
  ) {
    Object.keys(_addressObject).forEach((key) => {
      const value = _addressObject[key]
      if (typeof value === 'string') {
        // Check if value is an address
        if (isAddress(value)) {
          if (_detailedInfo) {
            _addressObject[key] = {
              address: value,
              explorer: _getLink(value),
            }
          } else {
            _addressObject[key] = _getLink(value)
          }
        }
      } else {
        _convertAddressesToExplorerLinks(value, _getLink, _detailedInfo)
      }
    })
    return _addressObject
  }
  const addrObjDeepCopy = JSON.parse(JSON.stringify(addressObject))
  return _convertAddressesToExplorerLinks(addrObjDeepCopy, getLink, detailedInfo)
}

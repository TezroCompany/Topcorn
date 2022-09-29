// @ts-ignore
import { BN } from "@openzeppelin/test-helpers"

export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
export const MAX_UINT256 = new BN("2").pow(new BN("256")).subn(1).toString()
export const MAX_UINT32 = new BN("2").pow(new BN("32")).subn(1).toString()
export const MIN_PLENTY_BASE = new BN("10").pow(new BN("20")).toString()
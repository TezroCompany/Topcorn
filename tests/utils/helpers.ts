import { ethers } from "hardhat"

var JSONbig = require("json-bigint")
import fs from "fs"

function parseJson(file: string) {
    var jsonString = fs.readFileSync(file)
    const data = JSONbig.parse(jsonString)
    return [data["columns"], data["data"]]
}

async function incrementTime(t = 86400) {
    // @ts-ignore
    await ethers.provider.send("evm_mine")
    await ethers.provider.send("evm_increaseTime", [t])
    // @ts-ignore
    await ethers.provider.send("evm_mine")
}

async function getEthSpentOnGas(result: any) {
    const receipt = await result.wait()
    return receipt.effectiveGasPrice.mul(receipt.cumulativeGasUsed)
}

function toTopcorn(amount: string) {
    return ethers.utils.parseUnits(amount, 18)
}

function toEther(amount: string) {
    return ethers.utils.parseEther(amount)
}

function withoutDecimals(amount: string) {
    return ethers.utils.formatUnits(amount, 18)
}

export { toTopcorn, toEther, parseJson, getEthSpentOnGas, incrementTime, withoutDecimals }

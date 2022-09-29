import { ethers } from "hardhat"
// @ts-ignore
import { BN } from "@openzeppelin/test-helpers"

import { expect } from "chai"
import { deploy } from "../scripts/deploy"
import { parseJson } from "./utils/helpers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers.js"

let user: SignerWithAddress, user2: SignerWithAddress, owner: SignerWithAddress
let userAddress: string, ownerAddress: string, user2Address: string

// Set the test data
const [columns, tests] = parseJson("./tests/coverage_data/sun.json") as [string[], string[][]]
var numberTests = tests.length
var startTest = 0

describe("Sun", function () {
    before(async function () {
        ;[owner, user, user2] = await ethers.getSigners()
        const contracts = await deploy("Test", false, true)

        userAddress = user.address
        user2Address = user2.address
        ownerAddress = contracts.account

        this.diamond = contracts.farmDiamond
        this.season = await ethers.getContractAt("MockSeasonFacet", this.diamond.address)
        this.field = await ethers.getContractAt("MockFieldFacet", this.diamond.address)
        this.silo = await ethers.getContractAt("MockSiloFacet", this.diamond.address)
        this.topcorn = await ethers.getContractAt("MockToken", contracts.topcorn)
        this.pair = await ethers.getContractAt("MockPancakeswapV2Pair", contracts.pair)
        this.pegPair = await ethers.getContractAt("MockPancakeswapV2Pair", contracts.pegPair)
    })
    ;[...Array(numberTests).keys()]
        .map((i: number) => i + startTest)
        .forEach(function (v) {
            const testStr = "Test #"
            describe(testStr.concat(v.toString()), function () {
                let testData: Record<string, any> = {}
                columns.forEach((key, i: number) => (testData[key] = tests[v][i]))
                before(async function () {
                    await this.season.resetState()
                    await this.pair.burnTokens(this.topcorn.address)
                    await this.pair.burnAllLP(this.silo.address)
                    this.testData = {}
                    columns.forEach((key, i: number) => (this.testData[key] = tests[v][i]))
                    for (var i = 0; i < this.testData.season - 1; i++) {
                        await this.season.lightSunrise()
                    }

                    await this.topcorn.mint(this.silo.address, this.testData.topcornsInSilo)
                    await this.topcorn.mint(this.pair.address, this.testData.topcornsInPool)
                    await this.silo.incrementDepositedTopcornsE(this.testData.topcornsInSilo)
                    await this.season.setSoilE(this.testData.soil)
                    await this.silo.depositSiloAssetsE(userAddress, "1", "100000")
                    await this.field.incrementTotalPodsE(
                        (parseInt(this.testData.unripenedPods) + parseInt(this.testData.harvestablePods)).toString()
                    )
                    await this.field.incrementTotalHarvestableE(this.testData.harvestablePods)
                    this.pair.simulateTrade(this.testData.topcornsInPool, this.testData.ethInPool)
                    await this.silo.incrementDepositedLPE("1")
                    this.result = await this.season.sunSunrise(this.testData.twapTopcorns, this.testData.twapUSDC, this.testData.divisor)
                })

                it("checks values", async function () {
                    expect(await this.topcorn.totalSupply()).to.eq(this.testData.newTotalSupply)
                    expect(await this.topcorn.balanceOf(this.silo.address)).to.eq(
                        (parseInt(this.testData.newTopcornsInSilo) + parseInt(this.testData.newHarvestablePods)).toString()
                    )
                    expect(await this.silo.totalDepositedTopcorns()).to.eq(this.testData.newTopcornsInSilo)
                    expect(await this.field.totalSoil()).to.eq(this.testData.newSupplyofSoil)
                    expect(await this.field.totalHarvestable()).to.eq(this.testData.newHarvestablePods)
                    expect(await this.field.totalUnripenedPods()).to.eq(this.testData.newUnripenedPods)
                    expect(await this.field.totalPods()).to.eq(this.testData.newTotalPods)
                })

                it("emits the correct event", async function () {
                    if (new BN(this.testData.currentTWAP).gt(new BN("1000000000000000000"))) {
                        await expect(this.result)
                            .to.emit(this.season, "SupplyIncrease")
                            .withArgs(
                                (parseInt(this.testData.currentSeason) + 1).toString(),
                                this.testData.currentTWAP,
                                this.testData.deltaHarvestablePods,
                                this.testData.deltaTopcornsInSilo,
                                this.testData.deltaSoil
                            )
                    } else if (new BN(this.testData.currentTWAP).eq(new BN("1000000000000000000"))) {
                        await expect(this.result)
                            .to.emit(this.season, "SupplyNeutral")
                            .withArgs((parseInt(this.testData.currentSeason) + 1).toString(), this.testData.deltaSoil)
                    } else {
                        await expect(this.result)
                            .to.emit(this.season, "SupplyDecrease")
                            .withArgs((parseInt(this.testData.currentSeason) + 1).toString(), this.testData.currentTWAP, this.testData.deltaSoil)
                    }
                })
            })
        })
    it("decrements the withdraw buffer", async function () {
        await this.season.resetState()
        await this.season.halfWeekSunrise()
        expect(await this.season.withdrawSeasons()).to.eq(24)
        await this.season.halfWeekSunrise()
        expect(await this.season.withdrawSeasons()).to.eq(23)
        await this.season.decrementSunrise(14)
        expect(await this.season.withdrawSeasons()).to.eq(9)
        await this.season.halfWeekSunrise()
        expect(await this.season.withdrawSeasons()).to.eq(9)
        await this.season.weekSunrise()
        expect(await this.season.withdrawSeasons()).to.eq(8)
        await this.season.decrementSunrise(100)
        expect(await this.season.withdrawSeasons()).to.eq(5)
    })
})


describe("Sun Soil", function () {
    before(async function () {
        ;[owner, user, user2] = await ethers.getSigners()
        userAddress = user.address
        user2Address = user2.address
        const contracts = await deploy("Test", false, true)
        ownerAddress = contracts.account
        this.diamond = contracts.farmDiamond
        this.season = await ethers.getContractAt("MockSeasonFacet", this.diamond.address)
        this.field = await ethers.getContractAt("MockFieldFacet", this.diamond.address)
        this.silo = await ethers.getContractAt("MockSiloFacet", this.diamond.address)
        this.topcorn = await ethers.getContractAt("MockToken", contracts.topcorn)
        this.pair = await ethers.getContractAt("MockPancakeswapV2Pair", contracts.pair)
        this.pegPair = await ethers.getContractAt("MockPancakeswapV2Pair", contracts.pegPair)
        await this.topcorn.mint(this.silo.address, "100000")
        await this.season.setYieldE("100")
    })

    this.beforeEach(async function () {
        await this.season.setSoilE(0)
    })

    it("Properly sets the soil bounds", async function () {
        expect(await this.season.minSoil("100")).to.be.equal("50")
    })
})

describe("Incentivize", function () {
    before(async function () {
        ;[owner, user, user2] = await ethers.getSigners()
        userAddress = user.address
        user2Address = user2.address
        const contracts = await deploy("Test", false, true)
        ownerAddress = contracts.account
        this.diamond = contracts.farmDiamond
        this.season = await ethers.getContractAt("MockSeasonFacet", this.diamond.address)
        this.field = await ethers.getContractAt("MockFieldFacet", this.diamond.address)
        this.silo = await ethers.getContractAt("MockSiloFacet", this.diamond.address)
        this.topcorn = await ethers.getContractAt("MockToken", contracts.topcorn)
        this.pair = await ethers.getContractAt("MockPancakeswapV2Pair", contracts.pair)
        this.pegPair = await ethers.getContractAt("MockPancakeswapV2Pair", contracts.pegPair)
    })

    it("Check incentivize", async function () {
        const balanceBefore = await this.topcorn.balanceOf(userAddress)
        expect(balanceBefore).to.equal("0")
        const price = 5.97e14
        const time = 100
        const gasprice = 1110182695

        const tx = await this.season.incentivizeReward(userAddress, price, time, gasprice)
        await tx.wait()

        expect(await this.topcorn.balanceOf(userAddress)).to.equal("3169712364844331172")
    })
})

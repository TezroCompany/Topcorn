import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

import { expect } from "chai"
import { deploy } from "../scripts/deploy"
import { parseJson } from "./utils/helpers"
import { MAX_UINT32 } from "./utils/constants"
import { ethers } from "hardhat"

let user: SignerWithAddress, user2: SignerWithAddress, owner: SignerWithAddress
let userAddress: string, ownerAddress: string, user2Address: string

// Set the test data
const [columns, tests] = parseJson("./tests/coverage_data/weather.json") as [string[], (number | boolean)[][]]
var numberTests = tests.length
var startTest = 0

describe("Complex Weather", function () {
    before(async function () {
        ;[owner, user, user2] = await ethers.getSigners()
        userAddress = user.address
        user2Address = user2.address
        const contracts = await deploy("Test", false, true)
        ownerAddress = contracts.account
        this.diamond = contracts.farmDiamond
        this.season = await ethers.getContractAt("MockSeasonFacet", this.diamond.address)
        this.silo = await ethers.getContractAt("MockSiloFacet", this.diamond.address)
        this.topcorn = await ethers.getContractAt("MockToken", contracts.topcorn)
    })
    ;[...Array(numberTests).keys()]
        .map((i) => i + startTest)
        .forEach(function (v) {
            const testStr = "Test #"
            describe(testStr.concat(v.toString()), function () {
                before(async function () {
                    this.testData = {}
                    columns.forEach((key, i: number) => (this.testData[key] = tests[v][i]))
                    await this.season.setYieldE(this.testData.startingWeather)
                    this.topcorn.connect(user).burn(await this.topcorn.balanceOf(userAddress))
                    this.dsoil = this.testData.lastSoil
                    this.startSoil = this.testData.startingSoil
                    this.endSoil = this.testData.endingSoil
                    this.price = this.testData.priceAvg
                    this.pods = this.testData.unharvestablePods
                    await this.topcorn.mint(userAddress, this.testData.totalOutstandingTopcorns)
                    await this.season.setLastSowTimeE(this.testData.lastSowTime)
                    await this.season.setNextSowTimeE(this.testData.nextSowTime)
                    this.result = await this.season.stepWeatherWithParams(
                        this.pods,
                        this.dsoil,
                        this.startSoil,
                        this.endSoil,
                        this.price,
                        this.testData.wasRaining,
                        this.testData.rainStalk
                    )
                })
                it("Checks New Weather", async function () {
                    expect(await this.season.yield()).to.eq(this.testData.newWeather)
                })
                it("Emits The Correct Case Weather", async function () {
                    if (this.testData.totalOutstandingTopcorns !== 0)
                        await expect(this.result)
                            .to.emit(this.season, "WeatherChange")
                            .withArgs(await this.season.season(), this.testData.Code, this.testData.newWeather - this.testData.startingWeather, this.testData.newWeather)
                })
            })
        })

    describe("Extreme Weather", async function () {
        before(async function () {
            await this.season.setLastDSoilE("100000")
            await this.season.setStartSoilE("10000")
            await this.topcorn.mint(userAddress, "1000000000")
            await this.season.setPodsE("100000000000")
        })

        beforeEach(async function () {
            await this.season.setYieldE("10")
        })

        it("nextSowTime immediately", async function () {
            await this.season.setLastSowTimeE("1")
            await this.season.setNextSowTimeE("10")
            await this.season.stepWeatherE(ethers.utils.parseEther("1"), "1")
            const weather = await this.season.weather()
            expect(weather.yield).to.equal(7)
            expect(weather.nextSowTime).to.equal(parseInt(MAX_UINT32))
            expect(weather.lastSowTime).to.equal(10)
        })

        it("lastSowTime max", async function () {
            await this.season.setLastSowTimeE(MAX_UINT32)
            await this.season.setNextSowTimeE("1000")
            await this.season.stepWeatherE(ethers.utils.parseEther("1"), "1")
            const weather = await this.season.weather()
            expect(weather.yield).to.equal(7)
            expect(weather.nextSowTime).to.equal(parseInt(MAX_UINT32))
            expect(weather.lastSowTime).to.equal(1000)
        })

        it("lastSowTime max", async function () {
            await this.season.setLastSowTimeE("1061")
            await this.season.setNextSowTimeE("1000")
            await this.season.stepWeatherE(ethers.utils.parseEther("1"), "1")
            const weather = await this.season.weather()
            expect(weather.yield).to.equal(7)
            expect(weather.nextSowTime).to.equal(parseInt(MAX_UINT32))
            expect(weather.lastSowTime).to.equal(1000)
        })

        it("lastSowTime max", async function () {
            await this.season.setLastSowTimeE("1060")
            await this.season.setNextSowTimeE("1000")
            await this.season.stepWeatherE(ethers.utils.parseEther("1"), "1")
            const weather = await this.season.weather()
            expect(weather.yield).to.equal(9)
            expect(weather.nextSowTime).to.equal(parseInt(MAX_UINT32))
            expect(weather.lastSowTime).to.equal(1000)
        })

        it("lastSowTime max", async function () {
            await this.season.setLastSowTimeE("940")
            await this.season.setNextSowTimeE("1000")
            await this.season.stepWeatherE(ethers.utils.parseEther("1"), "1")
            const weather = await this.season.weather()
            expect(weather.yield).to.equal(9)
            expect(weather.nextSowTime).to.equal(parseInt(MAX_UINT32))
            expect(weather.lastSowTime).to.equal(1000)
        })

        it("lastSowTime max", async function () {
            await this.season.setLastSowTimeE("900")
            await this.season.setNextSowTimeE("1000")
            await this.season.stepWeatherE(ethers.utils.parseEther("1"), "1")
            const weather = await this.season.weather()
            expect(weather.yield).to.equal(10)
            expect(weather.nextSowTime).to.equal(parseInt(MAX_UINT32))
            expect(weather.lastSowTime).to.equal(1000)
        })

        it("lastSowTime max", async function () {
            await this.season.setLastSowTimeE("900")
            await this.season.setNextSowTimeE(MAX_UINT32)
            await this.season.stepWeatherE(ethers.utils.parseEther("1"), "1")
            const weather = await this.season.weather()
            expect(weather.yield).to.equal(9)
            expect(weather.nextSowTime).to.equal(parseInt(MAX_UINT32))
            expect(weather.lastSowTime).to.equal(parseInt(MAX_UINT32))
        })
    })
})

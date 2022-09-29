import { ethers } from "hardhat"

import { expect } from "chai"

import { deploy } from "../scripts/deploy"

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers.js"

let user: SignerWithAddress, user2: SignerWithAddress, owner: SignerWithAddress
let userAddress: string, ownerAddress: string, user2Address: string

describe("Claim", function () {
    before(async function () {
        ;[owner, user, user2] = await ethers.getSigners()
        const contracts = await deploy("Test", false, true)

        userAddress = user.address
        user2Address = user2.address
        ownerAddress = contracts.account

        this.diamond = contracts.farmDiamond
        this.season = await ethers.getContractAt("MockSeasonFacet", this.diamond.address)
        this.claim = await ethers.getContractAt("MockClaimFacet", this.diamond.address)
        this.silo = await ethers.getContractAt("MockSiloFacet", this.diamond.address)
        this.field = await ethers.getContractAt("MockFieldFacet", this.diamond.address)
        this.pair = await ethers.getContractAt("MockPancakeswapV2Pair", contracts.pair)
        this.pegPair = await ethers.getContractAt("MockPancakeswapV2Pair", contracts.pegPair)
        this.topcorn = await ethers.getContractAt("MockToken", contracts.topcorn)
        this.weth = await ethers.getContractAt("MockToken", contracts.wbnb)

        await this.season.siloSunrise(0)
        await this.topcorn.mint(userAddress, "1000000000")
        await this.topcorn.mint(user2Address, "1000000000")
        await this.topcorn.mint(this.pair.address, "100000")
        await this.weth.mint(this.pair.address, "100")
        await this.pair.connect(user).approve(this.silo.address, "100000000000")
        await this.pair.connect(user2).approve(this.silo.address, "100000000000")
        await this.topcorn.connect(user).approve(this.silo.address, "100000000000")
        await this.topcorn.connect(user2).approve(this.silo.address, "100000000000")
        await this.pair.faucet(userAddress, "100")
        await this.pair.set("100000", "100", "1")

        await user.sendTransaction({
            to: this.weth.address,
            value: ethers.utils.parseEther("1.0"),
        })
    })

    beforeEach(async function () {
        await this.season.resetAccount(userAddress)
        await this.season.resetAccount(user2Address)
        await this.season.resetAccount(ownerAddress)
        await this.season.resetState()
        await this.season.siloSunrise(0)
    })

    describe("claim", function () {
        beforeEach(async function () {
            await this.silo.connect(user).depositTopcorns("1000")
            await this.silo.connect(user).depositLP("1")
            await this.season.setSoilE("5000")
            await this.field.connect(user).sowTopcorns("1000")
            await this.field.incrementTotalHarvestableE("1000")
            await this.silo.connect(user).withdrawTopcorns([2], ["1000"])
            await this.silo.connect(user).withdrawLP([2], ["1"])
            await this.season.farmSunrises("25")
        })

        describe("claim topcorns", async function () {
            it("reverts when deposit is empty", async function () {
                await expect(this.claim.connect(user).claimTopcorns(["0"])).to.be.revertedWith("Claim: TopCorn withdrawal is empty.")
            })

            it("successfully claims topcorns", async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                await this.claim.connect(user).claimTopcorns(["27"])
                const newTopcorns = await this.topcorn.balanceOf(userAddress)
                expect(await this.silo.topcornDeposit(userAddress, "27")).to.be.equal("0")
                expect(newTopcorns.sub(topcorns)).to.be.equal("1000")
            })
        })

        describe("harvest topcorns", async function () {
            it("reverts when plot is not harvestable", async function () {
                await expect(this.claim.connect(user).harvest(["1"])).to.be.revertedWith("Claim: Plot not harvestable.")
                await expect(this.claim.connect(user).harvest(["1000000"])).to.be.revertedWith("Claim: Plot not harvestable.")
            })

            it("successfully harvests topcorns", async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                await this.claim.connect(user).harvest(["0"])
                const newTopcorns = await this.topcorn.balanceOf(userAddress)
                expect(await this.field.plot(userAddress, "27")).to.be.equal("0")
                expect(newTopcorns.sub(topcorns)).to.be.equal("1000")
            })
        })

        describe("claim LP", async function () {
            it("reverts when deposit is not claimable", async function () {
                await expect(this.claim.connect(user).claimLP(["0"])).to.be.revertedWith("Claim: LP withdrawal is empty.")
            })

            it("successfully claims lp", async function () {
                const lp = await this.pair.balanceOf(userAddress)
                await this.claim.connect(user).claimLP(["27"])
                const newLP = await this.pair.balanceOf(userAddress)
                const lpDeposit = await this.silo.lpDeposit(userAddress, "27")
                expect(lpDeposit[0]).to.be.equal("0")
                expect(lpDeposit[1]).to.be.equal("0")
                expect(newLP.sub(lp)).to.be.equal("1")
            })
        })

        describe("claim all", async function () {
            describe("No Topcorns to wallet", async function () {
                beforeEach(async function () {
                    const topcorns = await this.topcorn.balanceOf(userAddress)
                    this.result = await this.claim.connect(user).claim([["27"], [], [], false, true, "0", "0", false])
                    const newTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.claimedTopcorns = newTopcorns.sub(topcorns)
                    this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
                })

                it("properly sends topcorns to wallet", async function () {
                    expect(this.claimedTopcorns.toString()).to.equal("0")
                })

                // Before partial claiming, was claimedTopcorns and not wrappedTopcorns
                it("properly claims topcorns", async function () {
                    expect(this.wrappedTopcorns.toString()).to.equal("1000")
                })
                it("no topcorns created or destroyed", async function () {
                    expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("1000")
                })
            })

            describe("Topcorns to wallet", async function () {
                beforeEach(async function () {
                    const topcorns = await this.topcorn.balanceOf(userAddress)
                    this.result = await this.claim.connect(user).claim([["27"], [], [], false, true, "0", "0", true])
                    const newTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.claimedTopcorns = newTopcorns.sub(topcorns)
                    this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
                })

                it("properly sends topcorns to wallet", async function () {
                    expect(this.claimedTopcorns.toString()).to.equal("1000")
                })

                // Before partial claiming, was claimedTopcorns and not wrappedTopcorns
                it("properly claims topcorns", async function () {
                    expect(this.wrappedTopcorns.toString()).to.equal("0")
                })
                it("no topcorns created or destroyed", async function () {
                    expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("1000")
                })
            })
        })

        describe("claim and allocate", function () {
            describe("exact allocate", async function () {
                beforeEach(async function () {
                    const topcorns = await this.topcorn.balanceOf(userAddress)
                    this.result = await this.claim.connect(user).claimWithAllocationE([["27"], [], [], false, true, "0", "0", false], "1000")
                    const newTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.claimedTopcorns = newTopcorns.sub(topcorns)
                    this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
                })
                it("properly claims topcorns", async function () {
                    expect(this.claimedTopcorns.toString()).to.equal("0")
                    expect(this.wrappedTopcorns.toString()).to.equal("0")
                })
                it("properly allocates topcorns", async function () {
                    expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1000")
                })
                it("no topcorns created or destroyed", async function () {
                    expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("0")
                })
            })

            describe("exact LP allocate", async function () {
                beforeEach(async function () {
                    const topcorns = await this.topcorn.balanceOf(userAddress)
                    this.result = await this.claim.connect(user).claimWithAllocationE([[], ["27"], [], false, true, "1", "1", false], "1000")
                    const newTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.claimedTopcorns = newTopcorns.sub(topcorns)
                    this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
                })
                it("properly claims topcorns", async function () {
                    expect(this.claimedTopcorns.toString()).to.equal("0")
                    expect(this.wrappedTopcorns.toString()).to.equal("0")
                })
                it("properly claims eth", async function () {
                    await expect(this.result).to.changeEtherBalance(user, "1")
                })
                it("properly allocates topcorns", async function () {
                    expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1000")
                })
                it("no topcorns created or destroyed", async function () {
                    expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("0")
                })
            })

            describe("under allocate", async function () {
                beforeEach(async function () {
                    const topcorns = await this.topcorn.balanceOf(userAddress)
                    this.result = await this.claim.connect(user).claimWithAllocationE([["27"], [], [], false, true, "0", "0", false], "500")
                    const newTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.claimedTopcorns = newTopcorns.sub(topcorns)
                    this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
                })

                it("properly claims topcorns", async function () {
                    expect(this.claimedTopcorns.toString()).to.equal("0")
                    expect(this.wrappedTopcorns.toString()).to.equal("500")
                })
                it("properly allocates topcorns", async function () {
                    expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "500")
                })
                it("no topcorns created or destroyed", async function () {
                    expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("500")
                })
            })

            describe("over allocate", async function () {
                beforeEach(async function () {
                    const topcorns = await this.topcorn.balanceOf(userAddress)
                    this.result = await this.claim.connect(user).claimWithAllocationE([["27"], [], [], false, true, "0", "0", false], "1500")
                    const newTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.claimedTopcorns = newTopcorns.sub(topcorns)
                    this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
                })
                it("properly claims topcorns", async function () {
                    expect(this.claimedTopcorns.toString()).to.equal("-500")
                    expect(this.wrappedTopcorns.toString()).to.equal("0")
                })
                it("properly allocates topcorns", async function () {
                    expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1000")
                })
                it("no topcorns created or destroyed", async function () {
                    expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("-500")
                })
            })

            describe("multiple allocate", async function () {
                beforeEach(async function () {
                    const topcorns = await this.topcorn.balanceOf(userAddress)
                    this.result = await this.claim.connect(user).claimWithAllocationE([["27"], [], ["0"], false, true, "0", "0", false], "1500")
                    const newTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.claimedTopcorns = newTopcorns.sub(topcorns)
                    this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
                })
                it("properly claims topcorns", async function () {
                    expect(this.claimedTopcorns.toString()).to.equal("0")
                    expect(this.wrappedTopcorns.toString()).to.equal("500")
                })
                it("properly allocates topcorns", async function () {
                    expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1500")
                })
                it("no topcorns created or destroyed", async function () {
                    expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("500")
                })
            })

            describe("allocate with topcorns to wallet", async function () {
                beforeEach(async function () {
                    const topcorns = await this.topcorn.balanceOf(userAddress)
                    this.result = await this.claim.connect(user).claimWithAllocationE([["27"], [], [], false, true, "0", "0", true], "500")
                    const Topcorns = await this.topcorn.balanceOf(userAddress)
                    this.claimedTopcorns = Topcorns.sub(topcorns)
                    this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
                })

                it("properly claims topcorns", async function () {
                    expect(this.claimedTopcorns.toString()).to.equal("500")
                    expect(this.wrappedTopcorns.toString()).to.equal("0")
                })

                it("no topcorns created or destroyed", async function () {
                    expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("500")
                })
            })
        })

        describe("claim and deposit Topcorns", function () {
            beforeEach(async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                this.result = await this.silo.connect(user).claimAndDepositTopcorns("1000", [["27"], [], [], false, true, "0", "0", false])
                const Topcorns = await this.topcorn.balanceOf(userAddress)
                this.claimedTopcorns = Topcorns.sub(topcorns)
                this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
            })
            it("properly claims topcorns", async function () {
                expect(this.claimedTopcorns.toString()).to.equal("0")
            })
            it("properly allocates topcorns", async function () {
                expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1000")
                expect(this.result).to.emit(this.silo, "TopcornDeposit").withArgs(userAddress, "27", "1000")
            })
            it("no topcorns created or destroyed", async function () {
                expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("0")
            })
        })

        describe("claim buy and deposit Topcorns", function () {
            beforeEach(async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                this.result = await this.silo
                    .connect(user)
                    .claimBuyAndDepositTopcorns("1000", "990", [["27"], [], [], false, true, "0", "0", false], { value: "1" })
                const Topcorns = await this.topcorn.balanceOf(userAddress)
                this.claimedTopcorns = Topcorns.sub(topcorns)
                this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
            })
            it("properly claims topcorns", async function () {
                expect(this.claimedTopcorns.toString()).to.equal("0")
            })
            it("properly allocates topcorns", async function () {
                expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1000")
            })
            it("no topcorns created or destroyed", async function () {
                expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("0")
            })
        })

        describe("claim and sow Topcorns", function () {
            beforeEach(async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                this.result = await this.field.connect(user).claimAndSowTopcorns("1000", [["27"], [], [], false, true, "0", "0", false])
                const Topcorns = await this.topcorn.balanceOf(userAddress)
                this.claimedTopcorns = Topcorns.sub(topcorns)
                this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
            })
            it("properly claims topcorns", async function () {
                expect(this.claimedTopcorns.toString()).to.equal("0")
            })
            it("properly allocates topcorns", async function () {
                expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1000")
                expect(this.result).to.emit(this.field, "Sow").withArgs(userAddress, "1000", "1000", "1000")
            })
            it("no topcorns created or destroyed", async function () {
                expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("0")
            })
        })

        describe("claim, buy and sow Topcorns", function () {
            beforeEach(async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                this.result = await this.field
                    .connect(user)
                    .claimBuyAndSowTopcorns("1000", "990", [["27"], [], [], false, true, "0", "0", false], { value: "1" })
                const Topcorns = await this.topcorn.balanceOf(userAddress)
                this.claimedTopcorns = Topcorns.sub(topcorns)
                this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
            })
            it("properly claims topcorns", async function () {
                expect(this.claimedTopcorns.toString()).to.equal("0")
            })
            it("properly allocates topcorns", async function () {
                expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1000")
                expect(this.result).to.emit(this.field, "Sow").withArgs(userAddress, "1000", "1990", "1990")
            })
            it("no topcorns created or destroyed", async function () {
                expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("0")
            })
        })

        describe("claim and deposit LP", function () {
            beforeEach(async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                this.silo.connect(user).claimAndDepositLP("1", [["27"], [], [], false, true, "0", "0", false])
                const Topcorns = await this.topcorn.balanceOf(userAddress)
                this.claimedTopcorns = Topcorns.sub(topcorns)
                this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
            })
            it("properly claims topcorns", async function () {
                expect(this.wrappedTopcorns.toString()).to.equal("1000")
            })
            it("no topcorns created or destroyed", async function () {
                expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("1000")
            })
        })

        describe("claim add and deposit LP, exact allocation", function () {
            beforeEach(async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                this.result = this.silo
                    .connect(user)
                    .claimAddAndDepositLP("0", "0", "0", ["1000", "1000", "1"], [["27"], [], [], false, true, "0", "0", false], { value: "1" })
                const Topcorns = await this.topcorn.balanceOf(userAddress)
                this.claimedTopcorns = Topcorns.sub(topcorns)
                this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
            })
            it("properly claims topcorns", async function () {
                expect(this.claimedTopcorns.toString()).to.equal("0")
            })
            it("properly allocates topcorns", async function () {
                expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1000")
            })
            it("no topcorns created or destroyed", async function () {
                expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("0")
            })
        })

        describe("claim add and deposit LP, over allocation", function () {
            beforeEach(async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                this.result = this.silo
                    .connect(user)
                    .claimAddAndDepositLP("0", "0", "0", ["1000", "1000", "1"], [["27"], [], ["0"], false, true, "0", "0", false], {
                        value: "1",
                    })
                const Topcorns = await this.topcorn.balanceOf(userAddress)
                this.claimedTopcorns = Topcorns.sub(topcorns)
                this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
            })

            // Before partial claiming, was claimedTopcorns and not wrappedTopcorns
            it("properly claims topcorns", async function () {
                expect(this.wrappedTopcorns.toString()).to.equal("1000")
            })
            it("properly allocates topcorns", async function () {
                expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1000")
            })
            it("no topcorns created or destroyed", async function () {
                expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("1000")
            })
        })

        describe("claim add and deposit LP, under allocation", function () {
            beforeEach(async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                this.result = this.silo
                    .connect(user)
                    .claimAddAndDepositLP("0", "0", "0", ["2000", "2000", "2"], [["27"], [], [], false, true, "0", "0", false], { value: "2" })
                const Topcorns = await this.topcorn.balanceOf(userAddress)
                this.claimedTopcorns = Topcorns.sub(topcorns)
                this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
            })
            it("properly claims topcorns", async function () {
                expect(this.claimedTopcorns.toString()).to.equal("-1000")
            })
            it("properly allocates topcorns", async function () {
                expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1000")
            })
            it("no topcorns created or destroyed", async function () {
                expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("-1000")
            })
        })

        describe("claim add buy Topcorns and deposit LP, exact allocation", function () {
            beforeEach(async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                this.result = this.silo
                    .connect(user)
                    .claimAddAndDepositLP("0", "1000", "0", ["2000", "2000", "2"], [["27"], [], [], false, true, "0", "0", false], {
                        value: "4",
                    })
                const Topcorns = await this.topcorn.balanceOf(userAddress)
                this.claimedTopcorns = Topcorns.sub(topcorns)
                this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
            })
            it("properly claims topcorns", async function () {
                expect(this.claimedTopcorns.toString()).to.equal("0")
            })
            it("properly allocates topcorns", async function () {
                expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "1000")
            })
            it("no topcorns created or destroyed", async function () {
                expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("0")
            })
        })

        describe("claim add buy ETH and deposit LP, exact allocation", function () {
            beforeEach(async function () {
                const topcorns = await this.topcorn.balanceOf(userAddress)
                this.result = this.silo
                    .connect(user)
                    .claimAddAndDepositLP("0", "0", "1", ["2000", "2000", "2"], [["27"], [], ["0"], false, true, "0", "0", false], {
                        value: "1",
                    })
                const Topcorns = await this.topcorn.balanceOf(userAddress)
                this.claimedTopcorns = Topcorns.sub(topcorns)
                this.wrappedTopcorns = await this.claim.connect(user).wrappedTopcorns(userAddress)
            })
            it("properly claims topcorns", async function () {
                expect(this.claimedTopcorns.toString()).to.equal("-1011")
            })
            it("properly allocates topcorns", async function () {
                expect(this.result).to.emit(this.claim, "TopcornAllocation").withArgs(userAddress, "2000")
            })
            it("no topcorns created or destroyed", async function () {
                expect(this.claimedTopcorns.add(this.wrappedTopcorns).toString()).to.equal("-1011")
            })
        })
    })

    describe("wrap/unwrap", function () {
        beforeEach(async function () {
            const topcorns = await this.topcorn.balanceOf(userAddress)
            this.result = this.claim.connect(user).wrapTopcorns("1000")
            const Topcorns = await this.topcorn.balanceOf(userAddress)
            this.deltaTopcorns = Topcorns.sub(topcorns)
        })

        it("wraps topcorns", async function () {
            expect(this.deltaTopcorns).to.be.equal("-1000")
            expect(await this.claim.wrappedTopcorns(userAddress)).to.be.equal("1000")
            expect(await this.topcorn.balanceOf(this.claim.address)).to.be.equal("1000")
        })

        it("unwraps all topcorns", async function () {
            const topcornsBefore = await this.topcorn.balanceOf(userAddress)
            await this.claim.connect(user).unwrapTopcorns("1000")
            const Topcorns = await this.topcorn.balanceOf(userAddress)
            expect(await this.claim.wrappedTopcorns(userAddress)).to.be.equal("0")
            expect(await this.topcorn.balanceOf(this.claim.address)).to.be.equal("0")
            expect(Topcorns.sub(topcornsBefore)).to.be.equal("1000")
        })

        it("unwraps some topcorns", async function () {
            const topcornsBefore = await this.topcorn.balanceOf(userAddress)
            await this.claim.connect(user).unwrapTopcorns("500")
            const Topcorns = await this.topcorn.balanceOf(userAddress)
            expect(await this.claim.wrappedTopcorns(userAddress)).to.be.equal("500")
            expect(await this.topcorn.balanceOf(this.claim.address)).to.be.equal("500")
            expect(Topcorns.sub(topcornsBefore)).to.be.equal("500")
        })

        it("unwraps too many topcorns", async function () {
            const topcornsBefore = await this.topcorn.balanceOf(userAddress)
            await this.claim.connect(user).unwrapTopcorns("1500")
            const Topcorns = await this.topcorn.balanceOf(userAddress)
            expect(await this.claim.wrappedTopcorns(userAddress)).to.be.equal("0")
            expect(await this.topcorn.balanceOf(this.claim.address)).to.be.equal("0")
            expect(Topcorns.sub(topcornsBefore)).to.be.equal("1000")
        })

        it("unwraps too many topcorns", async function () {
            const topcornsBefore = await this.topcorn.balanceOf(userAddress)
            await this.claim.connect(user).unwrapTopcorns("1500")
            const Topcorns = await this.topcorn.balanceOf(userAddress)
            expect(await this.claim.wrappedTopcorns(userAddress)).to.be.equal("0")
            expect(await this.topcorn.balanceOf(this.claim.address)).to.be.equal("0")
            expect(Topcorns.sub(topcornsBefore)).to.be.equal("1000")
        })

        it("claims and unwraps topcorns", async function () {
            await this.season.setSoilE("5000")
            await this.field.connect(user).sowTopcorns("1000")
            await this.field.incrementTotalHarvestableE("1000")
            const topcornsBefore = await this.topcorn.balanceOf(userAddress)
            this.result = await this.claim.connect(user).claimAndUnwrapTopcorns([[], [], ["0"], false, true, "0", "0", true], "1000")
            const Topcorns = await this.topcorn.balanceOf(userAddress)
            expect(await this.topcorn.balanceOf(this.claim.address)).to.be.equal("0")
            expect(await this.claim.wrappedTopcorns(userAddress)).to.be.equal("0")
            expect(Topcorns.sub(topcornsBefore)).to.be.equal("2000")
        })
    })

    it("Guards against reentrancy", async function () {
        await expect(this.season.reentrancyGuardTest()).to.be.revertedWith("ReentrancyGuard: reentrant call")
    })
})

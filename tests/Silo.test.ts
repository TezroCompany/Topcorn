import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers.js"
import { expect } from "chai"
import { ethers } from "hardhat"
import { deploy } from "../scripts/deploy"
import { getEthSpentOnGas, toTopcorn, toEther } from "./utils/helpers"

let user: SignerWithAddress, user2: SignerWithAddress, owner: SignerWithAddress
let userAddress: string, ownerAddress: string, user2Address: string

describe("Silo", function () {
    before(async function () {
        ;[owner, user, user2] = await ethers.getSigners()
        const contracts = await deploy("Test", false, true)

        userAddress = user.address
        user2Address = user2.address
        ownerAddress = contracts.account

        this.diamond = contracts.farmDiamond
        this.season = await ethers.getContractAt("MockSeasonFacet", this.diamond.address)
        this.diamondLoupeFacet = await ethers.getContractAt("DiamondLoupeFacet", this.diamond.address)
        this.silo = await ethers.getContractAt("MockSiloFacet", this.diamond.address)
        this.convert = await ethers.getContractAt("ConvertFacet", this.diamond.address)
        this.pair = await ethers.getContractAt("MockPancakeswapV2Pair", contracts.pair)
        this.pegPair = await ethers.getContractAt("MockPancakeswapV2Pair", contracts.pegPair)
        this.topcorn = await ethers.getContractAt("MockToken", contracts.topcorn)
        this.claim = await ethers.getContractAt("MockClaimFacet", this.diamond.address)

        await owner.sendTransaction({
            to: contracts.wbnb,
            value: ethers.utils.parseEther("100"),
        })

        await this.pair.simulateTrade(toTopcorn("1000"), toEther("1"))
        await this.pair.setLiqudity("1")
        await this.season.siloSunrise(0)
        await this.pair.faucet(userAddress, "1")
        await this.topcorn.mint(userAddress, toTopcorn("1000000000"))
        await this.topcorn.mint(user2Address, "1000000000")
        await this.pair.connect(user).approve(this.silo.address, "100000000000")
        await this.pair.connect(user2).approve(this.silo.address, "100000000000")
        await this.topcorn.connect(user).approve(this.silo.address, "100000" + "000000000000000000")
        await this.topcorn.connect(user2).approve(this.silo.address, "100000" + "000000000000000000")
    })

    beforeEach(async function () {
        await this.season.resetAccount(userAddress)
        await this.season.resetAccount(user2Address)
        await this.season.resetAccount(ownerAddress)
        await this.pair.burnAllLP(this.silo.address)
        await this.pair.burnAllLP(userAddress)
        await this.pair.burnAllLP(user2Address)
        await this.pair.burnAllLP(ownerAddress)
        await this.season.resetState()
        await this.season.siloSunrise(0)
    })

 
    describe('deposit', function () {
      describe('single deposit', function () {
        beforeEach(async function () {
          this.result = await this.silo.connect(user).depositTopcorns('1000');
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('1000');
          expect(await this.silo.totalSeeds()).to.eq('2000');
          expect(await this.silo.totalStalk()).to.eq('10000000');
        });

        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2000');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('10000000');
        });

        it('properly adds the crate', async function () {
          expect(await this.silo.topcornDeposit(userAddress, 2)).to.eq('1000');
        })

        it('emits Deposit event', async function () {
          await expect(this.result).to.emit(this.silo, 'TopcornDeposit').withArgs(userAddress, 2, '1000');
        });
      });

      describe('2 deposits same season', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.silo.connect(user).depositTopcorns('1000');
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('2000');
          expect(await this.silo.totalSeeds()).to.eq('4000');
          expect(await this.silo.totalStalk()).to.eq('20000000');
        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('4000');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('20000000');
        });

        it('properly adds the crate', async function () {
          expect(await this.silo.topcornDeposit(userAddress, 2)).to.eq('2000');
        });
      });

      describe('2 deposits 2 users', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.silo.connect(user2).depositTopcorns('1000');
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('2000');
          expect(await this.silo.totalSeeds()).to.eq('4000');
          expect(await this.silo.totalStalk()).to.eq('20000000');
        });

        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2000');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('10000000');
        });
        it('properly updates the user2 balance', async function () {
          expect(await this.silo.balanceOfSeeds(user2Address)).to.eq('2000');
          expect(await this.silo.balanceOfStalk(user2Address)).to.eq('10000000');
        });

        it('properly adds the crate', async function () {
          expect(await this.silo.topcornDeposit(userAddress, 2)).to.eq('1000');
          expect(await this.silo.topcornDeposit(user2Address, 2)).to.eq('1000');
        });
      });

      describe('1 deposit with step', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(0);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('1000');
          expect(await this.silo.totalSeeds()).to.eq('2000');
          expect(await this.silo.totalStalk()).to.eq('10000000');
        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2000');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('10000000');
        });
      });
      
      describe('2 deposits different seasons', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(0);
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(0);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('2000');
          expect(await this.silo.totalSeeds()).to.eq('4000');
          expect(await this.silo.totalStalk()).to.eq('20002000');
        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('4000');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('20002000');
        });

        it('properly adds the crate', async function () {
          expect(await this.silo.topcornDeposit(userAddress, 2)).to.eq('1000');
          expect(await this.silo.topcornDeposit(userAddress, 3)).to.eq('1000');
        });
      });
    });

    describe('withdraw', function () {
      describe('withdraw 1 topcorn crate', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          this.result = await this.silo.connect(user).withdrawTopcorns([2],['1000']);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('0');
          expect(await this.silo.totalStalk()).to.eq('0');
          expect(await this.silo.totalSeeds()).to.eq('0');
          expect(await this.silo.totalWithdrawnTopcorns()).to.eq('1000');
        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('0');
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('0');
        });
        it('properly removes the crate', async function () {
          expect(await this.silo.topcornDeposit(user2Address, 2)).to.eq('0');
        });

        it('emits TopcornRemove event', async function () {
          await expect(this.result).to.emit(this.silo, 'TopcornRemove').withArgs(userAddress, [2], ['1000'], '1000', '10000000', '2000');
        });
      });
      describe('withdraw part of a topcorn crate', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('2000');
          await this.silo.connect(user).withdrawTopcorns([2],['1000']);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('1000');
          expect(await this.silo.totalStalk()).to.eq('10000000');
          expect(await this.silo.totalSeeds()).to.eq('2000');
          expect(await this.silo.totalWithdrawnTopcorns()).to.eq('1000');
        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('10000000');
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2000');
        });
        it('properly removes the crate', async function () {
          expect(await this.silo.topcornDeposit(userAddress, 2)).to.eq('1000');
        });
      });
      describe('2 topcorn crates', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(0);
          await this.silo.connect(user).depositTopcorns('1000');
          await this.silo.connect(user).withdrawTopcorns([2,3],['1000','1000']);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('0');
          expect(await this.silo.totalStalk()).to.eq('0');
          expect(await this.silo.totalSeeds()).to.eq('0');
          expect(await this.silo.totalWithdrawnTopcorns()).to.eq('2000');
        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('0');
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('0');
        });
        it('properly removes the crate', async function () {
          expect(await this.silo.topcornDeposit(userAddress, 2)).to.eq(0);
          expect(await this.silo.topcornDeposit(userAddress, 3)).to.eq(0);
        });
      });
    });

    describe('supply increase', function () {
      describe('1 supply increase', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(100);
        });
        it('properly updates the total balances', async function () {
          expect(await this.silo.totalFarmableTopcorns()).to.eq('100');
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('1100');
          expect(await this.silo.totalStalk()).to.eq('11000000');
          expect(await this.silo.totalSeeds()).to.eq('2200');

        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('100');
          expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('1000000');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('11000000');
        });
      });

      describe('supply increase and update silo', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(100);
          await this.silo.updateSilo(userAddress);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalFarmableTopcorns()).to.eq('0');
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('1100');
          expect(await this.silo.totalStalk()).to.eq('11002000');
          expect(await this.silo.totalSeeds()).to.eq('2200');

        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('0');
          expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('0');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('11002000');
        });

        it('properly updates the user balance', async function () {
          expect(await this.silo.topcornDeposit(userAddress,3)).to.eq('100');
        });
      });

      describe('2 supply increase', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(100);
          await this.season.siloSunrise(100);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalFarmableTopcorns()).to.eq('200');
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('1200');
          expect(await this.silo.totalSeeds()).to.eq('2400');
          expect(await this.silo.totalStalk()).to.eq('12000000');

        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('200');
          expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('2000000');
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2400');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('12000000');
        });
      });

      describe('2 supply increases and update silo ', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(100);
          await this.season.siloSunrise(100);
          await this.silo.updateSilo(userAddress);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalFarmableTopcorns()).to.eq('0');
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('1200');
          expect(await this.silo.totalStalk()).to.eq('12004000');
          expect(await this.silo.totalSeeds()).to.eq('2400');

        });

        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('0');
          expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('0');
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2400');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('12004000');
        });

        it('properly updates the user balance', async function () {
          expect(await this.silo.topcornDeposit(userAddress,4)).to.eq('200');
        });
      });

      describe('3 supply increase', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(100);
          await this.season.siloSunrise(100);
          await this.season.siloSunrise(100);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalFarmableTopcorns()).to.eq('300');
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('1300');
          expect(await this.silo.totalSeeds()).to.eq('2600');
          expect(await this.silo.totalStalk()).to.eq('13000000');

        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('300');
          expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('3000000');
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2600');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('13000000');
        });
      });

      describe('3 supply increase and an update silo', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(100);
          await this.season.siloSunrise(100);
          await this.season.siloSunrise(100);
          await this.silo.updateSilo(userAddress);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalFarmableTopcorns()).to.eq('0');
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('1300');
          expect(await this.silo.totalSeeds()).to.eq('2600');
          expect(await this.silo.totalStalk()).to.eq('13006000');

        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('0');
          expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('0');
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2600');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('13006000');
        });

        it('properly updates the user balance', async function () {
          expect(await this.silo.topcornDeposit(userAddress,5)).to.eq('300');
        });
      });

      describe('2 supply increases and update silo in the middle', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(100);
          await this.silo.updateSilo(userAddress);
          await this.season.siloSunrise(100);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalFarmableTopcorns()).to.eq('100');
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('1200');
          expect(await this.silo.totalStalk()).to.eq('12002000');
          expect(await this.silo.totalSeeds()).to.eq('2400');

        });

        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('100');
          expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('1000000');
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2400');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('12002000');
        });

        it('properly updates the user balance', async function () {
          expect(await this.silo.topcornDeposit(userAddress,3)).to.eq('100');
        });
      });

      describe('3 supply increase and an update silo in the middle', function () {
        beforeEach(async function () {
          await this.silo.connect(user).depositTopcorns('1000');
          await this.season.siloSunrise(100);
          await this.season.siloSunrise(100);
          await this.silo.updateSilo(userAddress);
          await this.season.siloSunrise(100);
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalFarmableTopcorns()).to.eq('100');
        });

        it('properly updates the total balances', async function () {
          expect(await this.silo.totalDepositedTopcorns()).to.eq('1300');
          expect(await this.silo.totalSeeds()).to.eq('2600');
          expect(await this.silo.totalStalk()).to.eq('13004000');

        });
        it('properly updates the user balance', async function () {
          expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('100');
          expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('1000000');
          expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2600');
          expect(await this.silo.balanceOfStalk(userAddress)).to.eq('13004000');
        });

        it('properly updates the user balance', async function () {
          expect(await this.silo.topcornDeposit(userAddress,4)).to.eq('200');
        });
      });

      describe('2 supply increases with alternating updates', function () {
      beforeEach(async function () {
        await this.silo.connect(user).depositTopcorns('1000');
        await this.season.siloSunrise(100);
        await this.silo.updateSilo(userAddress);
        await this.season.siloSunrise(100);
        await this.silo.updateSilo(userAddress);
      });

      it('properly updates the total balances', async function () {
        expect(await this.silo.totalFarmableTopcorns()).to.eq('0');
      });

      it('properly updates the total balances', async function () {
        expect(await this.silo.totalDepositedTopcorns()).to.eq('1200');
        expect(await this.silo.totalStalk()).to.eq('12004200');
        expect(await this.silo.totalSeeds()).to.eq('2400');

      });

      it('properly updates the user balance', async function () {
        expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('0');
        expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('0');
        expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2400');
        expect(await this.silo.balanceOfStalk(userAddress)).to.eq('12004200');
      });

      it('properly updates the user balance', async function () {
        expect(await this.silo.topcornDeposit(userAddress,3)).to.eq('100');
        expect(await this.silo.topcornDeposit(userAddress,4)).to.eq('100');
      });
    });

    describe('2 users with supply increase and 1 update', function () {
      beforeEach(async function () {
        await this.silo.connect(user).depositTopcorns('1000');
        await this.silo.connect(user2).depositTopcorns('1000');
        await this.season.siloSunrise(100);
        await this.silo.updateSilo(userAddress);
      });

      it('properly updates the total balances', async function () {
        expect(await this.silo.totalFarmableTopcorns()).to.eq('50');
      });

      it('properly updates the total balances', async function () {
        expect(await this.silo.totalDepositedTopcorns()).to.eq('2100');
        expect(await this.silo.totalStalk()).to.eq('21002000');
        expect(await this.silo.totalSeeds()).to.eq('4200');

      });

      it('properly updates the user balance', async function () {
        expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('0');
        expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('0');
        expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2100');
        expect(await this.silo.balanceOfStalk(userAddress)).to.eq('10502000');
      });

      it('properly updates the user2 balance', async function () {
        expect(await this.silo.balanceOfFarmableTopcorns(user2Address)).to.eq('50');
        expect(await this.silo.balanceOfFarmableStalk(user2Address)).to.eq('500000');
        expect(await this.silo.balanceOfSeeds(user2Address)).to.eq('2100');
        expect(await this.silo.balanceOfStalk(user2Address)).to.eq('10500000');
      });

      it('properly updates the user balance', async function () {
        expect(await this.silo.topcornDeposit(userAddress,3)).to.eq('50');
      });
    });

    describe('2 users with supply increase and both update', function () {
      beforeEach(async function () {
        await this.silo.connect(user).depositTopcorns('1000');
        await this.silo.connect(user2).depositTopcorns('1000');
        await this.season.siloSunrise(100);
        await this.silo.updateSilo(userAddress);
        await this.silo.updateSilo(user2Address);
      });

      it('properly updates the total balances', async function () {
        expect(await this.silo.totalFarmableTopcorns()).to.eq('0');
      });

      it('properly updates the total balances', async function () {
        expect(await this.silo.totalDepositedTopcorns()).to.eq('2100');
        expect(await this.silo.totalStalk()).to.eq('21004000');
        expect(await this.silo.totalSeeds()).to.eq('4200');
      });

      it('properly updates the user balance', async function () {
        expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('0');
        expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('0');
        expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2100');
        expect(await this.silo.balanceOfStalk(userAddress)).to.eq('10502000');
      });

      it('properly updates the user2 balance', async function () {
        expect(await this.silo.balanceOfFarmableTopcorns(user2Address)).to.eq('0');
        expect(await this.silo.balanceOfFarmableStalk(user2Address)).to.eq('0');
        expect(await this.silo.balanceOfSeeds(user2Address)).to.eq('2100');
        expect(await this.silo.balanceOfStalk(user2Address)).to.eq('10502000');
      });

      it('properly updates the user balance', async function () {
        expect(await this.silo.topcornDeposit(userAddress,3)).to.eq('50');
        expect(await this.silo.topcornDeposit(user2Address,3)).to.eq('50');
      });
    });

   describe('2 users with supply increase and both update', function () {
      beforeEach(async function () {
        await this.silo.connect(user).depositTopcorns('1000');
        await this.silo.connect(user2).depositTopcorns('1000');
        await this.season.siloSunrise(100);
        await this.silo.updateSilo(userAddress);
        await this.season.siloSunrise(100);
        await this.silo.updateSilo(user2Address);
      });

      it('properly updates the total balances', async function () {
        expect(await this.silo.totalFarmableTopcorns()).to.eq('51');
      });

      it('properly updates the total balances', async function () {
        expect(await this.silo.totalDepositedTopcorns()).to.eq('2200');
        expect(await this.silo.totalStalk()).to.eq('22006000');
        expect(await this.silo.totalSeeds()).to.eq('4400');

      });

      it('properly updates the user balance', async function () {
        expect(await this.silo.balanceOfFarmableTopcorns(userAddress)).to.eq('50');
        expect(await this.silo.balanceOfFarmableStalk(userAddress)).to.eq('500000');
        expect(await this.silo.balanceOfSeeds(userAddress)).to.eq('2200');
        expect(await this.silo.balanceOfStalk(userAddress)).to.eq('11002000');
      });

      it('properly updates the user2 balance', async function () {
        expect(await this.silo.balanceOfFarmableTopcorns(user2Address)).to.eq('0');
        expect(await this.silo.balanceOfFarmableStalk(user2Address)).to.eq('0');
        expect(await this.silo.balanceOfSeeds(user2Address)).to.eq('2198');
        expect(await this.silo.balanceOfStalk(user2Address)).to.eq('10994000');
      });

      it('properly updates the user balance', async function () {
        expect(await this.silo.topcornDeposit(userAddress,3)).to.eq('50');
      });
   });
   
    });

    describe("LP Refund", function () {
        describe("Add and Deposit LP", async function () {
           describe("no swap", async function () {               
                it("exact amount", async function () {
                    this.beforeTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.beforeEth = await ethers.provider.getBalance(userAddress)
                    this.result = await this.silo
                        .connect(user)
                       .addAndDepositLP("0", "0", "0", [toTopcorn("1000"), toTopcorn("1000"), toEther("1")], { value: toEther("1") })
                    this.ethSpentOnGas = await getEthSpentOnGas(this.result)

                    expect(this.beforeTopcorns.sub(await this.topcorn.balanceOf(userAddress))).to.equal(toTopcorn("1000"))
                    expect(this.beforeEth.sub(await ethers.provider.getBalance(userAddress)).sub(this.ethSpentOnGas)).to.equal(toEther("1"))
                })

                it("too much topcorn", async function () {
                    this.beforeTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.beforeEth = await ethers.provider.getBalance(userAddress)
                    this.result = await this.silo
                        .connect(user)
                        .addAndDepositLP("0", "0", "0", [toTopcorn("1001"), toTopcorn("1000"), toEther("1")], { value: toEther("1") })
                    this.ethSpentOnGas = await getEthSpentOnGas(this.result)

                    expect(this.beforeTopcorns.sub(await this.topcorn.balanceOf(userAddress))).to.equal(toTopcorn("1000"))
                    expect(this.beforeEth.sub(await ethers.provider.getBalance(userAddress)).sub(this.ethSpentOnGas)).to.equal(toEther("1"))
                })

                it("too much eth", async function () {
                    this.beforeTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.beforeEth = await ethers.provider.getBalance(userAddress)
                    this.result = await this.silo
                        .connect(user)
                        .addAndDepositLP("0", "0", "0", [toTopcorn("1000"), toTopcorn("1000"), toEther("1")], { value: toEther("1.01") })
                    this.ethSpentOnGas = await getEthSpentOnGas(this.result)

                    expect(this.beforeTopcorns.sub(await this.topcorn.balanceOf(userAddress))).to.equal(toTopcorn("1000"))
                    expect(this.beforeEth.sub(await ethers.provider.getBalance(userAddress)).sub(this.ethSpentOnGas)).to.equal(toEther("1"))
                })
            })

            describe("eth to topcorn swap", async function () {
                it("exact amount", async function () {
                    this.beforeTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.beforeEth = await ethers.provider.getBalance(userAddress)
                    this.result = await this.silo
                        .connect(user)
                        .addAndDepositLP("0", toTopcorn("500"), "0", [toTopcorn("1000"), toTopcorn("1000"), toEther("1")], {
                            value: toEther("2").add("1"),
                        })
                    this.ethSpentOnGas = await getEthSpentOnGas(this.result)

                    expect(this.beforeTopcorns.sub(await this.topcorn.balanceOf(userAddress))).to.equal(toTopcorn("500"))
                    expect(this.beforeEth.sub(await ethers.provider.getBalance(userAddress)).sub(this.ethSpentOnGas)).to.equal(
                        toEther("2").add("1")
                    )
                })

                it("too much topcorn", async function () {
                    this.beforeTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.beforeEth = await ethers.provider.getBalance(userAddress)
                    this.result = await this.silo
                        .connect(user)
                        .addAndDepositLP("0", toTopcorn("500"), "0", [toTopcorn("1001"), toTopcorn("1000"), toEther("1")], {
                            value: toEther("2").add("1"),
                        })
                    this.ethSpentOnGas = await getEthSpentOnGas(this.result)

                    expect(this.beforeTopcorns.sub(await this.topcorn.balanceOf(userAddress))).to.equal(toTopcorn("500"))
                    expect(this.beforeEth.sub(await ethers.provider.getBalance(userAddress)).sub(this.ethSpentOnGas)).to.equal(
                        toEther("2").add("1")
                    )
                })

                it("too much eth", async function () {
                    this.beforeTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.beforeEth = await ethers.provider.getBalance(userAddress)
                    this.result = await this.silo
                        .connect(user)
                        .addAndDepositLP("0", toTopcorn("500"), "0", [toTopcorn("1000"), toTopcorn("1000"), toEther("1")], {
                            value: toEther("2").add("11"),
                        })
                    this.ethSpentOnGas = await getEthSpentOnGas(this.result)

                    expect(this.beforeTopcorns.sub(await this.topcorn.balanceOf(userAddress))).to.equal(toTopcorn("500"))
                    expect(this.beforeEth.sub(await ethers.provider.getBalance(userAddress)).sub(this.ethSpentOnGas)).to.equal(
                        toEther("2").add("1")
                    )
                })
            })

            describe("topcorn to eth swap", async function () {
                it("exact amount", async function () {
                    this.beforeTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.beforeEth = await ethers.provider.getBalance(userAddress)
                    this.result = await this.silo
                        .connect(user)
                        .addAndDepositLP("0", "0", toEther("0.5"), [toTopcorn("1000"), toTopcorn("1000"), toEther("1")], { value: toEther("0.5") })
                    this.ethSpentOnGas = await getEthSpentOnGas(this.result)

                    expect(this.beforeTopcorns.sub(await this.topcorn.balanceOf(userAddress))).to.equal(toTopcorn("2000").add("1"))
                    expect(this.beforeEth.sub(await ethers.provider.getBalance(userAddress)).sub(this.ethSpentOnGas)).to.be.closeTo(toEther("0.5"), 10**9)
                })

                it("too much topcorn", async function () {
                    this.beforeTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.beforeEth = await ethers.provider.getBalance(userAddress)
                    this.result = await this.silo
                        .connect(user)
                        .addAndDepositLP("0", "0", toEther("0.5"), [toTopcorn("1001"), toTopcorn("1000"), toEther("1")], { value: toEther("0.5") })
                    this.ethSpentOnGas = await getEthSpentOnGas(this.result)

                    expect(this.beforeTopcorns.sub(await this.topcorn.balanceOf(userAddress))).to.equal(toTopcorn("2000").add("1"))
                    expect(this.beforeEth.sub(await ethers.provider.getBalance(userAddress)).sub(this.ethSpentOnGas)).to.equal(toEther("0.5"))
                })

                it("too much eth", async function () {
                    this.beforeTopcorns = await this.topcorn.balanceOf(userAddress)
                    this.beforeEth = await ethers.provider.getBalance(userAddress)
                    this.result = await this.silo
                        .connect(user)
                        .addAndDepositLP("0", "0", toEther("0.5"), [toTopcorn("1000"), toTopcorn("1000"), toEther("1")], { value: toEther("0.6") })
                    this.ethSpentOnGas = await getEthSpentOnGas(this.result)

                    expect(this.beforeTopcorns.sub(await this.topcorn.balanceOf(userAddress))).to.equal(toTopcorn("2000").add("1"))
                    expect(this.beforeEth.sub(await ethers.provider.getBalance(userAddress)).sub(this.ethSpentOnGas)).to.be.closeTo(toEther("0.5"), 10**9)
                })
            })
        })

        it("Double Refund", async function () {
            this.beforeTopcorns = await this.topcorn.balanceOf(userAddress)
            this.beforeEth = await ethers.provider.getBalance(userAddress)
            this.result = await this.silo.connect(user).mockRefund(toTopcorn("1000"), { value: toEther("0.5") })
            this.ethSpentOnGas = await getEthSpentOnGas(this.result)

            expect(this.beforeTopcorns.sub(await this.topcorn.balanceOf(userAddress))).to.equal("0")
            expect(this.beforeEth.sub(await ethers.provider.getBalance(userAddress)).sub(this.ethSpentOnGas)).to.equal("0")
        })
    })
})

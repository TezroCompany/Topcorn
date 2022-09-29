var fs = require("fs");

const pancakeSWAP_V2_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const pancakeSWAP_V2_PAIR = "0x87898263B6C5BABe34b4ec53F22d98430b91e371";
const WBNB = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const TOPCORN_DEV = "0x46F8d9A4E116A665e0E4144DbD5D85320ff9e6e7";

async function router() {
    let routerJson = fs.readFileSync(
      `./artifacts/contracts/mocks/MockPancakeV2Router.sol/MockPancakeV2Router.json`
    );

    await network.provider.send("hardhat_setCode", [
      pancakeSWAP_V2_ROUTER,
      JSON.parse(routerJson).deployedBytecode,
    ]);

    const mockRouter = await ethers.getContractAt(
      "MockPancakeV2Router",
      pancakeSWAP_V2_ROUTER
    );

    let tokenJson = fs.readFileSync(
      `./artifacts/contracts/mocks/MockWBNB.sol/MockWBNB.json`
    );

    await network.provider.send("hardhat_setCode", [
      WBNB,
      JSON.parse(tokenJson).deployedBytecode,
    ]);

    await mockRouter.setWBNB(WBNB);
    return pancakeSWAP_V2_ROUTER;
}

async function pool() {
    let tokenJson = fs.readFileSync(
      `./artifacts/contracts/mocks/MockPancakeswapV2Pair.sol/MockPancakeswapV2Pair.json`
    );

    await network.provider.send("hardhat_setCode", [
      pancakeSWAP_V2_PAIR,
      JSON.parse(tokenJson).deployedBytecode,
    ]);

    const pair = await ethers.getContractAt(
      "MockPancakeswapV2Pair",
      pancakeSWAP_V2_PAIR
    );
    
    await pair.resetLP();
    await pair.setToken(TOPCORN_DEV);
    return pancakeSWAP_V2_PAIR;
}

async function topcorn() {
    let tokenJson = fs.readFileSync(
      `./artifacts/contracts/mocks/MockToken.sol/MockToken.json`
    );

    await network.provider.send("hardhat_setCode", [
      TOPCORN_DEV,
      JSON.parse(tokenJson).deployedBytecode,
    ]);

    const topcorn = await ethers.getContractAt("MockToken", TOPCORN_DEV);
    await topcorn.setDecimals(18);
    return TOPCORN_DEV;
}

exports.impersonateRouter = router;
exports.impersonateTopcorn = topcorn;
exports.impersonatePool = pool;

const diamond = require("./diamond.js");

const {
  impersonateTopcorn,
  impersonateRouter,
  impersonatePool,
} = require("./impersonate.js");

function addCommas(nStr) {
  nStr += "";
  const x = nStr.split(".");
  let x1 = x[0];
  const x2 = x.length > 1 ? "." + x[1] : "";
  var rgx = /(\d+)(\d{3})/;
  while (rgx.test(x1)) {
    x1 = x1.replace(rgx, "$1" + "," + "$2");
  }
  return x1 + x2;
}

function strDisplay(str) {
  return addCommas(str.toString());
}

async function main(scriptName = "Deploy", verbose = true, mock = false) {
  if (verbose) {
    console.log("SCRIPT NAME: ", scriptName);
    console.log("MOCKS ENABLED: ", mock);
    console.log("VERBOSE ENABLED: ", verbose);
  }

  if (mock) {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    });
  }

  const accounts = await ethers.getSigners();
  const account = await accounts[0].getAddress();

  if (verbose) {
    console.log("Account: " + account);
    console.log("---");
  }

  let tx;
  let totalGasUsed = ethers.BigNumber.from("0");
  let receipt;

  async function deployFacets(
    verbose,
    facets,
    libraryNames = [],
    facetLibraries = {}
  ) {
    const instances = [];
    const libraries = {};

    for (const name of libraryNames) {
      if (verbose) {
        console.log(`Deploying: ${name}`);
      }

      let libraryFactory = await ethers.getContractFactory(name);
      libraryFactory = await libraryFactory.deploy();
      await libraryFactory.deployed();
      const receipt = await libraryFactory.deployTransaction.wait();

      if (verbose) {
        console.log(`${name} deploy gas used: ` + strDisplay(receipt.gasUsed));
        console.log(`Deployed at ${libraryFactory.address}`);
      }
      
      libraries[name] = libraryFactory.address;
    }

    for (let facet of facets) {
      let constructorArgs = [];
      if (Array.isArray(facet)) {
        [facet, constructorArgs] = facet;
      }
      let factory;
      if (facetLibraries[facet] !== undefined) {
        let facetLibrary = Object.keys(libraries).reduce((acc, val) => {
          if (facetLibraries[facet].includes(val)) acc[val] = libraries[val];
          return acc;
        }, {});
        factory = await ethers.getContractFactory(facet, {
          libraries: facetLibrary,
        });
      } else {
        factory = await ethers.getContractFactory(facet);
      }

      const facetInstance = await factory.deploy(...constructorArgs);
      await facetInstance.deployed();
      const tx = facetInstance.deployTransaction;
      const receipt = await tx.wait();
      if (verbose) {
        console.log(`${facet} deploy gas used: ` + strDisplay(receipt.gasUsed));
      }
        
      totalGasUsed = totalGasUsed.add(receipt.gasUsed);
      instances.push(facetInstance);
    }
    return instances;
  }

  let [
    seasonFacet,
    oracleFacet,
    fieldFacet,
    siloFacet,
    systemFacet,
    claimFacet,
    marketplaceFacet,
    convertFacet,
  ] = mock
    ? await deployFacets(
        verbose,
        [
          "MockSeasonFacet",
          "MockOracleFacet",
          "MockFieldFacet",
          "MockSiloFacet",
          "MockSystemFacet",
          "MockClaimFacet",
          "MockMarketplaceFacet",
          "MockConvertFacet",
        ],
        ["LibClaim"],
        {
          MockMarketplaceFacet: ["LibClaim"],
          MockSiloFacet: ["LibClaim"],
          MockFieldFacet: ["LibClaim"],
          MockClaimFacet: ["LibClaim"],
          MockConvertFacet: ["LibClaim"],
        }
      )
    : await deployFacets(
        verbose,
        [
          "SeasonFacet",
          "OracleFacet",
          "FieldFacet",
          "SiloFacet",
          "SystemFacet",
          "ClaimFacet",
          "MarketplaceFacet",
          "ConvertFacet",
        ],
        ["LibClaim"],
        {
          SiloFacet: ["LibClaim"],
          FieldFacet: ["LibClaim"],
          ClaimFacet: ["LibClaim"],
          ConvertFacet: ["LibClaim"],
          MarketplaceFacet: ["LibClaim"],
        }
      );

  const initDiamondArg = mock
    ? "contracts/mocks/MockInitDiamond.sol:MockInitDiamond"
    : "contracts/farm/init/InitDiamond.sol:InitDiamond";

  let args = [];
  if (mock) {
    args.push(await impersonateTopcorn());
    args.push(await impersonatePool());
    args.push(await impersonateRouter());
  }

  const [farmDiamond, diamondCut] = await diamond.deploy({
    diamondName: "FarmDiamond",
    initDiamond: initDiamondArg,
    facets: [
      ["SeasonFacet", seasonFacet],
      ["OracleFacet", oracleFacet],
      ["FieldFacet", fieldFacet],
      ["SiloFacet", siloFacet],
      ["SystemFacet", systemFacet],
      ["ClaimFacet", claimFacet],
      ["MarketplaceFacet", marketplaceFacet],
      ["ConvertFacet", convertFacet],
    ],
    owner: account,
    args: args,
    verbose: verbose,
  });

  tx = farmDiamond.deployTransaction;
  receipt = await tx.wait();

  if (verbose) {
    console.log("Farm diamond deploy gas used: " + strDisplay(receipt.gasUsed));
    console.log("Farm diamond cut gas used: " + strDisplay(diamondCut.gasUsed));
  }    

  totalGasUsed = totalGasUsed.add(receipt.gasUsed).add(diamondCut.gasUsed);

  const season = await ethers.getContractAt("SeasonFacet", farmDiamond.address);
  const topcorn = await season.topcorn();
  const pair = await season.pair();
  const pegPair = await season.pegPair();
  const silo = await ethers.getContractAt("SiloFacet", farmDiamond.address);
  const wbnb = await silo.wbnb();

  if (verbose) {
    console.log("--");
    console.log("Farmer diamond address:" + farmDiamond.address);
    console.log("TopCorn address:" + topcorn);
    console.log("Pancake Pair address:" + pair);
    console.log("--");
  }

  const diamondLoupeFacet = await ethers.getContractAt(
    "DiamondLoupeFacet",
    farmDiamond.address
  );

  if (verbose) {
    console.log("Total gas used: " + strDisplay(totalGasUsed));
  }

  return {
    account: account,
    farmDiamond: farmDiamond,
    diamondLoupeFacet: diamondLoupeFacet,
    seasonFacet: seasonFacet,
    oracleFacet: oracleFacet,
    fieldFacet: fieldFacet,
    siloFacet: siloFacet,
    governanceFacet: systemFacet,
    claimFacet: claimFacet,
    convertFacet: convertFacet,
    pair: pair,
    pegPair: pegPair,
    wbnb: wbnb,
    topcorn: topcorn,
  };
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
exports.deploy = main;

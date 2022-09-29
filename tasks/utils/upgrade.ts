import { task } from "hardhat/config";
import { upgradeWithNewFacets } from "../../scripts/diamond";
import { deployPropose } from "../../scripts/propose-upgrade";

// npx hardhat upgrade
task("upgrade", "Commits a Improvement Proposals")
  .setAction(async (taskArgs, hre) => {
    const account = await hre.run("account");
    const diamondAddress = await hre.run("gca", { contractName: 'diamond' });

    await upgradeWithNewFacets({
      diamondAddress: diamondAddress,
      initFacetName: "",
      facetNames: ["MarketplaceFacet", "SeasonFacet", "SiloFacet", "ClaimFacet", "OracleFacet"],
      libraryNames: ['LibClaim'],
      facetLibraries: {
        MarketplaceFacet: 'LibClaim',
        SiloFacet: 'LibClaim',
        ClaimFacet: 'LibClaim',
      },
      bip: false,
      verbose: true,
      account: account
    });
  })

// npx hardhat newPropose
task("newPropose", "deploy facets or init")
  .setAction(async (taskArgs, hre) => {
    //const diamondAddress = await hre.run("gca", { contractName: 'diamond' });
    const diamondAddress = "0x758DA0A25aB827f8Cf90Cf696276037d5d0a72B4";

    await deployPropose({
      diamondAddress: diamondAddress,
      initFacetName: "",
      facetNames: ["MarketplaceFacet"],
      libraryNames: ['LibClaim',],
      facetLibraries: {
        MarketplaceFacet: 'LibClaim',
      },
      verbose: true,
    });
  })

/*
  await deployPropose({
    diamondAddress: diamondAddress,
    initFacetName: "InitLiquidity",
    facetNames: [],
    libraryNames: [],
    facetLibraries: {
    },
    verbose: true,
  });
*/

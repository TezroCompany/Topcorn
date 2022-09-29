

const FacetCutAction = {
  Add: 0,
  Replace: 1,
  Remove: 2
}

function addCommas(nStr) {
  nStr += ''
  const x = nStr.split('.')
  let x1 = x[0]
  const x2 = x.length > 1 ? '.' + x[1] : ''
  var rgx = /(\d+)(\d{3})/
  while (rgx.test(x1)) {
    x1 = x1.replace(rgx, '$1' + ',' + '$2')
  }
  return x1 + x2
}

function strDisplay(str) {
  return addCommas(str.toString())
}

function getSelectors(contract) {
  const signatures = Object.keys(contract.interface.functions)
  const selectors = signatures.reduce((acc, val) => {
    if (val !== 'init(bytes)' && val !== 'c_0x4820c4cf(bytes32)') {
      acc.push(contract.interface.getSighash(val))
    }
    return acc
  }, [])
  return selectors
}

function inFacets (selector, facets) {
  for (const facet of facets) {
    if (facet.functionSelectors.includes(selector)) {
      return true
    }
  }
  return false
}

async function deployPropose({
  diamondAddress,
  facetNames,
  facetLibraries = {},
  libraryNames = [],
  selectorsToRemove = [],
  selectorsToAdd = {},
  initFacetName,
  initArgs = [],
  libraries = {},
  initFacetAddress = ethers.constants.AddressZero,
  object = false,
  verbose = false,
}) {

  if (!initFacetName) {
    initFacetName = undefined
  }

  let totalGasUsed = ethers.BigNumber.from('0')

  if (arguments.length !== 1) {
    throw Error(`Requires only 1 map argument. ${arguments.length} arguments used.`)
  }
  const diamondLoupeFacet = await ethers.getContractAt('DiamondLoupeFacet', diamondAddress)

  const diamondCut = []
  const existingFacets = await diamondLoupeFacet.facets()
  const undeployed = []
  const deployed = []
  if (verbose) console.log('Deploying Libraries')
  for (const name of libraryNames) {
    if (!Object.keys(libraries).includes(name)) {
      if (verbose) console.log(`Deploying: ${name}`)
      let libraryFactory = await ethers.getContractFactory(name)
      libraryFactory = await libraryFactory.deploy()
      await libraryFactory.deployed()
      const receipt = await libraryFactory.deployTransaction.wait()
      if (verbose) console.log(`${name} deploy gas used: ` + strDisplay(receipt.gasUsed))
      totalGasUsed = totalGasUsed.add(receipt.gasUsed)
      if (verbose) console.log(`Deployed at ${libraryFactory.address}`)
      libraries[name] = libraryFactory.address
    }
  }
  if (verbose) console.log('\nDeploying Facets')
  for (const name of facetNames) {
    let facetFactory
    if (facetLibraries[name] !== undefined) {
      let facetLibrary = Object.keys(libraries).reduce((acc, val) => {
        if (facetLibraries[name].includes(val)) acc[val] = libraries[val];
        return acc;
      }, {});
      facetFactory = await ethers.getContractFactory(name, {
        libraries: facetLibrary
      },
      );
    }
    else facetFactory = await ethers.getContractFactory(name)
    undeployed.push([name, facetFactory])
  }
  if (verbose) console.log('')
  if (selectorsToRemove.length > 0) {
    // check if any selectorsToRemove are already gone
    for (const selector of selectorsToRemove) {
      if (!inFacets(selector, existingFacets)) {
        throw Error('Function selector to remove is already gone.')
      }
    }
    diamondCut.push([
      ethers.constants.AddressZero,
      FacetCutAction.Remove,
      selectorsToRemove
    ])
  }

  for (const [name, facetFactory] of undeployed) {
    if (verbose) console.log(`Deploying ${name}`)
    deployed.push([name, await facetFactory.deploy()])
  }

  for (const [name, deployedFactory] of deployed) {
    if (verbose) console.log(`${name} hash: ${deployedFactory.deployTransaction.hash}`);
    await deployedFactory.deployed()
    const receipt = await deployedFactory.deployTransaction.wait()
    if (verbose) console.log(`${name} deploy gas used: ` + strDisplay(receipt.gasUsed))
    totalGasUsed = totalGasUsed.add(receipt.gasUsed)
    if (verbose) console.log(`${name} deployed: ${deployedFactory.address}`)
    if (verbose) console.log('--')
    const add = []
    const replace = []
    const selectors = selectorsToAdd[name] !== undefined ? selectorsToAdd[name] : getSelectors(deployedFactory)
    for (const selector of selectors) {
      if (!inFacets(selector, existingFacets)) {
        add.push(selector)
      } else {
        replace.push(selector)
      }
    }
    if (add.length > 0) {
      diamondCut.push([deployedFactory.address, FacetCutAction.Add, add])
    }
    if (replace.length > 0) {
      diamondCut.push([
        deployedFactory.address,
        FacetCutAction.Replace,
        replace
      ])
    }
  }
  if (verbose) {
    console.log('diamondCut arg:')
    console.log(diamondCut)
    console.log('------')
  }

  let functionCall = '0x'
  if (initFacetName !== undefined) {
    let initFacet
    for (const [name, deployedFactory] of deployed) {
      if (name === initFacetName) {
        initFacet = deployedFactory
        const receipt = await deployedFactory.deployTransaction.wait()
        if (verbose) console.log(`${name} deploy gas used: ` + strDisplay(receipt.gasUsed))
        totalGasUsed = totalGasUsed.add(receipt.gasUsed)
        break
      }
    }

    if (initFacetAddress !== ethers.constants.AddressZero) {
      initFacet = await ethers.getContractAt('InitFundraiser', initFacetAddress);
    }
    if (!initFacet) {
      const InitFacet = await ethers.getContractFactory(initFacetName)
      initFacet = await InitFacet.deploy()
      await initFacet.deployed()
      const receipt = await initFacet.deployTransaction.wait()
      if (verbose) console.log(`Init Diamond deploy gas used: ` + strDisplay(receipt.gasUsed))
      totalGasUsed = totalGasUsed.add(receipt.gasUsed)
      if (verbose) console.log('Deployed init facet: ' + initFacet.address)
    } else {
      if (verbose) console.log('Using init facet: ' + initFacet.address)
    }
    functionCall = initFacet.interface.encodeFunctionData('init', initArgs)
    if (verbose) console.log(`Function call: ${functionCall}`)
    initFacetAddress = initFacet.address
  }
  let result;
  if (object) {
    return {
      diamondCut: diamondCut,
      initFacetAddress: initFacetAddress,
      functionCall: functionCall
    }
  }

  if (verbose) {
    console.log("gnosis-safe-multisig:\n");
    console.log(`\nContract address:`)
    console.log(diamondAddress)
    console.log(`\nABI:`)
    console.log(ABI_diamondCut)
    console.log(`\n_diamondCut:`)
    console.log(diamondCut)
    console.log(`\n_init:`)
    console.log(initFacetAddress)
    console.log(`\n_calldata:`)
    console.log(functionCall)
  }
  return result
}

exports.FacetCutAction = FacetCutAction
exports.deployPropose = deployPropose
exports.getSelectors = getSelectors
exports.inFacets = inFacets


const ABI_diamondCut =
`
[
 {
   "inputs": [
     {
       "components": [
         {
           "internalType": "address",
           "name": "facetAddress",
           "type": "address"
         },
         {
           "internalType": "enum IDiamondCut.FacetCutAction",
           "name": "action",
           "type": "uint8"
         },
         {
           "internalType": "bytes4[]",
           "name": "functionSelectors",
           "type": "bytes4[]"
         }
       ],
       "internalType": "struct IDiamondCut.FacetCut[]",
       "name": "_diamondCut",
       "type": "tuple[]"
     },
     {
       "internalType": "address",
       "name": "_init",
       "type": "address"
     },
     {
       "internalType": "bytes",
       "name": "_calldata",
       "type": "bytes"
     }
   ],
   "name": "diamondCut",
   "outputs": [],
   "stateMutability": "nonpayable",
   "type": "function"
 }
]
`
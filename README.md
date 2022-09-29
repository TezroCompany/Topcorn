# TopCorn - Algorithmic stablecoin (Beanstalk-fork)

- [Official docs Topcorn](https://topcorn.gitbook.io/docs/)

## Installation
```bash
$ nvm use
```

```bash
$ npm install
```

## Development

### Creating smart contract
Create your smart contract in `contracts/farm/facets/` folder 

### Compilation
Set solidity version in hardhat.config.ts file, solidity -> compilers -> version, then run compilation

```bash
$ npx hardhat compile  
```

### Deploy
Run deploy in hardhat network
```bash
$ npm run deploy
```

Run deploy in ropsten network
```bash
$ npm run deploy:ropsten 
```

Run deploy in bsc testnet network (chapel)
```bash
$ npm run deploy:testnetBNB 
```

Run deploy in bsc mainnet network (bsc)
```bash
$ npm run deploy:mainnetBNB 
```

### Verification contract  

Run verify in ropsten network
```bash
$ npm run verify:mainnetBNB
```
## Useful links
1. Hardhat documentation:
https://hardhat.org/getting-started/
2. Style Guide:
https://docs.soliditylang.org/en/v0.8.13/style-guide.html#style-guide
3. Common Patterns:
https://docs.soliditylang.org/en/v0.8.13/common-patterns.html
4. Security Considerations:
https://docs.soliditylang.org/en/v0.8.13/security-considerations.html#security-considerations

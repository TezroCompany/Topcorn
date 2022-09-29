import fs from "fs"
import { task } from "hardhat/config"

task("diamondABI", "Generates ABI file for diamond, includes all ABIs of facets", async () => {
    const basePath = "/contracts/farm/facets/"
    let files = fs.readdirSync("." + basePath)
    let abi = []

    for (let file of files) {
        let jsonFile
        if (file.includes("Facet")) {
            if (!file.includes(".sol")) {
                jsonFile = `${file}.json`
                file = `${file}/${file}.sol`
            } else {
                jsonFile = file.replace("sol", "json")
            }
            const json = fs.readFileSync(`./artifacts${basePath}${file}/${jsonFile}`, "utf-8")
            const jsonAbi = JSON.parse(json)
            abi.push(...jsonAbi.abi)
        }
    }
    const abiFile = JSON.stringify(abi)
    fs.writeFileSync("./diamondAbi.json", abiFile)
    console.log("ABI written to ./diamondAbi.json")
})

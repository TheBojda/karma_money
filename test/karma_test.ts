import { ethers } from "hardhat";
import { Karma } from "../typechain-types";
import { assert } from "chai";

describe("Karma Smart contract test", () => {

    let contract: Karma

    let MINER: any
    let ALICE: any
    let JOHN: any
    let PETER: any

    async function showBalances() {
        console.log(`balance of ALICE: ${await contract.balanceOf(ALICE.address)}`)
        console.log(`balance of JOHN: ${await contract.balanceOf(JOHN.address)}`)
        console.log(`balance of PETER: ${await contract.balanceOf(PETER.address)}`)
        console.log(`debt of ALICE -> JOHN: ${await contract.debtOf(ALICE.address, JOHN.address)}`)
        console.log(`debt of ALICE -> PETER: ${await contract.debtOf(ALICE.address, PETER.address)}`)
        console.log(`debt of JOHN -> ALICE: ${await contract.debtOf(JOHN.address, ALICE.address)}`)
        console.log(`debt of JOHN -> PETER: ${await contract.debtOf(JOHN.address, PETER.address)}`)
        console.log(`debt of PETER -> ALICE: ${await contract.debtOf(PETER.address, ALICE.address)}`)
        console.log(`debt of PETER -> JOHN: ${await contract.debtOf(PETER.address, JOHN.address)}`)
    }

    before(async () => {
        const signers = await ethers.getSigners()
        MINER = signers[0]
        ALICE = signers[1]
        JOHN = signers[2]
        PETER = signers[3]

        const Karma = await ethers.getContractFactory("Karma");
        contract = await Karma.deploy("Karma USD", "kUSD", 0);
    })

    it("Moving 10 kUSD from ALICE to JOHN", async () => {
        await contract.connect(ALICE).transfer(JOHN.address, 10)
        await showBalances()
        assert.equal(await contract.balanceOf(ALICE.address), ethers.toBigInt(10))
    })

    it("Moving 10 kUSD from JOHN to PETER", async () => {
        await contract.connect(JOHN).transfer(PETER.address, 10)
        await showBalances()
        assert.equal(await contract.balanceOf(JOHN.address), ethers.toBigInt(10))
    })


    it("Moving 10 kUSD from PETER to ALICE", async () => {
        await contract.connect(PETER).transfer(ALICE.address, 10)
        await showBalances()
        assert.equal(await contract.balanceOf(PETER.address), ethers.toBigInt(10))
    })

    it("Mine the cycle", async () => {
        await contract.mineCycle([ALICE.address, JOHN.address, PETER.address], 10)
        await showBalances()
        assert.equal(await contract.balanceOf(ALICE.address), ethers.toBigInt(0))
        assert.equal(await contract.balanceOf(JOHN.address), ethers.toBigInt(0))
        assert.equal(await contract.balanceOf(PETER.address), ethers.toBigInt(0))
    })

})
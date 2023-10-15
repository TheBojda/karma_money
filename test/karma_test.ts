import { ethers } from "hardhat";
import { Karma } from "../typechain-types";
import { assert } from "chai";
import { SignTypedDataVersion, recoverTypedSignature } from "@metamask/eth-sig-util"
import { toBigInt } from "ethers";

describe("Karma Smart contract test", () => {

    let contract: Karma

    let MINER: any
    let ALICE: any
    let JOHN: any
    let PETER: any

    let karma_request_domain: any

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
        contract = await Karma.deploy("Karma USD", "kUSD");

        karma_request_domain = {
            "name": "Karma Request",
            "version": "1",
            "chainId": 31337,
            "verifyingContract": await contract.getAddress()
        }
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
        await contract.connect(MINER).mineCycle([ALICE.address, JOHN.address, PETER.address])
        await showBalances()
        assert.equal(await contract.balanceOf(ALICE.address), ethers.toBigInt(0))
        assert.equal(await contract.balanceOf(JOHN.address), ethers.toBigInt(0))
        assert.equal(await contract.balanceOf(PETER.address), ethers.toBigInt(0))
    })

    const EIP712Domain = {
        "EIP712Domain": [
            {
                "name": "name",
                "type": "string"
            },
            {
                "name": "version",
                "type": "string"
            },
            {
                "name": "chainId",
                "type": "uint256"
            },
            {
                "name": "verifyingContract",
                "type": "address"
            }
        ]
    }

    it("Meta transfer request for 10 kUSD from ALICE to JOHN", async () => {
        const types = {
            "TransferRequest": [
                {
                    "name": "to",
                    "type": "address"
                },
                {
                    "name": "amount",
                    "type": "uint256"
                }
            ]
        }
        const message = {
            "to": JOHN.address,
            "amount": 10
        }

        const signature = await ALICE.signTypedData(karma_request_domain, types, message)

        const recorveredAddress = recoverTypedSignature({
            data: {
                "types": {
                    ...EIP712Domain,
                    ...types
                },
                "primaryType": "TransferRequest",
                "domain": karma_request_domain,
                "message": message
            },
            signature: signature,
            version: SignTypedDataVersion.V4
        })
        assert.equal(recorveredAddress.toLowerCase(), ALICE.address.toLowerCase())
    })

    it("Meta transfer for 10 kUSD from ALICE to JOHN, executed by MINER", async () => {
        const types = {
            "TransferRequest": [
                {
                    "name": "from",
                    "type": "address"
                },
                {
                    "name": "to",
                    "type": "address"
                },
                {
                    "name": "amount",
                    "type": "uint256"
                },
                {
                    "name": "nonce",
                    "type": "uint256"
                }
            ]
        }

        let nonce = await contract.connect(MINER).getNonce(ALICE.address)
        const message = {
            "from": ALICE.address,
            "to": JOHN.address,
            "amount": 10,
            "nonce": nonce
        }

        const signature = await ALICE.signTypedData(karma_request_domain, types, message)
        await contract.connect(MINER).metaTransfer(ALICE.address, JOHN.address, 10, nonce, signature)
        await showBalances()
        assert.equal(await contract.balanceOf(ALICE.address), ethers.toBigInt(10))
    })

    it("Meta approve for 10 kUSD from ALICE to JOHN, executed by MINER", async () => {
        const types = {
            "ApproveRequest": [
                {
                    "name": "owner",
                    "type": "address"
                },
                {
                    "name": "spender",
                    "type": "address"
                },
                {
                    "name": "amount",
                    "type": "uint256"
                },
                {
                    "name": "nonce",
                    "type": "uint256"
                }
            ]
        }

        let nonce = await contract.connect(MINER).getNonce(ALICE.address)
        const message = {
            "owner": ALICE.address,
            "spender": JOHN.address,
            "amount": 10,
            "nonce": nonce
        }

        const signature = await ALICE.signTypedData(karma_request_domain, types, message)
        await contract.connect(MINER).metaApprove(ALICE.address, JOHN.address, 10, nonce, signature)
        let allowance = await contract.allowance(ALICE.address, JOHN.address);
        assert.equal(allowance, toBigInt(10));
    })

    it("Meta set cycle reward to 1 kUSD for ALICE, executed by MINER", async () => {
        const types = {
            "SetCycleRewardRequest": [
                {
                    "name": "owner",
                    "type": "address"
                },
                {
                    "name": "amount",
                    "type": "uint256"
                },
                {
                    "name": "nonce",
                    "type": "uint256"
                }
            ]
        }

        let nonce = await contract.connect(MINER).getNonce(ALICE.address)
        const message = {
            "owner": ALICE.address,
            "amount": 1,
            "nonce": nonce
        }

        const signature = await ALICE.signTypedData(karma_request_domain, types, message)
        await contract.connect(MINER).metaSetCycleReward(ALICE.address, 1, nonce, signature)
        let reward = await contract.cycleRewardOf(ALICE.address)
        assert.equal(reward, toBigInt(1));
    })

})
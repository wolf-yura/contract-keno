const GBTS = artifacts.require("GBTS");
const ULP = artifacts.require("UnifiedLiquidityPool");
const Keno = artifacts.require("Keno");
const RNG = artifacts.require("RandomNumberConsumer");

const { assert } = require("chai");
const { BN } = require("web3-utils");
const timeMachine = require('ganache-time-traveler');

contract("Keno", (accounts) => {
    let gbts_contract, ulp_contract, keno_contract, rng_contract;

    before(async () => {
        await GBTS.new(
            { from: accounts[0] }
        ).then((instance) => {
            gbts_contract = instance;
        });

        await RNG.new(
            "0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9",   // Chainlink VRF Coordinator address
            "0xa36085F69e2889c224210F603D836748e7dC0088",   // LINK token address
            "0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4",   // Key Hash
            1, // fee
            { from: accounts[0] }
        ).then((instance) => {
            rng_contract = instance;
        });

        await ULP.new(
            gbts_contract.address,
            rng_contract.address,
            { from: accounts[0] }
        ).then((instance) => {
            ulp_contract = instance;
        });

        await Keno.new(
            ulp_contract.address,
            gbts_contract.address,
            4,
            { from: accounts[0] }
        ).then((instance) => {
            keno_contract = instance;
        });

        await gbts_contract.transfer(accounts[1], new BN('1000000000000000000000000'), { from: accounts[0] }); // Win Account 1000000 GBTS
        await gbts_contract.transfer(accounts[2], new BN('1000000000000000000000000'), { from: accounts[0] }); // Lose Account 1000000 GBTS
        await gbts_contract.transfer(ulp_contract.address, new BN('100000000000000000000000'), { from: accounts[0] }); //  100000 GBTS

        await gbts_contract.approve(ulp_contract.address, new BN('10000000000000000000000'), { from: accounts[0] }); // 1000GBTS

        await ulp_contract.startStaking(
            new BN('1000000000000000000000'), //1000 GBTS
            { from: accounts[0] }
        );

        await ulp_contract.unlockGameForApproval(
            keno_contract.address,
            { from: accounts[0] }
        );

        await timeMachine.advanceTimeAndBlock(86400);

        await ulp_contract.changeGameApproval(
            keno_contract.address,
            true,
            { from: accounts[0] }
        );
        await rng_contract.setULPAddress(ulp_contract.address);
    });

});

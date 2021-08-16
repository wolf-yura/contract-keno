const GBTS = artifacts.require("GBTS");
const ULP = artifacts.require("UnifiedLiquidityPool");
const Keno = artifacts.require("Keno");
const RNG = artifacts.require("RandomNumberConsumer");

const { assert } = require("chai");
const { BN } = require("web3-utils");
const timeMachine = require('ganache-time-traveler');

contract("Keno", (accounts) => {
    let gbts_contract, ulp_contract, keno_contract, rng_contract;
    const outRangeTicketNumbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    const ticket1Numbers = [32, 4, 10, 27, 1];
    const ticket2Numbers = [1, 11, 22];
    const ticket3Numbers = [3, 5, 7, 11, 9, 15, 23, 41, 33, 55];
    const ticket4Numbers = [10, 20, 50, 30];

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

        await gbts_contract.transfer(accounts[1], new BN('100000000000000000000'), { from: accounts[0] }); //  Account1 100 GBTS
        await gbts_contract.transfer(accounts[2], new BN('100000000000000000000'), { from: accounts[0] }); //  Account2 100 GBTS
        await gbts_contract.transfer(ulp_contract.address, new BN('1000000000000000000000'), { from: accounts[0] }); //  1000 GBTS

        await gbts_contract.approve(ulp_contract.address, new BN('1000000000000000000000'), { from: accounts[0] }); // 1000 GBTS
        await gbts_contract.approve(keno_contract.address, new BN('100000000000000000000'), { from: accounts[1] });
        await gbts_contract.approve(keno_contract.address, new BN('100000000000000000000'), { from: accounts[2] });

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
    describe("Buy Tickets", () => {

        it("Buying tickets is not working with out of number range.", async () => {
            let thrownError;
            try {
                await keno_contract.buyTicket(
                    outRangeTicketNumbers,
                    { from: accounts[1] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'Keno: Every ticket should have 1 to 11 numbers.',
            )
        });


        it("Buying tickets is working", async () => {
            await keno_contract.buyTicket(ticket1Numbers, { from: accounts[1] });
            // await keno_contract.buyTicket(ticket2Numbers, { from: accounts[1] }); 
            // await keno_contract.buyTicket(ticket3Numbers, { from: accounts[2] }); 
            // await keno_contract.buyTicket(ticket4Numbers, { from: accounts[2] }); 

            // assert.equal(new BN(await gbts_contract.balanceOf(accounts[1])).toString(), new BN('99000000000000000000').toString());
            // assert.equal(new BN(await gbts_contract.balanceOf(accounts[2])).toString(), new BN('99000000000000000000').toString());
        });
    });
});

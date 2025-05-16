const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("VickreyAuction", function () {
    let auction;
    let owner, bidder1;
    const maxPrice = ethers.parseEther("10");
    const auctionDuration = 1000;

    before(async () => {
        [owner, bidder1] = await ethers.getSigners();
    });

    beforeEach(async () => {
        const startTime = (await time.latest()) + 100;
        const endTime = startTime + auctionDuration;
        
        const VickreyAuction = await ethers.getContractFactory("VickreyAuction");
        auction = await VickreyAuction.deploy(
            startTime, 
            endTime, 
            maxPrice, 
            { value: maxPrice }
        );
    });

    it("Singolo partecipante vince e conferma consegna", async () => {
        // Avanza al tempo di inizio asta
        await time.increaseTo((await auction.startTime()) + 1);
        
        const bidAmount = ethers.parseEther("5");
        const requiredDeposit = bidAmount / 10n;
        
        await auction.connect(bidder1).bid(bidAmount, { value: requiredDeposit });
        
        // Avanza alla fine dell'asta
        await time.increaseTo(await auction.endTime());
        await auction.finalizeAuction();

        expect(await auction.winner()).to.equal(bidder1.address);
        await expect(auction.confirmDelivery())
            .to.emit(auction, "DeliveryConfirmed");
    });

    it("Verifica deposito insufficiente", async () => {
        await time.increaseTo((await auction.startTime()) + 1);
        
        const bidAmount = ethers.parseEther("5");
        const insufficientDeposit = bidAmount / 10n - ethers.parseEther("0.01");
        
        await expect(
            auction.connect(bidder1).bid(bidAmount, { value: insufficientDeposit })
        ).to.be.revertedWith("Deposito insuficiente");
    });
});
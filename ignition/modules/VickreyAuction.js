const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VickreyAuction", function () {
  let auction, owner, bidder1, bidder2;
  const maxBidAllowed = ethers.utils.parseEther("10");

  // helper per avanzare il tempo
  async function increaseTime(sec) {
    await ethers.provider.send("evm_increaseTime", [sec]);
    await ethers.provider.send("evm_mine", []);
  }

  beforeEach(async () => {
    [owner, bidder1, bidder2] = await ethers.getSigners();
    const block = await ethers.provider.getBlock("latest");
    const now   = block.timestamp;
    const start = now - 10;
    const end   = now + 1000;

    const F = await ethers.getContractFactory("VickreyAuction");
    auction = await F.deploy(maxBidAllowed, start, end);
    await auction.deployed();
  });

  it("accepts a single valid bid and finalizes correctly", async () => {
    const bid1 = ethers.utils.parseEther("1.0"); // 1 ETH

    // 1) piazza l'offerta
    await expect(auction.connect(bidder1).placeBid({ value: bid1 }))
      .to.emit(auction, "BidPlaced")
      .withArgs(bidder1.address);

    // 2) avanzo il tempo oltre l'asta
    await increaseTime(2000);

    // 3) finalizzo e controllo l'evento + valori
    await expect(auction.connect(owner).finalizeAuction())
      .to.emit(auction, "AuctionFinalized")
      .withArgs(
        bidder1.address,
        bid1.mul(90).div(100),  // net = 0.9 ETH
        bid1.mul(90).div(100)   // secondLowest = 0.9 ETH (solo 1 offerta)
      );

    expect(await auction.winner()).to.equal(bidder1.address);
    expect(await auction.secondLowestBid()).to.equal(bid1.mul(90).div(100));
  });

  it("finalizes with two bids and allows refunds", async () => {
    const bid1 = ethers.utils.parseEther("1.0"); // net = 0.9
    const bid2 = ethers.utils.parseEther("2.0"); // net = 1.8

    // 1) piazziamo le due offerte PRIMA di avanzare il tempo
    await auction.connect(bidder1).placeBid({ value: bid1 });
    await auction.connect(bidder2).placeBid({ value: bid2 });

    // 2) ora l'asta è scaduta
    await increaseTime(2000);

    // 3) finalizzo
    await auction.connect(owner).finalizeAuction();

    expect(await auction.winner()).to.equal(bidder1.address);
    expect(await auction.secondLowestBid()).to.equal(
      bid2.mul(90).div(100)
    );

    // 4) refund per il perdente
    const balBefore = await ethers.provider.getBalance(bidder2.address);
    const tx         = await auction.connect(bidder2).refundLosingBidders();
    const rc         = await tx.wait();
    const gasCost    = rc.gasUsed.mul(rc.effectiveGasPrice);
    const balAfter   = await ethers.provider.getBalance(bidder2.address);

    // rimborso = 2 ETH (1.8 + 0.2 di deposito)
    expect(balAfter.sub(balBefore).add(gasCost)).to.equal(bid2);

    // 5) doppio rimborso => revert “No bid”
    await expect(
      auction.connect(bidder2).refundLosingBidders()
    ).to.be.revertedWith("No bid");
  });
});
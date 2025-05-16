const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const maxBidAllowed = hre.ethers.parseEther("10");
  const now = Math.floor(Date.now() / 1000);
  const auctionStart = now + 60; // ⏳ tra 1 minuto
  const auctionEnd = now + 3600; // ⏰ finisce tra 1 ora

  const VickreyAuction = await hre.ethers.getContractFactory("VickreyAuction");
  const auction = await VickreyAuction.deploy(maxBidAllowed, auctionStart, auctionEnd);

  await auction.waitForDeployment();

  console.log("✅ VickreyAuction deployed to:", auction.target);
  console.log("ℹ️  Starts at:", auctionStart, "Ends at:", auctionEnd);

  fs.writeFileSync(
    "address.json",
    JSON.stringify(
      {
        address: auction.target,
        auctionStart,
        auctionEnd
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error("❌ Error deploying:", error);
  process.exitCode = 1;
});

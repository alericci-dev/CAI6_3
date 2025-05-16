const hre = require("hardhat");
const { ethers } = hre;
const fs = require("fs");

async function main() {
  const CONTRACT_ADDRESS = "INSERISCI_L_INDIRIZZO_DEL_CONTRATTO";
  const [caller] = await ethers.getSigners();

  const contractArtifact = JSON.parse(
    fs.readFileSync("artifacts/contracts/VickreyAuction.sol/VickreyAuction.json")
  );
  const auction = new ethers.Contract(CONTRACT_ADDRESS, contractArtifact.abi, caller);

  const allBidders = await auction.getAllBidders();

  console.log("📋 Offerte registrate:");
  for (const addr of allBidders) {
    const [amount, deposit] = await auction.getBid(addr);
    console.log(`🧾 ${addr} - Bid: ${ethers.formatEther(amount)} ETH - Deposito: ${ethers.formatEther(deposit)} ETH`);
  }

  const winner = await auction.winner();
  console.log(`\n🏆 Vincitore: ${winner}`);
}

main().catch((error) => {
  console.error("❌ Errore:", error);
  process.exit(1);
});

const hre = require("hardhat");
const { ethers } = hre;
const fs = require("fs");

async function main() {
  const CONTRACT_ADDRESS = "INSERISCI_L_INDIRIZZO_DEL_CONTRATTO";
  const [owner] = await ethers.getSigners();

  const contractArtifact = JSON.parse(
    fs.readFileSync("artifacts/contracts/VickreyAuction.sol/VickreyAuction.json")
  );
  const auction = new ethers.Contract(CONTRACT_ADDRESS, contractArtifact.abi, owner);

  const tx = await auction.finalizeAuction();
  await tx.wait();

  const winner = await auction.winner();
  const secondPrice = await auction.secondLowestBid();

  console.log(`🎉 Asta finalizzata!`);
  console.log(`🏆 Vincitore: ${winner}`);
  console.log(`💰 Prezzo da pagare: ${ethers.formatEther(secondPrice)} ETH`);
}

main().catch((error) => {
  console.error("❌ Errore:", error);
  process.exit(1);
});

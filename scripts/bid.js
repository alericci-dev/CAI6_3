const hre = require("hardhat");
const { ethers } = hre;
const fs = require("fs");

async function main() {
  const CONTRACT_ADDRESS = "INSERISCI_L_INDIRIZZO_DEL_CONTRATTO";
  const [signer] = await ethers.getSigners();

  const contractArtifact = JSON.parse(
    fs.readFileSync("artifacts/contracts/VickreyAuction.sol/VickreyAuction.json")
  );
  const auction = new ethers.Contract(CONTRACT_ADDRESS, contractArtifact.abi, signer);

  const bidEth = "2.2"; // Puoi cambiarlo
  const bidAmount = ethers.parseEther(bidEth);
  const deposit = bidAmount.div(10);
  const totalToSend = bidAmount.add(deposit);

  const tx = await auction.placeBid({ value: totalToSend });
  await tx.wait();

  console.log(`✅ Offerta piazzata: ${bidEth} ETH + deposito`);
}

main().catch((error) => {
  console.error("❌ Errore:", error);
  process.exit(1);
});

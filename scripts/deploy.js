// scripts/deploy.js
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // deployContract automatically deploys and returns the contract instance
  const amm = await ethers.deployContract("MealCoinAMM", [deployer.address]);
  // Wait for the contract to be fully deployed on-chain
  await amm.waitForDeployment();

  console.log("MealCoinAMM deployed to:", await amm.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});

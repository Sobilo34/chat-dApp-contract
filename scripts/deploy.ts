import { ethers } from "hardhat";

async function main() {
  console.log("Deploying Web3Chat contracts...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  // Deploy ENS contract
  console.log("Deploying Web3ChatENS...");
  const Web3ChatENS = await ethers.getContractFactory("Web3ChatENS");
  const ensContract = await Web3ChatENS.deploy();
  await ensContract.waitForDeployment();
  const ensAddress = await ensContract.getAddress();
  console.log("Web3ChatENS deployed to:", ensAddress);

  // Deploy Registry contract
  console.log("Deploying Web3ChatRegistry...");
  const Web3ChatRegistry = await ethers.getContractFactory("Web3ChatRegistry");
  const registryContract = await Web3ChatRegistry.deploy(ensAddress);
  await registryContract.waitForDeployment();
  const registryAddress = await registryContract.getAddress();
  console.log("Web3ChatRegistry deployed to:", registryAddress);

  // Deploy Chat contract
  console.log("Deploying Web3ChatMessaging...");
  const Web3ChatMessaging = await ethers.getContractFactory("Web3ChatMessaging");
  const chatContract = await Web3ChatMessaging.deploy(registryAddress);
  await chatContract.waitForDeployment();
  const chatAddress = await chatContract.getAddress();
  console.log("Web3ChatMessaging deployed to:", chatAddress);

  // Deploy Multicall contract
  console.log("Deploying Web3ChatMulticall...");
  const Web3ChatMulticall = await ethers.getContractFactory("Web3ChatMulticall");
  const multicallContract = await Web3ChatMulticall.deploy();
  await multicallContract.waitForDeployment();
  const multicallAddress = await multicallContract.getAddress();
  console.log("Web3ChatMulticall deployed to:", multicallAddress);

  console.log("\n--- Deployment Summary ---");
  console.log("Web3ChatENS:", ensAddress);
  console.log("Web3ChatRegistry:", registryAddress);
  console.log("Web3ChatMessaging:", chatAddress);
  console.log("Web3ChatMulticall:", multicallAddress);
  
  // Save deployment addresses to a file for frontend use
  const deploymentInfo = {
    network: "localhost", // Change based on deployment network
    chainId: 1337, // Change based on deployment network
    contracts: {
      Web3ChatENS: ensAddress,
      Web3ChatRegistry: registryAddress,
      Web3ChatMessaging: chatAddress,
      Web3ChatMulticall: multicallAddress
    },
    deployedAt: new Date().toISOString()
  };
  
  const fs = require('fs');
  fs.writeFileSync('./deployments.json', JSON.stringify(deploymentInfo, null, 2));
  console.log("\nDeployment info saved to deployments.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

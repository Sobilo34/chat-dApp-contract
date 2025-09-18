// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const Web3ChatModule = buildModule("Web3ChatModule", (m) => {
  // Deploy the simplified Web3ChatDApp contract
  const web3ChatDApp = m.contract("Web3ChatDApp", []);

  return { 
    web3ChatDApp
  };
});

export default Web3ChatModule;

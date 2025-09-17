// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const Web3ChatModule = buildModule("Web3ChatModule", (m) => {
  // 1. Deploy ENS contract first (no dependencies)
  const web3ChatENS = m.contract("Web3ChatENS", []);
  
  // 2. Deploy Registry contract with ENS contract address
  const web3ChatRegistry = m.contract("Web3ChatRegistry", [web3ChatENS]);
  
  // 3. Set the registry contract address in ENS contract for access control
  m.call(web3ChatENS, "setRegistryContract", [web3ChatRegistry]);
  
  // 4. Deploy Chat contract with Registry contract address
  const web3ChatMessaging = m.contract("Web3ChatMessaging", [web3ChatRegistry]);
  
  // 5. Deploy Multicall helper contract
  const web3ChatMulticall = m.contract("Web3ChatMulticall", []);

  return { 
    web3ChatENS,
    web3ChatRegistry, 
    web3ChatMessaging,
    web3ChatMulticall
  };
});

export default Web3ChatModule;

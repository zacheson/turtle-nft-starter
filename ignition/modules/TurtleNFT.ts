// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

const TurtleModule = buildModule("TrutleModule", (m) => {
  const lock = m.contract("TurtleTimepieceNFT")

  return { lock }
})

export default TurtleModule

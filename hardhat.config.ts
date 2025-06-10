import { HardhatUserConfig, task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import "@nomicfoundation/hardhat-toolbox"
import "hardhat-contract-sizer"
import dotenv from "dotenv"

/**
 * @dev Configure .env.
 */
dotenv.config()

/**
 * @dev Get the gas provider - deployer
 */
const DEPLOYER_KEY = process.env.DEPLOYER_KEY || ""

/**
 * @dev Get explorer API keys.
 */
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || ""
const BINANCE_API_KEY = process.env.BINANCE_API_KEY || ""
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || ""
const ARBISCAN_API_KEY = process.env.ARBISCAN_API_KEY || ""

/**
 * @dev Get the mainnet RPC urls.
 */
const ETHEREUM_RPC_URL = process.env.ETHEREUM_RPC_URL
const BINANCE_RPC_URL = process.env.BINANCE_RPC_URL
const POLYGON_RPC_URL = process.env.POLYGON_RPC_URL
const ARBITRUM_RPC_URL = process.env.ARBITRUM_RPC_URL

/**
 * @dev Get the testnet RPC urls.
 */
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL
const BNBTEST_RPC_URL = process.env.BNBTEST_RPC_URL
const AMOY_RPC_URL = process.env.AMOY_RPC_URL
const ARBI_SEPOLIA_RPC_URL = process.env.ARBI_SEPOLIA_RPC_URL

/**
 * @dev Export the configuration.
 */
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  etherscan: {
    apiKey: {
      ethereum: ETHERSCAN_API_KEY,
      binance: BINANCE_API_KEY,
      polygon: POLYGONSCAN_API_KEY,
      arbitrum: ARBISCAN_API_KEY,
      sepolia: ETHERSCAN_API_KEY,
      bnbtest: BINANCE_API_KEY,
      amoy: POLYGONSCAN_API_KEY,
      arbsepolia: ARBISCAN_API_KEY,
    },
  },
  networks: {
    hardhat: {},
    ethereum: {
      url: ETHEREUM_RPC_URL,
      chainId: 1,
      accounts: [DEPLOYER_KEY],
    },

    binance: {
      url: BINANCE_RPC_URL,
      chainId: 56,
      accounts: [DEPLOYER_KEY],
    },

    polygon: {
      url: POLYGON_RPC_URL,
      chainId: 137,
      accounts: [DEPLOYER_KEY],
    },

    arbitrum: {
      url: ARBITRUM_RPC_URL,
      chainId: 42161,
      accounts: [DEPLOYER_KEY],
    },

    sepolia: {
      url: SEPOLIA_RPC_URL,
      chainId: 11155111,
      accounts: [DEPLOYER_KEY],
    },

    bnbtest: {
      url: BNBTEST_RPC_URL,
      chainId: 97,
      accounts: [DEPLOYER_KEY],
    },

    amoy: {
      url: AMOY_RPC_URL,
      chainId: 80002,
      accounts: [DEPLOYER_KEY],
    },

    arbsepolia: {
      url: ARBI_SEPOLIA_RPC_URL,
      chainId: 421614,
      accounts: [DEPLOYER_KEY],
    },
  },
  gasReporter: {
    enabled: true,
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
}

export default config

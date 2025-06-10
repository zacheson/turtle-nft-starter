# TurtleTimepieceNFT

**TurtleTimepieceNFT** is a Hardhat-based NFT smart contract project.  
Easily deploy your NFT collection to Ethereum Mainnet or Sepolia Testnet.

---

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/zacheson/turtle-nft-starter.git
cd TurtleTimepieceNFT
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Configure Environment Variables

Create a `.env` file using .env.example in the root directory and add your deployer wallet’s private key. (Do not remote any other keys.)  
**Make sure this wallet contains enough ETH for deployment gas fees.**

```env
DEPLOYER_KEY=your_private_key_here
```

> **Warning:** Never share your private key or commit it to version control.

---

## 🧑‍💻 Deploy the NFT Smart Contract

### Deploy to Ethereum Mainnet

```bash
npm run deploy:ethereum
```

### Deploy to Sepolia Testnet

```bash
npm run deploy:sepolia
```

---

## 🗂️ Project Structure

```
TurtleTimepieceNFT/
├── contracts/           # Solidity smart contracts
├── scripts/             # Deployment scripts
├── test/                # Unit tests
├── hardhat.config.js    # Hardhat configuration
├── package.json
└── .env                 # Environment variables (not committed)
```

---

## 📝 Notes

- Ensure your deployer wallet is funded with enough ETH for your chosen network.
- Modify deployment parameters in the `scripts/` folder as needed.
- For contract verification or advanced configuration, refer to the [Hardhat documentation](https://hardhat.org/getting-started/).

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

**Happy minting! 🐢⏰**

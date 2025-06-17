// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";

/**
 * @title TurtleTimepieceNFT
 * @dev ERC721 contract for the Turtle Timepiece NFT collection
 */
contract TurtleTimepieceNFT is ERC721URIStorage, Ownable, ReentrancyGuard, Pausable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    Counters.Counter private _tokenIds;
    
    // Maximum supply of NFTs
    uint256 public constant MAX_SUPPLY = 20;
    
    // Price per NFT in ETH
    uint256 public mintPrice = 0.001 ether;
    
    // IPFS folder CID
    string private constant IPFS_FOLDER = "QmUxwjKEFoWAmeCQfRBxhVsDar9CMpqBtCEHgpgW3nEE8M";
    
    // Maps each tokenId to the address of the user who purchased the NFT using Stripe payment.
    mapping(uint256 => address) public stripePaidUser;

    // Maps each tokenId to its sold status.
    mapping(uint256 => bool) public isTokenSold;
    
    // Events
    event NFTMinted(address owner, uint256 tokenId, string tokenURI);
    event NFTSold(address from, address to, uint256 tokenId, uint256 price);
    event TokenSoldWithStripe(uint256 tokenId, address user);
    event TokenSaleUpdated(uint256 tokenId, address oldBuyer, address newBuyer);
    event TokenClaimed(uint256 tokenId, address claimer);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);
    
    constructor() ERC721("Aquaduct", "Timeless") {
        // Pre-mint NFTs to the contract owner
        address owner = _msgSender();
        for(uint256 i = 1; i <= MAX_SUPPLY; i++) {
            _tokenIds.increment();
            _mint(owner, i);
            
            // Construct the full URI with .json extension
            string memory uri = string(
                abi.encodePacked(
                    "ipfs://",
                    IPFS_FOLDER,
                    "/",
                    Strings.toString(i),
                    ".json"
                )
            );
            
            console.log("Setting URI for token %s: %s", Strings.toString(i), uri);
            _setTokenURI(i, uri);
            emit NFTMinted(owner, i, uri);
        }
    }
    
    /**
     * @dev Returns the URI for a given token ID
     */
    function tokenURI(uint256 tokenId) public view virtual override(ERC721URIStorage) returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        require(tokenId <= MAX_SUPPLY, "Token ID exceeds maximum supply");
        
        string memory uri = string(
            abi.encodePacked(
                "ipfs://",
                IPFS_FOLDER,
                "/",
                Strings.toString(tokenId),
                ".json"
            )
        );
        
        console.log("Returning URI for token %s: %s", Strings.toString(tokenId), uri);
        return uri;
    }
    
    /**
     * @dev Set the sale price
     * @param newPrice New price in wei
     */
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    /**
     * @dev Put a token up for sale or remove it from sale
     * @param tokenId The token to modify sale status
     * @param user The user's address
     */
    function setStripePaidUser(uint256 tokenId, address user) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        require(!isTokenSold[tokenId], "Token already sold out");
        
        address oldBuyer = stripePaidUser[tokenId];
        stripePaidUser[tokenId] = user;
        
        if (oldBuyer == address(0) && user != address(0)) {
            emit TokenSoldWithStripe(tokenId, user);
        } else {
            emit TokenSaleUpdated(tokenId, oldBuyer, user);
        }
    }

    /**
     * @dev Claim a token (for Stripe purchases)
     * @param tokenId The token to claim
     */
    function claimToken(uint256 tokenId) external nonReentrant whenNotPaused {
        require(_exists(tokenId), "Token does not exist");
        require(msg.sender == stripePaidUser[tokenId], "Token is not available for claiming");
        require(!isTokenSold[tokenId], "Token already sold out");

        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner == owner(), "Token not owned by contract owner");
        
        _transfer(tokenOwner, msg.sender, tokenId);
        isTokenSold[tokenId] = true;
        
        emit TokenClaimed(tokenId, msg.sender);
    }

    /**
     * @dev Purchase an NFT with ETH
     * @param tokenId The token ID to purchase
     */
    function purchaseNFT(uint256 tokenId) external payable nonReentrant whenNotPaused {
        require(_exists(tokenId), "Token does not exist");
        require(!isTokenSold[tokenId], "Token already sold out");
        require(stripePaidUser[tokenId] == address(0), "Token already sold out via Stripe");
        require(msg.value >= mintPrice, "Insufficient ETH sent");
        
        address seller = ownerOf(tokenId);
        require(seller != msg.sender, "Cannot buy your own token");
        
        // Calculate excess ETH
        uint256 excess = msg.value - mintPrice;
        
        // Transfer the NFT
        _transfer(seller, msg.sender, tokenId);
        
        // Mark token as not for sale after purchase
        isTokenSold[tokenId] = true;
        
        // Transfer payment to the seller
        (bool success, ) = payable(owner()).call{value: mintPrice}("");
        require(success, "Payment to seller failed");
        
        // Refund excess ETH to buyer
        if (excess > 0) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: excess}("");
            require(refundSuccess, "Refund failed");
        }
        
        emit NFTSold(seller, msg.sender, tokenId, mintPrice);
    }
    
    /**
     * @dev Returns the current token count
     */
    function getTokenCount() external view returns (uint256) {
        return _tokenIds.current();
    }
    
    /**
     * @dev Returns array of token IDs that have been sold out
     */
    function getSoldTokenIDs() external view returns (uint256[] memory) {
        uint256[] memory tokensForSale = new uint256[](_tokenIds.current());
        uint256 count = 0;
        
        for (uint256 i = 1; i <= _tokenIds.current(); i++) {
            if (isTokenSold[i]) {
                tokensForSale[count] = i;
                count++;
            }
        }
        
        // Create a new array with the correct size
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tokensForSale[i];
        }
        
        return result;
    }

    function getUnclaimedIDsWithStripe() external view returns (uint256[] memory) {
        uint256 total = _tokenIds.current();
        uint256 count = 0;

        // First, determine the number of unclaimed IDs with Stripe
        for (uint256 i = 1; i <= total; i++) {
            if (!isTokenSold[i] && stripePaidUser[i] != address(0)) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = 1; i <= total; i++) {
            if (!isTokenSold[i] && stripePaidUser[i] != address(0)) {
                result[idx] = i;
                idx++;
            }
        }
        return result;
    }
} 
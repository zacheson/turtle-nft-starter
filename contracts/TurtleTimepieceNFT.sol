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
    uint256 public constant MAX_SUPPLY = 1;
    
    // Price per NFT in ETH
    uint256 public mintPrice = 0.001 ether;
    
    // IPFS folder CID
    string private constant IPFS_FOLDER = "QmUxwjKEFoWAmeCQfRBxhVsDar9CMpqBtCEHgpgW3nEE8M";
    
    // Mapping to track which tokens are available for sale
    mapping(uint256 => bool) public isTokenForSale;
    
    // Events
    event NFTMinted(address owner, uint256 tokenId, string tokenURI);
    event NFTSold(address from, address to, uint256 tokenId, uint256 price);
    event TokenPutForSale(uint256 tokenId);
    event TokenRemovedFromSale(uint256 tokenId);
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
            isTokenForSale[i] = true; // Mark token as available for sale
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
     * @param forSale Whether the token should be for sale
     */
    function setTokenSaleStatus(uint256 tokenId, bool forSale) external {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == _msgSender(), "Not token owner");
        isTokenForSale[tokenId] = forSale;
        if (forSale) {
            emit TokenPutForSale(tokenId);
        } else {
            emit TokenRemovedFromSale(tokenId);
        }
    }

    /**
     * @dev Claim a token (for Stripe purchases)
     * @param tokenId The token to claim
     */
    function claimToken(uint256 tokenId) external nonReentrant whenNotPaused {
        require(_exists(tokenId), "Token does not exist");
        require(isTokenForSale[tokenId], "Token is not available for claiming");
        
        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner == owner(), "Token not owned by contract owner");
        
        _transfer(tokenOwner, msg.sender, tokenId);
        isTokenForSale[tokenId] = false;
        
        emit TokenClaimed(tokenId, msg.sender);
    }

    /**
     * @dev Purchase an NFT with ETH
     * @param tokenId The token ID to purchase
     */
    function purchaseNFT(uint256 tokenId) external payable nonReentrant whenNotPaused {
        require(_exists(tokenId), "Token does not exist");
        require(isTokenForSale[tokenId], "Token is not for sale");
        require(msg.value >= mintPrice, "Insufficient ETH sent");
        
        address seller = ownerOf(tokenId);
        require(seller != msg.sender, "Cannot buy your own token");
        
        // Calculate excess ETH
        uint256 excess = msg.value - mintPrice;
        
        // Transfer the NFT
        _transfer(seller, msg.sender, tokenId);
        
        // Mark token as not for sale after purchase
        isTokenForSale[tokenId] = false;
        
        // Transfer payment to the seller
        (bool success, ) = payable(seller).call{value: mintPrice}("");
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
     * @dev Returns array of token IDs that are available for sale
     */
    function getTokensForSale() external view returns (uint256[] memory) {
        uint256[] memory tokensForSale = new uint256[](_tokenIds.current());
        uint256 count = 0;
        
        for (uint256 i = 1; i <= _tokenIds.current(); i++) {
            if (isTokenForSale[i]) {
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
} 
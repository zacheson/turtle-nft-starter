// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title TurtleTimepieceNFT
 * @dev ERC721 contract for the Turtle Timepiece NFT collection
 */
contract TurtleTimepieceNFT is ERC721, Ownable, ReentrancyGuard, Pausable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    Counters.Counter private _tokenIds;
    
    // Maximum supply of NFTs
    uint256 public constant MAX_SUPPLY = 20;
    
    // Base URI for metadata
    string private _baseTokenURI;
    
    // Price per NFT in ETH
    uint256 public mintPrice = 0.114 ether;
    
    // Mapping to track which tokens are available for sale
    mapping(uint256 => bool) public isTokenForSale;

    // Mapping to track pre-purchased tokens (via Stripe)
    mapping(uint256 => address) public stripePurchases;
    
    // Events
    event NFTMinted(address owner, uint256 tokenId);
    event NFTSold(address from, address to, uint256 tokenId, uint256 price);
    event TokenPutForSale(uint256 tokenId);
    event TokenRemovedFromSale(uint256 tokenId);
    event TokenPrePurchased(uint256 tokenId, address purchaser);
    event TokenClaimed(uint256 tokenId, address claimer);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);
    
    constructor() ERC721("Timeless Experience", "Turtle") {
        _baseTokenURI = "";
        // Pre-mint all NFTs to the contract owner
        address owner = _msgSender();
        for (uint256 i = 1; i <= MAX_SUPPLY; i++) {
            _tokenIds.increment();
            _mint(owner, i);
            isTokenForSale[i] = true; // Mark all tokens as available for sale
            emit NFTMinted(owner, i);
        }
    }
    
    /**
     * @dev Returns the base URI for token metadata
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
    
    /**
     * @dev Removes the "ipfs://" prefix from a string
     */
    function _removeIpfsPrefix(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length >= 7 && 
                strBytes[0] == "i" && 
                strBytes[1] == "p" && 
                strBytes[2] == "f" && 
                strBytes[3] == "s" && 
                strBytes[4] == ":" && 
                strBytes[5] == "/" && 
                strBytes[6] == "/", 
                "Invalid IPFS URI");
        
        bytes memory result = new bytes(strBytes.length - 7);
        for(uint i = 7; i < strBytes.length; i++) {
            result[i-7] = strBytes[i];
        }
        return string(result);
    }
    
    /**
     * @dev Returns the URI for a given token ID with HTTP gateway URL
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        require(bytes(baseURI).length > 0, "Base URI not set");
        return string.concat(baseURI, tokenId.toString(), ".json");
    }
    
    /**
     * @dev Updates the base URI for token metadata
     * @param baseURI New base URI
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
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
     * @dev Mark a token as pre-purchased via Stripe
     * @param tokenId The token that was purchased
     * @param purchaser The address that will be able to claim the token
     */
    function markTokenAsPrePurchased(uint256 tokenId, address purchaser) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        require(isTokenForSale[tokenId], "Token is not for sale");
        require(purchaser != address(0), "Invalid purchaser address");
        require(stripePurchases[tokenId] == address(0), "Token already pre-purchased");
        
        isTokenForSale[tokenId] = false;
        stripePurchases[tokenId] = purchaser;
        emit TokenPrePurchased(tokenId, purchaser);
    }

    /**
     * @dev Claim a pre-purchased token
     * @param tokenId The token to claim
     */
    function claimToken(uint256 tokenId) external nonReentrant whenNotPaused {
        require(_exists(tokenId), "Token does not exist");
        require(stripePurchases[tokenId] == msg.sender, "Not authorized to claim");
        
        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner == owner(), "Token not owned by contract owner");
        
        _transfer(tokenOwner, msg.sender, tokenId);
        stripePurchases[tokenId] = address(0);
        
        emit TokenClaimed(tokenId, msg.sender);
    }

    /**
     * @dev Purchase an NFT that is for sale with ETH
     * @param tokenId The token ID to purchase
     */
    function purchaseNFT(uint256 tokenId) external payable nonReentrant whenNotPaused {
        require(_exists(tokenId), "Token does not exist");
        require(isTokenForSale[tokenId], "Token is not for sale");
        require(msg.value >= mintPrice, "Insufficient ETH sent");
        require(stripePurchases[tokenId] == address(0), "Token is pre-purchased");
        
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
            if (isTokenForSale[i] && stripePurchases[i] == address(0)) {
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

    /**
     * @dev Check if a token is pre-purchased and by whom
     * @param tokenId The token ID to check
     * @return The address that pre-purchased the token, or zero address if not pre-purchased
     */
    function getPrePurchaser(uint256 tokenId) external view returns (address) {
        return stripePurchases[tokenId];
    }
}
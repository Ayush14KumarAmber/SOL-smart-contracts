// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MySimpleNFT
 * @dev A minimal ERC721 implementation for learning or small projects.
 *      Uses OpenZeppelin’s ERC721 standard for safety and simplicity.
 *      Owner can mint NFTs and set a baseURI for metadata.
 */

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MySimpleNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    string private _baseTokenURI;
    uint256 public immutable MAX_SUPPLY;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 maxSupply_
    ) ERC721(name_, symbol_) {
        _baseTokenURI = baseURI_;
        MAX_SUPPLY = maxSupply_;
        _tokenIdCounter.increment(); // start from 1
    }

    /**
     * @dev Mint a new NFT to `to`.
     * Can only be called by the owner.
     */
    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        require(tokenId <= MAX_SUPPLY, "Max supply reached");
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    /**
     * @dev Update the base URI for all token metadata.
     */
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    /**
     * @dev Internal base URI override.
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Burn a token if you own it or are approved.
     */
    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not owner nor approved");
        _burn(tokenId);
    }
}

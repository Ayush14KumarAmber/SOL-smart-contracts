// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    )
        ERC20(name_, symbol_) 
        Ownable(msg.sender)   // 👈 Pass msg.sender as initial owner
    {
        _mint(msg.sender, initialSupply); // Mint initial supply to deployer
    }

    /**
     * @dev Mints new tokens to a specified address (onlyOwner).
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens from a specified address (onlyOwner).
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
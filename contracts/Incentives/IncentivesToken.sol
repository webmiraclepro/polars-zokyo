// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./ERC20.sol";
import "./SafeERC20.sol";

contract IncentivesToken is ERC20{
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}
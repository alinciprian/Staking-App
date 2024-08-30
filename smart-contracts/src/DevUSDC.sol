// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title DevUSDC
/// @notice Basic implementation of an ERC20 stablecoin pegged to the U.S. dollar to reward users with for their stake
contract DevUSDC is ERC20 {
    /*//////////////////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(uint256 initialSupply) ERC20("devUSDC", "dUSDC") {
        _mint(msg.sender, initialSupply);
    }
}

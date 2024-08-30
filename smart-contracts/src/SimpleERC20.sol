// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SimpleERC20
/// @notice Simple ERC20 implementation to mint and burn tokens on demand
contract SimpleERC20 is ERC20 {
    /*//////////////////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    /*//////////////////////////////////////////////////////////////////////////
                                USER-FACING METHODS
    //////////////////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 value) external virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) external virtual {
        _burn(from, value);
    }
}

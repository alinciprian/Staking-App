// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IStakeERC20
/// @notice Simple staking Vault with a constant APR 10% used to stake SIMPLE tokens
/// rewarded in devUSDC, an ERC20 stablecoin pegged to the U.S. dollar.
interface IStakeERC20 {
    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new stake position is added
    /// @param owner The address of the stake position owner
    /// @param amount The size of the stake position
    event Staked(address indexed owner, uint256 amount);

    /// @notice Emitted when stake position is unstaked
    /// @param owner The address of the stake position owner
    /// @param amount The size of the stake position
    /// @param reward The reward obtained upon unstaking
    event Unstaked(address indexed owner, uint256 amount, uint256 reward);

    struct Position {
        uint256 size;
        uint256 startTime;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The ERC20 token address used for staking
    ///
    /// @dev The ERC20 token address is set at deployment time
    function token() external view returns (IERC20 token);

    /// @notice The ERC20 stablecoin pegged to U.S. dollar used to reward users
    ///
    /// @dev The ERC20 stablecoin token address is set at deployment time
    function devUSDC() external view returns (IERC20 devUSDC);

    /// @notice The reward rate used to compute the rewards when unstaking
    ///
    /// @dev The reward rate is set at deployment time
    function rewardRate() external view returns (uint256 rate);

    /*//////////////////////////////////////////////////////////////////////////
                                USER-FACING METHODS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Stake tokens into the contract
    ///
    /// Notes:
    /// - A user can stake multiple times, in which case the amount will be added to the stake position size
    /// and the stake's starting time will be updated to the current block timestamp
    ///
    /// @param amount The amount of tokens to stake
    function stake(uint256 amount) external;

    /// @dev Unstake tokens from the contract and claim rewards
    function unstake() external;

    /// @dev Returns the stake position of {msg.sender}
    function getPosition() external view returns (Position memory);
}

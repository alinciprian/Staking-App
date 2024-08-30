// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IStakeERC20} from "./interfaces/IStakeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title : StakeERC20 contract
 */
contract StakeERC20 is ReentrancyGuard, Ownable {
    /*//////////////////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when stake amount is zero
    error StakeERC20__StakeAmountCantBeZero();

    /// @notice Thrown when a user attempts to stake an amount exceeding their balance
    error StakeERC20__NotEnoughBalance();

    /// @notice Thrown when a user attempts to withdraw a stake that does not exist
    error StakeERC20__NoStakeToWithdraw();

    /// @notice Thrown when a user attempts to withdraw a stake before the unstake period has elapsed
    error StakeERC20__UnstakingPeriodNotPassed();

    /// @notice Thrown when the contract is paused
    error StakeERC20__ContractCurrentlyOnPause();

    /// @notice Thrown if the transfer fails
    error StakeERC20__TransferFailed();

    /// @notice Thrown when trying to addToStakePosition, but use has none
    error StakeERC20__NoStakePositionAvalible();

    /*//////////////////////////////////////////////////////////////////////////
                                PUBLIC CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    uint256 constant SECONDS_IN_A_YEAR = 31557600; // used to transform duration of the stake in years

    /*//////////////////////////////////////////////////////////////////////////
                                PUBLIC STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    struct Stake {
        uint256 size;
        uint256 startTime;
        uint256 rewardAquired;
        uint256 lastClaimedRewards;
    }

    IERC20 public token;
    IERC20 public devUSDC;
    uint256 public totalAmountStakedInContract;
    uint256 public rewardRate = 10; // for 10% yearly reward
    uint256 public totalStaked;
    uint256 public stakeLockPeriod = 7 days;
    bool contractPaused = false;

    address[] users;

    /*//////////////////////////////////////////////////////////////////////////
                                PRIVATE STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Stake positions mapped by owner address
    mapping(address user => mapping(uint256 stakeId => Stake stake)) private _stakes;
    mapping(address => uint256) private _stakeCount;

    /*//////////////////////////////////////////////////////////////////////////
                                Modifiers
    //////////////////////////////////////////////////////////////////////////*/

    modifier notPaused() {
        if (contractPaused) {
            revert StakeERC20__ContractCurrentlyOnPause();
        }
        _;
    }

    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert StakeERC20__StakeAmountCantBeZero();
        }
        _;
    }

    modifier preexistentStakes() {
        if (_stakeCount[msg.sender] == 0) {
            revert StakeERC20__NoStakePositionAvalible();
        }

        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @param _token The address of the ERC20 token to be staked
    /// @param _devUSDC The address of the ERC20 stablecoin pegged to U.S. dollar
    /// @param _rewardRate The rate used to compute the staking rewards
    constructor(address _token, address _devUSDC, uint256 _rewardRate) Ownable(msg.sender) {
        token = IERC20(_token);
        devUSDC = IERC20(_devUSDC);
        rewardRate = _rewardRate;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                USER-FACING METHODS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     *  Creates a stake position. In the checks phase we need to make sure that:
     *  The amount to be staked is greater than 0
     *  User have enough balance
     *  In the effect phase the _stake and _stakeCount mappings are updated accordingly
     *  And lastly the tokens are transfered from the user to the staking contract
     * @param amount: the amount to be staked
     */
    function createStakePosition(uint256 amount) public notPaused moreThanZero(amount) {
        if (IERC20(token).balanceOf(msg.sender) < amount) {
            revert StakeERC20__NotEnoughBalance();
        }

        Stake memory stakePosition = _stakes[msg.sender][_stakeCount[msg.sender]];
        stakePosition.size += amount;
        stakePosition.startTime = block.timestamp;
        stakePosition.lastClaimedRewards = block.timestamp;
        _stakeCount[msg.sender] += 1;
        totalAmountStakedInContract += amount;
        users.push(msg.sender);

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert StakeERC20__TransferFailed();
        }
    }

    /**
     * A function that allows the user to increase a pre existent staking position, reseting the
     * stake duration. If users don't want to reset the minimum stake duration, they should create
     * a new stake.
     * Checks for zero amount, checks for balance, and checks for stakeCount to be > 1
     * @param stakeId: the id of the stake to be increased
     * @param amount: amount to add tot the position
     */
    function addToStakePosition(uint256 stakeId, uint256 amount)
        public
        notPaused
        moreThanZero(amount)
        preexistentStakes
    {
        if (IERC20(token).balanceOf(msg.sender) < amount) {
            revert StakeERC20__NotEnoughBalance();
        }

        Stake memory stakePosition = _stakes[msg.sender][stakeId];
        stakePosition.rewardAquired = _calculateRewards(msg.sender, stakeId);
        stakePosition.size += amount;
        stakePosition.startTime = block.timestamp;
        totalAmountStakedInContract += amount;

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert StakeERC20__TransferFailed();
        }
    }

    /**
     * The function is used to withdraw a stake position.
     * We need to ensure that the minimum lock period has passed.
     */
    function withdrawPosition(uint256 stakeId) public notPaused preexistentStakes nonReentrant {
        Stake memory stake = _stakes[msg.sender][stakeId];
        if (stake.size == 0) {
            revert StakeERC20__NoStakeToWithdraw();
        }
        if (block.timestamp - stake.startTime < stakeLockPeriod) revert StakeERC20__UnstakingPeriodNotPassed();

        uint256 totalRewards = _calculateRewards(msg.sender, stakeId) + stake.rewardAquired;
        uint256 totalAmount = totalRewards + stake.size;
        totalAmountStakedInContract -= stake.size;

        delete _stakes[msg.sender][stakeId];

        bool success = token.transfer(msg.sender, totalAmount);
        if (!success) {
            revert StakeERC20__TransferFailed();
        }
    }

    /**
     * Let a user withdraw all stake positions with one click
     * Only positions with minimum lock period satisfied
     */
    function withdrawAll() public preexistentStakes notPaused {
        uint256 totalReward;
        uint256 totalStakedAmount;
        for (uint256 i = 0; i <= _stakeCount[msg.sender]; i++) {
            Stake memory stake = _stakes[msg.sender][i];
            if (block.timestamp - stake.startTime >= stakeLockPeriod) {
                totalReward = _calculateRewards(msg.sender, i) + stake.rewardAquired;
                totalStakedAmount += stake.size;
                totalAmountStakedInContract -= stake.size;
                delete _stakes[msg.sender][i];
            } else {
                return;
            }
        }
        uint256 amountToSend = totalReward + totalStakedAmount;
        bool success = token.transferFrom(address(this), msg.sender, amountToSend);
        if (!success) {
            revert StakeERC20__TransferFailed();
        }
    }

    /**
     * The function will calculate the reward and transfer them
     * @param stakeId The id of the stake to claimReward from
     */
    function claimRewards(uint256 stakeId) external preexistentStakes notPaused {
        Stake memory stake = _stakes[msg.sender][stakeId];
        uint256 rewards = stake.rewardAquired + _calculateClaimRewards(msg.sender, stakeId);

        stake.rewardAquired = 0;
        stake.lastClaimedRewards = block.timestamp;

        bool success = token.transferFrom(address(this), msg.sender, rewards);
        if (!success) {
            revert StakeERC20__TransferFailed();
        }
    }

    /**
     * A function that will send back all the funds along with aquired rewards.
     * Owner can use it anytime, bypassing minimum lock period.
     */
    function forceWithdraw() public onlyOwner {
        for (uint256 i = 0; i <= users.length; i++) {
            uint256 userTotalStaked;
            uint256 reward;
            for (uint256 j = 0; j <= _stakeCount[users[i]]; j++) {
                reward = _stakes[users[i]][j].rewardAquired + _calculateClaimRewards(msg.sender, _stakeCount[users[i]]);
                userTotalStaked += _stakes[users[i]][j].size;
            }
            uint256 totalAmount = userTotalStaked + reward;
            token.transferFrom(address(this), address(users[i]), totalAmount);
        }
    }

    function setRewardRate(uint256 newReward) public onlyOwner {
        rewardRate = newReward;
    }

    function changeLockPeriod(uint256 newLockPeriod) public onlyOwner {
        stakeLockPeriod = newLockPeriod;
    }

    /**
     * @dev This function is intended to be used for withdraw functions
     * This function will calculate de rewards for a stake position
     * @param user Which used to calculate for
     * @param stakeId The individual id position of the user
     */
    function _calculateRewards(address user, uint256 stakeId) internal view returns (uint256) {
        Stake memory stakePosition = _stakes[user][stakeId];
        uint256 stakedTimeInYears = (block.timestamp - stakePosition.startTime) / SECONDS_IN_A_YEAR;
        uint256 reward = (stakePosition.size * rewardRate * stakedTimeInYears) / 100;
        return reward;
    }

    /**
     * @dev This function is intended to be used for claimRewards and forceWithdraw function
     * @param user Which used to calculate for
     * @param stakeId The individual id position of the user
     */
    function _calculateClaimRewards(address user, uint256 stakeId) internal view returns (uint256) {
        Stake memory stakePosition = _stakes[user][stakeId];
        uint256 stakedTimeInYears = (block.timestamp - stakePosition.lastClaimedRewards) / SECONDS_IN_A_YEAR;
        uint256 reward = (stakePosition.size * rewardRate * stakedTimeInYears) / 100;
        return reward;
    }
}

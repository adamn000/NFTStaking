// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SimpleNFT} from "../src/SimpleNFT.sol";
import {RewardToken} from "../src/RewardToken.sol";

/**
 * @title NFTStaking
 * @author
 * @notice This is basic staking contract with ERC721 implementation. User can stake NFTs and get rewards in
 * ERC20 tokens.
 */

contract NFTStaking {
    // @dev Contracts of ERC721 token for stake nad ERC20 reward token
    SimpleNFT private immutable i_simpleNFT;
    RewardToken private immutable i_rewardToken;

    error NftNotAllowedForStake();
    error FrozeTimeHasNotPassedYet();
    error NotTheOwner();
    error NoRewardsToClaim();
    error TransferFailed();
    error WrongAddressOfRewardToken();

    // @dev Reward rate is 100 tokens per day. It could be set to different amounts by changing s_rewardRate
    // @dev and PER_DAY variables.
    uint256 public s_rewardRate = 100;
    uint256 public PER_DAY = 86400;
    uint256 public constant MIN_STAKE_TIME = 30 days;
    uint256 public s_totalStaked;
    uint256 public s_rewardPerTokenStaked;
    uint256 private s_lastTimeStamp;

    // @dev Amount of tokens which user already claimed.
    mapping(address => uint256) private s_userRewardPerTokenPaid;
    // @dev Rewards earned by user.
    mapping(address => uint256) private s_userRewards;
    mapping(uint256 => uint256) private s_stakedTimeStamp;
    // @dev Users can withdraw only tokens they staked.
    mapping(uint256 => address) private s_tokenIdToOwner;
    mapping(address => uint256) private s_userTokenAmountStaked;

    event NftTokenStaked(address indexed user, address indexed token, uint256 tokenId);
    event NftTokenUnstaked(address indexed user, address indexed token, uint256 tokenId);

    /**
     * @dev Every time user stake or withdraw tokens there is an update of variables.
     */
    modifier updateRewards(address user) {
        s_rewardPerTokenStaked = rewardPerToken();
        s_lastTimeStamp = block.timestamp;
        s_userRewards[user] = rewardEarned(user);
        s_userRewardPerTokenPaid[user] = s_rewardPerTokenStaked;
        _;
    }

    /**
     * @param nftAddressForStake The address of ERC721 token for stake
     * @param rewardTokenAddress The address of ERC20 token for rewards
     * @dev The addresses must be set during deploying the contract, can't be changed later
     */
    constructor(address nftAddressForStake, address rewardTokenAddress) {
        i_simpleNFT = SimpleNFT(nftAddressForStake);
        i_rewardToken = RewardToken(rewardTokenAddress);
    }

    /*
     * @param nftToken The NFT token address depositing for stake
     * @param tokenId The id of the depositing token
     * @notice This function will send NFT token from user wallet to the contract
     */
    function stake(address nftToken, uint256 tokenId) public updateRewards(msg.sender) {
        if (nftToken != address(i_simpleNFT)) {
            revert NftNotAllowedForStake();
        }
        s_tokenIdToOwner[tokenId] = msg.sender;
        s_stakedTimeStamp[tokenId] = block.timestamp;
        s_totalStaked++;
        s_userTokenAmountStaked[msg.sender]++;

        IERC721(nftToken).transferFrom(msg.sender, address(this), tokenId);
        emit NftTokenStaked(msg.sender, nftToken, tokenId);
    }

    /**
     *
     * @notice This function allows user to withdraw their NFTs from contract.
     * @notice !!! Minimum time of stake is 30 days !!!
     */
    function unstake(address nftToken, uint256 tokenId) public updateRewards(msg.sender) {
        if (stakedTimeTokenId(tokenId) < MIN_STAKE_TIME) {
            revert FrozeTimeHasNotPassedYet();
        }
        if (s_tokenIdToOwner[tokenId] != msg.sender) {
            revert NotTheOwner();
        }
        s_tokenIdToOwner[tokenId] = address(0);
        s_stakedTimeStamp[tokenId] = 0;
        s_totalStaked--;

        IERC721(nftToken).transferFrom(address(this), msg.sender, tokenId);
        emit NftTokenUnstaked(msg.sender, nftToken, tokenId);
    }

    /**
     * @param token The address of ERC20 token to pay staking rewards.
     * @notice With this function user can claim earned rewards from staking thei NFT tokens.
     */
    function claimRewards(address token) public updateRewards(msg.sender) {
        uint256 userRewards = rewardEarned(msg.sender);
        if (userRewards == 0) {
            revert NoRewardsToClaim();
        }
        if (token != address(i_rewardToken)) {
            revert WrongAddressOfRewardToken();
        }
        s_userRewards[msg.sender] = 0;
        bool success = IERC20(token).transfer(msg.sender, userRewards);
        if (!success) {
            revert TransferFailed();
        }
    }

    /**
     * @param user The address of user who staked any tokens
     * @notice This function is calculating each user rewards from staking NFTs
     */
    function rewardEarned(address user) public view returns (uint256) {
        uint256 rewardPerTokenStaked = rewardPerToken();
        uint256 userRewardPerTokenPaid = s_userRewardPerTokenPaid[user];
        uint256 userRewards = s_userRewards[user];
        uint256 userTokenAmountStaked = s_userTokenAmountStaked[user];
        return ((userTokenAmountStaked * (rewardPerTokenStaked - userRewardPerTokenPaid)) / 1e18) + userRewards;
    }

    /**
     * @notice This function is calculating reward per token depending on actual amount of total staked tokens.
     * @dev In this case the rate is 100 tokens per day. It could be set for different amounts.
     */
    function rewardPerToken() public view returns (uint256) {
        if (s_totalStaked == 0) {
            return s_rewardPerTokenStaked;
        }
        uint256 stakeTime = block.timestamp - s_lastTimeStamp;
        return s_rewardPerTokenStaked + (s_rewardRate * 1e18 * stakeTime / PER_DAY) / s_totalStaked;
    }

    //////////////////////
    // View Functions  //
    ////////////////////

    function stakedTimeTokenId(uint256 tokenId) public view returns (uint256) {
        return block.timestamp - s_stakedTimeStamp[tokenId];
    }

    function getStakeTime(uint256 tokenId) external view returns (uint256) {
        return s_stakedTimeStamp[tokenId];
    }

    function getTokenIdToOwner(uint256 tokenId) external view returns (address) {
        return s_tokenIdToOwner[tokenId];
    }

    function getUserRewards(address user) external view returns (uint256) {
        return s_userRewards[user];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}

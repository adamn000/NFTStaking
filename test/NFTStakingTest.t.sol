// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {NFTStaking} from "../src/NFTStaking.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {SimpleNFT} from "../src/SimpleNFT.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC721Mock} from "@openzeppelin/contracts/mocks/ERC721Mock.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract NFTStakingTest is Test {
    event NftTokenStaked(address indexed user, address indexed token, uint256 tokenId);

    NFTStaking nftStaking;
    SimpleNFT public simpleNFT;
    RewardToken public rewardToken;

    address public nftAddress;
    address randomAddress;
    address USER = makeAddr("user");
    address USER2 = makeAddr("user2");
    uint256 tokenIdToMint = 1;

    ERC721 public nft;

    function setUp() public {
        simpleNFT = new SimpleNFT();
        rewardToken = new RewardToken();
        simpleNFT.mint(USER, 1);
        simpleNFT.mint(USER2, 2);
        nftStaking = new NFTStaking(address(simpleNFT), address(rewardToken));
        rewardToken.mint(address(nftStaking), 1000e18);
    }

    /////////////////////
    // Stake Function //
    ///////////////////

    function testCantStakeNotAllowedToken() public {
        ERC721Mock randomNft = new ERC721Mock("RandomNFT","RNFT");
        vm.startPrank(USER);
        randomNft.mint(USER, tokenIdToMint);
        randomNft.approve(address(nftStaking), tokenIdToMint);

        vm.expectRevert(NFTStaking.NftNotAllowedForStake.selector);
        nftStaking.stake(address(randomNft), tokenIdToMint);
        vm.stopPrank();
    }

    function testUserCanStake() public {
        vm.startPrank(USER);
        simpleNFT.approve(address(nftStaking), tokenIdToMint);
        nftStaking.stake(address(simpleNFT), tokenIdToMint);

        assert(simpleNFT.balanceOf(USER) == 0);
        assert(simpleNFT.ownerOf(tokenIdToMint) == address(nftStaking));
    }

    modifier staked() {
        vm.startPrank(USER);
        simpleNFT.approve(address(nftStaking), tokenIdToMint);
        nftStaking.stake(address(simpleNFT), tokenIdToMint);
        vm.stopPrank();
        _;
    }

    function testUpdateStakeInformation() public staked {
        vm.warp(block.timestamp + 100);

        assert(nftStaking.stakedTimeTokenId(tokenIdToMint) == 100);
        assert(nftStaking.getTokenIdToOwner(tokenIdToMint) == USER);
    }

    function testEmitEventAfterSuccessfulStaked() public {
        vm.prank(USER);
        simpleNFT.approve(address(nftStaking), tokenIdToMint);

        vm.expectEmit(true, true, true, true, address(nftStaking));
        emit NftTokenStaked(USER, address(simpleNFT), tokenIdToMint);
        vm.prank(USER);
        nftStaking.stake(address(simpleNFT), tokenIdToMint);
    }

    ////////////////////////
    // Unstake Function  //
    //////////////////////

    function testCantUnstakeIfFrozeTimeHasntPassed() public staked {
        vm.warp(block.timestamp + 10 days);
        vm.expectRevert(NFTStaking.FrozeTimeHasNotPassedYet.selector);
        vm.prank(USER);
        nftStaking.unstake(address(simpleNFT), tokenIdToMint);
    }

    function testOnlyOwnerOfTokenCanUnstake() public staked {
        vm.warp(block.timestamp + 30 days);
        vm.expectRevert(NFTStaking.NotTheOwner.selector);
        vm.prank(USER2);
        nftStaking.unstake(address(simpleNFT), tokenIdToMint);
    }

    function testUserCanUnstakeToken() public staked {
        vm.warp(block.timestamp + 30 days);
        vm.prank(USER);
        nftStaking.unstake(address(simpleNFT), tokenIdToMint);

        assert(simpleNFT.ownerOf(1) == USER);
        assert(simpleNFT.balanceOf(address(nftStaking)) == 0);
    }

    /////////////////////////////////
    // Reward Calculation Tests   //
    ///////////////////////////////

    modifier stakedUser2() {
        vm.startPrank(USER2);
        simpleNFT.approve(address(nftStaking), 2);
        nftStaking.stake(address(simpleNFT), 2);
        vm.stopPrank();
        _;
    }

    function testRewardPerTokenCalculationWithOneStaker() public staked {
        vm.warp(block.timestamp + 2 days);
        uint256 rewardPerToken = nftStaking.rewardPerToken();
        uint256 expectedReward = 200 ether;
        assertEq(rewardPerToken, expectedReward);
    }

    function testRewardPerTokenCalculationWithMultipleSaker() public staked stakedUser2 {
        vm.warp(block.timestamp + 2 days);
        uint256 rewardPerToken = nftStaking.rewardPerToken();
        uint256 expectedReward = 100 ether;
        assertEq(rewardPerToken, expectedReward);
    }

    function testRewardEarnedWithDiferentAmountStaked() public staked {
        uint256 userOneExpectedReward = 100;
        uint256 userTwoExpectedReward = 300;

        vm.startPrank(USER2);
        simpleNFT.mint(USER2, 3);
        simpleNFT.mint(USER2, 4);
        simpleNFT.approve(address(nftStaking), 2);
        simpleNFT.approve(address(nftStaking), 3);
        simpleNFT.approve(address(nftStaking), 4);
        nftStaking.stake(address(simpleNFT), 2);
        nftStaking.stake(address(simpleNFT), 3);
        nftStaking.stake(address(simpleNFT), 4);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        uint256 userOneReward = nftStaking.rewardEarned(USER);
        uint256 userTwoReward = nftStaking.rewardEarned(USER2);

        assertEq(userOneExpectedReward, userOneReward);
        assertEq(userTwoExpectedReward, userTwoReward);
    }

    function testRewardEarnedWithDifferenTimeStaked() public staked {
        uint256 userOneExpectedReward = 250;
        uint256 userTwoExpectedReward = 50;

        vm.warp(block.timestamp + 2 days);

        vm.startPrank(USER2);
        simpleNFT.approve(address(nftStaking), 2);
        nftStaking.stake(address(simpleNFT), 2);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days);

        uint256 userOneReward = nftStaking.rewardEarned(USER);
        uint256 userTwoReward = nftStaking.rewardEarned(USER2);

        assertEq(userOneExpectedReward, userOneReward);
        assertEq(userTwoExpectedReward, userTwoReward);
    }

    /////////////////////////
    // claimRewards Tests //
    ///////////////////////

    function testRevertIfUserDontHaveRewardsToClaim() public staked {
        vm.expectRevert(NFTStaking.NoRewardsToClaim.selector);
        vm.prank(USER);
        nftStaking.claimRewards(address(rewardToken));
    }

    function testRevertIfRewardTokenAddressIsWrong() public staked {
        vm.warp(block.timestamp + 1 days);
        ERC20Mock randomToken = new ERC20Mock();
        vm.expectRevert(NFTStaking.WrongAddressOfRewardToken.selector);
        vm.prank(USER);
        nftStaking.claimRewards(address(randomToken));
    }

    function testUserCanClaimRewardsAndHaveBalance() public staked {
        console.log(nftStaking.getUserRewards(USER));

        uint256 userExpectedBalance = 200;

        vm.warp(block.timestamp + 2 days);
        vm.prank(USER);
        nftStaking.claimRewards(address(rewardToken));

        uint256 userBalance = rewardToken.balanceOf(USER);
        assertEq(userBalance, userExpectedBalance);
        assert(nftStaking.rewardEarned(USER) == 0);
        console.log(nftStaking.getUserRewards(USER));
    }
}

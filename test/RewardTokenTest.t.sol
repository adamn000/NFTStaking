// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {RewardToken} from "../src/RewardToken.sol";

contract RewardTokenTest is Test {
    RewardToken public rewardToken;

    address USER = makeAddr("user");
    uint256 public constant AMOUNT_TO_MINT = 1 ether;

    function setUp() public {
        rewardToken = new RewardToken();
    }

    function testAmountMintCantBeZero() public {
        vm.expectRevert(RewardToken.AmountMustBeMoreThanZero.selector);
        rewardToken.mint(USER, 0);
    }

    function testCantMintToAddressZero() public {
        vm.expectRevert(RewardToken.CantMintToAddressZero.selector);
        rewardToken.mint(address(0), AMOUNT_TO_MINT);
    }

    function testUserCanMintAndHaveBalance() public {
        rewardToken.mint(USER, AMOUNT_TO_MINT);
        assert(rewardToken.balanceOf(USER) == AMOUNT_TO_MINT);
    }
}

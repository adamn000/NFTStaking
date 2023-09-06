// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardToken is ERC20, Ownable {
    error AmountMustBeMoreThanZero();
    error CantMintToAddressZero();

    constructor() ERC20("RewardToken", "RWT") {}

    function mint(address to, uint256 amount) public onlyOwner {
        if (amount <= 0) {
            revert AmountMustBeMoreThanZero();
        }
        if (to == address(0)) {
            revert CantMintToAddressZero();
        }
        _mint(to, amount);
    }
}

// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {NFTStaking} from "../src/NFTStaking.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {SimpleNFT} from "../src/SimpleNFT.sol";

contract DeployNFTStaking is Script {
    NFTStaking nftStaking;
    // @dev Use addresses of contracts
    address rewardToken;
    address nftToken;

    function run() external returns (NFTStaking) {
        vm.startBroadcast();
        nftStaking = new NFTStaking(nftToken, rewardToken);
        vm.stopBroadcast();
        return nftStaking;
    }
}

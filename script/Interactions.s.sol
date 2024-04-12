// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {MockLinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            ,
            ,
            ,
            uint256 deploeyerKey
        ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator, deploeyerKey);
    }

    function createSubscription(
        address vrfCoorinator,
        uint256 deploeyerKey
    ) public returns (uint64) {
        console.log("creating subscription on ChainID:", block.chainid);
        vm.startBroadcast(deploeyerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoorinator).createSubscription();

        vm.stopBroadcast();
        console.log("Your subid is :", subId);
        console.log("Plase update subscriptionId in HelperConfig.s.sol");

        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            address link,
            uint256 deploeyerKey
        ) = helperConfig.activeNetworkConfig();

        fundSubscription(vrfCoordinator, subscriptionId, link, deploeyerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint256 deploeyerKey
    ) public {
        console.log("Fundding subscription", subId);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("On chainID", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deploeyerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deploeyerKey);
            MockLinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId,
        uint256 deploeyerKey
    ) public {
        console.log("Adding consumer contract: ", raffle);
        console.log("Using vrfcoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        vm.startBroadcast(deploeyerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            ,
            uint256 deploeyerKey
        ) = helperConfig.activeNetworkConfig();

        addConsumer(raffle, vrfCoordinator, subscriptionId, deploeyerKey);
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}

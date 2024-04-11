// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {VRFCoordinatorV2Interface} from "../lib/chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "../lib/chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

/**
 * @title A sample Raffle Contract
 * @author SantaSwap
 * @notice This contract is for creating a sample raffle
 * @dev Implements chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughETH();
    error Raffle__TransferFailed();
    error Raffle__NotYetTimeStamp();
    error Raffle__NotOpened();
    error Raffle__UpkeedNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    VRFCoordinatorV2Interface COORDINATOR;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev dutation of the lottery in seconds
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;
    RaffleState private _s_raffleState;

    // events
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_interval = interval;
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        _s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETH();
        }

        if (_s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpened();
        }
        s_players.push(payable(msg.sender));
        // enteredAddressToAmount[msg.sender] = msg.value;

        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory) {
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == _s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);

        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) public {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeedNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(_s_raffleState)
            );
        }
        _s_raffleState = RaffleState.CALCULATING;

        // 1. request the RNG
        COORDINATOR.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId, //
            REQUEST_CONFIRMATIONS, //
            i_callbackGasLimit,
            NUM_WORDS
        );
        // 2. get the random number
    }

    // cei check effect interaction
    function fulfillRandomWords(
        uint256 /*_requestId */,
        uint256[] memory _randomWords
    ) internal override {
        // check
        // require (if -> error)
        // effects (our onw contract)
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        _s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        // check
        // require (if -> error)
        s_lastTimeStamp = block.timestamp;

        // interactions
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }

        emit WinnerPicked(winner);
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return _s_raffleState;
    }
}

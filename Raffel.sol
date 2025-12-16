// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* address vrfcordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B; */
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNeeded(uint256 currentBalance, uint256 numPlayers, RaffleState raffleState);
    
    /* Type Declarations */
    // So below each one of these states, can actually be converted to integers. 0 for OPEN, 1 for CALCULATING..
    enum RaffleState {
        OPEN, // You could enter the raffle, since there is no calculation happening
        CALCULATING // You could not enter it because, the pickwinner is executing
    }
    
    /* State Variables */
    uint32 private constant NUMWORDS =  1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable i_entranceFee; // Storage unchanged variable
    uint256 private immutable i_interval; // Lottery duration in seconds
    uint256 private s_lastTimeStamp; // This the last time
    address payable[] private s_players; // Storage variable
    bytes32 private immutable i_keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit = 500000;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    event RaffleEntered(address indexed player);
    event RandomnessRequested(uint256 indexed requestId);
    event RaffleWinner(address indexed winner, uint256 requestId);

    constructor(uint256 subscriptionId, uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint32 callbackGaslimit) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_callbackGasLimit = callbackGaslimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN; // This is the same if we did RaffleState(0)
    }

    function enterRaffle() external payable {
        if(msg.value < i_entranceFee ) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if(s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender)); // Adding the address to the array of address that entered teh Raffle
        // Basically anytime we update the storage we want to emi an event, that the storage was updated, like here by the msg.sender
        emit RaffleEntered(msg.sender); // This will generate the logs data, for the front to get if wanted
    }

    /**
        * @dev This is the function that the chainlink nodes will call to see 
        * if the lottery is ready to have a winner picked.
        * The following should be true in order for upkeepNeeded to be true:
        * 1. The time interval has passed between raffle runs
        * 2. The lottery is open
        * 3. The contract has ETH
        * 4. Implicitly, you subscription has LINK
        *  @param - ignored
    */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers; // When this becomes true it, the off chain oracle node trigger the preformUpKeep function
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        // Checking if enough time has passed
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded) {
            revert Raffle__UpkeepNeeded(address(this).balance, s_players.length, s_raffleState);
        }
        s_raffleState = RaffleState.CALCULATING;
        // The requestId is generated buy the coordinator. It uniquely identifies the request
        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUMWORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}))
            })
        );
    }

    // This function gets called when the oracle node generate the random value, and the coordinator runs this below function
    // CEI: Checks, Effects, Interactions Pattern
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // Checks, like require, conditional statements

        // s_player = 10
        // rng = 12
        // 12 % 10 = 2
        // 54354354354354354345.. % 10 = x, x is going to be the index of the winner in the players array

        // Effects (Internal Contract State)
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // This will wipe out everything in that s_players
        s_lastTimeStamp = block.timestamp;
        emit RaffleWinner(recentWinner, requestId);
        
        // Interactions (External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if(!success) {
            revert Raffle__TransferFailed();
        }
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

}
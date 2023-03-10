// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

error lowScore(); //This means the score of the player is lower than the highscore.
error noPrizePool(); //This means that there is 0 eth in the prize pool.
error notPaidFee(); //This means that the player has not paid the participation Fee.
error notEqualFee(); //This means that the transaction is not equal the required fee.
error noScore(); //This means that while there are participants no one has yet to finish the game.
error cryrdleNotOpen(); //This means that the keeper is currently running to update the daily coinOfTheDay and pay the winners.
error UpkeepNotNeeded(uint256 cryrdleState); //This means that the upkeep is not needed since the checkUpkeep returns False

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "hardhat/console.sol";

contract Cryrdle is VRFConsumerBaseV2, AutomationCompatibleInterface {

    /* Type declarations */
    enum CryrdleState {
        OPEN,
        CALCULATING
    }

    /* state variables */
    address public gameAcc; //the treasury account address.
    uint256 public gameBal; //the balance stored on the treasury account. This should be a gnosis account?
    address[] participants; //the participants who joined the guessing game.
    uint256 private immutable i_participationFee; //participation that is set in the constructor
    uint256 public rewardPerWinner; //reward per player
    uint256 public highscore;
    address[] winners;
    uint256 public coinOfTheDay; //random index between 1-100 that determines the coin of the day
    uint256[] coinHistory; //array that records the random numbers generated
    CryrdleState private s_cryrdleState; //stores the state of the game in a variable
    
    
    /* Chainlink Keeper specific variables */
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    /* Chainlink VRF specific variables */
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;



    /* Events */
    event CryrdleJoined(address indexed participant); //event to emit when a new person joined crydle
    event CoinOfTheDayUpdated(uint256 indexed coinOfTheDay); //event to emit when coin of the day was updated via vrf
    event WinnersPayedOut(address[] indexed winners); //event to emit when winners got paid out
    event GameStateReinitiated(); //event to emit when game state variables are set back to 0.
    event NewCryrdleGameStarted(uint256 indexed requestId); //event to emit when perform upkeep function successfully ran

    /* Mappings */
    mapping(address => uint256) totalPointBalances; // mapping that tracks the total point balance of all participants
    mapping(address => uint256) dayPointBalances; // mapping that tracks the daily point balance of all participants
    mapping(address => bool) paidParticipationFee; //mapping that holds accounts of who paid

    /* Functions */
    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane,
        uint256 interval,
        uint256 participationFee,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_participationFee = participationFee;
        s_cryrdleState = CryrdleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        gameAcc = msg.sender;
        gameBal = 0;
    }


    /* Cryrdle.STATE is open and the game is ongoing */
    function joinCryrdle() public payable {
        //require wallet addrress ! in participation array.
        if (msg.value != i_participationFee) {
            revert notEqualFee();
        } else {
            participants.push(msg.sender);
            gameBal += msg.value;
            paidParticipationFee[msg.sender] = true;
            emit CryrdleJoined(msg.sender);
        }
        if(s_cryrdleState != CryrdleState.OPEN) {
            revert cryrdleNotOpen();
        }
    }

    //rename function to submit
    function addPoints(address _participant, uint256 points) public {
        if (paidParticipationFee[_participant] != true) {
            revert notPaidFee();
        } else {
            // update point balances
            dayPointBalances[_participant] += points;
            totalPointBalances[_participant] += points;
            //update winner object array
            if (dayPointBalances[_participant] < highscore) {
                revert lowScore(); //have to check if this deletes the previous update
            } else if (dayPointBalances[_participant] == highscore) {
                winners.push(_participant);
                rewardPerWinner = gameBal / winners.length;
            } else {
                highscore = points;
                winners = new address[](0);
                winners.push(_participant);
                rewardPerWinner = gameBal / winners.length;
            }
        }
    }



    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = CryrdleState.OPEN == s_cryrdleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        upkeepNeeded = (timePassed && isOpen);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert UpkeepNotNeeded(
                uint256(s_cryrdleState)
            );
        }
        s_cryrdleState = CryrdleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS);
        emit NewCryrdleGameStarted(requestId); //This can probably be deleted as the fulfillRandomWords function already ran.
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {        
        /* handle payout OPEN QUESTION: how to avoid revert of the fulfillRandomWords function is no prize pool*/
        if (gameBal > 0) {
            revert noPrizePool();
        }
        for (uint256 i = 0; i < winners.length; i++) {
            payable(winners[i]).transfer(rewardPerWinner);
        }
        emit WinnersPayedOut(winners);

        /* Update Coin of the Day */
        coinOfTheDay = (randomWords[0] % 100) + 1; // this stores a random number between 1-100 within the coinOfTheDay variable
        coinHistory.push(coinOfTheDay);
        emit CoinOfTheDayUpdated(coinOfTheDay);
        
        /* initiate to original game state*/
        gameBal = 0;
        winners = new address[](0);
        participants = new address[](0);
        s_lastTimeStamp = block.timestamp;
        s_cryrdleState = CryrdleState.OPEN;
        emit GameStateReinitiated();
    }

    /* view functions */
    function getParticipants() public view returns (address[] memory) {
        return participants;
    }

    function getNumberOfParticipants() public view returns (uint256) {
        return participants.length;
    }

    function getWinners() public view returns (address[] memory) {
        if (rewardPerWinner == 0) {
            revert noScore();
        }
        return winners;
    }

    function getNumberOfWinners() public view returns (uint256) {
        return winners.length;
    }

    function getRewardPerWinner() public view returns (uint256) {
        return rewardPerWinner;
    }

    function getHighScore() public view returns (uint256) {
        return highscore;
    }

    function getPlayerDayPointBalance(address playerAddress) public view returns (uint256) {
        return dayPointBalances[playerAddress];
    }

    function getPlayerTotalPointBalance(address playerAddress) public view returns (uint256) {
        return totalPointBalances[playerAddress];
    }

    function getParticipationFee() public view returns (uint256) {
        return i_participationFee;
    }

    function getCryrdleState() public view returns (CryrdleState) {
        return s_cryrdleState;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    //add a AM I a winer function
    function getWinnerBinary() public view returns(bool){
        
    }

}







// _____________________________________________________

// pragma solidity ^0.8.7;

// import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
// import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
// import "hardhat/console.sol";

// /* Errors */
// error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
// error Raffle__TransferFailed();
// error Raffle__SendMoreToEnterRaffle();
// error Raffle__RaffleNotOpen();

// /**@title A sample Raffle Contract
//  * @author Patrick Collins
//  * @notice This contract is for creating a sample raffle contract
//  * @dev This implements the Chainlink VRF Version 2
//  */
// contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
//     /* Type declarations */
//     enum RaffleState {
//         OPEN,
//         CALCULATING
//     }
//     /* State variables */
//     // Chainlink VRF Variables
//     VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
//     uint64 private immutable i_subscriptionId;
//     bytes32 private immutable i_gasLane;
//     uint32 private immutable i_callbackGasLimit;
//     uint16 private constant REQUEST_CONFIRMATIONS = 3;
//     uint32 private constant NUM_WORDS = 1;

//     // Lottery Variables
//     uint256 private immutable i_interval;
//     uint256 private immutable i_entranceFee;
//     uint256 private s_lastTimeStamp;
//     address private s_recentWinner;
//     address payable[] private s_players;
//     RaffleState private s_raffleState;

//     /* Events */
//     event RequestedRaffleWinner(uint256 indexed requestId);
//     event RaffleEnter(address indexed player);
//     event WinnerPicked(address indexed player);

//     /* Functions */
//     constructor(
//         address vrfCoordinatorV2,
//         uint64 subscriptionId,
//         bytes32 gasLane, // keyHash
//         uint256 interval,
//         uint256 entranceFee,
//         uint32 callbackGasLimit
//     ) VRFConsumerBaseV2(vrfCoordinatorV2) {
//         i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
//         i_gasLane = gasLane;
//         i_interval = interval;
//         i_subscriptionId = subscriptionId;
//         i_entranceFee = entranceFee;
//         s_raffleState = RaffleState.OPEN;
//         s_lastTimeStamp = block.timestamp;
//         i_callbackGasLimit = callbackGasLimit;
//     }

//     function enterRaffle() public payable {
//         // require(msg.value >= i_entranceFee, "Not enough value sent");
//         // require(s_raffleState == RaffleState.OPEN, "Raffle is not open");
//         if (msg.value < i_entranceFee) {
//             revert Raffle__SendMoreToEnterRaffle();
//         }
//         if (s_raffleState != RaffleState.OPEN) {
//             revert Raffle__RaffleNotOpen();
//         }
//         s_players.push(payable(msg.sender));
//         // Emit an event when we update a dynamic array or mapping
//         // Named events with the function name reversed
//         emit RaffleEnter(msg.sender);
//     }

//     /**
//      * @dev This is the function that the Chainlink Keeper nodes call
//      * they look for `upkeepNeeded` to return True.
//      * the following should be true for this to return true:
//      * 1. The time interval has passed between raffle runs.
//      * 2. The lottery is open.
//      * 3. The contract has ETH.
//      * 4. Implicity, your subscription is funded with LINK.
//      */
//     function checkUpkeep(
//         bytes memory /* checkData */
//     )
//         public
//         view
//         override
//         returns (
//             bool upkeepNeeded,
//             bytes memory /* performData */
//         )
//     {
//         bool isOpen = RaffleState.OPEN == s_raffleState;
//         bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
//         bool hasPlayers = s_players.length > 0;
//         bool hasBalance = address(this).balance > 0;
//         upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
//         return (upkeepNeeded, "0x0"); // can we comment this out?
//     }

//     /**
//      * @dev Once `checkUpkeep` is returning `true`, this function is called
//      * and it kicks off a Chainlink VRF call to get a random winner.
//      */
//     function performUpkeep(
//         bytes calldata /* performData */
//     ) external override {
//         (bool upkeepNeeded, ) = checkUpkeep("");
//         // require(upkeepNeeded, "Upkeep not needed");
//         if (!upkeepNeeded) {
//             revert Raffle__UpkeepNotNeeded(
//                 address(this).balance,
//                 s_players.length,
//                 uint256(s_raffleState)
//             );
//         }
//         s_raffleState = RaffleState.CALCULATING;
//         uint256 requestId = i_vrfCoordinator.requestRandomWords(
//             i_gasLane,
//             i_subscriptionId,
//             REQUEST_CONFIRMATIONS,
//             i_callbackGasLimit,
//             NUM_WORDS
//         );
//         // Quiz... is this redundant?
//         emit RequestedRaffleWinner(requestId);
//     }

//     /**
//      * @dev This is the function that Chainlink VRF node
//      * calls to send the money to the random winner.
//      */
//     function fulfillRandomWords(
//         uint256, /* requestId */
//         uint256[] memory randomWords
//     ) internal override {
//         // s_players size 10
//         // randomNumber 202
//         // 202 % 10 ? what's doesn't divide evenly into 202?
//         // 20 * 10 = 200
//         // 2
//         // 202 % 10 = 2
//         uint256 indexOfWinner = randomWords[0] % s_players.length;
//         address payable recentWinner = s_players[indexOfWinner];
//         s_recentWinner = recentWinner;
//         s_players = new address payable[](0);
//         s_raffleState = RaffleState.OPEN;
//         s_lastTimeStamp = block.timestamp;
//         (bool success, ) = recentWinner.call{value: address(this).balance}("");
//         // require(success, "Transfer failed");
//         if (!success) {
//             revert Raffle__TransferFailed();
//         }
//         emit WinnerPicked(recentWinner);
//     }

//     /** Getter Functions */

//     function getRaffleState() public view returns (RaffleState) {
//         return s_raffleState;
//     }

//     function getNumWords() public pure returns (uint256) {
//         return NUM_WORDS;
//     }

//     function getRequestConfirmations() public pure returns (uint256) {
//         return REQUEST_CONFIRMATIONS;
//     }

//     function getRecentWinner() public view returns (address) {
//         return s_recentWinner;
//     }

//     function getPlayer(uint256 index) public view returns (address) {
//         return s_players[index];
//     }

//     function getLastTimeStamp() public view returns (uint256) {
//         return s_lastTimeStamp;
//     }

//     function getInterval() public view returns (uint256) {
//         return i_interval;
//     }

//     function getEntranceFee() public view returns (uint256) {
//         return i_entranceFee;
//     }

//     function getNumberOfPlayers() public view returns (uint256) {
//         return s_players.length;
//     }
// }

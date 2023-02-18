// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

error lowScore(); //This means the score of the player is lower than the highscore.
error noPrizePool(); //This means that there is 0 eth in the prize pool.
error notPaidFee(); //This means that the player has not paid the participation Fee.
error notEqualFee(); //This means that the transaction is not equal the required fee.
error noScore(); //This means that while there are participants no one has yet to finish the game.

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "hardhat/console.sol";

contract Cryrdle is VRFConsumerBaseV2 {
    /* state variables */
    address public gameAcc; //the treasury account address.
    uint256 public gameBal; //the balance stored on the treasury account. This should be a gnosis account?
    address[] participants; //the participants who joined the guessing game.
    uint256 private immutable i_participationFee; //participation that is set in the constructor
    uint256 rewardPerWinner; //reward per player
    uint256 public highscore;
    address[] winners;
    uint256 coinOfTheDay; //random index between 1-100 that determines the coin of the day

    /* VRF specific variables */
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /* Events */
    event CryrdleJoined(address indexed participant); //event to emit upon a person joined crydle
    event RequestedRaffleWinner(uint256 indexed requestId);

    /* Mappings */
    mapping(address => uint256) totalPointBalances; // mapping that tracks the total point balance of all participants
    mapping(address => uint256) dayPointBalances; // mapping that tracks the daily point balance of all participants
    mapping(address => bool) paidParticipationFee; //mapping that holds accounts of who paid

    constructor(
        uint256 participationFee,
        address vrfCoordinatorV2,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        gameAcc = msg.sender;
        gameBal = 0;
        i_participationFee = participationFee;
    }

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
    }

    function requestRandomCoin() external {
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS}
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
            
    }

    //the function below should only be allowed to executed by the owner
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

    function payWinner() public payable {
        if (msg.value > 0) {
            revert noPrizePool();
        }
        for (uint256 i = 0; i < winners.length; i++) {
            payable(winners[i]).transfer(rewardPerWinner);
        }
        gameBal = 0;
        winners = new address[](0);
        participants = new address[](0);
    }

    /* view functions */
    function getParticipants() public view returns (address[] memory) {
        return participants;
    }

    function getWinners() public view returns (address[] memory) {
        if (rewardPerWinner == 0) {
            revert noScore();
        }
        return winners;
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
}

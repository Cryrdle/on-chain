// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

contract Cryrdle {
    address public gameAcc; //the treasury account address.
    uint256 public gameBal; //the balance stored on the treasury account.
    uint256 public totalGuesses; //the total amount of guesses.
    address[] participants; //the participants who joined the guessing game.
    uint256 public participationFee; //participation that is set in the constructor
    mapping(address => uint) totalPointBalances; // mapping that tracks the total point balance of all participants
    mapping(address => uint) dayPointBalances; // mapping that tracks the daily point balance of all participants
    address[] winners;
    
    struct CurrentWinner {
    uint currentHighscore;
    address currentWinnerAddress;
    }
    CurrentWinner[] public currentWinners;


    constructor() {
        gameAcc = msg.sender;
        gameBal = 0;
        totalGuesses = 0;
        participationFee = 0.0001 ether;
    }

    function joinCryrdle() public payable {
        require(msg.value == participationFee, "The participation fee is fixed");
        participants.push(msg.sender);
        gameBal += msg.value;
    }

    //the function below should only be allowed to executed by the owner
    function addPoints(address _participant, uint256 points) public{
        require(checkParticipant(_participant), "The participation fee is fixed");
        // update point balances
        dayPointBalances[_participant] += points;
        totalPointBalances[_participant] += points;

        //update winner object array
        uint i = 0;
        for (i; i < currentWinners.length; i++) {
            if(currentWinners[i].currentHighscore < points) {
                break;}
            else { 
                currentWinners[i].currentHighscore = points;
                currentWinners[i].currentWinnerAddress = _participant;
                winners.push(_participant); }
        }
    }

    function payWinner(address[] memory _winners) public payable {
        require(msg.value > 0, "There is no price pool");
        uint256 amountPerRecipient = gameBal / _winners.length;
        for (uint256 i = 0; i < _winners.length; i++) {
            payable(winners[i]).transfer(amountPerRecipient);
        }
        gameBal = 0;
    }

    function checkParticipant(address _address) public view returns (bool) {
        for (uint i = 0; i < participants.length; i++) {
        if (participants[i] == _address) {
            return true;
            }
        }
        return false;
    }

    function getParticipants() public view returns (address[] memory) {
        return participants;
    }

    function getWinners() public view returns (address[] memory) {
        return winners;
    }


}


// payable function to enter the game
// upkeeper function to track time
// vrf to add randomnesss
//call API from back-end and coinmarketcap
// payout function
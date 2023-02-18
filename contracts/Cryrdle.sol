// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

error lowScore(); //This means the score of the player is lower than the highscore.
error noPrizePool(); //This means that there is 0 eth in the prize pool.
error notPaidFee(); //This means that the player has not paid the participation Fee.
error notEqualFee(); //This means that the transaction is not equal the required fee.

contract Cryrdle {
    address public gameAcc; //the treasury account address.
    uint256 public gameBal; //the balance stored on the treasury account. This should be a gnosis account?
    uint256 public totalGuesses; //the total amount of guesses.
    address[] participants; //the participants who joined the guessing game.
    uint256 public participationFee; //participation that is set in the constructor
    mapping(address => uint256) totalPointBalances; // mapping that tracks the total point balance of all participants
    mapping(address => uint256) dayPointBalances; // mapping that tracks the daily point balance of all participants
    mapping(address => bool) paidParticipationFee; //mapping that holds accounts of who paid
    uint256 rewardPerWinner; //reward per player
    uint256 public highscore;
    address[] winners;

    constructor() {
        gameAcc = msg.sender;
        gameBal = 0;
        totalGuesses = 0;
        participationFee = 0.0001 ether;
    }

    function joinCryrdle() public payable {
        //require wallet addrress ! in participation array.
        if(msg.value != participationFee) {
            revert notEqualFee();
        } else {
            participants.push(msg.sender);
            gameBal += msg.value;
            paidParticipationFee[msg.sender] = true;
        }
    }

    //the function below should only be allowed to executed by the owner
    function addPoints(address _participant, uint256 points) public {
        if(paidParticipationFee[_participant] != true) {revert notPaidFee();}
        else {
            // update point balances
            dayPointBalances[_participant] += points;
            totalPointBalances[_participant] += points;

            //update winner object array
            if (dayPointBalances[_participant] < highscore) {
                revert lowScore();
            } else if (dayPointBalances[_participant] == highscore) {
                winners.push(_participant);
            } else {
                highscore = points;
                winners = new address[](0);
                winners.push(_participant);
            }
        }
    }

    function payWinner() public payable {
        if (msg.value > 0) {revert noPrizePool(); }
        rewardPerWinner = gameBal / winners.length;
        for (uint256 i = 0; i < winners.length; i++) {
            payable(winners[i]).transfer(rewardPerWinner);
        }
        gameBal = 0;
        winners = new address[](0);
        participants = new address[](0);
    }

    function getParticipants() public view returns (address[] memory) {
        return participants;
    }

    function getWinners() public view returns (address[] memory) {
        return winners;
    }
}
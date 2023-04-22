// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

error notPaidFee(); //This means that the player has not paid the participation Fee.
error notEqualFee(); //This means that the transaction is not equal the required fee.
error noScore(); //This means that while there are participants no one has yet to finish the game.
error cryrdleNotOpen(); //This means that the keeper is currently running to update the daily coinOfTheDay and pay the winners.
error UpkeepNotNeeded(uint256 cryrdleState); //This means that the upkeep is not needed since the checkUpkeep returns False
error AlreadyParticipatedToday(); //This means that the player has already joinedCryrdle once today.

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
    uint256 public currentGameId;
    address private adminWalletJK; //admin wallet for admin fee
    address private adminWalletJS; //admin wallet for admin fee

    
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
    event WinnerNotification(address indexed participant); //event to emit when perform upkeep function successfully ran
    event LooserNotification(address indexed participant); //event to emit when perform upkeep function successfully ran



    /* Mappings */
    mapping(address => uint256) public totalPointBalances; // mapping that tracks the total point balance of all participants
    mapping(uint256 => mapping(address => uint256)) public dayPointBalances; // mapping that tracks the daily point balance of all participants
    mapping(uint256 => mapping(address => bool)) public paidParticipationFee; //mapping that holds accounts of who paid


    /* Functions */
    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane,
        uint256 interval,
        uint256 participationFee,
        uint32 callbackGasLimit,
        address _adminWalletJK,
        address _adminWalletJS
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
        adminWalletJK = _adminWalletJK;
        adminWalletJS = _adminWalletJS;
    }


    /* Cryrdle.STATE is open and the game is ongoing */
    function joinCryrdle() public payable {
    //check if the game state is open 
    if(s_cryrdleState != CryrdleState.OPEN) {
        revert cryrdleNotOpen();
    }
    //check if the player has already joined once or not
    if(paidParticipationFee[currentGameId][msg.sender]) {
        revert AlreadyParticipatedToday();
    }
    if (msg.value != i_participationFee) {
        revert notEqualFee();
    } else {
        participants.push(msg.sender);
        gameBal += msg.value;
        paidParticipationFee[currentGameId][msg.sender] = true;
        emit CryrdleJoined(msg.sender);
    }
    }

    function addPoints(address _participant, uint256 points) public {
    if (!paidParticipationFee[currentGameId][_participant]) {
        revert notPaidFee();
    } else {
        dayPointBalances[currentGameId][_participant] += points;
        totalPointBalances[_participant] += points;
        
        if (dayPointBalances[currentGameId][_participant] == highscore) {
            winners.push(_participant);
            rewardPerWinner = (gameBal * 95) / (winners.length * 100); // reserving 2% for gas fees & 3% for admin fee
            emit WinnerNotification(_participant);
        } else if (dayPointBalances[currentGameId][_participant] > highscore) {
            highscore = points;
            winners = new address[](0);
            winners.push(_participant);
            rewardPerWinner = (gameBal * 95) / (winners.length * 100); // reserving 2% for gas fees & 3% for admin fee
            emit WinnerNotification(_participant);
        } else {
            emit LooserNotification(_participant);
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

        /* Update Coin of the Day */
        coinOfTheDay = (randomWords[0] % 100) + 1; // this stores a random number between 1-100 within the coinOfTheDay variable
        coinHistory.push(coinOfTheDay);
        emit CoinOfTheDayUpdated(coinOfTheDay);

        if (gameBal == 0) {
            //no one is paid out since no one joined the game.
        } else {
        for (uint256 i = 0; i < winners.length; i++) {
            payable(winners[i]).transfer(rewardPerWinner);
            emit WinnersPayedOut(winners);}
        }
        reinitiateGameState();
    }

    function reinitiateGameState() public {
    // Distribute admin fee
    uint256 adminFee = (gameBal * 3) / 100;
    uint256 adminFeePerWallet = adminFee / 2;
    payable(adminWalletJK).transfer(adminFeePerWallet);
    payable(adminWalletJS).transfer(adminFeePerWallet);
    
    
    /* initiate to original game state*/
    currentGameId += 1;
    gameBal = address(this).balance;
    rewardPerWinner = 0;
    winners = new address[](0);
    participants = new address[](0);
    s_lastTimeStamp = block.timestamp;
    s_cryrdleState = CryrdleState.OPEN;
    emit GameStateReinitiated();
    }

    //Receive function to deposit ETH to pay for gas fees.
    receive() external payable {
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
        return dayPointBalances[currentGameId][playerAddress];
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

    //add a AM I a winner function
    function getCheckWinner(address playerAddress) public view returns (bool) {
    for (uint i = 0; i < winners.length; i++) {
        if (winners[i] == playerAddress) {
            return true;
        }
    }
    return false;
    }

}
# on-chain
## Contains all operations that are on-chain.

### Achievements
At current, I worked on the following function: 
1. joinCryrdle() --> Join the Game by paying the participation fee and adding the address to the participants array.
1. addPoints() --> A function that allows us to give points to participants based on their correct guesses. At the same time it also updates the winner array.
1. checkUpkeep() --> This function makes sure that the game is restarted every 24 hours.
1. performUpkeep() --> This function initiates the fulfillRandomWords function when upkeep needed.
1. fulfillRandomWords() --> provide a .This function (1)pays out every address that has the highest highscore, (2) updates the coin of the day via a random number between 1-100, and (3) restarts the game by reinitiating the game state.
1. And a bunch of helper functions!

### ToDos
1. Write test and deploy scripts.
1. Resarch Fathom Blockchain.


Current Contract Address
0x7ac4220a71517172Ae38a25d00Aad2d22E1E3A21

Constructor Input Parameters
address vrfCoordinatorV2 = "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625";
uint64 subscriptionId = "1479";
bytes32 gasLane = "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c";
uint256 interval = "86400";
uint256 participationFee = "1000000000000000";
uint32 callbackGasLimit = "500000";
address _adminWalletJK = "XX";
address _adminWalletJS = "XX";

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
0xC8516d2A5E056936C8CB7A3C18E03E051E54C610

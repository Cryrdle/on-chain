# on-chain
## Contains all operations that are on-chain.

### Achievements
At current, I worked on the following function: 
1. joinCryrdle() --> Join the Game by paying the participation fee and adding the address to the participants array.
2. addPoints() --> A function that allows us to give points to participants based on their correct guesses. At the same time it also updates the winner array. There is still an error here.
2. payWinner() --> This function pays out every address that has the highest highscore.
3. checkParticipant() --> Helper function for addPoints() to check if the address is in the participation array.
4. getParticipants() --> Helper function to return the participants array.
5. getWinners() --> Helper function to return the winners array.

### ToDos
3. Write test and deploy scripts.
4. Resarch Fathom Blockchain.
5. where is the coin of the day being stored. 
6. keeper, vrf, API
7. Clarify what is the functionality of the smart contract and of the front-end/back-end.
8. ether.js to hide the coin of the day (to avoid hacking of the hashing)
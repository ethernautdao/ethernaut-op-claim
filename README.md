## EthernautDAO OP claim

### What is it?

We combine a soulbound token (EXP) given to educational contributors with OP tokens as a liquid and transferable asset. Anyone holding EXP is eligible to proportionally claim OP tokens on a monthly basis. 

The amount EXP holders can claim follows this function:
```
Claimable OP = 5 * (EXP balance)
```
E.g. if someone holds 10 EXP, he/she will be able to claim 50 OP tokens per month. A cap at 99 EXP is considered for now. 

EXP tokens are earned by mentoring, creating educational content, or contributing to the Ethereum ecosystem in any other way. Everyone can nominate people to receive EXP in #exp-nominations on our Discord. If the nomination got enough votes, it will be consideres in the next EXP distribution. 

The $OP distribution will be 10.000 OP/month. If there is more than 10k OP to be claimed, the contract will get everyone's balances and reduce the claimable OP of each address. We will request every EXP holder to subscribe to the distribution and pick the total OP to be claimed at the end of each epoch.  

### How does it work?

1. EXP holders input their address and call `subscribe` on our [OPTokenClaim](https://optimistic.etherscan.io/address/0x9b0365ec449d929f62106368eb3dc58b3d578b0b#writeContract) contract when a new epoch starts
2. The contract registers their EXP balance, which will be taken into account for the reward calculation of the current epoch
3. Once an epoch passed, EXP holders will be able to claim their reward by calling `claimOP` on our claim contract
5. Once you claimed your OP, the contract automatically resubscribes you for the next reward distribution

If you subscribe and then earn more EXP, you can just resubscribe with your updated EXP balance. 

### Duration

The monthly claim of OP tokens will start on December 1st and runs for 6 months. Once this period is over all remaining OP tokens requested for mentors and for the monthly distribution will go back to the Optimism Foundation.

The contract owner can extend the claim period by calling `extendClaim(uint256 months)`.

### Epoch dates

The first 6 Epoch start dates are:

- Epoch 0: 1669852800 // Thu Dec 01 2022 00:00:00 UTC
- Epoch 1: 1672444800 // Sat Dec 31 2022 00:00:00 UTC
- Epoch 2: 1675036800 // Mon Jan 30 2023 00:00:00 UTC
- Epoch 3: 1677628800 // Wed Mar 01 2023 00:00:00 UTC
- Epoch 4: 1680220800 // Fri Mar 31 2023 00:00:00 UTC
- Epoch 5: 1682812800 // Sun Apr 30 2023 00:00:00 UTC
- Epoch 6: 1685404800 // Tue May 30 2023 00:00:00 UTC

At Epoch 0 only subscribing is possible, at Epoch 6 only claiming is possible - unless the duration gets extended by the contract owner.

### Deployed contracts

- [OPTokenClaim](https://optimistic.etherscan.io/address/0x9b0365ec449d929f62106368eb3dc58b3d578b0b#writeContract): 0x9B0365ec449d929F62106368eb3DC58b3D578b0b
- [EXP Token](https://optimistic.etherscan.io/address/0x6354Ce7509fB90d38f852F75b7A764eca6957629): 0x6354Ce7509fB90d38f852F75b7A764eca6957629
- [EXP NFT](https://optimistic.etherscan.io/address/0xC057ef640A24a7acb02938666Aa9bad9B00046c9): 0xC057ef640A24a7acb02938666Aa9bad9B00046c9

### Further info

- [Discord](https://discord.gg/dNmZ7W2y)
- [Optimism proposal](https://gov.optimism.io/t/review-gf-phase-1-proposal-cycle-8-ethernautdao/3800)
- [EthernautDAO Github](https://github.com/ethernautdao)
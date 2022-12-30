## OP claim contract

From https://gov.optimism.io/t/review-gf-phase-1-proposal-cycle-7-ethernautdao/3500

> We combine a soulbound token (EXP) given to educational contributors with OP tokens as a liquid and transferable asset.
> Any developer holding (EXP) will be enabled to proportionally claim OP tokens on a monthly basis.
> EXP is earned by mentoring (10 EXP), creating developer educational content (3 EXP), hacking smart contracts (3 EXP), and reporting those hacks with educational content (3 EXP). We encourage these community members to provide liquidity and vote for Optimism proposals, but we will not enforce them. Every user is free to use their OP tokens as they see fit.

A Cap at 99 EXP is considered for now.

### Claimable amount

Claimable OP will follow this function:
`Claimable OP = 5 * (EXP balance)`

This will result in

```
1 EXP = 5 claimable OP
99 EXP = 495 claimable OP
```

The $OP distribution will be 10.000 OP/month. If there is more than 10k OP to be claimed, the distribution will get everyone's balances and reduce the claimable OP of each address. We will request every EXP holder to subscribe to the distribution and pick the total OP to be claimed at the end of each epoch.  

### Duration

From https://gov.optimism.io/t/review-gf-phase-1-proposal-cycle-8-ethernautdao/3800

> The monthly claim of OP tokens will start on December 1st and run for 6 months. Once this period is done all remaining OP tokens requested for mentors and monthly distribution, left in EthernautDAO treasury will go back to the Optimism Foundation.

The owner can extend the claim period with function `extendClaim(uint256 months)`.

### Epoch dates

The first 6 Epoch start dates are:

- Epoch 0: 1669852800 // Thu Dec 01 2022 00:00:00 UTC
- Epoch 1: 1672444800 // Sat Dec 31 2022 00:00:00 UTC
- Epoch 2: 1675036800 // Mon Jan 30 2023 00:00:00 UTC
- Epoch 3: 1677628800 // Wed Mar 01 2023 00:00:00 UTC
- Epoch 4: 1680220800 // Fri Mar 31 2023 00:00:00 UTC
- Epoch 5: 1682812800 // Sun Apr 30 2023 00:00:00 UTC
- Epoch 6: 1685404800 // Tue May 30 2023 00:00:00 UTC

### How does it work?

1. EXP holders call `subscribe` when a new epoch starts
2. The contract registers their EXP balance, which will be taken into account for the reward calculation of the current epoch
3. If the total reward of a epoch exceeds 10k OP, the reward of each EXP holder is reduced accordingly
4. Once an epoch passed, EXP holders will be able to claim their reward via `claimOP`
5. Back to step 1.

At Epoch 0 only subscribing is possible, at Epoch 6 only claiming is possible - unless the duration gets extended by an owner.

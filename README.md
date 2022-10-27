## OP claim contract

From https://gov.optimism.io/t/review-gf-phase-1-proposal-cycle-7-ethernautdao/3500

> We combine a soulbound token (EXP) given to educational contributors with OP tokens as a liquid and transferable asset.
> Any developer holding (EXP) will be enabled to proportionally claim OP tokens on a monthly basis.
> EXP is earned by mentoring (10 EXP), creating developer educational content (3 EXP), hacking smart contracts (3 EXP), and reporting those hacks with educational content (3 EXP). We encourage these community members to provide liquidity and vote for Optimism proposals, but we will not enforce them. Every user is free to use their OP tokens as they see fit.

A Cap at 99 EXP is considered for now.

Claimable OP will follow this function:
`Claimable OP = 5 * (EXP balance) - 4`

This will result in

```
1EXP = 1 claimable OP
99 EXP (max lvl) = 491 claimable OP
```

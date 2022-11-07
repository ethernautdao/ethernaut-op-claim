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

From https://gov.optimism.io/t/review-gf-phase-1-proposal-cycle-8-ethernautdao/3800

> The monthly claim of OP tokens will start on December 1st and run for 6 months. Once this period is done all remaining OP tokens requested for mentors and monthly distribution, left in EthernautDAO treasury will go back to the Optimism Foundation.

The owner can extend the claim period with function `extendClaim(uint256 months)`.

### Epoch dates

The next 6 Epoch start dates are:

- 1672444800 // Thu Dec 01 2022 00:00:00 UTC
- 1675036800 // Mon Jan 30 2023 00:00:00 UTC
- 1677628800 // Wed Mar 01 2023 00:00:00 UTC
- 1680220800 // Fri Mar 31 2023 00:00:00 UTC
- 1682812800 // Sun Apr 30 2023 00:00:00 UTC
- 1685404800 // Tue May 30 2023 00:00:00 UTC

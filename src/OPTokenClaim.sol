// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract OPTokenClaim is Ownable {
    // EXP and OP token
    IERC20 public immutable EXP;
    IERC20 public immutable OP;

    // EthernautDAO Treasury
    address public treasury;

    // we assume 1 month is always 30 days
    uint128 public constant EPOCH_DURATION = 86400 * 30;
    // first claim period runs for 6 months, can be extended by owner
    uint256 public claimDuration = 6;

    struct Epoch {
        uint128 start; // start date of first epoch
        uint128 date; // start date of current epoch
    }

    Epoch public epoch;

    // date -> address -> claimed
    mapping(uint256 => mapping(address => bool)) public epochToAddressClaimed;

    event ClaimedOP(address indexed to, uint256 indexed amount);

    constructor(address _EXP, address _OP, address _treasury) {
        EXP = IERC20(_EXP);
        OP = IERC20(_OP);

        treasury = _treasury;

        epoch = Epoch({
            start: (uint128(block.timestamp) / EPOCH_DURATION) * EPOCH_DURATION,
            date: (uint128(block.timestamp) / EPOCH_DURATION) * EPOCH_DURATION
        });
    }

    // set new treasury in case address changes
    function setTreasury(address newTreasury) external onlyOwner {
        treasury = newTreasury;
    }

    // extend duration of claim period (in months)
    function extendClaim(uint256 months) external onlyOwner {
        claimDuration += months;
    }

    function claimOP(address account) external {
        _checkEpoch();
        require((epoch.date - epoch.start) / EPOCH_DURATION < claimDuration, "claim period over");
        require(!epochToAddressClaimed[epoch.date][account], "already claimed for this epoch");

        uint256 claimableOP = _calcReward(account);
        require(OP.allowance(treasury, address(this)) >= claimableOP, "reward exceeds allowance");

        // set claimed to true
        epochToAddressClaimed[epoch.date][account] = true;

        // transfer OP to account
        OP.transferFrom(treasury, account, claimableOP);

        emit ClaimedOP(account, claimableOP);
    }

    function _checkEpoch() internal {
        // if more than 1 month passed, begin new epoch
        if (block.timestamp > epoch.date + EPOCH_DURATION) {
            epoch.date = (uint128(block.timestamp) / EPOCH_DURATION) * EPOCH_DURATION;
        }
    }

    function _calcReward(address account) internal view returns (uint256) {
        uint256 expBalance = EXP.balanceOf(account);
        require(expBalance > 0, "address has no exp");

        return (expBalance * 5 - 4 ether);
    }
}

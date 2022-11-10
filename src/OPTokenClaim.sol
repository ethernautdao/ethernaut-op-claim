// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract OPTokenClaim is Ownable {
    // EXP and OP token
    IERC20 public immutable EXP;
    IERC20 public immutable OP;
    // treasury EthernautDAO multisg
    address public immutable treasury;

    // first claim period runs for 6 months, can be extended by owner
    uint256 public claimDuration = 6;

    struct Epoch {
        uint128 start; // start date of first epoch
        uint128 date; // start date of current epoch
    }

    Epoch public epoch;

    // date -> address -> claimed
    mapping(uint256 => mapping(address => bool)) public epochToAddressClaimed;

    event ClaimExtended(uint256 indexed months);
    event NewEpoch(uint128 indexed date);
    event OPClaimed(address indexed to, uint256 indexed amount);

    constructor(address _EXP, address _OP, address _treasury) {
        EXP = IERC20(_EXP);
        OP = IERC20(_OP);

        treasury = _treasury;

        epoch = Epoch({
            start: 1669852800, // Thu Dec 01 2022 00:00:00 UTC
            date: 1669852800
        });
    }

    // extend duration of claim period (in months)
    function extendClaim(uint256 months) external onlyOwner {
        claimDuration += months;
        emit ClaimExtended(months);
    }

    function claimOP(address account) external {
        _checkEpoch();
        require((epoch.date - epoch.start) / 30 days < claimDuration, "claim period over");
        require(!epochToAddressClaimed[epoch.date][account], "already claimed for this epoch");

        uint256 claimableOP = _calcReward(account);
        // set claimed to true
        epochToAddressClaimed[epoch.date][account] = true;
        // transfer OP to account
        require(OP.transferFrom(treasury, account, claimableOP), "Transfer failed");

        emit OPClaimed(account, claimableOP);
    }

    function _checkEpoch() internal {
        // if more than 1 month passed, begin new epoch
        if (block.timestamp > epoch.date + 30 days) {
            epoch.date = epoch.date + 30 days;
            emit NewEpoch(epoch.date);
        }
    }

    function _calcReward(address account) internal view returns (uint256) {
        uint256 expBalance = EXP.balanceOf(account);
        require(expBalance > 0, "address has no exp");
        // limit is 99 EXP -> 491 OP per month
        if (expBalance > 99 ether) {
            expBalance = 99 ether;
        }

        return (expBalance * 5 - 4 ether);
    }
}

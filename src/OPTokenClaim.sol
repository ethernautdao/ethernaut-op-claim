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
    uint256 public constant DURATION = 86400 * 30;
    uint256 public currentEpoch;

    // epoch -> address -> claimed
    mapping(uint256 => mapping(address => bool)) public epochToAddressClaimed;

    event ClaimedOP(address indexed to, uint256 indexed amount);

    constructor(address _EXP, address _OP, address _treasury) {
        EXP = IERC20(_EXP);
        OP = IERC20(_OP);

        treasury = _treasury;

        currentEpoch = (block.timestamp / DURATION) * DURATION;
    }

    // set new treasury in case multisig address changes
    function setTreasury(address newTreasury) external onlyOwner {
        treasury = newTreasury;
    }

    function claimOP(address account) external {
        _checkEpoch();
        require(!epochToAddressClaimed[currentEpoch][account], "already claimed for this epoch");

        uint256 claimableOP = _calcReward(account);
        require(OP.allowance(treasury, address(this)) >= claimableOP, "reward exceeds allowance");

        // set claimed to true
        epochToAddressClaimed[currentEpoch][account] = true;

        // transfer OP to account
        OP.transferFrom(treasury, account, claimableOP);

        emit ClaimedOP(account, claimableOP);
    }

    function _checkEpoch() internal {
        // if 1 month passed start new epoch
        if (block.timestamp > currentEpoch + DURATION) {
            currentEpoch = currentEpoch + DURATION;
        }
    }

    function _calcReward(address account) internal view returns (uint256) {
        uint256 expBalance = EXP.balanceOf(account);
        require(expBalance > 0, "address has no exp");

        return (expBalance * 5 - 4 ether);
    }
}

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

    struct Config {
        // start date of first epoch
        uint128 start;
        // first claim period runs for 6 months, can be extended by owner
        uint128 maxEpoch;
    }

    Config public config;

    // epochNumber -> address -> claimed
    mapping(uint256 => mapping(address => bool)) public epochToAddressClaimed;

    event ClaimExtended(uint256 indexed months);
    event OPClaimed(address indexed to, uint256 epoch, uint256 amount);

    constructor(
        address _EXP,
        address _OP,
        address _treasury
    ) {
        EXP = IERC20(_EXP);
        OP = IERC20(_OP);

        treasury = _treasury;

        config = Config({
            start: 1669852800, // Thu Dec 01 2022 00:00:00 UTC
            maxEpoch: 6
        });

        // TODO: transferOwnership to EthernautDAO multisig?
    }

    /// extend duration of claim period
    /// @param months number of months to extend claim period
    function extendClaim(uint256 months) external onlyOwner {
        unchecked {
            config.maxEpoch += uint128(months);
        }
        emit ClaimExtended(months);
    }

    function claimOP(address account) external {
        Config memory _config = config;

        // epoch 0 is the first
        uint256 epoch = currentEpoch(_config);

        require(epoch < _config.maxEpoch, "claim period over");

        require(
            !epochToAddressClaimed[epoch][account],
            "already claimed for this epoch"
        );

        uint256 claimableOP = _calcReward(account);

        // set claimed to true
        epochToAddressClaimed[epoch][account] = true;

        // transfer OP to account
        require(
            OP.transferFrom(treasury, account, claimableOP),
            "Transfer failed"
        );

        emit OPClaimed(account, epoch, claimableOP);
    }

    /// @dev reverts if claims have not started yet
    function currentEpoch(Config memory _config)
        internal
        view
        returns (uint256 epochNumber)
    {
        require(block.timestamp >= _config.start, "claim period not started");
        unchecked {
            epochNumber = (block.timestamp - _config.start) / 30 days;
        }
    }

    function _calcReward(address account) internal view returns (uint256) {
        uint256 expBalance = EXP.balanceOf(account);
        require(expBalance > 0, "address has no exp");

        // cap at 99 EXP
        if (expBalance > 99 ether) {
            expBalance = 99 ether;
        }

        return (expBalance * 5 - 4 ether);
    }

    function currentEpoch() external view returns (uint256 epochNumber) {
        epochNumber = currentEpoch(config);
    }

    function maxEpoch() external view returns (uint256) {
        return config.maxEpoch;
    }
}

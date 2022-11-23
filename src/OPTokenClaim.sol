// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract OPTokenClaim is Ownable {
    // EXP and OP token
    IERC20 public immutable EXP;
    IERC20 public immutable OP;

    // EthernautDAO treasury (multisig)
    address public immutable treasury;

    // constants
    uint256 public constant MAX_REWARD = 10000 ether;
    uint256 public constant MAX_EXP = 99 ether;

    struct Config {
        // start date of first epoch
        uint128 start;
        // duration of claims
        uint128 maxEpoch;
    }

    Config public config;

    struct EpochInfo {
        // number of subscribed accounts
        uint128 numAccounts;
        // total subscribed EXP (overflows at 3.4 * 10^20 EXP)
        uint128 totalEXP;
        // address to subscribed EXP
        mapping(address => uint256) addressToEXP;
        // address to claimed
        mapping(address => bool) addressClaimed;
    }

    EpochInfo[] public epochs;

    event ClaimExtended(uint256 indexed months);
    event Subscribed(address indexed account, uint256 epoch, uint256 amount);
    event OPClaimed(address indexed to, uint256 epoch, uint256 reward);

    constructor(address _EXP, address _OP, address _treasury) {
        EXP = IERC20(_EXP);
        OP = IERC20(_OP);

        // multisig address: 0x2431BFA47bB3d494Bd720FaC71960F27a54b6FE7
        treasury = _treasury;

        config = Config({
            start: 1669852800, // Thu Dec 01 2022 00:00:00 UTC
            maxEpoch: 6 // first claim duration runs for 6 months
        });

        // push first epoch
        epochs.push();

        // transfer ownership to multisig
        _transferOwnership(treasury);
    }

    /* ========== ADMIN CONFIGURATION ========== */
    
    /// extend duration of claim period
    /// @param months number of months to extend claim period
    function extendClaim(uint256 months) external onlyOwner {
        unchecked {
            config.maxEpoch += uint128(months);
        }
        emit ClaimExtended(months);
    }

    /* ========== VIEWS ========== */

    /// returns current epoch number
    function currentEpoch() external view returns (uint256 epochNumber) {
        unchecked {
            epochNumber = (block.timestamp - config.start) / 30 days;
        }
    }

    /// returns last epoch where claims are open
    function maxEpoch() external view returns (uint256) {
        return config.maxEpoch;
    }

    /// calculates reward for account at given epoch
    function rewardAtEpoch(address account, uint256 epoch) external view returns (uint256) {
        return _calcReward(account, epoch);
    }

    /// returns number of subscribed accounts at epoch
    function accountsAtEpoch(uint256 epoch) external view returns (uint128) {
        return epochs[epoch].numAccounts;
    }

    /// returns total subscribed EXP at epoch
    function totalEXPAtEpoch(uint256 epoch) external view returns (uint128) {
        return epochs[epoch].totalEXP;
    }

    /// returns subscribed EXP of account at given epoch and if account claimed
    function accountInfoAtEpoch(address account, uint256 epoch) external view returns (uint256, bool) {
        return (epochs[epoch].addressToEXP[account], epochs[epoch].addressClaimed[account]);
    }

    /* ========== USER FUNCTIONS ========== */

    /// subscribe to reward distribution for current epoch
    function subscribe(address account) external {
        Config memory _config = config;

        // epoch 0 is the first
        uint256 epoch = _currentEpoch(_config);
        require(epoch < _config.maxEpoch, "claims ended");
        require(epochs[epoch].addressToEXP[account] == 0, "already subscribed for this epoch");

        uint256 expBalance = EXP.balanceOf(account);
        require(expBalance > 0, "address has no exp");

        // cap at MAX_EXP = 99 EXP
        if (expBalance > MAX_EXP) {
            expBalance = MAX_EXP;
        }

        epochs[epoch].addressToEXP[account] = expBalance;
        epochs[epoch].totalEXP += uint128(expBalance);
        epochs[epoch].numAccounts++;

        emit Subscribed(account, epoch, expBalance);
    }

    /// claim subscribed OP reward
    function claimOP(address account) external {
        Config memory _config = config;

        // users claim reward for last epoch, so claims start at epoch 1
        uint256 epoch = _currentEpoch(_config);
        require(epoch > 0, "claims have not started yet");
        require(epoch - 1 < _config.maxEpoch, "claims ended");

        // check if subscribed and if already claimed
        require(epochs[epoch - 1].addressToEXP[account] > 0, "didn't subscribe");
        require(!epochs[epoch - 1].addressClaimed[account], "already claimed for this epoch");

        uint256 OPReward = _calcReward(account, epoch - 1);

        // set claimed to true
        epochs[epoch - 1].addressClaimed[account] = true;

        // transfer OP to account
        require(OP.transferFrom(treasury, account, OPReward), "Transfer failed");

        emit OPClaimed(account, epoch - 1, OPReward);
    }

    /// @dev reverts if claims have not started yet
    function _currentEpoch(Config memory _config) internal returns (uint256 epochNumber) {
        require(block.timestamp >= _config.start, "reward dist not started yet");
        unchecked {
            epochNumber = (block.timestamp - _config.start) / 30 days;
        }

        // push new epoch to array if needed
        while ((epochs.length - 1) < epochNumber) {
            epochs.push();
        }
    }

    // calculates reward of account for given epoch
    function _calcReward(address account, uint256 epoch) internal view returns (uint256) {
        // calculate the total reward of given epoch
        uint256 totalEXP = epochs[epoch].totalEXP;
        uint256 subscribedAccounts = epochs[epoch].numAccounts;

        uint256 totalReward = totalEXP * 5 - 4 ether * subscribedAccounts;

        // if total reward of given epoch is greater than 10k OP (MAX_REWARD), reduce reward       
        uint256 factor = 1 * 10 ** 15;
        if (totalReward > MAX_REWARD) {
            factor = MAX_REWARD * 10 ** 15 / totalReward;
        }

        // calculate individual reward
        uint256 balanceAtEpoch = epochs[epoch].addressToEXP[account];
        uint256 reward = (balanceAtEpoch * 5 - 4 ether) * factor;

        return (reward / 10 ** 15);
    }
}

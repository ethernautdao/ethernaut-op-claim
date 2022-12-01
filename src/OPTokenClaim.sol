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

    mapping(uint256 => uint256) public totalEXPAtEpoch;

    mapping(uint256 => mapping(address => uint256)) public epochToSubscribedEXP;

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

        // transfer ownership to multisig
        _transferOwnership(_treasury);
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

    /// @return epochNumber the current epoch number
    function currentEpoch() external view returns (uint256 epochNumber) {
        return _currentEpoch(config);
    }

    /// returns last epoch where claims are open
    function maxEpoch() external view returns (uint256) {
        return config.maxEpoch;
    }

    /// @return reward the amount of OP tokens to be claimed
    function calcReward(address account, uint256 epochNum) public view returns (uint256 reward) {
        unchecked {
            // calculate the total reward of given epoch
            uint256 totalReward = totalEXPAtEpoch[epochNum] * 5;

            // calculate individual reward
            uint256 subscribedEXP = epochToSubscribedEXP[epochNum][account];
            if (totalReward > MAX_REWARD) {
                reward = 5 * subscribedEXP * MAX_REWARD / totalReward;
            } else {
                reward = 5 * subscribedEXP;
            }
        }
    }

    /* ========== USER FUNCTIONS ========== */

    /// subscribe to reward distribution for current epoch
    function subscribe(address account) public {
        Config memory _config = config;

        // epoch 0 is the first
        uint256 epochNum = _currentEpoch(_config);
        require(epochNum < _config.maxEpoch, "claims ended");

        uint256 expBalance = EXP.balanceOf(account);
        require(expBalance > 0, "address has no exp");

        // cap at MAX_EXP = 99 EXP
        if (expBalance > MAX_EXP) {
            expBalance = MAX_EXP;
        }

        uint256 subscribedEXP = epochToSubscribedEXP[epochNum][account];
        if (subscribedEXP == expBalance) {
            // no change
            return;
        }

        // update total EXP at epoch
        unchecked {
            totalEXPAtEpoch[epochNum] += expBalance - subscribedEXP;
        }

        // update subscribed EXP for this account
        epochToSubscribedEXP[epochNum][account] = expBalance;

        emit Subscribed(account, epochNum, expBalance);
    }

    /// claim subscribed OP reward
    function claimOP(address account) external {
        Config memory _config = config;

        // users claim reward for last epoch, so claims start at epoch 1
        uint256 epochNum = _currentEpoch(_config);
        require(epochNum > 0, "claims have not started yet");

        uint256 lastEpochNum;
        unchecked {
            lastEpochNum = epochNum - 1;
        }
        require(lastEpochNum < _config.maxEpoch, "claims ended");

        // check if subscribed and if already claimed
        require(epochToSubscribedEXP[lastEpochNum][account] > 0, "didn't subscribe or already claimed");

        uint256 OPReward = calcReward(account, lastEpochNum);

        // mark as claimed
        epochToSubscribedEXP[lastEpochNum][account] = 0;

        // subscribe for next epoch
        if (epochNum < _config.maxEpoch) {
            subscribe(account);
        }

        // transfer OP to account
        require(OP.transferFrom(treasury, account, OPReward), "Transfer failed");

        emit OPClaimed(account, lastEpochNum, OPReward);
    }

    /// @dev reverts if claims have not started yet
    function _currentEpoch(Config memory _config) internal view returns (uint256 epochNumber) {
        require(block.timestamp >= _config.start, "reward dist not started yet");
        unchecked {
            epochNumber = (block.timestamp - _config.start) / 30 days;
        }
    }
}

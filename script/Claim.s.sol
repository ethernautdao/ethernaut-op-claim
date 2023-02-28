// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Accounts} from "./Accounts.sol";
import {OPTokenClaim} from "../src/OPTokenClaim.sol";

contract Claim is Script, Accounts {
    // EthernautDAO OP claim contract
    OPTokenClaim public opTokenClaim = OPTokenClaim(0x9B0365ec449d929F62106368eb3DC58b3D578b0b);

    function run() public {
        // create and select fork
        string memory RPC_URL = vm.envString("RPC_URL");
        vm.createSelectFork(RPC_URL);

        // private key for sending transactions
        uint256 pk = vm.envUint("PRIVATE_KEY");
        console2.log("Deploying contracts with address", vm.addr(pk));

        // start broadcasting
        vm.startBroadcast(pk);

        // the reward of last epoch is claimed
        uint256 lastEpoch = opTokenClaim.currentEpoch() - 1;

        // call claim function for all accounts in array
        uint256 length = accounts.length;
        for (uint256 i; i < length; i++) {
            uint256 reward = opTokenClaim.calcReward(accounts[i], lastEpoch);
            
            // if theres OP ready to be claimed, call claim function
            if (reward != 0) opTokenClaim.claimOP(accounts[i]);
        }
        
        vm.stopBroadcast();
    }
}
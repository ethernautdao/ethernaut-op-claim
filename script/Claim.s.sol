// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Accounts, IMultiCall} from "./Utils.sol";
import {OPTokenClaim} from "../src/OPTokenClaim.sol";

contract Claim is Script, Accounts {
    // EthernautDAO OP claim contract
    OPTokenClaim internal opTokenClaim = OPTokenClaim(0x9B0365ec449d929F62106368eb3DC58b3D578b0b);

    // MakerDAO Multicall contract on Optimism
    IMultiCall internal multiCall = IMultiCall(0xcA11bde05977b3631167028862bE2a173976CA11);

    // Calldata for MultiCall contract
    IMultiCall.Call[] internal callArray;

    function run() public {
        // create and select fork
        string memory RPC_URL = vm.envString("RPC_URL");
        vm.createSelectFork(RPC_URL);

        // private key for sending transactions
        uint256 pk = vm.envUint("PRIVATE_KEY");
        console2.log("Sending transaction with address", vm.addr(pk));

        // the reward of last epoch is claimed
        uint256 lastEpoch = opTokenClaim.currentEpoch() - 1;

        // iterate over account array
        uint256 length = accounts.length;
        for (uint256 i; i < length; i++) {
            // get reward of account
            uint256 reward = opTokenClaim.calcReward(accounts[i], lastEpoch);

            // if theres OP ready to be claimed, append calldata array
            if (reward != 0) {
                callArray.push(
                    IMultiCall.Call({
                        target: address(opTokenClaim),
                        callData: abi.encodeWithSignature("claimOP(address)", accounts[i])
                    })
                );
            }
        }

        // call multicall contract
        vm.startBroadcast(pk);

        IMultiCall(multiCall).aggregate(callArray);

        vm.stopBroadcast();
    }
}

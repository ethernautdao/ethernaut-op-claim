// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Script, console2} from "forge-std/Script.sol";

import {OPTokenClaim} from "../src/OPTokenClaim.sol";

contract OPTokenClaimDeploy is Script {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        console2.log("from address:", vm.addr(pk));
        vm.startBroadcast(pk);

        address _EXP = 0x6354Ce7509fB90d38f852F75b7A764eca6957629;
        address _OP = 0x4200000000000000000000000000000000000042;
        address _treasury = 0x2431BFA47bB3d494Bd720FaC71960F27a54b6FE7;

        OPTokenClaim deployed = new OPTokenClaim(_EXP, _OP, _treasury);

        console2.log("OPTokenClaim:", address(deployed));

        vm.stopBroadcast();
    }
}

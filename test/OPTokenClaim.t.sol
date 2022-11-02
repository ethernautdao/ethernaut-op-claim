// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/OPTokenClaim.sol";

import "./tokens/EXP.sol";
import "./tokens/OP.sol";

contract ClaimOPTest is Test {
    OPTokenClaim public claimContract;

    Optimism public OP;
    EthernautExperience public EXP;

    address public alice = address(100);
    address public bob = address(101);

    // duration of an epoch
    uint256 public constant DURATION = 86400 * 30;

    // current unix timestamp
    uint256 currentTime = 1667243025;

    function setUp() public {
        // set time to current unix timestamp
        vm.warp(currentTime);

        // deploy erc20 tokens
        OP = new Optimism();
        EXP = new EthernautExperience();

        // we assume this address is the OP token treasury
        claimContract = new OPTokenClaim(address(EXP), address(OP), address(this));
        OP.mint(address(this), 300_000 ether);

        // allow OPTokenClaim to spend 5000 OP
        OP.approve(address(claimContract), 5000 ether);

        // mint 10 EXP to Alice
        EXP.mint(alice, 10 ether);
    }

    function testAliceClaim() public {
        // claim EXP token for alice
        claimContract.claimOP(alice);

        // 10 EXP results in 46 OP per month (10 * 5 - 4)
        assertEq(OP.balanceOf(alice), 46 ether);

        // fast forward one month
        vm.warp(DURATION + 1 + currentTime);
        claimContract.claimOP(alice);
        assertEq(OP.balanceOf(alice), 46 ether * 2);
    }

    function testBobClaim() public {
        // bob has no EXP, so shouldnt be able to claim
        vm.expectRevert(bytes("address has no exp"));
        claimContract.claimOP(bob);
    }

    function testDoubleClaim() public {
        // claiming several times in a single epoch shouldnt be possible
        claimContract.claimOP(alice);

        // fast forward 1 week (1 epoch = 1 month)
        vm.warp(86400 * 7 + currentTime);

        // claim again
        vm.expectRevert(bytes("already claimed for this epoch"));
        claimContract.claimOP(alice);
    }

    function testSpendLimit() public {
        // mint 5000 EXP to Bob, resulting in >5k OP reward
        EXP.mint(bob, 5000 * 1 ether);

        vm.expectRevert(bytes("reward exceeds allowance"));
        claimContract.claimOP(bob);
    }

    function testFuzzClaiming(uint256 balance) public {
        // cap is currently at 99 EXP per address
        balance = bound(balance, 1, 99);

        EXP.mint(bob, balance * 1 ether);

        claimContract.claimOP(bob);

        // should always mint the correct amount
        assertEq(OP.balanceOf(bob), balance * 1 ether * 5 - 4 ether);
    }

    function testClaimPeriod() public {
        // fast forward 6 months, call claim function once a month to update index
        for (uint256 i = 0; i < 6; i++) {
            vm.warp(DURATION * i + 1 + currentTime);
            claimContract.claimOP(alice);
        }

        // fast forward 6 months and 1 second -> claim should be deactivated
        vm.warp(DURATION * 6 + 1 + currentTime);
        vm.expectRevert(bytes("claim period over"));
        claimContract.claimOP(alice);

        // extend claim for another month -> claiming possible again
        claimContract.extendClaim(1);
        claimContract.claimOP(alice);

        // fast forward another month -> should revert again
        vm.warp(DURATION * 7 + 1 + currentTime);
        vm.expectRevert(bytes("claim period over"));
        claimContract.claimOP(alice);

        // 7 months passed, so alice should have been able to claim 46 OP 7 times
        assertEq(OP.balanceOf(alice), 46 ether * 7);
    }
}

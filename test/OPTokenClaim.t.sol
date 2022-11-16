// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/OPTokenClaim.sol";

import "./tokens/EXP.sol";
import "./tokens/OP.sol";

contract ClaimOPTest is Test {
    event OPClaimed(address indexed to, uint256 epoch, uint256 amount);

    // claim contract
    OPTokenClaim public claimContract;

    // OP and EXP token
    Optimism public OP;
    EthernautExperience public EXP;

    // test accounts
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    // start unix timestamp: Thu Dec 01 2022 00:00:00 UTC
    uint256 start = 1669852800;

    function setUp() public {
        // set time to current unix timestamp
        vm.warp(start);

        // deploy erc20 tokens
        OP = new Optimism();
        EXP = new EthernautExperience();

        // we assume this address is the OP token treasury
        claimContract = new OPTokenClaim(
            address(EXP),
            address(OP),
            address(this)
        );
        OP.mint(address(this), 300_000 ether);

        // allow OPTokenClaim to spend 5000 OP
        OP.approve(address(claimContract), 5000 ether);

        // mint 10 EXP to Alice
        EXP.mint(alice, 10 ether);
    }

    function testExpOwnerCanClaim() public {
        // claim OP token for alice
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(alice, 0, 46 ether);
        claimContract.claimOP(alice);

        // 10 EXP results in 46 OP per month (10 * 5 - 4)
        assertEq(OP.balanceOf(alice), 46 ether);

        // fast forward one month and one second and claim again
        vm.warp(30 days + start + 1);
        claimContract.claimOP(alice);

        // alice should own 92 OP now
        assertEq(OP.balanceOf(alice), 46 ether * 2);
    }

    function testNonExpOwnerCanNotClaim() public {
        // bob has no EXP, so shouldnt be able to claim
        vm.expectRevert(bytes("address has no exp"));
        claimContract.claimOP(bob);
    }

    function testDoubleClaim() public {
        // claim first time
        claimContract.claimOP(alice);

        // fast forward 1 week
        vm.warp(start + 7 days);

        // claim again, same epoch
        vm.expectRevert(bytes("already claimed for this epoch"));
        claimContract.claimOP(alice);
    }

    function testEXPLimit() public {
        // mint 200 EXP to Bob
        EXP.mint(bob, 200 ether);

        // claim OP token for bob
        claimContract.claimOP(bob);

        // Bob should have 491 OP (max claim amount per month)
        assertEq(OP.balanceOf(bob), 491 ether);
    }

    function testFuzzClaiming(uint256 balance) public {
        // test balances between 1 and 1000 EXP
        balance = bound(balance, 1 ether, 1000 ether);

        // mint EXP and claim OP
        EXP.mint(bob, balance);
        claimContract.claimOP(bob);

        // should always mint the correct amount:
        // 491 OP for EXP > 99
        // EXP * 5 - 4 for EXP < 99
        if (balance > 99 ether) {
            assertEq(OP.balanceOf(bob), 491 ether);
        } else {
            assertEq(OP.balanceOf(bob), balance * 5 - 4 ether);
        }
    }

    function testExtendClaimAuth() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        claimContract.extendClaim(1);
    }

    function testClaimPeriod() public {
        // fast forward 6 months, call claim function once a month
        for (uint256 i = 0; i < 6; i++) {
            vm.warp(30 days * i + start + 1);
            claimContract.claimOP(alice);
        }

        // fast forward 6 months and 1 second -> claim should be deactivated
        vm.warp(30 days * 6 + start + 1);
        vm.expectRevert(bytes("claim period over"));
        claimContract.claimOP(alice);

        // extend claim for another month -> claiming possible again
        claimContract.extendClaim(1);
        claimContract.claimOP(alice);

        // fast forward another month -> should revert again
        vm.warp(30 days * 7 + start + 1);
        vm.expectRevert(bytes("claim period over"));
        claimContract.claimOP(alice);

        // 7 months passed, so alice should have been able to claim 46 OP 7 times
        assertEq(OP.balanceOf(alice), 46 ether * 7);
    }
}

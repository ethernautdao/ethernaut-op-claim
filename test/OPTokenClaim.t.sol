// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/OPTokenClaim.sol";

import "./tokens/EXP.sol";
import "./tokens/OP.sol";

contract ClaimOPTest is Test {
    event OPClaimed(address indexed to, uint256 epoch, uint256 amount);
    event Subscribed(address indexed account, uint256 epoch, uint256 amount);

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

    function testSubscribeBeforeStart() public {
        vm.warp(start - 1);

        vm.expectRevert("reward dist not started yet");
        claimContract.subscribe(alice);
    }

    function testClaimBeforeStart() public {
        vm.warp(start - 1);

        vm.expectRevert("reward dist not started yet");
        claimContract.claimOP(alice);
    }

    function testExpOwnerCanClaim() public {
        // first subscribe for reward distribution
        claimContract.subscribe(alice);

        // fast forward one month
        vm.warp(30 days + start + 1);

        // claim OP token for alice
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(alice, 0, 46 ether);
        claimContract.claimOP(alice);

        // 10 EXP results in 46 OP per month (10 * 5 - 4)
        assertEq(OP.balanceOf(alice), 46 ether);

        // subscribe for reward distribution of new epoch
        claimContract.subscribe(alice);

        // fast forward one month and one second and claim again
        vm.warp(60 days + start + 1);
        claimContract.claimOP(alice);

        // alice should own 92 OP now
        assertEq(OP.balanceOf(alice), 46 ether * 2);
    }

    function testNonExpOwnerCanNotSubscribe() public {
        // bob has no EXP, so shouldnt be able to claim
        vm.expectRevert(bytes("address has no exp"));
        claimContract.subscribe(bob);
    }

    function testNonExpOwnerCanNotClaim() public {
        // fast forward one month
        vm.warp(30 days + start + 1);

        // bob has no EXP, so shouldnt be able to claim
        vm.expectRevert("didn't subscribe or already claimed");
        claimContract.claimOP(bob);
    }

    function testDoubleClaim() public {
        // first subscribe for reward distribution
        claimContract.subscribe(alice);

        // try claiming in same epoch
        vm.expectRevert("claims have not started yet");
        claimContract.claimOP(alice);

        // fast forward one month
        vm.warp(30 days + start + 1);

        // claim first time
        claimContract.claimOP(alice);

        // fast forward 1 week
        vm.warp(30 days + start + 7 days);

        // claim again, same epoch -> should fail
        vm.expectRevert("didn't subscribe or already claimed");
        claimContract.claimOP(alice);
    }

    function testClaimingResubscribes() public {
        // first subscribe for reward distribution
        claimContract.subscribe(alice);

        // fast forward one month
        vm.warp(30 days + start + 1);

        // claim OP token for alice
        claimContract.claimOP(alice);

        // fast forward one month
        vm.warp(60 days + start + 1);

        // claim OP token for alice again
        claimContract.claimOP(alice);

        // alice should own 92 OP now
        assertEq(OP.balanceOf(alice), 46 ether * 2);
    }

    function testResubscribingUpdatesBalance() public {
        // first subscribe for reward distribution
        claimContract.subscribe(alice);

        // mint 10 more EXP to Alice
        EXP.mint(alice, 10 ether);

        // alice should now have 20 EXP
        assertEq(EXP.balanceOf(alice), 20 ether);

        // but her subscribed balance is still only 10 EXP
        assertEq(claimContract.epochToSubscribedEXP(0, alice), 10 ether);

        // alice can resubscribe
        claimContract.subscribe(alice);

        // her subscribed balance should have been updated
        assertEq(claimContract.epochToSubscribedEXP(0, alice), 20 ether);
    }

    function testEXPLimit() public {
        // mint 200 EXP to Bob
        EXP.mint(bob, 200 ether);

        // subscribe for reward distribution
        claimContract.subscribe(bob);

        // fast forward one month
        vm.warp(30 days + start + 1);

        // claim OP token for bob
        // should transfer 491 OP (max claim amount)
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(bob, 0, 491 ether);
        claimContract.claimOP(bob);
    }

    function testFuzzClaiming(uint256 balance) public {
        // test balances between 1 and 1000 EXP
        balance = bound(balance, 1 ether, 1000 ether);

        // mint EXP and subscribe for OP reward
        EXP.mint(bob, balance);
        claimContract.subscribe(bob);

        // fast forward one month
        vm.warp(30 days + start + 1);
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

    function testExtendClaim() public {
        assertEq(claimContract.maxEpoch(), 6);

        // extend claim period by 1 month
        claimContract.extendClaim(1);

        assertEq(claimContract.maxEpoch(), 7);
    }

    function testMaxClaimPeriod() public {
        // subscribe and claim for first 5 epochs (epoch 0 .. 4)
        for (uint256 i = 1; i < 6; i++) {
            // first subscribe
            claimContract.subscribe(alice);

            // then claim when epoch is over
            vm.warp(30 days * i + start + 1);
            claimContract.claimOP(alice);
        }

        // subscribe for epoch 5
        claimContract.subscribe(alice);

        // fast forward 6 months and 1 second -> subscribing should be deactivated
        vm.warp(30 days * 6 + start + 1);
        vm.expectRevert(bytes("claims ended"));
        claimContract.subscribe(alice);

        // but claiming for past epoch (epoch 5) should still be possible
        claimContract.claimOP(alice);

        // extend claims for 1 month
        claimContract.extendClaim(1);

        // subscribing should be possible again
        vm.expectEmit(true, true, true, true);
        emit Subscribed(alice, 6, 10 ether);
        claimContract.subscribe(alice);
    }

    function testReducedReward() public {
        // mint 99 EXP to 21 accounts and subscribe to reward dist
        for (uint256 i = 100; i < 121; i++) {
            EXP.mint(vm.addr(i), 99 ether);
            claimContract.subscribe(vm.addr(i));
        }

        // total subscribed EXP should be 99 * 21 = 2079
        assertEq(claimContract.totalEXPAtEpoch(0), 2079 ether);

        // fast forward one month
        vm.warp(30 days + start + 1);

        // total OP reward for epoch 0 is 10311 OP
        // factor should be 0.9698...
        // so reward for each individual user should be
        // (99 EXP * 5 - 4) * 0.9698.. = 476.19047.. OP
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(vm.addr(100), 0, 476_190476190476183000);
        claimContract.claimOP(vm.addr(100));
    }
}

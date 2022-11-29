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

        OP.mint(address(this), 120_000 ether);

        // allow OPTokenClaim to spend 10000 OP
        OP.approve(address(claimContract), 10000 ether);

        // mint 10 EXP to Alice
        EXP.mint(alice, 10 ether);
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
        assertEq(claimContract.epochToSubscribedEXP(0, alice), 10 ether);

        // fast forward one month
        vm.warp(30 days + start);

        // claim OP token for alice
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(alice, 0, 50 ether); // 10 EXP results in 50 OP per month
        claimContract.claimOP(alice);

        // should have automatically subscribed for new epoch
        assertEq(claimContract.epochToSubscribedEXP(1, alice), 10 ether);

        // fast forward one month and claim again
        vm.warp(60 days + start);

        vm.expectEmit(true, true, true, true);
        emit OPClaimed(alice, 1, 50 ether);
        claimContract.claimOP(alice);

        // alice should own 100 OP now
        assertEq(OP.balanceOf(alice), 100 ether);
    }

    function testNonExpOwnerCanNotSubscribe() public {
        // bob has no EXP, so shouldnt be able to subscribe
        vm.expectRevert(bytes("address has no exp"));
        claimContract.subscribe(bob);
    }

    function testNonExpOwnerCanNotClaim() public {
        // fast forward one month
        vm.warp(30 days + start + 1);

        // bob has no EXP (and didnt subscribe), so shouldnt be able to claim
        vm.expectRevert("didn't subscribe or already claimed");
        claimContract.claimOP(bob);
    }

    function testDoubleClaim() public {
        // first subscribe for reward distribution
        claimContract.subscribe(alice);

        // claiming in same epoch should fail
        vm.expectRevert("claims have not started yet");
        claimContract.claimOP(alice);

        // fast forward one month
        vm.warp(30 days + start);

        // claim for epoch 0
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(alice, 0, 50 ether);
        claimContract.claimOP(alice);

        // fast forward 1 week
        vm.warp(30 days + start + 7 days);

        // claim again for epoch 0 -> should fail
        vm.expectRevert("didn't subscribe or already claimed");
        claimContract.claimOP(alice);
    }

    function testClaimingResubscribes() public {
        // first subscribe for reward distribution
        claimContract.subscribe(alice);

        // fast forward one month
        vm.warp(30 days + start);

        // claim OP token for alice
        claimContract.claimOP(alice);

        // fast forward another month
        vm.warp(60 days + start);

        // claim OP token for alice again
        claimContract.claimOP(alice);

        // alice should own 100 OP now
        assertEq(OP.balanceOf(alice), 100 ether);
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

        // total subscribed EXP should have increased by 10
        assertEq(claimContract.totalEXPAtEpoch(0), 20 ether);

        // number of subscribed accounts should be 1
        assertEq(claimContract.accountsAtEpoch(0), 1);

        // alice subscribes again with unchanged EXP balance
        claimContract.subscribe(alice);

        // subscribed balance, totalEXP and numAccoutns should stay the same
        assertEq(claimContract.epochToSubscribedEXP(0, alice), 20 ether);
        assertEq(claimContract.totalEXPAtEpoch(0), 20 ether);
        assertEq(claimContract.accountsAtEpoch(0), 1);
    }

    function testEXPLimit() public {
        // mint 200 EXP to Bob
        EXP.mint(bob, 200 ether);

        // subscribe for reward distribution
        claimContract.subscribe(bob);

        // subscribed EXP should be 99
        assertEq(claimContract.epochToSubscribedEXP(0, bob), 99 ether);

        // fast forward one month
        vm.warp(30 days + start);

        // claim OP token for bob
        // should transfer 495 OP (max claim amount)
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(bob, 0, 495 ether);
        claimContract.claimOP(bob);
    }

    function testFuzzClaiming(uint256 balance) public {
        // test balances between 1 and 1000 EXP
        balance = bound(balance, 1 ether, 1000 ether);

        // mint EXP and subscribe for OP reward
        EXP.mint(bob, balance);
        claimContract.subscribe(bob);

        // fast forward one month
        vm.warp(30 days + start);

        // should always mint the correct amount:
        // 495 OP for EXP > 99
        // EXP * 5 for EXP <= 99
        claimContract.claimOP(bob);
        if (balance > 99 ether) {
            assertEq(OP.balanceOf(bob), 495 ether);
        } else {
            assertEq(OP.balanceOf(bob), balance * 5);
        }
    }

    function testMaxClaimPeriod() public {
        // first subscribe
        claimContract.subscribe(alice);

        // claim for first 5 epochs (epoch 0 .. 4)
        for (uint256 i = 1; i < 6; i++) {
            // then claim when epoch is over, automatically resubscribes
            vm.warp(30 days * i + start);
            claimContract.claimOP(alice);
        }

        // should have subscribed for epoch 5 by now
        assertEq(claimContract.epochToSubscribedEXP(5, alice), 10 ether);

        // fast forward 6 months -> subscribing should be deactivated
        vm.warp(30 days * 6 + start);
        vm.expectRevert(bytes("claims ended"));
        claimContract.subscribe(alice);

        // but claiming for past epoch (epoch 5) should still be possible
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(alice, 5, 50 ether);
        claimContract.claimOP(alice);

        // it shouldnt automatically resubscribe this time
        assertEq(claimContract.epochToSubscribedEXP(6, alice), 0);

        // extend claims for 1 month
        claimContract.extendClaim(1);

        // subscribing should be possible again
        vm.expectEmit(true, true, true, true);
        emit Subscribed(alice, 6, 10 ether);
        claimContract.subscribe(alice);
    }

    /// @dev tests that there are no rounding errors when operating at the reward limit
    function testReduceRewardLimit() public {
        // mint 20 EXP to 100 accounts and subscribe to reward dist
        for (uint256 i = 100; i < 200; i++) {
            EXP.mint(vm.addr(i), 20 ether);
            claimContract.subscribe(vm.addr(i));
        }

        assertEq(claimContract.totalEXPAtEpoch(0), 2000 ether);

        // fast forward one month
        vm.warp(30 days + start);

        // total OP reward for epoch 0 is 10k OP (aka the limit)
        // factor should be 1.0
        // so reward for each individual user should be
        // (20 EXP * 5) * 1.0 = 100 OP
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(vm.addr(100), 0, 100 ether);
        claimContract.claimOP(vm.addr(100));
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
        vm.warp(30 days + start);

        // total OP reward for epoch 0 is 10311 OP
        // factor should be 0.9620...
        // so reward for each individual user should be
        // (99 EXP * 5) * 0.9620.. = 476.19047.. OP
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(vm.addr(100), 0, 476_190476190476190000);
        claimContract.claimOP(vm.addr(100));
    }

    function testReducedReward50Percent() public {
        // mint 40 EXP to 100 accounts and subscribe to reward dist
        for (uint256 i = 100; i < 200; i++) {
            EXP.mint(vm.addr(i), 40 ether);
            claimContract.subscribe(vm.addr(i));
        }

        assertEq(claimContract.totalEXPAtEpoch(0), 4000 ether);

        // fast forward one month
        vm.warp(30 days + start);

        // total OP reward for epoch 0 is 20k OP
        // factor should be 0.5
        // so reward for each individual user should be
        // (40 EXP * 5) * 0.5 = 100 OP
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(vm.addr(100), 0, 100 ether);
        claimContract.claimOP(vm.addr(100));
    }

    function testReducedReward99Percent() public {
        // mint 50 EXP to 4k accounts (!) and subscribe to reward dist
        for (uint256 i = 100; i < 4_100; i++) {
            EXP.mint(vm.addr(i), 50 ether);
            claimContract.subscribe(vm.addr(i));
        }

        assertEq(claimContract.totalEXPAtEpoch(0), 200_000 ether);

        // fast forward one month
        vm.warp(30 days + start);

        // total OP reward for epoch 0 is 1m OP
        // factor should be 0.01
        // so reward for each individual user should be
        // (50 EXP * 5) * 0.01 = 2.5 OP
        vm.expectEmit(true, true, true, true);
        emit OPClaimed(vm.addr(100), 0, 2.5 ether);
        claimContract.claimOP(vm.addr(100));
    }
}

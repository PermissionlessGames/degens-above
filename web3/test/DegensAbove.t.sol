// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DegensAbove} from "../src/DegensAbove.sol";

contract TestDegensAbove is Test {
    DegensAbove public game;

    function setUp() public {
        game = new DegensAbove();
    }

    function test_constants() public view {
        assertEq(game.BetSize(), 1024 ether);
        assertEq(game.BettingPhaseSeconds(), 60);
        assertEq(game.BaseRaceLength(), 32);
    }
}

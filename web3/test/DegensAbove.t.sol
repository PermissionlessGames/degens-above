// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ArbSys} from "../src/ArbSys.sol";
import {DevDegensAbove} from "../src/dev/DevDegensAbove.sol";
import {DegensAbove} from "../src/DegensAbove.sol";

contract ArbSysMock is ArbSys {
    function arbBlockNumber() external view returns (uint) {
        return block.number;
    }

    function arbBlockHash(uint256 arbBlockNum) external view returns (bytes32) {
        return blockhash(arbBlockNum);
    }
}

contract TestDegensAbove is Test {
    DevDegensAbove public game;

    uint256 player1PrivateKey = 0x1337;
    address player1;

    event NewRace(uint256 indexed raceID, uint256 entropy, uint256 length);
    event ChariotCreated(uint256 indexed raceID, uint256 indexed chariotID, uint256 chariotSpeed, uint256 chariotAttributes);
    event ChariotUpdated(uint256 indexed raceID, uint256 indexed chariotID, uint256 finishesAtBlockNumber);
    event BetPlaced(uint256 indexed raceID, address indexed player, uint256 indexed chariotID, uint256 amount);
    event PotIncreased(uint256 indexed raceID, address indexed contributor, uint256 amount);

    function setUp() public {
        game = new DevDegensAbove();
        
        ArbSysMock arbSys = new ArbSysMock();
        vm.etch(address(100), address(arbSys).code);
        
        player1 = vm.addr(player1PrivateKey);
        vm.deal(player1, 10 * game.BetSize());
    }

    function test_constants() public view {
        assertEq(game.BetSize(), 1024 ether);
        assertEq(game.BettingPhaseBlocks(), 40);
        assertEq(game.BaseRaceLength(), 32);
    }

    function test_nextRace() public {
        uint256 i = 0;

        uint256 expectedRaceID = game.NumRaces() + 1;

        game.setEntropySource(true);

        vm.expectEmit(true, false, false, false);
        emit NewRace(expectedRaceID, 0, 0);
        for (i = 0; i < 16; i++) {
            vm.expectEmit(true, true, false, false);
            emit ChariotCreated(expectedRaceID, i, 0, 0);
            vm.expectEmit(true, true, false, false);
            emit ChariotUpdated(expectedRaceID, i, 0);
        }

        game.nextRace();

        uint256 minimumFinishesAt = type(uint256).max;
        for (i = 0; i < 16; i++) {
            uint256 chariotSpeed = game.RaceChariotSpeed(expectedRaceID, i);
            uint256 chariotFinishesAt = game.RaceChariotFinishesAtBlock(expectedRaceID, i);

            vm.assertGe(chariotSpeed, 1);
            vm.assertLe(chariotSpeed, 4);

            if (chariotFinishesAt < minimumFinishesAt) {
                minimumFinishesAt = chariotFinishesAt;
            }
        }

        vm.assertEq(game.RaceEndsAtBlock(expectedRaceID), minimumFinishesAt);
        
        // Verify betting phase and race start timing
        assertEq(game.BettingStartedAt(expectedRaceID), block.number, "Betting should start at current block");
        assertEq(game.RaceStartedAt(expectedRaceID), block.number + game.BettingPhaseBlocks(), "Race should start (and betting end) after BettingPhaseBlocks");
    }

    function test_nextRace_reverts_if_race_not_ended() public {
        game.nextRace();

        vm.expectRevert(abi.encodeWithSelector(DegensAbove.RaceNotEnded.selector));
        game.nextRace();
    }
    
    function test_placeBet() public {
        game.nextRace();
        
        uint256 raceID = game.NumRaces();
        uint256 chariotID = 5;
        
        uint256 initialRacePot = game.RacePot(raceID);
        uint256 initialRaceBalance = game.RaceBalance(raceID);
        uint256 initialPlayerTotalBets = game.RacePlayerTotalBets(raceID, player1);
        uint256 initialPlayerChariotBet = game.RacePlayerChariotBets(raceID, player1, chariotID);
        uint256 initialPlayerBalance = player1.balance;
        
        vm.startPrank(player1);
        vm.expectEmit(true, true, true, true);
        emit BetPlaced(raceID, player1, chariotID, 1);
        
        game.placeBet{value: game.BetSize()}(raceID, chariotID);
        vm.stopPrank();
        
        uint256 rake = game.BetSize() / 8;
        uint256 expectedPotIncrease = game.BetSize() - rake;
        
        assertEq(game.RacePot(raceID), initialRacePot + expectedPotIncrease, "Race pot should increase by bet amount minus rake");
        assertEq(game.RaceBalance(raceID), initialRaceBalance + expectedPotIncrease, "Race balance should increase by bet amount minus rake");
        assertEq(game.RacePlayerTotalBets(raceID, player1), initialPlayerTotalBets + 1, "Player total bets should increase by 1");
        assertEq(game.RacePlayerChariotBets(raceID, player1, chariotID), initialPlayerChariotBet + 1, "Player chariot bet should increase by 1");
        assertEq(player1.balance, initialPlayerBalance - game.BetSize(), "Player balance should decrease by bet amount");
    }
    
    function test_placeBet_multiple() public {
        game.nextRace();
        
        uint256 raceID = game.NumRaces();
        uint256 chariotID = 5;
        
        {
            uint256 numBets = 3;
            uint256 remainder = 100;
            uint256 totalValue = numBets * game.BetSize() + remainder;
            
            uint256 initialRacePot = game.RacePot(raceID);
            uint256 initialRaceBalance = game.RaceBalance(raceID);
            uint256 initialPlayerTotalBets = game.RacePlayerTotalBets(raceID, player1);
            uint256 initialPlayerChariotBet = game.RacePlayerChariotBets(raceID, player1, chariotID);
            uint256 initialPlayerBalance = player1.balance;
            
            uint256 rake = (numBets * game.BetSize()) / 8;
            uint256 expectedPotIncrease = (numBets * game.BetSize()) - rake;
            
            vm.startPrank(player1);
            vm.expectEmit(true, true, true, true);
            emit BetPlaced(raceID, player1, chariotID, numBets);
            
            game.placeBet{value: totalValue}(raceID, chariotID);
            vm.stopPrank();
            
            assertEq(game.RacePot(raceID), initialRacePot + expectedPotIncrease, "Race pot should increase by total bet amount minus rake");
            assertEq(game.RaceBalance(raceID), initialRaceBalance + expectedPotIncrease, "Race balance should increase by total bet amount minus rake");
            assertEq(game.RacePlayerTotalBets(raceID, player1), initialPlayerTotalBets + numBets, "Player total bets should increase by number of bets");
            assertEq(game.RacePlayerChariotBets(raceID, player1, chariotID), initialPlayerChariotBet + numBets, "Player chariot bet should increase by number of bets");
            assertEq(player1.balance, initialPlayerBalance - (numBets * game.BetSize()), "Player balance should decrease by total bet amount (remainder returned)");
        }
    }
    
    function test_placeBet_rejects_insufficient_amount() public {
        game.nextRace();
        
        uint256 raceID = game.NumRaces();
        uint256 chariotID = 5;
        uint256 insufficientAmount = game.BetSize() - 1;
        
        vm.startPrank(player1);
        vm.expectRevert(abi.encodeWithSelector(DegensAbove.InvalidBetAmount.selector));
        game.placeBet{value: insufficientAmount}(raceID, chariotID);
        vm.stopPrank();
    }
    
    function test_placeBet_adds_rake_to_next_race() public {
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        
        DevDegensAbove mockGame = new DevDegensAbove();
        mockGame.nextRace();
        
        uint256 nextRaceID = currentRaceID + 1;
        
        uint256 initialCurrentRacePot = game.RacePot(currentRaceID);
        uint256 initialNextRacePot = game.RacePot(nextRaceID);
        
        uint256 chariotID = 5;
        uint256 betAmount = game.BetSize();
        
        vm.startPrank(player1);
        game.placeBet{value: betAmount}(currentRaceID, chariotID);
        vm.stopPrank();
        
        uint256 expectedRake = betAmount / 8;
        uint256 expectedCurrentRacePotIncrease = betAmount - expectedRake;
        
        assertEq(
            game.RacePot(currentRaceID), 
            initialCurrentRacePot + expectedCurrentRacePotIncrease, 
            "Current race pot should increase by bet amount minus rake"
        );
        
        assertEq(
            game.RacePot(nextRaceID), 
            initialNextRacePot + expectedRake, 
            "Next race pot should increase by rake amount (1/8 of bet)"
        );
    }
    
    function test_placeBet_multiple_adds_rake_to_next_race() public {
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        
        DevDegensAbove mockGame = new DevDegensAbove();
        mockGame.nextRace();
        
        uint256 nextRaceID = currentRaceID + 1;
        
        {
            uint256 initialCurrentRacePot = game.RacePot(currentRaceID);
            uint256 initialNextRacePot = game.RacePot(nextRaceID);
            
            uint256 chariotID = 5;
            uint256 numBets = 3;
            uint256 totalBetAmount = numBets * game.BetSize();
            
            vm.startPrank(player1);
            game.placeBet{value: totalBetAmount}(currentRaceID, chariotID);
            vm.stopPrank();
            
            uint256 expectedRake = totalBetAmount / 8;
            uint256 expectedCurrentRacePotIncrease = totalBetAmount - expectedRake;
            
            assertEq(
                game.RacePot(currentRaceID), 
                initialCurrentRacePot + expectedCurrentRacePotIncrease, 
                "Current race pot should increase by total bet amount minus rake"
            );
            
            assertEq(
                game.RacePot(nextRaceID), 
                initialNextRacePot + expectedRake, 
                "Next race pot should increase by rake amount (1/8 of bet)"
            );
        }
    }
    
    function test_increasePot() public {
        game.nextRace();
        uint256 raceID = game.NumRaces();
        
        uint256 initialRacePot = game.RacePot(raceID);
        uint256 initialRaceBalance = game.RaceBalance(raceID);
        uint256 initialPlayerBalance = player1.balance;
        
        uint256 addAmount = 500 ether;
        
        vm.startPrank(player1);
        vm.expectEmit(true, true, true, true);
        emit PotIncreased(raceID, player1, addAmount);
        
        game.increasePot{value: addAmount}(raceID);
        vm.stopPrank();
        
        assertEq(
            game.RacePot(raceID), 
            initialRacePot + addAmount, 
            "Race pot should increase by the added amount"
        );
        assertEq(
            game.RaceBalance(raceID), 
            initialRaceBalance + addAmount, 
            "Race balance should increase by the added amount"
        );
        assertEq(
            player1.balance, 
            initialPlayerBalance - addAmount, 
            "Player balance should decrease by the added amount"
        );
    }
    
    function test_increasePot_zero_amount() public {
        game.nextRace();
        uint256 raceID = game.NumRaces();
        
        uint256 initialRacePot = game.RacePot(raceID);
        uint256 initialRaceBalance = game.RaceBalance(raceID);
        
        vm.startPrank(player1);
        game.increasePot{value: 0}(raceID);
        vm.stopPrank();
        
        assertEq(
            game.RacePot(raceID), 
            initialRacePot, 
            "Race pot should remain unchanged with zero amount"
        );
        assertEq(
            game.RaceBalance(raceID), 
            initialRaceBalance, 
            "Race balance should remain unchanged with zero amount"
        );
    }
    
    function test_placeBet_rake_with_no_next_race() public {
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        uint256 nextRaceID = currentRaceID + 1;
        
        uint256 initialCurrentRacePot = game.RacePot(currentRaceID);
        
        uint256 chariotID = 5;
        uint256 betAmount = game.BetSize();
        
        vm.startPrank(player1);
        game.placeBet{value: betAmount}(currentRaceID, chariotID);
        vm.stopPrank();
        
        uint256 expectedRake = betAmount / 8;
        uint256 expectedCurrentRacePotIncrease = betAmount - expectedRake;
        
        assertEq(
            game.RacePot(currentRaceID), 
            initialCurrentRacePot + expectedCurrentRacePotIncrease, 
            "Current race pot should increase by bet amount minus rake"
        );
        
        assertEq(
            game.RacePot(nextRaceID), 
            expectedRake, 
            "Next race pot should be set to rake amount (1/8 of bet)"
        );
    }
    
    function test_increasePot_future_race() public {
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        uint256 futureRaceID = currentRaceID + 5;
        
        uint256 initialPlayerBalance = player1.balance;
        
        uint256 addAmount = 500 ether;
        
        vm.startPrank(player1);
        vm.expectEmit(true, true, true, true);
        emit PotIncreased(futureRaceID, player1, addAmount);
        
        game.increasePot{value: addAmount}(futureRaceID);
        vm.stopPrank();
        
        assertEq(
            game.RacePot(futureRaceID), 
            addAmount, 
            "Future race pot should be set to the added amount"
        );
        assertEq(
            game.RaceBalance(futureRaceID), 
            addAmount, 
            "Future race balance should be set to the added amount"
        );
        assertEq(
            player1.balance, 
            initialPlayerBalance - addAmount, 
            "Player balance should decrease by the added amount"
        );
    }
    
    function test_increasePot_past_race_reverts() public {
        game.nextRace();
        uint256 firstRaceID = game.NumRaces();
        
        vm.roll(game.RaceEndsAtBlock(firstRaceID) + 1);
        
        game.nextRace();
        uint256 secondRaceID = game.NumRaces();
        
        uint256 addAmount = 500 ether;
        
        vm.startPrank(player1);
        vm.expectRevert(abi.encodeWithSelector(DegensAbove.RaceEnded.selector));
        game.increasePot{value: addAmount}(firstRaceID);
        vm.stopPrank();
        
        uint256 initialSecondRacePot = game.RacePot(secondRaceID);
        
        vm.startPrank(player1);
        game.increasePot{value: addAmount}(secondRaceID);
        vm.stopPrank();
        
        assertEq(
            game.RacePot(secondRaceID), 
            initialSecondRacePot + addAmount, 
            "Current race pot should increase by the added amount"
        );
    }
    
    function test_increasePot_race_in_progress() public {
        game.nextRace();
        uint256 raceID = game.NumRaces();
        
        // Roll to after betting phase but before race ends
        vm.roll(game.RaceStartedAt(raceID) + 5);
        
        assertLt(block.number, game.RaceEndsAtBlock(raceID), "Test setup: We should be in the middle of the race");
        
        uint256 initialRacePot = game.RacePot(raceID);
        uint256 initialRaceBalance = game.RaceBalance(raceID);
        uint256 initialPlayerBalance = player1.balance;
        
        uint256 addAmount = 500 ether;
        
        vm.startPrank(player1);
        vm.expectEmit(true, true, true, true);
        emit PotIncreased(raceID, player1, addAmount);
        
        game.increasePot{value: addAmount}(raceID);
        vm.stopPrank();
        
        assertEq(
            game.RacePot(raceID), 
            initialRacePot + addAmount, 
            "Race pot should increase by the added amount even during the race"
        );
        assertEq(
            game.RaceBalance(raceID), 
            initialRaceBalance + addAmount, 
            "Race balance should increase by the added amount even during the race"
        );
        assertEq(
            player1.balance, 
            initialPlayerBalance - addAmount, 
            "Player balance should decrease by the added amount"
        );
    }

    function test_placeBet_rake_emits_pot_increased_event() public {
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        uint256 nextRaceID = currentRaceID + 1;
        
        uint256 chariotID = 5;
        uint256 betAmount = game.BetSize();
        uint256 rake = betAmount / 8;
        
        vm.startPrank(player1);
        vm.expectEmit(true, true, true, true);
        emit PotIncreased(nextRaceID, player1, rake);
        
        game.placeBet{value: betAmount}(currentRaceID, chariotID);
        vm.stopPrank();
        
        assertEq(
            game.RacePot(nextRaceID),
            rake,
            "Next race pot should be increased by the rake amount"
        );
    }
    
    function test_placeBet_rejects_nonexistent_race() public {
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        uint256 nonexistentRaceID = currentRaceID + 1;
        
        uint256 chariotID = 5;
        uint256 betSize = game.BetSize();
        
        vm.startPrank(player1);
        vm.expectRevert(abi.encodeWithSelector(DegensAbove.InvalidRaceID.selector));
        game.placeBet{value: betSize}(nonexistentRaceID, chariotID);
        vm.stopPrank();
    }
    
    function test_placeBet_rejects_ended_race() public {
        game.nextRace();
        uint256 raceID = game.NumRaces();
        
        uint256 raceEndsAt = game.RaceEndsAtBlock(raceID);
        vm.roll(raceEndsAt);
        
        uint256 chariotID = 5;
        uint256 betSize = game.BetSize();
        
        vm.startPrank(player1);
        // Since we're rolling to the race end, the betting phase is also closed
        vm.expectRevert(abi.encodeWithSelector(DegensAbove.BettingPhaseClosed.selector));
        game.placeBet{value: betSize}(raceID, chariotID);
        vm.stopPrank();
    }
    
    function test_placeBet_rejects_after_betting_phase() public {
        game.nextRace();
        uint256 raceID = game.NumRaces();
        
        // Roll to just after the betting phase ends
        vm.roll(game.RaceStartedAt(raceID));
        
        uint256 chariotID = 5;
        uint256 betSize = game.BetSize();
        
        vm.startPrank(player1);
        vm.expectRevert(abi.encodeWithSelector(DegensAbove.BettingPhaseClosed.selector));
        game.placeBet{value: betSize}(raceID, chariotID);
        vm.stopPrank();
    }
}

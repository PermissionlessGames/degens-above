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

    // Player setup
    uint256 player1PrivateKey = 0x1337;
    address player1;

    // Events copied over from DegensAbove contract
    event NewRace(uint256 indexed raceID, uint256 entropy, uint256 length);
    event ChariotCreated(uint256 indexed raceID, uint256 indexed chariotID, uint256 chariotSpeed, uint256 chariotAttributes);
    event ChariotUpdated(uint256 indexed raceID, uint256 indexed chariotID, uint256 finishesAtBlockNumber);
    event BetPlaced(uint256 indexed raceID, address indexed player, uint256 indexed chariotID, uint256 amount);
    event PotIncreased(uint256 indexed raceID, address indexed contributor, uint256 amount);

    function setUp() public {
        game = new DevDegensAbove();
        
        // Set up mock ArbSys contract as a fake precompile for forge tests against Anvil test chain.
        ArbSysMock arbSys = new ArbSysMock();
        vm.etch(address(100), address(arbSys).code);
        
        // Set up player
        player1 = vm.addr(player1PrivateKey);
        vm.deal(player1, 10 * game.BetSize());
    }

    function test_constants() public view {
        assertEq(game.BetSize(), 1024 ether);
        assertEq(game.BettingPhaseSeconds(), 60);
        assertEq(game.BaseRaceLength(), 32);
    }

    function test_nextRace() public {
        uint256 i = 0;

        uint256 expectedRaceID = game.NumRaces() + 1;

        // Use blockhash as entropy source instead of mocked entropy
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
    }

    function test_nextRace_reverts_if_race_not_ended() public {
        game.nextRace();

        vm.expectRevert(abi.encodeWithSelector(DegensAbove.RaceNotEnded.selector));
        game.nextRace();
    }
    
    function test_placeBet() public {
        // Create a new race
        game.nextRace();
        
        uint256 raceID = game.NumRaces();
        uint256 chariotID = 5; // Choose a specific chariot
        
        // Record initial state
        uint256 initialRacePot = game.RacePot(raceID);
        uint256 initialRaceBalance = game.RaceBalance(raceID);
        uint256 initialPlayerTotalBets = game.RacePlayerTotalBets(raceID, player1);
        uint256 initialPlayerChariotBet = game.RacePlayerChariotBets(raceID, player1, chariotID);
        uint256 initialPlayerBalance = player1.balance;
        
        // Place bet as player
        vm.startPrank(player1);
        
        // Expect the BetPlaced event with the number of bets (1)
        vm.expectEmit(true, true, true, true);
        emit BetPlaced(raceID, player1, chariotID, 1);
        
        game.placeBet{value: game.BetSize()}(raceID, chariotID);
        vm.stopPrank();
        
        // Calculate expected pot increase (7/8 of bet amount)
        uint256 rake = game.BetSize() / 8;
        uint256 expectedPotIncrease = game.BetSize() - rake;
        
        // Verify state changes
        assertEq(game.RacePot(raceID), initialRacePot + expectedPotIncrease, "Race pot should increase by bet amount minus rake");
        assertEq(game.RaceBalance(raceID), initialRaceBalance + expectedPotIncrease, "Race balance should increase by bet amount minus rake");
        assertEq(game.RacePlayerTotalBets(raceID, player1), initialPlayerTotalBets + 1, "Player total bets should increase by 1");
        assertEq(game.RacePlayerChariotBets(raceID, player1, chariotID), initialPlayerChariotBet + 1, "Player chariot bet should increase by 1");
        assertEq(player1.balance, initialPlayerBalance - game.BetSize(), "Player balance should decrease by bet amount");
    }
    
    function test_placeBet_multiple() public {
        // Create a new race
        game.nextRace();
        
        uint256 raceID = game.NumRaces();
        uint256 chariotID = 5; // Choose a specific chariot
        
        // Use scopes to reduce stack variables
        {
            uint256 numBets = 3; // Place 3 bets at once
            uint256 remainder = 100; // Add a small remainder
            uint256 totalValue = numBets * game.BetSize() + remainder;
            
            // Record initial state
            uint256 initialRacePot = game.RacePot(raceID);
            uint256 initialRaceBalance = game.RaceBalance(raceID);
            uint256 initialPlayerTotalBets = game.RacePlayerTotalBets(raceID, player1);
            uint256 initialPlayerChariotBet = game.RacePlayerChariotBets(raceID, player1, chariotID);
            uint256 initialPlayerBalance = player1.balance;
            
            // Calculate rake and expected pot increase
            uint256 rake = (numBets * game.BetSize()) / 8;
            uint256 expectedPotIncrease = (numBets * game.BetSize()) - rake;
            
            // Place multiple bets as player
            vm.startPrank(player1);
            
            // Expect the BetPlaced event with the number of bets
            vm.expectEmit(true, true, true, true);
            emit BetPlaced(raceID, player1, chariotID, numBets);
            
            game.placeBet{value: totalValue}(raceID, chariotID);
            vm.stopPrank();
            
            // Verify state changes
            assertEq(game.RacePot(raceID), initialRacePot + expectedPotIncrease, "Race pot should increase by total bet amount minus rake");
            assertEq(game.RaceBalance(raceID), initialRaceBalance + expectedPotIncrease, "Race balance should increase by total bet amount minus rake");
            assertEq(game.RacePlayerTotalBets(raceID, player1), initialPlayerTotalBets + numBets, "Player total bets should increase by number of bets");
            assertEq(game.RacePlayerChariotBets(raceID, player1, chariotID), initialPlayerChariotBet + numBets, "Player chariot bet should increase by number of bets");
            assertEq(player1.balance, initialPlayerBalance - (numBets * game.BetSize()), "Player balance should decrease by total bet amount (remainder returned)");
        }
    }
    
    function test_placeBet_rejects_insufficient_amount() public {
        // Create a new race
        game.nextRace();
        
        uint256 raceID = game.NumRaces();
        uint256 chariotID = 5; // Choose a specific chariot
        uint256 insufficientAmount = game.BetSize() - 1; // Just below the minimum bet size
        
        // Place bet with insufficient amount
        vm.startPrank(player1);
        
        // Expect the transaction to revert with InvalidBetAmount
        vm.expectRevert(abi.encodeWithSelector(DegensAbove.InvalidBetAmount.selector));
        game.placeBet{value: insufficientAmount}(raceID, chariotID);
        
        vm.stopPrank();
    }
    
    function test_placeBet_adds_rake_to_next_race() public {
        // Create two races
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        
        // Create the next race without ending the current one
        // We need to do this in a way that doesn't roll the block number
        // to avoid triggering the RaceEnded check
        
        // Record the current race end block
        uint256 currentRaceEndsAt = game.RaceEndsAtBlock(currentRaceID);
        
        // Create a mock DevDegensAbove to create the next race
        DevDegensAbove mockGame = new DevDegensAbove();
        
        // Create a race in the mock game (this will be race ID 1)
        mockGame.nextRace();
        
        // Get the next race ID for our main game
        uint256 nextRaceID = currentRaceID + 1;
        
        // Record initial state
        uint256 initialCurrentRacePot = game.RacePot(currentRaceID);
        uint256 initialNextRacePot = game.RacePot(nextRaceID);
        
        // Place bet on current race
        uint256 chariotID = 5;
        uint256 betAmount = game.BetSize();
        
        vm.startPrank(player1);
        game.placeBet{value: betAmount}(currentRaceID, chariotID);
        vm.stopPrank();
        
        // Calculate expected rake (1/8 of bet amount)
        uint256 expectedRake = betAmount / 8;
        uint256 expectedCurrentRacePotIncrease = betAmount - expectedRake;
        
        // Verify that current race pot increased by bet amount minus rake
        assertEq(
            game.RacePot(currentRaceID), 
            initialCurrentRacePot + expectedCurrentRacePotIncrease, 
            "Current race pot should increase by bet amount minus rake"
        );
        
        // Verify that next race pot increased by rake amount
        assertEq(
            game.RacePot(nextRaceID), 
            initialNextRacePot + expectedRake, 
            "Next race pot should increase by rake amount (1/8 of bet)"
        );
    }
    
    function test_placeBet_multiple_adds_rake_to_next_race() public {
        // Create two races
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        
        // Create the next race without ending the current one
        // We need to do this in a way that doesn't roll the block number
        // to avoid triggering the RaceEnded check
        
        // Record the current race end block
        uint256 currentRaceEndsAt = game.RaceEndsAtBlock(currentRaceID);
        
        // Create a mock DevDegensAbove to create the next race
        DevDegensAbove mockGame = new DevDegensAbove();
        
        // Create a race in the mock game (this will be race ID 1)
        mockGame.nextRace();
        
        // Get the next race ID for our main game
        uint256 nextRaceID = currentRaceID + 1;
        
        // Use scopes to reduce stack variables
        {
            // Record initial state
            uint256 initialCurrentRacePot = game.RacePot(currentRaceID);
            uint256 initialNextRacePot = game.RacePot(nextRaceID);
            
            // Place multiple bets on current race
            uint256 chariotID = 5;
            uint256 numBets = 3;
            uint256 totalBetAmount = numBets * game.BetSize();
            
            vm.startPrank(player1);
            game.placeBet{value: totalBetAmount}(currentRaceID, chariotID);
            vm.stopPrank();
            
            // Calculate expected rake (1/8 of total bet amount)
            uint256 expectedRake = totalBetAmount / 8;
            uint256 expectedCurrentRacePotIncrease = totalBetAmount - expectedRake;
            
            // Verify that current race pot increased by total bet amount minus rake
            assertEq(
                game.RacePot(currentRaceID), 
                initialCurrentRacePot + expectedCurrentRacePotIncrease, 
                "Current race pot should increase by total bet amount minus rake"
            );
            
            // Verify that next race pot increased by rake amount
            assertEq(
                game.RacePot(nextRaceID), 
                initialNextRacePot + expectedRake, 
                "Next race pot should increase by rake amount (1/8 of bet)"
            );
        }
    }
    
    function test_increasePot() public {
        // Create a race
        game.nextRace();
        uint256 raceID = game.NumRaces();
        
        // Record initial state
        uint256 initialRacePot = game.RacePot(raceID);
        uint256 initialRaceBalance = game.RaceBalance(raceID);
        uint256 initialPlayerBalance = player1.balance;
        
        // Amount to add to pot
        uint256 addAmount = 500 ether;
        
        // Increase pot as player
        vm.startPrank(player1);
        
        // Expect the PotIncreased event
        vm.expectEmit(true, true, true, true);
        emit PotIncreased(raceID, player1, addAmount);
        
        game.increasePot{value: addAmount}(raceID);
        vm.stopPrank();
        
        // Verify state changes
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
        // Create a race
        game.nextRace();
        uint256 raceID = game.NumRaces();
        
        // Record initial state
        uint256 initialRacePot = game.RacePot(raceID);
        uint256 initialRaceBalance = game.RaceBalance(raceID);
        
        // Try to increase pot with zero amount
        vm.startPrank(player1);
        game.increasePot{value: 0}(raceID);
        vm.stopPrank();
        
        // Verify state remains unchanged
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
        // Create only one race
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        uint256 nextRaceID = currentRaceID + 1; // This race doesn't exist yet
        
        // Record initial state
        uint256 initialCurrentRacePot = game.RacePot(currentRaceID);
        
        // Place bet on current race
        uint256 chariotID = 5;
        uint256 betAmount = game.BetSize();
        
        vm.startPrank(player1);
        game.placeBet{value: betAmount}(currentRaceID, chariotID);
        vm.stopPrank();
        
        // Calculate expected rake (1/8 of bet amount)
        uint256 expectedRake = betAmount / 8;
        uint256 expectedCurrentRacePotIncrease = betAmount - expectedRake;
        
        // Verify that current race pot increased by bet amount minus rake
        assertEq(
            game.RacePot(currentRaceID), 
            initialCurrentRacePot + expectedCurrentRacePotIncrease, 
            "Current race pot should increase by bet amount minus rake"
        );
        
        // Verify that next race pot is set to the rake amount
        assertEq(
            game.RacePot(nextRaceID), 
            expectedRake, 
            "Next race pot should be set to rake amount (1/8 of bet)"
        );
    }
    
    function test_increasePot_future_race() public {
        // Create a race
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        uint256 futureRaceID = currentRaceID + 5; // A race that doesn't exist yet
        
        // Record initial state
        uint256 initialPlayerBalance = player1.balance;
        
        // Amount to add to pot
        uint256 addAmount = 500 ether;
        
        // Increase pot for a future race
        vm.startPrank(player1);
        
        // Expect the PotIncreased event
        vm.expectEmit(true, true, true, true);
        emit PotIncreased(futureRaceID, player1, addAmount);
        
        game.increasePot{value: addAmount}(futureRaceID);
        vm.stopPrank();
        
        // Verify state changes
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
        // Create two races
        game.nextRace();
        uint256 firstRaceID = game.NumRaces();
        
        // Warp to end of first race
        vm.roll(game.RaceEndsAtBlock(firstRaceID) + 1);
        
        game.nextRace();
        uint256 secondRaceID = game.NumRaces();
        
        // Amount to add to pot
        uint256 addAmount = 500 ether;
        
        // Try to increase pot for the past race (should revert)
        vm.startPrank(player1);
        vm.expectRevert(abi.encodeWithSelector(DegensAbove.RaceEnded.selector));
        game.increasePot{value: addAmount}(firstRaceID);
        vm.stopPrank();
        
        // Verify we can still increase pot for the current race
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
        // Create a race
        game.nextRace();
        uint256 raceID = game.NumRaces();
        
        // Advance a few blocks to simulate race in progress
        // but not yet ended
        uint256 currentBlock = block.number;
        uint256 midRaceBlock = currentBlock + 5;
        vm.roll(midRaceBlock);
        
        // Make sure we're still before the race end
        assertLt(midRaceBlock, game.RaceEndsAtBlock(raceID), "Test setup: We should be in the middle of the race");
        
        // Record initial state
        uint256 initialRacePot = game.RacePot(raceID);
        uint256 initialRaceBalance = game.RaceBalance(raceID);
        uint256 initialPlayerBalance = player1.balance;
        
        // Amount to add to pot
        uint256 addAmount = 500 ether;
        
        // Increase pot as player for the race in progress
        vm.startPrank(player1);
        
        // Expect the PotIncreased event
        vm.expectEmit(true, true, true, true);
        emit PotIncreased(raceID, player1, addAmount);
        
        game.increasePot{value: addAmount}(raceID);
        vm.stopPrank();
        
        // Verify state changes
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
        // Create a race
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        uint256 nextRaceID = currentRaceID + 1; // Next race doesn't exist yet
        
        uint256 chariotID = 5;
        uint256 betAmount = game.BetSize();
        uint256 rake = betAmount / 8; // 1/8 of bet amount
        
        vm.startPrank(player1);
        
        // Expect the PotIncreased event for the rake added to the next race
        vm.expectEmit(true, true, true, true);
        emit PotIncreased(nextRaceID, player1, rake);
        
        // Place bet which should add rake to next race and emit the event
        game.placeBet{value: betAmount}(currentRaceID, chariotID);
        
        vm.stopPrank();
        
        // Verify the next race pot was increased by the rake amount
        assertEq(
            game.RacePot(nextRaceID),
            rake,
            "Next race pot should be increased by the rake amount"
        );
    }
    
    function test_placeBet_rejects_nonexistent_race() public {
        // Create a race
        game.nextRace();
        uint256 currentRaceID = game.NumRaces();
        uint256 nonexistentRaceID = currentRaceID + 1; // This race doesn't exist yet
        
        uint256 chariotID = 5;
        uint256 betSize = game.BetSize(); // Store bet size in a variable
        
        // Try to place bet on a non-existent race
        vm.startPrank(player1);
        
        // Expect the transaction to revert with InvalidRaceID
        vm.expectRevert(abi.encodeWithSelector(DegensAbove.InvalidRaceID.selector));
        game.placeBet{value: betSize}(nonexistentRaceID, chariotID);
        
        vm.stopPrank();
    }
    
    function test_placeBet_rejects_ended_race() public {
        // Create a race
        game.nextRace();
        uint256 raceID = game.NumRaces();
        
        // Get the race end block
        uint256 raceEndsAt = game.RaceEndsAtBlock(raceID);
        
        // Advance to the end of the race
        vm.roll(raceEndsAt);
        
        uint256 chariotID = 5;
        uint256 betSize = game.BetSize(); // Store bet size in a variable
        
        // Try to place bet on an ended race
        vm.startPrank(player1);
        
        // Expect the transaction to revert with RaceEnded
        vm.expectRevert(abi.encodeWithSelector(DegensAbove.RaceEnded.selector));
        game.placeBet{value: betSize}(raceID, chariotID);
        
        vm.stopPrank();
    }
    
    function test_placeBet_rejects_after_betting_phase() public {
        // Create a race
        game.nextRace();
        uint256 raceID = game.NumRaces();
        
        // Get the race end block and betting phase end
        uint256 raceStartedAt = game.RaceStartedAt(raceID);
        uint256 bettingPhaseEnd = raceStartedAt + game.BettingPhaseSeconds();
        
        // We need to ensure the race ends after the betting phase
        // Since we can't modify the race end directly, we'll create a new test
        // that focuses only on the betting phase check
        
        // Advance to just after the betting phase
        vm.roll(bettingPhaseEnd + 1);
        
        uint256 chariotID = 5;
        uint256 betSize = game.BetSize(); // Store bet size in a variable
        
        // Try to place bet after the betting phase
        vm.startPrank(player1);
        
        // Expect the transaction to revert with BettingPhaseClosed
        vm.expectRevert(abi.encodeWithSelector(DegensAbove.BettingPhaseClosed.selector));
        game.placeBet{value: betSize}(raceID, chariotID);
        
        vm.stopPrank();
    }
}

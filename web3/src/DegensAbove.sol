// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ArbSys} from "./ArbSys.sol";

/**
 * @title DegensAbove
 * @author zomglings
 * @notice A game where players play as gods betting on and affecting mortal chariot races.
 *
 * @notice Game mechanics:
 *  - Players bet on races in 1000 G7 increments during the betting phase
 *  - Bets are hidden until revealed by players
 *  - Revealing bets mints miracles (ERC1155 tokens)
 *  - Miracles can be burned to speed up or slow down chariots (costs 100 G7)
 *  - 10% of pot seeds the next race, remainder split among winners
 *  - Each race has 16 chariots with varying speeds (0-3)
 *  - Race course length is randomly determined
 */
contract DegensAbove {
    uint256 public constant BetSize = 1024 ether;
    uint256 public constant BettingPhaseBlocks = 40;
    uint256 public constant BaseRaceLength = 32;

    uint256 public NumRaces;
    // Race ID -> entropy for that race
    // Entropy layout (least to most significant):
    //  - 7 bits: Race length in excess of BaseRaceLength
    // - For each chariot 0 - 15, sequentially (total: 224 bits):
    //   - 2 bits: Speed of that chariot (0-3 + 1)
    //   - 4 bits: Horse color
    //   - 4 bits: Chariot color
    //   - 4 bits: Charioteer color
    mapping(uint256 => uint256) public RaceEntropy;
    // Race ID -> Pot size for that race
    mapping(uint256 => uint256) public RacePot;
    // Race ID -> current balance for that race (deposits - rake - withdrawals)
    mapping(uint256 => uint256) public RaceBalance;
    // Race ID -> block number at which betting started
    mapping(uint256 => uint256) public BettingStartedAt;
    // Race ID -> block number at which race started (also when betting ends)
    mapping(uint256 => uint256) public RaceStartedAt;
    // Race ID -> Length of that race
    mapping(uint256 => uint256) public RaceLength;
    // Race ID -> Chariot ID (0-15) -> Speed of that chariot (1-4)
    mapping(uint256 => mapping(uint256 => uint256)) public RaceChariotSpeed;
    // Race ID -> Chariot ID (0-15) -> binpacked attributes for that chariot
    mapping(uint256 => mapping(uint256 => uint256)) public RaceChariotAttributes;
    // Race ID -> Player address -> Chariot ID -> Bet amount
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public RacePlayerChariotBets;
    // Race ID -> Player address -> total amount bet
    mapping(uint256 => mapping(address => uint256)) public RacePlayerTotalBets;
    // Race ID -> Player address -> number of miracles remaining
    mapping(uint256 => mapping(address => uint256)) public RacePlayerMiracles;
    // Race ID -> Chariot ID (0-15) -> block number at which chariot finishes race
    mapping(uint256 => mapping(uint256 => uint256)) public RaceChariotFinishesAtBlock;
    // Race ID -> block number at which race ends
    mapping(uint256 => uint256) public RaceEndsAtBlock;
    // Race ID -> Chariot ID -> whether this chariot won the race
    mapping(uint256 => mapping(uint256 => bool)) public RaceWinners;
    // Race ID -> last block when all chariot positions were snapshotted
    mapping(uint256 => uint256) public RaceLastSnapshotBlock;
    // Race ID -> Chariot ID -> distance traveled at the last snapshot
    mapping(uint256 => mapping(uint256 => uint256)) public RaceChariotPositionSnapshot;

    event NewRace(uint256 indexed raceID, uint256 entropy, uint256 length);
    event ChariotCreated(
        uint256 indexed raceID, uint256 indexed chariotID, uint256 chariotSpeed, uint256 chariotAttributes
    );
    event ChariotUpdated(uint256 indexed raceID, uint256 indexed chariotID, uint256 finishesAtBlockNumber);
    event BetPlaced(uint256 indexed raceID, address indexed player, uint256 indexed chariotID, uint256 numBets);
    event PotIncreased(uint256 indexed raceID, address indexed contributor, uint256 amount);
    event RaceEnded(uint256 indexed raceID);
    event WinningChariot(uint256 indexed raceID, uint256 indexed chariotID);
    event ChariotPositionsUpdated(uint256 indexed raceID, uint256 snapshotBlock);
    event ChariotSpeedChanged(uint256 indexed raceID, uint256 indexed chariotID, uint256 oldSpeed, uint256 newSpeed);

    error RaceNotEnded();
    error RaceAlreadyEnded();
    error InvalidBetAmount();
    error BettingPhaseClosed();
    error BettingPhaseNotStarted();
    error InvalidChariotID();
    error InvalidRaceID();

    constructor() {}

    function _blockNumber() internal view returns (uint256) {
        return ArbSys(address(100)).arbBlockNumber();
    }

    function _blockhash(uint256 number) internal view returns (bytes32) {
        return ArbSys(address(100)).arbBlockHash(number);
    }

    function _entropy() internal view virtual returns (uint256) {
        return uint256(keccak256(abi.encodePacked(blockhash(_blockNumber()), NumRaces)));
    }

    function nextRace() public {
        if (_blockNumber() < RaceEndsAtBlock[NumRaces]) {
            revert RaceNotEnded();
        }
        NumRaces++;

        // Set up betting phase
        uint256 currentBlock = _blockNumber();
        BettingStartedAt[NumRaces] = currentBlock;

        // Race starts after betting phase ends
        RaceStartedAt[NumRaces] = currentBlock + BettingPhaseBlocks;

        RaceEntropy[NumRaces] = _entropy();
        RaceLength[NumRaces] = BaseRaceLength + (RaceEntropy[NumRaces] % 128);
        emit NewRace(NumRaces, RaceEntropy[NumRaces], RaceLength[NumRaces]);

        RaceEndsAtBlock[NumRaces] = type(uint256).max;

        // Initialize the snapshot block to the race start block
        RaceLastSnapshotBlock[NumRaces] = RaceStartedAt[NumRaces];

        uint256 i = 0;
        for (i = 0; i < 16; i++) {
            uint256 chariotEntropy = (RaceEntropy[NumRaces] >> (7 + 16 * i)) & (0xFFFF >> 2);
            RaceChariotSpeed[NumRaces][i] = chariotEntropy % 4 + 1;
            RaceChariotAttributes[NumRaces][i] = chariotEntropy >> 2;
            emit ChariotCreated(NumRaces, i, RaceChariotSpeed[NumRaces][i], RaceChariotAttributes[NumRaces][i]);

            // Initialize position snapshot to 0 (starting line)
            RaceChariotPositionSnapshot[NumRaces][i] = 0;

            uint256 blocksToFinish = RaceLength[NumRaces] / RaceChariotSpeed[NumRaces][i];
            if (RaceChariotSpeed[NumRaces][i] * blocksToFinish < RaceLength[NumRaces]) {
                blocksToFinish++;
            }
            // Chariots finish relative to race start, not betting start
            RaceChariotFinishesAtBlock[NumRaces][i] = RaceStartedAt[NumRaces] + blocksToFinish;
            if (RaceEndsAtBlock[NumRaces] > RaceChariotFinishesAtBlock[NumRaces][i]) {
                RaceEndsAtBlock[NumRaces] = RaceChariotFinishesAtBlock[NumRaces][i];
            }
            emit ChariotUpdated(NumRaces, i, RaceChariotFinishesAtBlock[NumRaces][i]);
        }

        // Emit initial positions event
        emit ChariotPositionsUpdated(NumRaces, RaceLastSnapshotBlock[NumRaces]);
    }

    function placeBet(uint256 raceID, uint256 chariotID) external payable {
        if (msg.value < BetSize) {
            revert InvalidBetAmount();
        }

        if (raceID > NumRaces) {
            revert InvalidRaceID();
        }

        uint256 currentBlock = _blockNumber();

        // Check that betting has started
        if (currentBlock < BettingStartedAt[raceID]) {
            revert BettingPhaseNotStarted();
        }

        // Check that betting phase is still open
        if (currentBlock >= RaceStartedAt[raceID]) {
            revert BettingPhaseClosed();
        }

        if (chariotID >= 16) {
            revert InvalidChariotID();
        }

        uint256 numBets = msg.value / BetSize;
        uint256 betAmount = numBets * BetSize;
        uint256 remainder = msg.value - betAmount;

        uint256 rake = betAmount >> 3;

        uint256 currentRacePotAmount = betAmount - rake;
        _increasePot(raceID, currentRacePotAmount);
        if (rake > 0) {
            _increasePot(raceID + 1, rake);
        }

        RacePlayerChariotBets[raceID][msg.sender][chariotID] += numBets;
        RacePlayerTotalBets[raceID][msg.sender] += numBets;

        emit BetPlaced(raceID, msg.sender, chariotID, numBets);

        if (remainder > 0) {
            (bool success,) = msg.sender.call{value: remainder}("");
            require(success, "Failed to return remainder");
        }
    }

    // Internal function to increase pot with a specific amount
    function _increasePot(uint256 raceID, uint256 amount) internal {
        // If this is a past race (has ended), always revert
        if (raceID <= NumRaces && _blockNumber() >= RaceEndsAtBlock[raceID]) {
            revert RaceAlreadyEnded();
        }

        // Only update state if amount is greater than 0
        if (amount > 0) {
            // Update the race pot and balance
            RacePot[raceID] += amount;
            RaceBalance[raceID] += amount;

            // Emit the PotIncreased event
            emit PotIncreased(raceID, msg.sender, amount);
        }
    }

    // External function to increase pot with msg.value
    function increasePot(uint256 raceID) external payable {
        _increasePot(raceID, msg.value);
    }

    /**
     * @notice Calculate the current position of a chariot based on the last snapshot and elapsed time
     * @param raceID The ID of the race
     * @param chariotID The ID of the chariot
     * @return The current position (distance traveled) of the chariot
     */
    function getChariotPosition(uint256 raceID, uint256 chariotID) public view returns (uint256) {
        if (raceID > NumRaces || chariotID >= 16) {
            return 0;
        }

        uint256 currentBlock = _blockNumber();

        // If race hasn't started yet, position is 0
        if (currentBlock < RaceStartedAt[raceID]) {
            return 0;
        }

        // If we're past the finish block for this chariot, it has completed the race
        if (currentBlock >= RaceChariotFinishesAtBlock[raceID][chariotID]) {
            return RaceLength[raceID];
        }

        // Calculate position based on snapshot and elapsed time
        uint256 elapsedBlocks =
            currentBlock > RaceLastSnapshotBlock[raceID] ? currentBlock - RaceLastSnapshotBlock[raceID] : 0;

        uint256 distanceSinceSnapshot = elapsedBlocks * RaceChariotSpeed[raceID][chariotID];
        uint256 totalDistance = RaceChariotPositionSnapshot[raceID][chariotID] + distanceSinceSnapshot;

        // Cap at race length
        return totalDistance < RaceLength[raceID] ? totalDistance : RaceLength[raceID];
    }

    /**
     * @notice Update all chariot positions and take a new snapshot
     * @param raceID The ID of the race to update
     */
    function _updateChariotPositions(uint256 raceID) internal {
        uint256 currentBlock = _blockNumber();

        // Only update if race has started but not ended
        if (currentBlock < RaceStartedAt[raceID] || currentBlock >= RaceEndsAtBlock[raceID]) {
            return;
        }

        // Update position snapshots for all chariots
        for (uint256 i = 0; i < 16; i++) {
            RaceChariotPositionSnapshot[raceID][i] = getChariotPosition(raceID, i);
        }

        // Update the snapshot block
        RaceLastSnapshotBlock[raceID] = currentBlock;

        // Emit event for the update
        emit ChariotPositionsUpdated(raceID, currentBlock);
    }

    /**
     * @notice Change the speed of a chariot and update all position snapshots
     * @param raceID The ID of the race
     * @param chariotID The ID of the chariot to modify
     * @param newSpeed The new speed for the chariot (1-4)
     */
    function changeChariotSpeed(uint256 raceID, uint256 chariotID, uint256 newSpeed) external {
        if (raceID > NumRaces) {
            revert InvalidRaceID();
        }

        if (chariotID >= 16) {
            revert InvalidChariotID();
        }

        uint256 currentBlock = _blockNumber();

        // Can only change speed if race has started but not ended
        if (currentBlock < RaceStartedAt[raceID]) {
            revert BettingPhaseNotStarted();
        }

        if (currentBlock >= RaceEndsAtBlock[raceID]) {
            revert RaceAlreadyEnded();
        }

        // Speed must be between 1 and 4
        require(newSpeed >= 1 && newSpeed <= 4, "Invalid speed");

        // Store old speed for the event
        uint256 oldSpeed = RaceChariotSpeed[raceID][chariotID];

        // Update all chariot positions first
        _updateChariotPositions(raceID);

        // Change the speed
        RaceChariotSpeed[raceID][chariotID] = newSpeed;

        // Recalculate finish block for this chariot
        uint256 remainingDistance = RaceLength[raceID] - RaceChariotPositionSnapshot[raceID][chariotID];
        uint256 blocksToFinish = remainingDistance / newSpeed;
        if (newSpeed * blocksToFinish < remainingDistance) {
            blocksToFinish++;
        }

        // Update finish block
        RaceChariotFinishesAtBlock[raceID][chariotID] = currentBlock + blocksToFinish;

        // Update race end block if this chariot now finishes earlier than the current earliest
        if (RaceChariotFinishesAtBlock[raceID][chariotID] < RaceEndsAtBlock[raceID]) {
            RaceEndsAtBlock[raceID] = RaceChariotFinishesAtBlock[raceID][chariotID];
        }

        // Emit events
        emit ChariotSpeedChanged(raceID, chariotID, oldSpeed, newSpeed);
        emit ChariotUpdated(raceID, chariotID, RaceChariotFinishesAtBlock[raceID][chariotID]);
    }

    /**
     * @notice Ends a race, determines winners, and optionally starts the next race
     * @param raceID The ID of the race to end
     * @param startNextRace Whether to automatically start the next race
     */
    function endRace(uint256 raceID, bool startNextRace) external {
        if (raceID > NumRaces) {
            revert InvalidRaceID();
        }

        uint256 currentBlock = _blockNumber();
        if (currentBlock < RaceEndsAtBlock[raceID]) {
            revert RaceNotEnded();
        }

        // Update all positions one final time to get accurate final positions
        _updateChariotPositions(raceID);

        // Find the maximum distance traveled (some chariots might not complete the full race)
        uint256 maxDistance = 0;
        for (uint256 i = 0; i < 16; i++) {
            if (RaceChariotPositionSnapshot[raceID][i] > maxDistance) {
                maxDistance = RaceChariotPositionSnapshot[raceID][i];
            }
        }

        // Mark winners (chariots that traveled the maximum distance)
        for (uint256 i = 0; i < 16; i++) {
            if (RaceChariotPositionSnapshot[raceID][i] == maxDistance) {
                RaceWinners[raceID][i] = true;
                emit WinningChariot(raceID, i);
            }
        }

        emit RaceEnded(raceID);

        if (startNextRace) {
            nextRace();
        }
    }
}

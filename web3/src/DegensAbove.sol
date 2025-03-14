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
    uint256 public constant BettingPhaseSeconds = 60;
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
    // Race ID -> block number at which race started
    mapping(uint256 => uint256) public RaceStartedAt;
    // Race ID -> Length of that race
    mapping(uint256 => uint256) public RaceLength;
    // Race ID -> Winner of that race
    mapping(uint256 => uint256) public RaceWinner;
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

    event NewRace(uint256 indexed raceID, uint256 entropy, uint256 length);
    event ChariotCreated(uint256 indexed raceID, uint256 indexed chariotID, uint256 chariotSpeed, uint256 chariotAttributes);
    event ChariotUpdated(uint256 indexed raceID, uint256 indexed chariotID, uint256 finishesAtBlockNumber);
    event BetPlaced(uint256 indexed raceID, address indexed player, uint256 indexed chariotID, uint256 numBets);
    event PotIncreased(uint256 indexed raceID, address indexed contributor, uint256 amount);

    error RaceNotEnded();
    error RaceEnded();
    error InvalidBetAmount();
    error BettingPhaseClosed();
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
        RaceStartedAt[NumRaces] = _blockNumber();
        RaceEntropy[NumRaces] = _entropy();
        RaceLength[NumRaces] = BaseRaceLength + (RaceEntropy[NumRaces] % 128);
        emit NewRace(NumRaces, RaceEntropy[NumRaces], RaceLength[NumRaces]);

        RaceEndsAtBlock[NumRaces] = type(uint256).max;
        
        uint256 i = 0;
        for (i = 0; i < 16; i++) {
            uint256 chariotEntropy = (RaceEntropy[NumRaces] >> (7 + 16*i)) & (0xFFFF >> 2);
            RaceChariotSpeed[NumRaces][i] = chariotEntropy % 4 + 1;
            RaceChariotAttributes[NumRaces][i] = chariotEntropy >> 2;
            emit ChariotCreated(NumRaces, i, RaceChariotSpeed[NumRaces][i], RaceChariotAttributes[NumRaces][i]);

            uint256 blocksToFinish = RaceLength[NumRaces] / RaceChariotSpeed[NumRaces][i];
            if (RaceChariotSpeed[NumRaces][i] * blocksToFinish < RaceLength[NumRaces]) {
                blocksToFinish++;
            }
            RaceChariotFinishesAtBlock[NumRaces][i] = block.number + blocksToFinish;
            if (RaceEndsAtBlock[NumRaces] > RaceChariotFinishesAtBlock[NumRaces][i]) {
                RaceEndsAtBlock[NumRaces] = RaceChariotFinishesAtBlock[NumRaces][i];
            }
            emit ChariotUpdated(NumRaces, i, RaceChariotFinishesAtBlock[NumRaces][i]);
        }
    }

    function placeBet(uint256 raceID, uint256 chariotID) external payable {
        if (msg.value < BetSize) {
            revert InvalidBetAmount();
        }

        if (raceID > NumRaces) {
            revert InvalidRaceID();
        }

        if (_blockNumber() > RaceStartedAt[raceID] + BettingPhaseSeconds) {
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
            (bool success, ) = msg.sender.call{value: remainder}("");
            require(success, "Failed to return remainder");
        }
    }

    // Internal function to increase pot with a specific amount
    function _increasePot(uint256 raceID, uint256 amount) internal {
        // If this is a past race (has ended), always revert
        if (raceID <= NumRaces && _blockNumber() >= RaceEndsAtBlock[raceID]) {
            revert RaceEnded();
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
}

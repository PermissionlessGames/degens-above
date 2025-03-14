// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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
    // Race ID -> Pot size for that race
    mapping(uint256 => uint256) public RacePot;
    // Race ID -> current balance for that race (deposits - rake - withdrawals)
    mapping(uint256 => uint256) public RaceBalance;
    // Race ID -> Started at timestamp
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
    // Race ID -> Player address -> number of miracles remaining
    mapping(uint256 => mapping(address => uint256)) public RacePlayerMiracles;
    // Race ID -> binpacked timestamps at which chariots finish the race
    mapping(uint256 => uint256) public RaceChariotFinishesAt;
    // Race ID -> ends at timestamp
    mapping(uint256 => uint256) public RaceEndsAt;

    constructor() {}
}

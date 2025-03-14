// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DegensAbove} from "../DegensAbove.sol";

// Inspired by DevDegensGambit:
// https://github.com/PermissionlessGames/degen-casino/blob/b808123f0397994524175902914cdc9e3317ef49/src/dev/DevDegenGambit.sol

contract DevDegensAbove is DegensAbove {
    uint256 CurrentEntropy;
    bool public EntropyIsHash;

    constructor() DegensAbove() {}

    function setEntropySource(bool isFromHash) external {
        EntropyIsHash = isFromHash;
    }

    function setEntropy(uint256 entropy) public {
        CurrentEntropy = entropy;
    }

    function _entropy() internal view override returns (uint256) {
        if (EntropyIsHash) {
            return super._entropy();
        } else {
            return CurrentEntropy;
        }
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Test token used to produce a Sepolia Transfer event for the camp exercise.
contract CampTestToken is ERC20 {
    constructor() ERC20("Camp Test Token", "CAMP") {
        _mint(msg.sender, 1_000 ether);
    }
}

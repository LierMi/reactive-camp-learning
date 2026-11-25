// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AbstractReactive} from "@reactive/src/base/AbstractReactive.sol";

/// @notice Watches Transfer events from one Sepolia ERC-20 token.
contract SepoliaTransferMonitor is AbstractReactive {
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant TRANSFER_TOPIC = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    error InvalidSetup();
    error NotOwner();
    error StillSubscribed();
    error OutstandingDebt();
    error WithdrawalFailed();

    event TransferSeen(
        address indexed token, address indexed from, address indexed to, uint256 amount, uint256 sourceTxHash
    );

    address public immutable owner;
    address public immutable token;
    uint256 public remaining;
    uint256 public seen;
    uint256 public lastAmount;
    uint256 public lastTxHash;

    constructor(address token_, uint256 maxEvents_) payable {
        if (token_ == address(0) || maxEvents_ == 0) revert InvalidSetup();
        owner = msg.sender;
        token = token_;
        remaining = maxEvents_;
        SYSTEM.subscribe(SEPOLIA_CHAIN_ID, token_, TRANSFER_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    function react(LogRecord calldata log_) external onlySystem {
        if (
            remaining == 0 || log_.chainId != SEPOLIA_CHAIN_ID || log_.contractAddress != token
                || log_.topic0 != TRANSFER_TOPIC || log_.opCode != 3 || log_.data.length != 32
        ) return;

        uint256 amount = abi.decode(log_.data, (uint256));
        // ERC-20 address topics are left-padded to 256 bits; the low 160 bits are the address.
        // forge-lint: disable-next-line(unsafe-typecast)
        address from = address(uint160(log_.topic1));
        // forge-lint: disable-next-line(unsafe-typecast)
        address to = address(uint160(log_.topic2));

        seen += 1;
        lastAmount = amount;
        lastTxHash = log_.txHash;
        remaining -= 1;
        emit TransferSeen(token, from, to, amount, log_.txHash);

        if (remaining == 0) {
            SYSTEM.unsubscribe(
                SEPOLIA_CHAIN_ID, token, TRANSFER_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
            );
        }
    }

    /// @notice Return unused deployment funds after the monitor has stopped and its debt is zero.
    function withdraw() external {
        if (msg.sender != owner) revert NotOwner();
        if (remaining != 0) revert StillSubscribed();
        if (SYSTEM.debt(address(this)) != 0) revert OutstandingDebt();
        (bool success,) = payable(owner).call{value: address(this).balance}("");
        if (!success) revert WithdrawalFailed();
    }
}

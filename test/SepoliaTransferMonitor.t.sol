// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {IReactive} from "@reactive/src/interfaces/IReactive.sol";
import {AbstractPayer} from "@reactive/src/base/AbstractPayer.sol";
import {SepoliaTransferMonitor} from "../src/SepoliaTransferMonitor.sol";

contract RecordingSystem {
    uint256 public chainId;
    address public token;
    uint256 public topic0;
    uint256 public topic1;
    uint256 public topic2;
    uint256 public topic3;
    bool public active;

    function subscribe(
        uint256 chainId_,
        address token_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external {
        chainId = chainId_;
        token = token_;
        topic0 = topic0_;
        topic1 = topic1_;
        topic2 = topic2_;
        topic3 = topic3_;
        active = true;
    }

    function unsubscribe(
        uint256 chainId_,
        address token_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external {
        require(active && chainId == chainId_ && token == token_ && topic0 == topic0_);
        require(topic1 == topic1_ && topic2 == topic2_ && topic3 == topic3_);
        active = false;
    }

    function debt(address) external pure returns (uint256) {
        return 0;
    }
}

contract SepoliaTransferMonitorTest is Test {
    address internal constant SYSTEM = 0x8888888888888888888888888888888888888888;
    address internal constant TOKEN = address(0x1234);
    address internal constant RECIPIENT = address(0xB0B);
    uint256 internal constant TRANSFER_TOPIC = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    uint256 internal constant IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    RecordingSystem internal system;
    SepoliaTransferMonitor internal monitor;

    function setUp() public {
        vm.etch(SYSTEM, address(new RecordingSystem()).code);
        system = RecordingSystem(SYSTEM);
        vm.deal(address(this), 1 ether);
        monitor = new SepoliaTransferMonitor{value: 0.1 ether}(TOKEN, RECIPIENT, 2);
    }

    function test_constructorSubscribesOnlyToChosenToken() public view {
        assertEq(system.chainId(), 11155111);
        assertEq(system.token(), TOKEN);
        assertEq(system.topic0(), TRANSFER_TOPIC);
        assertEq(system.topic1(), IGNORE);
        assertEq(system.topic2(), uint256(uint160(RECIPIENT)));
        assertEq(system.topic3(), IGNORE);
        assertTrue(system.active());
        assertEq(address(monitor).balance, 0.1 ether);
    }

    function test_reactCountsTransfersAndUnsubscribesAtLimit() public {
        IReactive.LogRecord memory record = transferRecord(100, 0xabc);
        vm.prank(SYSTEM);
        monitor.react(record);
        assertEq(monitor.seen(), 1);
        assertEq(monitor.remaining(), 1);
        assertEq(monitor.lastAmount(), 100);
        assertEq(monitor.lastTxHash(), 0xabc);
        assertTrue(system.active());

        vm.prank(SYSTEM);
        monitor.react(transferRecord(250, 0xdef));
        assertEq(monitor.seen(), 2);
        assertEq(monitor.remaining(), 0);
        assertFalse(system.active());
    }

    function test_reactRejectsAnyoneExceptSystem() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(AbstractPayer.NotAuthorized.selector, address(0xBEEF), SYSTEM));
        monitor.react(transferRecord(100, 0xabc));
    }

    function test_unexpectedLogReturnsWithoutCounting() public {
        IReactive.LogRecord memory record = transferRecord(100, 0xabc);
        record.contractAddress = address(0x9999);
        vm.prank(SYSTEM);
        monitor.react(record);
        assertEq(monitor.seen(), 0);
        assertEq(monitor.remaining(), 2);
        assertTrue(system.active());
    }

    function test_transferToOtherRecipientReturnsWithoutCounting() public {
        IReactive.LogRecord memory record = transferRecord(100, 0xabc);
        record.topic2 = uint256(uint160(address(0xCAFE)));
        vm.prank(SYSTEM);
        monitor.react(record);
        assertEq(monitor.seen(), 0);
        assertEq(monitor.remaining(), 2);
        assertTrue(system.active());
    }

    function test_ownerCanWithdrawRemainingFundsAfterUnsubscribe() public {
        vm.prank(SYSTEM);
        monitor.react(transferRecord(100, 0xabc));
        vm.prank(SYSTEM);
        monitor.react(transferRecord(200, 0xdef));
        uint256 beforeBalance = address(this).balance;
        monitor.withdraw();
        assertEq(address(monitor).balance, 0);
        assertEq(address(this).balance, beforeBalance + 0.1 ether);
    }

    function test_cannotWithdrawWhileSubscribed() public {
        vm.expectRevert();
        monitor.withdraw();
    }

    function transferRecord(uint256 amount, uint256 txHash) internal pure returns (IReactive.LogRecord memory record) {
        record.chainId = 11155111;
        record.contractAddress = TOKEN;
        record.topic0 = TRANSFER_TOPIC;
        record.topic1 = uint256(uint160(address(0xA11CE)));
        record.topic2 = uint256(uint160(RECIPIENT));
        record.opCode = 3;
        record.data = abi.encode(amount);
        record.txHash = txHash;
    }

    receive() external payable {}
}

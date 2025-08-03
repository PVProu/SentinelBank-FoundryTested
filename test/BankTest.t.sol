//License
// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/ImprovedCryptoBank.sol";
import "../src/BankFeesBox.sol";

contract BankTest is Test {
    ImprovedCryptoBank public bank;
    BankFeesBox public feesBox;

    address user1 = vm.addr(1);
    address user2 = vm.addr(2);
    address admin = vm.addr(3);
    uint256 maxBalance = 5 ether;
    uint256 nullNum = 0;

    event WithdrawSuccess(address to, uint256 amount);
    event FeeDeposit(uint256 amount);

    function setUp() public {
        feesBox = new BankFeesBox(admin);
        bank = new ImprovedCryptoBank(maxBalance, admin, address(feesBox));
    }

    function testDepositEther() public {
        vm.deal(user1, 10 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 1 ether}();
        assertEq(bank.userBalance(user1), 1 ether);
        vm.stopPrank();
    }

    function testCannotDepositMoreThanMaxBalance() public {
        vm.deal(user1, 10 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 5 ether}();
        vm.startPrank(user1);
        vm.expectRevert(bytes("Max balance reached"));
        bank.depositEther{value: 1 wei}();
        vm.stopPrank();
    }

    function testCannotWithdrawMoreThanBalance() public {
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 0.5 ether}();
        vm.startPrank(user1);
        vm.expectRevert(bytes("Not enough ether"));
        bank.withdrawEther(0.6 ether);
        vm.stopPrank();
    }

    function testWithdrawEtherAndSendFee() public {
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 1 ether}();
        bank.withdrawEther(1 ether);
        assertEq(feesBox.boxBalance(), 0.01 ether);
        assertEq(bank.userBalance(user1), 0);
        vm.stopPrank();
    }

    function testCannotWithdrawIfFeeBoxUnset() public {
        bank = new ImprovedCryptoBank(maxBalance, admin, address(0));
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 1 ether}();
        vm.startPrank(user1);
        vm.expectRevert(bytes("Invalid fee box address"));
        bank.withdrawEther(1 ether);
        vm.stopPrank();
    }

    function testOnlyAdminCanModifyFee() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes("Not admin"));
        bank.modifyFee(2);
        vm.expectRevert(bytes("Not admin"));
        bank.modifyFee(3);
        vm.stopPrank();
    }

    function testOnlyAdminCanModifyMaxBalance() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes("Not admin"));
        bank.modifyMaxBalance(10 ether);
        vm.expectRevert(bytes("Not admin"));
        bank.modifyMaxBalance(3 ether);
        vm.stopPrank();
    }

    function testManagerCanWithdrawFees() public {
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 1 ether}();
        vm.startPrank(user1);
        bank.withdrawEther(1 ether);
        vm.startPrank(admin);
        feesBox.addManager(user2);
        vm.startPrank(user2);
        feesBox.withdrawEth(0.01 ether);
        assertEq(feesBox.boxBalance(), 0);
        vm.stopPrank();
    }

    function testOnlyOwnerCanManageFeesBoxManagers() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes("Only owner can add manager"));
        feesBox.addManager(user2);
        vm.startPrank(user1);
        vm.expectRevert(bytes("Only owner can delete manager"));
        feesBox.deleteManager(admin);
        vm.stopPrank();
    }

    function testCannotWithdrawFeesIfNotManager() public {
        vm.expectRevert(bytes("Not authorized"));
        feesBox.withdrawEth(1 ether);
    }

    function testWithdrawRevertsIfFeeTooHigh() public {
        vm.startPrank(admin);
        bank.modifyFee(100);
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 1 ether}();
        vm.expectRevert("Amount after fees must be more than 0");
        bank.withdrawEther(1 ether);
    }

    function testAddManagerFailsIfNotOwner() public {
        vm.expectRevert("Only owner can add manager");
        vm.startPrank(address(0x123));
        feesBox.addManager(address(0x456));
        vm.stopPrank();
    }

    function testDeleteManagerFailsIfNotOwner() public {
        vm.startPrank(address(0x123));
        vm.expectRevert("Only owner can delete manager");
        feesBox.deleteManager(admin); // Admin is manager, but who is calling is not the manager
        vm.stopPrank();
    }

    function testDeleteManagerFailsIfNotManager() public {
        vm.startPrank(admin);
        vm.expectRevert("Not manager");
        feesBox.deleteManager(address(0x999)); // It s not a manager
        vm.stopPrank();
    }

    function testWithdrawFailsIfAmountAfterFeeZero() public {
        vm.startPrank(admin);
        bank.modifyFee(100);
        vm.stopPrank();
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        bank.depositEther{value: 1 ether}();
        vm.expectRevert("Amount after fees must be more than 0");
        bank.withdrawEther(0 ether);
        vm.stopPrank();
    }

    function testWithdrawFailsIfFeesBoxAddressIsZero() public {
        vm.startPrank(admin);
        ImprovedCryptoBank badBank = new ImprovedCryptoBank(5 ether, admin, address(0));

        vm.stopPrank();
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        badBank.depositEther{value: 1 ether}();

        vm.expectRevert("Invalid fee box address");
        badBank.withdrawEther(0.5 ether);
        vm.stopPrank();
    }
    
    function testCannotDeleteIfNotManager() public {
        vm.startPrank(admin);
        feesBox.addManager(user1);
        feesBox.deleteManager(user1);
        vm.stopPrank();
    }

    function testInitialFeeIsOnePercent() public {
        uint256 fee = bank.fee();
        assertEq(fee, 1);
    }

    function testInitialMaxBalance() public {
        uint256 max = bank.maxBalance();
        assertEq(max, maxBalance);
    }

    function testModifyMaxBalanceByAdmin() public {
        vm.startPrank(admin);
        bank.modifyMaxBalance(10 ether);
        assertEq(bank.maxBalance(), 10 ether);
        vm.stopPrank();
    }

    function testModifyFeeByAdmin() public {
        vm.startPrank(admin);
        bank.modifyFee(3);
        assertEq(bank.fee(), 3);
        vm.stopPrank();
    }

    function testFeeDepositEventEmitted() public {
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 1 ether}();
        vm.expectEmit(true, false, false, true);
        emit FeeDeposit(0.01 ether);
        bank.withdrawEther(1 ether);
        vm.stopPrank();
    }

    function testWithdrawSuccessEventEmitted() public {
        vm.startPrank(admin);
        feesBox.addManager(user1);
        vm.stopPrank();

        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 1 ether}();
        bank.withdrawEther(1 ether);
        vm.expectEmit(true, true, false, true);
        emit WithdrawSuccess(user1, 0.01 ether);
        feesBox.withdrawEth(0.01 ether);
        vm.stopPrank();
    }

    function testDepositEtherMultipleTimes() public {
        vm.deal(user1, 5 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 2 ether}();
        bank.depositEther{value: 1 ether}();
        bank.depositEther{value: 2 ether}();
        assertEq(bank.userBalance(user1), 5 ether);
        vm.stopPrank();
    }

    function testDepositRevertExactlyMaxBalance() public {
        vm.deal(user1, 6 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 5 ether}();
        vm.expectRevert("Max balance reached");
        bank.depositEther{value: 1 wei}();
        vm.stopPrank();
    }

    function testWithdrawAllWithNonZeroFee() public {
        vm.deal(user1, 2 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 2 ether}();
        bank.withdrawEther(2 ether);
        assertEq(bank.userBalance(user1), 0);
        assertEq(feesBox.boxBalance(), (2 ether * 1) / 100);
        vm.stopPrank();
    }

    function testFeeCalculationAccuracy() public {
        vm.startPrank(admin);
        bank.modifyFee(3); // 3%
        vm.stopPrank();

        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        bank.depositEther{value: 1 ether}();
        bank.withdrawEther(1 ether);
        uint256 expectedFee = (1 ether * 3) / 100;
        assertEq(feesBox.boxBalance(), expectedFee);
        vm.stopPrank();
    }


// Fuzzing testing
    function testFuzzingDepositWithinLimit(uint256 amount_) public {
        vm.assume(amount_ <= maxBalance);

        vm.deal(user1, amount_);
        vm.startPrank(user1);
        bank.depositEther{value: amount_}();
        vm.stopPrank();
    }

    function testFuzzingWithdrawExactBalance(uint256 amount_) public {
        vm.assume(amount_ <= maxBalance);
        vm.assume(amount_ > nullNum);
        vm.deal(user1, amount_);
        vm.startPrank(user1);
        bank.depositEther{value: amount_}();
        bank.withdrawEther(amount_);
        uint256 expectedFee = (amount_ * bank.fee()) / 100;
        vm.stopPrank();
    }

    function testFuzzingModifyFeeWithinRange(uint256 num1_) public {
        vm.startPrank(admin);
        bank.modifyFee(num1_);
        assertEq(bank.fee(), num1_);
        vm.stopPrank();
    }

    function testFuzzingModifyMaxBalance(uint256 newMax_) public {
        vm.startPrank(admin);
        bank.modifyMaxBalance(newMax_);
        assertEq(bank.maxBalance(), newMax_);
        vm.stopPrank();
    }

    function testFuzzingFailWithdrawMoreThanBalance(uint256 deposit_, uint256 withdraw_) public {
        vm.assume(deposit_ <= maxBalance);
        vm.assume(withdraw_ > deposit_);

        vm.deal(user2, deposit_);
        vm.startPrank(user2);
        bank.depositEther{value: deposit_}();
        vm.expectRevert(bytes("Not enough ether"));
        bank.withdrawEther(withdraw_);
        vm.stopPrank();
    }

}

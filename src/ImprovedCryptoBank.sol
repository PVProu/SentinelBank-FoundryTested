//License
// SPDX-License-Identifier: LGPL-3.0-only

// Solidity version
pragma solidity 0.8.30;

import "./IBankFeesBox.sol";

//Functions: 
    // 1. Diposit Ether
    // 2. Withdraw Ether (+ fees sent to the fees bank box)
    // 3. Modify max balance (only by admin)
    // 4. Modify fee (only by admin)

//Rules:
    // 1. Multiuser
    // 2. Only users can deposit ether
    // 3. User can only withdraw previously deposited ether
    // 4. MAX balance = 5 ether
    // 5. MaxBalance modifiable by owner
    // 6. Fees modifiable by owner
    // 7. Fees sent authomatically to feesBoxing contract

contract ImprovedCryptoBank{

    // Variables
    uint256 public maxBalance;
    address public admin;
    uint256 public fee;
    address public feesBoxing;

    mapping (address => uint256) public userBalance;

    //Events
    event EtherDeposit(address user_, uint256 etherAmount_);
    event EtherWithdraw(address user_, uint256 etherAmount_);
    event MaxBalanceChanged(uint256 newMaxBalance_);
    event FeeChanged(uint newFee_);

    // Modifiers
    modifier onlyAdmin(){
        require (msg.sender == admin, "Not admin");
        _;
    }

    constructor(uint256 maxBalance_, address admin_, address feesBoxing_){
            maxBalance = maxBalance_;
            feesBoxing = feesBoxing_;
            admin = admin_;
            fee = 1;
    }

    //Functions

    // 1 . Deposit
    function depositEther() external payable{
        require(userBalance[msg.sender] + msg.value <= maxBalance, "Max balance reached");
        userBalance[msg.sender] += msg.value;
         // When we are sending or receiving ether, ALWAYS use msg.value due to security reasons
        emit EtherDeposit(msg.sender, msg.value);
    }

    // 2. Withdraw
    function withdrawEther(uint256 amount_) external{
        // CEI pattern: 1-checks, 2- Effects, 3-interactions, otherwise it can be vulnerable for hacking attacks (like reentrancy attacks)
        require(amount_ <= userBalance[msg.sender], "Not enough ether");
        // 1. Update state and calculate fee
        uint256 feeAmount = (amount_ * fee) / 100;
        uint256 amountToWithdraw = amount_ - feeAmount;
        require(amountToWithdraw > 0, "Amount after fees must be more than 0");
        require(feesBoxing != address(0), "Invalid fee box address");

        userBalance[msg.sender] -= amount_;
        // Send fees to the bank fee box
        IBankFeesBox(feesBoxing).receiveFees{value: feeAmount}();
        // 2. Transfer ether
        (bool success,) = msg.sender.call{value: amountToWithdraw}("");
        require(success, "Failed to send ether");

        emit EtherWithdraw(msg.sender, amount_);
    }

    // 3. Modify maxBalance
    function modifyMaxBalance(uint256 newMaxBalance_) external onlyAdmin{
        maxBalance = newMaxBalance_;
        emit MaxBalanceChanged(maxBalance);
    }
    // 4. Modify fee
    function modifyFee(uint256 newFee_) external onlyAdmin{
        fee = newFee_;
        emit FeeChanged(fee);
    }
}
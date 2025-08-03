//License
// SPDX-License-Identifier: LGPL-3.0-only

// Solidity version
pragma solidity 0.8.30;

contract BankFeesBox{

    address owner;
    uint256 public boxBalance;

    // Mapping to store managers
    mapping(address => bool) public isManager;

    event WithdrawSuccess(address to, uint256 amount);
    event FeeDeposit(uint256 amount);

    // Only manager can withdraw
    modifier onlyAutorized() {
        require(isManager[msg.sender], "Not authorized");
        _;
    }

    // Constructor to set owner
    constructor(address owner_) {
        owner = owner_;
        isManager[owner] = true;
    }

    // Receive fees
    function receiveFees() external payable{
        boxBalance += msg.value;
        emit FeeDeposit(msg.value);
    }

    // Withdraw ETH and recalculate the boxBalance 
    function withdrawEth(uint256 amount) external onlyAutorized{
        boxBalance -= amount;
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        emit WithdrawSuccess(msg.sender, amount);
    }

    // Adds manager to manage the box (only owner)
    function addManager(address manager) external {
        require(msg.sender == owner, "Only owner can add manager");
        isManager[manager] = true;
    }

    // Deletes managers (only owner)
    function deleteManager(address manager) external {
        require(msg.sender == owner, "Only owner can delete manager");
        require(isManager[manager], "Not manager");
        isManager[manager] = false;
    }
}
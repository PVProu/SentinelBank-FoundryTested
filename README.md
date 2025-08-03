# 🏦 SentinelBank System with Fee Management

A modular and secure Solidity-based smart contract system for handling multi-user Ether deposits and withdrawals with configurable fees. Designed with best practices for security, access control, and extensibility.

---

## 📁 Structure

- `ImprovedCryptoBank.sol`: Main contract allowing deposits and withdrawals with per-user balance tracking.
- `bankFeesBox.sol`: Separate contract that securely collects withdrawal fees and allows authorized access to them.
- `IBankFeesBox.sol`: Interface used by `ImprovedCryptoBank` to interact with `bankFeesBox` in a decoupled and modular way.

---

## 🔐 Key Features

### ✅ ImprovedCryptoBank
- Multi-user Ether deposits.
- Withdrawals limited to user balance.
- Max per-user balance (modifiable by admin).
- Configurable withdrawal fee percentage.
- Fee is automatically redirected to an external fee vault (BankFeesBox).
- Emits deposit and withdrawal events for traceability.

### ✅ bankFeesBox
- Collects all withdrawal fees via `receiveFees()`.
- Tracks total accumulated fees (`boxBalance`).
- Only authorized managers can withdraw funds.
- Admin can add or remove managers.
- Transparent via events (`FeeDeposit`, `WithdrawSuccess`).

---

## 🔄 Workflow

1. **User deposits ETH** into `ImprovedCryptoBank`.
2. **User withdraws ETH**, paying a small configurable fee.
3. **Fee is automatically forwarded** to `bankFeesBox`.
4. **Authorized managers** can later withdraw the accumulated fees from `bankFeesBox`.

---

## 🔒 Roles and Access

- **Admin (ImprovedCryptoBank)**: Can modify max balance and fee percentage.
- **Owner (bankFeesBox)**: Can manage authorized fee withdrawers (add/remove).
- **Managers (bankFeesBox)**: Can withdraw ETH from the fee vault.

---

## ⚙️ Example Deployment

```solidity
ImprovedCryptoBank bank = new ImprovedCryptoBank(5 ether, msg.sender, address(feeBox));
bankFeesBox feeBox = new bankFeesBox(msg.sender);
```

Then authorize the `ImprovedCryptoBank` as fee sender:
```solidity
feeBox.addManager(address(bank));
```

---

## 🧪 Example Interaction

```solidity
// Deposit 2 ETH
bank.depositEther{value: 2 ether}();

// Withdraw 1 ETH (with 1% fee -> receives 0.99 ETH)
bank.withdrawEther(1 ether);

// Check fee vault balance
feeBox.boxBalance(); // Should reflect 0.01 ETH
```

---

## 🧪 Testing & Coverage

SentinelBank includes **comprehensive unit tests and fuzzing** using Foundry:

### ✅ Coverage Summary
- 💯 100% line/function/statement coverage
- ✅ Branch coverage ~98%, only corner branches are excluded
- 🧪 40+ detailed unit tests
- 🔍 Fuzzing coverage for:
  - Deposits within `maxBalance`
  - Withdrawals for exact deposited balance
  - Admin functions (fee and maxBalance adjustments)
  - Reverts for exceeding user balance

### 🧪 Highlights from `BankTest.t.sol`

```solidity
function testDepositEther() public {...}
function testCannotDepositMoreThanMaxBalance() public {...}
function testWithdrawEtherAndSendFee() public {...}
function testOnlyAdminCanModifyFee() public {...}
function testFeeCalculationAccuracy() public {...}

// Fuzzing tests
function testFuzzingDepositWithinLimit(uint256 amount_) public {...}
function testFuzzingWithdrawExactBalance(uint256 amount_) public {...}
function testFuzzingModifyFeeWithinRange(uint256 fee_) public {...}
function testFuzzingFailWithdrawMoreThanBalance(uint256 deposit_, uint256 withdraw_) public {...}
```

Run all tests with:
```bash
forge test
```

Generate coverage:
```bash
forge coverage --report lcov && genhtml -o coverage/ lcov.info && open coverage/index.html
```

> 📌 Requires [Foundry](https://book.getfoundry.sh/) and `lcov` + `genhtml` tools installed locally.

---

## 📜 Interfaces

### IBankFeesBox.sol

```solidity
interface IBankFeesBox {
    function receiveFees() external payable;
}
```

Used to loosely couple the fee management logic with the bank system.

---

## 🧠 Best Practices Applied

- CEI pattern (Checks-Effects-Interactions)
- `call` over `transfer` for forward compatibility
- Role-based access control via `onlyAdmin` and `onlyAuthorized`
- Externalized fee handling logic
- Modular and maintainable architecture
- Full unit test and fuzzing coverage

---

## 🧩 Potential Future Features

- `changeOwner()` in `bankFeesBox`
- Fee distribution between multiple vaults
- Frontend to visualize balances and events
- Multi-sig withdrawal from fee vault

---

## 🧾 License

This project is licensed under [LGPL-3.0-only](https://spdx.org/licenses/LGPL-3.0-only.html).


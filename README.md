# Flash Loan Collateral Strategy

A sophisticated DeFi protocol that enables flash loan arbitrage by using borrowed assets as collateral to borrow other assets atomically within a single transaction.

## Overview

This protocol allows users to:
1. Flash loan Asset A (e.g., WETH) from Aave V3
2. Deposit Asset A as collateral
3. Borrow Asset B (e.g., USDC) against that collateral
4. Transfer Asset B to an external contract for arbitrage execution
5. Receive Asset B back with profit
6. Repay everything atomically

**All of this happens in ONE transaction** - if any step fails, the entire transaction reverts.

## Key Features

- **Atomic Execution**: Everything happens in a single transaction or reverts
- **Flash Loan Integration**: Uses Aave V3 flash loans (0.05% fee)
- **Flexible Arbitrage**: Users implement their own arbitrage strategies
- **Safety First**: Multiple validation checks and ReentrancyGuard protection
- **Gas Optimized**: Efficient code with minimal storage operations
- **Well Tested**: Comprehensive test suite with >95% coverage

## Architecture

### Core Contracts

```
contracts/
├── FlashLoanCollateralStrategy.sol  # Main strategy contract
├── interfaces/
│   ├── IArbitrageExecutor.sol       # Interface for user arbitrage contracts
│   ├── IFlashLoanSimpleReceiver.sol # Aave V3 flash loan callback interface
│   └── ILendingProtocol.sol         # Aave V3 Pool interface
├── examples/
│   └── ExampleDEXArbitrage.sol      # Example arbitrage implementation
└── mocks/
    ├── MockERC20.sol                # Mock token for testing
    ├── MockAavePool.sol             # Mock Aave Pool for testing
    └── MockArbitrageExecutor.sol    # Mock arbitrage for testing
```

### Strategy Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User calls initiateStrategy()                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Flash loan WETH from Aave                                │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Deposit WETH as collateral in Aave                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Borrow USDC against WETH collateral                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Transfer USDC to arbitrage executor contract             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Arbitrage executor executes strategy (DEX trades, etc.)  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Arbitrage executor returns USDC + profit                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 8. Repay USDC borrow to Aave                                │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 9. Withdraw WETH collateral from Aave                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 10. Repay WETH flash loan + 0.05% fee                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ ✅ Transaction complete - Profit remains in strategy         │
└─────────────────────────────────────────────────────────────┘
```

## Installation

### Prerequisites

- Node.js v18+
- npm or yarn
- Git

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd Flash_defi
```

2. Install dependencies:
```bash
npm install
```

3. Copy environment variables:
```bash
cp .env.example .env
```

4. Edit `.env` with your configuration:
```bash
# Add your private key, RPC URLs, and API keys
nano .env
```

5. Compile contracts:
```bash
npm run compile
```

6. Run tests:
```bash
npm test
```

## Usage

### For Users: Implementing Your Arbitrage Strategy

#### Step 1: Create Your Arbitrage Executor

Create a contract implementing `IArbitrageExecutor`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IArbitrageExecutor.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyArbitrageStrategy is IArbitrageExecutor {
    function executeArbitrage(
        address token,
        uint256 amount,
        uint256 requiredReturn
    ) external override returns (bool) {
        // 1. Receive tokens from FlashLoanCollateralStrategy

        // 2. Execute your arbitrage logic here
        //    - DEX trades
        //    - Liquidations
        //    - Cross-protocol arbitrage
        //    - etc.

        // 3. Transfer requiredReturn amount back to msg.sender
        IERC20(token).transfer(msg.sender, requiredReturn);

        // 4. Keep any profit in this contract

        return true;
    }
}
```

See `contracts/examples/ExampleDEXArbitrage.sol` for a detailed example.

#### Step 2: Deploy Your Contracts

```bash
# Deploy the main strategy contract
npx hardhat run scripts/deploy.js --network mainnet

# Deploy your arbitrage executor
npx hardhat run scripts/deploy-your-arbitrage.js --network mainnet
```

#### Step 3: Execute Strategy

```javascript
const strategy = await ethers.getContractAt(
    "FlashLoanCollateralStrategy",
    STRATEGY_ADDRESS
);

// Calculate parameters
const flashLoanAmount = ethers.parseEther("10"); // 10 WETH
const borrowAmount = ethers.parseUnits("15000", 6); // 15,000 USDC
const yourArbitrageContract = "0x..."; // Your deployed arbitrage executor

// Execute strategy
const tx = await strategy.initiateStrategy(
    flashLoanAmount,
    borrowAmount,
    yourArbitrageContract
);

await tx.wait();
console.log("Strategy executed successfully!");
```

#### Step 4: Withdraw Profits

```javascript
const usdcBalance = await usdc.balanceOf(strategy.address);
await strategy.emergencyWithdraw(USDC_ADDRESS, usdcBalance);
```

## Configuration

### Network Addresses

The protocol is compatible with any network where Aave V3 is deployed:

**Ethereum Mainnet:**
- Aave Pool: `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2`
- WETH: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`
- USDC: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`

**Arbitrum:**
- Aave Pool: `0x794a61358D6845594F94dc1DB02A252b5b4814aD`
- WETH: `0x82aF49447D8a07e3bd95BD0d56f35241523fBab1`
- USDC: `0xaf88d065e77c8cC2239327C5EDb3A432268e5831`

**Polygon:**
- Aave Pool: `0x794a61358D6845594F94dc1DB02A252b5b4814aD`
- WETH: `0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619`
- USDC: `0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174`

### Parameter Calculation

**Calculate required collateral:**
```javascript
// To borrow $15,000 USDC with 80% LTV
// Need: $15,000 / 0.80 = $18,750 collateral
// At ETH = $2,000: 18,750 / 2,000 = 9.375 WETH

const borrowAmount = ethers.parseUnits("15000", 6);
const ltv = 8000; // 80% in basis points

const requiredCollateral = await strategy.calculateRequiredCollateral(
    borrowAmount,
    ltv
);
```

**Calculate flash loan fee:**
```javascript
const flashLoanAmount = ethers.parseEther("10");
const fee = await strategy.calculateFlashLoanFee(flashLoanAmount);
// Fee = 10 * 0.0005 = 0.005 WETH
```

## Testing

### Run All Tests

```bash
npm test
```

### Run Specific Test Suite

```bash
npx hardhat test --grep "Deployment and Configuration"
```

### Test with Gas Reporting

```bash
REPORT_GAS=true npm test
```

### Test on Mainnet Fork

```bash
# Edit hardhat.config.js to enable forking
# Set forking.enabled = true and forking.url to your RPC

npx hardhat test --network hardhat
```

## Security Considerations

### Access Control
- Only contract owner can initiate strategies
- Only Aave Pool can call `executeOperation` callback
- Emergency withdraw restricted to owner

### Reentrancy Protection
- All public functions use `nonReentrant` modifier
- Follows checks-effects-interactions pattern

### Validation Checks
- Target wallet must be a contract (not EOA)
- All amounts must be > 0
- All addresses must be non-zero
- Flash loan callback validates caller and initiator

### Known Risks

1. **Smart Contract Risk**: Bugs in the code could lead to loss of funds
2. **Flash Loan Fee Risk**: Aave can change flash loan fees
3. **Liquidation Risk**: Position could be liquidated if collateral value drops
4. **Arbitrage Risk**: Arbitrage may not be profitable after gas costs
5. **MEV Risk**: Transactions could be front-run in the mempool

### Recommended Mitigations
- Start with small amounts
- Use Flashbots or private RPC
- Monitor health factor closely
- Set conservative minimum profit requirements
- Get professional security audit before mainnet deployment

## Gas Costs

Typical gas consumption:
- Strategy execution: **800,000 - 1,500,000 gas**
- Varies based on arbitrage complexity

At 50 gwei gas price:
- Cost: 0.04 - 0.075 ETH (~$80-150 at $2000/ETH)

**Your arbitrage profit must exceed total costs:**
- Gas fees
- Flash loan fee (0.05%)
- DEX swap fees (0.3%+)
- Slippage

## API Reference

### Main Functions

#### `initiateStrategy(uint256 flashLoanAmount, uint256 borrowAmount, address targetWallet)`
Initiates the flash loan strategy.

**Parameters:**
- `flashLoanAmount`: Amount of flash loan asset to borrow (in Wei)
- `borrowAmount`: Amount of borrow asset to borrow against collateral
- `targetWallet`: Address of arbitrage executor contract

**Requirements:**
- Caller must be owner
- All amounts must be > 0
- Target wallet must be a contract

**Events:**
- `StrategyInitiated(uint256 flashLoanAmount, uint256 borrowAmount, address targetWallet, uint256 timestamp)`

#### `emergencyWithdraw(address token, uint256 amount)`
Withdraws tokens from the contract (owner only).

**Parameters:**
- `token`: Address of token to withdraw
- `amount`: Amount to withdraw

**Events:**
- `EmergencyWithdraw(address token, uint256 amount, uint256 timestamp)`

#### `updateMinProfit(uint256 newMinProfit)`
Updates minimum required profit threshold (owner only).

**Parameters:**
- `newMinProfit`: New minimum profit in borrow asset terms

**Events:**
- `MinProfitUpdated(uint256 oldValue, uint256 newValue)`

### View Functions

#### `calculateRequiredCollateral(uint256 borrowAmount, uint256 ltv) → uint256`
Calculates collateral needed for desired borrow amount.

#### `getHealthFactor() → uint256`
Returns current health factor of the contract's Aave position.

#### `getUserAccountData() → (uint256, uint256, uint256, uint256, uint256, uint256)`
Returns detailed account data from Aave.

#### `calculateFlashLoanFee(uint256 amount) → uint256`
Calculates flash loan fee for given amount.

## Examples

### Example 1: Simple DEX Arbitrage

```javascript
// Scenario: USDC is cheaper on Uniswap than Sushiswap

// 1. Flash loan 10 WETH
// 2. Deposit as collateral
// 3. Borrow 15,000 USDC
// 4. Send USDC to arbitrage contract
// 5. Arbitrage contract:
//    - Swaps USDC -> ETH on Uniswap (cheaper)
//    - Swaps ETH -> USDC on Sushiswap (expensive)
//    - Returns USDC + profit
// 6. Repay everything
// 7. Keep profit

const tx = await strategy.initiateStrategy(
    ethers.parseEther("10"),
    ethers.parseUnits("15000", 6),
    myArbitrageContract
);
```

### Example 2: Liquidation Arbitrage

```javascript
// Scenario: Underwater position available for liquidation

// 1. Flash loan 100 WETH
// 2. Deposit as collateral
// 3. Borrow 150,000 USDC
// 4. Arbitrage contract liquidates position
// 5. Receive collateral at discount
// 6. Sell collateral for profit
// 7. Return USDC
// 8. Keep profit

const tx = await strategy.initiateStrategy(
    ethers.parseEther("100"),
    ethers.parseUnits("150000", 6),
    liquidationArbitrageContract
);
```

## Troubleshooting

### Common Errors

**"TargetMustBeContract"**
- Target wallet address is an EOA, not a contract
- Deploy your arbitrage executor first

**"InsufficientReturn"**
- Arbitrage didn't return enough tokens
- Check your arbitrage logic
- Verify token approvals

**"ArbitrageExecutionFailed"**
- Arbitrage contract returned false
- Check arbitrage contract logs
- May not be profitable enough

**"UnauthorizedCallback"**
- Only Aave Pool can call executeOperation
- Check msg.sender validation

### Debug Tips

1. Test on mainnet fork first
2. Use console.log in Hardhat tests
3. Check event emissions
4. Monitor gas usage
5. Verify token approvals

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Write tests for new features
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own risk. The authors are not responsible for any losses incurred through the use of this software.

**This is experimental software. Do not use in production without:**
- Thorough testing
- Professional security audit
- Legal review
- Risk assessment

## Resources

- [Aave V3 Documentation](https://docs.aave.com/developers/getting-started/readme)
- [Hardhat Documentation](https://hardhat.org/docs)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Flash Loan Basics](https://docs.aave.com/developers/guides/flash-loans)

## Support

For questions and support:
- Open an issue on GitHub
- Review existing documentation
- Check test files for usage examples

---

**Built with ❤️ for the DeFi community**

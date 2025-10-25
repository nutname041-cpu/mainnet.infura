// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IFlashLoanSimpleReceiver.sol";
import "./interfaces/ILendingProtocol.sol";
import "./interfaces/IArbitrageExecutor.sol";

/**
 * @title FlashLoanCollateralStrategy
 * @notice Flash loan strategy that uses borrowed assets as collateral to borrow other assets for arbitrage
 * @dev Implements Aave V3 flash loan callback to execute multi-step DeFi strategy atomically
 *
 * Strategy flow:
 * 1. Flash loan Asset A (e.g., WETH)
 * 2. Deposit Asset A as collateral in Aave
 * 3. Borrow Asset B (e.g., USDC) against collateral
 * 4. Transfer Asset B to target wallet
 * 5. Execute arbitrage via callback to target wallet
 * 6. Receive Asset B back from target wallet
 * 7. Repay Asset B borrow to Aave
 * 8. Withdraw Asset A collateral
 * 9. Repay Asset A flash loan with fee
 */
contract FlashLoanCollateralStrategy is IFlashLoanSimpleReceiver, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    /// @notice Aave V3 Pool contract address
    address public immutable aavePool;

    /// @notice Asset to be flash loaned (collateral asset)
    address public immutable flashLoanAsset;

    /// @notice Asset to be borrowed against collateral
    address public immutable borrowAsset;

    /// @notice Minimum profit required for strategy execution
    uint256 public minProfitRequired;

    /// @notice Aave flash loan fee in basis points (5 = 0.05%)
    uint256 public constant FLASH_LOAN_FEE_BPS = 5;

    // ============ Custom Errors ============

    error FlashLoanFailed(string reason);
    error InsufficientReturn(uint256 expected, uint256 actual);
    error UnauthorizedCallback(address caller);
    error ArbitrageExecutionFailed(address wallet, string reason);
    error InsufficientCollateral(uint256 required, uint256 available);
    error InvalidAmount(string parameter);
    error InvalidAddress(string parameter);
    error TargetMustBeContract(address target);

    // ============ Events ============

    event StrategyInitiated(
        uint256 flashLoanAmount,
        uint256 borrowAmount,
        address indexed targetWallet,
        uint256 timestamp
    );

    event CollateralDeposited(
        address indexed asset,
        uint256 amount
    );

    event BorrowExecuted(
        address indexed asset,
        uint256 amount
    );

    event ArbitrageExecuted(
        address indexed wallet,
        uint256 amountSent,
        uint256 amountReturned
    );

    event StrategyCompleted(
        uint256 profit,
        uint256 timestamp
    );

    event EmergencyWithdraw(
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    event MinProfitUpdated(
        uint256 oldValue,
        uint256 newValue
    );

    // ============ Constructor ============

    /**
     * @notice Initialize the flash loan collateral strategy contract
     * @param _aavePool Address of Aave V3 Pool contract
     * @param _flashLoanAsset Address of asset to flash loan (collateral)
     * @param _borrowAsset Address of asset to borrow against collateral
     * @param _owner Address of contract owner
     */
    constructor(
        address _aavePool,
        address _flashLoanAsset,
        address _borrowAsset,
        address _owner
    ) Ownable(_owner) {
        if (_aavePool == address(0)) revert InvalidAddress("aavePool");
        if (_flashLoanAsset == address(0)) revert InvalidAddress("flashLoanAsset");
        if (_borrowAsset == address(0)) revert InvalidAddress("borrowAsset");
        if (_owner == address(0)) revert InvalidAddress("owner");

        aavePool = _aavePool;
        flashLoanAsset = _flashLoanAsset;
        borrowAsset = _borrowAsset;
        minProfitRequired = 0; // Can be set later by owner
    }

    // ============ Main Functions ============

    /**
     * @notice Initiate the flash loan collateral strategy
     * @dev Only callable by contract owner, triggers flash loan and entire strategy flow
     * @param flashLoanAmount Amount of flash loan asset to borrow
     * @param borrowAmount Amount of borrow asset to borrow against collateral
     * @param targetWallet Address of contract that will execute arbitrage (must be contract)
     */
    function initiateStrategy(
        uint256 flashLoanAmount,
        uint256 borrowAmount,
        address targetWallet
    ) external onlyOwner nonReentrant {
        // Validate inputs
        if (flashLoanAmount == 0) revert InvalidAmount("flashLoanAmount");
        if (borrowAmount == 0) revert InvalidAmount("borrowAmount");
        if (targetWallet == address(0)) revert InvalidAddress("targetWallet");

        // Validate target wallet is a contract, not EOA
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(targetWallet)
        }
        if (codeSize == 0) revert TargetMustBeContract(targetWallet);

        // Encode parameters for flash loan callback
        bytes memory params = abi.encode(borrowAmount, targetWallet);

        emit StrategyInitiated(flashLoanAmount, borrowAmount, targetWallet, block.timestamp);

        // Initiate flash loan from Aave V3 Pool
        ILendingProtocol(aavePool).flashLoanSimple(
            address(this),
            flashLoanAsset,
            flashLoanAmount,
            params,
            0 // referralCode
        );
    }

    /**
     * @notice Callback function called by Aave Pool after flash loan transfer
     * @dev Executes the entire strategy: deposit collateral, borrow, execute arbitrage, repay
     * @param asset Address of the flash loaned asset
     * @param amount Amount of flash loan received
     * @param premium Flash loan fee amount
     * @param initiator Address that initiated the flash loan
     * @param params Encoded parameters (borrowAmount, targetWallet)
     * @return success Boolean indicating successful execution
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        // ============ Step 1: Validation ============
        if (msg.sender != aavePool) revert UnauthorizedCallback(msg.sender);
        if (initiator != address(this)) revert UnauthorizedCallback(initiator);
        if (asset != flashLoanAsset) revert FlashLoanFailed("Invalid flash loan asset");

        // Decode parameters
        (uint256 borrowAmount, address targetWallet) = abi.decode(params, (uint256, address));

        // ============ Step 2: Deposit as Collateral ============
        IERC20(flashLoanAsset).safeIncreaseAllowance(aavePool, amount);

        ILendingProtocol(aavePool).supply(
            flashLoanAsset,
            amount,
            address(this),
            0 // referralCode
        );

        // Enable the asset as collateral
        ILendingProtocol(aavePool).setUserUseReserveAsCollateral(flashLoanAsset, true);

        emit CollateralDeposited(flashLoanAsset, amount);

        // ============ Step 3: Borrow Against Collateral ============
        ILendingProtocol(aavePool).borrow(
            borrowAsset,
            borrowAmount,
            2, // Variable interest rate mode
            0, // referralCode
            address(this)
        );

        emit BorrowExecuted(borrowAsset, borrowAmount);

        // ============ Step 4: Transfer to Target Wallet ============
        uint256 balanceBefore = IERC20(borrowAsset).balanceOf(address(this));

        IERC20(borrowAsset).safeTransfer(targetWallet, borrowAmount);

        // ============ Step 5: Execute Arbitrage Callback ============
        // Calculate required return amount (borrowAmount + 2% buffer for slippage)
        uint256 requiredReturnAmount = borrowAmount + (borrowAmount * 2) / 100;

        bool arbitrageSuccess = IArbitrageExecutor(targetWallet).executeArbitrage(
            borrowAsset,
            borrowAmount,
            requiredReturnAmount
        );

        if (!arbitrageSuccess) {
            revert ArbitrageExecutionFailed(targetWallet, "Arbitrage execution returned false");
        }

        // ============ Step 6: Verify Return ============
        uint256 balanceAfter = IERC20(borrowAsset).balanceOf(address(this));
        uint256 returnedAmount = balanceAfter - balanceBefore + borrowAmount;

        if (balanceAfter < borrowAmount) {
            revert InsufficientReturn(borrowAmount, balanceAfter);
        }

        emit ArbitrageExecuted(targetWallet, borrowAmount, returnedAmount);

        // ============ Step 7: Repay Borrow ============
        IERC20(borrowAsset).safeIncreaseAllowance(aavePool, type(uint256).max);

        ILendingProtocol(aavePool).repay(
            borrowAsset,
            type(uint256).max, // Repay all debt including any interest
            2, // Variable interest rate mode
            address(this)
        );

        // ============ Step 8: Withdraw Collateral ============
        ILendingProtocol(aavePool).withdraw(
            flashLoanAsset,
            amount, // Withdraw the full collateral amount
            address(this)
        );

        // ============ Step 9: Approve Flash Loan Repayment ============
        uint256 amountOwed = amount + premium;
        IERC20(flashLoanAsset).safeIncreaseAllowance(aavePool, amountOwed);

        // Calculate and emit profit
        uint256 finalBorrowBalance = IERC20(borrowAsset).balanceOf(address(this));
        emit StrategyCompleted(finalBorrowBalance, block.timestamp);

        return true;
    }

    // ============ Admin Functions ============

    /**
     * @notice Emergency withdraw function to recover stuck tokens
     * @dev Only callable by owner when no active strategy is running
     * @param token Address of token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) revert InvalidAddress("token");
        if (amount == 0) revert InvalidAmount("amount");

        IERC20(token).safeTransfer(owner(), amount);

        emit EmergencyWithdraw(token, amount, block.timestamp);
    }

    /**
     * @notice Update minimum required profit threshold
     * @dev Only callable by owner
     * @param newMinProfit New minimum profit value in borrowAsset terms
     */
    function updateMinProfit(uint256 newMinProfit) external onlyOwner {
        uint256 oldValue = minProfitRequired;
        minProfitRequired = newMinProfit;

        emit MinProfitUpdated(oldValue, newMinProfit);
    }

    // ============ View Functions ============

    /**
     * @notice Calculate required collateral for a desired borrow amount
     * @param borrowAmount Amount desired to borrow
     * @param ltv Loan-to-value ratio in basis points (e.g., 8000 = 80%)
     * @return requiredCollateral Amount of collateral needed
     */
    function calculateRequiredCollateral(
        uint256 borrowAmount,
        uint256 ltv
    ) public pure returns (uint256 requiredCollateral) {
        if (ltv == 0) return 0;
        return (borrowAmount * 10000) / ltv;
    }

    /**
     * @notice Get current health factor of this contract's Aave position
     * @return healthFactor Current health factor (scaled by 1e18)
     */
    function getHealthFactor() public view returns (uint256 healthFactor) {
        (
            ,
            ,
            ,
            ,
            ,
            uint256 currentHealthFactor
        ) = ILendingProtocol(aavePool).getUserAccountData(address(this));

        return currentHealthFactor;
    }

    /**
     * @notice Get user account data from Aave
     * @return totalCollateralBase Total collateral in base currency
     * @return totalDebtBase Total debt in base currency
     * @return availableBorrowsBase Available borrow capacity in base currency
     * @return currentLiquidationThreshold Current liquidation threshold
     * @return ltv Loan to value ratio
     * @return healthFactor Health factor
     */
    function getUserAccountData()
        public
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return ILendingProtocol(aavePool).getUserAccountData(address(this));
    }

    /**
     * @notice Calculate flash loan fee for a given amount
     * @param amount Flash loan amount
     * @return fee Flash loan fee amount
     */
    function calculateFlashLoanFee(uint256 amount) public pure returns (uint256 fee) {
        return (amount * FLASH_LOAN_FEE_BPS) / 10000;
    }
}

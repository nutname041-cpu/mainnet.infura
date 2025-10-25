// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IFlashLoanSimpleReceiver.sol";

/**
 * @title MockAavePool
 * @notice Mock Aave V3 Pool contract for testing flash loan functionality
 * @dev Simplified implementation that simulates Aave behavior
 */
contract MockAavePool {
    using SafeERC20 for IERC20;

    // Flash loan fee: 0.05% = 5 basis points
    uint256 public constant FLASH_LOAN_FEE_BPS = 5;

    // Track user collateral and debt
    mapping(address => mapping(address => uint256)) public userCollateral;
    mapping(address => mapping(address => uint256)) public userDebt;
    mapping(address => mapping(address => bool)) public userCollateralEnabled;

    // Events
    event Supply(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event FlashLoan(address indexed receiver, address indexed asset, uint256 amount, uint256 premium);

    /**
     * @notice Execute a flash loan
     */
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 /*referralCode*/
    ) external {
        uint256 premium = (amount * FLASH_LOAN_FEE_BPS) / 10000;

        // Transfer flash loaned amount to receiver
        IERC20(asset).safeTransfer(receiverAddress, amount);

        emit FlashLoan(receiverAddress, asset, amount, premium);

        // Call receiver's callback
        bool success = IFlashLoanSimpleReceiver(receiverAddress).executeOperation(
            asset,
            amount,
            premium,
            msg.sender,
            params
        );

        require(success, "Flash loan callback failed");

        // Take back the loan + premium
        IERC20(asset).safeTransferFrom(receiverAddress, address(this), amount + premium);
    }

    /**
     * @notice Supply (deposit) assets as collateral
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 /*referralCode*/
    ) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        userCollateral[onBehalfOf][asset] += amount;

        emit Supply(onBehalfOf, asset, amount);
    }

    /**
     * @notice Enable or disable an asset as collateral
     */
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external {
        userCollateralEnabled[msg.sender][asset] = useAsCollateral;
    }

    /**
     * @notice Borrow assets against collateral
     */
    function borrow(
        address asset,
        uint256 amount,
        uint256 /*interestRateMode*/,
        uint16 /*referralCode*/,
        address onBehalfOf
    ) external {
        userDebt[onBehalfOf][asset] += amount;
        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Borrow(onBehalfOf, asset, amount);
    }

    /**
     * @notice Repay borrowed assets
     */
    function repay(
        address asset,
        uint256 amount,
        uint256 /*interestRateMode*/,
        address onBehalfOf
    ) external returns (uint256) {
        uint256 currentDebt = userDebt[onBehalfOf][asset];
        uint256 amountToRepay = amount;

        if (amount == type(uint256).max) {
            amountToRepay = currentDebt;
        }

        if (amountToRepay > currentDebt) {
            amountToRepay = currentDebt;
        }

        userDebt[onBehalfOf][asset] -= amountToRepay;
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amountToRepay);

        emit Repay(onBehalfOf, asset, amountToRepay);

        return amountToRepay;
    }

    /**
     * @notice Withdraw supplied collateral
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        uint256 userBalance = userCollateral[msg.sender][asset];
        uint256 amountToWithdraw = amount;

        if (amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }

        require(amountToWithdraw <= userBalance, "Insufficient collateral");

        userCollateral[msg.sender][asset] -= amountToWithdraw;
        IERC20(asset).safeTransfer(to, amountToWithdraw);

        emit Withdraw(msg.sender, asset, amountToWithdraw);

        return amountToWithdraw;
    }

    /**
     * @notice Get user account data
     */
    function getUserAccountData(address user)
        external
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
        // Simplified mock - return reasonable values
        totalCollateralBase = 20000e8; // $20,000
        totalDebtBase = 15000e8; // $15,000
        availableBorrowsBase = 1000e8; // $1,000 available
        currentLiquidationThreshold = 8500; // 85%
        ltv = 8000; // 80%

        // Calculate health factor: (collateral * liquidationThreshold) / debt
        if (totalDebtBase > 0) {
            healthFactor = (totalCollateralBase * currentLiquidationThreshold) / totalDebtBase / 100;
        } else {
            healthFactor = type(uint256).max;
        }

        return (
            totalCollateralBase,
            totalDebtBase,
            availableBorrowsBase,
            currentLiquidationThreshold,
            ltv,
            healthFactor
        );
    }

    /**
     * @notice Fund the pool with tokens for testing
     */
    function fundPool(address asset, uint256 amount) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    }
}

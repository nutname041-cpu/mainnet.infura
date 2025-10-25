// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ILendingProtocol
 * @notice Interface for Aave V3 Pool contract
 * @dev Abstraction of Aave V3 lending protocol functions used in the flash loan strategy
 */
interface ILendingProtocol {
    /**
     * @notice Executes a flash loan with a single asset
     * @param receiverAddress Address of the contract receiving the flash loan
     * @param asset Address of the asset being flash loaned
     * @param amount Amount of the asset to flash loan
     * @param params Arbitrary bytes-encoded parameters to pass to the receiver
     * @param referralCode Referral code for potential fee sharing (use 0 if none)
     */
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;

    /**
     * @notice Supplies an amount of underlying asset into the reserve
     * @param asset Address of the underlying asset to supply
     * @param amount Amount to be supplied
     * @param onBehalfOf Address that will receive the aTokens
     * @param referralCode Referral code for potential fee sharing (use 0 if none)
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    /**
     * @notice Borrows an amount of underlying asset
     * @param asset Address of the underlying asset to borrow
     * @param amount Amount to be borrowed
     * @param interestRateMode Interest rate mode (1 = stable, 2 = variable)
     * @param referralCode Referral code for potential fee sharing (use 0 if none)
     * @param onBehalfOf Address that will incur the debt
     */
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    /**
     * @notice Repays a borrowed amount
     * @param asset Address of the underlying asset to repay
     * @param amount Amount to repay (use type(uint256).max to repay all)
     * @param interestRateMode Interest rate mode (1 = stable, 2 = variable)
     * @param onBehalfOf Address whose debt will be repaid
     * @return amountRepaid The actual amount repaid
     */
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256 amountRepaid);

    /**
     * @notice Withdraws an amount of underlying asset from the reserve
     * @param asset Address of the underlying asset to withdraw
     * @param amount Amount to withdraw (use type(uint256).max to withdraw all)
     * @param to Address that will receive the underlying asset
     * @return amountWithdrawn The actual amount withdrawn
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256 amountWithdrawn);

    /**
     * @notice Sets whether a reserve should be used as collateral
     * @param asset Address of the underlying asset
     * @param useAsCollateral True to use as collateral, false otherwise
     */
    function setUserUseReserveAsCollateral(
        address asset,
        bool useAsCollateral
    ) external;

    /**
     * @notice Returns the user account data across all reserves
     * @param user Address of the user
     * @return totalCollateralBase Total collateral in base currency
     * @return totalDebtBase Total debt in base currency
     * @return availableBorrowsBase Available borrow capacity in base currency
     * @return currentLiquidationThreshold Current liquidation threshold
     * @return ltv Loan to value ratio
     * @return healthFactor Health factor (below 1.0 means liquidatable)
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
        );
}

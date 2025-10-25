// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IArbitrageExecutor
 * @notice Interface that target wallet contracts must implement to execute arbitrage strategies
 * @dev This contract will be called by FlashLoanCollateralStrategy with borrowed assets
 */
interface IArbitrageExecutor {
    /**
     * @notice Execute arbitrage strategy with provided tokens
     * @dev This function will be called by the FlashLoanCollateralStrategy contract
     * @dev The implementing contract must:
     *      1. Receive the specified amount of token
     *      2. Execute arbitrage strategy (DEX trades, etc.)
     *      3. Transfer at least requiredReturn back to msg.sender (the strategy contract)
     *      4. Return true if successful
     * @param token Address of the asset to use for arbitrage
     * @param amount Amount of asset available for arbitrage
     * @param requiredReturn Minimum amount that must be returned to the strategy contract
     * @return success Boolean indicating whether the arbitrage was successful
     */
    function executeArbitrage(
        address token,
        uint256 amount,
        uint256 requiredReturn
    ) external returns (bool success);
}

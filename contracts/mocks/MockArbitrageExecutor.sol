// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IArbitrageExecutor.sol";

/**
 * @title MockArbitrageExecutor
 * @notice Mock arbitrage executor for testing the flash loan strategy
 * @dev Simulates arbitrage by simply returning the required amount (plus optional profit)
 */
contract MockArbitrageExecutor is IArbitrageExecutor {
    using SafeERC20 for IERC20;

    bool public shouldSucceed = true;
    bool public shouldReturnEnough = true;
    uint256 public profitAmount = 0;

    event ArbitrageExecuted(address token, uint256 amount, uint256 returned);

    /**
     * @notice Execute mock arbitrage strategy
     * @dev Simulates arbitrage by returning tokens with optional profit
     */
    function executeArbitrage(
        address token,
        uint256 amount,
        uint256 requiredReturn
    ) external override returns (bool) {
        if (!shouldSucceed) {
            return false;
        }

        // Simulate arbitrage "work" - in real scenario, this would be DEX trades, etc.
        // For testing, we just prepare the return amount

        uint256 returnAmount;
        if (shouldReturnEnough) {
            returnAmount = requiredReturn + profitAmount;
        } else {
            returnAmount = requiredReturn / 2; // Return insufficient amount
        }

        // Transfer tokens back to the strategy contract
        IERC20(token).safeTransfer(msg.sender, returnAmount);

        emit ArbitrageExecuted(token, amount, returnAmount);

        return true;
    }

    /**
     * @notice Set whether the arbitrage should succeed
     */
    function setShouldSucceed(bool _shouldSucceed) external {
        shouldSucceed = _shouldSucceed;
    }

    /**
     * @notice Set whether the arbitrage should return enough tokens
     */
    function setShouldReturnEnough(bool _shouldReturnEnough) external {
        shouldReturnEnough = _shouldReturnEnough;
    }

    /**
     * @notice Set the profit amount to return
     */
    function setProfitAmount(uint256 _profitAmount) external {
        profitAmount = _profitAmount;
    }

    /**
     * @notice Receive tokens (for testing)
     */
    receive() external payable {}
}

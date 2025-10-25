// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IFlashLoanSimpleReceiver
 * @notice Interface for Aave V3 flash loan callback receiver
 * @dev Contracts implementing this interface can receive flash loans from Aave V3 Pool
 */
interface IFlashLoanSimpleReceiver {
    /**
     * @notice Executes an operation after receiving the flash loan
     * @dev This function is called by the Aave Pool contract after transferring the flash loaned amount
     * @param asset The address of the flash loaned asset
     * @param amount The amount of the flash loan
     * @param premium The fee for the flash loan
     * @param initiator The address that initiated the flash loan
     * @param params Arbitrary bytes-encoded parameters passed from the initiator
     * @return success Boolean indicating whether the operation was successful
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool success);
}

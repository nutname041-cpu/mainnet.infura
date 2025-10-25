const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * Main deployment script for FlashLoanCollateralStrategy contract
 * Deploys to configured network and saves deployment information
 */
async function main() {
    console.log("=".repeat(60));
    console.log("Flash Loan Collateral Strategy - Deployment Script");
    console.log("=".repeat(60));

    // Get network information
    const network = await hre.ethers.provider.getNetwork();
    const networkName = hre.network.name;
    const chainId = network.chainId;

    console.log(`\nNetwork: ${networkName}`);
    console.log(`Chain ID: ${chainId}`);

    // Get deployer information
    const [deployer] = await hre.ethers.getSigners();
    const deployerAddress = await deployer.getAddress();
    const deployerBalance = await hre.ethers.provider.getBalance(deployerAddress);

    console.log(`\nDeployer: ${deployerAddress}`);
    console.log(`Balance: ${hre.ethers.formatEther(deployerBalance)} ETH`);

    // Load network-specific contract addresses
    let aavePoolAddress, flashLoanAsset, borrowAsset;

    if (networkName === "mainnet" || chainId === 1n) {
        aavePoolAddress = process.env.AAVE_POOL_ADDRESS_MAINNET || "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2";
        flashLoanAsset = process.env.WETH_ADDRESS || "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
        borrowAsset = process.env.USDC_ADDRESS || "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    } else if (networkName === "arbitrum" || chainId === 42161n) {
        aavePoolAddress = process.env.AAVE_POOL_ADDRESS_ARBITRUM || "0x794a61358D6845594F94dc1DB02A252b5b4814aD";
        flashLoanAsset = process.env.WETH_ADDRESS || "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
        borrowAsset = process.env.USDC_ADDRESS || "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";
    } else if (networkName === "polygon" || chainId === 137n) {
        aavePoolAddress = process.env.AAVE_POOL_ADDRESS_POLYGON || "0x794a61358D6845594F94dc1DB02A252b5b4814aD";
        flashLoanAsset = process.env.WETH_ADDRESS || "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
        borrowAsset = process.env.USDC_ADDRESS || "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
    } else {
        // Localhost or testnet - use environment variables
        aavePoolAddress = process.env.AAVE_POOL_ADDRESS || "0x0000000000000000000000000000000000000000";
        flashLoanAsset = process.env.FLASH_LOAN_ASSET || "0x0000000000000000000000000000000000000000";
        borrowAsset = process.env.BORROW_ASSET || "0x0000000000000000000000000000000000000000";

        if (aavePoolAddress === "0x0000000000000000000000000000000000000000") {
            console.warn("\n⚠️  WARNING: Using zero addresses for deployment on local network");
            console.warn("Set AAVE_POOL_ADDRESS, FLASH_LOAN_ASSET, and BORROW_ASSET in .env file");
        }
    }

    console.log("\n" + "=".repeat(60));
    console.log("Deployment Configuration");
    console.log("=".repeat(60));
    console.log(`Aave Pool: ${aavePoolAddress}`);
    console.log(`Flash Loan Asset (Collateral): ${flashLoanAsset}`);
    console.log(`Borrow Asset: ${borrowAsset}`);
    console.log(`Owner: ${deployerAddress}`);

    // Deploy contract
    console.log("\n" + "=".repeat(60));
    console.log("Deploying FlashLoanCollateralStrategy...");
    console.log("=".repeat(60));

    const FlashLoanCollateralStrategy = await hre.ethers.getContractFactory("FlashLoanCollateralStrategy");
    const strategy = await FlashLoanCollateralStrategy.deploy(
        aavePoolAddress,
        flashLoanAsset,
        borrowAsset,
        deployerAddress
    );

    await strategy.waitForDeployment();

    const strategyAddress = await strategy.getAddress();
    const deploymentTx = strategy.deploymentTransaction();
    const deploymentReceipt = await deploymentTx.wait(2); // Wait for 2 confirmations

    console.log(`\n✅ Contract deployed to: ${strategyAddress}`);
    console.log(`Transaction hash: ${deploymentTx.hash}`);
    console.log(`Block number: ${deploymentReceipt.blockNumber}`);
    console.log(`Gas used: ${deploymentReceipt.gasUsed.toString()}`);

    // Verify contract on block explorer (skip for localhost)
    if (networkName !== "localhost" && networkName !== "hardhat") {
        console.log("\n" + "=".repeat(60));
        console.log("Verifying contract on block explorer...");
        console.log("=".repeat(60));

        try {
            await hre.run("verify:verify", {
                address: strategyAddress,
                constructorArguments: [
                    aavePoolAddress,
                    flashLoanAsset,
                    borrowAsset,
                    deployerAddress
                ]
            });
            console.log("✅ Contract verified successfully");
        } catch (error) {
            console.log("⚠️  Verification failed:", error.message);
            console.log("You can verify manually later with:");
            console.log(`npx hardhat verify --network ${networkName} ${strategyAddress} ${aavePoolAddress} ${flashLoanAsset} ${borrowAsset} ${deployerAddress}`);
        }
    }

    // Save deployment information
    const deploymentInfo = {
        network: networkName,
        chainId: chainId.toString(),
        timestamp: new Date().toISOString(),
        contracts: {
            FlashLoanCollateralStrategy: {
                address: strategyAddress,
                deployer: deployerAddress,
                txHash: deploymentTx.hash,
                blockNumber: deploymentReceipt.blockNumber,
                gasUsed: deploymentReceipt.gasUsed.toString(),
                constructor: {
                    aavePool: aavePoolAddress,
                    flashLoanAsset: flashLoanAsset,
                    borrowAsset: borrowAsset,
                    owner: deployerAddress
                }
            }
        }
    };

    const deploymentsDir = path.join(__dirname, "..", "deployments");
    if (!fs.existsSync(deploymentsDir)) {
        fs.mkdirSync(deploymentsDir);
    }

    const deploymentFile = path.join(deploymentsDir, `${networkName}_${chainId}.json`);
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));

    console.log("\n" + "=".repeat(60));
    console.log("Deployment Summary");
    console.log("=".repeat(60));
    console.log(`Contract Address: ${strategyAddress}`);
    console.log(`Network: ${networkName} (Chain ID: ${chainId})`);
    console.log(`Deployment info saved to: ${deploymentFile}`);
    console.log("\n" + "=".repeat(60));
    console.log("Next Steps:");
    console.log("=".repeat(60));
    console.log("1. Deploy your arbitrage executor contract");
    console.log("2. Test the strategy with small amounts first");
    console.log("3. Call initiateStrategy() with your parameters");
    console.log("4. Monitor events for execution status");
    console.log("=".repeat(60));
}

// Execute deployment
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Deployment failed:");
        console.error(error);
        process.exit(1);
    });

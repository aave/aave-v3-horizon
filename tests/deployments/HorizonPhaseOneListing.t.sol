// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {DataTypes} from '../../src/contracts/protocol/libraries/types/DataTypes.sol';
import {MarketReport, ContractsReport} from '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {Default} from '../../scripts/DeployAaveV3MarketBatched.sol';
import {MarketReportUtils} from '../../src/deployments/contracts/utilities/MarketReportUtils.sol';
import {ConfigureHorizonPhaseOne} from '../../scripts/misc/ConfigureHorizonPhaseOne.sol';
import {ReserveConfiguration} from '../../src/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';

contract HorizonPhaseOneListingTest is Test {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    address internal deployer = 0xA22f39d5fEb10489F7FA84C2C545BAc4EA48eBB7;

    address internal GHO_ADDRESS;
    address internal USDC_ADDRESS;
    address internal RLUSD_ADDRESS;
    address internal USTB_ADDRESS;
    address internal USCC_ADDRESS;
    address internal USYC_ADDRESS;

    MarketReport internal marketReport;
    ContractsReport internal contracts;

    function setUp() public {
        Default defaultContract = new Default();

        vm.startPrank(deployer);
        string memory reportFilePath = defaultContract.run();
        vm.stopPrank();

        marketReport = abi.decode(vm.parseJson(reportFilePath), (MarketReport));
        contracts = MarketReportUtils.toContractsReport(marketReport);

        ConfigureHorizonPhaseOne configureHorizonPhaseOne = new ConfigureHorizonPhaseOne();

        vm.startPrank(deployer);
        configureHorizonPhaseOne.run(reportFilePath);
        vm.stopPrank();

        GHO_ADDRESS = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
        USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        RLUSD_ADDRESS = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
        USTB_ADDRESS = 0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e;
        USCC_ADDRESS = 0x14d60E7FDC0D71d8611742720E4C50E7a974020c;
        USYC_ADDRESS = 0x136471a34f6ef19fE571EFFC1CA711fdb8E49f2b;
    }

    function test_listing() public {
        assertEq(contracts.poolProxy.getConfiguration(GHO_ADDRESS).getSupplyCap(), 5_000_000);
        assertEq(contracts.poolProxy.getConfiguration(USDC_ADDRESS).getSupplyCap(), 5_000_000);
        assertEq(contracts.poolProxy.getConfiguration(RLUSD_ADDRESS).getSupplyCap(), 5_000_000);
        assertEq(contracts.poolProxy.getConfiguration(USTB_ADDRESS).getSupplyCap(), 3_000_000);
        assertEq(contracts.poolProxy.getConfiguration(USCC_ADDRESS).getSupplyCap(), 3_000_000);
        assertEq(contracts.poolProxy.getConfiguration(USYC_ADDRESS).getSupplyCap(), 3_000_000);

        assertEq(contracts.poolProxy.getConfiguration(GHO_ADDRESS).getBorrowCap(), 4_000_000);
        assertEq(contracts.poolProxy.getConfiguration(USDC_ADDRESS).getBorrowCap(), 4_000_000);
        assertEq(contracts.poolProxy.getConfiguration(RLUSD_ADDRESS).getBorrowCap(), 4_000_000);
        assertEq(contracts.poolProxy.getConfiguration(USTB_ADDRESS).getBorrowCap(), 0);
        assertEq(contracts.poolProxy.getConfiguration(USCC_ADDRESS).getBorrowCap(), 0);
        assertEq(contracts.poolProxy.getConfiguration(USYC_ADDRESS).getBorrowCap(), 0);
    }
}
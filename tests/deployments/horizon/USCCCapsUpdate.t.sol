// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2 as console} from 'forge-std/console2.sol';
import {HorizonPhaseOneUpdateTest, IDefaultInterestRateStrategyV2, ReserveConfiguration, DataTypes} from '../HorizonPhaseOneUpdate.t.sol';
import {DeployUSCCCapsUpdatePayload} from '../../../scripts/horizon/DeployUSCCCapsUpdatePayload.sol';

/// forge-config: default.evm_version = "cancun"
contract USCCCapsUpdateTest is HorizonPhaseOneUpdateTest {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  function test_listing(address token, TokenListingParams memory params) internal virtual override {
    test_getConfiguration(token, params);
    test_interestRateStrategy(token, params);
    test_variableDebtToken(token, params);
    test_priceFeed(token, params);
  }

  function test_eMode(
    uint8 eModeCategory,
    EModeCategoryParams memory params
  ) internal virtual override {
    test_eMode_configuration(eModeCategory, params);
  }

  function test_getConfiguration(
    address token,
    TokenListingParams memory params
  ) internal view virtual override {
    DataTypes.ReserveConfigurationMap memory config = pool.getConfiguration(token);
    assertEq(config.getSupplyCap(), params.supplyCap, 'supplyCap');
    assertEq(config.getBorrowCap(), params.borrowCap, 'borrowCap');
    assertEq(config.getIsVirtualAccActive(), true, 'isVirtualAccActive');
    assertEq(config.getBorrowingEnabled(), params.enabledToBorrow, 'borrowingEnabled');
    assertEq(
      config.getBorrowableInIsolation(),
      params.borrowableInIsolation,
      'borrowableInIsolation'
    );
    assertEq(config.getSiloedBorrowing(), params.withSiloedBorrowing, 'siloedBorrowing');
    assertEq(config.getFlashLoanEnabled(), params.flashloanable, 'flashloanable');
    assertEq(config.getReserveFactor(), params.reserveFactor, 'reserveFactor');
    assertEq(config.getLtv(), params.ltv, 'ltv');
    assertEq(config.getLiquidationThreshold(), params.liquidationThreshold, 'liquidationThreshold');
    assertEq(config.getLiquidationBonus(), params.liquidationBonus, 'liquidationBonus');
    assertEq(config.getDebtCeiling(), params.debtCeiling, 'debtCeiling');
    assertEq(config.getLiquidationProtocolFee(), params.liqProtocolFee, 'liqProtocolFee');
    assertEq(config.getPaused(), false, 'unpaused');
  }

  function loadDeployment() internal virtual override returns (DeploymentInfo memory) {
    address usccCapsUpdate = new DeployUSCCCapsUpdatePayload().run();
    vm.prank(EMERGENCY_MULTISIG);
    (bool success, ) = LISTING_EXECUTOR_ADDRESS.call(
      abi.encodeWithSignature(
        'executeTransaction(address,uint256,string,bytes,bool)',
        address(usccCapsUpdate), // target
        0, // value
        'execute()', // signature
        '', // data
        true // withDelegatecall
      )
    );
    require(success, 'Failed to execute transaction');

    return deploymentInfo;
  }

  function loadUpdatedParams() internal virtual override {
    super.loadUpdatedParams();
    USCC_TOKEN_LISTING_PARAMS.supplyCap = 1_920_000;
  }
}

/// forge-config: default.evm_version = "cancun"
contract USCCCapsUpdatePostDeploymentForkTest is USCCCapsUpdateTest {
  function loadDeployment() internal override returns (DeploymentInfo memory) {
    address usccCapsUpdate = 0x008C5bA747286d6f7801A80EE2394AD2d5F9CfD3;
    vm.prank(EMERGENCY_MULTISIG);
    (bool success, ) = LISTING_EXECUTOR_ADDRESS.call(
      abi.encodeWithSignature(
        'executeTransaction(address,uint256,string,bytes,bool)',
        address(usccCapsUpdate), // target
        0, // value
        'execute()', // signature
        '', // data
        true // withDelegatecall
      )
    );
    require(success, 'Failed to execute transaction');

    return deploymentInfo;
  }
}

/// forge-config: default.evm_version = "cancun"
contract USCCCapsUpdatePostExecutionForkTest is USCCCapsUpdateTest {
  function setUp() public override {
    vm.skip(true, 'post-payload execution');
    super.setUp();
  }

  function loadDeployment() internal view override returns (DeploymentInfo memory) {
    return deploymentInfo;
  }
}

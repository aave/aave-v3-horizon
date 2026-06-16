// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2 as console} from 'forge-std/console2.sol';
import {Test, Vm} from 'forge-std/Test.sol';
import {AaveV3EthereumHorizonCustom} from './utils/AaveV3EthereumHorizonCustom.sol';
import {IRwaOracleParameterRegistry} from './dependencies/IRwaOracleParameterRegistry.sol';

abstract contract ParameterRegistryUpdateBaseTest is Test {
  struct ParamRegistryFields {
    uint64 maxExpectedApy;
    uint32 upperBoundTolerance;
    uint32 lowerBoundTolerance;
    uint32 maxDiscount;
    uint80 lookbackWindowSize;
    bool isUpperBoundEnabled;
    bool isLowerBoundEnabled;
    bool isActionTakingEnabled;
  }
  IRwaOracleParameterRegistry public parameterRegistry;
  mapping(address => ParamRegistryFields) public expectedParams;

  function setUp() public virtual {
    parameterRegistry = IRwaOracleParameterRegistry(
      AaveV3EthereumHorizonCustom.RWA_ORACLE_PARAMS_REGISTRY
    );
    _loadExpectedParams();
  }

  function test_parameterRegistryUpdate_USTB() public view {
    _assertParameters(
      AaveV3EthereumHorizonCustom.USTB_UNDERLYING,
      expectedParams[AaveV3EthereumHorizonCustom.USTB_UNDERLYING]
    );
  }

  function test_parameterRegistryUpdate_USCC() public view {
    _assertParameters(
      AaveV3EthereumHorizonCustom.USCC_UNDERLYING,
      expectedParams[AaveV3EthereumHorizonCustom.USCC_UNDERLYING]
    );
  }

  function test_parameterRegistryUpdate_USYC() public view {
    _assertParameters(
      AaveV3EthereumHorizonCustom.USYC_UNDERLYING,
      expectedParams[AaveV3EthereumHorizonCustom.USYC_UNDERLYING]
    );
  }

  function test_parameterRegistryUpdate_JAAA() public view {
    _assertParameters(
      AaveV3EthereumHorizonCustom.JAAA_UNDERLYING,
      expectedParams[AaveV3EthereumHorizonCustom.JAAA_UNDERLYING]
    );
  }

  function test_parameterRegistryUpdate_JTRSY() public view {
    _assertParameters(
      AaveV3EthereumHorizonCustom.JTRSY_UNDERLYING,
      expectedParams[AaveV3EthereumHorizonCustom.JTRSY_UNDERLYING]
    );
  }

  function test_parameterRegistryUpdate_VBILL() public view {
    _assertParameters(
      AaveV3EthereumHorizonCustom.VBILL_UNDERLYING,
      expectedParams[AaveV3EthereumHorizonCustom.VBILL_UNDERLYING]
    );
  }

  function _loadExpectedParams() internal virtual {}

  function _assertParameters(address asset, ParamRegistryFields memory expectedParam) public view {
    (
      uint64 maxExpectedApy,
      uint32 upperBoundTolerance,
      uint32 lowerBoundTolerance,
      uint32 maxDiscount,
      uint80 lookbackWindowSize,
      bool isUpperBoundEnabled,
      bool isLowerBoundEnabled,
      bool isActionTakingEnabled
    ) = parameterRegistry.getParametersForAsset(asset);

    assertEq(maxExpectedApy, expectedParam.maxExpectedApy, 'maxExpectedApy');
    assertEq(upperBoundTolerance, expectedParam.upperBoundTolerance, 'upperBoundTolerance');
    assertEq(lowerBoundTolerance, expectedParam.lowerBoundTolerance, 'lowerBoundTolerance');
    assertEq(maxDiscount, expectedParam.maxDiscount, 'maxDiscount');
    assertEq(lookbackWindowSize, expectedParam.lookbackWindowSize, 'lookbackWindowSize');
    assertEq(isUpperBoundEnabled, expectedParam.isUpperBoundEnabled, 'isUpperBoundEnabled');
    assertEq(isLowerBoundEnabled, expectedParam.isLowerBoundEnabled, 'isLowerBoundEnabled');
    assertEq(isActionTakingEnabled, expectedParam.isActionTakingEnabled, 'isActionTakingEnabled');
  }
}

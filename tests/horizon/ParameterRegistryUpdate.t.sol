// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'tests/horizon/ParameterRegistryUpdateBase.t.sol';

contract ParameterRegistryUpdateTest is ParameterRegistryUpdateBaseTest {
  function setUp() public override {
    super.setUp();
    vm.createSelectFork('mainnet');
  }

  function _loadExpectedParams() internal override {
    expectedParams[AaveV3EthereumHorizonCustom.USYC_UNDERLYING] = ParamRegistryFields({
      maxExpectedApy: 375,
      upperBoundTolerance: 10,
      lowerBoundTolerance: 5,
      maxDiscount: 10,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });
    expectedParams[AaveV3EthereumHorizonCustom.JAAA_UNDERLYING] = ParamRegistryFields({
      maxExpectedApy: 500,
      upperBoundTolerance: 25,
      lowerBoundTolerance: 10,
      maxDiscount: 75,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });
    expectedParams[AaveV3EthereumHorizonCustom.JTRSY_UNDERLYING] = ParamRegistryFields({
      maxExpectedApy: 375,
      upperBoundTolerance: 10,
      lowerBoundTolerance: 5,
      maxDiscount: 10,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });
    expectedParams[AaveV3EthereumHorizonCustom.USTB_UNDERLYING] = ParamRegistryFields({
      maxExpectedApy: 375,
      upperBoundTolerance: 10,
      lowerBoundTolerance: 5,
      maxDiscount: 10,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });
    expectedParams[AaveV3EthereumHorizonCustom.USCC_UNDERLYING] = ParamRegistryFields({
      maxExpectedApy: 750,
      upperBoundTolerance: 50,
      lowerBoundTolerance: 10,
      maxDiscount: 40,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });
    expectedParams[AaveV3EthereumHorizonCustom.VBILL_UNDERLYING] = ParamRegistryFields({
      maxExpectedApy: 0,
      upperBoundTolerance: 10,
      lowerBoundTolerance: 10,
      maxDiscount: 0,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });
  }
}

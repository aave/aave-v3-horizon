// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test, Vm} from 'forge-std/Test.sol';
import {AaveV3HorizonEthereum} from './utils/AaveV3HorizonEthereum.sol';

/// forge-config: default.evm_version = "cancun"
contract OracleDynamicBoundsTest is Test {
  function setUp() public {
    vm.createSelectFork('mainnet', 23469081);
  }
  struct ExpectedParams {
    uint64 maxExpectedApy;
    uint32 upperBoundTolerance;
    uint32 lowerBoundTolerance;
    uint32 maxDiscount;
    uint80 lookbackWindowSize;
    bool isUpperBoundEnabled;
    bool isLowerBoundEnabled;
    bool isActionTakingEnabled;
  }

  ExpectedParams internal USTB_EXPECTED_PARAMS =
    ExpectedParams({
      maxExpectedApy: 415,
      upperBoundTolerance: 15,
      lowerBoundTolerance: 5,
      maxDiscount: 10,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });
  ExpectedParams internal USCC_EXPECTED_PARAMS =
    ExpectedParams({
      maxExpectedApy: 2500,
      upperBoundTolerance: 50,
      lowerBoundTolerance: 10,
      maxDiscount: 40,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });
  ExpectedParams internal USYC_EXPECTED_PARAMS =
    ExpectedParams({
      maxExpectedApy: 420,
      upperBoundTolerance: 15,
      lowerBoundTolerance: 5,
      maxDiscount: 10,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });
  ExpectedParams internal JTRSY_EXPECTED_PARAMS =
    ExpectedParams({
      maxExpectedApy: 390,
      upperBoundTolerance: 15,
      lowerBoundTolerance: 5,
      maxDiscount: 10,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });
  ExpectedParams internal JAAA_EXPECTED_PARAMS =
    ExpectedParams({
      maxExpectedApy: 520,
      upperBoundTolerance: 50,
      lowerBoundTolerance: 10,
      maxDiscount: 75,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });
  ExpectedParams internal VBILL_EXPECTED_PARAMS =
    ExpectedParams({
      maxExpectedApy: 0,
      upperBoundTolerance: 10,
      lowerBoundTolerance: 10,
      maxDiscount: 0,
      lookbackWindowSize: 4,
      isUpperBoundEnabled: true,
      isLowerBoundEnabled: true,
      isActionTakingEnabled: false
    });

  function test_registry_admin() external {
    (bool success, bytes memory data) = AaveV3HorizonEthereum.PARAM_REGISTRY.call(
      abi.encodeWithSignature('owner()')
    );
    require(success, 'Failed to call owner()');
    address owner = abi.decode(data, (address));
    assertEq(owner, AaveV3HorizonEthereum.HORIZON_OPS, 'owner');

    (success, data) = AaveV3HorizonEthereum.PARAM_REGISTRY.call(
      abi.encodeWithSignature('updater()')
    );
    require(success, 'Failed to call owner()');
    address updater = abi.decode(data, (address));
    assertEq(updater, AaveV3HorizonEthereum.HORIZON_OPS, 'updater');
  }

  function test_ustb_oracle() external {
    test_horizon_adapter(
      AaveV3HorizonEthereum.USTB_ADDRESS,
      AaveV3HorizonEthereum.USTB_PRICE_FEED_ADAPTER,
      true
    );
    test_registry_params(AaveV3HorizonEthereum.USTB_ADDRESS, USTB_EXPECTED_PARAMS);
    test_lookback_data(AaveV3HorizonEthereum.USTB_ADDRESS);
  }

  function test_uscc_oracle() external {
    test_horizon_adapter(
      AaveV3HorizonEthereum.USCC_ADDRESS,
      AaveV3HorizonEthereum.USCC_PRICE_FEED_ADAPTER,
      true
    );
    test_registry_params(AaveV3HorizonEthereum.USCC_ADDRESS, USCC_EXPECTED_PARAMS);
    test_lookback_data(AaveV3HorizonEthereum.USCC_ADDRESS);
  }

  function test_usyc_oracle() external {
    test_horizon_adapter(
      AaveV3HorizonEthereum.USYC_ADDRESS,
      AaveV3HorizonEthereum.USYC_PRICE_FEED,
      false
    );
    test_registry_params(AaveV3HorizonEthereum.USYC_ADDRESS, USYC_EXPECTED_PARAMS);
    test_lookback_data(AaveV3HorizonEthereum.USYC_ADDRESS);
  }

  function test_jtrsy_oracle() external {
    test_horizon_adapter(
      AaveV3HorizonEthereum.JTRSY_ADDRESS,
      AaveV3HorizonEthereum.JTRSY_PRICE_FEED_ADAPTER,
      true
    );
    test_registry_params(AaveV3HorizonEthereum.JTRSY_ADDRESS, JTRSY_EXPECTED_PARAMS);
    test_lookback_data(AaveV3HorizonEthereum.JTRSY_ADDRESS);
  }

  function test_jaaa_oracle() external {
    test_horizon_adapter(
      AaveV3HorizonEthereum.JAAA_ADDRESS,
      AaveV3HorizonEthereum.JAAA_PRICE_FEED_ADAPTER,
      true
    );
    test_registry_params(AaveV3HorizonEthereum.JAAA_ADDRESS, JAAA_EXPECTED_PARAMS);
    test_lookback_data(AaveV3HorizonEthereum.JAAA_ADDRESS);
  }

  function test_vbill() external {
    test_horizon_adapter(
      AaveV3HorizonEthereum.VBILL_ADDRESS,
      AaveV3HorizonEthereum.VBILL_PRICE_FEED,
      false
    );
    test_registry_params(AaveV3HorizonEthereum.VBILL_ADDRESS, VBILL_EXPECTED_PARAMS);
    test_lookback_data(AaveV3HorizonEthereum.VBILL_ADDRESS);
  }

  function test_registry_params(address asset, ExpectedParams memory expectedParams) internal {
    bool success;
    bytes memory data;

    (success, data) = AaveV3HorizonEthereum.PARAM_REGISTRY.call(
      abi.encodeWithSignature('assetExists(address)', asset)
    );
    require(success, 'Failed to call assetExists()');
    bool exists = abi.decode(data, (bool));
    assertEq(exists, true, 'assetExists');

    (success, data) = AaveV3HorizonEthereum.PARAM_REGISTRY.call(
      abi.encodeWithSignature('getParametersForAsset(address)', asset)
    );
    require(success, 'Failed to call getParametersForAsset()');

    (
      uint64 maxExpectedApy,
      uint32 upperBoundTolerance,
      uint32 lowerBoundTolerance,
      uint32 maxDiscount,
      uint80 lookbackWindowSize,
      bool isUpperBoundEnabled,
      bool isLowerBoundEnabled,
      bool isActionTakingEnabled
    ) = abi.decode(data, (uint64, uint32, uint32, uint32, uint80, bool, bool, bool));

    assertEq(maxExpectedApy, expectedParams.maxExpectedApy, 'maxExpectedApy');
    assertEq(upperBoundTolerance, expectedParams.upperBoundTolerance, 'upperBoundTolerance');
    assertEq(lowerBoundTolerance, expectedParams.lowerBoundTolerance, 'lowerBoundTolerance');
    assertEq(maxDiscount, expectedParams.maxDiscount, 'maxDiscount');
    assertEq(lookbackWindowSize, expectedParams.lookbackWindowSize, 'lookbackWindowSize');
    assertEq(isUpperBoundEnabled, expectedParams.isUpperBoundEnabled, 'isUpperBoundEnabled');
    assertEq(isLowerBoundEnabled, expectedParams.isLowerBoundEnabled, 'isLowerBoundEnabled');
    assertEq(isActionTakingEnabled, expectedParams.isActionTakingEnabled, 'isActionTakingEnabled');
  }

  function test_horizon_adapter(address asset, address source, bool isAdapter) internal {
    bool success;
    bytes memory data;
    if (isAdapter) {
      // oracle source from horizon adapter
      (success, data) = source.call(abi.encodeWithSignature('source()'));
      require(success, 'Failed to call source()');
      source = abi.decode(data, (address));
    }

    // oracle address from param registry
    (success, data) = AaveV3HorizonEthereum.PARAM_REGISTRY.call(
      abi.encodeWithSignature('getOracle(address)', asset)
    );
    require(success, 'Failed to call getOracle()');
    address oracle = abi.decode(data, (address));

    assertEq(source, oracle, 'source');
  }

  function test_lookback_data(address asset) internal {
    bool success;
    bytes memory data;

    (success, data) = AaveV3HorizonEthereum.PARAM_REGISTRY.call(
      abi.encodeWithSignature('getLookbackData(address)', asset)
    );
    require(success, 'Failed to call getLookbackData()');

    (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) = abi.decode(data, (uint80, int256, uint256, uint256, uint80));

    assertGt(roundId, 0, 'roundId');
    assertGt(answer, 0, 'answer');
    assertApproxEqRel(startedAt, vm.getBlockTimestamp() - 4 * 1 days, 1e14, 'startedAt');
    assertApproxEqRel(updatedAt, vm.getBlockTimestamp() - 4 * 1 days, 1e14, 'updatedAt');
    assertGt(answeredInRound, 0, 'answeredInRound');
  }
}

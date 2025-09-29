// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2 as console} from 'forge-std/console2.sol';

import {Test, Vm} from 'forge-std/Test.sol';
import {IAaveOracle} from '../../src/contracts/interfaces/IAaveOracle.sol';
import {IPool} from '../../src/contracts/interfaces/IPool.sol';
import {AggregatorInterface} from '../../src/contracts/dependencies/chainlink/AggregatorInterface.sol';

import {AaveV3HorizonEthereum} from './utils/AaveV3HorizonEthereum.sol';

/// forge-config: default.evm_version = "cancun"
contract OracleDynamicBoundsTest is Test {
  address constant USTB_NEW_AGGREGATOR = 0x267D0DD05fbc989565C521e0B8882f61027FF32A;
  address constant USCC_NEW_AGGREGATOR = 0x2d7Cd12f24bD28684847bF3e4317899a4Db53c58;
  address constant USYC_NEW_AGGREGATOR = 0x3C405e1FE8a6BE5d9b714B8C88Ad913F236B1639;
  address constant JTRSY_NEW_AGGREGATOR = 0xcf8683fFdFC4b871DF35D05bc763F239612e7272;
  address constant JAAA_NEW_AGGREGATOR = 0x3a8E8491236368a582b651786bEdA49BD5c3BA7B;
  address constant VBILL_NEW_AGGREGATOR = 0x04d81C346252E31Ee888393AF6E2037a9a4d70Af;

  // read admin addresses found on-chain
  address constant USTB_READ_ADMIN = 0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf;
  address constant USCC_READ_ADMIN = 0x69D55D504BC9556E377b340D19818E736bbB318b;
  address constant USYC_READ_ADMIN = 0x69D55D504BC9556E377b340D19818E736bbB318b;
  address constant JTRSY_READ_ADMIN = 0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf;
  address constant JAAA_READ_ADMIN = 0x69D55D504BC9556E377b340D19818E736bbB318b;
  address constant VBILL_READ_ADMIN = 0x5ed77a9D9b7cc80E9d0D7711024AF38C2643C1c4;

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

  struct NewAggregator {
    address aggregator;
    address readAdmin;
  }

  mapping(address => ExpectedParams) internal expectedParams; // asset => expected params
  mapping(address => NewAggregator) internal newAggregators; // asset => new aggregator address

  IAaveOracle internal oracle;
  function setUp() public {
    vm.createSelectFork('mainnet', 23469081);
    _initEnvironment();
  }

  function _initEnvironment() internal {
    expectedParams[AaveV3HorizonEthereum.USTB_ADDRESS] = USTB_EXPECTED_PARAMS;
    expectedParams[AaveV3HorizonEthereum.USCC_ADDRESS] = USCC_EXPECTED_PARAMS;
    expectedParams[AaveV3HorizonEthereum.USYC_ADDRESS] = USYC_EXPECTED_PARAMS;
    expectedParams[AaveV3HorizonEthereum.JTRSY_ADDRESS] = JTRSY_EXPECTED_PARAMS;
    expectedParams[AaveV3HorizonEthereum.JAAA_ADDRESS] = JAAA_EXPECTED_PARAMS;
    expectedParams[AaveV3HorizonEthereum.VBILL_ADDRESS] = VBILL_EXPECTED_PARAMS;

    newAggregators[AaveV3HorizonEthereum.USTB_ADDRESS] = NewAggregator({
      aggregator: USTB_NEW_AGGREGATOR,
      readAdmin: USTB_READ_ADMIN
    });
    newAggregators[AaveV3HorizonEthereum.USCC_ADDRESS] = NewAggregator({
      aggregator: USCC_NEW_AGGREGATOR,
      readAdmin: USCC_READ_ADMIN
    });
    newAggregators[AaveV3HorizonEthereum.USYC_ADDRESS] = NewAggregator({
      aggregator: USYC_NEW_AGGREGATOR,
      readAdmin: USYC_READ_ADMIN
    });
    newAggregators[AaveV3HorizonEthereum.JTRSY_ADDRESS] = NewAggregator({
      aggregator: JTRSY_NEW_AGGREGATOR,
      readAdmin: JTRSY_READ_ADMIN
    });
    newAggregators[AaveV3HorizonEthereum.JAAA_ADDRESS] = NewAggregator({
      aggregator: JAAA_NEW_AGGREGATOR,
      readAdmin: JAAA_READ_ADMIN
    });
    newAggregators[AaveV3HorizonEthereum.VBILL_ADDRESS] = NewAggregator({
      aggregator: VBILL_NEW_AGGREGATOR,
      readAdmin: VBILL_READ_ADMIN
    });

    oracle = IAaveOracle(IPool(AaveV3HorizonEthereum.POOL).ADDRESSES_PROVIDER().getPriceOracle());
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

  function test_ustb() external {
    address oracleSource = oracle.getSourceOfAsset(AaveV3HorizonEthereum.USTB_ADDRESS);
    test_asset(AaveV3HorizonEthereum.USTB_ADDRESS, oracleSource, true);
  }

  function test_uscc() external {
    address oracleSource = oracle.getSourceOfAsset(AaveV3HorizonEthereum.USCC_ADDRESS);
    test_asset(AaveV3HorizonEthereum.USCC_ADDRESS, oracleSource, true);
  }

  function test_usyc() external {
    address oracleSource = oracle.getSourceOfAsset(AaveV3HorizonEthereum.USYC_ADDRESS);
    test_asset(AaveV3HorizonEthereum.USYC_ADDRESS, oracleSource, false);
  }

  function test_jtrsy() external {
    address oracleSource = oracle.getSourceOfAsset(AaveV3HorizonEthereum.JTRSY_ADDRESS);
    test_asset(AaveV3HorizonEthereum.JTRSY_ADDRESS, oracleSource, true);
  }

  function test_jaaa() external {
    address oracleSource = oracle.getSourceOfAsset(AaveV3HorizonEthereum.JAAA_ADDRESS);
    test_asset(AaveV3HorizonEthereum.JAAA_ADDRESS, oracleSource, true);
  }

  function test_vbill() external {
    // VBILL not deployed yet, get price feed directly from lib
    test_asset(AaveV3HorizonEthereum.VBILL_ADDRESS, AaveV3HorizonEthereum.VBILL_PRICE_FEED, false);
  }

  function test_asset(address asset, address oracleSource, bool isAdapter) internal {
    test_horizon_adapter(asset, oracleSource, isAdapter);
    test_registry_params(asset);
    test_lookback_data(asset);
    test_new_aggregator(asset);
  }

  function test_registry_params(address asset) internal {
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

    ExpectedParams memory expectedParam = expectedParams[asset];

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

    assertEq(maxExpectedApy, expectedParam.maxExpectedApy, 'maxExpectedApy');
    assertEq(upperBoundTolerance, expectedParam.upperBoundTolerance, 'upperBoundTolerance');
    assertEq(lowerBoundTolerance, expectedParam.lowerBoundTolerance, 'lowerBoundTolerance');
    assertEq(maxDiscount, expectedParam.maxDiscount, 'maxDiscount');
    assertEq(lookbackWindowSize, expectedParam.lookbackWindowSize, 'lookbackWindowSize');
    assertEq(isUpperBoundEnabled, expectedParam.isUpperBoundEnabled, 'isUpperBoundEnabled');
    assertEq(isLowerBoundEnabled, expectedParam.isLowerBoundEnabled, 'isLowerBoundEnabled');
    assertEq(isActionTakingEnabled, expectedParam.isActionTakingEnabled, 'isActionTakingEnabled');
  }

  /// test that the oracle source from horizon adapter/oracle source is the same as the oracle address from the param registry
  function test_horizon_adapter(address asset, address oracleSource, bool isAdapter) internal {
    bool success;
    bytes memory data;
    if (isAdapter) {
      // if adapter, get oracle source from horizon adapter source
      (success, data) = oracleSource.call(abi.encodeWithSignature('source()'));
      require(success, 'Failed to call source()');
      oracleSource = abi.decode(data, (address));
    }
    address oracle = _getParamRegistryOracle(asset);
    assertEq(oracleSource, oracle, 'source');
  }

  // read look back data from param registry
  function test_lookback_data(address asset) internal {
    bool success;
    bytes memory data;

    (success, data) = AaveV3HorizonEthereum.PARAM_REGISTRY.call(
      abi.encodeWithSignature('getLookbackData(address)', asset)
    );
    require(success, 'Failed to call getLookbackData()');

    // reads from old aggregator data
    (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) = abi.decode(data, (uint80, int256, uint256, uint256, uint80));

    assertGt(roundId, 0, 'roundId');
    assertGt(answer, 0, 'answer');
    assertApproxEqRel(
      startedAt,
      vm.getBlockTimestamp() - expectedParams[asset].lookbackWindowSize * 1 days, // within expected lookback window
      1e15,
      'startedAt'
    );
    assertApproxEqRel(
      updatedAt,
      vm.getBlockTimestamp() - expectedParams[asset].lookbackWindowSize * 1 days, // within expected lookback window
      1e15,
      'updatedAt'
    );
    assertGt(answeredInRound, 0, 'answeredInRound');
  }

  function test_new_aggregator(address asset) internal {
    // new aggregator data

    vm.prank(newAggregators[asset].readAdmin); // has access to price feed
    (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) = AggregatorInterface(newAggregators[asset].aggregator).latestRoundData();

    assertGt(roundId, expectedParams[asset].lookbackWindowSize, 'roundId');
    assertGt(answer, 0, 'answer');
    assertApproxEqRel(
      startedAt,
      vm.getBlockTimestamp() - expectedParams[asset].lookbackWindowSize * 1 days, // within expected lookback window
      1e15,
      'startedAt'
    );
    assertApproxEqRel(
      updatedAt,
      vm.getBlockTimestamp() - expectedParams[asset].lookbackWindowSize * 1 days, // within expected lookback window
      1e15,
      'updatedAt'
    );
    assertGt(answeredInRound, expectedParams[asset].lookbackWindowSize, 'answeredInRound');
  }

  // read oracle address from param registry
  function _getParamRegistryOracle(address asset) internal returns (address) {
    (bool success, bytes memory data) = AaveV3HorizonEthereum.PARAM_REGISTRY.call(
      abi.encodeWithSignature('getOracle(address)', asset)
    );
    require(success, 'Failed to call getOracle()');
    return abi.decode(data, (address));
  }
}

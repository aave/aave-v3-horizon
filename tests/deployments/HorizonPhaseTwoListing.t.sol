// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import './HorizonBase.t.sol';
import {DeployHorizonPhaseTwoPayload} from '../../scripts/misc/DeployHorizonPhaseTwoPayload.sol';

/// forge-config: default.evm_version = "cancun"
contract HorizonPhaseTwoListingTest is HorizonBaseTest {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using EModeConfiguration for uint128;
  using PercentageMath for uint256;

  TokenListingParams internal VBILL_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA VBILL',
      aTokenSymbol: 'aHorRwaVBILL',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt VBILL',
      variableDebtTokenSymbol: 'variableDebtHorRwaVBILL',
      isRwa: true,
      hasPriceAdapter: false,
      oracle: AaveV3HorizonEthereum.VBILL_PRICE_FEED,
      underlyingPriceFeed: AaveV3HorizonEthereum.VBILL_PRICE_FEED,
      supplyCap: 15_000_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 83_00,
      liquidationThreshold: 88_00,
      liquidationBonus: 100_00 + 3_00,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      }),
      initialDeposit: 0
    });

  function setUp() public virtual {
    vm.createSelectFork('mainnet');
    initEnvironment();
    _loadDeployment();

    _whitelistVbillRwa(alice);
    _whitelistVbillRwa(pool.getReserveAToken(AaveV3HorizonEthereum.VBILL_ADDRESS));
  }

  function test_listing_VBILL() public {
    test_listing(AaveV3HorizonEthereum.VBILL_ADDRESS, VBILL_TOKEN_LISTING_PARAMS);
  }

  function test_listing(address token, TokenListingParams memory params) internal virtual override {
    super.test_listing(token, params);
    if (params.isRwa) {
      test_nonEMode_collateralization(
        token,
        params,
        _toDynamicAddressArray(
          AaveV3HorizonEthereum.USDC_ADDRESS,
          AaveV3HorizonEthereum.RLUSD_ADDRESS,
          AaveV3HorizonEthereum.GHO_ADDRESS
        )
      );
    }
  }

  function _loadDeployment() internal virtual {
    (, address horizonPhaseTwoListing) = new DeployHorizonPhaseTwoPayload().run();

    vm.startPrank(AaveV3HorizonEthereum.HORIZON_EMERGENCY);
    (bool success, bytes memory returnData) = AaveV3HorizonEthereum.HORIZON_EXECUTOR.call(
      abi.encodeWithSignature(
        'executeTransaction(address,uint256,string,bytes,bool)',
        address(horizonPhaseTwoListing), // target
        0, // value
        'execute()', // signature
        '', // data
        true // withDelegatecall
      )
    );
    vm.stopPrank();
    require(success, 'Failed to execute transaction');
  }

  function _whitelistVbillRwa(address addressToWhitelist) internal virtual {
    (bool success, bytes memory data) = AaveV3HorizonEthereum.VBILL_ADDRESS.call(
      abi.encodeWithSignature('REGISTRY_SERVICE()')
    );
    require(success, 'Failed to call REGISTRY_SERVICE()');
    (success, data) = AaveV3HorizonEthereum.VBILL_ADDRESS.call(
      abi.encodeWithSignature('getDSService(uint256)', abi.decode(data, (uint256)))
    );
    require(success, 'Failed to call getDSService()');
    address registryService = abi.decode(data, (address));

    address admin = 0xDA8e2d926D28a86aeE933d928357583aae5D3b85; // retrieved onchain
    (success, data) = AaveV3HorizonEthereum.VBILL_ADDRESS.call(
      abi.encodeWithSignature('TRUST_SERVICE()')
    );
    require(success, 'Failed to call TRUST_SERVICE()');
    (success, data) = AaveV3HorizonEthereum.VBILL_ADDRESS.call(
      abi.encodeWithSignature('getDSService(uint256)', abi.decode(data, (uint256)))
    );
    address trustService = abi.decode(data, (address));
    (success, data) = trustService.call(abi.encodeWithSignature('getRole(address)', admin));
    require(success, 'Failed to call getRole()');
    require(abi.decode(data, (uint8)) != 0, 'Admin does not have role');

    vm.prank(admin);
    (success, ) = registryService.call(
      abi.encodeWithSignature(
        'addWallet(address,string)',
        addressToWhitelist,
        'f27e20ca73314651b387da0aa9116f30' // retrieved from on-chain tx
      )
    );
    require(success, 'Failed to call addWallet()');
  }
}

/// forge-config: default.evm_version = "cancun"
contract HorizonPhaseTwoListingPostDeploymentForkTest is HorizonPhaseTwoListingTest {
  function setUp() public virtual override {
    vm.skip(true, 'post payload deployment');
    vm.createSelectFork('mainnet');

    initEnvironment();
    _loadDeployment();

    _whitelistVbillRwa(alice);
    _whitelistVbillRwa(pool.getReserveAToken(AaveV3HorizonEthereum.VBILL_ADDRESS));
  }

  function _loadDeployment() internal virtual override {
    address horizonPhaseTwoListing = address(0); // fill in with deployed payload address

    vm.startPrank(AaveV3HorizonEthereum.HORIZON_EMERGENCY);
    (bool success, bytes memory returnData) = AaveV3HorizonEthereum.HORIZON_EXECUTOR.call(
      abi.encodeWithSignature(
        'executeTransaction(address,uint256,string,bytes,bool)',
        address(horizonPhaseTwoListing), // target
        0, // value
        'execute()', // signature
        '', // data
        true // withDelegatecall
      )
    );
    vm.stopPrank();
    require(success, 'Failed to execute transaction');
  }
}

/// forge-config: default.evm_version = "cancun"
contract HorizonPhaseTwoListingPostExecutionForkTest is HorizonPhaseTwoListingTest {
  function setUp() public virtual override {
    vm.skip(true, 'post payload execution');
    vm.createSelectFork('mainnet');

    initEnvironment();
    _loadDeployment();

    _whitelistVbillRwa(alice);
    _whitelistVbillRwa(pool.getReserveAToken(AaveV3HorizonEthereum.VBILL_ADDRESS));
  }

  function _loadDeployment() internal virtual override {}
}

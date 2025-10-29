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
      oracle: AaveV3EthereumHorizonCustom.VBILL_PRICE_FEED,
      underlyingPriceFeed: AaveV3EthereumHorizonCustom.VBILL_PRICE_FEED,
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

  EModeCategoryParams internal VBILL_GHO_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 84_00,
      liquidationThreshold: 89_00,
      liquidationBonus: 100_00 + 3_00,
      label: 'VBILL GHO',
      collateralAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.VBILL_UNDERLYING),
      borrowableAssets: _toDynamicAddressArray(AaveV3EthereumHorizonAssets.GHO_UNDERLYING)
    });

  function setUp() public virtual {
    vm.createSelectFork('mainnet');
    initEnvironment();
    _loadDeployment();

    _whitelistVbillRwa(alice);
    _whitelistVbillRwa(pool.getReserveAToken(AaveV3EthereumHorizonCustom.VBILL_UNDERLYING));

    _transferVBILLTo(alice, 1_000_000e6);
  }

  function test_listing_VBILL() public {
    test_listing(AaveV3EthereumHorizonCustom.VBILL_UNDERLYING, VBILL_TOKEN_LISTING_PARAMS);
  }

  function test_eMode_VBILL_GHO() public {
    test_eMode({eModeCategory: 1, params: VBILL_GHO_EMODE_PARAMS, dealCollateral: false});
  }

  // fund accounts by transferring existing VBILL, as `deal` causes issues on token contract accounting
  function _transferVBILLTo(address user, uint256 amount) internal virtual {
    vm.prank(0x5E6c2AD8376A9E5E857B1d91643399E9aB65ff8c); // on-chain holder, ~25M VBILL balance
    IERC20(AaveV3EthereumHorizonCustom.VBILL_UNDERLYING).transfer(user, amount);
  }

  function test_listing(address token, TokenListingParams memory params) internal virtual override {
    super.test_listing(token, params);
    if (params.isRwa) {
      test_nonEMode_collateralization({
        token: token,
        params: params,
        borrowableAssets: _toDynamicAddressArray(
          AaveV3EthereumHorizonAssets.USDC_UNDERLYING,
          AaveV3EthereumHorizonAssets.GHO_UNDERLYING
        ),
        dealCollateral: false
      });
    }
  }

  function _loadDeployment() internal virtual {
    (, address horizonPhaseTwoListing) = new DeployHorizonPhaseTwoPayload().run();

    vm.startPrank(AaveV3EthereumHorizonCustom.HORIZON_EMERGENCY);
    (bool success, bytes memory returnData) = AaveV3EthereumHorizonCustom.HORIZON_EXECUTOR.call(
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
    (bool success, bytes memory data) = AaveV3EthereumHorizonCustom.VBILL_UNDERLYING.call(
      abi.encodeWithSignature('REGISTRY_SERVICE()')
    );
    require(success, 'Failed to call REGISTRY_SERVICE()');
    (success, data) = AaveV3EthereumHorizonCustom.VBILL_UNDERLYING.call(
      abi.encodeWithSignature('getDSService(uint256)', abi.decode(data, (uint256)))
    );
    require(success, 'Failed to call getDSService()');
    address registryService = abi.decode(data, (address));

    address admin = 0xDA8e2d926D28a86aeE933d928357583aae5D3b85; // retrieved onchain
    (success, data) = AaveV3EthereumHorizonCustom.VBILL_UNDERLYING.call(
      abi.encodeWithSignature('TRUST_SERVICE()')
    );
    require(success, 'Failed to call TRUST_SERVICE()');
    (success, data) = AaveV3EthereumHorizonCustom.VBILL_UNDERLYING.call(
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
contract HorizonPhaseTwoListingVTestnetTest is HorizonPhaseTwoListingTest {
  function setUp() public virtual override {
    vm.createSelectFork('vtestnet');

    initEnvironment();

    _whitelistVbillRwa(alice);
    _whitelistVbillRwa(pool.getReserveAToken(AaveV3EthereumHorizonCustom.VBILL_UNDERLYING));

    _transferVBILLTo(alice, 1_000_000e6);
  }

  function test_actions() public {
    address testUser1 = 0xabCa9b6E08dC6C031880f515Ec0cf9e395D0d6B8;
    address testUser2 = 0x66C1d4c6195D587C99aCc4256EbaC0a8D0AB9f64;
    address testUser3 = 0xd22eefD49B81e078f576Dbb4A804aa250cB3A291;

    _supplyAndBorrow(testUser1);
    _supplyAndBorrow(testUser2);
    _supplyAndBorrow(testUser3);
  }

  function _supplyAndBorrow(address user) internal virtual {
    vm.startPrank(user);
    IERC20(AaveV3EthereumHorizonCustom.VBILL_UNDERLYING).approve(address(pool), 100e6);
    pool.supply(AaveV3EthereumHorizonCustom.VBILL_UNDERLYING, 100e6, user, 0);
    pool.borrow(AaveV3EthereumHorizonAssets.USDC_UNDERLYING, 50e6, 2, 0, user);
    vm.stopPrank();
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
    _whitelistVbillRwa(pool.getReserveAToken(AaveV3EthereumHorizonCustom.VBILL_UNDERLYING));

    _transferVBILLTo(alice, 1_000_000e6);
  }

  function _loadDeployment() internal virtual override {
    address horizonPhaseTwoListing = address(0); // fill in with deployed payload address

    vm.startPrank(AaveV3EthereumHorizonCustom.HORIZON_EMERGENCY);
    (bool success, bytes memory returnData) = AaveV3EthereumHorizonCustom.HORIZON_EXECUTOR.call(
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

    _whitelistVbillRwa(alice);
    _whitelistVbillRwa(pool.getReserveAToken(AaveV3EthereumHorizonCustom.VBILL_UNDERLYING));

    _transferVBILLTo(alice, 1_000_000e6);
  }
}

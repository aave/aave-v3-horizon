// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import './HorizonBase.t.sol';
import {HorizonInput} from 'src/deployments/inputs/HorizonInput.sol';
import {DeployHorizonPhaseTwoPayload} from '../../scripts/misc/DeployHorizonPhaseTwoPayload.sol';

/// forge-config: default.evm_version = "cancun"
contract HorizonPhaseTwoListingTest is HorizonBaseTest {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using EModeConfiguration for uint128;
  using PercentageMath for uint256;

  address internal constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address internal constant RLUSD_ADDRESS = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
  address internal constant GHO_ADDRESS = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
  address internal constant VBILL_ADDRESS = 0x2255718832bC9fD3bE1CaF75084F4803DA14FF01;
  address internal constant VBILL_PRICE_FEED = 0x5ed77a9D9b7cc80E9d0D7711024AF38C2643C1c4;

  TokenListingParams internal VBILL_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA VBILL',
      aTokenSymbol: 'aHorRwaVBILL',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt VBILL',
      variableDebtTokenSymbol: 'variableDebtHorRwaVBILL',
      isRwa: true,
      hasPriceAdapter: false,
      oracle: VBILL_PRICE_FEED,
      underlyingPriceFeed: VBILL_PRICE_FEED,
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
    loadDeployment();
  }

  function loadDeployment() internal virtual {
    HorizonInput horizonInput = new HorizonInput();
    address horizonPhaseTwoListing = new DeployHorizonPhaseTwoPayload().run();

    // console.log('horizonPhaseTwoListing', horizonPhaseTwoListing);
    // console.log('emergencyMultisig', horizonInput.EMERGENCY_MULTISIG());
    // console.log('phaseOneListingExecutor', horizonInput.PHASE_ONE_LISTING_EXECUTOR());

    vm.startPrank(horizonInput.EMERGENCY_MULTISIG());
    (bool success, bytes memory returnData) = horizonInput.PHASE_ONE_LISTING_EXECUTOR().call(
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

  function test_listing(address token, TokenListingParams memory params) internal virtual override {
    super.test_listing(token, params);
    if (params.isRwa) {
      test_nonEMode_collateralization(
        token,
        params,
        _toDynamicAddressArray(USDC_ADDRESS, RLUSD_ADDRESS, GHO_ADDRESS)
      );
    }
  }

  function test_listing_VBILL() public {
    whitelistVbillRwa(alice);
    whitelistVbillRwa(pool.getReserveAToken(VBILL_ADDRESS));

    // deal(VBILL_ADDRESS, alice, 1e10);

    // vm.prank(alice);
    // IERC20(VBILL_ADDRESS).approve(address(pool), 1e10);

    // vm.prank(address(pool));
    // IERC20(VBILL_ADDRESS).transferFrom(alice, 0x69133f8Ef7F9A5F80D25c2DAEaea64C804aC7Cf9, 1000);

    // vm.prank(alice);
    // pool.supply(VBILL_ADDRESS, 1e10, alice, 0);

    // console.log('balance of alice', IERC20(VBILL_ADDRESS).balanceOf(alice));

    test_listing(VBILL_ADDRESS, VBILL_TOKEN_LISTING_PARAMS);
    // assertTrue(true);
    // address token = VBILL_ADDRESS;
    // address aToken = pool.getReserveAToken(token);
    // console.log('atoken, treasury', aToken, IAToken(aToken).RESERVE_TREASURY_ADDRESS());
  }

  function whitelistVbillRwa(address addressToWhitelist) internal {
    (bool success, bytes memory data) = VBILL_ADDRESS.call(
      abi.encodeWithSignature('REGISTRY_SERVICE()')
    );
    require(success, 'Failed to call REGISTRY_SERVICE()');
    (success, data) = VBILL_ADDRESS.call(
      abi.encodeWithSignature('getDSService(uint256)', abi.decode(data, (uint256)))
    );
    require(success, 'Failed to call getDSService()');
    address registryService = abi.decode(data, (address));

    address admin = 0xDA8e2d926D28a86aeE933d928357583aae5D3b85;
    (success, data) = VBILL_ADDRESS.call(abi.encodeWithSignature('TRUST_SERVICE()'));
    require(success, 'Failed to call TRUST_SERVICE()');
    (success, data) = VBILL_ADDRESS.call(
      abi.encodeWithSignature('getDSService(uint256)', abi.decode(data, (uint256)))
    );
    address trustService = abi.decode(data, (address));
    (success, data) = trustService.call(abi.encodeWithSignature('getRole(address)', admin));
    // console.log('data', abi.decode(data, (uint8)));
    // console.log('trustService', trustService);
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

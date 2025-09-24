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
      isRwa: false,
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

  function setUp() public virtual {
    vm.createSelectFork('mainnet');
    initEnvironment();
    loadDeployment();
  }

  function test_listing_VBILL() public {
    test_listing(VBILL_ADDRESS, VBILL_TOKEN_LISTING_PARAMS);
    assertTrue(true);
  }
}

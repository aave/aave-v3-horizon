// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {HorizonPhaseOneListingTest, IDefaultInterestRateStrategyV2, ReserveConfiguration, DataTypes, EModeConfiguration} from './HorizonPhaseOneListing.t.sol';
import {DeployHorizonPhaseOneUpdatePayload} from '../../scripts/misc/DeployHorizonPhaseOneUpdatePayload.sol';

/// forge-config: default.evm_version = "cancun"
contract HorizonPhaseOneUpdateTest is HorizonPhaseOneListingTest {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using EModeConfiguration for uint128;

  // horizon addresses
  DeploymentInfo internal deploymentInfo =
    DeploymentInfo({
      pool: 0xAe05Cd22df81871bc7cC2a04BeCfb516bFe332C8,
      revenueSplitter: 0xE5E6091073a9EcaCD8611d0D4A843464ebf3D2F8,
      defaultInterestRateStrategy: 0x87593272C06f4FC49EC2942eBda0972d2F1Ab521,
      rwaATokenManager: 0x803e5Db3E26e88AD0a682A46c3E04cdd053D0EB9,
      aTokenImpl: 0x9B2e8Be7f365F4A51137A41Df5C2d5F27A5C243C,
      rwaATokenImpl: 0x1d0Da70de08987b1888befECe0024443Bf3c2450,
      variableDebtTokenImpl: 0x15F03E5dE87c12cb2e2b8e5d6ECEf0a9E21ab269,
      poolAdmin: AAVE_DAO_EXECUTOR
    });

  function loadDeployment() internal virtual override returns (DeploymentInfo memory) {
    address horizonPhaseOneUpdate = new DeployHorizonPhaseOneUpdatePayload().run();
    vm.prank(EMERGENCY_MULTISIG);
    (bool success, ) = LISTING_EXECUTOR_ADDRESS.call(
      abi.encodeWithSignature(
        'executeTransaction(address,uint256,string,bytes,bool)',
        address(horizonPhaseOneUpdate), // target
        0, // value
        'execute()', // signature
        '', // data
        true // withDelegatecall
      )
    );
    require(success, 'Failed to execute transaction');

    return deploymentInfo;
  }

  function setUp() public virtual override {
    vm.skip(true);
    super.setUp();
    loadUpdatedParams();
  }

  function loadUpdatedParams() internal {
    // rwa
    USTB_TOKEN_LISTING_PARAMS = TokenListingParams({
      aTokenName: 'Aave Horizon RWA USTB',
      aTokenSymbol: 'aHorRwaUSTB',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USTB',
      variableDebtTokenSymbol: 'variableDebtHorRwaUSTB',
      isRwa: true,
      hasPriceAdapter: true,
      oracle: USTB_PRICE_FEED_ADAPTER,
      underlyingPriceFeed: USTB_PRICE_FEED,
      supplyCap: 1_800_000,
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
    USTB_STABLECOINS_EMODE_PARAMS.label = '';
    USCC_TOKEN_LISTING_PARAMS = TokenListingParams({
      aTokenName: 'Aave Horizon RWA USCC',
      aTokenSymbol: 'aHorRwaUSCC',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USCC',
      variableDebtTokenSymbol: 'variableDebtHorRwaUSCC',
      isRwa: true,
      hasPriceAdapter: true,
      oracle: USCC_PRICE_FEED_ADAPTER,
      underlyingPriceFeed: USCC_PRICE_FEED,
      supplyCap: 960_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 73_00,
      liquidationThreshold: 80_00,
      liquidationBonus: 100_00 + 7_50,
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
    USCC_GHO_EMODE_PARAMS.ltv = 74_00;
    USCC_GHO_EMODE_PARAMS.liquidationThreshold = 81_00;
    USCC_STABLECOINS_EMODE_PARAMS.label = '';
    USYC_TOKEN_LISTING_PARAMS = TokenListingParams({
      aTokenName: 'Aave Horizon RWA USYC',
      aTokenSymbol: 'aHorRwaUSYC',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USYC',
      variableDebtTokenSymbol: 'variableDebtHorRwaUSYC',
      isRwa: true,
      hasPriceAdapter: false,
      oracle: USYC_PRICE_FEED,
      underlyingPriceFeed: USYC_PRICE_FEED,
      supplyCap: 10_300_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 85_00,
      liquidationThreshold: 89_00,
      liquidationBonus: 100_00 + 3_10,
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
    USYC_STABLECOINS_EMODE_PARAMS.label = '';
    JTRSY_TOKEN_LISTING_PARAMS = TokenListingParams({
      aTokenName: 'Aave Horizon RWA JTRSY',
      aTokenSymbol: 'aHorRwaJTRSY',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt JTRSY',
      variableDebtTokenSymbol: 'variableDebtHorRwaJTRSY',
      isRwa: true,
      hasPriceAdapter: true,
      oracle: JTRSY_PRICE_FEED_ADAPTER,
      underlyingPriceFeed: JTRSY_PRICE_FEED,
      supplyCap: 4_600_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 77_00,
      liquidationThreshold: 83_00,
      liquidationBonus: 100_00 + 4_50,
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
    JTRSY_STABLECOINS_EMODE_PARAMS.label = '';
    JAAA_TOKEN_LISTING_PARAMS = TokenListingParams({
      aTokenName: 'Aave Horizon RWA JAAA',
      aTokenSymbol: 'aHorRwaJAAA',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt JAAA',
      variableDebtTokenSymbol: 'variableDebtHorRwaJAAA',
      isRwa: true,
      hasPriceAdapter: true,
      oracle: JAAA_PRICE_FEED_ADAPTER,
      underlyingPriceFeed: JAAA_PRICE_FEED,
      supplyCap: 9_900_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 71_00,
      liquidationThreshold: 78_00,
      liquidationBonus: 100_00 + 9_00,
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
    JAAA_STABLECOINS_EMODE_PARAMS.label = '';

    // stables
    GHO_TOKEN_LISTING_PARAMS.supplyCap = 1_000_000;
    GHO_TOKEN_LISTING_PARAMS.borrowCap = 900_000;

    // rLUSD
    RLUSD_TOKEN_LISTING_PARAMS.supplyCap = 30_000_000;
    RLUSD_TOKEN_LISTING_PARAMS.borrowCap = 27_000_000;

    // USDC
    USDC_TOKEN_LISTING_PARAMS.supplyCap = 16_000_000;
    USDC_TOKEN_LISTING_PARAMS.borrowCap = 14_400_000;
  }

  function test_eMode_USTB_Stablecoins() public view override {
    test_eMode_disabled(1, USTB_STABLECOINS_EMODE_PARAMS);
  }

  function test_eMode_USCC_Stablecoins() public view override {
    test_eMode_disabled(3, USCC_STABLECOINS_EMODE_PARAMS);
  }

  function test_eMode_USYC_Stablecoins() public view override {
    test_eMode_disabled(5, USYC_STABLECOINS_EMODE_PARAMS);
  }

  function test_eMode_JTRSY_Stablecoins() public view override {
    test_eMode_disabled(7, JTRSY_STABLECOINS_EMODE_PARAMS);
  }

  function test_eMode_JAAA_Stablecoins() public view override {
    test_eMode_disabled(9, JAAA_STABLECOINS_EMODE_PARAMS);
  }

  function test_eMode_disabled(
    uint8 eModeCategory,
    EModeCategoryParams memory params
  ) internal view {
    assertEq(pool.getEModeCategoryCollateralConfig(eModeCategory).ltv, params.ltv, 'emode.ltv');
    assertEq(
      pool.getEModeCategoryCollateralConfig(eModeCategory).liquidationThreshold,
      params.liquidationThreshold,
      'emode.liquidationThreshold'
    );
    assertEq(
      pool.getEModeCategoryCollateralConfig(eModeCategory).liquidationBonus,
      params.liquidationBonus,
      'emode.liquidationBonus'
    );
    assertEq(pool.getEModeCategoryLabel(eModeCategory), params.label, 'emode.label');
    assertEq(pool.getEModeCategoryCollateralBitmap(eModeCategory), 0, 'emode.collateralBitmap');
    assertEq(pool.getEModeCategoryBorrowableBitmap(eModeCategory), 0, 'emode.borrowableBitmap');
  }
}

contract HorizonPhaseOneUpdatePostDeploymentForkTest is HorizonPhaseOneUpdateTest {
  function setUp() public override {
    vm.skip(true, 'post-payload deployment');
    super.setUp();
  }

  function loadDeployment() internal override returns (DeploymentInfo memory) {
    address horizonPhaseOneUpdate; // TODO: deployed payload address
    vm.prank(EMERGENCY_MULTISIG);
    (bool success, ) = LISTING_EXECUTOR_ADDRESS.call(
      abi.encodeWithSignature(
        'executeTransaction(address,uint256,string,bytes,bool)',
        address(horizonPhaseOneUpdate), // target
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

contract HorizonPhaseOneUpdatePostExecutionForkTest is HorizonPhaseOneUpdateTest {
  function setUp() public override {
    vm.skip(true, 'post-payload execution');
    super.setUp();
  }

  function loadDeployment() internal view override returns (DeploymentInfo memory) {
    return deploymentInfo;
  }
}

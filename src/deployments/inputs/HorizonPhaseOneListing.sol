// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ACLManager} from '../../contracts/protocol/configuration/ACLManager.sol';
import {IPoolConfigurator} from '../../contracts/interfaces/IPoolConfigurator.sol';
import {MarketReport} from '../interfaces/IMarketReportTypes.sol';
import {IAaveV3ConfigEngine as IEngine} from '../../contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from '../../contracts/extensions/v3-config-engine/EngineFlags.sol';
import {AaveV3Payload} from '../../contracts/extensions/v3-config-engine/AaveV3Payload.sol';

contract HorizonPhaseOneListing is AaveV3Payload {
  address public immutable ATOKEN_IMPLEMENTATION;
  address public immutable RWA_ATOKEN_IMPLEMENTATION;
  address public immutable VARIABLE_DEBT_TOKEN_IMPLEMENTATION;

  ACLManager public immutable ACL_MANAGER;
  IPoolConfigurator public immutable CONFIGURATOR;

  address public immutable GHO_ADDRESS;
  address public immutable GHO_PRICE_FEED;

  address public immutable USDC_ADDRESS;
  address public immutable USDC_PRICE_FEED;

  address public immutable RLUSD_ADDRESS;
  address public immutable RLUSD_PRICE_FEED;

  address public immutable USTB_ADDRESS;
  address public immutable USTB_PRICE_FEED_ADAPTER;

  address public immutable USCC_ADDRESS;
  address public immutable USCC_PRICE_FEED_ADAPTER;

  address public immutable USYC_ADDRESS;
  address public immutable USYC_PRICE_FEED;

  address public immutable JTRSY_ADDRESS;
  address public immutable JTRSY_PRICE_FEED_ADAPTER;

  address public immutable JAAA_ADDRESS;
  address public immutable JAAA_PRICE_FEED_ADAPTER;

  bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256('EMERGENCY_ADMIN');

  constructor(MarketReport memory report) AaveV3Payload(IEngine(report.configEngine)) {
    ATOKEN_IMPLEMENTATION = report.aToken;
    RWA_ATOKEN_IMPLEMENTATION = report.rwaAToken;
    VARIABLE_DEBT_TOKEN_IMPLEMENTATION = report.variableDebtToken;

    ACL_MANAGER = ACLManager(report.aclManager);
    require(report.poolConfiguratorProxy == address(CONFIG_ENGINE.POOL_CONFIGURATOR()));
    CONFIGURATOR = IPoolConfigurator(report.poolConfiguratorProxy);

    GHO_ADDRESS = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    GHO_PRICE_FEED = 0xD110cac5d8682A3b045D5524a9903E031d70FCCd;

    USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    USDC_PRICE_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    RLUSD_ADDRESS = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
    RLUSD_PRICE_FEED = 0x26C46B7aD0012cA71F2298ada567dC9Af14E7f2A;

    USTB_ADDRESS = 0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e;
    USTB_PRICE_FEED_ADAPTER = 0x5Ae4D93B9b9626Dc3289e1Afb14b821FD3C95F44;

    USCC_ADDRESS = 0x14d60E7FDC0D71d8611742720E4C50E7a974020c;
    USCC_PRICE_FEED_ADAPTER = 0x14CB2E810Eb93b79363f489D45a972b609E47230;

    USYC_ADDRESS = 0x136471a34f6ef19fE571EFFC1CA711fdb8E49f2b;
    USYC_PRICE_FEED = 0xE8E65Fb9116875012F5990Ecaab290B3531DbeB9;

    JTRSY_ADDRESS = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    JTRSY_PRICE_FEED_ADAPTER = 0xfAB6790E399f0481e1303167c655b3c39ee6e7A0;

    JAAA_ADDRESS = 0x5a0F93D040De44e78F251b03c43be9CF317Dcf64;
    JAAA_PRICE_FEED_ADAPTER = 0xF77f2537dba4ffD60f77fACdfB2c1706364fA03d;
  }

  function eModeCategoriesUpdates()
    public
    pure
    override
    returns (IEngine.EModeCategoryUpdate[] memory)
  {
    IEngine.EModeCategoryUpdate[] memory eModeCategories = new IEngine.EModeCategoryUpdate[](10);

    // USTB Stablecoins
    eModeCategories[0] = IEngine.EModeCategoryUpdate({
      eModeCategory: 1,
      ltv: 83_00,
      liqThreshold: 88_00,
      liqBonus: 3_00,
      label: 'USTB Stablecoins'
    });

    // USTB GHO
    eModeCategories[1] = IEngine.EModeCategoryUpdate({
      eModeCategory: 2,
      ltv: 84_00,
      liqThreshold: 89_00,
      liqBonus: 3_00,
      label: 'USTB GHO'
    });

    // USCC Stablecoins
    eModeCategories[2] = IEngine.EModeCategoryUpdate({
      eModeCategory: 3,
      ltv: 72_00,
      liqThreshold: 79_00,
      liqBonus: 7_50,
      label: 'USCC Stablecoins'
    });

    // USCC GHO
    eModeCategories[3] = IEngine.EModeCategoryUpdate({
      eModeCategory: 4,
      ltv: 73_00,
      liqThreshold: 80_00,
      liqBonus: 7_50,
      label: 'USCC GHO'
    });

    // USYC Stablecoins
    eModeCategories[4] = IEngine.EModeCategoryUpdate({
      eModeCategory: 5,
      ltv: 85_00,
      liqThreshold: 89_00,
      liqBonus: 3_10,
      label: 'USYC Stablecoins'
    });

    // USYC GHO
    eModeCategories[5] = IEngine.EModeCategoryUpdate({
      eModeCategory: 6,
      ltv: 86_00,
      liqThreshold: 90_00,
      liqBonus: 3_10,
      label: 'USYC GHO'
    });

    // JTRSY Stablecoins
    eModeCategories[6] = IEngine.EModeCategoryUpdate({
      eModeCategory: 7,
      ltv: 77_00,
      liqThreshold: 83_00,
      liqBonus: 4_50,
      label: 'JTRSY Stablecoins'
    });

    // JTRSY GHO
    eModeCategories[7] = IEngine.EModeCategoryUpdate({
      eModeCategory: 8,
      ltv: 78_00,
      liqThreshold: 84_00,
      liqBonus: 4_50,
      label: 'JTRSY GHO'
    });

    // JAAA Stablecoins
    eModeCategories[8] = IEngine.EModeCategoryUpdate({
      eModeCategory: 9,
      ltv: 71_00,
      liqThreshold: 78_00,
      liqBonus: 9_00,
      label: 'JAAA Stablecoins'
    });

    // JAAA GHO
    eModeCategories[9] = IEngine.EModeCategoryUpdate({
      eModeCategory: 10,
      ltv: 72_00,
      liqThreshold: 79_00,
      liqBonus: 9_00,
      label: 'JAAA GHO'
    });

    return eModeCategories;
  }

  function newListingsCustom()
    public
    view
    override
    returns (IEngine.ListingWithCustomImpl[] memory)
  {
    IEngine.ListingWithCustomImpl[] memory listingsCustom = new IEngine.ListingWithCustomImpl[](8);

    listingsCustom[0] = IEngine.ListingWithCustomImpl(
      IEngine.Listing({
        asset: GHO_ADDRESS,
        assetSymbol: 'GHO',
        priceFeed: GHO_PRICE_FEED,
        rateStrategyParams: IEngine.InterestRateInputData({
          optimalUsageRatio: 99_00,
          baseVariableBorrowRate: 4_75,
          variableRateSlope1: 0,
          variableRateSlope2: 0
        }),
        enabledToBorrow: EngineFlags.ENABLED,
        borrowableInIsolation: EngineFlags.DISABLED,
        withSiloedBorrowing: EngineFlags.DISABLED,
        flashloanable: EngineFlags.DISABLED,
        ltv: 0,
        liqThreshold: 0,
        liqBonus: 0,
        reserveFactor: 10_00,
        supplyCap: 25_000_000,
        borrowCap: 22_500_000,
        debtCeiling: 0,
        liqProtocolFee: 0
      }),
      IEngine.TokenImplementations({
        aToken: ATOKEN_IMPLEMENTATION,
        vToken: VARIABLE_DEBT_TOKEN_IMPLEMENTATION
      })
    );

    listingsCustom[1] = IEngine.ListingWithCustomImpl(
      IEngine.Listing({
        asset: USDC_ADDRESS,
        assetSymbol: 'USDC',
        priceFeed: USDC_PRICE_FEED,
        rateStrategyParams: IEngine.InterestRateInputData({
          optimalUsageRatio: 90_00,
          baseVariableBorrowRate: 0,
          variableRateSlope1: 5_00,
          variableRateSlope2: 25_00
        }),
        enabledToBorrow: EngineFlags.ENABLED,
        borrowableInIsolation: EngineFlags.DISABLED,
        withSiloedBorrowing: EngineFlags.DISABLED,
        flashloanable: EngineFlags.DISABLED,
        ltv: 0,
        liqThreshold: 0,
        liqBonus: 0,
        reserveFactor: 10_00,
        supplyCap: 35_000_000,
        borrowCap: 31_500_000,
        debtCeiling: 0,
        liqProtocolFee: 0
      }),
      IEngine.TokenImplementations({
        aToken: ATOKEN_IMPLEMENTATION,
        vToken: VARIABLE_DEBT_TOKEN_IMPLEMENTATION
      })
    );

    listingsCustom[2] = IEngine.ListingWithCustomImpl(
      IEngine.Listing({
        asset: RLUSD_ADDRESS,
        assetSymbol: 'RLUSD',
        priceFeed: RLUSD_PRICE_FEED,
        rateStrategyParams: IEngine.InterestRateInputData({
          optimalUsageRatio: 90_00,
          baseVariableBorrowRate: 0,
          variableRateSlope1: 5_00,
          variableRateSlope2: 25_00
        }),
        enabledToBorrow: EngineFlags.ENABLED,
        borrowableInIsolation: EngineFlags.DISABLED,
        withSiloedBorrowing: EngineFlags.DISABLED,
        flashloanable: EngineFlags.DISABLED,
        ltv: 0,
        liqThreshold: 0,
        liqBonus: 0,
        reserveFactor: 10_00,
        supplyCap: 35_000_000,
        borrowCap: 31_500_000,
        debtCeiling: 0,
        liqProtocolFee: 0
      }),
      IEngine.TokenImplementations({
        aToken: ATOKEN_IMPLEMENTATION,
        vToken: VARIABLE_DEBT_TOKEN_IMPLEMENTATION
      })
    );

    listingsCustom[3] = IEngine.ListingWithCustomImpl(
      IEngine.Listing({
        asset: USTB_ADDRESS,
        assetSymbol: 'USTB',
        priceFeed: USTB_PRICE_FEED_ADAPTER,
        rateStrategyParams: IEngine.InterestRateInputData({
          optimalUsageRatio: 99_00,
          baseVariableBorrowRate: 0,
          variableRateSlope1: 0,
          variableRateSlope2: 0
        }),
        enabledToBorrow: EngineFlags.DISABLED,
        borrowableInIsolation: EngineFlags.DISABLED,
        withSiloedBorrowing: EngineFlags.DISABLED,
        flashloanable: EngineFlags.DISABLED,
        ltv: 5,
        liqThreshold: 10,
        liqBonus: 3_00,
        reserveFactor: EngineFlags.KEEP_CURRENT,
        supplyCap: 46_090_000,
        borrowCap: 0,
        debtCeiling: 0,
        liqProtocolFee: 0
      }),
      IEngine.TokenImplementations({
        aToken: RWA_ATOKEN_IMPLEMENTATION,
        vToken: VARIABLE_DEBT_TOKEN_IMPLEMENTATION
      })
    );

    listingsCustom[4] = IEngine.ListingWithCustomImpl(
      IEngine.Listing({
        asset: USCC_ADDRESS,
        assetSymbol: 'USCC',
        priceFeed: USCC_PRICE_FEED_ADAPTER,
        rateStrategyParams: IEngine.InterestRateInputData({
          optimalUsageRatio: 99_00,
          baseVariableBorrowRate: 0,
          variableRateSlope1: 0,
          variableRateSlope2: 0
        }),
        enabledToBorrow: EngineFlags.DISABLED,
        borrowableInIsolation: EngineFlags.DISABLED,
        withSiloedBorrowing: EngineFlags.DISABLED,
        flashloanable: EngineFlags.DISABLED,
        ltv: 5,
        liqThreshold: 10,
        liqBonus: 7_50,
        reserveFactor: EngineFlags.KEEP_CURRENT,
        supplyCap: 15_400_000,
        borrowCap: 0,
        debtCeiling: 0,
        liqProtocolFee: 0
      }),
      IEngine.TokenImplementations({
        aToken: RWA_ATOKEN_IMPLEMENTATION,
        vToken: VARIABLE_DEBT_TOKEN_IMPLEMENTATION
      })
    );

    listingsCustom[5] = IEngine.ListingWithCustomImpl(
      IEngine.Listing({
        asset: USYC_ADDRESS,
        assetSymbol: 'USYC',
        priceFeed: USYC_PRICE_FEED,
        rateStrategyParams: IEngine.InterestRateInputData({
          optimalUsageRatio: 99_00,
          baseVariableBorrowRate: 0,
          variableRateSlope1: 0,
          variableRateSlope2: 0
        }),
        enabledToBorrow: EngineFlags.DISABLED,
        borrowableInIsolation: EngineFlags.DISABLED,
        withSiloedBorrowing: EngineFlags.DISABLED,
        flashloanable: EngineFlags.DISABLED,
        ltv: 5,
        liqThreshold: 10,
        liqBonus: 3_10,
        reserveFactor: EngineFlags.KEEP_CURRENT,
        supplyCap: 28_050_000,
        borrowCap: 0,
        debtCeiling: 0,
        liqProtocolFee: 0
      }),
      IEngine.TokenImplementations({
        aToken: RWA_ATOKEN_IMPLEMENTATION,
        vToken: VARIABLE_DEBT_TOKEN_IMPLEMENTATION
      })
    );

    listingsCustom[6] = IEngine.ListingWithCustomImpl(
      IEngine.Listing({
        asset: JTRSY_ADDRESS,
        assetSymbol: 'JTRSY',
        priceFeed: JTRSY_PRICE_FEED_ADAPTER,
        rateStrategyParams: IEngine.InterestRateInputData({
          optimalUsageRatio: 99_00,
          baseVariableBorrowRate: 0,
          variableRateSlope1: 0,
          variableRateSlope2: 0
        }),
        enabledToBorrow: EngineFlags.DISABLED,
        borrowableInIsolation: EngineFlags.DISABLED,
        withSiloedBorrowing: EngineFlags.DISABLED,
        flashloanable: EngineFlags.DISABLED,
        ltv: 5,
        liqThreshold: 10,
        liqBonus: 4_50,
        reserveFactor: EngineFlags.KEEP_CURRENT,
        supplyCap: 23_650_000,
        borrowCap: 0,
        debtCeiling: 0,
        liqProtocolFee: 0
      }),
      IEngine.TokenImplementations({
        aToken: RWA_ATOKEN_IMPLEMENTATION,
        vToken: VARIABLE_DEBT_TOKEN_IMPLEMENTATION
      })
    );

    listingsCustom[7] = IEngine.ListingWithCustomImpl(
      IEngine.Listing({
        asset: JAAA_ADDRESS,
        assetSymbol: 'JAAA',
        priceFeed: JAAA_PRICE_FEED_ADAPTER,
        rateStrategyParams: IEngine.InterestRateInputData({
          optimalUsageRatio: 99_00,
          baseVariableBorrowRate: 0,
          variableRateSlope1: 0,
          variableRateSlope2: 0
        }),
        enabledToBorrow: EngineFlags.DISABLED,
        borrowableInIsolation: EngineFlags.DISABLED,
        withSiloedBorrowing: EngineFlags.DISABLED,
        flashloanable: EngineFlags.DISABLED,
        ltv: 5,
        liqThreshold: 10,
        liqBonus: 9_00,
        reserveFactor: EngineFlags.KEEP_CURRENT,
        supplyCap: 24_800_000,
        borrowCap: 0,
        debtCeiling: 0,
        liqProtocolFee: 0
      }),
      IEngine.TokenImplementations({
        aToken: RWA_ATOKEN_IMPLEMENTATION,
        vToken: VARIABLE_DEBT_TOKEN_IMPLEMENTATION
      })
    );

    return listingsCustom;
  }

  function assetsEModeUpdates() public view override returns (IEngine.AssetEModeUpdate[] memory) {
    IEngine.AssetEModeUpdate[] memory assetsEMode = new IEngine.AssetEModeUpdate[](25);

    uint256 index = 0;

    // USTB Stablecoins
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USTB_ADDRESS,
      eModeCategory: 1,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USDC_ADDRESS,
      eModeCategory: 1,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: RLUSD_ADDRESS,
      eModeCategory: 1,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });

    // USTB GHO
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USTB_ADDRESS,
      eModeCategory: 2,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: GHO_ADDRESS,
      eModeCategory: 2,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });

    // USCC Stablecoins
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USCC_ADDRESS,
      eModeCategory: 3,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USDC_ADDRESS,
      eModeCategory: 3,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: RLUSD_ADDRESS,
      eModeCategory: 3,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });

    // USCC GHO
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USCC_ADDRESS,
      eModeCategory: 4,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: GHO_ADDRESS,
      eModeCategory: 4,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });

    // USYC Stablecoins
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USYC_ADDRESS,
      eModeCategory: 5,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USDC_ADDRESS,
      eModeCategory: 5,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: RLUSD_ADDRESS,
      eModeCategory: 5,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });

    // USYC GHO
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USYC_ADDRESS,
      eModeCategory: 6,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: GHO_ADDRESS,
      eModeCategory: 6,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });

    // JTRSY Stablecoins
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: JTRSY_ADDRESS,
      eModeCategory: 7,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USDC_ADDRESS,
      eModeCategory: 7,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: RLUSD_ADDRESS,
      eModeCategory: 7,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });

    // JTRSY GHO
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: JTRSY_ADDRESS,
      eModeCategory: 8,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: GHO_ADDRESS,
      eModeCategory: 8,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });

    // JAAA Stablecoins
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: JAAA_ADDRESS,
      eModeCategory: 9,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USDC_ADDRESS,
      eModeCategory: 9,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: RLUSD_ADDRESS,
      eModeCategory: 9,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });

    // JAAA GHO
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: JAAA_ADDRESS,
      eModeCategory: 10,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: GHO_ADDRESS,
      eModeCategory: 10,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });

    assert(index == assetsEMode.length);

    return assetsEMode;
  }

  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Horizon RWA', networkAbbreviation: 'HorRwa'});
  }

  function _postExecute() internal override {
    CONFIGURATOR.setPoolPause(true);
    ACLManager(ACL_MANAGER).renounceRole(EMERGENCY_ADMIN_ROLE, address(this));
  }
}

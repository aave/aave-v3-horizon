// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IAaveV3ConfigEngine as IEngine} from '../../contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from '../../contracts/extensions/v3-config-engine/EngineFlags.sol';
import {AaveV3Payload} from '../../contracts/extensions/v3-config-engine/AaveV3Payload.sol';

import {AaveV3EthereumHorizonCustom} from 'tests/horizon/utils/AaveV3EthereumHorizonCustom.sol';

contract HorizonPhaseTwoListing is AaveV3Payload {
  constructor(address configEngine) AaveV3Payload(IEngine(configEngine)) {}

  function eModeCategoriesUpdates()
    public
    pure
    override
    returns (IEngine.EModeCategoryUpdate[] memory)
  {
    IEngine.EModeCategoryUpdate[] memory eModeCategories = new IEngine.EModeCategoryUpdate[](1);

    // VBILL GHO
    eModeCategories[0] = IEngine.EModeCategoryUpdate({
      eModeCategory: 1, // overwrite previous empty eMode category
      ltv: 84_00,
      liqThreshold: 89_00,
      liqBonus: 3_00,
      label: 'VBILL GHO'
    });

    return eModeCategories;
  }

  function newListingsCustom()
    public
    view
    override
    returns (IEngine.ListingWithCustomImpl[] memory)
  {
    IEngine.ListingWithCustomImpl[] memory listingsCustom = new IEngine.ListingWithCustomImpl[](1);

    listingsCustom[0] = IEngine.ListingWithCustomImpl(
      IEngine.Listing({
        asset: AaveV3EthereumHorizonCustom.VBILL_UNDERLYING,
        assetSymbol: 'VBILL',
        priceFeed: AaveV3EthereumHorizonCustom.VBILL_PRICE_FEED,
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
        ltv: 83_00,
        liqThreshold: 88_00,
        liqBonus: 3_00,
        reserveFactor: EngineFlags.KEEP_CURRENT,
        supplyCap: 15_000_000,
        borrowCap: 0,
        debtCeiling: 0,
        liqProtocolFee: 0
      }),
      IEngine.TokenImplementations({
        aToken: AaveV3EthereumHorizonCustom.RWA_ATOKEN_IMPL,
        vToken: AaveV3EthereumHorizonCustom.VARIABLE_DEBT_TOKEN_IMPL
      })
    );

    return listingsCustom;
  }

  function assetsEModeUpdates() public view override returns (IEngine.AssetEModeUpdate[] memory) {
    IEngine.AssetEModeUpdate[] memory assetsEMode = new IEngine.AssetEModeUpdate[](2);

    uint256 index = 0;

    // Overwrite empty eMode category 1
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: AaveV3EthereumHorizonCustom.VBILL_UNDERLYING,
      eModeCategory: 1,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: AaveV3EthereumHorizonCustom.GHO_UNDERLYING,
      eModeCategory: 1,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.ENABLED
    });

    assert(index == assetsEMode.length);

    return assetsEMode;
  }

  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Horizon RWA', networkAbbreviation: 'HorRwa'});
  }
}

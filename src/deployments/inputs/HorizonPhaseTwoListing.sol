// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IAaveV3ConfigEngine as IEngine} from '../../contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from '../../contracts/extensions/v3-config-engine/EngineFlags.sol';
import {AaveV3Payload} from '../../contracts/extensions/v3-config-engine/AaveV3Payload.sol';

import {AaveV3HorizonEthereum} from '../contracts/utilities/AaveV3HorizonEthereum.sol';

contract HorizonPhaseTwoListing is AaveV3Payload {
  address public constant GHO_ADDRESS = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

  address public constant VBILL_ADDRESS = 0x2255718832bC9fD3bE1CaF75084F4803DA14FF01;
  address public constant VBILL_PRICE_FEED = 0x5ed77a9D9b7cc80E9d0D7711024AF38C2643C1c4;

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
      eModeCategory: 1, // overwrite previous category
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
        asset: VBILL_ADDRESS,
        assetSymbol: 'VBILL',
        priceFeed: VBILL_PRICE_FEED,
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
        aToken: AaveV3HorizonEthereum.RWA_ATOKEN_IMPLEMENTATION,
        vToken: AaveV3HorizonEthereum.VARIABLE_DEBT_TOKEN_IMPLEMENTATION
      })
    );

    return listingsCustom;
  }

  function assetsEModeUpdates() public view override returns (IEngine.AssetEModeUpdate[] memory) {
    IEngine.AssetEModeUpdate[] memory assetsEMode = new IEngine.AssetEModeUpdate[](2);

    uint256 index = 0;

    // USTB GHO
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: VBILL_ADDRESS,
      eModeCategory: 1,
      collateral: EngineFlags.ENABLED,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: GHO_ADDRESS,
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

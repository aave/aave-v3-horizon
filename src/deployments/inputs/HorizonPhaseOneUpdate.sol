// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IAaveV3ConfigEngine as IEngine} from '../../contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from '../../contracts/extensions/v3-config-engine/EngineFlags.sol';
import {AaveV3Payload} from '../../contracts/extensions/v3-config-engine/AaveV3Payload.sol';

contract HorizonPhaseOneUpdate is AaveV3Payload {
  address public immutable GHO_ADDRESS;
  address public immutable USDC_ADDRESS;
  address public immutable RLUSD_ADDRESS;
  address public immutable USTB_ADDRESS;
  address public immutable USCC_ADDRESS;
  address public immutable USYC_ADDRESS;
  address public immutable JTRSY_ADDRESS;
  address public immutable JAAA_ADDRESS;

  constructor(address configEngine) AaveV3Payload(IEngine(configEngine)) {
    GHO_ADDRESS = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    RLUSD_ADDRESS = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
    USTB_ADDRESS = 0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e;
    USCC_ADDRESS = 0x14d60E7FDC0D71d8611742720E4C50E7a974020c;
    USYC_ADDRESS = 0x136471a34f6ef19fE571EFFC1CA711fdb8E49f2b;
    JTRSY_ADDRESS = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    JAAA_ADDRESS = 0x5a0F93D040De44e78F251b03c43be9CF317Dcf64;
  }

  function capsUpdates() public view override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory caps = new IEngine.CapsUpdate[](8);

    caps[0] = IEngine.CapsUpdate({
      asset: USTB_ADDRESS,
      supplyCap: 1_430_000,
      borrowCap: EngineFlags.KEEP_CURRENT
    });

    caps[1] = IEngine.CapsUpdate({
      asset: USCC_ADDRESS,
      supplyCap: 470_000,
      borrowCap: EngineFlags.KEEP_CURRENT
    });

    caps[2] = IEngine.CapsUpdate({
      asset: USYC_ADDRESS,
      supplyCap: 8_520_000,
      borrowCap: EngineFlags.KEEP_CURRENT
    });

    caps[3] = IEngine.CapsUpdate({
      asset: JTRSY_ADDRESS,
      supplyCap: 7_300_000,
      borrowCap: EngineFlags.KEEP_CURRENT
    });

    caps[4] = IEngine.CapsUpdate({
      asset: JAAA_ADDRESS,
      supplyCap: 8_230_000,
      borrowCap: EngineFlags.KEEP_CURRENT
    });

    caps[5] = IEngine.CapsUpdate({asset: GHO_ADDRESS, supplyCap: 1_000_000, borrowCap: 900_000});

    caps[6] = IEngine.CapsUpdate({
      asset: RLUSD_ADDRESS,
      supplyCap: 15_000_000,
      borrowCap: 13_500_000
    });

    caps[7] = IEngine.CapsUpdate({
      asset: USDC_ADDRESS,
      supplyCap: 15_000_000,
      borrowCap: 13_500_000
    });

    return caps;
  }

  function collateralsUpdates() public view override returns (IEngine.CollateralUpdate[] memory) {
    IEngine.CollateralUpdate[] memory collaterals = new IEngine.CollateralUpdate[](5);

    collaterals[0] = IEngine.CollateralUpdate({
      asset: USTB_ADDRESS,
      ltv: 83_00,
      liqThreshold: 88_00,
      liqBonus: 3_00,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    collaterals[1] = IEngine.CollateralUpdate({
      asset: USCC_ADDRESS,
      ltv: 72_00,
      liqThreshold: 79_00,
      liqBonus: 7_50,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    collaterals[2] = IEngine.CollateralUpdate({
      asset: USYC_ADDRESS,
      ltv: 85_00,
      liqThreshold: 89_00,
      liqBonus: 3_10,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    collaterals[3] = IEngine.CollateralUpdate({
      asset: JTRSY_ADDRESS,
      ltv: 77_00,
      liqThreshold: 83_00,
      liqBonus: 4_50,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    collaterals[4] = IEngine.CollateralUpdate({
      asset: JAAA_ADDRESS,
      ltv: 71_00,
      liqThreshold: 78_00,
      liqBonus: 9_00,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    return collaterals;
  }

  function eModeCategoriesUpdates()
    public
    pure
    override
    returns (IEngine.EModeCategoryUpdate[] memory)
  {
    IEngine.EModeCategoryUpdate[] memory eModeCategories = new IEngine.EModeCategoryUpdate[](5);

    eModeCategories[0] = IEngine.EModeCategoryUpdate({
      eModeCategory: 1,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      label: ''
    });

    eModeCategories[1] = IEngine.EModeCategoryUpdate({
      eModeCategory: 3,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      label: ''
    });

    eModeCategories[2] = IEngine.EModeCategoryUpdate({
      eModeCategory: 5,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      label: ''
    });

    eModeCategories[3] = IEngine.EModeCategoryUpdate({
      eModeCategory: 7,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      label: ''
    });

    eModeCategories[4] = IEngine.EModeCategoryUpdate({
      eModeCategory: 9,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      label: ''
    });

    return eModeCategories;
  }

  function assetsEModeUpdates() public view override returns (IEngine.AssetEModeUpdate[] memory) {
    IEngine.AssetEModeUpdate[] memory assetsEMode = new IEngine.AssetEModeUpdate[](20);

    uint256 index = 0;

    // USTB Stablecoins
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USTB_ADDRESS,
      eModeCategory: 1,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.KEEP_CURRENT
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USDC_ADDRESS,
      eModeCategory: 1,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: RLUSD_ADDRESS,
      eModeCategory: 1,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: GHO_ADDRESS,
      eModeCategory: 1,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });

    // USCC Stablecoins
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USCC_ADDRESS,
      eModeCategory: 3,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.KEEP_CURRENT
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USDC_ADDRESS,
      eModeCategory: 3,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: RLUSD_ADDRESS,
      eModeCategory: 3,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: GHO_ADDRESS,
      eModeCategory: 3,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });

    // USYC Stablecoins
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USYC_ADDRESS,
      eModeCategory: 5,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.KEEP_CURRENT
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USDC_ADDRESS,
      eModeCategory: 5,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: RLUSD_ADDRESS,
      eModeCategory: 5,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: GHO_ADDRESS,
      eModeCategory: 5,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });

    // JTRSY Stablecoins
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: JTRSY_ADDRESS,
      eModeCategory: 7,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.KEEP_CURRENT
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USDC_ADDRESS,
      eModeCategory: 7,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: RLUSD_ADDRESS,
      eModeCategory: 7,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: GHO_ADDRESS,
      eModeCategory: 7,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });

    // JAAA Stablecoins
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: JAAA_ADDRESS,
      eModeCategory: 9,
      collateral: EngineFlags.DISABLED,
      borrowable: EngineFlags.KEEP_CURRENT
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: USDC_ADDRESS,
      eModeCategory: 9,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: RLUSD_ADDRESS,
      eModeCategory: 9,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });
    assetsEMode[index++] = IEngine.AssetEModeUpdate({
      asset: GHO_ADDRESS,
      eModeCategory: 9,
      collateral: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.DISABLED
    });

    require(index == assetsEMode.length, 'length mismatch');

    return assetsEMode;
  }

  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Horizon RWA', networkAbbreviation: 'HorRwa'});
  }
}

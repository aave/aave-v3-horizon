// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IAaveV3ConfigEngine as IEngine} from '../../contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from '../../contracts/extensions/v3-config-engine/EngineFlags.sol';
import {AaveV3Payload} from '../../contracts/extensions/v3-config-engine/AaveV3Payload.sol';

contract USCCCapsUpdate is AaveV3Payload {
  address public constant USCC_ADDRESS = 0x14d60E7FDC0D71d8611742720E4C50E7a974020c;

  constructor(address configEngine) AaveV3Payload(IEngine(configEngine)) {}

  function capsUpdates() public pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory caps = new IEngine.CapsUpdate[](1);

    caps[0] = IEngine.CapsUpdate({
      asset: USCC_ADDRESS,
      supplyCap: 1_920_000,
      borrowCap: EngineFlags.KEEP_CURRENT
    });

    return caps;
  }

  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Horizon RWA', networkAbbreviation: 'HorRwa'});
  }
}

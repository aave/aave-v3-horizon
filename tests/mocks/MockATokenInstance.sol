// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IPool} from '../../src/contracts/interfaces/IPool.sol';
import {ATokenInstance} from '../../src/contracts/instances/ATokenInstance.sol';

contract MockATokenInstance is ATokenInstance {
  uint256 internal immutable MOCK_REVISION;

  constructor(IPool pool, uint256 mockRevision) ATokenInstance(pool) {
    MOCK_REVISION = mockRevision;
  }

  function getMockRevision() public view returns (uint256) {
    return MOCK_REVISION;
  }

  function getRevision() internal pure virtual override returns (uint256) {
    return _cast(getMockRevision)();
  }

  function _cast(
    function() view returns (uint256) f
  ) internal pure returns (function() pure returns (uint256) f2) {
    assembly {
      f2 := f
    }
  }
}

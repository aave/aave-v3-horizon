// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IPool} from '../../src/contracts/interfaces/IPool.sol';
import {RwaATokenInstance} from '../../src/contracts/instances/RwaATokenInstance.sol';
import {Test} from 'forge-std/Test.sol';

contract MockRwaATokenInstance is RwaATokenInstance, Test {
  constructor(IPool pool, uint256 mockRevision) RwaATokenInstance(pool) {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('ATOKEN_REVISION()'),
      abi.encode(mockRevision)
    );
  }

  function getMockRevision() internal view returns (uint256) {
    return this.ATOKEN_REVISION();
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

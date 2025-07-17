// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MockAggregatorMetadata} from '../../../src/contracts/mocks/oracle/CLAggregators/MockAggregatorMetadata.sol';
import {ScaledPriceAdapter} from '../../../src/contracts/extensions/price-adapters/ScaledPriceAdapter.sol';
import {TestnetProcedures} from '../../utils/TestnetProcedures.sol';

contract ScaledPriceAdapterTests is TestnetProcedures {
  function test_adapter_less_than_base() public {
    test_fuzz_adapter({sourceDecimals: 2, price: 1e2});
    test_fuzz_adapter({sourceDecimals: 6, price: 32.323e6});
  }

  function test_adapter_greater_than_base() public {
    test_fuzz_adapter({sourceDecimals: 12, price: 1e12});
  }

  function test_adapter_equal_to_base() public {
    test_fuzz_adapter({sourceDecimals: 8, price: 1e8});
  }

  function test_fuzz_adapter(uint256 sourceDecimals, int256 price) public {
    sourceDecimals = bound(sourceDecimals, 1, 36);
    price = bound(price, 0, int256(10 ** (10 + sourceDecimals)));
    address source = address(new MockAggregatorMetadata(price, uint8(sourceDecimals)));
    ScaledPriceAdapter adapter = new ScaledPriceAdapter(source);

    (bool scaleUp, uint256 scale) = adapter.scale();
    assertEq(adapter.decimals(), 8);
    assertEq(scaleUp, adapter.decimals() > sourceDecimals);
    assertEq(
      scale,
      10 ** (scaleUp ? adapter.decimals() - sourceDecimals : sourceDecimals - adapter.decimals())
    );
    assertEq(adapter.latestAnswer(), scaleUp ? price * int256(scale) : price / int256(scale));
    assertEq(adapter.source(), source);
  }

  function test_adapter_invalid_source_feed() public {
    vm.expectRevert();
    new ScaledPriceAdapter(makeAddr('invalid'));
  }
}

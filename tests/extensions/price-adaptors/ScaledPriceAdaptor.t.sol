// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MockAggregatorMetadata} from '../../../src/contracts/mocks/oracle/CLAggregators/MockAggregatorMetadata.sol';
import {ScaledPriceAdaptor} from '../../../src/contracts/extensions/price-adaptors/ScaledPriceAdaptor.sol';
import {TestnetProcedures} from '../../utils/TestnetProcedures.sol';

contract ScaledPriceAdaptorTests is TestnetProcedures {
  function test_adaptor_less_than_base() public {
    test_fuzz_adaptor({sourceDecimals: 2, price: 1e2});
    test_fuzz_adaptor({sourceDecimals: 6, price: 32.323e6});
  }

  function test_adaptor_greater_than_base() public {
    test_fuzz_adaptor({sourceDecimals: 12, price: 1e12});
  }

  function test_adaptor_equal_to_base() public {
    test_fuzz_adaptor({sourceDecimals: 8, price: 1e8});
  }

  function test_fuzz_adaptor(uint256 sourceDecimals, int256 price) public {
    sourceDecimals = bound(sourceDecimals, 1, 36);
    price = bound(price, 1, int256(10 ** sourceDecimals));
    address source = address(new MockAggregatorMetadata(price, uint8(sourceDecimals)));
    ScaledPriceAdaptor adaptor = new ScaledPriceAdaptor(source);

    (bool scaleUp, uint256 scale) = adaptor.scale();
    assertEq(adaptor.decimals(), 8);
    assertEq(scaleUp, adaptor.decimals() > sourceDecimals);
    assertEq(
      scale,
      10 ** (scaleUp ? adaptor.decimals() - sourceDecimals : sourceDecimals - adaptor.decimals())
    );
    assertEq(adaptor.latestAnswer(), scaleUp ? price * int256(scale) : price / int256(scale));
    assertEq(adaptor.source(), source);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './MarketInput.sol';

contract VTestnetInput is MarketInput {
  address public constant DEPLOYER = 0x93A8876215A690b4EADFAb0efDBdB18BA1B450d3;

  function _getMarketInput(
    address
  )
    internal
    pure
    override
    returns (
      Roles memory roles,
      MarketConfig memory config,
      DeployFlags memory flags,
      MarketReport memory deployedContracts
    )
  {
    roles.marketOwner = DEPLOYER;
    roles.emergencyAdmin = DEPLOYER;
    roles.poolAdmin = DEPLOYER;
    roles.rwaATokenManagerAdmin = DEPLOYER;

    config.marketId = 'Aave V3 Horizon Market';
    config.providerId = 51;
    config.oracleDecimals = 8;
    config.flashLoanPremiumTotal = 0.0005e4;
    config.flashLoanPremiumToProtocol = 0.0004e4;
    config.wrappedNativeToken = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    config
      .marketReferenceCurrencyPriceInUsdProxyAggregator = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // eth-usd chainlink price feed
    config.networkBaseTokenPriceInUsdProxyAggregator = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // eth-usd chainlink price feed

    return (roles, config, flags, deployedContracts);
  }
}

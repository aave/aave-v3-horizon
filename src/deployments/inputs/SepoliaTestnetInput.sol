// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './MarketInput.sol';

contract SepoliaTestnetInput is MarketInput {
  address public constant DEPLOYER = 0x4646bce888521E63c3D71D3EE66Ee5bd1cad888C;

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
    config.wrappedNativeToken = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; // WETH on Sepolia

    config
      .marketReferenceCurrencyPriceInUsdProxyAggregator = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // eth-usd chainlink price feed
    config.networkBaseTokenPriceInUsdProxyAggregator = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // eth-usd chainlink price feed

    return (roles, config, flags, deployedContracts);
  }
}

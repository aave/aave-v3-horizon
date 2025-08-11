// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './MarketInput.sol';

contract HorizonInput is MarketInput {
  address public constant ETH_USD_PRICE_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // chainlink price feed
  address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant AAVE_DAO_EXECUTOR = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;
  address public constant AAVE_DAO_COLLECTOR = 0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c;
  address public constant OPERATIONAL_MULTISIG = 0xE6ec1f0Ae6Cd023bd0a9B4d0253BDC755103253c;
  address public constant EMERGENCY_MULTISIG = 0x13B57382c36BAB566E75C72303622AF29E27e1d3;
  address public constant PHASE_ONE_LISTING_EXECUTOR = 0x09e8E1408a68778CEDdC1938729Ea126710E7Dda;

  bytes32 public constant POOL_ADMIN_ROLE = keccak256('POOL_ADMIN');
  bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256('EMERGENCY_ADMIN');
  bytes32 public constant RISK_ADMIN_ROLE = keccak256('RISK_ADMIN');
  bytes32 public constant ASSET_LISTING_ADMIN_ROLE = keccak256('ASSET_LISTING_ADMIN');

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
    bytes[] memory additionalRoles = new bytes[](6);
    additionalRoles[0] = abi.encode(EMERGENCY_ADMIN_ROLE, PHASE_ONE_LISTING_EXECUTOR);
    additionalRoles[1] = abi.encode(ASSET_LISTING_ADMIN_ROLE, PHASE_ONE_LISTING_EXECUTOR);
    additionalRoles[2] = abi.encode(RISK_ADMIN_ROLE, PHASE_ONE_LISTING_EXECUTOR);
    additionalRoles[3] = abi.encode(POOL_ADMIN_ROLE, EMERGENCY_MULTISIG);
    additionalRoles[4] = abi.encode(EMERGENCY_ADMIN_ROLE, EMERGENCY_MULTISIG);
    additionalRoles[5] = abi.encode(RISK_ADMIN_ROLE, OPERATIONAL_MULTISIG);
    roles = Roles({
      marketOwner: AAVE_DAO_EXECUTOR,
      emergencyAdmin: AAVE_DAO_EXECUTOR,
      poolAdmin: AAVE_DAO_EXECUTOR,
      rwaATokenManagerAdmin: EMERGENCY_MULTISIG,
      additionalRoles: additionalRoles
    });

    config = MarketConfig({
      networkBaseTokenPriceInUsdProxyAggregator: ETH_USD_PRICE_FEED,
      marketReferenceCurrencyPriceInUsdProxyAggregator: ETH_USD_PRICE_FEED,
      marketId: 'Horizon RWA Market',
      oracleDecimals: 8,
      paraswapAugustusRegistry: address(0),
      l2SequencerUptimeFeed: address(0),
      l2PriceOracleSentinelGracePeriod: 0,
      providerId: 1,
      salt: bytes32(0),
      wrappedNativeToken: WETH_ADDRESS,
      flashLoanPremiumTotal: 5,
      flashLoanPremiumToProtocol: 100_00,
      incentivesProxy: address(0),
      treasury: address(0),
      treasuryPartner: AAVE_DAO_COLLECTOR, // TreasuryCollector
      treasurySplitPercent: 50_00
    });

    return (roles, config, flags, deployedContracts);
  }
}

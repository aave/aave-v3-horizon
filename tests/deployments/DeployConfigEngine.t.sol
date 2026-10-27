// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {VmSafe} from 'forge-std/Vm.sol';
import {DeployConfigEngine} from '../../scripts/misc/DeployConfigEngine.sol';
import {AaveV3ConfigEngine} from '../../src/contracts/extensions/v3-config-engine/AaveV3ConfigEngine.sol';
import {IAaveV3ConfigEngine as IEngine} from '../../src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {AaveV3Payload} from '../../src/contracts/extensions/v3-config-engine/AaveV3Payload.sol';
import {EngineFlags} from '../../src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {ATokenInstance} from '../../src/contracts/instances/ATokenInstance.sol';
import {RwaATokenInstance} from '../../src/contracts/instances/RwaATokenInstance.sol';
import {DataTypes} from '../../src/contracts/protocol/libraries/types/DataTypes.sol';
import {IPool} from '../../src/contracts/interfaces/IPool.sol';
import {IPoolAddressesProvider} from '../../src/contracts/interfaces/IPoolAddressesProvider.sol';
import {IACLManager} from '../../src/contracts/interfaces/IACLManager.sol';
import {IAaveOracle} from '../../src/contracts/interfaces/IAaveOracle.sol';
import {TestnetERC20} from '../../src/contracts/mocks/testnet-helpers/TestnetERC20.sol';
import {MockAggregator} from '../../src/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';
import {ProxyHelpers} from '../utils/ProxyHelpers.sol';

contract ConfigEngineTestListing is AaveV3Payload {
  address public immutable ASSET;
  address public immutable RWA_ASSET;
  address public immutable RWA_ATOKEN_IMPL;
  address public immutable PRICE_FEED;

  constructor(
    address configEngine,
    address asset,
    address rwaAsset,
    address rwaATokenImpl,
    address priceFeed
  ) AaveV3Payload(IEngine(configEngine)) {
    ASSET = asset;
    RWA_ASSET = rwaAsset;
    RWA_ATOKEN_IMPL = rwaATokenImpl;
    PRICE_FEED = priceFeed;
  }

  function newListings() public view override returns (IEngine.Listing[] memory) {
    IEngine.Listing[] memory listings = new IEngine.Listing[](1);
    listings[0] = _listing(ASSET, 'TEST');
    return listings;
  }

  function newListingsCustom()
    public
    view
    override
    returns (IEngine.ListingWithCustomImpl[] memory)
  {
    IEngine.ListingWithCustomImpl[] memory listingsCustom = new IEngine.ListingWithCustomImpl[](1);
    listingsCustom[0] = IEngine.ListingWithCustomImpl({
      base: _listing(RWA_ASSET, 'RWATEST'),
      implementations: IEngine.TokenImplementations({
        aToken: RWA_ATOKEN_IMPL,
        vToken: CONFIG_ENGINE.VTOKEN_IMPL()
      })
    });
    return listingsCustom;
  }

  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Horizon RWA', networkAbbreviation: 'HorRwa'});
  }

  function _listing(
    address asset,
    string memory assetSymbol
  ) internal view returns (IEngine.Listing memory) {
    return
      IEngine.Listing({
        asset: asset,
        assetSymbol: assetSymbol,
        priceFeed: PRICE_FEED,
        rateStrategyParams: IEngine.InterestRateInputData({
          optimalUsageRatio: 90_00,
          baseVariableBorrowRate: 0,
          variableRateSlope1: 4_00,
          variableRateSlope2: 60_00
        }),
        enabledToBorrow: EngineFlags.DISABLED,
        borrowableInIsolation: EngineFlags.DISABLED,
        withSiloedBorrowing: EngineFlags.DISABLED,
        flashloanable: EngineFlags.DISABLED,
        ltv: 50_00,
        liqThreshold: 60_00,
        liqBonus: 5_00,
        reserveFactor: 10_00,
        supplyCap: 1_000,
        borrowCap: 0,
        debtCeiling: 0,
        liqProtocolFee: 0
      });
  }
}

/// forge-config: default.evm_version = "cancun"
contract DeployConfigEngineTest is Test {
  // AaveV3EthereumHorizon address book, commit e796b7d71f37a3e7f78a3b2c0b47ee8d56dcff92
  address internal constant POOL_ADDRESSES_PROVIDER = 0x5D39E06b825C1F2B80bf2756a73e28eFAA128ba0;
  address internal constant POOL = 0xAe05Cd22df81871bc7cC2a04BeCfb516bFe332C8;
  address internal constant POOL_CONFIGURATOR = 0x83Cb1B4af26EEf6463aC20AFbAC9c0e2E017202F;
  address internal constant ACL_MANAGER = 0xEFD5df7b87d2dCe6DD454b4240b3e0A4db562321;
  address internal constant ACL_ADMIN = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;
  address internal constant ORACLE = 0x985BcfAB7e0f4EF2606CC5b64FC1A16311880442;
  address internal constant REWARDS_CONTROLLER = 0x1D5D386a90CEA8AcEa9fa75389e97CF5F1AE21D3;
  address internal constant COLLECTOR = 0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c;
  address internal constant ATOKEN_IMPL = 0x9EB507147b99D3Cde32A53Bd5cd12bDEEaC26E5c;
  address internal constant VTOKEN_IMPL = 0x15F03E5dE87c12cb2e2b8e5d6ECEf0a9E21ab269;

  address internal constant RWA_ATOKEN_IMPL = 0x5148d810B1DaE509d68f9d9219AD1d004EA32545;
  address internal constant DEFAULT_INTEREST_RATE_STRATEGY =
    0x87593272C06f4FC49EC2942eBda0972d2F1Ab521;

  // https://etherscan.io/address/0x30dA3a613c5b492BB4277Aa2a5D81f4759Ba83Af
  AaveV3ConfigEngine internal constant DEPRECATED_CONFIG_ENGINE =
    AaveV3ConfigEngine(0x30dA3a613c5b492BB4277Aa2a5D81f4759Ba83Af);
  address internal constant LISTING_ENGINE = 0x4e48debC1aDE8011A185Db7792299432d19AA017;
  address internal constant EMODE_ENGINE = 0xC45E60E50b0dFbb4e3bb768EEfa65245E6a3cB3b;
  address internal constant BORROW_ENGINE = 0x298ee3e454275d31Bdb3A2f34198B0638789586b;
  address internal constant COLLATERAL_ENGINE = 0x11C0FA8EcD3A4324c84e82765595c14E11B72E92;
  address internal constant PRICE_FEED_ENGINE = 0xEC662DACfbE623f74f580C92830Fab75B66f4ffc;
  address internal constant RATE_ENGINE = 0x2FB325d2551c6AAC0E2dA33F5cba1a84590676a7;
  address internal constant CAPS_ENGINE = 0xDC9C6d5e0eaEE649d25B81BcdB8f02d5f65B507D;

  AaveV3ConfigEngine internal configEngine;

  function setUp() public {
    // coverage disables the optimizer, so the sub-engine CREATE2 addresses don't match the deployed ones
    if (vm.isContext(VmSafe.ForgeContext.Coverage)) vm.skip(true);
    vm.createSelectFork('mainnet', 26250907);
    configEngine = AaveV3ConfigEngine(new DeployConfigEngine().run());
  }

  function test_engineConstants() public view {
    assertEq(address(configEngine.POOL()), POOL);
    assertEq(address(configEngine.POOL_CONFIGURATOR()), POOL_CONFIGURATOR);
    assertEq(address(configEngine.ORACLE()), ORACLE);
    assertEq(configEngine.REWARDS_CONTROLLER(), REWARDS_CONTROLLER);
    assertEq(configEngine.COLLECTOR(), COLLECTOR);
    assertEq(configEngine.DEFAULT_INTEREST_RATE_STRATEGY(), DEFAULT_INTEREST_RATE_STRATEGY);
    assertEq(configEngine.ATOKEN_IMPL(), ATOKEN_IMPL);
    assertEq(configEngine.VTOKEN_IMPL(), VTOKEN_IMPL);
  }

  function test_engineLibraries() public view {
    assertEq(configEngine.LISTING_ENGINE(), LISTING_ENGINE);
    assertEq(configEngine.EMODE_ENGINE(), EMODE_ENGINE);
    assertEq(configEngine.BORROW_ENGINE(), BORROW_ENGINE);
    assertEq(configEngine.COLLATERAL_ENGINE(), COLLATERAL_ENGINE);
    assertEq(configEngine.PRICE_FEED_ENGINE(), PRICE_FEED_ENGINE);
    assertEq(configEngine.RATE_ENGINE(), RATE_ENGINE);
    assertEq(configEngine.CAPS_ENGINE(), CAPS_ENGINE);

    assertEq(configEngine.LISTING_ENGINE(), DEPRECATED_CONFIG_ENGINE.LISTING_ENGINE());
    assertEq(configEngine.EMODE_ENGINE(), DEPRECATED_CONFIG_ENGINE.EMODE_ENGINE());
    assertEq(configEngine.BORROW_ENGINE(), DEPRECATED_CONFIG_ENGINE.BORROW_ENGINE());
    assertEq(configEngine.COLLATERAL_ENGINE(), DEPRECATED_CONFIG_ENGINE.COLLATERAL_ENGINE());
    assertEq(configEngine.PRICE_FEED_ENGINE(), DEPRECATED_CONFIG_ENGINE.PRICE_FEED_ENGINE());
    assertEq(configEngine.RATE_ENGINE(), DEPRECATED_CONFIG_ENGINE.RATE_ENGINE());
    assertEq(configEngine.CAPS_ENGINE(), DEPRECATED_CONFIG_ENGINE.CAPS_ENGINE());
  }

  function test_expectedAddresses_matchOnChain() public view {
    IPoolAddressesProvider provider = IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
    assertEq(provider.getPool(), POOL);
    assertEq(provider.getPoolConfigurator(), POOL_CONFIGURATOR);
    assertEq(provider.getPriceOracle(), ORACLE);
    assertEq(provider.getACLManager(), ACL_MANAGER);
    assertEq(provider.getACLAdmin(), ACL_ADMIN);

    assertEq(ATokenInstance(ATOKEN_IMPL).ATOKEN_REVISION(), 3);
    assertEq(address(ATokenInstance(ATOKEN_IMPL).POOL()), POOL);
    assertEq(RwaATokenInstance(RWA_ATOKEN_IMPL).ATOKEN_REVISION(), 3);
    assertEq(address(RwaATokenInstance(RWA_ATOKEN_IMPL).POOL()), POOL);

    address[] memory reserves = IPool(POOL).getReservesList();
    for (uint256 i = 0; i < reserves.length; ++i) {
      DataTypes.ReserveDataLegacy memory reserveData = IPool(POOL).getReserveData(reserves[i]);
      assertEq(reserveData.interestRateStrategyAddress, DEFAULT_INTEREST_RATE_STRATEGY);
      assertEq(
        ProxyHelpers.getInitializableAdminUpgradeabilityProxyImplementation(
          vm,
          reserveData.variableDebtTokenAddress
        ),
        VTOKEN_IMPL
      );
      assertEq(
        address(ATokenInstance(reserveData.aTokenAddress).getIncentivesController()),
        REWARDS_CONTROLLER
      );
    }
  }

  function test_listing() public {
    address priceFeed = address(new MockAggregator(1e8));
    address asset = address(new TestnetERC20('Test', 'TEST', 18, address(this)));
    address rwaAsset = address(new TestnetERC20('RWA Test', 'RWATEST', 6, address(this)));
    ConfigEngineTestListing payload = new ConfigEngineTestListing({
      configEngine: address(configEngine),
      asset: asset,
      rwaAsset: rwaAsset,
      rwaATokenImpl: RWA_ATOKEN_IMPL,
      priceFeed: priceFeed
    });

    vm.prank(ACL_ADMIN);
    IACLManager(ACL_MANAGER).addPoolAdmin(address(payload));
    payload.execute();

    _assertListing({asset: asset, aTokenImpl: ATOKEN_IMPL, priceFeed: priceFeed});
    _assertListing({asset: rwaAsset, aTokenImpl: RWA_ATOKEN_IMPL, priceFeed: priceFeed});
  }

  function test_run_revertsWith_subEngineNotDeployed() public {
    vm.etch(LISTING_ENGINE, '');
    DeployConfigEngine deployConfigEngine = new DeployConfigEngine();

    vm.expectRevert('ENGINE_NOT_DEPLOYED');
    deployConfigEngine.run();
  }

  function _assertListing(address asset, address aTokenImpl, address priceFeed) internal view {
    DataTypes.ReserveDataLegacy memory reserveData = IPool(POOL).getReserveData(asset);
    ATokenInstance aToken = ATokenInstance(reserveData.aTokenAddress);

    assertEq(aToken.RESERVE_TREASURY_ADDRESS(), COLLECTOR);
    assertEq(address(aToken.getIncentivesController()), REWARDS_CONTROLLER);
    assertEq(
      ProxyHelpers.getInitializableAdminUpgradeabilityProxyImplementation(vm, address(aToken)),
      aTokenImpl
    );
    assertEq(
      ProxyHelpers.getInitializableAdminUpgradeabilityProxyImplementation(
        vm,
        reserveData.variableDebtTokenAddress
      ),
      VTOKEN_IMPL
    );
    assertEq(reserveData.interestRateStrategyAddress, DEFAULT_INTEREST_RATE_STRATEGY);
    assertEq(IAaveOracle(ORACLE).getSourceOfAsset(asset), priceFeed);
  }
}

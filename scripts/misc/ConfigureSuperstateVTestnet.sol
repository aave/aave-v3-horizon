// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import '../../src/contracts/extensions/v3-config-engine/AaveV3Payload.sol';
import {ACLManager} from '../../src/contracts/protocol/configuration/ACLManager.sol';
import {IPool} from '../../src/contracts/interfaces/IPool.sol';
import {IERC20} from '../../src/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {AaveProtocolDataProvider} from '../../src/contracts/helpers/AaveProtocolDataProvider.sol';
import {console2} from 'forge-std/console2.sol';

contract VTestnetListing is AaveV3Payload {
    bytes32 public constant POOL_ADMIN_ROLE_ID =
        0x12ad05bde78c5ab75238ce885307f96ecd482bb402ef831f99e7018a0f169b7b;

    address public constant ACL_MANAGER = 0x7Ec3e2a60e8f24FA6A10387318b6d017711F6E34;
    address public constant VARIABLE_DEBT_TOKEN_IMPLEMENTATION = 0xeA741B4B5d9CA091F70C5C6B93d3ee3Ac79fd36d;
    address public constant ATOKEN_IMPL = 0x8D4c23FAB1B0eB6852ceb3fFF7306ABDc2EF784B;
    address public constant RWA_ATOKEN_IMPL = 0xb912925542214a008d75a8514a223aa5E18adB9c;

    address public constant BUIDL = 0x7712c34205737192402172409a8F7ccef8aA2AEc;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public constant BUIDL_PRICE_FEED = 0xb9BD795BB71012c0F3cd1D9c9A4c686F2d3524A4;
    address public constant USDC_PRICE_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    constructor(IEngine engine) AaveV3Payload(engine) {}

    function newListingsCustom()
    public
    view
    override
    returns (IEngine.ListingWithCustomImpl[] memory)
  {
    IEngine.ListingWithCustomImpl[] memory listingsCustom = new IEngine.ListingWithCustomImpl[](2);

    IEngine.InterestRateInputData memory rateParams = IEngine.InterestRateInputData({
      optimalUsageRatio: 45_00,
      baseVariableBorrowRate: 0,
      variableRateSlope1: 4_00,
      variableRateSlope2: 60_00
    });

    listingsCustom[0] = IEngine.ListingWithCustomImpl(
      IEngine.Listing({
        asset: USDC,
        assetSymbol: 'USDC',
        priceFeed: USDC_PRICE_FEED,
        rateStrategyParams: rateParams,
        enabledToBorrow: EngineFlags.ENABLED,
        borrowableInIsolation: EngineFlags.DISABLED,
        withSiloedBorrowing: EngineFlags.DISABLED,
        flashloanable: EngineFlags.ENABLED,
        ltv: 0,
        liqThreshold:  0,
        liqBonus: 0,
        reserveFactor: EngineFlags.KEEP_CURRENT,
        supplyCap: 0,
        borrowCap: 0,
        debtCeiling: 0,
        liqProtocolFee: 0
      }),
      IEngine.TokenImplementations({
        aToken: ATOKEN_IMPL,
        vToken: VARIABLE_DEBT_TOKEN_IMPLEMENTATION
      })
    );

    listingsCustom[1] = IEngine.ListingWithCustomImpl(
      IEngine.Listing({
        asset: BUIDL,
        assetSymbol: 'BUIDL',
        priceFeed: BUIDL_PRICE_FEED,
        rateStrategyParams: rateParams,
        enabledToBorrow: EngineFlags.DISABLED,
        borrowableInIsolation: EngineFlags.DISABLED,
        withSiloedBorrowing: EngineFlags.DISABLED,
        flashloanable: EngineFlags.DISABLED,
        ltv: 82_50,
        liqThreshold: 86_00,
        liqBonus: 5_00,
        reserveFactor: 10_00,
        supplyCap: 0,
        borrowCap: 0,
        debtCeiling: 0,
        liqProtocolFee: 0
      }),
      IEngine.TokenImplementations({
        aToken: RWA_ATOKEN_IMPL,
        vToken: VARIABLE_DEBT_TOKEN_IMPLEMENTATION
      })
    );

    return listingsCustom;
  }

   function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'HorizonVTestnet', networkAbbreviation: 'hvt'});
  }

    function _postExecute() internal override {
        ACLManager(ACL_MANAGER).renounceRole(POOL_ADMIN_ROLE_ID, address(this));
    }

}

contract ConfigureVTestnet is Script {
    address public constant CONFIG_ENGINE = 0x0Ffe992faB9D51B14C296748F29A96DACA9B6476;
    address public constant POOL = 0xD6AE14f977d8Beb1051118C61cb8e00fA36fBa60;
    address public constant PROTOCOL_DATA_PROVIDER = 0x64aa873B3bA4FdD810e32a315A1070abFEA12b01;

    function run() external {
        vm.startBroadcast();
        VTestnetListing vTestnetListing = new VTestnetListing(IEngine(CONFIG_ENGINE));
        ACLManager(vTestnetListing.ACL_MANAGER()).addPoolAdmin(address(vTestnetListing));
        vTestnetListing.execute();
        vm.stopBroadcast();

        (address aBUIDL, , ) = AaveProtocolDataProvider(PROTOCOL_DATA_PROVIDER).getReserveTokensAddresses(vTestnetListing.BUIDL());
        console2.log(aBUIDL);
    }

    function fork_test() external {
        address buidl = 0x7712c34205737192402172409a8F7ccef8aA2AEc;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        vm.startPrank(0x93A8876215A690b4EADFAb0efDBdB18BA1B450d3);
        IERC20(buidl).approve(POOL, 10e6);
        IERC20(usdc).approve(POOL, 10e6);
        IPool(POOL).supply(buidl, 10e6, 0x93A8876215A690b4EADFAb0efDBdB18BA1B450d3, 0);
        IPool(POOL).supply(usdc, 10e6, 0x93A8876215A690b4EADFAb0efDBdB18BA1B450d3, 0);
        IPool(POOL).borrow(usdc, 5e6, 2, 0, 0x93A8876215A690b4EADFAb0efDBdB18BA1B450d3);
        vm.stopPrank();

        console2.log(IERC20(buidl).balanceOf(0x93A8876215A690b4EADFAb0efDBdB18BA1B450d3));
        console2.log(IERC20(usdc).balanceOf(0x93A8876215A690b4EADFAb0efDBdB18BA1B450d3));
    }
}
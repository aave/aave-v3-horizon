// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {TestnetProcedures} from '../utils/TestnetProcedures.sol';
import {IAToken, IERC20} from '../../src/contracts/interfaces/IAToken.sol';
import {EIP712SigUtils} from '../utils/EIP712SigUtils.sol';
import {IPool} from '../../src/contracts/interfaces/IPool.sol';
import {IERC20Detailed} from '../../src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';

/// forge-config: default.evm_version = "cancun"
contract PoolSupplyHorizonForkTests is TestnetProcedures {
  address internal constant POOL = 0xAe05Cd22df81871bc7cC2a04BeCfb516bFe332C8;
  address internal constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address internal constant USYC_ADDRESS = 0x136471a34f6ef19fE571EFFC1CA711fdb8E49f2b;
  address internal constant USTB_ADDRESS = 0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e;
  address internal constant USCC_ADDRESS = 0x14d60E7FDC0D71d8611742720E4C50E7a974020c;
  address internal constant JTRSY_ADDRESS = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
  address internal constant JAAA_ADDRESS = 0x5a0F93D040De44e78F251b03c43be9CF317Dcf64;

  address internal user;
  uint256 internal userPk;
  function setUp() public {
    vm.createSelectFork('mainnet');
    (user, userPk) = makeAddrAndKey('TEST_USER');

    deal(user, 100 ether);
    // USTB, USDCC
    whitelistSuperstateRwa(user);
    // JTRSY, JAAA
    whitelistCentrifugeRwa(user);
    // USYC
    whitelistUsycRwa(POOL);
    whitelistUsycRwa(user);
    whitelistUsycRwa(address(getAToken(USYC_ADDRESS)));
  }

  function test_supplyWithPermit_USCC() public {
    (, bytes memory versionData) = USCC_ADDRESS.call(abi.encodeWithSignature('VERSION()'));
    // custom version that can be read from VERSION()
    test_supplyWithPermit({
      asset: USCC_ADDRESS,
      name: bytes(IERC20Detailed(USCC_ADDRESS).name()),
      version: bytes(abi.decode(versionData, (string))),
      isRWA: true
    });
  }

  function test_supplyWithPermit_USTB() public {
    (, bytes memory versionData) = USTB_ADDRESS.call(abi.encodeWithSignature('VERSION()'));
    // custom version that can be read from VERSION()
    test_supplyWithPermit({
      asset: USTB_ADDRESS,
      name: bytes(IERC20Detailed(USTB_ADDRESS).name()),
      version: bytes(abi.decode(versionData, (string))),
      isRWA: true
    });
  }

  function test_supplyWithPermit_USYC() public {
    // custom version
    test_supplyWithPermit({
      asset: USYC_ADDRESS,
      name: bytes(IERC20Detailed(USYC_ADDRESS).name()),
      version: bytes('2'),
      isRWA: true
    });
  }

  function test_supplyWithPermit_JAAA() public {
    whitelistCentrifugeRwa(user);
    // custom name differs from token.name()
    test_supplyWithPermit({
      asset: JAAA_ADDRESS,
      name: bytes('Centrifuge'),
      version: bytes('1'),
      isRWA: true
    });
  }

  function test_supplyWithPermit_JTRSY() public {
    whitelistCentrifugeRwa(user);
    // custom name differs from token.name()
    test_supplyWithPermit({
      asset: JTRSY_ADDRESS,
      name: bytes('Centrifuge'),
      version: bytes('1'),
      isRWA: true
    });
  }

  function test_supplyWithPermit_USDC() public {
    (, bytes memory versionData) = USDC_ADDRESS.call(abi.encodeWithSignature('version()'));
    test_supplyWithPermit({
      asset: USDC_ADDRESS,
      name: bytes(IERC20Detailed(USDC_ADDRESS).name()),
      version: bytes(abi.decode(versionData, (string))),
      isRWA: false
    });
  }

  function test_supplyWithPermit(
    address asset,
    bytes memory name,
    bytes memory version,
    bool isRWA
  ) internal {
    uint256 supplyAmount = 100 * 10 ** IERC20Detailed(asset).decimals();
    deal(asset, user, supplyAmount);

    uint256 initialBalance = IERC20(asset).balanceOf(user);

    EIP712SigUtils.Permit memory permit = EIP712SigUtils.Permit({
      owner: user,
      spender: POOL,
      value: supplyAmount,
      nonce: 0,
      deadline: vm.getBlockTimestamp() + 1 days
    });
    bytes32 digest = EIP712SigUtils.getTypedDataHash(permit, name, version, asset);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

    // only set as collateral if RWA
    if (isRWA) {
      vm.expectEmit(POOL);
      emit IPool.ReserveUsedAsCollateralEnabled(asset, user);
    }
    vm.expectEmit(POOL);
    emit IPool.Supply(asset, user, user, supplyAmount, 0);

    vm.prank(user);
    IPool(POOL).supplyWithPermit(asset, supplyAmount, user, 0, permit.deadline, v, r, s);

    assertEq(IERC20(asset).balanceOf(user), initialBalance - supplyAmount);
    if (isRWA) {
      // if not RWA, then balance of aToken will differ due to accrued interest
      assertEq(getAToken(asset).scaledBalanceOf(user), supplyAmount);
    }
  }

  function getAToken(address asset) internal view returns (IAToken) {
    address aTokenAddress = IPool(POOL).getReserveData(asset).aTokenAddress;
    return IAToken(aTokenAddress);
  }

  // adapted from HorizonListingMainnetTest
  function whitelistSuperstateRwa(address addressToWhitelist) internal {
    address SUPERSTATE_ALLOWLIST_V2 = 0x02f1fA8B196d21c7b733EB2700B825611d8A38E5;
    uint256 SUPERSTATE_ROOT_ENTITY_ID = 1;

    (bool success, bytes memory data) = SUPERSTATE_ALLOWLIST_V2.call(
      abi.encodeWithSignature('owner()')
    );
    require(success, 'Failed to call owner()');
    address owner = abi.decode(data, (address));

    vm.prank(owner);
    (success, ) = SUPERSTATE_ALLOWLIST_V2.call(
      abi.encodeWithSignature(
        'setEntityIdForAddress(uint256,address)',
        SUPERSTATE_ROOT_ENTITY_ID,
        addressToWhitelist
      )
    );
  }

  // adapted from HorizonListingMainnetTest
  function whitelistUsycRwa(address addressToWhitelist) internal {
    uint8 CIRCLE_INVESTOR_SDYF_INTERNATIONAL_ROLE = 3;
    address CIRCLE_SET_USER_ROLE_AUTHORIZED_CALLER = 0xDbE01f447040F78ccbC8Dfd101BEc1a2C21f800D;

    (bool success, bytes memory data) = USYC_ADDRESS.call(abi.encodeWithSignature('authority()'));
    require(success, 'Failed to call authority()');
    address authority = abi.decode(data, (address));

    vm.prank(CIRCLE_SET_USER_ROLE_AUTHORIZED_CALLER);
    (success, ) = authority.call(
      abi.encodeWithSignature(
        'setUserRole(address,uint8,bool)',
        addressToWhitelist,
        CIRCLE_INVESTOR_SDYF_INTERNATIONAL_ROLE,
        true
      )
    );
    require(success, 'Failed to call setUserRole()');
  }

  // adapted from HorizonListingMainnetTest
  function whitelistCentrifugeRwa(address addressToWhitelist) internal {
    address CENTRIFUGE_HOOK = 0xa2C98F0F76Da0C97039688CA6280d082942d0b48;
    address CENTRIFUGE_WARD = 0xFEE13c017693a4706391D516ACAbF6789D5c3157;
    address restrictionManager = CENTRIFUGE_HOOK;

    (bool success, bytes memory data) = restrictionManager.call(abi.encodeWithSignature('root()'));
    require(success, 'Failed to call root()');
    address root = abi.decode(data, (address));

    vm.prank(CENTRIFUGE_WARD);
    (success, ) = root.call(abi.encodeWithSignature('endorse(address)', addressToWhitelist));
    require(success, 'Failed to call endorse()');
  }
}

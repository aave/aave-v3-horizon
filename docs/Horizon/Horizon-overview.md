# Horizon RWA Instance

## Context
- Horizon is an initiative by Aave Labs focused on creating Real-World Asset (RWA) products tailored for institutions.
- Horizon will launch a licensed, separate instance of the Aave Protocol (initially a fork of v3.3) to accommodate regulatory compliance requirements associated with RWA products.
- Horizon Instance will have a dual role setup with responsibilities split between Aave DAO (Operational role) and Aave Labs (Executive role).
 
## Overview
The Horizon Instance will introduce permissioned (RWA) assets. The Aave Pool will remain the same, except that RWA assets can be used as collateral in order to borrow stablecoins. Permissioning occurs at the asset level, with each RWA token issuer enforcing asset-specific restrictions directly into their ERC-20 token. The Aave Pool is agnostic to each specific RWA implementation and its asset-level permissioning.

From an Issuer perspective, aTokens are an extension of the RWA tokens, which are securities. The aTokens will signify ownership of the supplied underlying RWA Token. To accomodate edge cases, a protocol-wide aToken Transfer Admin is also added, allowing Issuers the ability to forcibly transfer aTokens on behalf of end users (without needing approval). These transfers will still enforce collateralization and health factor requirements as in existing Aave peer-to-peer aToken transfers.

There is permissionless supply of USDC to the Horizon Instance which can earn yield. GHO will also be listed in Horizon as a standard, non-mintable stablecoin. Borrowable stablecoins will not be used as collateral. 

Liquidations will be limited to entities already allowlisted to hold the underlying RWA collateral asset.

## Expected Code/Functionality Changes

### RWA Asset (Collateral Asset)
A new RWA-specific aToken contract (`RwaAToken`) has been developed, which prevents internal/external (peer-to-peer) transfers and allowance-related methods for users. It also incorporates an authorized ATokenAdmin role (`ATOKEN_ADMIN_ROLE`) which can transfer aTokens on behalf of users within collateralization/health factor constraints.

- aToken transfers
  - users cannot transfer their own aTokens (transfer and allowance related methods will revert).
  - new `ATOKEN_ADMIN` can forcibly transfer users' aToken without needing approval (but can still only transfer an aToken amount up to a healthy collateralization/health factor).
- `RwaATokenManager` contract
  - external aToken manager smart contract which encodes granular authorized aToken transfer permissions (by granting `AUTHORIZED_TRANSFER_ROLE`).
- Supply
  - can only be supplied by permissioned users allowlisted to hold RWA Token (will rely on underlying RWA asset-level permissioning).
  - can be supplied as collateral.
  - cannot supply `onBehalfOf` (to align with restricting aToken transfers; this action will revert on `mint`).
- Borrow
  - cannot be borrowed or flashborrowed (via RWA aToken implementation, this action will revert on `transferUnderlyingTo`; also via asset configuration).
- Repay
  - n/a as it cannot be borrowed.
- Liquidation
  - cannot liquidate into aTokens, by reverting on RWA aToken `transferOnLiquidation` when `receiveAToken` is set to `true` (only underlying RWA Token collateral can be liquidated).
  - disbursement of Liquidation Protocol Fee is disabled (if fee is set greater than 0, it will revert on `transferOnLiquidation`; also via asset configuration).
  - liquidators are implicitly permissioned to those already allowlisted to receive underlying RWA asset (will rely on underlying RWA asset-level permissioning).
    - technically any user allowlisted to hold RWA token asset can liquidate; any further permissioning to a smaller subset of liquidators will be governed off-chain.

### Stablecoins (Borrowable Asset)
Stablecoins can be supplied permissionlessly to earn yield. However, they will only be able to be borrowed, but disabled as collateral assets (via asset configuration, by setting LTV to 0). Borrowing will be implicitly permissioned because only users that have supplied RWA assets can borrow stablecoins. Other existing functionality remains the same as in v3.3. 

### Miscellaneous
- additional errors codes, associated interfaces.
- additional test suites.

## Configuration
- Stablecoin asset listing
  - will set LTV to `0` to prevent their utilization as collateral assets.
  - authorized flashborrowers will be configured.
- RWA Token asset listing
  - will set `enabledToBorrow` to `false` to prevent borrowing.
  - aToken Manager contract address will be granted the RWA aToken admin role. 
  - Liquidation Protocol Fee will be set to `0`.
- Further granular aToken admin permissions will be configured in the aToken Manager contract itself.
  - token Issuers/admin will be granted aToken admin permissions on the RWA aToken corresponding to their specific RWA asset.

## Edge Cases of Note
User has a borrow position but loses private keys to wallet. This position will need to be migrated to a new wallet.
Issuers will resolve using: 
- authorized flashborrow to borrow enough stablecoin to repay a user's debt.
- repay `onBehalfOf` to repay debt on behalf of user.
- `ATOKEN_ADMIN` to move RWA aToken collateral to new wallet.
- open a new borrow position from new wallet.

User creates a position in Horizon but then becomes sanctioned. Their actions will need to be blocked until further resolution. 
Issues can resolve by:
- `ATOKEN_ADMIN` to move maximum allowable RWA aToken collateral to temporary wallet.
- prevent the liquidation of the sanctioned user's position through off-chain coordination.

## References
- https://governance.aave.com/t/arfc-horizon-s-rwa-instance/21898
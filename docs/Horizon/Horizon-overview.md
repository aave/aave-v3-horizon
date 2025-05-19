# Horizon RWA Instance

## Context
- Horizon is an initiative by Aave Labs focused on creating Real-World Asset (RWA) products tailored for institutions.
- Horizon will launch a licensed, separate instance of the Aave Protocol (initially a fork of v3.3) to accommodate regulatory compliance requirements associated with RWA products.
- Horizon Instance will have a dual role setup with responsibilities split between Aave DAO (Operational role) and Aave Labs (Executive role).
 
## Overview
- Horizon Instance will introduce permissioned (RWA) assets.
  - Permissioning occurs at the asset level, with each RWA token issuer enforcing asset-specific restrictions directly into their ERC-20 token.
  - The Aave Pool is agnostic to each specific RWA implementation and its asset-level permissioning.
  - RWA Collateral Supply: Each RWA issuer enforces its own allowlist mechanism, permitting only verified addresses to hold eligible RWAs.
    - RWA Tokens will be configured during asset listing so that they will only be used as collateral. RWA-specific aToken implementation will also prevent RWA tokens from being borrowable.
  - Stablecoin Supply:
    - There is permissionless supply of USDC to the Horizon instance which can earn yield.
    - GHO will be listed in Horizon as a standard, non-mintable stablecoin.
- RWA Tokens are tokenized securities, and thus the protocol must accommodate their use as collateral assets.
  - From an Issuer perspective, aTokens are an extension of these securities. They will signify ownership of the supplied underlying RWA Token. Thus, aToken transfers will be disabled for end users (also through RWA-specific aToken implementation). 
  - However, to accomodate edge cases, a protocol-wide aToken Transfer Admin is added, allowing Issuers the ability to forcibly transfer aTokens on behalf of end users (without needing approval). 
    - These transfers will still enforce collateralization and health factor requirements as in existing Aave peer-to-peer aToken transfers.
- Liquidations will be limited to entities already allowlisted to hold the underlying RWA collateral asset.
  - This is achieved by preventing liquidators from receiving underlying collateral in aToken (through RWA-specific aToken implementation).

## Expected Code Changes
- new RWA-specific aToken instance contract (`RwaAToken`)
  - prevents internal/external (peer-to-peer) transfers and allowance-related methods for users (by reverting).
  - creates authorized ATokenAdmin role which can transfer aTokens on behalf of users (`ATOKEN_ADMIN_ROLE`) within collateralization/health factor constraints.
  - prevents liquidation into aTokens (only underlying RWA Token collateral can be liquidated) by reverting.
  - prevents disbursement of the Liquidation Protocol Fee by reverting.
  - prevents supplying `onBehalfOf` other users by reverting.
- `RwaATokenManager` contract
  - external aToken manager smart contract to encode granular authorized aToken transfer permissions (by granting `AUTHORIZED_TRANSFER_ROLE`).
- miscellaneous
  - additional errors codes, associated interfaces.
  - additional test suites.

## Detailed Functionality Changes

### RWA Asset (Collateral Asset)
- aTokens
  - users cannot transfer their own aTokens (transfer-related methods will revert).
  - new `ATOKEN_ADMIN` can forcibly transfer users' aToken without needing approval (but can still only transfer an aToken amount up to healthy collateralization/health factor).
- Supply
  - can only be supplied by permissioned users allowlisted to hold RWA Token (will rely on underlying RWA asset-level permissioning).
  - can be supplied as collateral.
  - cannot supply `onBehalfOf` (to align with restricting aToken transfers; this action will revert).
- Borrow / Repay
  - cannot be borrowed or flashborrowed (via asset configuration and via RWA aToken implementation, this action will revert).
- Liquidation
  - cannot liquidate to `receiveAToken` (to align with restricting aToken transfer; this action will revert).
  - liquidators are implicitly permissioned to those already allowlisted to receive underlying RWA asset (will rely on underlying RWA asset-level permissioning).
    - technically any user allowlisted to hold RWA token asset can liquidate; any further permissioning to a smaller subset of liquidators will be governed off-chain.

### Stablecoins (Borrowable Asset)
- aTokens
  - same as v3.3.
- Supply
  - permissionless supply.
  - can be supplied, but cannot be used as collateral (via asset configuration).
  - can supply `onBehalfOf`.
- Withdraw
  - same as v3.3.
- Borrow
  - can be borrowed (implicitly permissioned, because only users that have supplied RWA assets can borrow stablecoins).
  - can be flashborrowed (there will also be authorized flashborrowers which are configured).
- Repay
  - same as v3.3.
- Liquidation
  - n/a - it will only be repaid in a liquidation but never used as collateral asset (via asset configuration).

### Liquidations
- if Liquidation Protocol Fee is set greater than 0, liquidation will revert.
- if liquidator sets `receiveAToken` to `true`, liquidation will revert.

## Configuration
- Liquidation Protocol Fee will be set to 0.
- Stablecoin asset listing
  - will be listed with LTV of 0 to prevent their utilization as collateral assets for borrowing.
  - flashborrowers will be configured.
- RWA Token asset listing
  - will set `enabledToBorrow` to `false` to prevent borrowing.
  - aToken Manager contract address will be granted the RWA aToken admin role. 
- Further granular aToken admin permissions will be configured in the aToken Manager contract itself.
  - token Issuers/admin will be granted aToken admin permissions on the RWA aToken corresponding to their specific RWA asset.

## Edge Cases of Note
User has a borrow position but loses private keys to wallet. This will need to be migrated to a new wallet.
Issuers will resolve using: 
- flashborrow to borrow enough stablecoin to repay a user's debt.
- repay `onBehalfOf` to repay debt on behalf of user.
- `ATOKEN_ADMIN` to move RWA aToken collateral to new wallet.
- open a new borrow position on new wallet.

User creates a position in Horizon but then becomes sanctioned. Their actions will need to be blocked until further resolution. 
Issues can resolve by:
- `ATOKEN_ADMIN` to move maximum allowable RWA aToken collateral to temporary wallet.
- preventing the liquidation of their position through off-chain coordination.

## References
- https://governance.aave.com/t/arfc-horizon-s-rwa-instance/21898
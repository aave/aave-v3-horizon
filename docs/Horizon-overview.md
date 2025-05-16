# Horizon RWA Instance

## Context
- Horizon is an initiative by Aave Labs focused on creating Real-World Asset (RWA) products tailored for institutions
- Horizon will launch a licensed, separate instance of the Aave Protocol (initially a fork of v3.3) to accommodate regulatory compliance requirements associated with RWA products
- Horizon Instance will have a dual role setup with responsibilities split between Aave DAO (Operational role) and Aave Labs (Executive role) 
  - Operational: ownership and upgrade of the contracts, execution of governance proposals
  - Executive: risk management, assets listing, and general configuration
 
## Overview
- Horizon Instance will introduce permissioned (RWA) assets
  - Permissioning occurs at the asset level, with each RWA token issuer enforcing asset-specific restrictions directly into their ERC-20 token
  - RWA Collateral Supply: Each RWA issuer enforces its own allowlist mechanism, permitting only verified addresses to hold eligible RWAs and use them as collateral
    - RWA Tokens can only be used as collateral and will not be borrowable
  - Stablecoin Supply: 
    - Any user can supply USDC to the Horizon instance and earn yield
    - GHO will be listed in Horizon as a standard, non-mintable stablecoin
- RWA Tokens are tokenized securities, and thus the protocol must accomodate their use as collateral assets
  - From an Issuer perspective, aTokens are an extension of these securities. They will represent ownership of the supplied underlying RWA Token. Thus, aToken transfers will be disabled for end users. 
  - However, to accomodate edge cases, a protocol-wide aToken Transfer Admin is added, allowing Issuers the ability to forcibly transfer aTokens on behalf of end users (without needing approval)
- Liquidations will be limited to entities already allow-listed to hold the underlying RWA collateral asset

## Expected Code Changes
- new RWA-specific aToken instance contract (`RwaAToken`)
  - prevent internal/external transfers and allowance-related methods
  - authorized ATokenAdmin role which can transfer on behalf of users (`ATOKEN_ADMIN_ROLE`)
  - prevent liquidation into aTokens (only underlying RWA Token collateral can be liquidated)
  - Prevent supplying `onBehalfOf`
- `RwaATokenManager` contract
  - external aToken manager smart contract to encode granular aToken transfer permissions (by granting `AUTHORIZED_TRANSFER_ROLE`)
- Miscellaneous
  - additional errors codes, tests
  - associated interfaces

## Detailed Functionality Changes

### RWA Asset (Collateral Asset)
- aTokens
  - users cannot transfer their own aTokens
  - new `ATOKEN_ADMIN` can forcibly transfer others users' aToken without needing approval (but can still only transfer an aToken amount up to healthy health factor)
- Supply
  - can only be supplied by permissioned users whitelisted to hold RWA Token (will rely on underlying RWA asset-level permissioning)
  - can only be supplied as collateral
  - cannot supply `onBehalfOf` (to align with restricting aToken transfer)
- Borrow
  - cannot be borrowed or flash borrowed 
- Repay
  - cannot be borrowed or flash borrowed 
- Liquidation
  - cannot be borrowed or flash borrowed (n/a as it cannot be borrowed)
  - cannot liquidate to `receiveAToken` (align with restricting aToken transfer)
  - liquidators are implicitly permissioned to those already whitelisted to receive underlying RWA asset
  - technically any user whitelisted to hold RWA asset can liquidate; any further permissioning to a smaller subset of liquidators will be governed off-chain

### Stablecoins (Borrowable Asset)
- aTokens
  - same as v3.3
- Supply
  - permissionless supply 
  - can be supplied, but cannot be used as collateral
  - can supply `onBehalfOf`
- Withdraw
  - same as v3.3
- Borrow
  - can be borrowed (implicitly permissioned as only users that have supplied RWA assets can borrow stablecoins)
  - can be flashborrowed (there will also be authorized flashborrowers)
- Repay
  - same as v3.3
- Liquidation
  - n/a as it will only be repaid in a liquidation but never used as collateral asset

## Edge Cases of note:
User has a borrow position but loses private keys to wallet. This will need to be migrated to a new wallet.
Issuers will resolve using: 
- flashborrow to borrow enough stablecoin to repay a user's debt
- repay `onBehalfOf` to repay debt on behalf of user
- `ATOKEN_ADMIN` to move RWA aToken collateral to new wallet
- open a new borrow position 


## References
- https://governance.aave.com/t/arfc-horizon-s-rwa-instance/21898
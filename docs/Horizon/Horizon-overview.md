# Horizon RWA Instance

## Context

- Horizon is an initiative by Aave Labs focused on creating Real-World Asset (RWA) products tailored for institutions.
- Horizon will launch a licensed, separate instance of the Aave Protocol (initially a fork of v3.3) to accommodate regulatory compliance requirements associated with RWA products.
- Horizon will have a dual role setup with responsibilities split between Aave DAO (Operational role) and Aave Labs (Executive role).

## Overview

The Horizon Instance will introduce permissioned (RWA) assets. The Aave Pool will remain the same, except that RWA assets can be used as collateral in order to borrow stablecoins. Permissioning occurs at the asset level, with each RWA token issuer enforcing asset-specific restrictions directly into their ERC-20 token. The Aave Pool is agnostic to each specific RWA implementation and its asset-level permissioning.

From an Issuer perspective, RwaATokens are an extension of the RWA Tokens, which are securities. These RWA-specific aTokens will signify receipt of ownership of the supplied underlying RWA Token, but holders retain control over their RWA Token and can withdraw them within collateralization limits. 

However, holding an RwaAToken is purposefully more restrictive than merely holding an RWA Token. RWA Tokens subject holders to Issuer whitelisting and transfer mechanisms, but RwaATokens are fully locked and cannot be transferred by holders themselves.

To accommodate edge cases, a protocol-wide RWA aToken Transfer Admin is also added, allowing Issuers the ability to forcibly transfer RWA aTokens on behalf of end users (without needing approval). These transfers will still enforce collateralization and health factor requirements as in existing Aave peer-to-peer aToken transfers.

As with the standard Aave instance, an asset can be listed in Horizon through the usual configuration process. This instance is primarily aimed at onboarding stablecoins for borrowing.

## Implementation Overview

### RWA Asset (Collateral Asset)

RWA assets can be listed by utilizing a newly developed aToken contract, `RwaAToken`, which restricts the functionality of the underlying asset within the Aave Pool. These RWA assets are aimed to be used as collateral only, which is achieved through proper Pool configuration.

- RwaAToken transfers
  - users cannot transfer their own RwaATokens (transfer and allowance related methods will revert).
  - new `ATOKEN_ADMIN` role, which can forcibly transfer any RwaAToken without needing approval (but can still only transfer an RwaAToken amount up to a healthy collateralization/health factor). This role will be given to the `RwaATokenManager` contract, which will further delegate authorization on a per-RwaAToken basis. 
- `RwaATokenManager` contract
  - external RwaAToken manager smart contract which encodes granular authorized RwaAToken transfer permissions (by granting `AUTHORIZED_TRANSFER_ROLE` for specific RwaATokens).
  - it is expected that only trusted parties (such as token Issuers) will be granted `AUTHORIZED_TRANSFER_ROLE`, and that RwaAToken authorized transfers will only occur in extenuating circumstances.
    - it is left to Authorized Transfer Admin to execute transfers that adhere to the underlying RWA Token mechanics and legal compliance (for example, ensuring that RwaAToken recipients are allowlisted to hold the corresponding RWA Token).
- Supply
  - can only be supplied by permissioned users allowlisted to hold RWA Token (will rely on underlying RWA asset-level permissioning).
  - can be supplied as collateral, through proper risk configuration (non-zero LTV and Liquidation Threshold).
  - cannot supply `onBehalfOf` (to align with restricting RwaAToken transfers; via RwaAToken implementation, this action will revert on `mint`).
    - as a consequence, meta transactions are not supported.
- Borrow
  - cannot be borrowed or flashborrowed (via RwaAToken implementation, this action will revert on `transferUnderlyingTo`; also via asset configuration).
- Repay
  - N/A as it cannot be borrowed.
- Liquidation
  - cannot liquidate into RwaATokens, by reverting on `transferOnLiquidation` when `receiveAToken` is set to `true` (only underlying RWA Token collateral can be liquidated).
  - disbursement of Liquidation Protocol Fee is disabled (if fee is set greater than 0, it will revert on `transferOnLiquidation`; also via asset configuration).
  - liquidators are implicitly permissioned to those already allowlisted to receive underlying RWA asset (will rely on underlying RWA asset-level permissioning imposed by RWA's `transfer` function).
    - technically any user allowlisted to hold RWA token asset can liquidate; any further permissioning to a smaller subset of liquidators will be governed off-chain.
- Withdrawal
  - users can withdraw RWA assets to any particular address (via the `to` address in the `withdraw` function); this can be considered a standard ERC20 transfer and will adhere to the same restrictions imposed by the underlying RWA Token.

#### Configuration

- RwaATokenManager contract address granted the RwaAToken admin role in the ACL Manager.
  - further granular RwaAToken admin permissions will be configured in the RwaATokenManager contract itself.
  - Token Issuers or relevant admin will be granted admin permissions on the RwaAToken corresponding to their specific RWA asset.
- No bridges/portals will be configured, hence no unbacked RwaATokens can be minted. 

Reserve

- priceFeed: different per asset, but will be required to be Chainlink-compatible
- rateStrategyParams: n/a
- borrowingEnabled: false (to prevent its borrowing)
- borrowableInIsolation: false
- withSiloedBorrowing: false
- flashloanable: false
- LTV: different per asset, <100%
- liqThreshold: different per asset, <100%
- liqBonus: different per asset, >100%
- reserveFactor: 0
- supplyCap: different per asset
- borrowCap: 0
- debtCeiling: non-zero if the RWA asset is in isolation
- liqProtocolFee: 0 (otherwise liquidations will revert in RwaAToken due to `transferOnLiquidation`)

### Stablecoins (Borrowable Asset)

Stablecoins can be supplied permissionlessly to earn yield. However, they will only be able to be borrowed, but disabled as collateral assets (via asset configuration, by setting LTV to 0). Borrowing will be implicitly permissioned because only users that have supplied RWA assets can borrow stablecoins. Other existing functionality remains the same as in v3.3. Stablecoin assets will be listed as usual, also working in a standard way.

#### Configuration

Reserve

- priceFeed: different per asset, but will be required to be Chainlink-compatible
- rateStrategyParams: different per asset 
- borrowingEnabled: true 
- borrowableInIsolation: false
- withSiloedBorrowing: false
- flashloanable: true (authorized flashborrowers also will be configured)
- LTV: 0 
- liqThreshold: 0 (to disable its use as collateral)
- liqBonus: 100% (as it won't apply for a non-collateral asset)
- reserveFactor: different per asset
- supplyCap: different per asset
- borrowCap: different per asset
- debtCeiling: 0 (only applies to isolated asset)
- liqProtocolFee: 0 (as it won't apply for a non-collateral asset)

## Edge Cases of Note

### RWA Holder Loses Private Keys to Wallet

If a user has a borrow position but loses private keys to their wallet, this position can be migrated to a new wallet by the Issuer. Consider the following scenario involving the example permissioned `RWA_1` token:

- `ALICE` supply `100 RWA_1`
- `ALICE` borrow `50 DAI`
- `ALICE` loses the wallet key

At this point, the `RWA_1` issuer `RWA_1_ISSUER` (which may be granted "authorized flashborrower" role) can resolve this by:

`RWA_1_ISSUER` creates a new multisig wallet controlled by `RWA_1_ISSUER` and `ALICE`, with 1 of 1 signers, `NEW_ALICE_WALLET`.

Separately, `RWA_1_ISSUER` flashloan `50 DAI` (0 premium to pay because it's an "authorized flashborrower") by executing `Pool.flashLoan(...)`. In the flashloan callback, `RWA_1_ISSUER` will:

1. repay onBehalfOf `ALICE` the `50 DAI` debt
1. execute `RwaATokenManager.transferRwaAToken(RWA_1, ALICE, NEW_ALICE_WALLET, 100)`
1. `RWA_1_ISSUER` opens a new borrow position from `NEW_ALICE_WALLET` for `50 DAI`
1. `RWA_1_ISSUER` repays flashloan using newly borrowed `50 DAI`
1. `RWA_1_ISSUER` revokes its signing role from `NEW_ALICE_WALLET`, leaving `ALICE` as the sole remaining signer

At the conclusion, `RWA_1_ISSUER` will have migrated both `ALICE`'s initial debt and collateral positions to `NEW_ALICE_WALLET`. It is not strictly necessary for `RWA_1_ISSUER` to be an "authorized flashborrower", but this will be helpful in cases where the debt position is large, ensuring that `RWA_1_ISSUER` will not be required to consistently maintain a liquidity buffer on hand to resolve this situation. 

There also may not be ample liquidity in the Pool to cover via flashloan the debt position to migrate. Under those circumstances, it is the responsibility of the Issuer to resolve as needed.

### RWA Holder Becomes Sanctioned After Creating a Horizon Borrow Position

If a user creates a position in Horizon but then becomes sanctioned, their actions will need to be blocked until further resolution. Consider the following scenario involving the example permissioned `RWA_1` token:

- `ALICE` supply `1000 RWA_1` with a value of `$1000 `and `80% LTV`
- `ALICE` borrow `100 DAI`. With `80% LTV`, she could borrow `700 DAI` more.
- At this point `RWA_1_ISSUER` sanctions `ALICE`

`RWA_1_ISSUER` can resolve this by:

#### Option 1

- `RWA_1_ISSUER` repays onBehalfOf `ALICE` `100 DAI` debt
- `RWA_1_ISSUER` calls `RwaAToken.authorizedTransfer` to move all collateral to a separate trusted address to be custodied until the sanction case is resolved

#### Option 2

- `RWA_1_ISSUER` moves as much `RWA_1` as they can (at the limit of `ALICE`'s Health Factor to be 1)
- when interest accrual pushes `ALICE`'s Health Factor lower than 1 (making her position liquidatable), `RWA_1_ISSUER` communicates off-chain with permissioned liquidators to prevent liquidation, leaving the debt position until sanction is resolved

Note: technically speaking, any wallet whitelisted to hold the underlying RWA Token can perform liquidations. Therefore, if the need arises to prevent the liquidation of any specific user's position (such as in a sanctioned user case), off-chain coordination or legal agreements are required between Issuers and relevant parties. 

## References

- https://governance.aave.com/t/arfc-horizon-s-rwa-instance/21898

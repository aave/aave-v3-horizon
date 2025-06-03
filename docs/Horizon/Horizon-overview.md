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

#### Edge Cases of Note

- User has a borrow position but loses private keys to wallet. This position will need to be migrated to a new wallet. Issuers can resolve using:
  - authorized flashborrow to borrow enough stablecoin to repay a user's debt.
  - repay `onBehalfOf` to repay debt on behalf of user.
  - `ATOKEN_ADMIN` to move RwaAToken collateral to new wallet.
  - open a new borrow position from new wallet.
- User creates a position in Horizon but then becomes sanctioned. Their actions will need to be blocked until further resolution. Issuers can resolve using:
  - `ATOKEN_ADMIN` to move maximum allowable RwaAToken collateral to temporary wallet, preventing further borrowing.
  - Technically any wallet whitelisted to hold the underlying RWA Token can be a liquidator. Therefore, to prevent the liquidation of any specific sanctioned user's position, off-chain coordination or legal agreements are required between Issuers and relevant parties. 

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

## References

- https://governance.aave.com/t/arfc-horizon-s-rwa-instance/21898

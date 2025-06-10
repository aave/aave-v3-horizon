# Horizon RWA Instance

## Context

- Horizon is an initiative by Aave Labs focused on creating Real-World Asset (RWA) products tailored for institutions.
- Horizon will launch a licensed, separate instance of the Aave Protocol (initially a fork of v3.3) to accommodate regulatory compliance requirements associated with RWA products.
- Horizon will have a dual role setup with responsibilities split between Aave DAO (Operational role) and Aave Labs (Executive role).

## Overview

The Horizon Instance will introduce permissioned (RWA) assets. The Aave Pool will remain the same, except that RWA assets can be used as collateral in order to borrow stablecoins. Permissioning occurs at the asset level, with each RWA token issuer enforcing asset-specific restrictions directly into their ERC-20 token. The Aave Pool is agnostic to each specific RWA implementation and its asset-level permissioning.

From an Issuer perspective, RwaATokens are an extension of the RWA Tokens, which are securities. These RWA-specific aTokens (which are themselves not securities) will simply signify receipt of ownership of the supplied underlying RWA Token, but holders retain control over their RWA Token and can withdraw them as desired within collateralization limits.

However, holding an RwaAToken is purposefully more restrictive than merely holding an RWA Token. RWA Tokens subject holders to Issuer whitelisting and transfer mechanisms, but RwaATokens are fully locked and cannot be transferred by holders themselves.

To accommodate edge cases, a protocol-wide RWA aToken Transfer Admin is also added, allowing Issuers the ability to forcibly transfer RWA aTokens on behalf of end users (without needing approval). These transfers will still enforce collateralization and health factor requirements as in existing Aave peer-to-peer aToken transfers.

As with the standard Aave instance, an asset can be listed in Horizon through the usual configuration process. This instance is primarily aimed at onboarding stablecoins for borrowing.

## Implementation Overview

### RWA Asset (Collateral Asset)

RWA assets can be listed by utilizing a newly developed aToken contract, `RwaAToken`, which restricts the functionality of the underlying asset within the Aave Pool. These RWA assets are aimed to be used as collateral only, which is achieved through proper Pool configuration (ie setting `Liquidation Threshold` for RWA Tokens to `0`).

- RwaAToken transfers
  - users cannot transfer their own RwaATokens (transfer, allowance, and permit related methods will revert).
  - new `ATOKEN_ADMIN` role, which can forcibly transfer any RwaAToken without needing approval (but can still only transfer an RwaAToken amount up to a healthy collateralization/health factor). This role is expected to be given to the `RwaATokenManager` contract, which will granularly delegate authorization to individual accounts on a per-RwaAToken basis. 
  - note that `ATOKEN_ADMIN` can also forcibly transfer RwaATokens from the treasury address. While the treasury address currently does not receive RwaATokens of any sort through Reserve Factor or Liquidation Bonus, if this changes in the future there must be restrictions in place to protect RwaATokens earned by treasury.
- `RwaATokenManager` contract
  - external RwaAToken manager smart contract which encodes granular authorized RwaAToken transfer permissions (by granting `AUTHORIZED_TRANSFER_ROLE` for specific RwaATokens).
  - it is expected that only trusted parties (such as token Issuers) will be granted `AUTHORIZED_TRANSFER_ROLE`, and that RwaAToken authorized transfers will only occur in emergency situations (such as resolving [specific edge cases](#edge-cases-of-note)), rather than within the typical flow of operations.
  - it is left to Authorized Transfer Admin to execute authorized transfers that ensure compliance (for example, ensuring that RwaAToken recipients are allowlisted to hold the corresponding RWA Token). This scenario is described [here](#non-allowlisted-account-can-receive-rwaatokens). 
- Supply
  - can only be supplied by permissioned users allowlisted to hold RWA Token (will rely on underlying RWA asset-level permissioning).
  - can be supplied as collateral, through proper risk configuration (non-zero LTV and Liquidation Threshold).
  - cannot supply `onBehalfOf` (to align with restricting RwaAToken transfers; via RwaAToken implementation, this action will revert on `mint`).
    - as a consequence, meta transactions submitted by relayers on behalf of a user are not supported.
- Withdraw
  - users can withdraw RWA assets to any specified address (via the `to` address argument in the `withdraw` function); this should be considered a standard ERC20 transfer and will adhere to the same restrictions imposed by the underlying RWA Token. This scenario is described [here](#withdraw-as-a-transfer-of-underlying-rwa-token).
- Borrow
  - cannot be borrowed or flashborrowed (via RwaAToken implementation, this action will revert on `transferUnderlyingTo`; also via asset configuration).
- Repay
  - N/A as it cannot be borrowed.
- Liquidation
  - cannot liquidate into RwaATokens, by reverting on `transferOnLiquidation` when `receiveAToken` is set to `true` (only underlying RWA Token collateral can be liquidated).
  - disbursement of Liquidation Protocol Fee is disabled (if fee is set greater than 0, it will revert on `transferOnLiquidation`; also via asset configuration).
  - this should be considered a standard ERC20 transfer between liquidated user and liquidator, and will adhere to the same restrictions imposed by the underlying RWA Token. This scenario is described [here](#liquidation-as-a-transfer-of-underlying-rwa-token).
  - liquidators are implicitly permissioned to those already allowlisted to receive underlying RWA asset (will rely on underlying RWA asset-level permissioning imposed by RWA's `transfer` function).
    - technically any user allowlisted to hold RWA token asset can liquidate; any further permissioning to a smaller subset of liquidators will be governed off-chain.

#### Configuration

- RwaATokenManager contract address granted the RwaAToken admin role in the ACL Manager.
  - further granular RwaAToken admin permissions will be configured in the RwaATokenManager contract itself.
  - Token Issuers or relevant admin will be granted admin permissions on the RwaAToken corresponding to their specific RWA asset.
- No bridges/portals will be configured, hence no unbacked RwaATokens can be minted. 

#### Reserve

- priceFeed: different per asset, but will be required to be Chainlink-compatible
- rateStrategyParams: N/A (can be left empty)
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
- liqProtocolFee: 0 (must be 0, otherwise liquidations will revert in RwaAToken due to `transferOnLiquidation`)

### Stablecoins (Borrowable Asset)

Stablecoins can be supplied permissionlessly to earn yield. However, they will only be able to be borrowed, but disabled as collateral assets (via asset configuration, by setting Liquidation Threshold to 0). Borrowing will be implicitly permissioned because only users that have supplied RWA assets can borrow stablecoins (except in a potential case [here](#non-allowlisted-account-can-receive-rwaatokens)). Other existing functionality remains the same as in v3.3. Stablecoin assets will be listed as usual, also working in a standard way.

#### Reserve Configuration

- priceFeed: different per asset, but will be required to be Chainlink-compatible
- rateStrategyParams: different per asset 
- borrowingEnabled: true 
- borrowableInIsolation: true
- withSiloedBorrowing: false
- flashloanable: true (flashborrowers also will be configured)
- LTV: 0
- liqThreshold: 0 (to disable its use as collateral)
- liqBonus: 100% (as it won't apply for a non-collateral asset)
- reserveFactor: different per asset
- supplyCap: different per asset
- borrowCap: different per asset
- debtCeiling: 0 (only applies to isolated asset)
- liqProtocolFee: 0 (as it won't apply for a non-collateral asset)

## Edge Cases of Note

Consider the following scenarios involving the example permissioned `RWA_1` token.

### RWA Holder Loses Private Keys to Wallet

If a user has a borrow position but loses private keys to their wallet, this position can be migrated to a new wallet by the Issuer.

#### Assumptions

- `RWA_1_ISSUER` has been granted the role "flashborrower". The account will not pay a premium on the flashloan amount loaned.
- `RWA_1_ISSUER` has an off-chain agreement with `RWA_1` suppliers to migrate supplier lost positions if needed.

#### Context

1. `ALICE` supply `100 RWA_1`, receiving `100 aRWA_1`.
1. `ALICE` borrow `50 USDC`.
1. `ALICE` loses her wallet private key.
1. `ALICE` position is effectively unreachable in the protocol. 

`ALICE` creates a new wallet, `ALICE2`. 

#### Resolution

1. `RWA_1_ISSUER` creates a new multisig wallet controlled by `RWA_1_ISSUER` and `ALICE2` with 1 of 1 signers (`NEW_ALICE_WALLET`) which will eventually be fully transferred to `ALICE2`.
1. `RWA_1_ISSUER` executes a "complex" flashloan for `50 USDC` by calling `Pool.flashLoan(...)`. In the flashloan callback, `RWA_1_ISSUER` will:
    - repay the `50 USDC` debt `onBehalfOf` `ALICE`.
    - execute `RwaATokenManager.transferRwaAToken(RWA_1, ALICE, NEW_ALICE_WALLET, 100)` to transfer `100 aRWA_1` to `NEW_ALICE_WALLET`.
    - `RWA_1_ISSUER` opens a new borrow position from `NEW_ALICE_WALLET` for `50 USDC`.
    - `RWA_1_ISSUER` repays flashloan using newly borrowed `50 USDC`.
    - `RWA_1_ISSUER` revokes its signing role from `NEW_ALICE_WALLET`, fully transferring ownership to `ALICE2`.

At the conclusion, `RWA_1_ISSUER` will have migrated both `ALICE`'s initial debt and collateral positions to `NEW_ALICE_WALLET`. It is not strictly necessary for `RWA_1_ISSUER` to be a "flashborrower", but this will be helpful in cases where the debt position is large, ensuring that `RWA_1_ISSUER` will not be required to consistently maintain a liquidity buffer on hand to resolve this situation. This also allows for the position to be migrated without paying a premium for the flashloaned amount.

Limitations
- There may not be ample liquidity in the Horizon Pool to cover via flashloan the debt position to migrate. Under those circumstances, it is the responsibility of the Issuer to provide liquidity as needed.

### RWA Holder Becomes Sanctioned After Creating a Debt Position

If a user creates a debt position but then becomes sanctioned, their actions may need to be blocked until further resolution. Consider the following scenario involving the example permissioned `RWA_1` token.

#### Assumptions

- `RWA_1` has a `80% LTV` in Horizon.

#### Context

- `ALICE` supply `1000 RWA_1` with a value of `$1000`, receiving `1000 aRWA_1`.
- `ALICE` borrow `100 USDC`. With `80% LTV`, she could borrow `700 USDC` more.
- At this point `ALICE` becomes sanctioned.

#### Resolution

Option 1

- `RWA_1_ISSUER` repays `100 USDC` debt onBehalfOf `ALICE`.
- `RWA_1_ISSUER` calls `RwaAToken.authorizedTransfer` to move all `1000 aRWA_1` collateral to a separate trusted address (`RWA_1_TRUSTED`) to be custodied until the sanction case is resolved.
- `RWA_1_ISSUER` retains off-chain agreement with `ALICE` to recoup `100 USDC` repaid debt.

Option 2

- `RWA_1_ISSUER` calls `RwaAToken.authorizedTransfer` to move as much `aRWA_1` as they can (at the limit of `ALICE`'s Health Factor to be 1) to a separate trusted address (`RWA_1_TRUSTED`) to be custodied until the sanction case is resolved.
- When interest accrual reduces `ALICE`'s Health Factor below 1 (making her position liquidatable), `RWA_1_ISSUER` coordinates off-chain with permissioned liquidators to prevent liquidation, leaving the debt position in Horizon unaddressed until sanction is resolved.

At the conclusion, `aRWA_1` custodied by `RWA_1_TRUSTED` can be returned or moved elsewhere to ensure legal compliance. It is left to `RWA_1_ISSUER` to adjudicate as required. 

#### Limitations

- It's possible that the accrued interest could lead to bad debt and deficit accounting if the remaining collateral is insufficient to cover the remaining debt during a liquidation operation.
- Technically speaking, any wallet whitelisted to hold the underlying RWA Token can perform liquidations. Therefore, if the need arises to prevent the liquidation of any specific user's position (such as in a sanctioned user case), off-chain coordination or legal agreements are required to be in place between Issuers and any relevant parties. 

## Additional Considerations

Consider the following scenarios involving the example permissioned `RWA_1` token.

### Non Allowlisted Account Can Receive RwaATokens

`authorizedTransfer` of RwaATokens do not validate that recipient addresses belong to the allowlist of the underlying RWA Token. It is left to Authorized Transfer Admin to execute authorized transfers that adhere to the proper underlying RWA Token mechanics and ensure legal compliance. 

This theoretically allows recipients to open stablecoin debt positions without owning underlying RWA Tokens. See the following example. 

Assumptions:
- `ATOKEN_TRANSFER_ADMIN` is granted aToken Transfer Admin role, and is a trusted Issuer of `RWA_1`.
- `ALICE` is allowlisted to hold `RWA_1` and has supplied `100 RWA_1` to Horizon, receiving `100 aRWA_1`.
- `BOB` is not allowlisted to hold `RWA_1`.

1. `ATOKEN_TRANSFER_ADMIN` executes `authorizedTransfer` from `ALICE` to `BOB` for `100 aRWA_1`.
1. `BOB` sets `RWA_1` as collateral.
1. `BOB` borrows `50 USDC` against their `aRWA_1`.

The `ATOKEN_TRANSFER_ADMIN` bears responsibility to avoid this scenario if it violates underlying `RWA_1` operations through proper execution of the `authorizedTransfer` mechanism. 

### `Withdraw` as a Transfer of Underlying RWA Token

By specifying a separate `to` address argument in the `withdraw` function, users who have supplied RWA Tokens can withdraw them to any account. This should be considered a standard ERC20 transfer and will adhere to the same restrictions imposed by the underlying RWA Token.

Consider the scenario:
- `Bob` supply `100 RWA_1`.
- `Bob` withdraw `50 RWA_1` with `to` set to `ALICE`'s wallet address.
  - if `ALICE` has **not** been allowlisted to hold `RWA_1`, this transaction will revert.
  - if `ALICE` has been allowlisted to hold `RWA_1`, she will receive `50 RWA_1`.

Outcome

Assuming `ALICE` has been allowlisted, the two following helpful events will be emitted:

```
emit Withdraw(params.asset, msg.sender, params.to, amountToWithdraw);
```

where 
- `params.asset` (address) is the `RWA_1` token address.
- `msg.sender (address) is `BOB`'s account.
- `params.to` (address) is `ALICE`'s account.
- `amountToWithdraw` (uint256) is `50`, with corresponding decimals units appended (ex. if decimals is 6, this value will be `50_000_000`).

```
event Transfer(address indexed from, address indexed to, uint256 value);
```

where 
- `from` (address) is the `RWA_1` **RwaAToken** address.
  - Note that the emitted `from` address is the **RwaAToken** smart contract rather than `BOB`'s account. 
- `to` (address) is `ALICE`'s account.
- `value` (uint256) will match `amountToWithdraw` value.

The Issuer's Transfer Agent must take care to record this officially as a transfer of `RWA_1` between `BOB` and `ALICE`, rather than a transfer between the `RWA_1` RwaAToken contract and `ALICE`. 

### `Liquidation` as a Transfer of Underlying RWA Token

During a liquidation, collateral seized from the user being liquidated will be transferred to the liquidator. This should also be considered a standard ERC20 transfer. 

Assumptions:
- `BOB` and `ALICE` are allowlisted to hold `RWA_1`.
- `ALICE` has an off-chain legal agreement with `RWA_1_ISSUER` to be able to be a liquidator.
- `LTV` of `RWA_1` is `>80%` in Horizon.
- `RWA_1` has decimals of 8.

Consider the scenario:
- `BOB` supply `100 RWA_1`, and borrows `80 USDC`.
- time flies and `Bob`'s `USDC` debt grows to `120 USDC` through accumulation of interest. His position is no longer healthy and it becomes liquidatable. 
- `ALICE` executes a `liquidationCall` on `BOB`'s position, and is able to earn all of `BOB`'s seized `100 RWA_1` (which includes the liquidation bonus) by repaying `BOB`'s `120 USDC` debt.
- `ALICE` receives `100 RWA_1`.

Outcome

Two helpful events will be emitted involving the collateral:

```
event Transfer(address indexed from, address indexed to, uint256 value);
```

where 
- `from` (address) is the `RWA_1` **RwaAToken** address.
  - Note that the emitted `from` address is the **RwaAToken** smart contract rather than `BOB`'s account. 
- `to` (address) is `ALICE`'s account.
- `value` (uint256) will be the liquidated `RWA_1` collateral amount, ie `10_000_000` including decimals.

```
emit LiquidationCall(
  params.collateralAsset,
  params.debtAsset,
  params.user,
  vars.actualDebtToLiquidate,
  vars.actualCollateralToLiquidate,
  msg.sender,
  params.receiveAToken
);
```

where
- `params.collateralAsset` (address) is the `RWA_1` collateral token address.
- `params.debtAsset` (address) is the `USDC` debt token address.
- `params.user` (address) is the liquidated user account, `BOB`.
- `vars.actualDebtToLiquidate` (uint256) is the amount of debt asset, `USDC`, to liquidate, with corresponding decimals units appended (ex. if decimals is 6, this value will be `120_000_000`). 
- `vars.actualCollateralToLiquidate` (uint256) is the amount of collateral asset to liquidate, which is `10_000_000 RWA_1`.
- `msg.sender` (address) is the liquidator address, ie `ALICE`'s account.
- `params.receiveAToken` (bool) will be false, as `receiveAToken` is not allowed.

The Issuer's Transfer Agent must take care to record this officially as a transfer of `RWA_1` between `BOB` (liquidated user) and `ALICE` (liquidator), rather than a transfer between the `RWA_1` RwaAToken contract and `ALICE`.

### Further Configuration

Exact configuration details for eMode, isolated mode, flash loan premiums, and liquidity mining rewards are in progress.

## References

- https://governance.aave.com/t/arfc-horizon-s-rwa-instance/21898
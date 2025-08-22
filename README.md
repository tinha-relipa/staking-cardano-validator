# Staking

## How It Works

1. Staking rewards are calculated and distributed to all stakers once per day at a predetermined time.
2. Stakers must have their stake assets locked for at least one full day before they start earning rewards.
3. All rewards are paid out in ADA.
4. Stakers can add or remove part of their staked asset.
5. Stakers can unlock their rewards or withdraw all of their stake at any time.

## High-Level Overview

This is a multi-validator script with one spending script, one withdrawal script, and one minting script. The multi-validator is parameterized by four variables:

```
(
  admin_pkh: AddressHash,
  staking_policy_id: PolicyId,
  staking_asset_name: ByteArray,
  stake_credential: StakeCredential
)
```

There are five actions that can occur. Stakers will have a UTxO at the multi-validator script. The admin will deposit assets into the UTxO by consuming it and sending it back to the multi-validator script. The reward distribution utilizes a withdrawal script. This mechanism allows for daily payouts to the staker at a minimum cost to the admin.

1. Stake
2. Add Stake
3. Withdraw Rewards
4. Withdraw Stakes and Rewards
5. Distribute Stake

## Stake

To stake, the staker must first mint a `mint_asset`. The minting script ensures that the Stake UTxO is valid. It verifies that the datum values are valid, as these will be the source of truth for other actions with the script.

Validations:

- A UTxO is being sent to the multi-validator script.
- The UTxO contains at least one `staking_asset`.
- The `mint_asset` is being sent to the validator.
- The `asset_name` of `mint_asset` is the PKH of the owner.
- Only one `mint_asset` is minted.
- The output contains 2 ADA.
- The transaction is signed by the owner.
- The ADA staking credential of the asset sent to the multi-validator script matches the parameter.
- The Datum value is valid:
  - The `staking_asset` in the datum is equal to the parameter.
  - The `mint_asset` in the datum field matches the minted asset.
  - The `last_rewarded_time` was before the transaction.

## Add Stake

After staking, the staker can add more stake to earn additional rewards. If their initial stake has been in place for at least one day, the new stake deposited will be treated similarly, and they will be rewarded the full stake amount when rewards are distributed.

Validations:

- A UTxO is being sent to the multi-validator script.
- The UTxO has the same datum value as the consumed UTxO.
- The transaction is signed by the owner.
- The `stake_asset` amount has increased.
- The `mint_asset` is sent back.
- The ADA staking credential remains unchanged.
- Only one input is present.
- The UTxO contains at least 2 ADA.

## Withdraw Rewards

The staker can withdraw their rewards at any time.

Validations:

- A UTxO is being sent back to the multi-validator script.
- The UTxO has the same datum value as the consumed UTxO.
- The transaction is signed by the owner.
- The `stake_asset` was not consumed.
- The `mint_asset` is sent back.
- The ADA staking credential remains unchanged.
- Only one input is present.
- The UTxO contains at least 2 ADA.

## Withdraw Stakes and Rewards

The staker can withdraw their stake at any time with no lock-up period.

Validations:

- The transaction is signed by the staker.
- The `mint_asset` is burned.

## Distribute Stake

The fair distribution of stake rewards will depend on off-chain logic. However, the smart contract guarantees that the staked rewards and assets cannot be consumed by the admin. The distribution of staking rewards will be conducted by consuming the UTxOs at the script, adding rewards to them, and sending them back without consuming anything or altering the datum values.

Validations:

- The UTxO is sent back to the multi-validator.
- The Datum remains the same as consumed.
- The `stake_asset` is not consumed.
- The `mint_asset` is not consumed.
- The transaction is signed by the admin.

## Disclaimer

This staking contract provides the following functionalities:

Users stake their tokens, and their staked and rewarded tokens are protected and can only be consumed by the users themselves. The smart contract ensures the safety of users' staked tokens and provides the necessary framework for off-chain code to behave correctly.

The distribution of rewards is not permissionless. It relies on an entity to distribute the funds accordingly off-chain. The rewards can potentially be distributed disproportionately off-chain.

While this approach is not ideal, we believe it is reasonable for a V1 implementation. We will iterate and create a more permissionless staking contract once all products are on-chain.

All interactions with the script ensure that the owner always signs the transaction and that the staked tokens are never compromised.

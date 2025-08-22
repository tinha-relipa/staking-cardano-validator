# GET Platform Staking Smart Contracts

## Overview

A comprehensive Cardano staking system with factory-managed pools, voting mechanisms, and time-based multipliers. The system allows admins to create staking pools with configurable voting options and time multipliers, while users can stake tokens and participate in governance through voting.

## Key Features

- **Factory-Managed Pools**: Admin-controlled pool creation with unique configurations
- **Voting System**: Users select from predefined voting options when staking
- **Time-Based Multipliers**: Configurable time options that affect vote power
- **Vote Power Calculation**: Automatic calculation of vote power (vote_option × time_option)
- **Token-Specific Staking**: Each pool specifies which tokens can be staked
- **Flexible Withdrawals**: Users can withdraw their stakes at any time

## How It Works

1. **Pool Creation**: Only admins can create new staking pools through the factory contract
2. **Staking with Voting**: Users stake tokens and must select voting and time options
3. **Vote Power**: The system calculates vote power by multiplying vote option and time option

## Architecture

The system consists of two main components:

### 1. Factory Contract
Manages the creation and administration of staking pools.

**Parameters:**
```aiken
FactoryParams {
  factory_admin: AddressHash,
  pool_token_policy_id: PolicyId,
}
```

**Operations:**
- `CreatePool`: Admin creates new staking pools with voting/time configurations
- `UpdatePool`: Admin can activate/deactivate pools
- `UpdateFactoryAdmin`: Transfer factory admin rights

### 2. Staking Contract
Handles individual staking operations within pools.

**Parameters:**
```aiken
StakingParams {
  admin_pkh: AddressHash,
  asset_name: AssetName,
  staking_policy_id: PolicyId,
  staking_asset_name: ByteArray,
  stake_credential: ByteArray,
  voting_options: List<Int>,           // Available vote multipliers
  allowed_token_policy: PolicyId,      // Token that can be staked
  allowed_token_name: AssetName,
  time_options: List<POSIXTime>,       // Available time multipliers
}
```

**Operations:**
1. **Stake with Voting**: Users stake tokens and select vote/time options
2. **Add Stake**: Increase existing stake amount
3. **Withdraw Stakes**: Full withdrawal of staked tokens

## Pool Creation (Admin Only)

Only the factory admin can create new staking pools. Each pool is configured with specific voting options, allowed tokens, and time multipliers.

**Process:**
1. Admin calls `CreatePool` with pool parameters
2. Factory validates admin signature
3. Pool is created with unique ID and configuration
4. Pool token is minted as identifier

**Pool Configuration:**
```aiken
PoolInfo {
  pool_id: ByteArray,
  admin_pkh: AddressHash,
  voting_options: [1, 2, 3, 5],        // Available vote multipliers
  allowed_token_policy: PolicyId,       // Only this token can be staked
  allowed_token_name: AssetName,
  time_options: [30_days, 90_days, 365_days], // Time multipliers in POSIX
  is_active: Bool,
  // ... other fields
}
```

## Stake with Voting

Users stake tokens in a specific pool and must select voting and time options that affect their vote power.

**Process:**
1. User selects a pool and chooses vote_option and time_option
2. User calls `AddStakeOrConsumeStakingRewards { vote_option, time_option }`
3. Contract validates options are in pool's allowed lists
4. Vote power is calculated: `vote_power = vote_option × time_option`
5. Staking datum is created with voting information

**Validations:**
- Transaction signed by staker
- Vote option is in pool's `voting_options` list
- Time option is in pool's `time_options` list
- Correct allowed token is being staked
- Vote power calculation is correct
- UTxO sent to staking validator with proper datum
- Mint asset and owner asset are created

**Staking Datum:**
```aiken
StakingDatum {
  owner_address_hash: AddressHash,
  staked_at: POSIXTime,
  mint_policy_id: PolicyId,
  vote_option: Int,      // Selected vote multiplier
  time_option: Int,      // Selected time multiplier  
  vote_power: Int,       // vote_option × time_option
}
```

## Add Stake

Stakers can increase their existing stake amount while maintaining their original voting configuration.

**Process:**
1. User calls `AddStakeOrConsumeStakingRewards` with same vote/time options
2. Additional allowed tokens are added to the stake
3. Vote power remains the same (based on original selection)

**Validations:**
- Transaction signed by staker
- Same vote_option and time_option as original stake
- Vote power calculation matches original
- Additional allowed tokens are being staked
- Datum values remain consistent
- UTxO sent back to validator
- Minimum ADA maintained

## Withdraw Stakes

Stakers can perform a full withdrawal, reclaiming their staked tokens.

**Process:**
1. User calls `WithdrawStake` redeemer
2. All staked tokens are returned to user
3. Mint asset and owner asset are burned
4. Staking position is completely closed

**Validations:**
- Transaction signed by staker
- Mint asset is burned (-1 quantity)
- Owner asset is burned (-1 quantity)
- Exactly 2 assets burned in transaction
- All staked tokens returned to user

## Vote Power Usage

The vote power calculated from user selections provides a weighted value based on their staking commitment:

**Calculation:**
```
vote_power = vote_option × time_option
```

**Example:**
- User selects vote_option = 3, time_option = 2
- Resulting vote_power = 6
- Higher vote power indicates greater staking commitment

## Security Features

- **Admin-Only Pool Creation**: Only factory admin can create new pools
- **Validated Options**: Users can only select from predefined vote/time options
- **Token Validation**: Only specified tokens can be staked in each pool
- **Signature Verification**: All operations require proper signatures
- **Asset Protection**: Staked assets cannot be consumed by admin
- **Datum Integrity**: Vote power calculations are validated on-chain

## Integration Guide

### For Pool Administrators
1. Deploy factory contract with admin credentials
2. Create pools with desired voting/time configurations
3. Specify allowed tokens for each pool
4. Manage pool status (active/inactive)

### For Stakers
1. Choose a pool with desired voting options
2. Select vote_option and time_option when staking
3. Stake the pool's specified allowed token
4. Monitor vote power calculation
5. Withdraw full stake as needed

### For Developers
1. Use factory contract to discover available pools
2. Query pool configurations for voting/time options
3. Build UI for vote/time option selection
4. Calculate expected vote power for users
5. Track staking positions and vote power metrics

## Disclaimer

This staking contract provides the following functionalities:

Users stake their tokens, and their staked and rewarded tokens are protected and can only be consumed by the users themselves. The smart contract ensures the safety of users' staked tokens and provides the necessary framework for off-chain code to behave correctly.

The distribution of rewards is not permissionless. It relies on an entity to distribute the funds accordingly off-chain. The rewards can potentially be distributed disproportionately off-chain.

While this approach is not ideal, we believe it is reasonable for a V1 implementation. We will iterate and create a more permissionless staking contract once all products are on-chain.

All interactions with the script ensure that the owner always signs the transaction and that the staked tokens are never compromised.

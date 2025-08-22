use aiken/crypto.{Blake2b_224, Hash, VerificationKey}
use cardano/assets.{AssetName, PolicyId}

pub type AddressHash =
  Hash<Blake2b_224, VerificationKey>

pub type POSIXTime =
  Int

pub type AssetClass {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type StakingDatum {
  owner_address_hash: AddressHash,
  staked_at: POSIXTime,
  mint_policy_id: PolicyId,
  vote_option: Int,
  time_option: Int,
  vote_power: Int,  // vote_option * time_option
}

pub type StakingRedeemer {
  AddStakeOrConsumeStakingRewards {
    vote_option: Int,
    time_option: Int,
  }
  WithdrawStake
  DistributeStakingRewards
}

pub type MintRedeemer {
  Mint(Int)
  Burn(AddressHash)
}

pub type StakingParams {
  admin_pkh: AddressHash,
  asset_name: AssetName,
  staking_policy_id: PolicyId,
  staking_asset_name: ByteArray,
  stake_credential: ByteArray,
  voting_options: List<Int>,
  allowed_token_policy: PolicyId,
  allowed_token_name: AssetName,
  time_options: List<POSIXTime>,
}

// Factory-related types
pub type PoolInfo {
  pool_id: ByteArray,
  admin_pkh: AddressHash,
  staking_policy_id: PolicyId,
  staking_asset_name: ByteArray,
  stake_credential: ByteArray,
  created_at: POSIXTime,
  is_active: Bool,
  voting_options: List<Int>,
  allowed_token_policy: PolicyId,
  allowed_token_name: AssetName,
  time_options: List<POSIXTime>,
}

pub type FactoryDatum {
  factory_admin: AddressHash,
  total_pools: Int,
  pools: List<PoolInfo>,
}

pub type FactoryRedeemer {
  CreatePool {
    pool_params: StakingParams,
    pool_id: ByteArray,
  }
  UpdatePool {
    pool_id: ByteArray,
    new_status: Bool,
  }
  UpdateFactoryAdmin {
    new_admin: AddressHash,
  }
}

pub type FactoryMintRedeemer {
  MintPoolToken(ByteArray)  // pool_id
  BurnPoolToken(ByteArray)  // pool_id
}

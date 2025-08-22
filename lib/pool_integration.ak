use aiken/collection/list
use cardano/address.{Address}
use cardano/assets.{PolicyId}
use cardano/transaction.{Transaction, Output, InlineDatum}
use types.{
  FactoryDatum, PoolInfo, StakingParams, StakingDatum,
}
use factory_utils.{find_pool_by_id}

// Integration functions for factory and staking pools

// Create staking parameters from pool info
pub fn pool_info_to_staking_params(
  pool_info: PoolInfo,
  asset_name: ByteArray,
) -> StakingParams {
  StakingParams {
    admin_pkh: pool_info.admin_pkh,
    asset_name,
    staking_policy_id: pool_info.staking_policy_id,
    staking_asset_name: pool_info.staking_asset_name,
    stake_credential: pool_info.stake_credential,
    voting_options: pool_info.voting_options,
    allowed_token_policy: pool_info.allowed_token_policy,
    allowed_token_name: pool_info.allowed_token_name,
    time_options: pool_info.time_options,
  }
}

// Validate that a staking transaction references a valid pool
pub fn validate_pool_reference(
  factory_datum: FactoryDatum,
  pool_id: ByteArray,
  staking_params: StakingParams,
) -> Bool {
  expect Some(pool_info) = find_pool_by_id(factory_datum.pools, pool_id)
  
  let params_match = 
    pool_info.admin_pkh == staking_params.admin_pkh &&
    pool_info.staking_policy_id == staking_params.staking_policy_id &&
    pool_info.staking_asset_name == staking_params.staking_asset_name &&
    pool_info.stake_credential == staking_params.stake_credential
  
  pool_info.is_active && params_match
}

// Get all staking outputs for a specific pool
pub fn get_pool_staking_outputs(
  transaction: Transaction,
  pool_address: Address,
) -> List<Output> {
  list.filter(
    transaction.outputs,
    fn(output) { output.address == pool_address }
  )
}

// Validate staking datum against pool info
pub fn validate_staking_datum_for_pool(
  staking_datum: StakingDatum,
  pool_info: PoolInfo,
) -> Bool {
  // The mint policy ID in staking datum should match some validation
  // This could be extended based on specific business logic
  let created_after_pool = staking_datum.staked_at >= pool_info.created_at
  
  created_after_pool
}

// Get pool statistics from factory datum
pub fn get_pool_stats(factory_datum: FactoryDatum) -> (Int, Int, Int) {
  let total_pools = factory_datum.total_pools
  let active_pools = list.length(
    list.filter(factory_datum.pools, fn(pool) { pool.is_active })
  )
  let inactive_pools = total_pools - active_pools
  
  (total_pools, active_pools, inactive_pools)
}

// Find pools by staking asset
pub fn find_pools_by_asset(
  factory_datum: FactoryDatum,
  staking_policy_id: PolicyId,
  staking_asset_name: ByteArray,
) -> List<PoolInfo> {
  list.filter(
    factory_datum.pools,
    fn(pool) {
      pool.staking_policy_id == staking_policy_id &&
      pool.staking_asset_name == staking_asset_name &&
      pool.is_active
    }
  )
}

// Validate pool creation transaction
pub fn validate_pool_creation_tx(
  transaction: Transaction,
  factory_address: Address,
  new_pool_info: PoolInfo,
) -> Bool {
  // Check that factory output exists with updated datum
  let factory_outputs = list.filter(
    transaction.outputs,
    fn(output) { output.address == factory_address }
  )
  
  expect Some(factory_output) = list.head(factory_outputs)
  expect InlineDatum(output_datum) = factory_output.datum
  expect factory_datum: FactoryDatum = output_datum
  
  // Verify the new pool is in the updated datum
  list.any(
    factory_datum.pools,
    fn(pool) { pool.pool_id == new_pool_info.pool_id }
  )
}

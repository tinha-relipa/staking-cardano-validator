use aiken/collection/list
use aiken/crypto.{blake2b_256}
use aiken/primitive/bytearray
use cardano/transaction.{Transaction, Output}
use types.{PoolInfo, FactoryDatum, AddressHash}

// Generate a unique pool ID based on admin and timestamp
pub fn generate_pool_id(admin_pkh: AddressHash, timestamp: Int) -> ByteArray {
  // Simple approach: just hash the admin_pkh with some salt based on timestamp
  // In practice, you might want to use a more sophisticated approach
  let salt = if timestamp % 2 == 0 { "even" } else { "odd" }
  let combined = bytearray.concat(admin_pkh, salt)
  blake2b_256(combined)
}

// Find a pool by ID in the factory datum
pub fn find_pool_by_id(pools: List<PoolInfo>, pool_id: ByteArray) -> Option<PoolInfo> {
  list.find(pools, fn(pool) { pool.pool_id == pool_id })
}

// Get all active pools
pub fn get_active_pools(pools: List<PoolInfo>) -> List<PoolInfo> {
  list.filter(pools, fn(pool) { pool.is_active })
}

// Get pools by admin
pub fn get_pools_by_admin(pools: List<PoolInfo>, admin_pkh: AddressHash) -> List<PoolInfo> {
  list.filter(pools, fn(pool) { pool.admin_pkh == admin_pkh })
}

// Validate pool ID uniqueness
pub fn is_pool_id_unique(pools: List<PoolInfo>, pool_id: ByteArray) -> Bool {
  !list.any(pools, fn(pool) { pool.pool_id == pool_id })
}

// Count total active pools
pub fn count_active_pools(pools: List<PoolInfo>) -> Int {
  list.length(get_active_pools(pools))
}

// Validate factory datum structure
pub fn validate_factory_datum(datum: FactoryDatum) -> Bool {
  let pools_count_valid = list.length(datum.pools) == datum.total_pools
  // Check for duplicate pool IDs manually since unique_by doesn't exist
  let no_duplicate_ids = check_unique_pool_ids(datum.pools)
  
  pools_count_valid && no_duplicate_ids
}

// Helper function to check for unique pool IDs
fn check_unique_pool_ids(pools: List<PoolInfo>) -> Bool {
  when pools is {
    [] -> True
    [head, ..tail] -> 
      !list.any(tail, fn(pool) { pool.pool_id == head.pool_id }) && 
      check_unique_pool_ids(tail)
  }
}

// Get factory outputs from transaction
pub fn get_factory_outputs(transaction: Transaction, factory_address) -> List<Output> {
  list.filter(
    transaction.outputs,
    fn(output) { output.address == factory_address }
  )
}

// Validate pool parameters
pub fn validate_pool_params(
  admin_pkh: AddressHash,
  staking_policy_id: ByteArray,
  staking_asset_name: ByteArray,
  stake_credential: ByteArray,
) -> Bool {
  let admin_valid = bytearray.length(admin_pkh) == 28
  let policy_valid = bytearray.length(staking_policy_id) == 28
  let asset_name_valid = bytearray.length(staking_asset_name) > 0
  let stake_cred_valid = bytearray.length(stake_credential) > 0
  
  admin_valid && policy_valid && asset_name_valid && stake_cred_valid
}

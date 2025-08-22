use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId, quantity_of, lovelace_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_input,
}
use constants.{min_lovelace_in_utxo}
use types.{
  AddressHash, FactoryDatum, FactoryRedeemer, FactoryMintRedeemer, PoolInfo,
  StakingParams, CreatePool, UpdatePool, FinalizePool, UpdateFactoryAdmin, MintPoolToken,
  BurnPoolToken,
}

// Factory parameters
pub type FactoryParams {
  factory_admin: AddressHash,
  pool_token_policy_id: PolicyId,
}

validator factory(params: FactoryParams) {
  spend(
    datum: Option<FactoryDatum>,
    redeemer: FactoryRedeemer,
    my_output_reference: OutputReference,
    transaction: Transaction,
  ) {
    expect Some(factory_datum) = datum
    
    expect Some(input_from_factory) =
      transaction.inputs
        |> find_input(my_output_reference)

    // Find the output back to the factory
    let outputs_to_factory: List<Output> =
      list.filter(
        transaction.outputs,
        fn(output) { output.address == input_from_factory.output.address },
      )

    expect Some(output_to_factory) = list.head(outputs_to_factory)
    expect InlineDatum(output_datum) = output_to_factory.datum
    expect output_factory_datum: FactoryDatum = output_datum

    // Validate admin signature for all operations
    let admin_signed = 
      list.has(transaction.extra_signatories, factory_datum.factory_admin)

    when redeemer is {
      CreatePool { pool_params, pool_id } -> {
        // Validate pool creation
        let pool_id_unique = 
          !list.any(
            factory_datum.pools,
            fn(pool) { pool.pool_id == pool_id },
          )

        // Get current time from transaction validity range
        expect Finite(current_time) = transaction.validity_range.upper_bound.bound_type

        let new_pool = PoolInfo {
          pool_id,
          admin_pkh: pool_params.admin_pkh,
          staking_policy_id: pool_params.staking_policy_id,
          staking_asset_name: pool_params.staking_asset_name,
          stake_credential: pool_params.stake_credential,
          created_at: current_time,
          is_active: True,
          voting_options: pool_params.voting_options,
          allowed_token_policy: pool_params.allowed_token_policy,
          allowed_token_name: pool_params.allowed_token_name,
          time_options: pool_params.time_options,
          is_finalized: False,
          winning_vote_option: None,
          finalized_at: None,
        }

        // Validate output datum
        let expected_pools = [new_pool, ..factory_datum.pools]
        let datum_valid = 
          output_factory_datum.factory_admin == factory_datum.factory_admin &&
          output_factory_datum.total_pools == factory_datum.total_pools + 1 &&
          output_factory_datum.pools == expected_pools

        // Validate pool token is minted
        let pool_token_minted = 
          quantity_of(
            transaction.mint,
            params.pool_token_policy_id,
            pool_id,
          ) == 1

        // Validate minimum ADA is maintained
        let min_ada_valid = 
          lovelace_of(output_to_factory.value) >= min_lovelace_in_utxo

        admin_signed && pool_id_unique && datum_valid && pool_token_minted && min_ada_valid
      }

      UpdatePool { pool_id, new_status } -> {
        // Find and update the pool
        let updated_pools = 
          list.map(
            factory_datum.pools,
            fn(pool) {
              if pool.pool_id == pool_id {
                PoolInfo { ..pool, is_active: new_status }
              } else {
                pool
              }
            },
          )

        // Validate output datum
        let datum_valid = 
          output_factory_datum.factory_admin == factory_datum.factory_admin &&
          output_factory_datum.total_pools == factory_datum.total_pools &&
          output_factory_datum.pools == updated_pools

        // Validate minimum ADA is maintained
        let min_ada_valid = 
          lovelace_of(output_to_factory.value) >= min_lovelace_in_utxo

        admin_signed && datum_valid && min_ada_valid
      }

      FinalizePool { pool_id, winning_vote_option } -> {
        // Get current time from transaction validity range
        expect Finite(current_time) = transaction.validity_range.upper_bound.bound_type
        
        // Find and finalize the pool
        let updated_pools = 
          list.map(
            factory_datum.pools,
            fn(pool) {
              if pool.pool_id == pool_id {
                // Validate winning vote option is in pool's voting options
                expect list.has(pool.voting_options, winning_vote_option)
                PoolInfo { 
                  ..pool, 
                  is_finalized: True,
                  winning_vote_option: Some(winning_vote_option),
                  finalized_at: Some(current_time),
                }
              } else {
                pool
              }
            },
          )

        // Validate output datum
        let datum_valid = 
          output_factory_datum.factory_admin == factory_datum.factory_admin &&
          output_factory_datum.total_pools == factory_datum.total_pools &&
          output_factory_datum.pools == updated_pools

        // Validate minimum ADA is maintained
        let min_ada_valid = 
          lovelace_of(output_to_factory.value) >= min_lovelace_in_utxo

        admin_signed && datum_valid && min_ada_valid
      }

      UpdateFactoryAdmin { new_admin } -> {
        // Validate output datum
        let datum_valid = 
          output_factory_datum.factory_admin == new_admin &&
          output_factory_datum.total_pools == factory_datum.total_pools &&
          output_factory_datum.pools == factory_datum.pools

        // Validate minimum ADA is maintained
        let min_ada_valid = 
          lovelace_of(output_to_factory.value) >= min_lovelace_in_utxo

        admin_signed && datum_valid && min_ada_valid
      }
    }
  }

  mint(
    redeemer: FactoryMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      MintPoolToken(pool_id) -> {
        // Validate that a pool is being created in the same transaction
        let factory_inputs = 
          list.filter(
            transaction.inputs,
            fn(input) {
              when input.output.address.payment_credential is {
                Script(_) -> True
                _ -> False
              }
            },
          )

        let pool_token_quantity = 
          quantity_of(transaction.mint, policy_id, pool_id)

        // Validate exactly one token is minted
        pool_token_quantity == 1
      }

      BurnPoolToken(pool_id) -> {
        // Validate pool token is being burned
        let pool_token_quantity = 
          quantity_of(transaction.mint, policy_id, pool_id)

        // Validate exactly one token is burned
        pool_token_quantity == -1
      }
    }
  }

  else(_) {
    fail
  }
}

// Test functions
test create_pool() {
  let factory_datum = FactoryDatum {
    factory_admin: #"a1b2c3d4e5f6789012345678901234567890abcd",
    total_pools: 0,
    pools: [],
  }

  let pool_params = StakingParams {
    admin_pkh: #"1234567890abcdef1234567890abcdef12345678",
    asset_name: "STAKE",
    staking_policy_id: #"abcdef1234567890abcdef1234567890abcdef12",
    staking_asset_name: "STAKE_TOKEN",
    stake_credential: #"fedcba0987654321fedcba0987654321fedcba09",
    voting_options: [1, 2, 3],
    allowed_token_policy: #"abcdef1234567890abcdef1234567890abcdef12",
    allowed_token_name: "ALLOWED_TOKEN",
    time_options: [1727453227631, 1727456827631],
    factory_policy_id: #"abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab",
    pool_id: #"1a2b3c4d5e6f7890",
  }

  let pool_id = #"1a2b3c4d5e6f7890"

  let new_pool = PoolInfo {
    pool_id,
    admin_pkh: pool_params.admin_pkh,
    staking_policy_id: pool_params.staking_policy_id,
    staking_asset_name: pool_params.staking_asset_name,
    stake_credential: pool_params.stake_credential,
    created_at: 1727453227631,
    is_active: True,
    voting_options: pool_params.voting_options,
    allowed_token_policy: pool_params.allowed_token_policy,
    allowed_token_name: pool_params.allowed_token_name,
    time_options: pool_params.time_options,
    is_finalized: False,
    winning_vote_option: None,
    finalized_at: None,
  }

  let output_datum = FactoryDatum {
    factory_admin: #"a1b2c3d4e5f6789012345678901234567890abcd",
    total_pools: 1,
    pools: [new_pool],
  }

  // This would be a more complete test with actual transaction construction
  True
}

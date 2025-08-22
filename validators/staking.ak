use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{Address, Credential, Script}
use cardano/assets.{PolicyId, flatten, lovelace_of, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_input,
  find_script_outputs,
}
use constants.{min_lovelace_in_utxo}
use staking_utils.{valid_distribute_rewards, validation_logic}
use test_constants.{
  admin_pkh, asset_name, mint_policy_id, stake_credential_pkh,
  stake_script_credential, staking_address, get_collateral_asset,
  get_collateral_asset_name, get_collateral_policy_id, trader_address,
  trader_pkh,
}
use types.{
  AddStakeOrConsumeStakingRewards, AssetClass, Burn, DistributeStakingRewards,
  Mint, MintRedeemer, StakingDatum, StakingParams, StakingRedeemer,
  WithdrawStake,
}
use utils.{
  compare_stake, get_address_outputs, get_script_hash, get_upper_bound,
  get_validators_inputs,
}

validator staking(params: StakingParams) {
  spend(
    datum: Option<StakingDatum>,
    redeemer: StakingRedeemer,
    my_output_reference: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      AddStakeOrConsumeStakingRewards { vote_option, time_option } -> {
        expect Some(datum) = datum
        let signed_by_owner =
          list.has(transaction.extra_signatories, datum.owner_address_hash)

        expect Some(input_from_validator) =
          transaction.inputs
            |> transaction.find_input(my_output_reference)

        let only_one_validator_input: Bool =
          list.length(get_validators_inputs(transaction)) == 1

        let outputs_to_validator: List<Output> =
          get_address_outputs(transaction, input_from_validator.output.address)

        expect Some(output_to_validator) = list.head(outputs_to_validator)

        expect Some(output_stake_credential) =
          output_to_validator.address.stake_credential

        let stake_credential_is_valid =
          compare_stake(output_stake_credential, params.stake_credential)

        expect InlineDatum(output_datum) = output_to_validator.datum

        expect output_datum_typed: StakingDatum = output_datum

        // Validate voting and time options are allowed
        let vote_option_valid = list.has(params.voting_options, vote_option)
        let time_option_valid = list.has(params.time_options, time_option)
        
        // Calculate vote power
        let expected_vote_power = vote_option * time_option
        
        let datum_valid: Bool =
          output_datum_typed.owner_address_hash == datum.owner_address_hash && 
          output_datum_typed.staked_at == datum.staked_at && 
          output_datum_typed.mint_policy_id == datum.mint_policy_id &&
          output_datum_typed.vote_option == vote_option &&
          output_datum_typed.time_option == time_option &&
          output_datum_typed.vote_power == expected_vote_power

        let return_min_lovelace_valid =
          lovelace_of(output_to_validator.value) >= min_lovelace_in_utxo

        // Validate allowed token is being staked
        let allowed_token_present =
          quantity_of(
            output_to_validator.value,
            params.allowed_token_policy,
            params.allowed_token_name,
          ) >= 1
        
        let stake_asset_present =
          quantity_of(
            output_to_validator.value,
            params.staking_policy_id,
            params.staking_asset_name,
          ) >= 1

        let mint_asset_present =
          quantity_of(
            output_to_validator.value,
            datum.mint_policy_id,
            params.asset_name,
          ) == 1

        let owner_asset_present =
          quantity_of(
            output_to_validator.value,
            datum.mint_policy_id,
            datum.owner_address_hash,
          ) == 1

        signed_by_owner && stake_credential_is_valid && only_one_validator_input && datum_valid && return_min_lovelace_valid && allowed_token_present && stake_asset_present && mint_asset_present && owner_asset_present && vote_option_valid && time_option_valid
      }
      WithdrawStake -> {
        expect Some(datum) = datum
        let signed_by_owner =
          list.has(transaction.extra_signatories, datum.owner_address_hash)

        let mint_burnt =
          quantity_of(transaction.mint, datum.mint_policy_id, params.asset_name) == -1

        let owner_burnt =
          quantity_of(
            transaction.mint,
            datum.mint_policy_id,
            datum.owner_address_hash,
          ) == -1

        let mint_length_valid = list.length(flatten(transaction.mint)) == 2

        signed_by_owner && mint_burnt && owner_burnt && mint_length_valid
      }
      DistributeStakingRewards -> {
        expect Some(input) = find_input(transaction.inputs, my_output_reference)

        let withdrawals = transaction.withdrawals

        let own_withdrawal = input.output.address.payment_credential

        pairs.has_key(withdrawals, own_withdrawal)
      }
    }
  }

  withdraw(
    redeemer: List<(Int, Int)>,
    credential: Credential,
    transaction: Transaction,
  ) {
    expect Script(own_validator) = credential

    let admin_signed = list.has(transaction.extra_signatories, params.admin_pkh)

    let valid_distribute =
      valid_distribute_rewards(
        validation_logic,
        redeemer,
        own_validator,
        transaction,
      )

    valid_distribute && admin_signed
  }

  mint(redeemer: MintRedeemer, policy_id: PolicyId, transaction: Transaction) {
    when redeemer is {
      Mint(staking_amount) -> {
        let outputs_to_forward_contract: List<Output> =
          find_script_outputs(transaction.outputs, policy_id)

        expect Some(output_to_forward_contract) =
          list.head(outputs_to_forward_contract)

        expect InlineDatum(output_datum) = output_to_forward_contract.datum

        expect output_datum_typed: StakingDatum = output_datum

        let mint_length_valid = list.length(flatten(transaction.mint)) == 2

        let asset_minted =
          quantity_of(transaction.mint, policy_id, params.asset_name) == 1

        let owner_asset_minted =
          quantity_of(
            transaction.mint,
            policy_id,
            output_datum_typed.owner_address_hash,
          ) == 1

        let output_script_hash =
          get_script_hash(output_to_forward_contract.address)

        let output_is_to_forward_validator = output_script_hash == policy_id

        expect Some(output_to_forward_stake_credential) =
          output_to_forward_contract.address.stake_credential

        let stake_credential_is_valid =
          compare_stake(
            output_to_forward_stake_credential,
            params.stake_credential,
          )

        let signed_by_owner =
          list.has(
            transaction.extra_signatories,
            output_datum_typed.owner_address_hash,
          )
        let asset_is_valid = output_datum_typed.mint_policy_id == policy_id
        
        // Validate voting and time options are allowed
        let vote_option_valid = list.has(params.voting_options, output_datum_typed.vote_option)
        let time_option_valid = list.has(params.time_options, output_datum_typed.time_option)
        
        // Validate vote power calculation
        let expected_vote_power = output_datum_typed.vote_option * output_datum_typed.time_option
        let vote_power_valid = output_datum_typed.vote_power == expected_vote_power

        let lovelace_locked_valid =
          lovelace_of(output_to_forward_contract.value) >= min_lovelace_in_utxo

        // Validate allowed token is being staked
        let allowed_token_locked_valid =
          quantity_of(
            output_to_forward_contract.value,
            params.allowed_token_policy,
            params.allowed_token_name,
          ) == staking_amount
        
        let staking_asset_locked_valid =
          quantity_of(
            output_to_forward_contract.value,
            params.staking_policy_id,
            params.staking_asset_name,
          ) == staking_amount

        let owner_asset_locked_valid =
          quantity_of(
            output_to_forward_contract.value,
            policy_id,
            output_datum_typed.owner_address_hash,
          ) == 1

        let minted_asset_valid =
          quantity_of(
            output_to_forward_contract.value,
            policy_id,
            params.asset_name,
          ) == 1

        let last_rewarded_time_is_valid =
          get_upper_bound(transaction.validity_range) >= output_datum_typed.staked_at

        output_is_to_forward_validator && signed_by_owner && stake_credential_is_valid && last_rewarded_time_is_valid && asset_is_valid && lovelace_locked_valid && allowed_token_locked_valid && staking_asset_locked_valid && owner_asset_locked_valid && minted_asset_valid && mint_length_valid && asset_minted && owner_asset_minted && vote_option_valid && time_option_valid && vote_power_valid
      }

      Burn(owner_address_hash) -> {
        let mint_burnt =
          quantity_of(transaction.mint, policy_id, params.asset_name) == -1
        let owner_burnt =
          quantity_of(transaction.mint, policy_id, owner_address_hash) == -1

        let mint = flatten(transaction.mint)

        let mint_length_valid = list.length(mint) == 2

        mint_burnt && owner_burnt && mint_length_valid
      }
    }
  }

  else(_) {
    fail
  }
}

test mint() {
  let stake_datum =
    StakingDatum {
      owner_address_hash: trader_pkh,
      staked_at: 1727453227631,
      mint_policy_id,
      vote_option: 1,
      time_option: 2,
      vote_power: 2,
    }

  let staking_sent =
    assets.from_asset(
      get_collateral_asset.policy_id,
      get_collateral_asset.asset_name,
      1,
    )

  let mint = assets.from_asset(mint_policy_id, asset_name, 1)

  let staker_identifier_mint = assets.from_asset(mint_policy_id, trader_pkh, 1)

  let pos_out =
    Output {
      address: staking_address,
      value: mint
        |> assets.merge(staking_sent)
        |> assets.merge(staker_identifier_mint)
        |> assets.merge(assets.from_lovelace(min_lovelace_in_utxo)),
      datum: InlineDatum(stake_datum),
      reference_script: None,
    }

  let minted = assets.merge(mint, staker_identifier_mint)

  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [],
      outputs: [pos_out],
      fee: 0,
      mint: minted,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    StakingParams {
      admin_pkh: trader_pkh,
      asset_name,
      staking_policy_id: get_collateral_policy_id,
      staking_asset_name: get_collateral_asset_name,
      stake_credential: stake_credential_pkh,
      voting_options: [1, 2, 3],
      allowed_token_policy: get_collateral_policy_id,
      allowed_token_name: get_collateral_asset_name,
      time_options: [1727453227631, 1727456827631],
    }

  let redeemer = Mint(1)
  staking.mint(params, redeemer, mint_policy_id, tx)
}

test add_stake() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let stake_datum =
    StakingDatum {
      owner_address_hash: trader_pkh,
      staked_at: 1727453227631,
      mint_policy_id,
      vote_option: 1,
      time_option: 2,
      vote_power: 2,
    }

  let mint = assets.from_asset(mint_policy_id, asset_name, 1)
  let staker_identifier_mint_sent =
    assets.from_asset(mint_policy_id, trader_pkh, 1)

  let staking_sent =
    assets.from_asset(
      get_collateral_asset.policy_id,
      get_collateral_asset.asset_name,
      1,
    )

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: staking_address,
        value: mint
          |> assets.merge(staking_sent)
          |> assets.merge(staker_identifier_mint_sent)
          |> assets.merge(assets.from_lovelace(min_lovelace_in_utxo)),
        datum: InlineDatum(stake_datum),
        reference_script: None,
      },
    }

  let output =
    Output {
      address: staking_address,
      value: mint
        |> assets.merge(staking_sent)
        |> assets.merge(staker_identifier_mint_sent)
        |> assets.merge(assets.from_lovelace(min_lovelace_in_utxo)),
      datum: InlineDatum(stake_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    StakingParams {
      admin_pkh: trader_pkh,
      asset_name,
      staking_policy_id: get_collateral_policy_id,
      staking_asset_name: get_collateral_asset_name,
      stake_credential: stake_credential_pkh,
      voting_options: [1, 2, 3],
      allowed_token_policy: get_collateral_policy_id,
      allowed_token_name: get_collateral_asset_name,
      time_options: [1727453227631, 1727456827631],
    }
  let redeemer = AddStakeOrConsumeStakingRewards { vote_option: 1, time_option: 2 }
  staking.spend(params, Some(stake_datum), redeemer, own_ref, tx)
}

test consume_rewards() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let stake_datum =
    StakingDatum {
      owner_address_hash: trader_pkh,
      staked_at: 1727453227631,
      mint_policy_id,
      vote_option: 1,
      time_option: 2,
      vote_power: 2,
    }

  let mint = assets.from_asset(mint_policy_id, asset_name, 1)
  let staker_identifier_mint_sent =
    assets.from_asset(mint_policy_id, trader_pkh, 1)
  let staking_sent =
    assets.from_asset(
      get_collateral_asset.policy_id,
      get_collateral_asset.asset_name,
      10,
    )

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: staking_address,
        value: mint
          |> assets.merge(staking_sent)
          |> assets.merge(staker_identifier_mint_sent)
          |> assets.merge(assets.from_lovelace(6_000_000)),
        datum: InlineDatum(stake_datum),
        reference_script: None,
      },
    }

  let output =
    Output {
      address: staking_address,
      value: mint
        |> assets.merge(staking_sent)
        |> assets.merge(staker_identifier_mint_sent)
        |> assets.merge(assets.from_lovelace(min_lovelace_in_utxo)),
      datum: InlineDatum(stake_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    StakingParams {
      admin_pkh: trader_pkh,
      asset_name,
      staking_policy_id: get_collateral_policy_id,
      staking_asset_name: get_collateral_asset_name,
      stake_credential: stake_credential_pkh,
      voting_options: [1, 2, 3],
      allowed_token_policy: get_collateral_policy_id,
      allowed_token_name: get_collateral_asset_name,
      time_options: [1727453227631, 1727456827631],
    }
  let redeemer = AddStakeOrConsumeStakingRewards { vote_option: 1, time_option: 2 }
  staking.spend(params, Some(stake_datum), redeemer, own_ref, tx)
}

test withdraw_stake() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let stake_datum =
    StakingDatum {
      owner_address_hash: trader_pkh,
      mint_policy_id,
      vote_option: 1,
      time_option: 2,
      vote_power: 2,
      staked_at: 1727453227631,
    }

  let mint = assets.from_asset(mint_policy_id, asset_name, 1)
  let staker_identifier_mint_sent =
    assets.from_asset(mint_policy_id, trader_pkh, 1)

  let burnt_mint = assets.from_asset(mint_policy_id, asset_name, -1)
  let staker_identifier_mint_burnt =
    assets.from_asset(mint_policy_id, trader_pkh, -1)

  let staking_sent =
    assets.from_asset(
      get_collateral_asset.policy_id,
      get_collateral_asset.asset_name,
      10,
    )

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: staking_address,
        value: mint
          |> assets.merge(staking_sent)
          |> assets.merge(staker_identifier_mint_sent)
          |> assets.merge(assets.from_lovelace(6_000_000)),
        datum: InlineDatum(stake_datum),
        reference_script: None,
      },
    }

  let output =
    Output {
      address: trader_address,
      value: staking_sent
        |> assets.merge(assets.from_lovelace(6_000_000)),
      datum: InlineDatum(stake_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: burnt_mint |> assets.merge(staker_identifier_mint_burnt),
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    StakingParams {
      admin_pkh: trader_pkh,
      asset_name,
      staking_policy_id: get_collateral_policy_id,
      staking_asset_name: get_collateral_asset_name,
      stake_credential: stake_credential_pkh,
      voting_options: [1, 2, 3],
      allowed_token_policy: get_collateral_policy_id,
      allowed_token_name: get_collateral_asset_name,
      time_options: [1727453227631, 1727456827631],
    }
  let redeemer = WithdrawStake
  staking.spend(params, Some(stake_datum), redeemer, own_ref, tx)
}

test prop_withdraw_validator() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let stake_datum =
    StakingDatum {
      owner_address_hash: trader_pkh,
      mint_policy_id,
      vote_option: 1,
      time_option: 2,
      vote_power: 2,
      staked_at: 1727453227631,
    }

  let mint = assets.from_asset(mint_policy_id, asset_name, 1)
  let staker_identifier_mint_sent =
    assets.from_asset(mint_policy_id, trader_pkh, 1)

  let staking_sent =
    assets.from_asset(
      get_collateral_asset.policy_id,
      get_collateral_asset.asset_name,
      10,
    )

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: staking_address,
        value: mint
          |> assets.merge(staking_sent)
          |> assets.merge(staker_identifier_mint_sent)
          |> assets.merge(assets.from_lovelace(6_000_000)),
        datum: InlineDatum(stake_datum),
        reference_script: None,
      },
    }

  let output =
    Output {
      address: staking_address,
      value: mint
        |> assets.merge(staking_sent)
        |> assets.merge(staker_identifier_mint_sent)
        |> assets.merge(assets.from_lovelace(6_000_000)),
      datum: InlineDatum(stake_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [admin_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let redeemer = [(0, 0)]
  let params =
    StakingParams {
      admin_pkh,
      asset_name,
      staking_policy_id: get_collateral_policy_id,
      staking_asset_name: get_collateral_asset_name,
      stake_credential: stake_credential_pkh,
      voting_options: [1, 2, 3],
      allowed_token_policy: get_collateral_policy_id,
      allowed_token_name: get_collateral_asset_name,
      time_options: [1727453227631, 1727456827631],
    }
  staking.withdraw(params, redeemer, stake_script_credential, tx)
}

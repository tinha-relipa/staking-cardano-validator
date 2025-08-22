use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address.{Script}
use cardano/assets.{match}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use types.{StakingDatum}

pub fn valid_distribute_rewards(
  validation_logic: fn(Output, Output) -> Bool,
  redeemer: List<(Int, Int)>,
  own_validator: ScriptHash,
  transaction: Transaction,
) -> Bool {
  let Transaction { inputs, outputs, .. } = transaction
  let (script_inputs, script_input_count) =
    list.foldr(
      inputs,
      ([], 0),
      fn(i, acc_tuple) {
        let Input { output, .. } = i
        when output.address.payment_credential is {
          Script(script) ->
            if script == own_validator {
              let (acc, count) = acc_tuple
              ([output, ..acc], count + 1)
            } else {
              acc_tuple
            }
          _ -> acc_tuple
        }
      },
    )

  let indices: List<(Int, Int)> = redeemer
  let (_, _, input_index_count) =
    list.foldl(
      indices,
      (-1, -1, 0),
      fn(curr, acc) {
        let (in0, out0, count) = acc
        let (in1, out1) = curr
        if in1 > in0 && out1 > out0 {
          expect Some(in_utxo) = script_inputs |> list.at(in1)
          expect Some(out_utxo) = outputs |> list.at(out1)
          if validation_logic(in_utxo, out_utxo) {
            (in1, out1, count + 1)
          } else {
            fail @"Validation failed"
          }
        } else {
          fail @"Input and output indices must be in ascending orders"
        }
      },
    )
  (script_input_count == input_index_count)?
}

pub fn validation_logic(input: Output, output: Output) -> Bool {
  expect InlineDatum(input_datum) = input.datum
  expect input_datum_typed: StakingDatum = input_datum

  expect InlineDatum(output_datum) = output.datum
  expect output_datum_typed: StakingDatum = output_datum

  expect Some(output_stake_credential) = output.address.stake_credential

  expect Some(input_stake_credential) = input.address.stake_credential

  let stake_credential_is_valid =
    output_stake_credential == input_stake_credential

  let datum_valid: Bool =
    output_datum_typed.owner_address_hash == input_datum_typed.owner_address_hash && output_datum_typed.staked_at == input_datum_typed.staked_at && input_datum_typed.mint_policy_id == output_datum_typed.mint_policy_id

  let assets_match = match(output.value, input.value, >=)

  stake_credential_is_valid && datum_valid && assets_match
}

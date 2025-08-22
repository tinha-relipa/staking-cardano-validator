use aiken/collection/list
use aiken/crypto.{ScriptHash}
use aiken/interval.{Finite}
use aiken/primitive/bytearray
use cardano/address.{
  Address, Credential, Inline, Script, StakeCredential, VerificationKey,
}
use cardano/transaction.{Input, Output, Transaction, ValidityRange}

pub fn get_address_outputs(
  transaction: Transaction,
  address: Address,
) -> List<Output> {
  list.filter(transaction.outputs, fn(output) { output.address == address })
}

pub fn get_validators_inputs(transaction: Transaction) -> List<Input> {
  list.filter(
    transaction.inputs,
    fn(input) { is_script_credential(input.output.address.payment_credential) },
  )
}

pub fn is_script_credential(credential: Credential) -> Bool {
  when credential is {
    Script(_validator_hash) -> True
    _ -> False
  }
}

pub fn get_script_hash(address: Address) -> ScriptHash {
  when address.payment_credential is {
    Script(validator_hash) -> validator_hash
    _ -> fail
  }
}

pub fn get_upper_bound(range: ValidityRange) -> Int {
  expect Finite(upper_bound) = range.upper_bound.bound_type
  upper_bound
}

pub fn compare_stake(left: StakeCredential, right: ByteArray) -> Bool {
  let left =
    when left is {
      Inline(Script(x)) -> x
      Inline(VerificationKey(x)) -> x
      _ -> fail
    }

  let result = bytearray.compare(left, right)

  when result is {
    Less -> False
    Equal -> True
    Greater -> False
  }
}

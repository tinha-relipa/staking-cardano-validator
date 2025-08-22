use cardano/address.{Address, Inline, Script, StakeCredential, VerificationKey}
use types.{AssetClass}

pub const mint_policy_id =
  #"00a0b79a29bb50da169ef9ee302aa8acca1dd62ba2d7fa57331847f0"

pub const staking_script_hash =
  #"00a0b79a29bb50da169ef9ee302aa8acca1dd62ba2d7fa57331847f0"

pub const trader_pkh =
  #"d48838fee1e840857dab28a04dd88193aec8c297b85d8150c0a1f5cc"

pub const admin_pkh =
  #"6313a1d2c296eb3341e159b6c5c6991de11e81062b95108c9aa024ad"

pub const stake_credential_pkh =
  #"6313a1d2c296eb3341e159b6c5c6991de11e81062b95108c9aa024ad"

pub const get_collateral_policy_id =
  #"a5ff2c36e9eeb9655d06c0a2f02d9e200aa6f8db00d760acf62c0eba"

pub const get_collateral_asset_name = #"535452494b45"

pub const asset_name = #"53545241"

pub const mint_asset = AssetClass { policy_id: mint_policy_id, asset_name }

pub const stake_credential: StakeCredential =
  Inline(VerificationKey(stake_credential_pkh))

pub const stake_script_credential = Script(staking_script_hash)

pub const get_collateral_asset =
  AssetClass {
    policy_id: get_collateral_policy_id,
    asset_name: get_collateral_asset_name,
  }

pub const staking_address =
  Address {
    payment_credential: Script(staking_script_hash),
    stake_credential: Some(stake_credential),
  }

pub const trader_address =
  Address {
    payment_credential: VerificationKey(trader_pkh),
    stake_credential: Some(stake_credential),
  }

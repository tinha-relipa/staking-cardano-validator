1. Maximum eUTXO storage
- Problem: On-chain datum/UTXO size is limited (maximum ~14–15 KB); large participant sets or rich per-user state can exceed limits or make transactions too large/expensive.
- Goals: Keep validator datums minimal, scale to many participants, avoid re-writing large state each spend, and enable efficient claiming.

- Strategies
  - Split state across many UTXOs (sharding)
    - Partition by `(project_id, epoch)` and by user hash bucket `blake2b256(user_pubkey) mod N`.
    - Cap participants per bucket (e.g., ≤ 200 users per UTXO) to keep datum and redeemers small; when the cap is reached, open a new bucket.

2. Calculate reward for project's winners
- The calculation is based on users’ staking amounts and total reward that was sent by admin who created the project, then shared by percentage.

- Definitions
  - `P` = total reward funded by the project admin for the snapshot window.
  - `S_i` = user i’s staking amount at snapshot time.
  - `S_total = Σ S_i` over all eligible users.
  - `R_i` = user i’s reward.

- Formula (percentage-based)
  - If `S_total == 0`: no distribution; admin can withdraw the P back.
  - Otherwise: `R_i = floor(P × S_i / S_total)`.
  - Remainder `P - Σ R_i`: admin can withdraw it back.


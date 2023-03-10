DELETE FROM core.transactions;
DELETE FROM core.pot_whitelist_updated;
DELETE FROM claim.claim_period_set;
DELETE FROM claim.blacklist_set;
DELETE FROM cover.cover_created;
DELETE FROM cover.product_created;
DELETE FROM cover.cover_updated;
DELETE FROM cover.product_updated;
DELETE FROM cover.product_state_updated;
DELETE FROM cover.cover_creator_whitelist_updated;
DELETE FROM cover.cover_creation_fee_set;
DELETE FROM cover.min_cover_creation_stake_set;
DELETE FROM cover.min_stake_to_add_liquidity_set;
DELETE FROM cover.cover_initialized;
DELETE FROM cover.cover_user_whitelist_updated;
DELETE FROM reassurance.weight_set;
DELETE FROM factory.cx_token_deployed;
DELETE FROM consensus.finalized;
DELETE FROM consensus.reporting_burn_rate_set;
DELETE FROM consensus.first_reporting_stake_set;
DELETE FROM consensus.reporter_commission_set;
DELETE FROM consensus.resolved;
DELETE FROM consensus.cooldown_period_configured;
DELETE FROM consensus.report_closed;
DELETE FROM strategy.strategy_disabled;
DELETE FROM strategy.strategy_deleted;
DELETE FROM strategy.liquidity_state_update_interval_set;
DELETE FROM strategy.strategy_added;
DELETE FROM strategy.risk_pooling_period_set;
DELETE FROM strategy.max_lending_ratio_set;
DELETE FROM policy.cover_policy_rate_set;
DELETE FROM policy.coverage_lag_set;
DELETE FROM protocol.initialized;
DELETE FROM protocol.contract_added;
DELETE FROM protocol.contract_upgraded;
DELETE FROM protocol.member_added;
DELETE FROM protocol.member_removed;
DELETE FROM staking.pool_updated;
DELETE FROM staking.pool_closed;
DELETE FROM staking.deposited;
DELETE FROM staking.withdrawn;
DELETE FROM staking.rewards_withdrawn;
DELETE FROM store.pausers_set;
DELETE FROM vault.interest_accrued;
DELETE FROM vault.entered;
DELETE FROM vault.exited;
DELETE FROM factory.vault_deployed;
DELETE FROM staking.bond_pool_setup;
DELETE FROM staking.bond_created;
DELETE FROM staking.bond_claimed;
DELETE FROM cxtoken.claimed;
DELETE FROM reassurance.reassurance_added;
DELETE FROM reassurance.pool_capitalized;
DELETE FROM cover.stake_added;
DELETE FROM cover.stake_removed;
DELETE FROM cxtoken.coverage_start_set;
DELETE FROM consensus.reported;
DELETE FROM consensus.disputed;
DELETE FROM cover.fee_burned;
DELETE FROM consensus.attested;
DELETE FROM consensus.refuted;
DELETE FROM consensus.unstaken;
DELETE FROM consensus.reporter_reward_distributed;
DELETE FROM consensus.governance_burned;
DELETE FROM strategy.log_deposit;
DELETE FROM strategy.deposited;
DELETE FROM strategy.log_withdrawal;
DELETE FROM strategy.withdrawn;
DELETE FROM strategy.drained;
DELETE FROM policy.cover_purchased;
DELETE FROM vault.governance_transfer;
DELETE FROM vault.strategy_transfer;
DELETE FROM vault.strategy_receipt;
DELETE FROM vault.pods_issued;
DELETE FROM vault.pods_redeemed;
DELETE FROM vault.flash_loan_borrowed;
DELETE FROM vault.npm_staken;
DELETE FROM vault.npm_unstaken;

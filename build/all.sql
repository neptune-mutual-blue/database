CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DROP SCHEMA IF EXISTS core;
DROP SCHEMA IF EXISTS nft;
DROP SCHEMA IF EXISTS store;
DROP SCHEMA IF EXISTS protocol;
DROP SCHEMA IF EXISTS staking;
DROP SCHEMA IF EXISTS claim;
DROP SCHEMA IF EXISTS cover;
DROP SCHEMA IF EXISTS policy;
DROP SCHEMA IF EXISTS reassurance;
DROP SCHEMA IF EXISTS factory;
DROP SCHEMA IF EXISTS cxtoken;
DROP SCHEMA IF EXISTS vault;
DROP SCHEMA IF EXISTS consensus;
DROP SCHEMA IF EXISTS strategy;
DROP SCHEMA IF EXISTS ve;

DROP DOMAIN IF EXISTS tx;
DROP DOMAIN IF EXISTS bytes32;
DROP DOMAIN IF EXISTS address;
DROP DOMAIN IF EXISTS ipfs_url;
DROP DOMAIN IF EXISTS uint256;
DROP DOMAIN IF EXISTS uint8;
DROP DOMAIN IF EXISTS transaction_type;

CREATE DOMAIN bytes32 AS text;
CREATE DOMAIN address AS text;
CREATE DOMAIN ipfs_url AS text;
CREATE DOMAIN uint256 AS numeric(180, 0);
CREATE DOMAIN uint8 AS integer;

CREATE SCHEMA core;
CREATE SCHEMA store;
CREATE SCHEMA protocol;
CREATE SCHEMA staking;
CREATE SCHEMA claim;
CREATE SCHEMA cover;
CREATE SCHEMA policy;
CREATE SCHEMA reassurance;
CREATE SCHEMA factory;
CREATE SCHEMA cxtoken;
CREATE SCHEMA vault;
CREATE SCHEMA consensus;
CREATE SCHEMA strategy;
CREATE SCHEMA ve;
CREATE SCHEMA nft;


DROP TYPE IF EXISTS product_status_type CASCADE;
CREATE TYPE product_status_type AS ENUM ('Normal','Stopped','IncidentHappened','FalseReporting','Claimable');

DO 
$$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'readonlyuser') THEN
    CREATE ROLE readonlyuser NOLOGIN;
  END IF;
  
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'writeuser') THEN
    CREATE ROLE writeuser NOLOGIN;
    GRANT readonlyuser TO writeuser;
  END IF;
END
$$
LANGUAGE plpgsql;

CREATE TABLE core.locks
(
  namespace                                         text NOT NULL PRIMARY KEY,
  started_on                                        integer NOT NULL DEFAULT(extract(epoch FROM NOW() AT TIME ZONE 'UTC'))
);

CREATE TABLE core.transactions
(
  id                                                uuid PRIMARY KEY DEFAULT(gen_random_uuid()),
  transaction_hash                                  text NOT NULL,
  address                                           address /* NOT NULL */,
  block_timestamp                                   integer NOT NULL,
  block_number                                      text NOT NULL,
  transaction_sender                                address,
  chain_id                                          uint256 NOT NULL,
  transaction_stablecoin_amount                     uint256,
  transaction_npm_amount                            uint256,
  gas_price                                         uint256,
  event_name                                        text,
  coupon_code                                       text,
  ck                                                text,
  pk                                                text
);

CREATE UNIQUE INDEX transaction_hash_chain_id_uix
ON core.transactions(LOWER(transaction_hash), chain_id, LOWER(event_name));

CREATE INDEX transactions_block_timestamp_inx
ON core.transactions(block_timestamp);

CREATE INDEX transactions_block_number_inx
ON core.transactions(block_number);

CREATE INDEX transactions_chain_id_inx
ON core.transactions(chain_id);

/***************************************************************************************
event WhitelistUpdated(address indexed updatedBy, address[] accounts, bool[] statuses);
***************************************************************************************/
CREATE TABLE core.pot_whitelist_updated
(
  updated_by                                        address NOT NULL,
  accounts                                          address[] NOT NULL,
  statuses                                          bool[] NOT NULL
) INHERITS(core.transactions);

CREATE INDEX whitelist_updated_updated_by_inx
ON core.pot_whitelist_updated(updated_by);

/********************************************
event BondPoolSetup(SetupBondPoolArgs args);
********************************************/
CREATE TABLE staking.bond_pool_setup
(
  lp_token                                          address NOT NULL,
  treasury                                          address NOT NULL,
  bond_discount_rate                                uint256 NOT NULL,
  max_bond_amount                                   uint256 NOT NULL,
  vesting_term                                      uint256 NOT NULL,
  npm_to_top_up_now                                 uint256 NOT NULL
) INHERITS(core.transactions);

/****************************************************************************************************
event BondCreated(address indexed account, uint256 lpTokens, uint256 npmToVest, uint256 unlockDate);
****************************************************************************************************/
CREATE TABLE staking.bond_created
(
  account                                           address NOT NULL,
  lp_tokens                                         uint256 NOT NULL,
  npm_to_vest                                       uint256 NOT NULL,
  unlock_date                                       uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX bond_created_account_inx
ON staking.bond_created(account);

/***********************************************************
event BondClaimed(address indexed account, uint256 amount);
***********************************************************/
CREATE TABLE staking.bond_claimed
(
  account                                           address NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX bond_claimed_account_inx
ON staking.bond_claimed(account);

/*************************************************************************************************************************************************************************************************************************
event Claimed(address cxToken,bytes32 indexed coverKey,bytes32 indexed productKey, uint256 incidentDate,address indexed account,address reporter,uint256 amount,uint256 reporterFee,uint256 platformFee,uint256 claimed);
*************************************************************************************************************************************************************************************************************************/
CREATE TABLE cxtoken.claimed
(
  cx_token                                          address NOT NULL,
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  incident_date                                     uint256 NOT NULL,
  account                                           address NOT NULL,
  reporter                                          address NOT NULL,
  amount                                            uint256 NOT NULL,
  reporter_fee                                      uint256 NOT NULL,
  platform_fee                                      uint256 NOT NULL,
  claimed                                           uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX claimed_cover_key_inx
ON cxtoken.claimed(cover_key);

CREATE INDEX claimed_product_key_inx
ON cxtoken.claimed(product_key);

CREATE INDEX claimed_account_inx
ON cxtoken.claimed(account);

/**********************************************************************************
event ClaimPeriodSet(bytes32 indexed coverKey, uint256 previous, uint256 current);
**********************************************************************************/
CREATE TABLE claim.claim_period_set
(
  cover_key                                         bytes32 NOT NULL,
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX claim_period_set_cover_key_inx
ON claim.claim_period_set(cover_key);

/*************************************************************************************************************************************
event BlacklistSet(bytes32 indexed coverKey, bytes32 indexed productKey, uint256 indexed incidentDate, address account, bool status);
*************************************************************************************************************************************/
CREATE TABLE claim.blacklist_set
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  incident_date                                     uint256 NOT NULL,
  account                                           address NOT NULL,
  status                                            bool NOT NULL
) INHERITS(core.transactions);

CREATE INDEX blacklist_set_cover_key_inx
ON claim.blacklist_set(cover_key);

CREATE INDEX blacklist_set_product_key_inx
ON claim.blacklist_set(product_key);

CREATE INDEX blacklist_set_incident_date_inx
ON claim.blacklist_set(incident_date);

/***************************************************************************************************************************************************************
event CoverCreated(bytes32 indexed coverKey, string info, string tokenName, string tokenSymbol, bool indexed supportsProducts, bool indexed requiresWhitelist);
***************************************************************************************************************************************************************/
CREATE TABLE cover.cover_created
(
  cover_key                                         bytes32 NOT NULL,
  info                                              text NOT NULL,
  token_name                                        text NOT NULL,
  token_symbol                                      text NOT NULL,
  supports_products                                 bool NOT NULL,
  requires_whitelist                                bool NOT NULL
) INHERITS(core.transactions);

CREATE INDEX cover_created_cover_key_inx
ON cover.cover_created(cover_key);

CREATE INDEX cover_created_supports_products_inx
ON cover.cover_created(supports_products);

CREATE INDEX cover_created_requires_whitelist_inx
ON cover.cover_created(requires_whitelist);

/********************************************************************************
event ProductCreated(bytes32 indexed coverKey, bytes32 productKey, string info);
********************************************************************************/
CREATE TABLE cover.product_created
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  info                                              text NOT NULL
) INHERITS(core.transactions);

CREATE INDEX product_created_cover_key_inx
ON cover.product_created(cover_key);

/**********************************************************
event CoverUpdated(bytes32 indexed coverKey, string info);
**********************************************************/
CREATE TABLE cover.cover_updated
(
  cover_key                                         bytes32 NOT NULL,
  info                                              text NOT NULL
) INHERITS(core.transactions);

CREATE INDEX cover_updated_cover_key_inx
ON cover.cover_updated(cover_key);

/********************************************************************************
event ProductUpdated(bytes32 indexed coverKey, bytes32 productKey, string info);
********************************************************************************/
CREATE TABLE cover.product_updated
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  info                                              text NOT NULL
) INHERITS(core.transactions);

CREATE INDEX product_updated_cover_key_inx
ON cover.product_updated(cover_key);

/***************************************************************************************************************************************
event ProductStateUpdated(bytes32 indexed coverKey, bytes32 indexed productKey, address indexed updatedBy, bool status, string reason);
***************************************************************************************************************************************/
CREATE TABLE cover.product_state_updated
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  updated_by                                        address NOT NULL,
  status                                            bool NOT NULL,
  reason                                            text NOT NULL
) INHERITS(core.transactions);

CREATE INDEX product_state_updated_cover_key_inx
ON cover.product_state_updated(cover_key);

CREATE INDEX product_state_updated_product_key_inx
ON cover.product_state_updated(product_key);

CREATE INDEX product_state_updated_updated_by_inx
ON cover.product_state_updated(updated_by);

/*****************************************************************
event CoverCreatorWhitelistUpdated(address account, bool status);
*****************************************************************/
CREATE TABLE cover.cover_creator_whitelist_updated
(
  account                                           address NOT NULL,
  status                                            bool NOT NULL
) INHERITS(core.transactions);

/*************************************************************
event CoverCreationFeeSet(uint256 previous, uint256 current);
*************************************************************/
CREATE TABLE cover.cover_creation_fee_set
(
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL
) INHERITS(core.transactions);

/******************************************************************
event MinCoverCreationStakeSet(uint256 previous, uint256 current);
******************************************************************/
CREATE TABLE cover.min_cover_creation_stake_set
(
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL
) INHERITS(core.transactions);

/*******************************************************************
event MinStakeToAddLiquiditySet(uint256 previous, uint256 current);
*******************************************************************/
CREATE TABLE cover.min_stake_to_add_liquidity_set
(
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL
) INHERITS(core.transactions);

/*********************************************************************
event CoverInitialized(address indexed stablecoin, bytes32 withName);
*********************************************************************/
CREATE TABLE cover.cover_initialized
(
  stablecoin                                        address NOT NULL,
  with_name                                         bytes32 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX cover_initialized_stablecoin_inx
ON cover.cover_initialized(stablecoin);

/****************************************************************************************************************************
event CoverUserWhitelistUpdated(bytes32 indexed coverKey, bytes32 indexed productKey, address indexed account, bool status);
****************************************************************************************************************************/
CREATE TABLE cover.cover_user_whitelist_updated
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  account                                           address NOT NULL,
  status                                            bool NOT NULL
) INHERITS(core.transactions);

CREATE INDEX cover_user_whitelist_updated_cover_key_inx
ON cover.cover_user_whitelist_updated(cover_key);

CREATE INDEX cover_user_whitelist_updated_product_key_inx
ON cover.cover_user_whitelist_updated(product_key);

CREATE INDEX cover_user_whitelist_updated_account_inx
ON cover.cover_user_whitelist_updated(account);

/*********************************************************************************************
event ReassuranceAdded(bytes32 indexed coverKey, address indexed onBehalfOf, uint256 amount);
*********************************************************************************************/
CREATE TABLE reassurance.reassurance_added
(
  cover_key                                         bytes32 NOT NULL,
  on_behalf_of                                      address NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX reassurance_added_cover_key_inx
ON reassurance.reassurance_added(cover_key);

CREATE INDEX reassurance_added_on_behalf_of_inx
ON reassurance.reassurance_added(on_behalf_of);

/**********************************************************
event WeightSet(bytes32 indexed coverKey, uint256 weight);
**********************************************************/
CREATE TABLE reassurance.weight_set
(
  cover_key                                         bytes32 NOT NULL,
  weight                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX weight_set_cover_key_inx
ON reassurance.weight_set(cover_key);

/**************************************************************************************************************************
event PoolCapitalized(bytes32 indexed coverKey, bytes32 indexed productKey, uint256 indexed incidentDate, uint256 amount);
**************************************************************************************************************************/
CREATE TABLE reassurance.pool_capitalized
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  incident_date                                     uint256 NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX pool_capitalized_cover_key_inx
ON reassurance.pool_capitalized(cover_key);

CREATE INDEX pool_capitalized_product_key_inx
ON reassurance.pool_capitalized(product_key);

CREATE INDEX pool_capitalized_incident_date_inx
ON reassurance.pool_capitalized(incident_date);

/************************************************************************************
event StakeAdded(bytes32 indexed coverKey, address indexed account, uint256 amount);
************************************************************************************/
CREATE TABLE cover.stake_added
(
  cover_key                                         bytes32 NOT NULL,
  account                                           address NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX stake_added_cover_key_inx
ON cover.stake_added(cover_key);

CREATE INDEX stake_added_account_inx
ON cover.stake_added(account);

/**************************************************************************************
event StakeRemoved(bytes32 indexed coverKey, address indexed account, uint256 amount);
**************************************************************************************/
CREATE TABLE cover.stake_removed
(
  cover_key                                         bytes32 NOT NULL,
  account                                           address NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX stake_removed_cover_key_inx
ON cover.stake_removed(cover_key);

CREATE INDEX stake_removed_account_inx
ON cover.stake_removed(account);

/**********************************************************
event FeeBurned(bytes32 indexed coverKey, uint256 amount);
**********************************************************/
CREATE TABLE cover.fee_burned
(
  cover_key                                         bytes32 NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX fee_burned_cover_key_inx
ON cover.fee_burned(cover_key);

/***************************************************************************************************************************************
event CoverageStartSet(uint256 policyId, bytes32 coverKey, bytes32 productKey, address account, uint256 effectiveFrom, uint256 amount);
***************************************************************************************************************************************/
CREATE TABLE cxtoken.coverage_start_set
(
  policy_id                                         uint256 NOT NULL,
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  account                                           address NOT NULL,
  effective_from                                    uint256 NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

/*********************************************************************************************************************************************************
event CxTokenDeployed(address cxToken, IStore store, bytes32 indexed coverKey, bytes32 indexed productKey, string tokenName, uint256 indexed expiryDate);
*********************************************************************************************************************************************************/
CREATE TABLE factory.cx_token_deployed
(
  cx_token                                          address NOT NULL,
  store                                             address NOT NULL,
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  token_name                                        text NOT NULL,
  expiry_date                                       uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX cx_token_deployed_cover_key_inx
ON factory.cx_token_deployed(cover_key);

CREATE INDEX cx_token_deployed_product_key_inx
ON factory.cx_token_deployed(product_key);

CREATE INDEX cx_token_deployed_expiry_date_inx
ON factory.cx_token_deployed(expiry_date);

/***********************************************************************************************************************
event Finalized(bytes32 indexed coverKey, bytes32 indexed productKey, address finalizer, uint256 indexed incidentDate);
***********************************************************************************************************************/
CREATE TABLE consensus.finalized
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  finalizer                                         address NOT NULL,
  incident_date                                     uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX finalized_cover_key_inx
ON consensus.finalized(cover_key);

CREATE INDEX finalized_product_key_inx
ON consensus.finalized(product_key);

CREATE INDEX finalized_incident_date_inx
ON consensus.finalized(incident_date);

/*************************************************************************************************************************************************************************************
event Reported(bytes32 indexed coverKey, bytes32 indexed productKey, address reporter, uint256 indexed incidentDate, string info, uint256 initialStake, uint256 resolutionTimestamp);
*************************************************************************************************************************************************************************************/
CREATE TABLE consensus.reported
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  reporter                                          address NOT NULL,
  incident_date                                     uint256 NOT NULL,
  info                                              text NOT NULL,
  initial_stake                                     uint256 NOT NULL,
  resolution_timestamp                              uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX reported_cover_key_inx
ON consensus.reported(cover_key);

CREATE INDEX reported_product_key_inx
ON consensus.reported(product_key);

CREATE INDEX reported_incident_date_inx
ON consensus.reported(incident_date);

/********************************************************************************************************************************************************
event Disputed(bytes32 indexed coverKey, bytes32 indexed productKey, address reporter, uint256 indexed incidentDate, string info, uint256 initialStake);
********************************************************************************************************************************************************/
CREATE TABLE consensus.disputed
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  reporter                                          address NOT NULL,
  incident_date                                     uint256 NOT NULL,
  info                                              text NOT NULL,
  initial_stake                                     uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX disputed_cover_key_inx
ON consensus.disputed(cover_key);

CREATE INDEX disputed_product_key_inx
ON consensus.disputed(product_key);

CREATE INDEX disputed_incident_date_inx
ON consensus.disputed(incident_date);

/**************************************************************
event ReportingBurnRateSet(uint256 previous, uint256 current);
**************************************************************/
CREATE TABLE consensus.reporting_burn_rate_set
(
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL
) INHERITS(core.transactions);

/**********************************************************************************
event FirstReportingStakeSet(bytes32 coverKey, uint256 previous, uint256 current);
**********************************************************************************/
CREATE TABLE consensus.first_reporting_stake_set
(
  cover_key                                         bytes32 NOT NULL,
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL
) INHERITS(core.transactions);

/***************************************************************
event ReporterCommissionSet(uint256 previous, uint256 current);
***************************************************************/
CREATE TABLE consensus.reporter_commission_set
(
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL
) INHERITS(core.transactions);

/***********************************************************************************************************************************
event Attested(bytes32 indexed coverKey, bytes32 indexed productKey, address witness, uint256 indexed incidentDate, uint256 stake);
***********************************************************************************************************************************/
CREATE TABLE consensus.attested
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  witness                                           address NOT NULL,
  incident_date                                     uint256 NOT NULL,
  stake                                             uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX attested_cover_key_inx
ON consensus.attested(cover_key);

CREATE INDEX attested_product_key_inx
ON consensus.attested(product_key);

CREATE INDEX attested_incident_date_inx
ON consensus.attested(incident_date);

/**********************************************************************************************************************************
event Refuted(bytes32 indexed coverKey, bytes32 indexed productKey, address witness, uint256 indexed incidentDate, uint256 stake);
**********************************************************************************************************************************/
CREATE TABLE consensus.refuted
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  witness                                           address NOT NULL,
  incident_date                                     uint256 NOT NULL,
  stake                                             uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX refuted_cover_key_inx
ON consensus.refuted(cover_key);

CREATE INDEX refuted_product_key_inx
ON consensus.refuted(product_key);

CREATE INDEX refuted_incident_date_inx
ON consensus.refuted(incident_date);

/************************************************************************************************************************************
event Unstaken(bytes32 indexed coverKey, bytes32 indexed productKey, address indexed caller, uint256 originalStake, uint256 reward);
************************************************************************************************************************************/
CREATE TABLE consensus.unstaken
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  caller                                            address NOT NULL,
  original_stake                                    uint256 NOT NULL,
  reward                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX unstaken_cover_key_inx
ON consensus.unstaken(cover_key);

CREATE INDEX unstaken_product_key_inx
ON consensus.unstaken(product_key);

CREATE INDEX unstaken_caller_inx
ON consensus.unstaken(caller);

/********************************************************************************************************************************************************************************
event ReporterRewardDistributed(bytes32 indexed coverKey, bytes32 indexed productKey, address caller, address indexed reporter, uint256 originalReward, uint256 reporterReward);
********************************************************************************************************************************************************************************/
CREATE TABLE consensus.reporter_reward_distributed
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  caller                                            address NOT NULL,
  reporter                                          address NOT NULL,
  original_reward                                   uint256 NOT NULL,
  reporter_reward                                   uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX reporter_reward_distributed_cover_key_inx
ON consensus.reporter_reward_distributed(cover_key);

CREATE INDEX reporter_reward_distributed_product_key_inx
ON consensus.reporter_reward_distributed(product_key);

CREATE INDEX reporter_reward_distributed_reporter_inx
ON consensus.reporter_reward_distributed(reporter);

/*******************************************************************************************************************************************************************
event GovernanceBurned(bytes32 indexed coverKey, bytes32 indexed productKey, address caller, address indexed burner, uint256 originalReward, uint256 burnedAmount);
*******************************************************************************************************************************************************************/
CREATE TABLE consensus.governance_burned
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  caller                                            address NOT NULL,
  burner                                            address NOT NULL,
  original_reward                                   uint256 NOT NULL,
  burned_amount                                     uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX governance_burned_cover_key_inx
ON consensus.governance_burned(cover_key);

CREATE INDEX governance_burned_product_key_inx
ON consensus.governance_burned(product_key);

CREATE INDEX governance_burned_burner_inx
ON consensus.governance_burned(burner);

/*******************************************************************************************************************************************************************************************************
event Resolved(bytes32 indexed coverKey, bytes32 indexed productKey, uint256 incidentDate, uint256 resolutionDeadline, bool decision, bool emergency, uint256 claimBeginsFrom, uint256 claimExpiresAt);
*******************************************************************************************************************************************************************************************************/
CREATE TABLE consensus.resolved
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  incident_date                                     uint256 NOT NULL,
  resolution_deadline                               uint256 NOT NULL,
  decision                                          bool NOT NULL,
  emergency                                         bool NOT NULL,
  claim_begins_from                                 uint256 NOT NULL,
  claim_expires_at                                  uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX resolved_cover_key_inx
ON consensus.resolved(cover_key);

CREATE INDEX resolved_product_key_inx
ON consensus.resolved(product_key);

/*************************************************************************
event CooldownPeriodConfigured(bytes32 indexed coverKey, uint256 period);
*************************************************************************/
CREATE TABLE consensus.cooldown_period_configured
(
  cover_key                                         bytes32 NOT NULL,
  period                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX cooldown_period_configured_cover_key_inx
ON consensus.cooldown_period_configured(cover_key);

/*************************************************************************************************************************
event ReportClosed(bytes32 indexed coverKey, bytes32 indexed productKey, address indexed closedBy, uint256 incidentDate);
*************************************************************************************************************************/
CREATE TABLE consensus.report_closed
(
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  closed_by                                         address NOT NULL,
  incident_date                                     uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX report_closed_cover_key_inx
ON consensus.report_closed(cover_key);

CREATE INDEX report_closed_product_key_inx
ON consensus.report_closed(product_key);

CREATE INDEX report_closed_closed_by_inx
ON consensus.report_closed(closed_by);

/****************************************************************************************************************************************************
event LogDeposit(bytes32 indexed name, uint256 counter, uint256 amount, uint256 certificateReceived, uint256 depositTotal, uint256 withdrawalTotal);
****************************************************************************************************************************************************/
CREATE TABLE strategy.log_deposit
(
  name                                              bytes32 NOT NULL,
  counter                                           uint256 NOT NULL,
  amount                                            uint256 NOT NULL,
  certificate_received                              uint256 NOT NULL,
  deposit_total                                     uint256 NOT NULL,
  withdrawal_total                                  uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX log_deposit_name_inx
ON strategy.log_deposit(name);

/******************************************************************************************************************************
event Deposited(bytes32 indexed key, address indexed onBehalfOf, uint256 stablecoinDeposited, uint256 certificateTokenIssued);
******************************************************************************************************************************/
CREATE TABLE strategy.deposited
(
  key                                               bytes32 NOT NULL,
  on_behalf_of                                      address NOT NULL,
  stablecoin_deposited                              uint256 NOT NULL,
  certificate_token_issued                          uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX deposited_key_inx
ON strategy.deposited(key);

CREATE INDEX deposited_on_behalf_of_inx
ON strategy.deposited(on_behalf_of);

/********************************************************************************************************************************************************************
event LogWithdrawal(bytes32 indexed name, uint256 counter, uint256 stablecoinWithdrawn, uint256 certificateRedeemed, uint256 depositTotal, uint256 withdrawalTotal);
********************************************************************************************************************************************************************/
CREATE TABLE strategy.log_withdrawal
(
  name                                              bytes32 NOT NULL,
  counter                                           uint256 NOT NULL,
  stablecoin_withdrawn                              uint256 NOT NULL,
  certificate_redeemed                              uint256 NOT NULL,
  deposit_total                                     uint256 NOT NULL,
  withdrawal_total                                  uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX log_withdrawal_name_inx
ON strategy.log_withdrawal(name);

/****************************************************************************************************************************
event Withdrawn(bytes32 indexed key, address indexed sendTo, uint256 stablecoinWithdrawn, uint256 certificateTokenRedeemed);
****************************************************************************************************************************/
CREATE TABLE strategy.withdrawn
(
  key                                               bytes32 NOT NULL,
  send_to                                           address NOT NULL,
  stablecoin_withdrawn                              uint256 NOT NULL,
  certificate_token_redeemed                        uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX withdrawn_key_inx
ON strategy.withdrawn(key);

CREATE INDEX withdrawn_send_to_inx
ON strategy.withdrawn(send_to);

/****************************************************
event Drained(IERC20 indexed asset, uint256 amount);
****************************************************/
CREATE TABLE strategy.drained
(
  asset                                             address NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX drained_asset_inx
ON strategy.drained(asset);



/*************************************************
event StrategyDisabled(address indexed strategy);
*************************************************/
CREATE TABLE strategy.strategy_disabled
(
  strategy                                          address NOT NULL
) INHERITS(core.transactions);

CREATE INDEX strategy_disabled_strategy_inx
ON strategy.strategy_disabled(strategy);

/************************************************
event StrategyDeleted(address indexed strategy);
************************************************/
CREATE TABLE strategy.strategy_deleted
(
  strategy                                          address NOT NULL
) INHERITS(core.transactions);

CREATE INDEX strategy_deleted_strategy_inx
ON strategy.strategy_deleted(strategy);

/********************************************************
event LiquidityStateUpdateIntervalSet(uint256 duration);
********************************************************/
CREATE TABLE strategy.liquidity_state_update_interval_set
(
  duration                                          uint256 NOT NULL
) INHERITS(core.transactions);

/**********************************************
event StrategyAdded(address indexed strategy);
**********************************************/
CREATE TABLE strategy.strategy_added
(
  strategy                                          address NOT NULL
) INHERITS(core.transactions);

CREATE INDEX strategy_added_strategy_inx
ON strategy.strategy_added(strategy);

/*************************************************************************************************
event RiskPoolingPeriodSet(bytes32 indexed key, uint256 lendingPeriod, uint256 withdrawalWindow);
*************************************************************************************************/
CREATE TABLE strategy.risk_pooling_period_set
(
  key                                               bytes32 NOT NULL,
  lending_period                                    uint256 NOT NULL,
  withdrawal_window                                 uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX risk_pooling_period_set_key_inx
ON strategy.risk_pooling_period_set(key);

/****************************************
event MaxLendingRatioSet(uint256 ratio);
****************************************/
CREATE TABLE strategy.max_lending_ratio_set
(
  ratio                                             uint256 NOT NULL
) INHERITS(core.transactions);

/*********************************************************************************************************************************************
event CoverPurchased(PurchaseCoverArgs args, address indexed cxToken, uint256 fee, uint256 platformFee, uint256 expiresOn, uint256 policyId);
*********************************************************************************************************************************************/
CREATE TABLE policy.cover_purchased
(
  on_behalf_of                                      address NOT NULL,
  cover_key                                         bytes32 NOT NULL,
  product_key                                       bytes32 NOT NULL,
  cover_duration                                    uint256 NOT NULL,
  amount_to_cover                                   uint256 NOT NULL,
  referral_code                                     bytes32 NOT NULL,
  cx_token                                          address NOT NULL,
  fee                                               uint256 NOT NULL,
  platform_fee                                      uint256 NOT NULL,
  expires_on                                        uint256 NOT NULL,
  policy_id                                         uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX cover_purchased_cx_token_inx
ON policy.cover_purchased(cx_token);

CREATE INDEX cover_purchased_on_behalf_of_inx
ON policy.cover_purchased(on_behalf_of);

CREATE INDEX cover_purchased_cover_key_inx
ON policy.cover_purchased(cover_key);

CREATE INDEX cover_purchased_product_key_inx
ON policy.cover_purchased(product_key);

CREATE INDEX cover_purchased_cover_duration_inx
ON policy.cover_purchased(cover_duration);

CREATE INDEX cover_purchased_referral_code_inx
ON policy.cover_purchased(referral_code);

CREATE INDEX cover_purchased_expires_on_inx
ON policy.cover_purchased(expires_on);

CREATE INDEX cover_purchased_policy_id_inx
ON policy.cover_purchased(policy_id);

/***********************************************************************************
event CoverPolicyRateSet(bytes32 indexed coverKey, uint256 floor, uint256 ceiling);
***********************************************************************************/
CREATE TABLE policy.cover_policy_rate_set
(
  cover_key                                         bytes32 NOT NULL,
  floor                                             uint256 NOT NULL,
  ceiling                                           uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX cover_policy_rate_set_cover_key_inx
ON policy.cover_policy_rate_set(cover_key);

/***************************************************************
event CoverageLagSet(bytes32 indexed coverKey, uint256 window);
***************************************************************/
CREATE TABLE policy.coverage_lag_set
(
  cover_key                                         bytes32 NOT NULL,
  "window"                                          uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX coverage_lag_set_cover_key_inx
ON policy.coverage_lag_set(cover_key);

/***************************************
event Initialized(InitializeArgs args);
***************************************/
CREATE TABLE protocol.initialized
(
  burner                                            address NOT NULL,
  uniswap_v2_router_like                            address NOT NULL,
  uniswap_v2_factory_like                           address NOT NULL,
  npm                                               address NOT NULL,
  treasury                                          address NOT NULL,
  price_oracle                                      address NOT NULL,
  cover_creation_fee                                uint256 NOT NULL,
  min_cover_creation_stake                          uint256 NOT NULL,
  min_stake_to_add_liquidity                        uint256 NOT NULL,
  first_reporting_stake                             uint256 NOT NULL,
  claim_period                                      uint256 NOT NULL,
  reporting_burn_rate                               uint256 NOT NULL,
  governance_reporter_commission                    uint256 NOT NULL,
  claim_platform_fee                                uint256 NOT NULL,
  claim_reporter_commission                         uint256 NOT NULL,
  flash_loan_fee                                    uint256 NOT NULL,
  flash_loan_fee_protocol                           uint256 NOT NULL,
  resolution_cool_down_period                       uint256 NOT NULL,
  state_update_interval                             uint256 NOT NULL,
  max_lending_ratio                                 uint256 NOT NULL,
  lending_period                                    uint256 NOT NULL,
  withdrawal_window                                 uint256 NOT NULL,
  policy_floor                                      uint256 NOT NULL,
  policy_ceiling                                    uint256 NOT NULL
) INHERITS(core.transactions);


/*****************************************************************************************************
event ContractAdded(bytes32 indexed namespace, bytes32 indexed key, address indexed contractAddress);
*****************************************************************************************************/
CREATE TABLE protocol.contract_added
(
  namespace                                         bytes32 NOT NULL,
  key                                               bytes32 NOT NULL,
  contract_address                                  address NOT NULL
) INHERITS(core.transactions);

CREATE INDEX contract_added_namespace_inx
ON protocol.contract_added(namespace);

CREATE INDEX contract_added_key_inx
ON protocol.contract_added(key);

CREATE INDEX contract_added_contract_address_inx
ON protocol.contract_added(contract_address);

/******************************************************************************************************************
event ContractUpgraded(bytes32 indexed namespace, bytes32 indexed key, address previous, address indexed current);
******************************************************************************************************************/
CREATE TABLE protocol.contract_upgraded
(
  namespace                                         bytes32 NOT NULL,
  key                                               bytes32 NOT NULL,
  previous                                          address NOT NULL,
  current                                           address NOT NULL
) INHERITS(core.transactions);

CREATE INDEX contract_upgraded_namespace_inx
ON protocol.contract_upgraded(namespace);

CREATE INDEX contract_upgraded_key_inx
ON protocol.contract_upgraded(key);

CREATE INDEX contract_upgraded_current_inx
ON protocol.contract_upgraded(current);

/**********************************
event MemberAdded(address member);
**********************************/
CREATE TABLE protocol.member_added
(
  member                                            address NOT NULL
) INHERITS(core.transactions);

/************************************
event MemberRemoved(address member);
************************************/
CREATE TABLE protocol.member_removed
(
  member                                            address NOT NULL
) INHERITS(core.transactions);

/***************************************************************
event PoolUpdated(bytes32 indexed key, AddOrEditPoolArgs args);
***************************************************************/
CREATE TABLE staking.pool_updated
(
  key                                               bytes32 NOT NULL,
  name                                              text NOT NULL,
  pool_type                                         smallint NOT NULL,
  staking_token                                     address NOT NULL,
  uni_staking_token_dollar_pair                     address NOT NULL,
  reward_token                                      address NOT NULL,
  uni_reward_token_dollar_pair                      address NOT NULL,
  staking_target                                    uint256 NOT NULL,
  max_stake                                         uint256 NOT NULL,
  platform_fee                                      uint256 NOT NULL,
  reward_per_block                                  uint256 NOT NULL,
  lockup_period                                     uint256 NOT NULL,
  reward_token_to_deposit                           uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX pool_updated_key_inx
ON staking.pool_updated(key);

/***************************************************
event PoolClosed(bytes32 indexed key, string name);
***************************************************/
CREATE TABLE staking.pool_closed
(
  key                                               bytes32 NOT NULL,
  name                                              text NOT NULL
) INHERITS(core.transactions);

CREATE INDEX pool_closed_key_inx
ON staking.pool_closed(key);

/*****************************************************************************************************
event Deposited(bytes32 indexed key, address indexed account, address indexed token, uint256 amount);
*****************************************************************************************************/
CREATE TABLE staking.deposited
(
  key                                               bytes32 NOT NULL,
  account                                           address NOT NULL,
  token                                             address NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX deposited_key_inx
ON staking.deposited(key);

CREATE INDEX deposited_account_inx
ON staking.deposited(account);

CREATE INDEX deposited_token_inx
ON staking.deposited(token);

/*****************************************************************************************************
event Withdrawn(bytes32 indexed key, address indexed account, address indexed token, uint256 amount);
*****************************************************************************************************/
CREATE TABLE staking.withdrawn
(
  key                                               bytes32 NOT NULL,
  account                                           address NOT NULL,
  token                                             address NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX withdrawn_key_inx
ON staking.withdrawn(key);

CREATE INDEX withdrawn_account_inx
ON staking.withdrawn(account);

CREATE INDEX withdrawn_token_inx
ON staking.withdrawn(token);

/**********************************************************************************************************************************
event RewardsWithdrawn(bytes32 indexed key, address indexed account, address indexed token, uint256 rewards, uint256 platformFee);
**********************************************************************************************************************************/
CREATE TABLE staking.rewards_withdrawn
(
  key                                               bytes32 NOT NULL,
  account                                           address NOT NULL,
  token                                             address NOT NULL,
  rewards                                           uint256 NOT NULL,
  platform_fee                                      uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX rewards_withdrawn_key_inx
ON staking.rewards_withdrawn(key);

CREATE INDEX rewards_withdrawn_account_inx
ON staking.rewards_withdrawn(account);

CREATE INDEX rewards_withdrawn_token_inx
ON staking.rewards_withdrawn(token);

/*******************************************************************************
event PausersSet(address indexed addedBy, address[] accounts, bool[] statuses);
*******************************************************************************/
CREATE TABLE store.pausers_set
(
  added_by                                          address NOT NULL,
  accounts                                          address[] NOT NULL,
  statuses                                          bool[] NOT NULL
) INHERITS(core.transactions);

CREATE INDEX pausers_set_added_by_inx
ON store.pausers_set(added_by);

/*************************************************************
event GovernanceTransfer(address indexed to, uint256 amount);
*************************************************************/
CREATE TABLE vault.governance_transfer
(
  "to"                                              address NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX governance_transfer_to_inx
ON vault.governance_transfer("to");

/**************************************************************************************************************
event StrategyTransfer(address indexed token, address indexed strategy, bytes32 indexed name, uint256 amount);
**************************************************************************************************************/
CREATE TABLE vault.strategy_transfer
(
  token                                             address NOT NULL,
  strategy                                          address NOT NULL,
  name                                              bytes32 NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX strategy_transfer_token_inx
ON vault.strategy_transfer(token);

CREATE INDEX strategy_transfer_strategy_inx
ON vault.strategy_transfer(strategy);

CREATE INDEX strategy_transfer_name_inx
ON vault.strategy_transfer(name);

/*******************************************************************************************************************************************
event StrategyReceipt(address indexed token, address indexed strategy, bytes32 indexed name, uint256 amount, uint256 income, uint256 loss);
*******************************************************************************************************************************************/
CREATE TABLE vault.strategy_receipt
(
  token                                             address NOT NULL,
  strategy                                          address NOT NULL,
  name                                              bytes32 NOT NULL,
  amount                                            uint256 NOT NULL,
  income                                            uint256 NOT NULL,
  loss                                              uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX strategy_receipt_token_inx
ON vault.strategy_receipt(token);

CREATE INDEX strategy_receipt_strategy_inx
ON vault.strategy_receipt(strategy);

CREATE INDEX strategy_receipt_name_inx
ON vault.strategy_receipt(name);

/****************************************************************************************************************
event PodsIssued(address indexed account, uint256 issued, uint256 liquidityAdded, bytes32 indexed referralCode);
****************************************************************************************************************/
CREATE TABLE vault.pods_issued
(
  account                                           address NOT NULL,
  issued                                            uint256 NOT NULL,
  liquidity_added                                   uint256 NOT NULL,
  referral_code                                     bytes32 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX pods_issued_account_inx
ON vault.pods_issued(account);

CREATE INDEX pods_issued_referral_code_inx
ON vault.pods_issued(referral_code);

/*****************************************************************************************
event PodsRedeemed(address indexed account, uint256 redeemed, uint256 liquidityReleased);
*****************************************************************************************/
CREATE TABLE vault.pods_redeemed
(
  account                                           address NOT NULL,
  redeemed                                          uint256 NOT NULL,
  liquidity_released                                uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX pods_redeemed_account_inx
ON vault.pods_redeemed(account);

/***********************************************************************************************************************************
event FlashLoanBorrowed(address indexed lender, address indexed borrower, address indexed stablecoin, uint256 amount, uint256 fee);
***********************************************************************************************************************************/
CREATE TABLE vault.flash_loan_borrowed
(
  lender                                            address NOT NULL,
  borrower                                          address NOT NULL,
  stablecoin                                        address NOT NULL,
  amount                                            uint256 NOT NULL,
  fee                                               uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX flash_loan_borrowed_lender_inx
ON vault.flash_loan_borrowed(lender);

CREATE INDEX flash_loan_borrowed_borrower_inx
ON vault.flash_loan_borrowed(borrower);

CREATE INDEX flash_loan_borrowed_stablecoin_inx
ON vault.flash_loan_borrowed(stablecoin);

/*********************************************************
event NpmStaken(address indexed account, uint256 amount);
*********************************************************/
CREATE TABLE vault.npm_staken
(
  account                                         address NOT NULL,
  amount                                          uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX npm_staken_account_inx
ON vault.npm_staken(account);

/***********************************************************
event NpmUnstaken(address indexed account, uint256 amount);
***********************************************************/
CREATE TABLE vault.npm_unstaken
(
  account                                         address NOT NULL,
  amount                                          uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX npm_unstaken_account_inx
ON vault.npm_unstaken(account);

/************************************************
event InterestAccrued(bytes32 indexed coverKey);
************************************************/
CREATE TABLE vault.interest_accrued
(
  cover_key                                       bytes32 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX interest_accrued_cover_key_inx
ON vault.interest_accrued(cover_key);

/*****************************************************************
event Entered(bytes32 indexed coverKey, address indexed account);
*****************************************************************/
CREATE TABLE vault.entered
(
  cover_key                                       bytes32 NOT NULL,
  account                                         address NOT NULL
) INHERITS(core.transactions);

CREATE INDEX entered_cover_key_inx
ON vault.entered(cover_key);

CREATE INDEX entered_account_inx
ON vault.entered(account);

/****************************************************************
event Exited(bytes32 indexed coverKey, address indexed account);
****************************************************************/
CREATE TABLE vault.exited
(
  cover_key                                       bytes32 NOT NULL,
  account                                         address NOT NULL
) INHERITS(core.transactions);

CREATE INDEX exited_cover_key_inx
ON vault.exited(cover_key);

CREATE INDEX exited_account_inx
ON vault.exited(account);

/*****************************************************************************************
event VaultDeployed(address vault, bytes32 indexed coverKey, string name, string symbol);
*****************************************************************************************/
CREATE TABLE factory.vault_deployed
(
  vault                                           address NOT NULL,
  cover_key                                       bytes32 NOT NULL,
  name                                            text NOT NULL,
  symbol                                          text NOT NULL
) INHERITS(core.transactions);

CREATE INDEX vault_deployed_cover_key_inx
ON factory.vault_deployed(cover_key);


/*************************************************************************
event VoteEscrowLock(address indexed account, uint256 amount, uint256 durationInWeeks, uint256 previousUnlockAt, uint256 unlockAt, uint256 previousBalance, uint256 balance);
*************************************************************************/
CREATE TABLE ve.vote_escrow_lock
(
  account                                           address NOT NULL,
  amount                                            uint256 NOT NULL,
  duration_in_weeks                                 uint256 NOT NULL,
  previous_unlock_at                                uint256 NOT NULL,
  unlock_at                                         uint256 NOT NULL,
  previous_balance                                  uint256 NOT NULL,
  balance                                           uint256 NOT NULL  
) INHERITS(core.transactions);

CREATE INDEX vote_escrow_lock_account_inx
ON ve.vote_escrow_lock(account);


/*************************************************************************
event TransferWhitelistUpdated(address indexed updatedBy, address[] accounts, bool[] statuses);
*************************************************************************/
CREATE TABLE ve.transfer_whitelist_updated
(
  updated_by                                        address NOT NULL,
  accounts                                          address[] NOT NULL,
  statuses                                          boolean[] NOT NULL  
) INHERITS(core.transactions);

CREATE INDEX transfer_whitelist_updated_updated_by_inx
ON ve.transfer_whitelist_updated(updated_by);

/*************************************************************************
event VoteEscrowUnlock(address indexed account, uint256 amount, uint256 unlockAt, uint256 penalty);
*************************************************************************/
CREATE TABLE ve.vote_escrow_unlock
(
  account                                           address NOT NULL,
  amount                                            uint256 NOT NULL,
  unlock_at                                         uint256 NOT NULL,
  penalty                                           uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX vote_escrow_unlock_account_inx
ON ve.vote_escrow_unlock(account);

/*************************************************************************
event LiquidityGaugePoolInitialized(bytes32 indexed key, address indexed initializedBy, tuple(bytes32 key, address stakingToken, address veToken, address rewardToken, address registry, tuple(string name, string info, uint256 epochDuration, uint256 veBoostRatio, uint256 platformFee, address treasury) poolInfo) args);
*************************************************************************/
CREATE TABLE ve.liquidity_gauge_pool_initialized
(
  key                                               bytes32 NOT NULL,
  initialized_by                                    address NOT NULL,
  staking_token                                     address NOT NULL,
  ve_token                                          address NOT NULL,
  reward_token                                      address NOT NULL,
  registry                                          address NOT NULL,
  name                                              text NOT NULL,
  info                                              text NOT NULL,
  epoch_duration                                    uint256 NOT NULL,
  ve_boost_ratio                                    uint256 NOT NULL,
  platform_fee                                      uint256 NOT NULL,
  treasury                                          address NOT NULL
) INHERITS(core.transactions);

/*************************************************************************
event LiquidityGaugePoolSet(bytes32 indexed key, address indexed triggeredBy, address liquidityGaugePool, tuple(bytes32 key, string name, string info, uint256 lockupPeriodInBlocks, uint256 epochDuration, uint256 veBoostRatio, uint256 platformFee, address stakingToken, address veToken, address rewardToken, address registry, address treasury) args);
*************************************************************************/
CREATE TABLE ve.liquidity_gauge_pool_set
(
  -- lockup_period_in_blocks                        hard coded to 100
  key                                               bytes32 NOT NULL,
  triggered_by                                      address NOT NULL,
  liquidity_gauge_pool                              address NOT NULL,
  name                                              text NOT NULL,
  info                                              text NOT NULL,
  epoch_duration                                    uint256 NOT NULL,
  ve_boost_ratio                                    uint256 NOT NULL,
  platform_fee                                      uint256 NOT NULL,
  treasury                                          address NOT NULL
) INHERITS(core.transactions);

CREATE INDEX liquidity_gauge_pool_set_key_inx
ON ve.liquidity_gauge_pool_set(key);

/*************************************************************************
 event EpochDurationUpdated(bytes32 indexed key, uint256 previous, uint256 current);
*************************************************************************/
CREATE TABLE ve.epoch_duration_updated
(
  key                                               bytes32 NOT NULL,
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX epoch_duration_updated_key_inx
ON ve.epoch_duration_updated(key);

/*************************************************************************
event EpochRewardSet(bytes32 indexed key, address indexed triggeredBy, uint256 rewards);
*************************************************************************/
CREATE TABLE ve.epoch_reward_set
(
  key                                               bytes32 NOT NULL,
  triggered_by                                      address NOT NULL,
  rewards                                           uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX epoch_reward_set_key_inx
ON ve.epoch_reward_set(key);


/*************************************************************************
event LiquidityGaugePoolAdded(bytes32 key, ILiquidityGaugePool pool);
*************************************************************************/
CREATE TABLE ve.liquidity_gauge_pool_added
(
  key                                               bytes32 NOT NULL,
  pool                                              address NOT NULL
) INHERITS(core.transactions);

CREATE INDEX liquidity_gauge_pool_added_key_inx
ON ve.liquidity_gauge_pool_added(key);


/*************************************************************************
event LiquidityGaugePoolUpdated(bytes32 key, ILiquidityGaugePool previous, ILiquidityGaugePool current);
*************************************************************************/
CREATE TABLE ve.liquidity_gauge_pool_updated
(
  key                                               bytes32 NOT NULL,
  previous                                          address NOT NULL,
  current                                           address NOT NULL
) INHERITS(core.transactions);

CREATE INDEX liquidity_gauge_pool_updated_key_inx
ON ve.liquidity_gauge_pool_updated(key);

/*************************************************************************
event GaugeControllerRegistryPoolDeactivated(address indexed sender, bytes32 indexed key);
*************************************************************************/
CREATE TABLE ve.gauge_controller_registry_pool_deactivated
(
  sender                                            address NOT NULL,
  key                                               bytes32 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX gauge_controller_registry_pool_deactivated_sender_inx
ON ve.gauge_controller_registry_pool_deactivated(sender);

CREATE INDEX gauge_controller_registry_pool_deactivated_key_inx
ON ve.gauge_controller_registry_pool_deactivated(key);

/*************************************************************************
event GaugeControllerRegistryPoolActivated(address indexed sender, bytes32 indexed key);
*************************************************************************/
CREATE TABLE ve.gauge_controller_registry_pool_activated
(
  sender                                            address NOT NULL,
  key                                               bytes32 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX gauge_controller_registry_pool_activated_sender_inx
ON ve.gauge_controller_registry_pool_activated(sender);

CREATE INDEX gauge_controller_registry_pool_activated_key_inx
ON ve.gauge_controller_registry_pool_activated(key);

/*************************************************************************
event GaugeControllerRegistryPoolDeleted(address indexed sender, bytes32 key);
*************************************************************************/
CREATE TABLE ve.gauge_controller_registry_pool_deleted
(
  sender                                            address NOT NULL,
  key                                               bytes32 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX gauge_controller_registry_pool_deleted_sender_inx
ON ve.gauge_controller_registry_pool_deleted(sender);

CREATE INDEX gauge_controller_registry_pool_deleted_key_inx
ON ve.gauge_controller_registry_pool_deleted(key);

/*************************************************************************
event GaugeSet(uint256 indexed epoch, bytes32 indexed key, uint256 distribution);
*************************************************************************/
CREATE TABLE ve.gauge_set
(
  epoch                                             uint256 NOT NULL,
  key                                               bytes32 NOT NULL,
  pool                                              address NOT NULL,
  distribution                                      uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX gauge_set_epoch_inx
ON ve.gauge_set(epoch);

CREATE INDEX gauge_set_key_inx
ON ve.gauge_set(key);

/*************************************************************************
event GaugeAllocationTransferred(uint256 indexed epoch, uint256 totalAllocation);
*************************************************************************/
CREATE TABLE ve.gauge_allocation_transferred
(
  epoch                                             uint256 NOT NULL,
  total_allocation                                  uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX gauge_allocation_transferred_epoch_inx
ON ve.gauge_allocation_transferred(epoch);

/*************************************************************************
event VotingPowersUpdated(address indexed triggeredBy, uint256 previous, uint256 current, uint256 previousTotal, uint256 currentTotal);
*************************************************************************/
CREATE TABLE ve.voting_powers_updated
(
  key                                               bytes32 NOT NULL,
  triggered_by                                      address NOT NULL,
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL,
  previous_total                                    uint256 NOT NULL,
  current_total                                     uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX voting_powers_updated_triggered_by_inx
ON ve.voting_powers_updated(triggered_by);

/*************************************************************************
event LiquidityGaugeRewardsWithdrawn(bytes32 indexed key, address indexed account, address treasury, uint256 rewards, uint256 platformFee);
*************************************************************************/
CREATE TABLE ve.liquidity_gauge_rewards_withdrawn
(
  key                                               bytes32 NOT NULL,
  account                                           address NOT NULL,
  treasury                                          address NOT NULL,
  rewards                                           uint256 NOT NULL,
  platform_fee                                      uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX liquidity_gauge_rewards_withdrawn_key_inx
ON ve.liquidity_gauge_rewards_withdrawn(key);

CREATE INDEX liquidity_gauge_rewards_withdrawn_account_inx
ON ve.liquidity_gauge_rewards_withdrawn(account);

/*************************************************************************
event LiquidityGaugeDeposited(bytes32 indexed key, address indexed account, address indexed stakingToken, uint256 amount);
*************************************************************************/
CREATE TABLE ve.liquidity_gauge_deposited
(
  key                                               bytes32 NOT NULL,
  account                                           address NOT NULL,
  staking_token                                     address NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX liquidity_gauge_deposited_key_inx
ON ve.liquidity_gauge_deposited(key);

CREATE INDEX liquidity_gauge_deposited_account_inx
ON ve.liquidity_gauge_deposited(account);

CREATE INDEX liquidity_gauge_deposited_staking_token_inx
ON ve.liquidity_gauge_deposited(staking_token);

/*************************************************************************
event LiquidityGaugeWithdrawn(bytes32 indexed key, address indexed account, address indexed stakingToken, uint256 amount);
*************************************************************************/
CREATE TABLE ve.liquidity_gauge_withdrawn
(
  key                                               bytes32 NOT NULL,
  account                                           address NOT NULL,
  staking_token                                     address NOT NULL,
  amount                                            uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX liquidity_gauge_withdrawn_key_inx
ON ve.liquidity_gauge_withdrawn(key);

CREATE INDEX liquidity_gauge_withdrawn_account_inx
ON ve.liquidity_gauge_withdrawn(account);

CREATE INDEX liquidity_gauge_withdrawn_staking_token_inx
ON ve.liquidity_gauge_withdrawn(staking_token);

CREATE TABLE core.role_admin_changed
(
  role                                              bytes32 NOT NULL,
  previous_admin_role                               bytes32 NOT NULL,
  new_admin_role                                    bytes32 NOT NULL
) INHERITS(core.transactions);

CREATE TABLE core.transfer
(
  "from"                                            address NOT NULL,
  "to"                                              address NOT NULL,
  value                                             uint256 NOT NULL
) INHERITS(core.transactions);

CREATE TABLE core.role_granted
(
  role                                              bytes32 NOT NULL,
  account                                           address NOT NULL,
  sender                                            address NOT NULL
) INHERITS(core.transactions);

CREATE TABLE core.transparent_upgradeable_proxy_initialized
(
  version                                           uint256 NOT NULL
) INHERITS(core.transactions);


CREATE TABLE core.nft_transfer
(
  "from"                                            address NOT NULL,
  "to"                                              address NOT NULL,
  token_id                                          uint256 NOT NULL
) INHERITS(core.transactions);



/********************************************/
/********************************************/
/********************************************/

CREATE OR REPLACE FUNCTION get_cover_key_by_vault_address(_chain_id uint256, _vault address)
RETURNS bytes32
STABLE
AS
$$
BEGIN
  RETURN factory.vault_deployed.cover_key
  FROM factory.vault_deployed
  WHERE factory.vault_deployed.chain_id = _chain_id
  AND factory.vault_deployed.vault = _vault;
END
$$
LANGUAGE plpgsql;

/********************************************/

DROP FUNCTION IF EXISTS staking.bond_pool_setup_amounts_trigger() CASCADE;

CREATE FUNCTION staking.bond_pool_setup_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.npm_to_top_up_now;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER bond_pool_setup_amounts_trigger
BEFORE INSERT OR UPDATE ON staking.bond_pool_setup
FOR EACH ROW EXECUTE FUNCTION staking.bond_pool_setup_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS staking.bond_created_amounts_trigger() CASCADE;

CREATE FUNCTION staking.bond_created_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.npm_to_vest;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER bond_created_amounts_trigger
BEFORE INSERT OR UPDATE ON staking.bond_created
FOR EACH ROW EXECUTE FUNCTION staking.bond_created_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS staking.bond_claimed_amounts_trigger() CASCADE;

CREATE FUNCTION staking.bond_claimed_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER bond_claimed_amounts_trigger
BEFORE INSERT OR UPDATE ON staking.bond_claimed
FOR EACH ROW EXECUTE FUNCTION staking.bond_claimed_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS reassurance.reassurance_added_amounts_trigger() CASCADE;

CREATE FUNCTION reassurance.reassurance_added_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER reassurance_added_amounts_trigger
BEFORE INSERT OR UPDATE ON reassurance.reassurance_added
FOR EACH ROW EXECUTE FUNCTION reassurance.reassurance_added_amounts_trigger();


/********************************************/

DROP FUNCTION IF EXISTS reassurance.pool_capitalized_amounts_trigger() CASCADE;

CREATE FUNCTION reassurance.pool_capitalized_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER pool_capitalized_amounts_trigger
BEFORE INSERT OR UPDATE ON reassurance.pool_capitalized
FOR EACH ROW EXECUTE FUNCTION reassurance.pool_capitalized_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.stake_added_amounts_trigger() CASCADE;

CREATE FUNCTION cover.stake_added_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER stake_added_amounts_trigger
BEFORE INSERT OR UPDATE ON cover.stake_added
FOR EACH ROW EXECUTE FUNCTION cover.stake_added_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.stake_removed_amounts_trigger() CASCADE;

CREATE FUNCTION cover.stake_removed_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER stake_removed_amounts_trigger
BEFORE INSERT OR UPDATE ON cover.stake_removed
FOR EACH ROW EXECUTE FUNCTION cover.stake_removed_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.reported_amounts_trigger() CASCADE;

CREATE FUNCTION consensus.reported_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.initial_stake;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER reported_amounts_trigger
BEFORE INSERT OR UPDATE ON consensus.reported
FOR EACH ROW EXECUTE FUNCTION consensus.reported_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.disputed_amounts_trigger() CASCADE;

CREATE FUNCTION consensus.disputed_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.initial_stake;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER disputed_amounts_trigger
BEFORE INSERT OR UPDATE ON consensus.disputed
FOR EACH ROW EXECUTE FUNCTION consensus.disputed_amounts_trigger();


/********************************************/

DROP FUNCTION IF EXISTS cover.fee_burned_amounts_trigger() CASCADE;

CREATE FUNCTION cover.fee_burned_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER fee_burned_amounts_trigger
BEFORE INSERT OR UPDATE ON cover.fee_burned
FOR EACH ROW EXECUTE FUNCTION cover.fee_burned_amounts_trigger();


/********************************************/

DROP FUNCTION IF EXISTS consensus.attested_amounts_trigger() CASCADE;

CREATE FUNCTION consensus.attested_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.stake;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER attested_amounts_trigger
BEFORE INSERT OR UPDATE ON consensus.attested
FOR EACH ROW EXECUTE FUNCTION consensus.attested_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.refuted_amounts_trigger() CASCADE;

CREATE FUNCTION consensus.refuted_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.stake;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER refuted_amounts_trigger
BEFORE INSERT OR UPDATE ON consensus.refuted
FOR EACH ROW EXECUTE FUNCTION consensus.refuted_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.unstaken_amounts_trigger() CASCADE;

CREATE FUNCTION consensus.unstaken_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.original_stake;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER unstaken_amounts_trigger
BEFORE INSERT OR UPDATE ON consensus.unstaken
FOR EACH ROW EXECUTE FUNCTION consensus.unstaken_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.reporter_reward_distributed_amounts_trigger() CASCADE;

CREATE FUNCTION consensus.reporter_reward_distributed_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.reporter_reward;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER reporter_reward_distributed_amounts_trigger
BEFORE INSERT OR UPDATE ON consensus.reporter_reward_distributed
FOR EACH ROW EXECUTE FUNCTION consensus.reporter_reward_distributed_amounts_trigger();


/********************************************/

DROP FUNCTION IF EXISTS consensus.governance_burned_amounts_trigger() CASCADE;

CREATE FUNCTION consensus.governance_burned_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.burned_amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER governance_burned_amounts_trigger
BEFORE INSERT OR UPDATE ON consensus.governance_burned
FOR EACH ROW EXECUTE FUNCTION consensus.governance_burned_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS strategy.log_deposit_amounts_trigger() CASCADE;

CREATE FUNCTION strategy.log_deposit_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.deposit_total;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER log_deposit_amounts_trigger
BEFORE INSERT OR UPDATE ON strategy.log_deposit
FOR EACH ROW EXECUTE FUNCTION strategy.log_deposit_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS strategy.deposited_amounts_trigger() CASCADE;

CREATE FUNCTION strategy.deposited_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.stablecoin_deposited;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER deposited_amounts_trigger
BEFORE INSERT OR UPDATE ON strategy.deposited
FOR EACH ROW EXECUTE FUNCTION strategy.deposited_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS strategy.log_withdrawal_amounts_trigger() CASCADE;

CREATE FUNCTION strategy.log_withdrawal_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.withdrawal_total;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER log_withdrawal_amounts_trigger
BEFORE INSERT OR UPDATE ON strategy.log_withdrawal
FOR EACH ROW EXECUTE FUNCTION strategy.log_withdrawal_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS strategy.withdrawn_amounts_trigger() CASCADE;

CREATE FUNCTION strategy.withdrawn_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.stablecoin_withdrawn;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER withdrawn_amounts_trigger
BEFORE INSERT OR UPDATE ON strategy.withdrawn
FOR EACH ROW EXECUTE FUNCTION strategy.withdrawn_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS strategy.drained_amounts_trigger() CASCADE;

CREATE FUNCTION strategy.drained_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER drained_amounts_trigger
BEFORE INSERT OR UPDATE ON strategy.drained
FOR EACH ROW EXECUTE FUNCTION strategy.drained_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS policy.cover_purchased_amounts_trigger() CASCADE;

CREATE FUNCTION policy.cover_purchased_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.fee - NEW.platform_fee;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER cover_purchased_amounts_trigger
BEFORE INSERT OR UPDATE ON policy.cover_purchased
FOR EACH ROW EXECUTE FUNCTION policy.cover_purchased_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.governance_transfer_amounts_trigger() CASCADE;

CREATE FUNCTION vault.governance_transfer_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER governance_transfer_amounts_trigger
BEFORE INSERT OR UPDATE ON vault.governance_transfer
FOR EACH ROW EXECUTE FUNCTION vault.governance_transfer_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.strategy_transfer_amounts_trigger() CASCADE;

CREATE FUNCTION vault.strategy_transfer_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER strategy_transfer_amounts_trigger
BEFORE INSERT OR UPDATE ON vault.strategy_transfer
FOR EACH ROW EXECUTE FUNCTION vault.strategy_transfer_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.strategy_receipt_amounts_trigger() CASCADE;

CREATE FUNCTION vault.strategy_receipt_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER strategy_receipt_amounts_trigger
BEFORE INSERT OR UPDATE ON vault.strategy_receipt
FOR EACH ROW EXECUTE FUNCTION vault.strategy_receipt_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.pods_issued_amounts_trigger() CASCADE;

CREATE FUNCTION vault.pods_issued_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.liquidity_added;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER pods_issued_amounts_trigger
BEFORE INSERT OR UPDATE ON vault.pods_issued
FOR EACH ROW EXECUTE FUNCTION vault.pods_issued_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.pods_redeemed_amounts_trigger() CASCADE;

CREATE FUNCTION vault.pods_redeemed_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.liquidity_released * -1;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER pods_redeemed_amounts_trigger
BEFORE INSERT OR UPDATE ON vault.pods_redeemed
FOR EACH ROW EXECUTE FUNCTION vault.pods_redeemed_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.flash_loan_borrowed_amounts_trigger() CASCADE;

CREATE FUNCTION vault.flash_loan_borrowed_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER flash_loan_borrowed_amounts_trigger
BEFORE INSERT OR UPDATE ON vault.flash_loan_borrowed
FOR EACH ROW EXECUTE FUNCTION vault.flash_loan_borrowed_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.npm_staken_amounts_trigger() CASCADE;

CREATE FUNCTION vault.npm_staken_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER npm_staken_amounts_trigger
BEFORE INSERT OR UPDATE ON vault.npm_staken
FOR EACH ROW EXECUTE FUNCTION vault.npm_staken_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.npm_unstaken_amounts_trigger() CASCADE;

CREATE FUNCTION vault.npm_unstaken_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER npm_unstaken_amounts_trigger
BEFORE INSERT OR UPDATE ON vault.npm_unstaken
FOR EACH ROW EXECUTE FUNCTION vault.npm_unstaken_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS ve.vote_escrow_lock_amounts_trigger() CASCADE;

CREATE FUNCTION ve.vote_escrow_lock_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER vote_escrow_lock_amounts_trigger
BEFORE INSERT OR UPDATE ON ve.vote_escrow_lock
FOR EACH ROW EXECUTE FUNCTION ve.vote_escrow_lock_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS ve.vote_escrow_unlock_amounts_trigger() CASCADE;

CREATE FUNCTION ve.vote_escrow_unlock_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.amount;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER vote_escrow_unlock_amounts_trigger
BEFORE INSERT OR UPDATE ON ve.vote_escrow_unlock
FOR EACH ROW EXECUTE FUNCTION ve.vote_escrow_unlock_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS ve.liquidity_gauge_rewards_withdrawn_amounts_trigger() CASCADE;

CREATE FUNCTION ve.liquidity_gauge_rewards_withdrawn_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_npm_amount = NEW.rewards;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER liquidity_gauge_rewards_withdrawn_amounts_trigger
BEFORE INSERT OR UPDATE ON ve.liquidity_gauge_rewards_withdrawn
FOR EACH ROW EXECUTE FUNCTION ve.liquidity_gauge_rewards_withdrawn_amounts_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.pods_issued_referral_code_trigger() CASCADE;

CREATE FUNCTION vault.pods_issued_referral_code_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.coupon_code = NEW.referral_code;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER pods_issued_referral_code_trigger
BEFORE INSERT OR UPDATE ON vault.pods_issued
FOR EACH ROW EXECUTE FUNCTION vault.pods_issued_referral_code_trigger();

/********************************************/

DROP FUNCTION IF EXISTS policy.cover_purchased_referral_code_trigger() CASCADE;

CREATE FUNCTION policy.cover_purchased_referral_code_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.coupon_code = NEW.referral_code;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER cover_purchased_referral_code_trigger
BEFORE INSERT OR UPDATE ON policy.cover_purchased
FOR EACH ROW EXECUTE FUNCTION policy.cover_purchased_referral_code_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cxtoken.claimed_cover_key_trigger() CASCADE;

CREATE FUNCTION cxtoken.claimed_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER claimed_cover_key_trigger
BEFORE INSERT OR UPDATE ON cxtoken.claimed
FOR EACH ROW EXECUTE FUNCTION cxtoken.claimed_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.pods_issued_cover_key_trigger() CASCADE;

CREATE FUNCTION vault.pods_issued_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = get_cover_key_by_vault_address(NEW.chain_id, NEW.address);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER pods_issued_cover_key_trigger
BEFORE INSERT OR UPDATE ON vault.pods_issued
FOR EACH ROW EXECUTE FUNCTION vault.pods_issued_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.pods_redeemed_cover_key_trigger() CASCADE;

CREATE FUNCTION vault.pods_redeemed_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = get_cover_key_by_vault_address(NEW.chain_id, NEW.address);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER pods_redeemed_cover_key_trigger
BEFORE INSERT OR UPDATE ON vault.pods_redeemed
FOR EACH ROW EXECUTE FUNCTION vault.pods_redeemed_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS claim.claim_period_set_cover_key_trigger() CASCADE;

CREATE FUNCTION claim.claim_period_set_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER claim_period_set_cover_key_trigger
BEFORE INSERT OR UPDATE ON claim.claim_period_set
FOR EACH ROW EXECUTE FUNCTION claim.claim_period_set_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS claim.blacklist_set_cover_key_trigger() CASCADE;

CREATE FUNCTION claim.blacklist_set_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER blacklist_set_cover_key_trigger
BEFORE INSERT OR UPDATE ON claim.blacklist_set
FOR EACH ROW EXECUTE FUNCTION claim.blacklist_set_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.cover_created_cover_key_trigger() CASCADE;

CREATE FUNCTION cover.cover_created_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER cover_created_cover_key_trigger
BEFORE INSERT OR UPDATE ON cover.cover_created
FOR EACH ROW EXECUTE FUNCTION cover.cover_created_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.product_created_cover_key_trigger() CASCADE;

CREATE FUNCTION cover.product_created_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER product_created_cover_key_trigger
BEFORE INSERT OR UPDATE ON cover.product_created
FOR EACH ROW EXECUTE FUNCTION cover.product_created_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.cover_updated_cover_key_trigger() CASCADE;

CREATE FUNCTION cover.cover_updated_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER cover_updated_cover_key_trigger
BEFORE INSERT OR UPDATE ON cover.cover_updated
FOR EACH ROW EXECUTE FUNCTION cover.cover_updated_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.product_updated_cover_key_trigger() CASCADE;

CREATE FUNCTION cover.product_updated_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER product_updated_cover_key_trigger
BEFORE INSERT OR UPDATE ON cover.product_updated
FOR EACH ROW EXECUTE FUNCTION cover.product_updated_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.product_state_updated_cover_key_trigger() CASCADE;

CREATE FUNCTION cover.product_state_updated_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER product_state_updated_cover_key_trigger
BEFORE INSERT OR UPDATE ON cover.product_state_updated
FOR EACH ROW EXECUTE FUNCTION cover.product_state_updated_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.cover_user_whitelist_updated_cover_key_trigger() CASCADE;

CREATE FUNCTION cover.cover_user_whitelist_updated_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER cover_user_whitelist_updated_cover_key_trigger
BEFORE INSERT OR UPDATE ON cover.cover_user_whitelist_updated
FOR EACH ROW EXECUTE FUNCTION cover.cover_user_whitelist_updated_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS reassurance.reassurance_added_cover_key_trigger() CASCADE;

CREATE FUNCTION reassurance.reassurance_added_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER reassurance_added_cover_key_trigger
BEFORE INSERT OR UPDATE ON reassurance.reassurance_added
FOR EACH ROW EXECUTE FUNCTION reassurance.reassurance_added_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS reassurance.weight_set_cover_key_trigger() CASCADE;

CREATE FUNCTION reassurance.weight_set_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER weight_set_cover_key_trigger
BEFORE INSERT OR UPDATE ON reassurance.weight_set
FOR EACH ROW EXECUTE FUNCTION reassurance.weight_set_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS reassurance.pool_capitalized_cover_key_trigger() CASCADE;

CREATE FUNCTION reassurance.pool_capitalized_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER pool_capitalized_cover_key_trigger
BEFORE INSERT OR UPDATE ON reassurance.pool_capitalized
FOR EACH ROW EXECUTE FUNCTION reassurance.pool_capitalized_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.stake_added_cover_key_trigger() CASCADE;

CREATE FUNCTION cover.stake_added_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER stake_added_cover_key_trigger
BEFORE INSERT OR UPDATE ON cover.stake_added
FOR EACH ROW EXECUTE FUNCTION cover.stake_added_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.stake_removed_cover_key_trigger() CASCADE;

CREATE FUNCTION cover.stake_removed_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER stake_removed_cover_key_trigger
BEFORE INSERT OR UPDATE ON cover.stake_removed
FOR EACH ROW EXECUTE FUNCTION cover.stake_removed_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.fee_burned_cover_key_trigger() CASCADE;

CREATE FUNCTION cover.fee_burned_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER fee_burned_cover_key_trigger
BEFORE INSERT OR UPDATE ON cover.fee_burned
FOR EACH ROW EXECUTE FUNCTION cover.fee_burned_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cxtoken.coverage_start_set_cover_key_trigger() CASCADE;

CREATE FUNCTION cxtoken.coverage_start_set_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER coverage_start_set_cover_key_trigger
BEFORE INSERT OR UPDATE ON cxtoken.coverage_start_set
FOR EACH ROW EXECUTE FUNCTION cxtoken.coverage_start_set_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS factory.cx_token_deployed_cover_key_trigger() CASCADE;

CREATE FUNCTION factory.cx_token_deployed_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER cx_token_deployed_cover_key_trigger
BEFORE INSERT OR UPDATE ON factory.cx_token_deployed
FOR EACH ROW EXECUTE FUNCTION factory.cx_token_deployed_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.finalized_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.finalized_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER finalized_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.finalized
FOR EACH ROW EXECUTE FUNCTION consensus.finalized_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.reported_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.reported_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER reported_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.reported
FOR EACH ROW EXECUTE FUNCTION consensus.reported_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.disputed_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.disputed_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER disputed_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.disputed
FOR EACH ROW EXECUTE FUNCTION consensus.disputed_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.first_reporting_stake_set_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.first_reporting_stake_set_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER first_reporting_stake_set_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.first_reporting_stake_set
FOR EACH ROW EXECUTE FUNCTION consensus.first_reporting_stake_set_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.attested_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.attested_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER attested_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.attested
FOR EACH ROW EXECUTE FUNCTION consensus.attested_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.refuted_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.refuted_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER refuted_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.refuted
FOR EACH ROW EXECUTE FUNCTION consensus.refuted_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.unstaken_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.unstaken_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER unstaken_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.unstaken
FOR EACH ROW EXECUTE FUNCTION consensus.unstaken_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.reporter_reward_distributed_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.reporter_reward_distributed_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER reporter_reward_distributed_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.reporter_reward_distributed
FOR EACH ROW EXECUTE FUNCTION consensus.reporter_reward_distributed_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.governance_burned_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.governance_burned_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER governance_burned_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.governance_burned
FOR EACH ROW EXECUTE FUNCTION consensus.governance_burned_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.resolved_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.resolved_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER resolved_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.resolved
FOR EACH ROW EXECUTE FUNCTION consensus.resolved_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.cooldown_period_configured_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.cooldown_period_configured_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER cooldown_period_configured_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.cooldown_period_configured
FOR EACH ROW EXECUTE FUNCTION consensus.cooldown_period_configured_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.report_closed_cover_key_trigger() CASCADE;

CREATE FUNCTION consensus.report_closed_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER report_closed_cover_key_trigger
BEFORE INSERT OR UPDATE ON consensus.report_closed
FOR EACH ROW EXECUTE FUNCTION consensus.report_closed_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS policy.cover_purchased_cover_key_trigger() CASCADE;

CREATE FUNCTION policy.cover_purchased_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER cover_purchased_cover_key_trigger
BEFORE INSERT OR UPDATE ON policy.cover_purchased
FOR EACH ROW EXECUTE FUNCTION policy.cover_purchased_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS policy.cover_policy_rate_set_cover_key_trigger() CASCADE;

CREATE FUNCTION policy.cover_policy_rate_set_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER cover_policy_rate_set_cover_key_trigger
BEFORE INSERT OR UPDATE ON policy.cover_policy_rate_set
FOR EACH ROW EXECUTE FUNCTION policy.cover_policy_rate_set_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS policy.coverage_lag_set_cover_key_trigger() CASCADE;

CREATE FUNCTION policy.coverage_lag_set_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER coverage_lag_set_cover_key_trigger
BEFORE INSERT OR UPDATE ON policy.coverage_lag_set
FOR EACH ROW EXECUTE FUNCTION policy.coverage_lag_set_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.interest_accrued_cover_key_trigger() CASCADE;

CREATE FUNCTION vault.interest_accrued_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER interest_accrued_cover_key_trigger
BEFORE INSERT OR UPDATE ON vault.interest_accrued
FOR EACH ROW EXECUTE FUNCTION vault.interest_accrued_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.entered_cover_key_trigger() CASCADE;

CREATE FUNCTION vault.entered_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER entered_cover_key_trigger
BEFORE INSERT OR UPDATE ON vault.entered
FOR EACH ROW EXECUTE FUNCTION vault.entered_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS vault.exited_cover_key_trigger() CASCADE;

CREATE FUNCTION vault.exited_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER exited_cover_key_trigger
BEFORE INSERT OR UPDATE ON vault.exited
FOR EACH ROW EXECUTE FUNCTION vault.exited_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS factory.vault_deployed_cover_key_trigger() CASCADE;

CREATE FUNCTION factory.vault_deployed_cover_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.ck = NEW.cover_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER vault_deployed_cover_key_trigger
BEFORE INSERT OR UPDATE ON factory.vault_deployed
FOR EACH ROW EXECUTE FUNCTION factory.vault_deployed_cover_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cxtoken.claimed_product_key_trigger() CASCADE;

CREATE FUNCTION cxtoken.claimed_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER claimed_product_key_trigger
BEFORE INSERT OR UPDATE ON cxtoken.claimed
FOR EACH ROW EXECUTE FUNCTION cxtoken.claimed_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS claim.blacklist_set_product_key_trigger() CASCADE;

CREATE FUNCTION claim.blacklist_set_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER blacklist_set_product_key_trigger
BEFORE INSERT OR UPDATE ON claim.blacklist_set
FOR EACH ROW EXECUTE FUNCTION claim.blacklist_set_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.product_created_product_key_trigger() CASCADE;

CREATE FUNCTION cover.product_created_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER product_created_product_key_trigger
BEFORE INSERT OR UPDATE ON cover.product_created
FOR EACH ROW EXECUTE FUNCTION cover.product_created_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.product_updated_product_key_trigger() CASCADE;

CREATE FUNCTION cover.product_updated_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER product_updated_product_key_trigger
BEFORE INSERT OR UPDATE ON cover.product_updated
FOR EACH ROW EXECUTE FUNCTION cover.product_updated_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.product_state_updated_product_key_trigger() CASCADE;

CREATE FUNCTION cover.product_state_updated_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER product_state_updated_product_key_trigger
BEFORE INSERT OR UPDATE ON cover.product_state_updated
FOR EACH ROW EXECUTE FUNCTION cover.product_state_updated_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cover.cover_user_whitelist_updated_product_key_trigger() CASCADE;

CREATE FUNCTION cover.cover_user_whitelist_updated_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER cover_user_whitelist_updated_product_key_trigger
BEFORE INSERT OR UPDATE ON cover.cover_user_whitelist_updated
FOR EACH ROW EXECUTE FUNCTION cover.cover_user_whitelist_updated_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS reassurance.pool_capitalized_product_key_trigger() CASCADE;

CREATE FUNCTION reassurance.pool_capitalized_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER pool_capitalized_product_key_trigger
BEFORE INSERT OR UPDATE ON reassurance.pool_capitalized
FOR EACH ROW EXECUTE FUNCTION reassurance.pool_capitalized_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS cxtoken.coverage_start_set_product_key_trigger() CASCADE;

CREATE FUNCTION cxtoken.coverage_start_set_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER coverage_start_set_product_key_trigger
BEFORE INSERT OR UPDATE ON cxtoken.coverage_start_set
FOR EACH ROW EXECUTE FUNCTION cxtoken.coverage_start_set_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS factory.cx_token_deployed_product_key_trigger() CASCADE;

CREATE FUNCTION factory.cx_token_deployed_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER cx_token_deployed_product_key_trigger
BEFORE INSERT OR UPDATE ON factory.cx_token_deployed
FOR EACH ROW EXECUTE FUNCTION factory.cx_token_deployed_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.finalized_product_key_trigger() CASCADE;

CREATE FUNCTION consensus.finalized_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER finalized_product_key_trigger
BEFORE INSERT OR UPDATE ON consensus.finalized
FOR EACH ROW EXECUTE FUNCTION consensus.finalized_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.reported_product_key_trigger() CASCADE;

CREATE FUNCTION consensus.reported_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER reported_product_key_trigger
BEFORE INSERT OR UPDATE ON consensus.reported
FOR EACH ROW EXECUTE FUNCTION consensus.reported_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.disputed_product_key_trigger() CASCADE;

CREATE FUNCTION consensus.disputed_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER disputed_product_key_trigger
BEFORE INSERT OR UPDATE ON consensus.disputed
FOR EACH ROW EXECUTE FUNCTION consensus.disputed_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.attested_product_key_trigger() CASCADE;

CREATE FUNCTION consensus.attested_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER attested_product_key_trigger
BEFORE INSERT OR UPDATE ON consensus.attested
FOR EACH ROW EXECUTE FUNCTION consensus.attested_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.refuted_product_key_trigger() CASCADE;

CREATE FUNCTION consensus.refuted_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER refuted_product_key_trigger
BEFORE INSERT OR UPDATE ON consensus.refuted
FOR EACH ROW EXECUTE FUNCTION consensus.refuted_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.unstaken_product_key_trigger() CASCADE;

CREATE FUNCTION consensus.unstaken_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER unstaken_product_key_trigger
BEFORE INSERT OR UPDATE ON consensus.unstaken
FOR EACH ROW EXECUTE FUNCTION consensus.unstaken_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.reporter_reward_distributed_product_key_trigger() CASCADE;

CREATE FUNCTION consensus.reporter_reward_distributed_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER reporter_reward_distributed_product_key_trigger
BEFORE INSERT OR UPDATE ON consensus.reporter_reward_distributed
FOR EACH ROW EXECUTE FUNCTION consensus.reporter_reward_distributed_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.governance_burned_product_key_trigger() CASCADE;

CREATE FUNCTION consensus.governance_burned_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER governance_burned_product_key_trigger
BEFORE INSERT OR UPDATE ON consensus.governance_burned
FOR EACH ROW EXECUTE FUNCTION consensus.governance_burned_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.resolved_product_key_trigger() CASCADE;

CREATE FUNCTION consensus.resolved_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER resolved_product_key_trigger
BEFORE INSERT OR UPDATE ON consensus.resolved
FOR EACH ROW EXECUTE FUNCTION consensus.resolved_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS consensus.report_closed_product_key_trigger() CASCADE;

CREATE FUNCTION consensus.report_closed_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER report_closed_product_key_trigger
BEFORE INSERT OR UPDATE ON consensus.report_closed
FOR EACH ROW EXECUTE FUNCTION consensus.report_closed_product_key_trigger();

/********************************************/

DROP FUNCTION IF EXISTS policy.cover_purchased_product_key_trigger() CASCADE;

CREATE FUNCTION policy.cover_purchased_product_key_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.pk = NEW.product_key;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER cover_purchased_product_key_trigger
BEFORE INSERT OR UPDATE ON policy.cover_purchased
FOR EACH ROW EXECUTE FUNCTION policy.cover_purchased_product_key_trigger();

/********************************************/


CREATE OR REPLACE FUNCTION format_stablecoin
(
  _amount         numeric
)
RETURNS money
IMMUTABLE
AS
$$
BEGIN
  RETURN _amount / POWER(10, 6);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_stablecoin_value(_chain_id uint256, _amount uint256)
RETURNS numeric
IMMUTABLE
AS
$$
BEGIN
  IF(_chain_id = 56) THEN
    RETURN _amount / POWER(10, 18);  
  END IF;

  RETURN _amount / POWER(10, 6);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_npm_value(_amount uint256)
RETURNS numeric
IMMUTABLE
AS
$$
BEGIN
  RETURN _amount / POWER(10, 18);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION format_npm
(
  _amount         numeric
)
RETURNS text
IMMUTABLE
AS
$$
BEGIN
  RETURN CONCAT(to_char(_amount / POWER(10, 18), 'FM999G999G999D00'), ' ', 'NPM');
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ether(amount uint256)
RETURNS uint256
IMMUTABLE
AS
$$
BEGIN
  RETURN COALESCE(amount, 0) * POWER(10, 18);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION wei_to_ether(amount uint256)
RETURNS uint256
IMMUTABLE
AS
$$
BEGIN
  RETURN COALESCE(amount, 0) / POWER(10, 18);
END
$$
LANGUAGE plpgsql;


CREATE FUNCTION average(numeric, variadic numeric[])
RETURNS numeric
IMMUTABLE
AS
$$
BEGIN
  RETURN (SELECT AVG(vals) FROM unnest($2 || ARRAY[$1]) t(vals));
END;
$$
LANGUAGE plpgsql;

DO
$$
BEGIN
  PERFORM 'bytes32'::regtype;
  EXCEPTION WHEN undefined_object THEN
  CREATE DOMAIN bytes32 AS text;
END
$$
LANGUAGE plpgsql;

DO
$$
BEGIN
  PERFORM 'address'::regtype;
  EXCEPTION WHEN undefined_object THEN
  CREATE DOMAIN address AS text;
END
$$
LANGUAGE plpgsql;

DO
$$
BEGIN
  PERFORM 'ipfs_url'::regtype;
  EXCEPTION WHEN undefined_object THEN
  CREATE DOMAIN ipfs_url AS text;
END
$$
LANGUAGE plpgsql;

DO
$$
BEGIN
  PERFORM 'uint256'::regtype;
  EXCEPTION WHEN undefined_object THEN
  CREATE DOMAIN uint256 AS numeric(180,0);
END
$$
LANGUAGE plpgsql;

DO
$$
BEGIN
  PERFORM 'uint96'::regtype;
  EXCEPTION WHEN undefined_object THEN
  CREATE DOMAIN uint96 AS numeric(180,0);
END
$$
LANGUAGE plpgsql;

DO
$$
BEGIN
  PERFORM 'uint8'::regtype;
  EXCEPTION WHEN undefined_object THEN
  CREATE DOMAIN uint8 AS integer;
END
$$
LANGUAGE plpgsql;

/***************************************************************************************
----------------------------------------------------------------------------------------
***************************************************************************************/

CREATE TABLE IF NOT EXISTS characters
(
  id                                                uuid PRIMARY KEY DEFAULT(gen_random_uuid()),
  level                                             integer,
  role                                              text,
  name                                              text,
  description                                       text,
  start_index                                       integer,
  siblings                                          integer,
  rarity                                            smallint,
  stage                                             text,
  views                                             uint256 NOT NULL DEFAULT(0),
  want_to_mint                                      uint256 NOT NULL DEFAULT(0)
);


CREATE TABLE IF NOT EXISTS nfts
(
  id                                                uuid PRIMARY KEY DEFAULT(gen_random_uuid()),
  token_id                                          uint256 NOT NULL UNIQUE,
  name                                              national character varying(128) NOT NULL,
  category                                          text GENERATED ALWAYS AS(trim(split_part(name, '#', 1))) STORED,
  nickname                                          text,
  family                                            text,
  description                                       text NOT NULL,
  url                                               text NOT NULL,
  image                                             text NOT NULL,
  external_url                                      text NOT NULL,
  date_published                                    uint256 NOT NULL,
  soulbound                                         boolean NOT NULL,
  attributes                                        jsonb NOT NULL,
  properties                                        jsonb NOT NULL,
  views                                             uint256 NOT NULL DEFAULT(0),
  want_to_mint                                      uint256 NOT NULL DEFAULT(0),
  likes                                             uint256 NOT NULL DEFAULT(0)
);

CREATE TABLE IF NOT EXISTS likes
(
  id                                                uuid PRIMARY KEY DEFAULT(gen_random_uuid()),
  token_id                                          uint256 NOT NULL,
  liked_by                                          address NOT NULL,
  liked                                             boolean NOT NULL DEFAULT(true),
  liked_at                                          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT(NOW()),
  last_liked_at                                     TIMESTAMP WITH TIME ZONE,
  last_unliked_at                                   TIMESTAMP WITH TIME ZONE
);


CREATE TABLE IF NOT EXISTS nft.merkle_root_updates
(
  id                                                uuid PRIMARY KEY DEFAULT(gen_random_uuid()),
  updated_on                                        integer NOT NULL,
  info                                              national character varying(200) NOT NULL,
  transaction_hash                                  text NOT NULL
);


CREATE TABLE IF NOT EXISTS nft.merkle_root_update_details
(
  id                                                                  uuid REFERENCES nft.merkle_root_updates,
  account                                                             address,
  policy                                                              uint256,
  liquidity                                                           uint256,
  points                                                              uint256,
  eligible_level                                                      uint8,
  level                                                               uint8,    
  family                                                              text,
  persona                                                             uint8,
  active                                                              boolean DEFAULT(true)
);

CREATE INDEX IF NOT EXISTS merkle_root_update_details_active_inx
ON nft.merkle_root_update_details(active);


/*************************************************************************
event PersonaSet(address indexed account, uint8 level, uint8 persona);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.persona_set
(
  account                                           address NOT NULL,
  level                                             uint8 NOT NULL,
  persona                                           uint8 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX IF NOT EXISTS persona_set_account_inx
ON nft.persona_set(account);

/*************************************************************************
event BoundariesSet(address indexed account, uint256[] levels, Boundary[] boundaries);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.boundaries_set
(
  account                                           address NOT NULL,
  levels                                            uint256[] NOT NULL,
  boundaries                                        jsonb[] NOT NULL
) INHERITS(core.transactions);

CREATE INDEX IF NOT EXISTS boundaries_set_account_inx
ON nft.boundaries_set(account);


/*************************************************************************
event MerkleRootSet(address indexed account, bytes32 previous, bytes32 current);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.merkle_root_set
(
  account                                           address NOT NULL,
  previous                                          bytes32 NOT NULL,
  current                                           bytes32 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX IF NOT EXISTS merkle_root_set_account_inx
ON nft.merkle_root_set(account);

/*************************************************************************
event MintedWithProof(bytes32[] proof, uint256 level, uint256 tokenId);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.minted_with_proof
(
  account                                           address,
  proof                                             bytes32[] NOT NULL,
  level                                             uint256 NOT NULL,
  token_id                                          uint256 NOT NULL
) INHERITS(core.transactions);

-- /*************************************************************************
-- event PersonaSet(address indexed account, uint8 level, uint8 persona);
-- *************************************************************************/
-- CREATE TABLE IF NOT EXISTS nft.persona_set
-- (
--   account                                           address NOT NULL,
--   level                                             uint256 NOT NULL,
--   persona                                           uint8 NOT NULL
-- ) INHERITS(core.transactions);

-- CREATE INDEX IF NOT EXISTS persona_set_account_inx
-- ON nft.persona_set(account);

/*************************************************************************
event SoulboundMinted(address indexed account, uint256 tokenId);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.soulbound_minted
(
  account                                           address NOT NULL,
  token_id                                          uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX IF NOT EXISTS soulbound_minted_account_inx
ON nft.soulbound_minted(account);

/*************************************************************************
event DefaultRoyaltySet(address indexed sender, address indexed receiver, uint96 feeNumerator);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.default_royalty_set
(
  sender                                            address NOT NULL,
  receiver                                          address NOT NULL,
  fee_numerator                                     uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX IF NOT EXISTS default_royalty_set_sender_inx
ON nft.default_royalty_set(sender);

CREATE INDEX IF NOT EXISTS default_royalty_set_receiver_inx
ON nft.default_royalty_set(receiver);

/*************************************************************************
event Transfer(address indexed from, address indexed to, uint256 tokens);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.neptune_legends_transfer
(
  sender                                            address NOT NULL,
  receiver                                          address NOT NULL,
  token_id                                          uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX IF NOT EXISTS neptune_legends_transfer_sender_inx
ON nft.neptune_legends_transfer(sender);

CREATE INDEX IF NOT EXISTS neptune_legends_transfer_receiver_inx
ON nft.neptune_legends_transfer(receiver);

/*************************************************************************
event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes indexed _toAddress, uint[] _tokenIds);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.send_to_chain
(
  sender                                            address NOT NULL,
  receiver                                          address NOT NULL,
  token_ids                                         uint256[] NOT NULL,
  dst_chain_id                                      uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX IF NOT EXISTS send_to_chain_sender_inx
ON nft.send_to_chain(sender);

CREATE INDEX IF NOT EXISTS send_to_chain_receiver_inx
ON nft.send_to_chain(receiver);

/*************************************************************************
event DefaultRoyaltyDeleted(address indexed sender);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.default_royalty_deleted
(
  sender                                            address NOT NULL
) INHERITS(core.transactions);

CREATE INDEX IF NOT EXISTS default_royalty_deleted_sender_inx
ON nft.default_royalty_deleted(sender);

/*************************************************************************
event TokenRoyaltySet(address indexed sender, uint256 tokenId, address indexed receiver, uint96 feeNumerator);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.token_royalty_set
(
  sender                                            address NOT NULL,
  token_id                                          uint256 NOT NULL,
  receiver                                          address NOT NULL,
  fee_numerator                                     uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX IF NOT EXISTS token_royalty_set_sender_inx
ON nft.token_royalty_set(sender);

CREATE INDEX IF NOT EXISTS token_royalty_set_receiver_inx
ON nft.token_royalty_set(receiver);

/*************************************************************************
event TokenRoyaltyReset(address indexed sender, uint256 tokenId);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.token_royalty_reset
(
  sender                                            address NOT NULL,
  token_id                                          uint256 NOT NULL
) INHERITS(core.transactions);

CREATE INDEX IF NOT EXISTS token_royalty_reset_sender_inx
ON nft.token_royalty_reset(sender);


/*************************************************************************
event BaseUriSet(string previous, string current);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.base_uri_set
(
  previous                                          text NOT NULL,
  current                                           text NOT NULL
) INHERITS(core.transactions);

/*************************************************************************
event SoulBound(uint256 id);
*************************************************************************/
CREATE TABLE IF NOT EXISTS nft.soul_bound
(
  token_id                                          uint256 NOT NULL
) INHERITS(core.transactions);



/***************************************************************************************
----------------------------------------------------------------------------------------
***************************************************************************************/
DELETE FROM characters;

INSERT INTO characters(level, role, name, description, start_index, siblings, rarity, stage)
SELECT 1 AS level, 'Guardian' AS role, 'Delphinus' AS name, 'The stellar dolphin guardian empowered by the heavens' AS description, 100000 AS start_index, 1000 AS siblings, 5 AS rarity, 'Selection' AS stage
UNION ALL
SELECT 1 AS level, 'Beast' AS role, 'Sabersquatch' AS name, 'A bloodthirsty predator and hunter of the weak' AS description, 110000 AS start_index, 1000 AS siblings, 5 AS rarity, 'Selection' AS stage
UNION ALL
SELECT 2 AS level, 'Guardian' AS role, 'Epic Delphinus' AS name, 'The stellar dolphin guardian empowered by the heavens' AS description, 120000 AS start_index, 500 AS siblings, 6 AS rarity, 'Evolution' AS stage
UNION ALL
SELECT 2 AS level, 'Beast' AS role, 'Diabolic Sabersquatch' AS name, 'A bloodthirsty predator and hunter of the weak' AS description, 121000 AS start_index, 500 AS siblings, 6 AS rarity, 'Evolution' AS stage
UNION ALL
SELECT 3 AS level, 'Guardian' AS role, 'Aquavallo' AS name, 'The steadfast seahorse guardian in voyage and battles' AS description, 130000 AS start_index, 250 AS siblings, 7 AS rarity, 'Selection' AS stage
UNION ALL
SELECT 3 AS level, 'Beast' AS role, 'Gargantuworm' AS name, 'A gigantic worm wreaking havoc and destruction' AS description, 131000 AS start_index, 250 AS siblings, 7 AS rarity, 'Selection' AS stage
UNION ALL
SELECT 4 AS level, 'Guardian' AS role, 'Epic Aquavallo' AS name, 'The steadfast seahorse guardian in voyage and battles' AS description, 140000 AS start_index, 200 AS siblings, 8 AS rarity, 'Evolution' AS stage
UNION ALL
SELECT 4 AS level, 'Beast' AS role, 'Diabolic Gargantuworm' AS name, 'A gigantic worm wreaking havoc and destruction' AS description, 141000 AS start_index, 200 AS siblings, 8 AS rarity, 'Evolution' AS stage
UNION ALL
SELECT 5 AS level, 'Guardian' AS role, 'Salacia' AS name, 'The majestic goddess and shielding light of the seas' AS description, 150000 AS start_index, 100 AS siblings, 9 AS rarity, 'Selection' AS stage
UNION ALL
SELECT 5 AS level, 'Beast' AS role, 'Merman Serpent' AS name, 'A vicious reptilian monster corrupting the seas' AS description, 151000 AS start_index, 100 AS siblings, 9 AS rarity, 'Selection' AS stage
UNION ALL
SELECT 6 AS level, 'Guardian' AS role, 'Epic Salacia' AS name, 'The majestic goddess and shielding light of the seas' AS description, 160000 AS start_index, 50 AS siblings, 10 AS rarity, 'Evolution' AS stage
UNION ALL
SELECT 6 AS level, 'Beast' AS role, 'Diabolic Merman Serpent' AS name, 'A vicious reptilian monster corrupting the seas' AS description, 161000 AS start_index, 50 AS siblings, 10 AS rarity, 'Evolution' AS stage
UNION ALL
SELECT 7 AS level, 'Guardian' AS role, 'Legendary Neptune' AS name, 'The all-powerful god of the sea and protector of the chain' AS description, 170000 AS start_index, 25 AS siblings, 10 AS rarity, 'Finale' AS stage
UNION ALL
SELECT NULL AS level, 'Beast' AS role, 'Grim Wyvern' AS name, 'A monstrous flying dragon vengefully targeting the chain' AS description, 180000 AS start_index, -1 AS siblings, 3 AS rarity, 'Soulbound' AS stage
UNION ALL
SELECT NULL AS level, 'Beast' AS role, 'Diabolic Grim Wyvern' AS name, 'A monstrous flying dragon vengefully targeting the chain' AS description, 190000 AS start_index, 1000 AS siblings, 5 AS rarity, NULL AS stage
UNION ALL
SELECT NULL AS level, 'Guardian' AS role, 'Neptune' AS name, 'The all-powerful god of the sea and protector of the chain' AS description, 199000 AS start_index, 25 AS siblings, 10 AS rarity, NULL AS stage;

CREATE OR REPLACE FUNCTION quote_literal_ilike(_ilike text)
RETURNS text
IMMUTABLE
AS
$$
BEGIN
  RETURN quote_literal(CONCAT('%', TRIM(_ilike), '%'));
END
$$
LANGUAGE plpgsql;
DROP VIEW IF EXISTS config_blockchain_network_view CASCADE;

CREATE VIEW config_blockchain_network_view
AS
SELECT
  1                                             AS chain_id,
  'Main Ethereum Network'                       AS network_name,
  'Mainnet'                                     AS nick_name,
  'ETH'                                         AS currency,
  'USDC'                                        AS stablecion,
  6                                             AS stablecoin_decimals,
  '0xb452ac021a1151aaf342c1b75aa914e03e6503b5'  AS protocol_address,
  '0x6579df8f986e4a982f200dafa0c1b955a438f620'  AS store_address,
  '0x57f12FE6A4e5fe819eec699FAdf9Db2D06606bB4'  AS npm_address,
  'https://etherscan.io/'                       AS explorer UNION ALL
SELECT 42161                                    AS chain_id,
  'Arbitrum One'                                AS network_name,
  'Arbitrum'                                    AS nick_name,
  'ETH'                                         AS currency,
  'USDC'                                        AS stablecion,
  6                                             AS stablecoin_decimals,
  '0xb452ac021a1151aaf342c1b75aa914e03e6503b5'  AS protocol_address,
  '0x6579df8f986e4a982f200dafa0c1b955a438f620'  AS store_address,
  '0x57f12FE6A4e5fe819eec699FAdf9Db2D06606bB4'  AS npm_address,
  'https://arbiscan.io/'                        AS explorer UNION ALL
SELECT 84531                                    AS chain_id,
  'Base Goerli'                                 AS network_name,
  'Base Goerli'                                 AS nick_name,
  'ETH'                                         AS currency,
  'USDC'                                        AS stablecion,
  6                                             AS stablecoin_decimals,
  '0x3b60152bfea33b894e06291aa2bb3404b8dfdc2b'  AS protocol_address,
  '0x52b124a19023edf0386a3d9e674fdd7e02b8a8a8'  AS store_address,
  '0x4bbdc138dd105c7dde874df7fcd087b064f7973d'  AS npm_address,
  'https://goerli.basescan.org/'                AS explorer;

DROP VIEW IF EXISTS config_known_ipfs_hashes_view CASCADE;

CREATE VIEW config_known_ipfs_hashes_view
AS
SELECT 'QmaADrtP13cZKwz5pdipXhU5F8WWXenBTZrUFp2MK4yVf2' AS ipfs_hash, '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x6f6e65696e63682d763300000000000000000000000000000000000000000000","productName":"1inch v3","requiresWhitelist":false,"efficiency":"4000","tags":["exchange","dex","swap","aggregation"],"about":"The 1inch Network unites decentralized protocols whose synergy enables the most lucrative, fastest, and protected operations in the DeFi space by offering access to hundreds of liquidity sources across multiple chains. The 1inch Network was launched at the ETHGlobal New York hackathon in May 2019 with the release of its Aggregation Protocol v1. Since then, 1inch Network has developed additional DeFi tools such as the Liquidity Protocol, Limit Order Protocol, P2P transactions, and 1inch Mobile Wallet.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":56,"name":"BNB Smart Chain Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the 1inch v3 protocol deployed on the Ethereum and BNB blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and BNB."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://1inch.io/","twitter":"https://twitter.com/1inch","blog":"https://blog.1inch.io/","documentation":"https://docs.1inch.io/","reddit":"https://www.reddit.com/r/1inch/","discord":"https://discord.com/invite/1inch","youtube":"https://www.youtube.com/channel/UCk0nvK4bHpteQXZKv7lkq5w","telegram":"https://t.me/OneInchNetwork","github":"https://github.com/1inch"},"resolutionSources":[{"text":"1inch Blog","uri":"https://blog.1inch.io/"},{"text":"1inch Twitter","uri":"https://twitter.com/1inch"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' AS ipfs_details UNION ALL
SELECT 'Qmac3pwFj4YirygAdqhEiyezzb5TUQFNCsD43R6ETo67ZV', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x676d782d76310000000000000000000000000000000000000000000000000000","productName":"GMX v1","requiresWhitelist":false,"efficiency":"6000","tags":["perpetual","trade","dex","leverage","swap"],"about":"GMX is a permissionless, decentralized spot and perpetual swap exchange on the Arbitrum network.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the GMX version 1 deployed on the Arbitrum and Ethereum blockchain (if available).","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum (if available)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gmx.io","app":"https://app.gmx.io","twitter":"https://twitter.com/GMX_IO","medium":"https://medium.com/@gmx.io","github":"https://github.com/gmx-io","telegram":"https://t.me/GMX_IO","discord":"https://discord.com/invite/ymN38YefH9"},"resolutionSources":[{"text":"GMX Blog","uri":"https://medium.com/@gmx.io"},{"text":"GMX Twitter","uri":"https://twitter.com/GMX_IO"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmagNBTagrbtG9EZhNFPXPiRAL1Cfq2cyT3WCzrqaJStt1', '{"title":"Curve Exploit","observed":"2023-07-31T08:08:00.000Z","proofOfIncident":["https://twitter.com/CurveFinance/status/1685925429041917952"],"description":"As a result of an issue in Vyper compiler in versions 0.2.15-0.3.0, following pools were hacked:\n\ncrv/eth\naleth/eth\nmseth/eth\npeth/eth\n\nAnother pool potentially affected is arbitrum’s tricrypto. Auditors and Vyper devs could not find a profitable exploit, but please exit that one","stake":"10000000000000000000000","createdBy":"0xB20d066d416ECFEC10C2Ed47390e44E0e4baFceD","permalink":"https://arbitrum.neptunemutual.net/reports/0x7072696d65000000000000000000000000000000000000000000000000000000/products/0x63757276652d7632000000000000000000000000000000000000000000000000"}' UNION ALL
SELECT 'QmaiakyFf99GsvJ3aD4JTPBmMhbVCjmdiCA6UqMyv2GuTp', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x616176652d763200000000000000000000000000000000000000000000000000","productName":"Aave Ethereum Market v2","requiresWhitelist":false,"efficiency":"9000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Aave is a decentralized non-custodial liquidity protocol where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) or undercollateralized (one-block liquidity) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the AAVE v2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://aave.com/","documentation":"https://docs.aave.com/","twitter":"https://twitter.com/aaveaave","github":"https://github.com/aave","discord":"https://discord.com/invite/CvKUrqM","telegram":"https://t.me/Aavesome","blog":"https://medium.com/aave","linkedin":""},"resolutionSources":[{"text":"Aave Twitter","uri":"https://twitter.com/aaveaave"},{"text":"Aave Blog","uri":"https://medium.com/aave"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmaKba8ZJdvVHTxXDD8ycajgzXwG1zSbGHD5fvnhHyyHJx', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x62616c616e6365722d7632000000000000000000000000000000000000000000","productName":"Balancer v2","requiresWhitelist":false,"efficiency":"7500","tags":["exchange","swap","dex","launchpad","flashloan"],"about":"Balancer is an automated market maker (AMM ) that allows LPs to deposit more types of tokens to liquidity pools instead of a pair, also gives more flexibility for LP creator to customize trading fees or create private pools. With the launch of V2 (since May 2021) the single Vault architecture separates the token accounting and management from the Pool logic, hence assets can shift around without emitting an ERC20 transfer event on-chain improving gas efficiency for traders.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Balancer V2 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions."]}}],"links":{"website":"https://balancer.fi/","twitter":"https://twitter.com/BalancerLabs","discord":"https://discord.balancer.fi/","blog":"https://medium.com/balancer-protocol","linkedin":"https://www.linkedin.com/company/balancer-labs/","youtube":"https://www.youtube.com/channel/UCBRHug6Hu3nmbxwVMt8x_Ow","github":"https://github.com/balancer-labs/"},"resolutionSources":[{"text":"Balancer Blog","uri":"https://medium.com/balancer-protocol"},{"text":"Balancer Twitter","uri":"https://twitter.com/BalancerLabs"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qmb8DRD8qE1irpj9YHTdkNks5BhLGyE1h8T86amhef77re', '{"coverKey":"0x62696e616e636500000000000000000000000000000000000000000000000000","coverName":"Binance Exchange Custody","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-BNB","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","bnb","binance"],"about":"Founded in 2017 Binance is by far the largest centralized crypto exchange ranked by daily volume traded. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users outside of the US and US territories (not any other apps listed on the platform)","To be eligible for a claim, policyholders must hold at least 100 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"One of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["The designated exchange platform suffers a security breach of its hot or cold wallets where the minimum total loss of funds exceeds $50M","Or the exchange halts all asset withdrawals for all users for more than 15 days except for Legitimate Reasons as defined under the Standard Terms and Conditions. In this case, incident report cannot be submitted until the expiry of the 15-day withdrawal-halt period. No policy could be purchased after withdrawal halt by the exchange and if any such policy purchased after withdrawal halt will be deemed invalid. Any policies that are expired prior to the end of the 15-day withdrawal-halt period will not be eligible for payout"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"50","ceiling":"1600","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"50000000000000000000000","stakeWithFee":"30000000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500","links":{"website":"https://binance.com/","discord":"https://discord.com/invite/jE4wt8g2H2","blog":"https://www.binance.com/en/blog","tiktok":"https://www.tiktok.com/@binance?lang=en","facebook":"https://www.facebook.com/binance","twitter":"https://twitter.com/binance","reddit":"https://www.reddit.com/r/binance/","instagram":"https://www.instagram.com/Binance/","coinmarketcap":"https://coinmarketcap.com/exchanges/binance/","youtube":"https://www.youtube.com/binanceyoutube"},"resolutionSources":[{"text":"Binance Twitter","uri":"https://twitter.com/binance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qmbije1EuhbETvUqcA1WR5Gt8QNrmwVM2diE5utX4LoLbX', '{"coverKey":"0x676d782d76310000000000000000000000000000000000000000000000000000","coverName":"GMX","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-GMX","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["perpetual","trade","dex","leverage","swap","glp"],"about":"GMX Exchange is a decentralized perpetual trading platform for top cryptocurrencies. Launched in September 2021, GMX allows traders to take long and short positions on perpetuals by depositing collateral. With up to 50x leverage, zero price impact trades, limit orders, and low swap fees, GMX has become a popular choice among DeFi traders. The DEX is currently live on Arbitrum and Avalanche.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process","list":{"type":"unordered","items":["This policy relates exclusively to  GMX version 2 deployed on the Arbitrum blockchain.  It includes smart contract risk associated with GLP.","To be eligible for a claim, policyholders must hold at least 399 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from the Arbitrum blockchain."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["Risks associated with the token bridges, including https://arbitrum.io/bridge-tutorial/ are excluded.","GLP counterparty risks are excluded.","All exclusions present in the standard terms and exclusions."]}}],"blockchains":[{"chainId":42161,"name":"Arbitrum"},{"chainId":43114,"name":"Avalanche C-Chain"}],"floor":"200","ceiling":"1800","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"400000000000000000000","stakeWithFee":"15000000000000000000000","initialReassuranceAmount":"25000000000","reassuranceRate":"2000","links":{"website":"https://gmx.io/","app":"https://app.gmx.io","discord":"https://discord.com/invite/ymN38YefH9","blog":"https://medium.com/@gmx.io","twitter":"https://twitter.com/GMX_IO","telegram":"https://t.me/GMX_IO","github":"https://github.com/gmx-io"},"resolutionSources":[{"text":"GMX Blog","uri":"https://medium.com/@gmx.io"},{"text":"GMX Twitter","uri":"https://twitter.com/GMX_IO"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmbQNn4ZstkW6aeaVeZ4DnBqx3Cg7pvoopsERFVmW9pwEB', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","coverName":"Popular DeFi Apps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-POP","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"6","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":56,"name":"BNB Chain"}],"floor":"200","ceiling":"1200","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"10000000000000000000000","stakeWithFee":"12500000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500"}' UNION ALL
SELECT 'Qmbuk5Bz1WFL7N3fPiPeofXrjdTH9owa97QXVstDrCYg8v', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x616176652d763200000000000000000000000000000000000000000000000000","productName":"Aave Ethereum Market v2","requiresWhitelist":false,"efficiency":"10000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Aave is a decentralized non-custodial liquidity protocol where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) or undercollateralized (one-block liquidity) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the AAVE v2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://aave.com/","documentation":"https://docs.aave.com/","twitter":"https://twitter.com/aaveaave","github":"https://github.com/aave","discord":"https://discord.com/invite/CvKUrqM","telegram":"https://t.me/Aavesome","blog":"https://medium.com/aave","linkedin":""},"resolutionSources":[{"text":"Aave Twitter","uri":"https://twitter.com/aaveaave"},{"text":"Aave Blog","uri":"https://medium.com/aave"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmcFbX3fHrnjLqtJbMLMJk2njFga6RPq2SysG3owZF6ziY', '{"coverKey":"0x62696e616e636500000000000000000000000000000000000000000000000000","coverName":"Binance Exchange Custody","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-BNB","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","bnb","binance"],"about":"Founded in 2017 Binance is by far the largest centralized crypto exchange ranked by daily volume traded. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users outside of the US and US territories (not any other apps listed on the platform)","To be eligible for a claim, policyholders must hold at least 100 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"One of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["The designated exchange platform suffers a security breach of its hot or cold wallets where the minimum total loss of funds exceeds $50M","Or the exchange halts all asset withdrawals for all users for more than 15 days except for Legitimate Reasons as defined under the Standard Terms and Conditions. In this case, incident report cannot be submitted until the expiry of the 15-day withdrawal-halt period. No policy could be purchased after withdrawal halt by the exchange and if any such policy purchased after withdrawal halt will be deemed invalid. Any policies that are expired prior to the end of the 15-day withdrawal-halt period will not be eligible for payout"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"50","ceiling":"1600","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"50000000000000000000000","stakeWithFee":"12500000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500","links":{"website":"https://binance.com/","discord":"https://discord.com/invite/jE4wt8g2H2","blog":"https://www.binance.com/en/blog","tiktok":"https://www.tiktok.com/@binance?lang=en","facebook":"https://www.facebook.com/binance","twitter":"https://twitter.com/binance","reddit":"https://www.reddit.com/r/binance/","instagram":"https://www.instagram.com/Binance/","coinmarketcap":"https://coinmarketcap.com/exchanges/binance/","youtube":"https://www.youtube.com/binanceyoutube"},"resolutionSources":[{"text":"Binance Twitter","uri":"https://twitter.com/binance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmcGnscy5Mfdu6sc8sLWdHTMgjEuXS5rMZbc3MzWEV3yJq', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","coverName":"Popular DeFi Apps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-POP","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"10","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"floor":"200","ceiling":"1200","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"25000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500"}' UNION ALL
SELECT 'QmchsMM8GzKQUain63VW2shmZu319E3wFcs4uosGhDq3rM', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","coverName":"Prime dApps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-PRI","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"6","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"floor":"50","ceiling":"800","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"10000000000000000000000","stakeWithFee":"12000000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500"}' UNION ALL
SELECT 'QmcK1pTGGqa7RHwxZtid5EL6ncSXR8Trnbc7yDCuC8vj1H', '{"title":"Curve pools been exploited","observed":"2023-07-31T06:07:00.000Z","proofOfIncident":["https://twitter.com/curvefinance/status/1685693202722848768?s=46&t=MS9Mk_e5oFCUxeHDdAmLuQ"],"description":"According to Curve Protocol''s tweet:\nA number of stablepools (alETH/msETH/pETH) using Vyper 0.2.15 have been exploited as a result of a malfunctioning reentrancy lock.","stake":"10000000000000000000000","createdBy":"0xada72FCb3539872D4510e6105aF969ae39558472","permalink":"https://ethereum.neptunemutual.net/reports/0x7072696d65000000000000000000000000000000000000000000000000000000/products/0x63757276652d7632000000000000000000000000000000000000000000000000"}' UNION ALL
SELECT 'QmctEE6U5BS63FvkU6QD8eSR91K1g7G6owRoKfLYLG61zo', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x736166652d763100000000000000000000000000000000000000000000000000","productName":"Safe v1","requiresWhitelist":false,"efficiency":"9500","tags":["wallet","multi-sig"],"about":"Gnosis Safe is the successor to the Gnosis Multisig. Multi-signature. Multi-signature allows you define an access/control-scheme through multiple signers that need to confirm transactions. DeFi integrations. Easily interact with popular decentralized finance protocols to invest, trade and manage digital assets.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to all of the instances of Gnosis Safe v1 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gnosis-safe.io/","twitter":"https://twitter.com/gnosisSafe","discord":"https://discord.com/invite/AjG7AQD9Qn","github":"https://github.com/safe-global","documentation":"https://docs.gnosis-safe.io/"},"resolutionSources":[{"text":"Gnosis Safe Twitter","uri":"https://twitter.com/gnosisSafe"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmcTj2zcuHRfxx2HKiVMumy35SCiYHiJD6Xe14rKNjuGe4', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x63757276652d7632000000000000000000000000000000000000000000000000","productName":"Curve Finance v2","requiresWhitelist":false,"efficiency":"7000","tags":["dex","exchange","swap","stablecoin"],"about":"Curve is an automated market maker (AMM), The main difference between Curve and other DEXes is that Curve focuses mainly on stablecoins trading. Thereby improving capital efficiency and reducing slippage. The release of its V2 since June 2021, also allows trading of non-pegged assets in a more concentrated liquidity fashion whilst still allowing LP to passively provide liquidity without specifying a price range.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Curve v2 protocol deployed on the Arbitrum and Ethereum blockchains.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://curve.fi/","twitter":"https://twitter.com/CurveFinance","telegram":"https://t.me/curvefi","discord":"https://discord.com/invite/9uEHakc","documentation":"https://resources.curve.fi/","github":"https://github.com/curvefi"},"resolutionSources":[{"text":"Curve News","uri":"https://news.curve.fi"},{"text":"Curve Twitter","uri":"https://twitter.com/CurveFinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmcyCnFeKwM7mnvz4w3x7cvcjJ1HD9uHGrTv8bdZWc1rDi', '{"coverKey":"0x68756f6269000000000000000000000000000000000000000000000000000000","coverName":"Huobi Global","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-HT","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","huobi","ht"],"about":"Founded in 2013 Huobi Global is amongst the battle tested crypto exchanges with longer operating history and once ranked number 1 globally in terms of trading volume. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users (outside of US and US territories).","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $50 million.","Huobi suffers a security breach of its hot or cold wallets where the user funds are permanently and irrecoverably stolen from Huobi.","The loss must arise from security incidents of the crypto storage systems"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Losses arisen due to issues with fork, merge,  any other changes of relevant underlying blockchains","Losses resulting from Key man risk where a single person controls access to the user funds at the custodian, is not covered.","Huobi non custodial wallet is not relevant to this cover","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"400","ceiling":"1600","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"27000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500","links":{"website":"https://www.huobi.com/","blog":"https://blog.huobi.com/","twitter":"https://twitter.com/huobiglobal","instagram":"https://www.instagram.com/huobiglobalofficial/","youtube":"https://www.youtube.com/huobiglobal","facebook":"https://www.facebook.com/huobiglobalofficial","reddit":"https://www.reddit.com/r/HuobiGlobal/","linkedin":"https://www.linkedin.com/company/huobi/"},"resolutionSources":[{"text":"Huobi Twitter","uri":"https://twitter.com/huobiglobal"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qmd8p5a5eUXFF9XofGCi9EWD8dnQayfPfANfRB4vGUtXqt', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","coverName":"Popular DeFi Apps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-POP","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"6","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"floor":"200","ceiling":"1200","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"10000000000000000000000","stakeWithFee":"30000000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500"}' UNION ALL
SELECT 'QmdDBBpGVParKgMGYTYzPs6edjcogByjJhRJ77guvUEukP', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x636f6d706f756e642d7633000000000000000000000000000000000000000000","productName":"Compound Finance","requiresWhitelist":false,"efficiency":"7000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Compound  is a decentralized non-custodial liquidity protocol on Ethereum where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"},{"chainId":137,"name":"Polygon Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Compound V3 protocol deployed on the Arbitrum, Ethereum and Polygon Mainnet blockchains.","To be eligible for a claim, policyholder must hold at least 99 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum, Ethereum and Polygon Mainnet."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://compound.finance/","discord":"https://discord.com/invite/fq6JSPkpJn","github":"https://github.com/compound-finance/compound-protocol","blog":"https://medium.com/compound-finance","twitter":"https://twitter.com/compoundfinance","app":"https://app.compound.finance/"},"resolutionSources":[{"text":"Compound Twitter","uri":"https://twitter.com/compoundfinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmdpPqKV1QVxjq21FHa4UP7Hn4urWAK23BWaYxyWoLvUkP', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x676e6f7369732d736166652d7631000000000000000000000000000000000000","productName":"Gnosis Safe v1","requiresWhitelist":false,"efficiency":"7000","tags":["wallet","multi-sig"],"about":"Gnosis Safe is the successor to the Gnosis Multisig. Multi-signature. Multi-signature allows you define an access/control-scheme through multiple signers that need to confirm transactions. DeFi integrations. Easily interact with popular decentralized finance protocols to invest, trade and manage digital assets.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to all of the instances of Gnosis Safe v1 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gnosis-safe.io/","twitter":"https://twitter.com/gnosisSafe","discord":"https://discord.com/invite/AjG7AQD9Qn","github":"https://github.com/safe-global","documentation":"https://docs.gnosis-safe.io/"},"resolutionSources":[{"text":"Gnosis Safe Twitter","uri":"https://twitter.com/gnosisSafe"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmdVzaJvHjZ9aqkV86cbJH2zihhME8MF22QegZm8C3r7qc', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x6f6e65696e63682d763200000000000000000000000000000000000000000000","productName":"1inch v2","requiresWhitelist":false,"efficiency":"8000","tags":["exchange","dex","swap","aggregation"],"about":"The 1inch Network brings together decentralized protocols that work synergistically to provide efficient, secure operations in the DeFi space. It offers access to a multitude of liquidity sources across various chains. The 1inch Network was launched at the ETHGlobal New York hackathon in May 2019 with the release of its Aggregation Protocol v1. Since then, the 1inch Network has added more DeFi tools to its repertoire, including the Liquidity Protocol, Limit Order Protocol, P2P transactions, and the 1inch Mobile Wallet.","blockchains":[{"chainId":56,"name":"BNB Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the 1inch v2 protocol deployed on the BNB Smart Chain.","To be eligible for a claim, the policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: BNB Smart Chain (BSC) (Previously Binance Smart Chain)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://1inch.io/","twitter":"https://twitter.com/1inch","blog":"https://blog.1inch.io/","documentation":"https://docs.1inch.io/","reddit":"https://www.reddit.com/r/1inch/","discord":"https://discord.com/invite/1inch","youtube":"https://www.youtube.com/channel/UCk0nvK4bHpteQXZKv7lkq5w","telegram":"https://t.me/OneInchNetwork","github":"https://github.com/1inch"},"resolutionSources":[{"text":"1inch Blog","uri":"https://blog.1inch.io/"},{"text":"1inch Twitter","uri":"https://twitter.com/1inch"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmdYHrqdRPAwBg32HCYMiG5RtdJ4Gb71igoGUrHfDzVeqq', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x636f6e7665782d76310000000000000000000000000000000000000000000000","productName":"Convex (Curve)","requiresWhitelist":false,"efficiency":"5000","tags":["curve","staking","yield"],"about":"Convex Finance is a platform for CRV token holders and Curve LPs to earn additional interest and  trading fees.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the version 1 version of the protocol (Convex/Curve) deployed on the Ethereum and Arbitrum blockchain.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and Arbitrum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://www.convexfinance.com","docs":"https://docs.convexfinance.com/","blog":"https://convexfinance.medium.com","twitter":"https://twitter.com/ConvexFinance","discord":"https://discord.com/invite/TTEVTqY488","telegram":"https://t.me/convexEthChat"},"resolutionSources":[{"text":"Convex Twitter","uri":"https://twitter.com/ConvexFinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qme5v1qf7tBZWASYpBMBzQ3shB61KXJwAKrDEuFcyrjSAn', '{"coverKey":"0x62696e616e636500000000000000000000000000000000000000000000000000","coverName":"Binance Exchange","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-BNB","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","bnb","binance"],"about":"Founded in 2017 Binance is by far the largest centralized crypto exchange ranked by daily volume traded. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users (outside of US and US territories).","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $50 million.","Binance suffers a security breach of its hot or cold wallets where the user funds are permanently and irrecoverably stolen from Binance.","The loss must arise from security incidents of the crypto storage systems"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Losses arisen due to issues with fork, merge,  any other changes of relevant underlying blockchains","Losses resulting from Key man risk where a single person controls access to the user funds at the custodian, is not covered.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"400","ceiling":"1600","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"30000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500","links":{"website":"https://binance.com/","discord":"https://discord.com/invite/jE4wt8g2H2","blog":"https://www.binance.com/en/blog","tiktok":"https://www.tiktok.com/@binance?lang=en","facebook":"https://www.facebook.com/binance","twitter":"https://twitter.com/binance","reddit":"https://www.reddit.com/r/binance/","instagram":"https://www.instagram.com/Binance/","coinmarketcap":"https://coinmarketcap.com/exchanges/binance/","youtube":"https://www.youtube.com/binanceyoutube"},"resolutionSources":[{"text":"Binance Twitter","uri":"https://twitter.com/binance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qme8nonYp95gD5e7K7VFP1SdaR82v8vTHVPKjbZ9gjRtVX', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x636f6d706f756e642d7633000000000000000000000000000000000000000000","productName":"Compound Finance","requiresWhitelist":false,"efficiency":"7000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Compound  is a decentralized non-custodial liquidity protocol on Ethereum where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"},{"chainId":137,"name":"Polygon Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Compound V3 protocol deployed on the Arbitrum, Ethereum and Polygon Mainnet blockchains.","To be eligible for a claim, policyholder must hold at least 99 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum, Ethereum and Polygon Mainnet."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://compound.finance/","discord":"https://discord.com/invite/fq6JSPkpJn","github":"https://github.com/compound-finance/compound-protocol","blog":"https://medium.com/compound-finance","twitter":"https://twitter.com/compoundfinance","app":"https://app.compound.finance/"},"resolutionSources":[{"text":"Compound Twitter","uri":"https://twitter.com/compoundfinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qmeu6eZfyQt25bW6JWWqwWPVBGythbBnFZEFytwY23iRgc', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x756e69737761702d763200000000000000000000000000000000000000000000","productName":"Uniswap v2","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","nft"],"about":"The Uniswap protocol is a peer-to-peer system designed for exchanging cryptocurrencies (ERC-20 Tokens) on the Ethereum blockchain. The protocol is implemented as a set of persistent, non-upgradable smart contracts; designed to prioritize censorship resistance, security, self-custody, and to function without any trusted intermediaries who may selectively restrict access.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Uniswap V2 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://uniswap.org/","app":"https://app.uniswap.org/#/swap?use=V2","twitter":"https://twitter.com/Uniswap","blog":"https://uniswap.org/blog","discord":"https://discord.com/invite/FCfyBSbCU5","github":"https://github.com/Uniswap","docs":"https://docs.uniswap.org/protocol/V2/introduction"},"resolutionSources":[{"text":"Uniswap Blog","uri":"https://uniswap.org/blog"},{"text":"Uniswap Twitter","uri":"https://twitter.com/Uniswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmeUY4Lo9VuRL2Fr5aftCv21rLGbuDMB8tg7LkiTpUeaKX', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x756e69737761702d763300000000000000000000000000000000000000000000","productName":"Uniswap v3","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","flashloan","nft"],"about":"The Key difference of UniswapV3 compared to V2 is “concentrated liquidity”,  allowing LPs to control the price range in which their assets get traded. To reduce slippage and improve capital efficiency. V3 is released in May 2021.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Uniswap v3 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://uniswap.org/","app":"https://app.uniswap.org/#/swap","twitter":"https://twitter.com/Uniswap","blog":"https://uniswap.org/blog","discord":"https://discord.com/invite/FCfyBSbCU5","github":"https://github.com/Uniswap","docs":"https://docs.uniswap.org/protocol/introduction"},"resolutionSources":[{"text":"Uniswap Blog","uri":"https://uniswap.org/blog"},{"text":"Uniswap Twitter","uri":"https://twitter.com/Uniswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmfD3Pp6tockqnhzzDLT1TDiZJZ7B4o56QY6aSepYGduDP', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x72706c2d76310000000000000000000000000000000000000000000000000000","productName":"Rocketpool v1","requiresWhitelist":false,"efficiency":"9000","tags":["staking","yield"],"about":"Rocket Pool is a liquid staking service protocol that runs a network of decentralized nodes, to perform validation services for the Ethereum 2.0 blockchain. Its purpose is to provide users who do not possess the required minimum of ETH tokens to stake and earn yields.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Rocket Pool v1 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://rocketpool.net/","discord":"https://discord.com/invite/rocketpool","blog":"https://medium.com/rocket-pool","twitter":"https://twitter.com/Rocket_Pool","github":"https://github.com/rocket-pool","dao":"https://dao.rocketpool.net/","youtube":"https://www.youtube.com/rocketpool","reddit":"https://www.reddit.com/r/rocketpool/"},"resolutionSources":[{"text":"Rocket Pool Twitter","uri":"https://twitter.com/Rocket_Pool"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmfDdLWy3DdY5GAqnWJ8VoXD24Uv9AAssQeHrrnk6uu1Ve', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x756e69737761702d763300000000000000000000000000000000000000000000","productName":"Uniswap v3","requiresWhitelist":false,"efficiency":"9500","tags":["exchange","dex","swap","nft"],"about":"The Uniswap protocol is a peer-to-peer system designed for exchanging cryptocurrencies (ERC-20 Tokens) on the Ethereum blockchain. The protocol is implemented as a set of persistent, non-upgradable smart contracts. It is designed to prioritize censorship resistance, security, self-custody, and to function without any trusted intermediaries who may selectively restrict access. It has been deployed on the BNB Smart Chain since early 2023.","blockchains":[{"chainId":56,"name":"BNB Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Uniswap v3 deployed on the BNB Smart Chain.","To be eligible for a claim, the policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: BNB Smart Chain (BSC) (Previously Binance Smart Chain)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://uniswap.org/","app":"https://app.uniswap.org/#/swap?use=V2","twitter":"https://twitter.com/Uniswap","blog":"https://uniswap.org/blog","discord":"https://discord.com/invite/FCfyBSbCU5","github":"https://github.com/Uniswap","docs":"https://docs.uniswap.org/protocol/V2/introduction"},"resolutionSources":[{"text":"Uniswap Blog","uri":"https://uniswap.org/blog"},{"text":"Uniswap Twitter","uri":"https://twitter.com/Uniswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmfEViRmvDaE8GaGWrgEjkAHsTx9Dmcsiwtu2TTYfi8M9Y', '{"coverKey":"0x636f696e62617365000000000000000000000000000000000000000000000000","coverName":"Coinbase (Non US)","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-COIN","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","coinbase","coin"],"about":"Founded in 2012 Coinbase is the largest exchange for institutional crypto traders, and the first crypto exchange that went public and listed on Nasdaq. Users can trade mainly spots via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users (outside of US and US territories).","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $50 million.","Coinbase suffers a security breach of its hot or cold wallets where the user funds are permanently and irrecoverably stolen from Coinbase.","The loss must arise from security incidents of the crypto storage systems"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Losses arisen due to issues with fork, merge,  any other changes of relevant underlying blockchains","Losses resulting from Key man risk where a single person controls access to the user funds at the custodian, is not covered.","Coinbase non custodial wallet is not relevant to this cover","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"400","ceiling":"1600","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"26000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500","links":{"website":"https://coinbase.com/","blog":"https://www.coinbase.com/blog","twitter":"https://twitter.com/coinbase","facebook":"https://www.facebook.com/Coinbase"},"resolutionSources":[{"text":"Coinbase Twitter","uri":"https://twitter.com/coinbase"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmNkoMt274zKMXFz5cKzNUNvfXNFpBgm3nZTTFKA47wmDu', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x73796e7468657469782d76320000000000000000000000000000000000000000","productName":"Synthetix v2","requiresWhitelist":false,"efficiency":"8000","tags":["derivative","staking","yield"],"about":"Synthetix is a new financial primitive enabling the creation of synthetic assets, offering unique derivatives and exposure to real-world assets on the blockchain.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":10,"name":"OP Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Synthetix Protocol (v2) deployed on the Ethereum and OP Mainnet blockchains.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and OP Mainnet."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://synthetix.io/","discord":"https://discord.com/invite/AEdUHzt","twitter":"https://twitter.com/synthetix_io","github":"https://github.com/synthetixio","blog":"https://blog.synthetix.io/","dao":"https://synthetix.io/governance","documentation":"https://docs.synthetix.io/"},"resolutionSources":[{"text":"Synthetix Twitter","uri":"https://twitter.com/synthetix_io"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmNrtsqPhdDwNZwsxyjPjgFzD1XM2VvLPhEiTMu9uiikXM', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x6e657875732d6d757475616c2d76310000000000000000000000000000000000","productName":"Nexus Mutual v1","requiresWhitelist":false,"efficiency":"9000","tags":["insurance","cover"],"about":"Nexus Mutual is a decentralized alternative to insurance. Nexus Mutual uses blockchain technology to create a risk sharing pool in the form of a mutual to return the power of insurance to the people. The platform is built on the Ethereum public chain. It allows anyone to become a member and purchase cover. It replaces the idea of a traditional insurance company because it is wholly owned by the members. The model encourages engagement as members will get economic incentives for participating in Risk Assessment, Claims Assessment and Governance.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Nexus Mutual v1 contracts deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://nexusmutual.io/","twitter":"https://twitter.com/NexusMutual","blog":"https://medium.com/nexus-mutual","documentation":"https://nexusmutual.gitbook.io/docs/users/understanding-nexus-mutual","github":"https://github.com/NexusMutual","discord":"https://discord.com/invite/aQjkzW5","telegram":"https://t.me/joinchat/K_g-fA-3CmFwXumCKQUXkw"},"resolutionSources":[{"text":"Nexus Mutual Twitter","uri":"https://twitter.com/NexusMutual"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmNTWRJnb1Luk4PwbqGZ3XY78bGRHeU7vw95HqmoySDnQa', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x73796e7468657469782d76320000000000000000000000000000000000000000","productName":"Synthetix v2","requiresWhitelist":false,"efficiency":"7000","tags":["derivative","staking","yield"],"about":"Synthetix is a new financial primitive enabling the creation of synthetic assets, offering unique derivatives and exposure to real-world assets on the blockchain.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Synthetix Protocol (v2) deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://synthetix.io/","discord":"https://discord.com/invite/AEdUHzt","twitter":"https://twitter.com/synthetix_io","github":"https://github.com/synthetixio","blog":"https://blog.synthetix.io/","dao":"https://synthetix.io/governance","documentation":"https://docs.synthetix.io/"},"resolutionSources":[{"text":"Synthetix Twitter","uri":"https://twitter.com/synthetix_io"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmP4BGgYVb8ZQyLDeAfk8oyszCRo2BPcqUYfh6uCeZDAMz', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x676d782d76320000000000000000000000000000000000000000000000000000","productName":"GMX v2","requiresWhitelist":false,"efficiency":"6000","tags":["perpetual","trade","dex","leverage","swap"],"about":"GMX is a permissionless, decentralized spot and perpetual swap exchange on the Arbitrum network.","blockchains":[{"chainId":42161,"name":"Arbitrum One"},{"chainId":43114,"name":"Avalanche C-Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the GMX version 1 deployed on the Arbitrum and Avalanche blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Avalanche."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gmx.io","app":"https://app.gmx.io","twitter":"https://twitter.com/GMX_IO","medium":"https://medium.com/@gmx.io","github":"https://github.com/gmx-io","telegram":"https://t.me/GMX_IO","discord":"https://discord.com/invite/ymN38YefH9"},"resolutionSources":[{"text":"GMX Blog","uri":"https://medium.com/@gmx.io"},{"text":"GMX Twitter","uri":"https://twitter.com/GMX_IO"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPabWcVa6t6tDjjTo6zneeaaub4EfoCnbNCkqFaX3LFKE', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x7375736869737761702d76330000000000000000000000000000000000000000","productName":"Sushiswap","requiresWhitelist":false,"efficiency":"5000","tags":["exchange","dex","swap","nft"],"about":"Sushiswap is  an automated market maker (AMM), in addition to facilitating market making for LPs and traders, Sushiswap also offers token aults for lending & borrowing.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"},{"chainId":56,"name":"BNB Smart Chain Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the v3 of the (Swap) protocol deployed on the Ethereum, Arbitrum and BNB blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum, Arbitrum and BNB."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://sushi.com/","twitter":"https://twitter.com/sushiswap","blog":"https://sushichef.medium.com/","github":"https://github.com/sushiswap","documentation":"https://dev.sushi.com/"},"resolutionSources":[{"text":"Sushi Blog","uri":"https://sushichef.medium.com"},{"text":"Sushi Twitter","uri":"https://twitter.com/sushiswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPEPkdEWPhfoQtX1XuFAerpZLDVtbbCYgiFiioMvHLwuo', '{"title":"Testing","observed":"2023-12-11T10:21:00.000Z","proofOfIncident":["https://example.com"],"description":"Test","stake":"2000000000000000000000","createdBy":"0x201Bcc0d375f10543e585fbB883B36c715c959B3","permalink":"https://mumbai.neptunemutual.com/reports/0x7072696d65000000000000000000000000000000000000000000000000000000/products/0x676e6f7369732d736166652d7631000000000000000000000000000000000000"}' UNION ALL
SELECT 'QmPiKWDUPVUJuW7bpqVpXRUyeC1rr3HNu9cUFrCE114BSB', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x63757276652d7632000000000000000000000000000000000000000000000000","productName":"Curve Finance v2","requiresWhitelist":false,"efficiency":"7000","tags":["dex","exchange","swap","stablecoin"],"about":"Curve is an automated market maker (AMM), The main difference between Curve and other DEXes is that Curve focuses mainly on stablecoins trading. Thereby improving capital efficiency and reducing slippage. The release of its V2 since June 2021, also allows trading of non-pegged assets in a more concentrated liquidity fashion whilst still allowing LP to passively provide liquidity without specifying a price range.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Curve v2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://curve.fi/","twitter":"https://twitter.com/CurveFinance","telegram":"https://t.me/curvefi","discord":"https://discord.com/invite/9uEHakc","documentation":"https://resources.curve.fi/","github":"https://github.com/curvefi"},"resolutionSources":[{"text":"Curve News","uri":"https://news.curve.fi"},{"text":"Curve Twitter","uri":"https://twitter.com/CurveFinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPiUWSq5P3JAChY4so6R7kQy33bVghBaS5dWNmg3ZQ5Ew', '{"title":"Test REPORT","observed":"2023-11-10T06:23:00.000Z","proofOfIncident":["https://thisisfake.com"],"description":"This is a fake report test. Please ignore this report.","stake":"2000000000000000000000","createdBy":"0x9BDAE2a084EC18528B78e90b38d1A67c79F6Cab6","permalink":"https://mumbai.neptunemutual.com/reports/0x7072696d65000000000000000000000000000000000000000000000000000000/products/0x676e6f7369732d736166652d7631000000000000000000000000000000000000"}' UNION ALL
SELECT 'QmPJHouJz6vx1JWX4ZG93CSLTp9wuM1JS6cQJz7tzsE4fd', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x7375736869737761702d76330000000000000000000000000000000000000000","productName":"Sushiswap","requiresWhitelist":false,"efficiency":"5000","tags":["exchange","dex","swap","nft"],"about":"Sushiswap is  an automated market maker (AMM), in addition to facilitating market making for LPs and traders, Sushiswap also offers token aults for lending & borrowing.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"},{"chainId":56,"name":"BNB Smart Chain Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the v3 of the (Swap) protocol deployed on the Ethereum, Arbitrum and BNB blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum, Arbitrum and BNB."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://sushi.com/","twitter":"https://twitter.com/sushiswap","blog":"https://sushichef.medium.com/","github":"https://github.com/sushiswap","documentation":"https://dev.sushi.com/"},"resolutionSources":[{"text":"Sushi Blog","uri":"https://sushichef.medium.com"},{"text":"Sushi Twitter","uri":"https://twitter.com/sushiswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPmBngN7neCy2ZGJyvu64drGscBjptF4x1QNWgRQiZCuF', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x62616e636f722d76330000000000000000000000000000000000000000000000","productName":"Bancor v3","requiresWhitelist":false,"efficiency":"5000","tags":["exchange","dex","swap"],"about":"Bancor was the first dApp that utilized AMM model and also pioneered the efforts in \"impermanent loss\" protection","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the version 3 of the Bancor protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://www.bancor.network","app":"https://app.bancor.network/swap","github":"https://github.com/bancorprotocol","docs":"https://docs.bancor.network/","support":"https://support.bancor.network/hc/en-us/","blog":"https://blog.bancor.network/","discord":"https://discord.com/invite/5d3JXqYQGj","telegram":"https://t.me/bancor","twitter":"https://twitter.com/Bancor"},"resolutionSources":[{"text":"Bancor Blog","uri":"https://blog.bancor.network/"},{"text":"Bancor Twitter","uri":"https://twitter.com/Bancor"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPoihzcsB7P1gjFmm8XQKt7ydnNnLgiWhjWnjaMJnHhiQ', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x756e69737761702d76322d616e642d7633000000000000000000000000000000","productName":"Uniswap","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","nft"],"about":"The Uniswap protocol is a peer-to-peer system designed for exchanging cryptocurrencies (ERC-20 Tokens) on the Ethereum blockchain. The protocol is implemented as a set of persistent, non-upgradable smart contracts; designed to prioritize censorship resistance, security, self-custody, and to function without any trusted intermediaries who may selectively restrict access.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":56,"name":"BNB Smart Chain Mainnet"},{"chainId":42161,"name":"Arbitrum One"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Uniswap V2 and V3 deployed on the Ethereum, Arbitrum and BNB blockchains.","To be eligible for a claim, policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum, Arbitrum and BNB Smart Chain."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://uniswap.org/","app":"https://app.uniswap.org/#/swap","twitter":"https://twitter.com/Uniswap","blog":"https://uniswap.org/blog","discord":"https://discord.com/invite/FCfyBSbCU5","github":"https://github.com/Uniswap","docs":"https://docs.uniswap.org/protocol/V2/introduction"},"resolutionSources":[{"text":"Uniswap Blog","uri":"https://uniswap.org/blog"},{"text":"Uniswap Twitter","uri":"https://twitter.com/Uniswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPuZBJ4CDXs71KmQaUtBLWTLHD4kWBH9N79mGgoZXkQNK', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x616176652d76322d616e642d7633000000000000000000000000000000000000","productName":"Aave","requiresWhitelist":false,"efficiency":"9000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Aave is a decentralized non-custodial liquidity protocol where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) or undercollateralized (one-block liquidity) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the AAVE v2 and v3 protocol deployed on the Arbitrum and Ethereum blockchains.","To be eligible for a claim, policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://aave.com/","documentation":"https://docs.aave.com/","twitter":"https://twitter.com/aaveaave","github":"https://github.com/aave","discord":"https://discord.com/invite/CvKUrqM","telegram":"https://t.me/Aavesome","blog":"https://medium.com/aave"},"resolutionSources":[{"text":"Aave Twitter","uri":"https://twitter.com/aaveaave"},{"text":"Aave Blog","uri":"https://medium.com/aave"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmQVtftRbnz7imWHAkc1q8jiZbRMDeB5kkiXXf8swWQf61', '{"coverKey":"0x72616469616e742d763200000000000000000000000000000000000000000000","coverName":"Radiant V2","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-RDNT","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["lending","omnichain","interoperability","leverage","LayerZero","DeFi 3.0"],"about":"Radiant Capital is a non-custodial omni-chain lending & flash loan protocol built on Layer Zero. Users can deposit any major asset on any major chain and borrow various supported assets across multiple chains.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process","list":{"type":"unordered","items":["This policy relates exclusively to  Radiant DAO’s version 2 (RDNT) deployed on Arbitrum with a migration to the LayerZero OFT format and integration with the Stargate stable router interface.","To be eligible for a claim, policyholders must hold at least 499 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from the Arbitrum blockchain."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["Risks associated with the token bridges are excluded.","All exclusions present in the standard terms and exclusions."]}}],"blockchains":[{"chainId":42161,"name":"Arbitrum"},{"chainId":56,"name":"BNB Smart Chain"}],"floor":"300","ceiling":"2000","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"350000000000000000000","stakeWithFee":"15000000000000000000000","initialReassuranceAmount":"15000000000","reassuranceRate":"2500","links":{"website":"https://radiant.capital/","app":"https://app.radiant.capital/","discord":"https://discord.gg/radiantcapital","blog":"https://medium.com/@RadiantCapital","twitter":"https://twitter.com/RDNTCapital","telegram":"https://t.me/radiantcapitalofficial","github":"https://github.com/radiant-capital","youtube":"https://www.youtube.com/c/RadiantCapital/"},"resolutionSources":[{"text":"Radiant Twitter","uri":"https://twitter.com/RDNTCapital"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmQY5QPMmz2kizsV6WDZC5pzMsHF9rVFJyWLS5irTRyF9T', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x636f6e7665782d76310000000000000000000000000000000000000000000000","productName":"Convex v1","requiresWhitelist":false,"efficiency":"9000","tags":["curve","staking","yield"],"about":"Convex Finance is a platform for CRV token holders and Curve liquidity providers to earn additional interest rewards and Curve trading fees on their tokens. Users can deposit either CRV or Curve LP tokens into Convex and be able to receive yields the native tokens are entitled to as well as CVX.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Convex v1 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://www.convexfinance.com","docs":"https://docs.convexfinance.com/","blog":"https://convexfinance.medium.com","twitter":"https://twitter.com/ConvexFinance","discord":"https://discord.com/invite/TTEVTqY488","telegram":"https://t.me/convexEthChat"},"resolutionSources":[{"text":"Convex Twitter","uri":"https://twitter.com/ConvexFinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmRmw7C2sHCLraMjByQec9xN7PXf3kTafdsc7gpTw7BrYa', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","coverName":"Prime dApps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-PRI","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"10","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"floor":"50","ceiling":"800","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"25000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500"}' UNION ALL
SELECT 'QmS5qnWfiHLkGhr78yyTBaa671x5M6TkpFHvVUyUR2mXjC', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x646f646f2d763200000000000000000000000000000000000000000000000000","productName":"DODO v2","requiresWhitelist":false,"efficiency":"7000","tags":["amm","dex","pmm","liquidity"],"about":"DODO is a DeFi  protocol and on-chain liquidity provider that differentiates itself with a proactive market maker (PMM) algorithm, with the aim to offer better liquidity and price stability compared to the AMM (automated market maker) models.  The PMM algorithm mimics human trading, utilizes oracles to gather market prices, then provides liquidity close to these prices in order to stabilize the portfolios for liquidity providers (LP).","blockchains":[{"chainId":56,"name":"BNB Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the DODO v2 protocol deployed on the BNB Smart Chain.","To be eligible for a claim, the policyholder must hold at least 399 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: BNB Smart Chain (BSC) (Previously Binance Smart Chain)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://dodoex.io","app":"https://app.dodoex.io","docs":"https://docs.dodoex.io","github":"https://github.com/DODOEX","telegram":"https://t.me/dodoex_official","twitter":"https://twitter.com/BreederDodo","discord":"https://discord.gg/tyKReUK","community":"https://community.dodoex.io/"},"resolutionSources":[{"text":"DODO Twitter","uri":"https://twitter.com/BreederDodo"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmSFTdPE2EhHECWk17WwjWKRCXdEDGjxLPYKzUwCfK5Rz8', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x70616e63616b65737761702d7632000000000000000000000000000000000000","productName":"PancakeSwap v2","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","nft"],"about":"PancakeSwap is the most popular decentralized exchange protocol for swapping BEP20 tokens on the BNB Smart Chain. The protocol, launched in December 2020, is based on the AMM (automated market maker) model, where users trade against a liquidity pool. These pools are filled by users who deposit their funds and, in return, receive liquidity provider (LP) tokens, enabling them to earn proportional trading fees.","blockchains":[{"chainId":56,"name":"BNB Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the PancakeSwap v2 deployed on the BNB Smart Chain.","To be eligible for a claim, the policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: BNB Smart Chain (BSC) (Previously Binance Smart Chain)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://pancakeswap.finance/","docs":"https://docs.pancakeswap.finance/","twitter":"https://twitter.com/pancakeswap","telegram":"https://t.me/pancakeswap","reddit":"https://reddit.com/r/pancakeswap","instagram":"https://instagram.com/pancakeswap_official","github":"https://github.com/pancakeswap/","discord":"https://discord.gg/pancakeswap","youtube":"https://www.youtube.com/@pancakeswap_official"},"resolutionSources":[{"text":"Pancakeswap Twitter","uri":"https://twitter.com/pancakeswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmSHNAZysPGjv81FEE9RRY1WVhPp7cpGNxv4GpjRb5keT4', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x7375736869737761702d76310000000000000000000000000000000000000000","productName":"Sushiswap","requiresWhitelist":false,"efficiency":"5000","tags":["exchange","dex","swap","nft"],"about":"Sushiswap is  an automated market maker (AMM), in addition to facilitating market making for LPs and traders, Sushiswap also offers token vaults for lending & borrowing.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the version 1 version of the (Swap) protocol deployed on the Ethereum and Arbitrum blockchain.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and Arbitrum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://sushi.com/","twitter":"https://twitter.com/sushiswap","blog":"https://sushichef.medium.com/","github":"https://github.com/sushiswap","documentation":"https://dev.sushi.com/"},"resolutionSources":[{"text":"Sushi Blog","uri":"https://sushichef.medium.com"},{"text":"Sushi Twitter","uri":"https://twitter.com/sushiswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmT6ukCFSBUPrP61Dz1i6Z71u3xRSWtRvQZR6FEfmPhnCA', '{"title":"Fake Dispute to Fake Report","proofOfDispute":["https://thisfakereportisfake.com"],"description":"Ignore this","stake":"2000000000000000000000","createdBy":"0x9BDAE2a084EC18528B78e90b38d1A67c79F6Cab6","permalink":"https://mumbai.neptunemutual.com/reports/0x7072696d65000000000000000000000000000000000000000000000000000000/products/0x676e6f7369732d736166652d7631000000000000000000000000000000000000/incidents/1699597506"}' UNION ALL
SELECT 'QmTGMmPURT6opok7qJUjSGtibVTvpPGcrd9gUdV2ucMpUn', '{"coverKey":"0x61746c6173737761702d76310000000000000000000000000000000000000000","coverName":"AtlasSwap v1","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-AS","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","dex","swap"],"about":"The AtlasSwap protocol is a peer-to-peer system for exchanging cryptocurrencies (ERC-20 Tokens)","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users outside of the US and US territories (not any other apps listed on the platform)","To be eligible for a claim, policyholders must hold at least 100 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"One of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["The designated exchange platform suffers a security breach of its hot or cold wallets where the minimum total loss of funds exceeds $50M","Or the exchange halts all asset withdrawals for all users for more than 15 days except for Legitimate Reasons as defined under the Standard Terms and Conditions. In this case, incident report cannot be submitted until the expiry of the 15-day withdrawal-halt period. No policy could be purchased after withdrawal halt by the exchange and if any such policy purchased after withdrawal halt will be deemed invalid. Any policies that are expired prior to the end of the 15-day withdrawal-halt period will not be eligible for payout"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"50","ceiling":"1600","reportingPeriod":86400,"cooldownPeriod":300,"claimPeriod":86400,"minStakeToReport":"50000000000000000000000","stakeWithFee":"15500000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500","links":{"website":"https://atlasswap.com/"},"resolutionSources":[{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmThidT7SXTdi6a4LkszZfWgAhVPc8x7ub6fbsMuL3S23R', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","coverName":"Prime dApps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-PRI","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"6","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"floor":"50","ceiling":"800","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"10000000000000000000000","stakeWithFee":"30000000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500"}' UNION ALL
SELECT 'QmTwXYSsMjEZFCCcsJx7JS89Rs4gezQvgqEhf7rb7tm3z1', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x31696e63682d7632000000000000000000000000000000000000000000000000","productName":"1inch v2","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","aggregation"],"about":"The 1inch Network unites decentralized protocols whose synergy enables the most lucrative, fastest, and protected operations in the DeFi space by offering access to hundreds of liquidity sources across multiple chains. The 1inch Network was launched at the ETHGlobal New York hackathon in May 2019 with the release of its Aggregation Protocol v1. Since then, 1inch Network has developed additional DeFi tools such as the Liquidity Protocol, Limit Order Protocol, P2P transactions, and 1inch Mobile Wallet.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the 1inch V2 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://1inch.io/","twitter":"https://twitter.com/1inch","blog":"https://blog.1inch.io/","documentation":"https://docs.1inch.io/","reddit":"https://www.reddit.com/r/1inch/","discord":"https://discord.com/invite/1inch","youtube":"https://www.youtube.com/channel/UCk0nvK4bHpteQXZKv7lkq5w","telegram":"https://t.me/OneInchNetwork","github":"https://github.com/1inch"},"resolutionSources":[{"text":"1inch Blog","uri":"https://blog.1inch.io/"},{"text":"1inch Twitter","uri":"https://twitter.com/1inch"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmUsRg5QKE7sAtJwchZdiVKXpaXAv98xpwsNxPbvhUYQJf', '{"coverKey":"0x6f6b780000000000000000000000000000000000000000000000000000000000","coverName":"OKX Exchange Custody","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-OKX","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","okx","okb","okex"],"about":"Founded in 2017, OKX is a rebrand from the former OKEX exchange, it is one of the leading global crypto exchanges, particularly with strong derivatives trading volume. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users outside of the US and US territories (not any other apps listed on the platform)","To be eligible for a claim, policyholders must hold at least 100 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"One of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["The designated exchange platform suffers a security breach of its hot or cold wallets where the minimum total loss of  funds exceeds $50M","Or the exchange halts all asset withdrawals for all users for more than 15 days except for Legitimate Reasons as defined under the Standard Terms and Conditions.  In this case, incident report cannot be submitted until the expiry of the 15-day withdrawal-halt period. No policy could be purchased after withdrawal halt by the exchange and if any such policy purchased after withdrawal halt will be deemed invalid.  Any policies that are expired prior to the end of the 15-day withdrawal-halt period will not be eligible for payout"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"50","ceiling":"700","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"50000000000000000000000","stakeWithFee":"30000000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500","links":{"website":"https://www.okx.com/","telegram":"https://t.me/OKXOfficial_English","twitter":"https://twitter.com/okx","blog":"https://www.okx.com/academy/en/category/Press-en","instagram":"https://www.instagram.com/okx_official/","youtube":"https://www.youtube.com/channel/UCZEp9q993DknUPrhIL51lcw","discord":"https://discord.com/invite/e6EyvM5QwM","linkedin":"https://www.linkedin.com/company/okxofficial/"},"resolutionSources":[{"text":"OKX Twitter","uri":"https://twitter.com/okx"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmVSGRGf2xrCN9U76G8S7BN9bhZbi74wX9gkDnujCixasS', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x6c69646f2d763100000000000000000000000000000000000000000000000000","productName":"Lido v1","requiresWhitelist":false,"efficiency":"9000","tags":["staking","yield"],"about":"Lido is the leading liquid staking solution - providing a simple and secure way to earn interest on your digital assets. By staking with Lido your assets remain liquid and can be used across a range of DeFi applications, earning extra yield.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://lido.fi/","documentation":"https://docs.lido.fi/","telegram":"https://t.me/lidofinance","twitter":"https://twitter.com/lidofinance","discord":"https://discord.com/invite/lido","github":"https://github.com/lidofinance","reddit":"https://www.reddit.com/r/LidoFinance/","blog":"https://blog.lido.fi/"},"resolutionSources":[{"text":"Lido Twitter","uri":"https://twitter.com/lidofinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmVUkJHNaFbHnULoVGscDAiW7P5WhLfRSXuxCxB73537Kf', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x62616c616e6365722d7632000000000000000000000000000000000000000000","productName":"Balancer v2","requiresWhitelist":false,"efficiency":"7500","tags":["exchange","swap","dex","launchpad","flashloan"],"about":"Balancer is an automated market maker (AMM ) that allows LPs to deposit more types of tokens to liquidity pools instead of a pair, also gives more flexibility for LP creator to customize trading fees or create private pools. With the launch of V2 (since May 2021) the single Vault architecture separates the token accounting and management from the Pool logic, hence assets can shift around without emitting an ERC20 transfer event on-chain improving gas efficiency for traders.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Balancer v2 deployed on the Arbitrum and Ethereum blockchains.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions."]}}],"links":{"website":"https://balancer.fi/","twitter":"https://twitter.com/BalancerLabs","discord":"https://discord.balancer.fi/","blog":"https://medium.com/balancer-protocol","linkedin":"https://www.linkedin.com/company/balancer-labs/","youtube":"https://www.youtube.com/channel/UCBRHug6Hu3nmbxwVMt8x_Ow","github":"https://github.com/balancer-labs/"},"resolutionSources":[{"text":"Balancer Blog","uri":"https://medium.com/balancer-protocol"},{"text":"Balancer Twitter","uri":"https://twitter.com/BalancerLabs"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmVVwLMVUvTYTCkLXWrGSYz2eegpcjfcfeD9ebCHkSS84G', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x616176652d76322d6e2d76330000000000000000000000000000000000000000","productName":"Aave V4","requiresWhitelist":false,"efficiency":"9000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Aave is a decentralized non-custodial liquidity protocol where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) or undercollateralized (one-block liquidity) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the AAVE v2 and v3 protocol deployed on the Arbitrum and Ethereum blockchains.","To be eligible for a claim, policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://aave.com/","documentation":"https://docs.aave.com/","twitter":"https://twitter.com/aaveaave","github":"https://github.com/aave","discord":"https://discord.com/invite/CvKUrqM","telegram":"https://t.me/Aavesome","blog":"https://medium.com/aave"},"resolutionSources":[{"text":"Aave Twitter","uri":"https://twitter.com/aaveaave"},{"text":"Aave Blog","uri":"https://medium.com/aave"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmW1bzN7xkWX5jkoZLUskeBGdzmE7VC2v59kpXhTX22fn6', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x676e6f7369732d736166652d7631000000000000000000000000000000000000","productName":"Gnosis Safe v1","requiresWhitelist":false,"efficiency":"9500","tags":["wallet","multi-sig"],"about":"Gnosis Safe is the successor to the Gnosis Multisig. Multi-signature. Multi-signature allows you define an access/control-scheme through multiple signers that need to confirm transactions. DeFi integrations. Easily interact with popular decentralized finance protocols to invest, trade and manage digital assets.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to all of the instances of Gnosis Safe v1 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gnosis-safe.io/","twitter":"https://twitter.com/gnosisSafe","discord":"https://discord.com/invite/AjG7AQD9Qn","github":"https://github.com/safe-global","documentation":"https://docs.gnosis-safe.io/"},"resolutionSources":[{"text":"Gnosis Safe Twitter","uri":"https://twitter.com/gnosisSafe"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmWBQG45NLNiWoQYFA2RYs6fF8PQiQG8E9Xd5kgHY8jReg', '{"coverKey":"0x6f6b780000000000000000000000000000000000000000000000000000000000","coverName":"OKX","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-OKX","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","okx","okex"],"about":"Founded in 2017, OKX is a rebrand from the former OKEX exchange, it is one of the leading global crypto exchanges,  particularly with strong derivatives trading volume. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users (outside of US and US territories).","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $50 million.","OKX suffers a security breach of its hot or cold wallets where the user funds are permanently and irrecoverably stolen from OKX.","The loss must arise from security incidents of the crypto storage systems"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Losses arisen due to issues with fork, merge,  any other changes of relevant underlying blockchains","Losses resulting from Key man risk where a single person controls access to the user funds at the custodian, is not covered.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"400","ceiling":"1600","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"27000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500","links":{"website":"https://www.okx.com/","telegram":"https://t.me/OKXOfficial_English","twitter":"https://twitter.com/okx","blog":"https://www.okx.com/academy/en/category/Press-en","instagram":"https://www.instagram.com/okx_official/","youtube":"https://www.youtube.com/channel/UCZEp9q993DknUPrhIL51lcw","discord":"https://discord.com/invite/e6EyvM5QwM","linkedin":"https://www.linkedin.com/company/okxofficial/"},"resolutionSources":[{"text":"OKX Twitter","uri":"https://twitter.com/okx"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmWC9UhJVSX3C5xCVNJSMqev3cSTB4pyeqMS3BLkVsRZQn', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x6f6e65696e63682d763200000000000000000000000000000000000000000000","productName":"1inch v2","requiresWhitelist":false,"efficiency":"4000","tags":["exchange","dex","swap","aggregation"],"about":"The 1inch Network unites decentralized protocols whose synergy enables the most lucrative, fastest, and protected operations in the DeFi space by offering access to hundreds of liquidity sources across multiple chains. The 1inch Network was launched at the ETHGlobal New York hackathon in May 2019 with the release of its Aggregation Protocol v1. Since then, 1inch Network has developed additional DeFi tools such as the Liquidity Protocol, Limit Order Protocol, P2P transactions, and 1inch Mobile Wallet.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the 1inch v2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://1inch.io/","twitter":"https://twitter.com/1inch","blog":"https://blog.1inch.io/","documentation":"https://docs.1inch.io/","reddit":"https://www.reddit.com/r/1inch/","discord":"https://discord.com/invite/1inch","youtube":"https://www.youtube.com/channel/UCk0nvK4bHpteQXZKv7lkq5w","telegram":"https://t.me/OneInchNetwork","github":"https://github.com/1inch"},"resolutionSources":[{"text":"1inch Blog","uri":"https://blog.1inch.io/"},{"text":"1inch Twitter","uri":"https://twitter.com/1inch"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmWcy6Vhi85gDXBEDzSSQMhV8md1T6e9tEZnxemgdBf26B', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x616176652d763300000000000000000000000000000000000000000000000000","productName":"Aave v3","requiresWhitelist":false,"efficiency":"9000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Aave is a decentralized non-custodial liquidity protocol where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) or undercollateralized (one-block liquidity) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the AAVE v3 protocol deployed on the Arbitrum and Ethereum blockchain (if available).","To be eligible for a claim, policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum (if available)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://aave.com/","documentation":"https://docs.aave.com/","twitter":"https://twitter.com/aaveaave","github":"https://github.com/aave","discord":"https://discord.com/invite/CvKUrqM","telegram":"https://t.me/Aavesome","blog":"https://medium.com/aave"},"resolutionSources":[{"text":"Aave Twitter","uri":"https://twitter.com/aaveaave"},{"text":"Aave Blog","uri":"https://medium.com/aave"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmWJjgxNEJ1Ue3mHqGeiaHn91EDJW4JBaKsvFhdCHHsWBK', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x636f6d706f756e642d7632000000000000000000000000000000000000000000","productName":"Compound v2","requiresWhitelist":false,"efficiency":"9000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Compound  is a decentralized non-custodial liquidity protocol on Ethereum where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Compound V2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://compound.finance/","discord":"https://discord.com/invite/fq6JSPkpJn","github":"https://github.com/compound-finance/compound-protocol","blog":"https://medium.com/compound-finance","twitter":"https://twitter.com/compoundfinance","app":"https://app.compound.finance/"},"resolutionSources":[{"text":"Compound Twitter","uri":"https://twitter.com/compoundfinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmWRdPnZKhxhPfd5rqK4FwvbQ7uCd1q6JWuk9v4h9WTrFX', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x62616c616e6365722d7632000000000000000000000000000000000000000000","productName":"Balancer v2","requiresWhitelist":false,"efficiency":"7500","tags":["exchange","swap","dex","launchpad","flashloan"],"about":"Balancer is an automated market maker (AMM ) that allows LPs to deposit more types of tokens to liquidity pools instead of a pair, also gives more flexibility for LP creator to customize trading fees or create private pools. With the launch of V2 (since May 2021) the single Vault architecture separates the token accounting and management from the Pool logic, hence assets can shift around without emitting an ERC20 transfer event on-chain improving gas efficiency for traders.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Balancer v2 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions."]}}],"links":{"website":"https://balancer.fi/","twitter":"https://twitter.com/BalancerLabs","discord":"https://discord.balancer.fi/","blog":"https://medium.com/balancer-protocol","linkedin":"https://www.linkedin.com/company/balancer-labs/","youtube":"https://www.youtube.com/channel/UCBRHug6Hu3nmbxwVMt8x_Ow","github":"https://github.com/balancer-labs/"},"resolutionSources":[{"text":"Balancer Blog","uri":"https://medium.com/balancer-protocol"},{"text":"Balancer Twitter","uri":"https://twitter.com/BalancerLabs"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmX5ssdLHSpsQwu3YVGbS1CTUZG2XVgTXxyKVC2Fcyf8Rr', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x676d782d76320000000000000000000000000000000000000000000000000000","productName":"GMX v2","requiresWhitelist":false,"efficiency":"6000","tags":["perpetual","trade","dex","leverage","swap"],"about":"GMX is a permissionless, decentralized spot and perpetual swap exchange on the Arbitrum network.","blockchains":[{"chainId":42161,"name":"Arbitrum One"},{"chainId":43114,"name":"Avalanche C-Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the GMX version 1 deployed on the Arbitrum and Avalanche blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Avalanche."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gmx.io","app":"https://app.gmx.io","twitter":"https://twitter.com/GMX_IO","medium":"https://medium.com/@gmx.io","github":"https://github.com/gmx-io","telegram":"https://t.me/GMX_IO","discord":"https://discord.com/invite/ymN38YefH9"},"resolutionSources":[{"text":"GMX Blog","uri":"https://medium.com/@gmx.io"},{"text":"GMX Twitter","uri":"https://twitter.com/GMX_IO"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmXFX5NCii3nwPtVw5Ax7q73JeTS5oZnpqGPCnz33TGC2Y', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x6d616b65722d7631000000000000000000000000000000000000000000000000","productName":"Maker DAO MCD v1","requiresWhitelist":false,"efficiency":"9000","tags":["lending","borrowing","stablecoin","yield","staking","payment"],"about":"MakerDAO is a decentralized organization dedicated to bringing stability to the cryptocurrency economy. The Maker Protocol employs a two-token system. The first being, Dai, a collateral-backed stablecoin that offers stability. The Maker Foundation and the MakerDAO community believe that a decentralized stablecoin is required to have any business or individual realize the advantages of digital money. Second, there is MKR, a governance token that is used by stakeholders to maintain the system and manage Dai. MKR token holders are the decision-makers of the Maker Protocol, supported by the larger public community and various other external parties.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to Version 1 of the Maker DAO (Multi-Collateral DAI) smart contracts deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://makerdao.com/","twitter":"https://twitter.com/MakerDAO","blog":"https://medium.com/@MakerDAO","documentation":"https://docs.makerdao.com/","reddit":"https://www.reddit.com/r/MakerDAO/","telegram":"https://t.me/makerdaoOfficial","discord":"https://discord.com/invite/RBRumCpEDH","youtube":"https://www.youtube.com/MakerDAO"},"resolutionSources":[{"text":"MakerDAO Blog","uri":"https://medium.com/@MakerDAO"},{"text":"MakerDAO Twitter","uri":"https://twitter.com/MakerDAO"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmXfy1Az9Y2FKXKDVkHgc3ThfLLQUatP5qQGbeqgQrfZ6B', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x647964782d763300000000000000000000000000000000000000000000000000","productName":"DYDX v3","requiresWhitelist":false,"efficiency":"3000","tags":["exchange","dex","swap","derivatives","leverage"],"about":"dYdX is a crypto derivatives exchange that leverages a hybrid model utilizing non-custodial, on-chain settlement and an off-chain order books matching engine.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the dYdX V3 protocol deployed on the StarkEx layer 2 blockchain running on top of Ethereum.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: StarkEx layer 2 blockchain running on top of Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://dydx.exchange","app":"https://trade.dydx.exchange/","testnet":"https://trade.stage.dydx.exchange/","docs":"https://docs.dydx.exchange/","github":"https://github.com/dydxprotocol/","blog":"https://dydx.exchange/blog","support":"https://help.dydx.exchange/en/","twitter":"https://twitter.com/dydx","discord":"https://discord.gg/Tuze6tY","youtube":"https://www.youtube.com/c/dYdXprotocol","reddit":"https://www.reddit.com/r/dydxprotocol","linkedin":"https://linkedin.com/company/dydx"},"resolutionSources":[{"text":"DYDX Blog","uri":"https://dydx.exchange/blog"},{"text":"DYDX Twitter","uri":"https://twitter.com/dydx"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmXPkuacaiXrh9aUdiMybBmTjJbZjSEgqq7CnetQuTywVG', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x73757368692d7632000000000000000000000000000000000000000000000000","productName":"Sushi v2","requiresWhitelist":false,"efficiency":"7000","tags":["exchange","dex","swap","fork","flashloan"],"about":"Sushi is a community-driven organization built to solve what might be called the “liquidity problem.” One could define this problem as the inability of disparate forms of liquidity to connect with markets in a decentralized way, and vice versa. While other solutions provide incrementally progressive advances toward solving the problem of liquidity, Sushi’s progress is intended to create a broader range of network effects. Rather than limiting itself to a single solution, Sushi intertwines many decentralized markets and instruments.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the SushiSwap v2 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://sushi.com/","twitter":"https://twitter.com/sushiswap","blog":"https://sushichef.medium.com/","github":"https://github.com/sushiswap","documentation":"https://dev.sushi.com/"},"resolutionSources":[{"text":"Sushi Blog","uri":"https://sushichef.medium.com"},{"text":"Sushi Twitter","uri":"https://twitter.com/sushiswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmYHbEJEQek15WwiC283ihf1RCpcfTQeqGXHkTstWA7o3y', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x616c706163612d76310000000000000000000000000000000000000000000000","productName":"Alpaca Finance v1","requiresWhitelist":false,"efficiency":"7000","tags":["lending","farming","loan","leverage","yield"],"about":"Alpaca Finance is a lending protocol allowing leveraged yield farming on BNB Smart Chain. It offers borrowers undercollateralized loans for leveraged yield farming positions. As a result, it amplifies the liquidity layer of integrated exchanges, improving their capital efficiency by connecting LP borrowers and lenders.","blockchains":[{"chainId":56,"name":"BNB Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Alpaca Finance v1 protocol deployed on the BNB Smart Chain.","To be eligible for a claim, the policyholder must hold at least 499 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: BNB Smart Chain (BSC) (Previously Binance Smart Chain)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://www.alpacafinance.org/","docs":"https://docs.alpacafinance.org/","app":"https://app.alpacafinance.org/","twitter":"https://twitter.com/AlpacaFinance","telegram":"https://t.me/alpacafinance","discord":"https://discord.com/invite/alpacafinance","blog":"https://medium.com/alpaca-finance","youtube":"https://www.youtube.com/channel/UC8xBPBPgRD-xe_ZfyOwV_Dg","reddit":"https://www.reddit.com/r/AlpacaFinanceOfficial/","github":"https://github.com/alpaca-finance/bsc-alpaca-contract"},"resolutionSources":[{"text":"Alpaca Finance Twitter","uri":"https://twitter.com/AlpacaFinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmYvtFvKNFM8ZhfiHGyPnWYq5rsqjcRgjJixFK2w1RytNt', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x73796e7468657469782d76320000000000000000000000000000000000000000","productName":"Synthetix v2","requiresWhitelist":false,"efficiency":"8000","tags":["derivative","staking","yield"],"about":"Synthetix is a new financial primitive enabling the creation of synthetic assets, offering unique derivatives and exposure to real-world assets on the blockchain.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Synthetix Protocol (v2) deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://synthetix.io/","discord":"https://discord.com/invite/AEdUHzt","twitter":"https://twitter.com/synthetix_io","github":"https://github.com/synthetixio","blog":"https://blog.synthetix.io/","dao":"https://synthetix.io/governance","documentation":"https://docs.synthetix.io/"},"resolutionSources":[{"text":"Synthetix Twitter","uri":"https://twitter.com/synthetix_io"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmYyjCcdjmRAB21EjAVPBWe2GAuNWGeMa9M7L23DzQ3f3y', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x6f6e65696e63682d763300000000000000000000000000000000000000000000","productName":"1inch v3","requiresWhitelist":false,"efficiency":"4000","tags":["exchange","dex","swap","aggregation"],"about":"The 1inch Network unites decentralized protocols whose synergy enables the most lucrative, fastest, and protected operations in the DeFi space by offering access to hundreds of liquidity sources across multiple chains. The 1inch Network was launched at the ETHGlobal New York hackathon in May 2019 with the release of its Aggregation Protocol v1. Since then, 1inch Network has developed additional DeFi tools such as the Liquidity Protocol, Limit Order Protocol, P2P transactions, and 1inch Mobile Wallet.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":56,"name":"BNB Smart Chain Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the 1inch v3 protocol deployed on the Ethereum and BNB blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and BNB."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://1inch.io/","twitter":"https://twitter.com/1inch","blog":"https://blog.1inch.io/","documentation":"https://docs.1inch.io/","reddit":"https://www.reddit.com/r/1inch/","discord":"https://discord.com/invite/1inch","youtube":"https://www.youtube.com/channel/UCk0nvK4bHpteQXZKv7lkq5w","telegram":"https://t.me/OneInchNetwork","github":"https://github.com/1inch"},"resolutionSources":[{"text":"1inch Blog","uri":"https://blog.1inch.io/"},{"text":"1inch Twitter","uri":"https://twitter.com/1inch"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmYzbk1mWWodnUtCZ8uUwMuLosDXuoMjKpKBECf9D8UF4t', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x6b79626572737761702d76310000000000000000000000000000000000000000","productName":"Kyberswap v1","requiresWhitelist":false,"efficiency":"5000","tags":["exchange","dex","swap"],"about":"Kyber Network is a multi-chain crypto trading and liquidity hub that connects liquidity from different sources to enable trades at the best rates .","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Kyberswap v1 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://kyber.network/","documentation":"https://docs.kyberswap.com/introduction","github":"https://github.com/KyberNetwork","dao":"https://kyber.org/vote","forum":"https://gov.kyber.org/","discord":"https://discord.com/invite/NB3vc8J9uv","telegram":"https://t.me/kybernetwork","twitter":"https://twitter.com/kybernetwork/","youtube":"https://www.youtube.com/channel/UCQ-8mEqsKM3x9dTT6rrqgJw","blog":"https://blog.kyber.network/"},"resolutionSources":[{"text":"Kyber Twitter","uri":"https://twitter.com/kybernetwork"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmZ9cjxk8ye3qui8JEgPjxDaFF48CbxNswtCfBMTLKnaj6', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x636f6d706f756e642d7632000000000000000000000000000000000000000000","productName":"Compound Finance","requiresWhitelist":false,"efficiency":"7000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Compound  is a decentralized non-custodial liquidity protocol on Ethereum where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Compound V2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 99 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://compound.finance/","discord":"https://discord.com/invite/fq6JSPkpJn","github":"https://github.com/compound-finance/compound-protocol","blog":"https://medium.com/compound-finance","twitter":"https://twitter.com/compoundfinance","app":"https://app.compound.finance/"},"resolutionSources":[{"text":"Compound Twitter","uri":"https://twitter.com/compoundfinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmZXDq4Cn9ZnEGhm68UN7HLpuxduesH5cx6QrhWuRccJLY', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x756e69737761702d763300000000000000000000000000000000000000000000","productName":"Uniswap v3","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","nft"],"about":"The Uniswap protocol is a peer-to-peer system designed for exchanging cryptocurrencies (ERC-20 Tokens) on the Ethereum blockchain. The protocol is implemented as a set of persistent, non-upgradable smart contracts; designed to prioritize censorship resistance, security, self-custody, and to function without any trusted intermediaries who may selectively restrict access.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Uniswap V3 deployed on the Ethereum and Arbitrum blockchain.","To be eligible for a claim, policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and Arbitrum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://uniswap.org/","app":"https://app.uniswap.org/#/swap?use=V2","twitter":"https://twitter.com/Uniswap","blog":"https://uniswap.org/blog","discord":"https://discord.com/invite/FCfyBSbCU5","github":"https://github.com/Uniswap","docs":"https://docs.uniswap.org/protocol/V2/introduction"},"resolutionSources":[{"text":"Uniswap Blog","uri":"https://uniswap.org/blog"},{"text":"Uniswap Twitter","uri":"https://twitter.com/Uniswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}';

DROP FUNCTION IF EXISTS hex_to_int(_hex text) CASCADE;

CREATE FUNCTION hex_to_int(_hex text)
RETURNS integer
IMMUTABLE
AS
$$
BEGIN
  RETURN ('x' || lpad(_hex, 8, '0'))::bit(32)::integer;
END
$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION string_to_bytes32(_string text)
RETURNS text
IMMUTABLE
AS
$$
  DECLARE _bytes32 text = '0x';
BEGIN

  FOR i IN 0..character_length(_string)
  LOOP
    _bytes32 := _bytes32 || to_hex(ascii(substring(_string FROM i + 1 FOR 1)));
  END LOOP;

  RETURN rpad(_bytes32, 66, '0');
END
$$
LANGUAGE plpgsql;

--SELECT * FROM bytes32_to_string(string_to_bytes32('prime'));

DROP FUNCTION IF EXISTS bytes32_to_string(_bytes32 text) CASCADE;

CREATE OR REPLACE FUNCTION bytes32_to_string(_bytes32 text)
RETURNS text
IMMUTABLE
AS
$$
  DECLARE _string text = '';
  DECLARE _fragment text;
  DECLARE _code integer;
  DECLARE _length integer;
BEGIN
  IF(_bytes32 IS NULL) THEN
    RETURN '';
  END IF;

  IF(starts_with(_bytes32, '0x')) THEN
    _bytes32 = substring(_bytes32, 3);
  END IF;
  
  _length := character_length(_bytes32);
  
  FOR i IN 0.._length BY 2
  LOOP
    _code := hex_to_int(substring(_bytes32 FROM i + 1 FOR 2));
    
    IF(_code = 0) THEN
      CONTINUE;
    END IF;

    _fragment := chr(_code);
    _string := _string || _fragment;
  END LOOP;

  RETURN _string;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM bytes32_to_string('0x7072696d65000000000000000000000000000000000000000000000000000000');



DROP FUNCTION IF EXISTS count_products
(
  _chain_id                           numeric,
  _cover_key                          bytes32
) CASCADE;

CREATE FUNCTION count_products
(
  _chain_id                           numeric,
  _cover_key                          bytes32
)
RETURNS integer
STABLE
AS
$$
BEGIN
  RETURN COUNT(product_key)
  FROM config_product_view
  WHERE chain_id = _chain_id
  AND cover_key = _cover_key;
END
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS cxtoken_to_stablecoin_units
(
  _chain_id                                         uint256,
  _amount_in_cxtoken                                uint256
) CASCADE;

CREATE FUNCTION cxtoken_to_stablecoin_units
(
  _chain_id                                         uint256,
  _amount_in_cxtoken                                uint256
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _precision                                integer;
BEGIN
  SELECT config_blockchain_network_view.stablecoin_decimals
  INTO _precision
  FROM config_blockchain_network_view
  WHERE config_blockchain_network_view.chain_id = _chain_id;
  
  RETURN (_amount_in_cxtoken / POWER(10, 18)) * POWER(10, _precision);
END
$$
LANGUAGE plpgsql;


/********************************************/

DROP FUNCTION IF EXISTS cxtoken.claimed_amounts_trigger() CASCADE;

CREATE FUNCTION cxtoken.claimed_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = cxtoken_to_stablecoin_units(NEW.chain_id, NEW.amount);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER claimed_amounts_trigger
BEFORE INSERT OR UPDATE ON cxtoken.claimed
FOR EACH ROW EXECUTE FUNCTION cxtoken.claimed_amounts_trigger();

DROP FUNCTION IF EXISTS get_capital_efficiency
(
  _chain_id                               numeric,
  _cover_key                              bytes32
) CASCADE;

CREATE FUNCTION get_capital_efficiency
(
  _chain_id                               numeric,
  _cover_key                              bytes32
)
RETURNS TABLE
(
  leverage_factor                         numeric,
  average_capital_efficiency              numeric
)
STABLE AS
$$
  DECLARE _leverage_factor                numeric;
  DECLARE _average_capital_efficiency     numeric;
BEGIN
  SELECT leverage INTO _leverage_factor
  FROM config_cover_view
  WHERE chain_id = _chain_id
  AND cover_key = _cover_key;
  
  SELECT AVG(capital_efficiency)
  INTO _average_capital_efficiency
  FROM config_product_view
  WHERE chain_id = _chain_id
  AND cover_key = _cover_key;

  RETURN QUERY
  SELECT _leverage_factor, _average_capital_efficiency;
END
$$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS get_capital_efficiency
(
  _chain_id                               numeric,
  _cover_key                              bytes32,
  _product_key                            bytes32
);

CREATE FUNCTION get_capital_efficiency
(
  _chain_id                               numeric,
  _cover_key                              bytes32,
  _product_key                            bytes32
)
RETURNS TABLE
(
  leverage_factor                         numeric,
  capital_efficiency                      numeric
)
STABLE
AS
$$
  DECLARE _leverage_factor                numeric;
  DECLARE _capital_efficiency             numeric;
BEGIN
  SELECT config_cover_view.leverage INTO _leverage_factor
  FROM config_cover_view
  WHERE chain_id = _chain_id
  AND cover_key = _cover_key;
  
  SELECT config_product_view.capital_efficiency INTO _capital_efficiency
  FROM config_product_view
  WHERE chain_id = _chain_id
  AND cover_key = _cover_key
  AND product_key = _product_key;

  RETURN QUERY
  SELECT COALESCE(_leverage_factor, 0), COALESCE(_capital_efficiency, 0);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_commitment
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _commitment                        uint256;
  DECLARE _paid                               uint256;
  DECLARE _incident_date                      uint256;
  DECLARE _starts_from                        uint256 = EXTRACT(epoch FROM NOW() AT TIME ZONE 'UTC');
BEGIN
  _incident_date := get_active_incident_date(_chain_id, _cover_key, _product_key);
  
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;

  IF(_incident_date > 0) THEN
    _starts_from := _incident_date;
  END IF;

  SELECT SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS commitment
  INTO _commitment
  FROM policy.cover_purchased  
  WHERE expires_on > _starts_from
  AND policy.cover_purchased.chain_id = _chain_id
  AND policy.cover_purchased.cover_key = _cover_key
  AND policy.cover_purchased.product_key = _product_key;

  SELECT SUM(wei_to_ether(cxtoken.claimed.amount))
  INTO _paid
  FROM cxtoken.claimed
  WHERE cxtoken.claimed.chain_id = _chain_id
  AND cxtoken.claimed.cover_key = _cover_key
  AND cxtoken.claimed.product_key = _product_key
  AND cxtoken.claimed.cx_token IN
  (
    SELECT factory.cx_token_deployed.cx_token
    FROM factory.cx_token_deployed
    WHERE expiry_date > EXTRACT(epoch FROM NOW() AT TIME ZONE 'UTC')
    AND factory.cx_token_deployed.chain_id = _chain_id
    AND factory.cx_token_deployed.cover_key = _cover_key
    AND factory.cx_token_deployed.product_key = _product_key
  );

  RETURN COALESCE(_commitment, 0) - COALESCE(_paid, 0);
END
$$
LANGUAGE plpgsql;


--SELECT * FROM get_commitment(84531,'0x6465666900000000000000000000000000000000000000000000000000000000', '0x73757368692d7632000000000000000000000000000000000000000000000000');

DROP FUNCTION IF EXISTS get_sum_commitment
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32
) CASCADE;

CREATE FUNCTION get_sum_commitment
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32
)
RETURNS uint256
STABLE
AS
$$
BEGIN
  RETURN
    SUM(get_commitment(_chain_id, _cover_key, config_product_view.product_key))
  FROM config_product_view
  WHERE config_product_view.chain_id = _chain_id
  AND config_product_view.cover_key = _cover_key;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_sum_commitment(84531,'0x6465666900000000000000000000000000000000000000000000000000000000');




CREATE OR REPLACE FUNCTION get_gauge_pool_last_added_block_number(_chain_id numeric, _key bytes32)
RETURNS numeric
STABLE
AS
$$
  DECLARE _last_deleted_block_number                    numeric;
  DECLARE _min_block_number                             numeric;
BEGIN
  SELECT MAX(ve.gauge_controller_registry_pool_deleted.block_number::numeric)
  INTO _last_deleted_block_number
  FROM ve.gauge_controller_registry_pool_deleted
  WHERE ve.gauge_controller_registry_pool_deleted.chain_id = _chain_id
  AND ve.gauge_controller_registry_pool_deleted.key = _key;

  RETURN MIN(ve.liquidity_gauge_pool_set.block_number::numeric)
  FROM ve.liquidity_gauge_pool_set
  WHERE ve.liquidity_gauge_pool_set.chain_id = _chain_id
  AND ve.liquidity_gauge_pool_set.key = _key
  AND ve.liquidity_gauge_pool_set.block_number::numeric > COALESCE(_last_deleted_block_number, 0);
END
$$
LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION get_npm(_chain_id numeric)
RETURNS text
STABLE
AS
$$
BEGIN
  RETURN npm_address
  FROM config_blockchain_network_view
  WHERE config_blockchain_network_view.chain_id = _chain_id;
END
$$
LANGUAGE plpgsql;
DROP FUNCTION IF EXISTS quote_literal_ilike CASCADE;

CREATE FUNCTION quote_literal_ilike(_ilike text)
RETURNS text
IMMUTABLE
AS
$$
BEGIN
  RETURN quote_literal(CONCAT('%', TRIM(_ilike), '%'));
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ABS(interval)
RETURNS interval
IMMUTABLE
AS
$$
  SELECT CASE WHEN ($1 < interval '0')
  THEN -$1 ELSE $1 END;
$$
LANGUAGE sql;


CREATE OR REPLACE FUNCTION to_relative_time
(
  _from                           TIMESTAMP WITH TIME ZONE,
  _to                             TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS text 
AS 
$$
  DECLARE duration                interval = ABS(_to - _from);
  DECLARE future                  boolean = _from > _to;
  DECLARE result                  text;
BEGIN
  IF duration < INTERVAL '1 minute' THEN
    RETURN 'recently';
  ELSIF duration < INTERVAL '1 hour' THEN
    result := extract(minute from duration)::integer || ' minutes';
  ELSIF duration < INTERVAL '1 day' THEN
    result := extract(hour from duration)::integer || ' hours';
  ELSIF duration < INTERVAL '7 days' THEN
    result := extract(day from duration)::integer || ' days';
  ELSIF duration < INTERVAL '1 month' THEN
    result := (extract(day from duration) / 7)::integer || ' weeks';
  ELSIF duration < INTERVAL '1 year' THEN
    result := (extract(day from duration) / 30)::numeric(8, 1) || ' months';
  ELSE
    result := (extract(day from duration) / 365)::numeric(8, 1) || ' years';
  END IF;


  IF(future) THEN
    RETURN CONCAT('in ', result);
  END IF;

  RETURN CONCAT(result, ' ago');
END;
$$
LANGUAGE plpgsql;




DROP VIEW IF EXISTS config_blockchain_network_view CASCADE;

CREATE VIEW config_blockchain_network_view
AS
SELECT
  1                                             AS chain_id,
  'Main Ethereum Network'                       AS network_name,
  'Mainnet'                                     AS nick_name,
  'ETH'                                         AS currency,
  'USDC'                                        AS stablecion,
  6                                             AS stablecoin_decimals,
  '0xb452ac021a1151aaf342c1b75aa914e03e6503b5'  AS protocol_address,
  '0x6579df8f986e4a982f200dafa0c1b955a438f620'  AS store_address,
  '0x57f12fe6a4e5fe819eec699fadf9db2d06606bb4'  AS npm_address,
  'https://etherscan.io/'                       AS explorer UNION ALL
SELECT 42161                                    AS chain_id,
  'Arbitrum One'                                AS network_name,
  'Arbitrum'                                    AS nick_name,
  'ETH'                                         AS currency,
  'USDC'                                        AS stablecion,
  6                                             AS stablecoin_decimals,
  '0xb452ac021a1151aaf342c1b75aa914e03e6503b5'  AS protocol_address,
  '0x6579df8f986e4a982f200dafa0c1b955a438f620'  AS store_address,
  '0x57f12fe6a4e5fe819eec699fadf9db2d06606bb4'  AS npm_address,
  'https://arbiscan.io/'                        AS explorer UNION ALL
SELECT 56                                       AS chain_id,
  'BNB Smart Chain'                             AS network_name,
  'BSC'                                         AS nick_name,
  'BNB'                                         AS currency,
  'USDC'                                        AS stablecion,
  18                                            AS stablecoin_decimals,
  '0xb452ac021a1151aaf342c1b75aa914e03e6503b5'  AS protocol_address,
  '0x6579df8f986e4a982f200dafa0c1b955a438f620'  AS store_address,
  '0x57f12fe6a4e5fe819eec699fadf9db2d06606bb4'  AS npm_address,
  'https://bscscan.com/'                        AS explorer UNION ALL
SELECT 80001                                    AS chain_id,
  'Polygon Mumbai'                              AS network_name,
  'Mumbai'                                      AS nick_name,
  'MATIC'                                       AS currency,
  'USDC'                                        AS stablecion,
  6                                             AS stablecoin_decimals,
  '0xf3393dD20B442DF5c4685fecd829656d9A49f9b6'  AS protocol_address,
  '0xA483aF3eD0DF092EC4b9b93DA400f84922c92Be9'  AS store_address,
  '0x88180bDc1Fa041d5Fce608B732D48373b2a12D62'  AS npm_address,
  'https://mumbai.polygonscan.com/'             AS explorer UNION ALL
SELECT 84531                                    AS chain_id,
  'Base Goerli'                                 AS network_name,
  'Base Goerli'                                 AS nick_name,
  'ETH'                                         AS currency,
  'USDC'                                        AS stablecion,
  6                                             AS stablecoin_decimals,
  '0x3b60152bfea33b894e06291aa2bb3404b8dfdc2b'  AS protocol_address,
  '0x52b124a19023edf0386a3d9e674fdd7e02b8a8a8'  AS store_address,
  '0x4bbdc138dd105c7dde874df7fcd087b064f7973d'  AS npm_address,
  'https://goerli.basescan.org/'                AS explorer;

DROP VIEW IF EXISTS config_contract_namespace_view CASCADE;

CREATE VIEW config_contract_namespace_view
AS
SELECT 'cns:cover:vault:factory' AS namespace,      'VaultFactory' AS contract_name UNION ALL
SELECT 'cns:cover:cxtoken:factory' AS namespace,    'cxTokenFactory' AS contract_name UNION ALL
SELECT 'cns:cover:reassurance' AS namespace,        'CoverReassurance' AS contract_name UNION ALL
SELECT 'cns:claim:processor' AS namespace,          'Processor' AS contract_name UNION ALL
SELECT 'cns:cover:policy:admin' AS namespace,       'PolicyAdmin' AS contract_name UNION ALL
SELECT 'cns:cover:policy' AS namespace,             'Policy' AS contract_name UNION ALL
SELECT 'cns:gov:resolution' AS namespace,           'Resolution' AS contract_name UNION ALL
SELECT 'cns:cover:stake' AS namespace,              'CoverStake' AS contract_name UNION ALL
SELECT 'cns:pools:staking' AS namespace,            'StakingPools' AS contract_name UNION ALL
SELECT 'cns:pools:bond' AS namespace,               'BondPool' AS contract_name UNION ALL
SELECT 'cns:cover' AS namespace,                    'Cover' AS contract_name UNION ALL
SELECT 'cns:gov' AS namespace,                      'Governance' AS contract_name UNION ALL
SELECT 'cns:cover:vault:delegate' AS namespace,     'VaultDelegate' AS contract_name UNION ALL
SELECT 'cns:liquidity:engine' AS namespace,         'LiquidityEngine' AS contract_name UNION ALL
SELECT 'cns:cover:vault' AS namespace,              'Vault' AS contract_name;


DROP VIEW IF EXISTS config_cover_view CASCADE;

CREATE VIEW config_cover_view
AS
SELECT
  1                              AS chain_id,
  string_to_bytes32('binance')   AS cover_key,
  1                              AS leverage,
  50                             AS policy_floor,
  700                            AS policy_ceiling,
  604800                         AS reporting_period,
  86400                          AS coverage_lag,
  50000000000000000000000        AS minimum_first_reporting_stake
UNION ALL
SELECT
  1                              AS chain_id,
  string_to_bytes32('okx')       AS cover_key,
  1                              AS leverage,
  50                             AS policy_floor,
  700                            AS policy_ceiling,
  604800                         AS reporting_period,
  86400                          AS coverage_lag,
  50000000000000000000000        AS minimum_first_reporting_stake
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  6                                        AS leverage,
  200                                      AS policy_floor,
  1200                                     AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  10000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  6                                        AS leverage,
  50                                       AS policy_floor,
  400                                      AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  10000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  56                                       AS chain_id,
  string_to_bytes32('binance')             AS cover_key,
  1                                        AS leverage,
  50                                       AS policy_floor,
  1600                                     AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  50000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  56                                       AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  6                                        AS leverage,
  200                                      AS policy_floor,
  1200                                     AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  10000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('binance')             AS cover_key,
  1                                        AS leverage,
  50                                       AS policy_floor,
  1600                                     AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  50000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('okx')                 AS cover_key,
  1                                        AS leverage,
  50                                       AS policy_floor,
  700                                      AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  50000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  6                                        AS leverage,
  200                                      AS policy_floor,
  1200                                     AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  10000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  6                                        AS leverage,
  50                                       AS policy_floor,
  800                                      AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  10000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('binance')             AS cover_key,
  1                                        AS leverage,
  400                                      AS policy_floor,
  1600                                     AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('coinbase')            AS cover_key,
  1                                        AS leverage,
  400                                      AS policy_floor,
  1600                                     AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('defi')                AS cover_key,
  10                                       AS leverage,
  200                                      AS policy_floor,
  1200                                     AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('huobi')               AS cover_key,
  1                                        AS leverage,
  400                                      AS policy_floor,
  1600                                     AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('okx')                 AS cover_key,
  1                                        AS leverage,
  400                                      AS policy_floor,
  1600                                     AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  10                                       AS leverage,
  50                                       AS policy_floor,
  800                                      AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake;

DROP VIEW IF EXISTS config_known_ipfs_hashes_view CASCADE;

CREATE VIEW config_known_ipfs_hashes_view
AS
SELECT 'QmaADrtP13cZKwz5pdipXhU5F8WWXenBTZrUFp2MK4yVf2' AS ipfs_hash, '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x6f6e65696e63682d763300000000000000000000000000000000000000000000","productName":"1inch v3","requiresWhitelist":false,"efficiency":"4000","tags":["exchange","dex","swap","aggregation"],"about":"The 1inch Network unites decentralized protocols whose synergy enables the most lucrative, fastest, and protected operations in the DeFi space by offering access to hundreds of liquidity sources across multiple chains. The 1inch Network was launched at the ETHGlobal New York hackathon in May 2019 with the release of its Aggregation Protocol v1. Since then, 1inch Network has developed additional DeFi tools such as the Liquidity Protocol, Limit Order Protocol, P2P transactions, and 1inch Mobile Wallet.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":56,"name":"BNB Smart Chain Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the 1inch v3 protocol deployed on the Ethereum and BNB blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and BNB."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://1inch.io/","twitter":"https://twitter.com/1inch","blog":"https://blog.1inch.io/","documentation":"https://docs.1inch.io/","reddit":"https://www.reddit.com/r/1inch/","discord":"https://discord.com/invite/1inch","youtube":"https://www.youtube.com/channel/UCk0nvK4bHpteQXZKv7lkq5w","telegram":"https://t.me/OneInchNetwork","github":"https://github.com/1inch"},"resolutionSources":[{"text":"1inch Blog","uri":"https://blog.1inch.io/"},{"text":"1inch Twitter","uri":"https://twitter.com/1inch"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' AS ipfs_details UNION ALL
SELECT 'Qmac3pwFj4YirygAdqhEiyezzb5TUQFNCsD43R6ETo67ZV', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x676d782d76310000000000000000000000000000000000000000000000000000","productName":"GMX v1","requiresWhitelist":false,"efficiency":"6000","tags":["perpetual","trade","dex","leverage","swap"],"about":"GMX is a permissionless, decentralized spot and perpetual swap exchange on the Arbitrum network.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the GMX version 1 deployed on the Arbitrum and Ethereum blockchain (if available).","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum (if available)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gmx.io","app":"https://app.gmx.io","twitter":"https://twitter.com/GMX_IO","medium":"https://medium.com/@gmx.io","github":"https://github.com/gmx-io","telegram":"https://t.me/GMX_IO","discord":"https://discord.com/invite/ymN38YefH9"},"resolutionSources":[{"text":"GMX Blog","uri":"https://medium.com/@gmx.io"},{"text":"GMX Twitter","uri":"https://twitter.com/GMX_IO"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmagNBTagrbtG9EZhNFPXPiRAL1Cfq2cyT3WCzrqaJStt1', '{"title":"Curve Exploit","observed":"2023-07-31T08:08:00.000Z","proofOfIncident":["https://twitter.com/CurveFinance/status/1685925429041917952"],"description":"As a result of an issue in Vyper compiler in versions 0.2.15-0.3.0, following pools were hacked:\n\ncrv/eth\naleth/eth\nmseth/eth\npeth/eth\n\nAnother pool potentially affected is arbitrum’s tricrypto. Auditors and Vyper devs could not find a profitable exploit, but please exit that one","stake":"10000000000000000000000","createdBy":"0xB20d066d416ECFEC10C2Ed47390e44E0e4baFceD","permalink":"https://arbitrum.neptunemutual.net/reports/0x7072696d65000000000000000000000000000000000000000000000000000000/products/0x63757276652d7632000000000000000000000000000000000000000000000000"}' UNION ALL
SELECT 'QmaiakyFf99GsvJ3aD4JTPBmMhbVCjmdiCA6UqMyv2GuTp', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x616176652d763200000000000000000000000000000000000000000000000000","productName":"Aave Ethereum Market v2","requiresWhitelist":false,"efficiency":"9000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Aave is a decentralized non-custodial liquidity protocol where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) or undercollateralized (one-block liquidity) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the AAVE v2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://aave.com/","documentation":"https://docs.aave.com/","twitter":"https://twitter.com/aaveaave","github":"https://github.com/aave","discord":"https://discord.com/invite/CvKUrqM","telegram":"https://t.me/Aavesome","blog":"https://medium.com/aave","linkedin":""},"resolutionSources":[{"text":"Aave Twitter","uri":"https://twitter.com/aaveaave"},{"text":"Aave Blog","uri":"https://medium.com/aave"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmaKba8ZJdvVHTxXDD8ycajgzXwG1zSbGHD5fvnhHyyHJx', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x62616c616e6365722d7632000000000000000000000000000000000000000000","productName":"Balancer v2","requiresWhitelist":false,"efficiency":"7500","tags":["exchange","swap","dex","launchpad","flashloan"],"about":"Balancer is an automated market maker (AMM ) that allows LPs to deposit more types of tokens to liquidity pools instead of a pair, also gives more flexibility for LP creator to customize trading fees or create private pools. With the launch of V2 (since May 2021) the single Vault architecture separates the token accounting and management from the Pool logic, hence assets can shift around without emitting an ERC20 transfer event on-chain improving gas efficiency for traders.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Balancer V2 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions."]}}],"links":{"website":"https://balancer.fi/","twitter":"https://twitter.com/BalancerLabs","discord":"https://discord.balancer.fi/","blog":"https://medium.com/balancer-protocol","linkedin":"https://www.linkedin.com/company/balancer-labs/","youtube":"https://www.youtube.com/channel/UCBRHug6Hu3nmbxwVMt8x_Ow","github":"https://github.com/balancer-labs/"},"resolutionSources":[{"text":"Balancer Blog","uri":"https://medium.com/balancer-protocol"},{"text":"Balancer Twitter","uri":"https://twitter.com/BalancerLabs"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qmb8DRD8qE1irpj9YHTdkNks5BhLGyE1h8T86amhef77re', '{"coverKey":"0x62696e616e636500000000000000000000000000000000000000000000000000","coverName":"Binance Exchange Custody","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-BNB","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","bnb","binance"],"about":"Founded in 2017 Binance is by far the largest centralized crypto exchange ranked by daily volume traded. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users outside of the US and US territories (not any other apps listed on the platform)","To be eligible for a claim, policyholders must hold at least 100 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"One of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["The designated exchange platform suffers a security breach of its hot or cold wallets where the minimum total loss of funds exceeds $50M","Or the exchange halts all asset withdrawals for all users for more than 15 days except for Legitimate Reasons as defined under the Standard Terms and Conditions. In this case, incident report cannot be submitted until the expiry of the 15-day withdrawal-halt period. No policy could be purchased after withdrawal halt by the exchange and if any such policy purchased after withdrawal halt will be deemed invalid. Any policies that are expired prior to the end of the 15-day withdrawal-halt period will not be eligible for payout"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"50","ceiling":"1600","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"50000000000000000000000","stakeWithFee":"30000000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500","links":{"website":"https://binance.com/","discord":"https://discord.com/invite/jE4wt8g2H2","blog":"https://www.binance.com/en/blog","tiktok":"https://www.tiktok.com/@binance?lang=en","facebook":"https://www.facebook.com/binance","twitter":"https://twitter.com/binance","reddit":"https://www.reddit.com/r/binance/","instagram":"https://www.instagram.com/Binance/","coinmarketcap":"https://coinmarketcap.com/exchanges/binance/","youtube":"https://www.youtube.com/binanceyoutube"},"resolutionSources":[{"text":"Binance Twitter","uri":"https://twitter.com/binance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qmbije1EuhbETvUqcA1WR5Gt8QNrmwVM2diE5utX4LoLbX', '{"coverKey":"0x676d782d76310000000000000000000000000000000000000000000000000000","coverName":"GMX","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-GMX","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["perpetual","trade","dex","leverage","swap","glp"],"about":"GMX Exchange is a decentralized perpetual trading platform for top cryptocurrencies. Launched in September 2021, GMX allows traders to take long and short positions on perpetuals by depositing collateral. With up to 50x leverage, zero price impact trades, limit orders, and low swap fees, GMX has become a popular choice among DeFi traders. The DEX is currently live on Arbitrum and Avalanche.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process","list":{"type":"unordered","items":["This policy relates exclusively to  GMX version 2 deployed on the Arbitrum blockchain.  It includes smart contract risk associated with GLP.","To be eligible for a claim, policyholders must hold at least 399 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from the Arbitrum blockchain."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["Risks associated with the token bridges, including https://arbitrum.io/bridge-tutorial/ are excluded.","GLP counterparty risks are excluded.","All exclusions present in the standard terms and exclusions."]}}],"blockchains":[{"chainId":42161,"name":"Arbitrum"},{"chainId":43114,"name":"Avalanche C-Chain"}],"floor":"200","ceiling":"1800","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"400000000000000000000","stakeWithFee":"15000000000000000000000","initialReassuranceAmount":"25000000000","reassuranceRate":"2000","links":{"website":"https://gmx.io/","app":"https://app.gmx.io","discord":"https://discord.com/invite/ymN38YefH9","blog":"https://medium.com/@gmx.io","twitter":"https://twitter.com/GMX_IO","telegram":"https://t.me/GMX_IO","github":"https://github.com/gmx-io"},"resolutionSources":[{"text":"GMX Blog","uri":"https://medium.com/@gmx.io"},{"text":"GMX Twitter","uri":"https://twitter.com/GMX_IO"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmbQNn4ZstkW6aeaVeZ4DnBqx3Cg7pvoopsERFVmW9pwEB', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","coverName":"Popular DeFi Apps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-POP","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"6","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":56,"name":"BNB Chain"}],"floor":"200","ceiling":"1200","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"10000000000000000000000","stakeWithFee":"12500000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500"}' UNION ALL
SELECT 'Qmbuk5Bz1WFL7N3fPiPeofXrjdTH9owa97QXVstDrCYg8v', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x616176652d763200000000000000000000000000000000000000000000000000","productName":"Aave Ethereum Market v2","requiresWhitelist":false,"efficiency":"10000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Aave is a decentralized non-custodial liquidity protocol where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) or undercollateralized (one-block liquidity) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the AAVE v2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://aave.com/","documentation":"https://docs.aave.com/","twitter":"https://twitter.com/aaveaave","github":"https://github.com/aave","discord":"https://discord.com/invite/CvKUrqM","telegram":"https://t.me/Aavesome","blog":"https://medium.com/aave","linkedin":""},"resolutionSources":[{"text":"Aave Twitter","uri":"https://twitter.com/aaveaave"},{"text":"Aave Blog","uri":"https://medium.com/aave"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmcFbX3fHrnjLqtJbMLMJk2njFga6RPq2SysG3owZF6ziY', '{"coverKey":"0x62696e616e636500000000000000000000000000000000000000000000000000","coverName":"Binance Exchange Custody","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-BNB","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","bnb","binance"],"about":"Founded in 2017 Binance is by far the largest centralized crypto exchange ranked by daily volume traded. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users outside of the US and US territories (not any other apps listed on the platform)","To be eligible for a claim, policyholders must hold at least 100 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"One of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["The designated exchange platform suffers a security breach of its hot or cold wallets where the minimum total loss of funds exceeds $50M","Or the exchange halts all asset withdrawals for all users for more than 15 days except for Legitimate Reasons as defined under the Standard Terms and Conditions. In this case, incident report cannot be submitted until the expiry of the 15-day withdrawal-halt period. No policy could be purchased after withdrawal halt by the exchange and if any such policy purchased after withdrawal halt will be deemed invalid. Any policies that are expired prior to the end of the 15-day withdrawal-halt period will not be eligible for payout"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"50","ceiling":"1600","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"50000000000000000000000","stakeWithFee":"12500000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500","links":{"website":"https://binance.com/","discord":"https://discord.com/invite/jE4wt8g2H2","blog":"https://www.binance.com/en/blog","tiktok":"https://www.tiktok.com/@binance?lang=en","facebook":"https://www.facebook.com/binance","twitter":"https://twitter.com/binance","reddit":"https://www.reddit.com/r/binance/","instagram":"https://www.instagram.com/Binance/","coinmarketcap":"https://coinmarketcap.com/exchanges/binance/","youtube":"https://www.youtube.com/binanceyoutube"},"resolutionSources":[{"text":"Binance Twitter","uri":"https://twitter.com/binance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmcGnscy5Mfdu6sc8sLWdHTMgjEuXS5rMZbc3MzWEV3yJq', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","coverName":"Popular DeFi Apps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-POP","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"10","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"floor":"200","ceiling":"1200","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"25000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500"}' UNION ALL
SELECT 'QmchsMM8GzKQUain63VW2shmZu319E3wFcs4uosGhDq3rM', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","coverName":"Prime dApps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-PRI","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"6","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"floor":"50","ceiling":"800","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"10000000000000000000000","stakeWithFee":"12000000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500"}' UNION ALL
SELECT 'QmcK1pTGGqa7RHwxZtid5EL6ncSXR8Trnbc7yDCuC8vj1H', '{"title":"Curve pools been exploited","observed":"2023-07-31T06:07:00.000Z","proofOfIncident":["https://twitter.com/curvefinance/status/1685693202722848768?s=46&t=MS9Mk_e5oFCUxeHDdAmLuQ"],"description":"According to Curve Protocol''s tweet:\nA number of stablepools (alETH/msETH/pETH) using Vyper 0.2.15 have been exploited as a result of a malfunctioning reentrancy lock.","stake":"10000000000000000000000","createdBy":"0xada72FCb3539872D4510e6105aF969ae39558472","permalink":"https://ethereum.neptunemutual.net/reports/0x7072696d65000000000000000000000000000000000000000000000000000000/products/0x63757276652d7632000000000000000000000000000000000000000000000000"}' UNION ALL
SELECT 'QmctEE6U5BS63FvkU6QD8eSR91K1g7G6owRoKfLYLG61zo', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x736166652d763100000000000000000000000000000000000000000000000000","productName":"Safe v1","requiresWhitelist":false,"efficiency":"9500","tags":["wallet","multi-sig"],"about":"Gnosis Safe is the successor to the Gnosis Multisig. Multi-signature. Multi-signature allows you define an access/control-scheme through multiple signers that need to confirm transactions. DeFi integrations. Easily interact with popular decentralized finance protocols to invest, trade and manage digital assets.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to all of the instances of Gnosis Safe v1 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gnosis-safe.io/","twitter":"https://twitter.com/gnosisSafe","discord":"https://discord.com/invite/AjG7AQD9Qn","github":"https://github.com/safe-global","documentation":"https://docs.gnosis-safe.io/"},"resolutionSources":[{"text":"Gnosis Safe Twitter","uri":"https://twitter.com/gnosisSafe"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmcTj2zcuHRfxx2HKiVMumy35SCiYHiJD6Xe14rKNjuGe4', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x63757276652d7632000000000000000000000000000000000000000000000000","productName":"Curve Finance v2","requiresWhitelist":false,"efficiency":"7000","tags":["dex","exchange","swap","stablecoin"],"about":"Curve is an automated market maker (AMM), The main difference between Curve and other DEXes is that Curve focuses mainly on stablecoins trading. Thereby improving capital efficiency and reducing slippage. The release of its V2 since June 2021, also allows trading of non-pegged assets in a more concentrated liquidity fashion whilst still allowing LP to passively provide liquidity without specifying a price range.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Curve v2 protocol deployed on the Arbitrum and Ethereum blockchains.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://curve.fi/","twitter":"https://twitter.com/CurveFinance","telegram":"https://t.me/curvefi","discord":"https://discord.com/invite/9uEHakc","documentation":"https://resources.curve.fi/","github":"https://github.com/curvefi"},"resolutionSources":[{"text":"Curve News","uri":"https://news.curve.fi"},{"text":"Curve Twitter","uri":"https://twitter.com/CurveFinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmcyCnFeKwM7mnvz4w3x7cvcjJ1HD9uHGrTv8bdZWc1rDi', '{"coverKey":"0x68756f6269000000000000000000000000000000000000000000000000000000","coverName":"Huobi Global","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-HT","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","huobi","ht"],"about":"Founded in 2013 Huobi Global is amongst the battle tested crypto exchanges with longer operating history and once ranked number 1 globally in terms of trading volume. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users (outside of US and US territories).","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $50 million.","Huobi suffers a security breach of its hot or cold wallets where the user funds are permanently and irrecoverably stolen from Huobi.","The loss must arise from security incidents of the crypto storage systems"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Losses arisen due to issues with fork, merge,  any other changes of relevant underlying blockchains","Losses resulting from Key man risk where a single person controls access to the user funds at the custodian, is not covered.","Huobi non custodial wallet is not relevant to this cover","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"400","ceiling":"1600","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"27000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500","links":{"website":"https://www.huobi.com/","blog":"https://blog.huobi.com/","twitter":"https://twitter.com/huobiglobal","instagram":"https://www.instagram.com/huobiglobalofficial/","youtube":"https://www.youtube.com/huobiglobal","facebook":"https://www.facebook.com/huobiglobalofficial","reddit":"https://www.reddit.com/r/HuobiGlobal/","linkedin":"https://www.linkedin.com/company/huobi/"},"resolutionSources":[{"text":"Huobi Twitter","uri":"https://twitter.com/huobiglobal"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qmd8p5a5eUXFF9XofGCi9EWD8dnQayfPfANfRB4vGUtXqt', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","coverName":"Popular DeFi Apps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-POP","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"6","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"floor":"200","ceiling":"1200","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"10000000000000000000000","stakeWithFee":"30000000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500"}' UNION ALL
SELECT 'QmdDBBpGVParKgMGYTYzPs6edjcogByjJhRJ77guvUEukP', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x636f6d706f756e642d7633000000000000000000000000000000000000000000","productName":"Compound Finance","requiresWhitelist":false,"efficiency":"7000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Compound  is a decentralized non-custodial liquidity protocol on Ethereum where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"},{"chainId":137,"name":"Polygon Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Compound V3 protocol deployed on the Arbitrum, Ethereum and Polygon Mainnet blockchains.","To be eligible for a claim, policyholder must hold at least 99 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum, Ethereum and Polygon Mainnet."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://compound.finance/","discord":"https://discord.com/invite/fq6JSPkpJn","github":"https://github.com/compound-finance/compound-protocol","blog":"https://medium.com/compound-finance","twitter":"https://twitter.com/compoundfinance","app":"https://app.compound.finance/"},"resolutionSources":[{"text":"Compound Twitter","uri":"https://twitter.com/compoundfinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmdpPqKV1QVxjq21FHa4UP7Hn4urWAK23BWaYxyWoLvUkP', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x676e6f7369732d736166652d7631000000000000000000000000000000000000","productName":"Gnosis Safe v1","requiresWhitelist":false,"efficiency":"7000","tags":["wallet","multi-sig"],"about":"Gnosis Safe is the successor to the Gnosis Multisig. Multi-signature. Multi-signature allows you define an access/control-scheme through multiple signers that need to confirm transactions. DeFi integrations. Easily interact with popular decentralized finance protocols to invest, trade and manage digital assets.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to all of the instances of Gnosis Safe v1 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gnosis-safe.io/","twitter":"https://twitter.com/gnosisSafe","discord":"https://discord.com/invite/AjG7AQD9Qn","github":"https://github.com/safe-global","documentation":"https://docs.gnosis-safe.io/"},"resolutionSources":[{"text":"Gnosis Safe Twitter","uri":"https://twitter.com/gnosisSafe"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmdVzaJvHjZ9aqkV86cbJH2zihhME8MF22QegZm8C3r7qc', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x6f6e65696e63682d763200000000000000000000000000000000000000000000","productName":"1inch v2","requiresWhitelist":false,"efficiency":"8000","tags":["exchange","dex","swap","aggregation"],"about":"The 1inch Network brings together decentralized protocols that work synergistically to provide efficient, secure operations in the DeFi space. It offers access to a multitude of liquidity sources across various chains. The 1inch Network was launched at the ETHGlobal New York hackathon in May 2019 with the release of its Aggregation Protocol v1. Since then, the 1inch Network has added more DeFi tools to its repertoire, including the Liquidity Protocol, Limit Order Protocol, P2P transactions, and the 1inch Mobile Wallet.","blockchains":[{"chainId":56,"name":"BNB Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the 1inch v2 protocol deployed on the BNB Smart Chain.","To be eligible for a claim, the policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: BNB Smart Chain (BSC) (Previously Binance Smart Chain)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://1inch.io/","twitter":"https://twitter.com/1inch","blog":"https://blog.1inch.io/","documentation":"https://docs.1inch.io/","reddit":"https://www.reddit.com/r/1inch/","discord":"https://discord.com/invite/1inch","youtube":"https://www.youtube.com/channel/UCk0nvK4bHpteQXZKv7lkq5w","telegram":"https://t.me/OneInchNetwork","github":"https://github.com/1inch"},"resolutionSources":[{"text":"1inch Blog","uri":"https://blog.1inch.io/"},{"text":"1inch Twitter","uri":"https://twitter.com/1inch"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmdYHrqdRPAwBg32HCYMiG5RtdJ4Gb71igoGUrHfDzVeqq', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x636f6e7665782d76310000000000000000000000000000000000000000000000","productName":"Convex (Curve)","requiresWhitelist":false,"efficiency":"5000","tags":["curve","staking","yield"],"about":"Convex Finance is a platform for CRV token holders and Curve LPs to earn additional interest and  trading fees.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the version 1 version of the protocol (Convex/Curve) deployed on the Ethereum and Arbitrum blockchain.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and Arbitrum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://www.convexfinance.com","docs":"https://docs.convexfinance.com/","blog":"https://convexfinance.medium.com","twitter":"https://twitter.com/ConvexFinance","discord":"https://discord.com/invite/TTEVTqY488","telegram":"https://t.me/convexEthChat"},"resolutionSources":[{"text":"Convex Twitter","uri":"https://twitter.com/ConvexFinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qme5v1qf7tBZWASYpBMBzQ3shB61KXJwAKrDEuFcyrjSAn', '{"coverKey":"0x62696e616e636500000000000000000000000000000000000000000000000000","coverName":"Binance Exchange","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-BNB","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","bnb","binance"],"about":"Founded in 2017 Binance is by far the largest centralized crypto exchange ranked by daily volume traded. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users (outside of US and US territories).","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $50 million.","Binance suffers a security breach of its hot or cold wallets where the user funds are permanently and irrecoverably stolen from Binance.","The loss must arise from security incidents of the crypto storage systems"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Losses arisen due to issues with fork, merge,  any other changes of relevant underlying blockchains","Losses resulting from Key man risk where a single person controls access to the user funds at the custodian, is not covered.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"400","ceiling":"1600","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"30000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500","links":{"website":"https://binance.com/","discord":"https://discord.com/invite/jE4wt8g2H2","blog":"https://www.binance.com/en/blog","tiktok":"https://www.tiktok.com/@binance?lang=en","facebook":"https://www.facebook.com/binance","twitter":"https://twitter.com/binance","reddit":"https://www.reddit.com/r/binance/","instagram":"https://www.instagram.com/Binance/","coinmarketcap":"https://coinmarketcap.com/exchanges/binance/","youtube":"https://www.youtube.com/binanceyoutube"},"resolutionSources":[{"text":"Binance Twitter","uri":"https://twitter.com/binance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qme8nonYp95gD5e7K7VFP1SdaR82v8vTHVPKjbZ9gjRtVX', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x636f6d706f756e642d7633000000000000000000000000000000000000000000","productName":"Compound Finance","requiresWhitelist":false,"efficiency":"7000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Compound  is a decentralized non-custodial liquidity protocol on Ethereum where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"},{"chainId":137,"name":"Polygon Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Compound V3 protocol deployed on the Arbitrum, Ethereum and Polygon Mainnet blockchains.","To be eligible for a claim, policyholder must hold at least 99 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum, Ethereum and Polygon Mainnet."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://compound.finance/","discord":"https://discord.com/invite/fq6JSPkpJn","github":"https://github.com/compound-finance/compound-protocol","blog":"https://medium.com/compound-finance","twitter":"https://twitter.com/compoundfinance","app":"https://app.compound.finance/"},"resolutionSources":[{"text":"Compound Twitter","uri":"https://twitter.com/compoundfinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'Qmeu6eZfyQt25bW6JWWqwWPVBGythbBnFZEFytwY23iRgc', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x756e69737761702d763200000000000000000000000000000000000000000000","productName":"Uniswap v2","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","nft"],"about":"The Uniswap protocol is a peer-to-peer system designed for exchanging cryptocurrencies (ERC-20 Tokens) on the Ethereum blockchain. The protocol is implemented as a set of persistent, non-upgradable smart contracts; designed to prioritize censorship resistance, security, self-custody, and to function without any trusted intermediaries who may selectively restrict access.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Uniswap V2 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://uniswap.org/","app":"https://app.uniswap.org/#/swap?use=V2","twitter":"https://twitter.com/Uniswap","blog":"https://uniswap.org/blog","discord":"https://discord.com/invite/FCfyBSbCU5","github":"https://github.com/Uniswap","docs":"https://docs.uniswap.org/protocol/V2/introduction"},"resolutionSources":[{"text":"Uniswap Blog","uri":"https://uniswap.org/blog"},{"text":"Uniswap Twitter","uri":"https://twitter.com/Uniswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmeUY4Lo9VuRL2Fr5aftCv21rLGbuDMB8tg7LkiTpUeaKX', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x756e69737761702d763300000000000000000000000000000000000000000000","productName":"Uniswap v3","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","flashloan","nft"],"about":"The Key difference of UniswapV3 compared to V2 is “concentrated liquidity”,  allowing LPs to control the price range in which their assets get traded. To reduce slippage and improve capital efficiency. V3 is released in May 2021.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Uniswap v3 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://uniswap.org/","app":"https://app.uniswap.org/#/swap","twitter":"https://twitter.com/Uniswap","blog":"https://uniswap.org/blog","discord":"https://discord.com/invite/FCfyBSbCU5","github":"https://github.com/Uniswap","docs":"https://docs.uniswap.org/protocol/introduction"},"resolutionSources":[{"text":"Uniswap Blog","uri":"https://uniswap.org/blog"},{"text":"Uniswap Twitter","uri":"https://twitter.com/Uniswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmfD3Pp6tockqnhzzDLT1TDiZJZ7B4o56QY6aSepYGduDP', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x72706c2d76310000000000000000000000000000000000000000000000000000","productName":"Rocketpool v1","requiresWhitelist":false,"efficiency":"9000","tags":["staking","yield"],"about":"Rocket Pool is a liquid staking service protocol that runs a network of decentralized nodes, to perform validation services for the Ethereum 2.0 blockchain. Its purpose is to provide users who do not possess the required minimum of ETH tokens to stake and earn yields.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Rocket Pool v1 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://rocketpool.net/","discord":"https://discord.com/invite/rocketpool","blog":"https://medium.com/rocket-pool","twitter":"https://twitter.com/Rocket_Pool","github":"https://github.com/rocket-pool","dao":"https://dao.rocketpool.net/","youtube":"https://www.youtube.com/rocketpool","reddit":"https://www.reddit.com/r/rocketpool/"},"resolutionSources":[{"text":"Rocket Pool Twitter","uri":"https://twitter.com/Rocket_Pool"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmfDdLWy3DdY5GAqnWJ8VoXD24Uv9AAssQeHrrnk6uu1Ve', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x756e69737761702d763300000000000000000000000000000000000000000000","productName":"Uniswap v3","requiresWhitelist":false,"efficiency":"9500","tags":["exchange","dex","swap","nft"],"about":"The Uniswap protocol is a peer-to-peer system designed for exchanging cryptocurrencies (ERC-20 Tokens) on the Ethereum blockchain. The protocol is implemented as a set of persistent, non-upgradable smart contracts. It is designed to prioritize censorship resistance, security, self-custody, and to function without any trusted intermediaries who may selectively restrict access. It has been deployed on the BNB Smart Chain since early 2023.","blockchains":[{"chainId":56,"name":"BNB Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Uniswap v3 deployed on the BNB Smart Chain.","To be eligible for a claim, the policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: BNB Smart Chain (BSC) (Previously Binance Smart Chain)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://uniswap.org/","app":"https://app.uniswap.org/#/swap?use=V2","twitter":"https://twitter.com/Uniswap","blog":"https://uniswap.org/blog","discord":"https://discord.com/invite/FCfyBSbCU5","github":"https://github.com/Uniswap","docs":"https://docs.uniswap.org/protocol/V2/introduction"},"resolutionSources":[{"text":"Uniswap Blog","uri":"https://uniswap.org/blog"},{"text":"Uniswap Twitter","uri":"https://twitter.com/Uniswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmfEViRmvDaE8GaGWrgEjkAHsTx9Dmcsiwtu2TTYfi8M9Y', '{"coverKey":"0x636f696e62617365000000000000000000000000000000000000000000000000","coverName":"Coinbase (Non US)","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-COIN","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","coinbase","coin"],"about":"Founded in 2012 Coinbase is the largest exchange for institutional crypto traders, and the first crypto exchange that went public and listed on Nasdaq. Users can trade mainly spots via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users (outside of US and US territories).","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $50 million.","Coinbase suffers a security breach of its hot or cold wallets where the user funds are permanently and irrecoverably stolen from Coinbase.","The loss must arise from security incidents of the crypto storage systems"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Losses arisen due to issues with fork, merge,  any other changes of relevant underlying blockchains","Losses resulting from Key man risk where a single person controls access to the user funds at the custodian, is not covered.","Coinbase non custodial wallet is not relevant to this cover","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"400","ceiling":"1600","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"26000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500","links":{"website":"https://coinbase.com/","blog":"https://www.coinbase.com/blog","twitter":"https://twitter.com/coinbase","facebook":"https://www.facebook.com/Coinbase"},"resolutionSources":[{"text":"Coinbase Twitter","uri":"https://twitter.com/coinbase"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmNkoMt274zKMXFz5cKzNUNvfXNFpBgm3nZTTFKA47wmDu', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x73796e7468657469782d76320000000000000000000000000000000000000000","productName":"Synthetix v2","requiresWhitelist":false,"efficiency":"8000","tags":["derivative","staking","yield"],"about":"Synthetix is a new financial primitive enabling the creation of synthetic assets, offering unique derivatives and exposure to real-world assets on the blockchain.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":10,"name":"OP Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Synthetix Protocol (v2) deployed on the Ethereum and OP Mainnet blockchains.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and OP Mainnet."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://synthetix.io/","discord":"https://discord.com/invite/AEdUHzt","twitter":"https://twitter.com/synthetix_io","github":"https://github.com/synthetixio","blog":"https://blog.synthetix.io/","dao":"https://synthetix.io/governance","documentation":"https://docs.synthetix.io/"},"resolutionSources":[{"text":"Synthetix Twitter","uri":"https://twitter.com/synthetix_io"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmNrtsqPhdDwNZwsxyjPjgFzD1XM2VvLPhEiTMu9uiikXM', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x6e657875732d6d757475616c2d76310000000000000000000000000000000000","productName":"Nexus Mutual v1","requiresWhitelist":false,"efficiency":"9000","tags":["insurance","cover"],"about":"Nexus Mutual is a decentralized alternative to insurance. Nexus Mutual uses blockchain technology to create a risk sharing pool in the form of a mutual to return the power of insurance to the people. The platform is built on the Ethereum public chain. It allows anyone to become a member and purchase cover. It replaces the idea of a traditional insurance company because it is wholly owned by the members. The model encourages engagement as members will get economic incentives for participating in Risk Assessment, Claims Assessment and Governance.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Nexus Mutual v1 contracts deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://nexusmutual.io/","twitter":"https://twitter.com/NexusMutual","blog":"https://medium.com/nexus-mutual","documentation":"https://nexusmutual.gitbook.io/docs/users/understanding-nexus-mutual","github":"https://github.com/NexusMutual","discord":"https://discord.com/invite/aQjkzW5","telegram":"https://t.me/joinchat/K_g-fA-3CmFwXumCKQUXkw"},"resolutionSources":[{"text":"Nexus Mutual Twitter","uri":"https://twitter.com/NexusMutual"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmNTWRJnb1Luk4PwbqGZ3XY78bGRHeU7vw95HqmoySDnQa', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x73796e7468657469782d76320000000000000000000000000000000000000000","productName":"Synthetix v2","requiresWhitelist":false,"efficiency":"7000","tags":["derivative","staking","yield"],"about":"Synthetix is a new financial primitive enabling the creation of synthetic assets, offering unique derivatives and exposure to real-world assets on the blockchain.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Synthetix Protocol (v2) deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://synthetix.io/","discord":"https://discord.com/invite/AEdUHzt","twitter":"https://twitter.com/synthetix_io","github":"https://github.com/synthetixio","blog":"https://blog.synthetix.io/","dao":"https://synthetix.io/governance","documentation":"https://docs.synthetix.io/"},"resolutionSources":[{"text":"Synthetix Twitter","uri":"https://twitter.com/synthetix_io"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmP4BGgYVb8ZQyLDeAfk8oyszCRo2BPcqUYfh6uCeZDAMz', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x676d782d76320000000000000000000000000000000000000000000000000000","productName":"GMX v2","requiresWhitelist":false,"efficiency":"6000","tags":["perpetual","trade","dex","leverage","swap"],"about":"GMX is a permissionless, decentralized spot and perpetual swap exchange on the Arbitrum network.","blockchains":[{"chainId":42161,"name":"Arbitrum One"},{"chainId":43114,"name":"Avalanche C-Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the GMX version 1 deployed on the Arbitrum and Avalanche blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Avalanche."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gmx.io","app":"https://app.gmx.io","twitter":"https://twitter.com/GMX_IO","medium":"https://medium.com/@gmx.io","github":"https://github.com/gmx-io","telegram":"https://t.me/GMX_IO","discord":"https://discord.com/invite/ymN38YefH9"},"resolutionSources":[{"text":"GMX Blog","uri":"https://medium.com/@gmx.io"},{"text":"GMX Twitter","uri":"https://twitter.com/GMX_IO"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPabWcVa6t6tDjjTo6zneeaaub4EfoCnbNCkqFaX3LFKE', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x7375736869737761702d76330000000000000000000000000000000000000000","productName":"Sushiswap","requiresWhitelist":false,"efficiency":"5000","tags":["exchange","dex","swap","nft"],"about":"Sushiswap is  an automated market maker (AMM), in addition to facilitating market making for LPs and traders, Sushiswap also offers token aults for lending & borrowing.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"},{"chainId":56,"name":"BNB Smart Chain Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the v3 of the (Swap) protocol deployed on the Ethereum, Arbitrum and BNB blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum, Arbitrum and BNB."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://sushi.com/","twitter":"https://twitter.com/sushiswap","blog":"https://sushichef.medium.com/","github":"https://github.com/sushiswap","documentation":"https://dev.sushi.com/"},"resolutionSources":[{"text":"Sushi Blog","uri":"https://sushichef.medium.com"},{"text":"Sushi Twitter","uri":"https://twitter.com/sushiswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPEPkdEWPhfoQtX1XuFAerpZLDVtbbCYgiFiioMvHLwuo', '{"title":"Testing","observed":"2023-12-11T10:21:00.000Z","proofOfIncident":["https://example.com"],"description":"Test","stake":"2000000000000000000000","createdBy":"0x201Bcc0d375f10543e585fbB883B36c715c959B3","permalink":"https://mumbai.neptunemutual.com/reports/0x7072696d65000000000000000000000000000000000000000000000000000000/products/0x676e6f7369732d736166652d7631000000000000000000000000000000000000"}' UNION ALL
SELECT 'QmPiKWDUPVUJuW7bpqVpXRUyeC1rr3HNu9cUFrCE114BSB', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x63757276652d7632000000000000000000000000000000000000000000000000","productName":"Curve Finance v2","requiresWhitelist":false,"efficiency":"7000","tags":["dex","exchange","swap","stablecoin"],"about":"Curve is an automated market maker (AMM), The main difference between Curve and other DEXes is that Curve focuses mainly on stablecoins trading. Thereby improving capital efficiency and reducing slippage. The release of its V2 since June 2021, also allows trading of non-pegged assets in a more concentrated liquidity fashion whilst still allowing LP to passively provide liquidity without specifying a price range.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Curve v2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://curve.fi/","twitter":"https://twitter.com/CurveFinance","telegram":"https://t.me/curvefi","discord":"https://discord.com/invite/9uEHakc","documentation":"https://resources.curve.fi/","github":"https://github.com/curvefi"},"resolutionSources":[{"text":"Curve News","uri":"https://news.curve.fi"},{"text":"Curve Twitter","uri":"https://twitter.com/CurveFinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPiUWSq5P3JAChY4so6R7kQy33bVghBaS5dWNmg3ZQ5Ew', '{"title":"Test REPORT","observed":"2023-11-10T06:23:00.000Z","proofOfIncident":["https://thisisfake.com"],"description":"This is a fake report test. Please ignore this report.","stake":"2000000000000000000000","createdBy":"0x9BDAE2a084EC18528B78e90b38d1A67c79F6Cab6","permalink":"https://mumbai.neptunemutual.com/reports/0x7072696d65000000000000000000000000000000000000000000000000000000/products/0x676e6f7369732d736166652d7631000000000000000000000000000000000000"}' UNION ALL
SELECT 'QmPJHouJz6vx1JWX4ZG93CSLTp9wuM1JS6cQJz7tzsE4fd', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x7375736869737761702d76330000000000000000000000000000000000000000","productName":"Sushiswap","requiresWhitelist":false,"efficiency":"5000","tags":["exchange","dex","swap","nft"],"about":"Sushiswap is  an automated market maker (AMM), in addition to facilitating market making for LPs and traders, Sushiswap also offers token aults for lending & borrowing.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"},{"chainId":56,"name":"BNB Smart Chain Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the v3 of the (Swap) protocol deployed on the Ethereum, Arbitrum and BNB blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum, Arbitrum and BNB."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://sushi.com/","twitter":"https://twitter.com/sushiswap","blog":"https://sushichef.medium.com/","github":"https://github.com/sushiswap","documentation":"https://dev.sushi.com/"},"resolutionSources":[{"text":"Sushi Blog","uri":"https://sushichef.medium.com"},{"text":"Sushi Twitter","uri":"https://twitter.com/sushiswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPmBngN7neCy2ZGJyvu64drGscBjptF4x1QNWgRQiZCuF', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x62616e636f722d76330000000000000000000000000000000000000000000000","productName":"Bancor v3","requiresWhitelist":false,"efficiency":"5000","tags":["exchange","dex","swap"],"about":"Bancor was the first dApp that utilized AMM model and also pioneered the efforts in \"impermanent loss\" protection","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the version 3 of the Bancor protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://www.bancor.network","app":"https://app.bancor.network/swap","github":"https://github.com/bancorprotocol","docs":"https://docs.bancor.network/","support":"https://support.bancor.network/hc/en-us/","blog":"https://blog.bancor.network/","discord":"https://discord.com/invite/5d3JXqYQGj","telegram":"https://t.me/bancor","twitter":"https://twitter.com/Bancor"},"resolutionSources":[{"text":"Bancor Blog","uri":"https://blog.bancor.network/"},{"text":"Bancor Twitter","uri":"https://twitter.com/Bancor"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPoihzcsB7P1gjFmm8XQKt7ydnNnLgiWhjWnjaMJnHhiQ', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x756e69737761702d76322d616e642d7633000000000000000000000000000000","productName":"Uniswap","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","nft"],"about":"The Uniswap protocol is a peer-to-peer system designed for exchanging cryptocurrencies (ERC-20 Tokens) on the Ethereum blockchain. The protocol is implemented as a set of persistent, non-upgradable smart contracts; designed to prioritize censorship resistance, security, self-custody, and to function without any trusted intermediaries who may selectively restrict access.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":56,"name":"BNB Smart Chain Mainnet"},{"chainId":42161,"name":"Arbitrum One"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Uniswap V2 and V3 deployed on the Ethereum, Arbitrum and BNB blockchains.","To be eligible for a claim, policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum, Arbitrum and BNB Smart Chain."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://uniswap.org/","app":"https://app.uniswap.org/#/swap","twitter":"https://twitter.com/Uniswap","blog":"https://uniswap.org/blog","discord":"https://discord.com/invite/FCfyBSbCU5","github":"https://github.com/Uniswap","docs":"https://docs.uniswap.org/protocol/V2/introduction"},"resolutionSources":[{"text":"Uniswap Blog","uri":"https://uniswap.org/blog"},{"text":"Uniswap Twitter","uri":"https://twitter.com/Uniswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmPuZBJ4CDXs71KmQaUtBLWTLHD4kWBH9N79mGgoZXkQNK', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x616176652d76322d616e642d7633000000000000000000000000000000000000","productName":"Aave","requiresWhitelist":false,"efficiency":"9000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Aave is a decentralized non-custodial liquidity protocol where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) or undercollateralized (one-block liquidity) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the AAVE v2 and v3 protocol deployed on the Arbitrum and Ethereum blockchains.","To be eligible for a claim, policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://aave.com/","documentation":"https://docs.aave.com/","twitter":"https://twitter.com/aaveaave","github":"https://github.com/aave","discord":"https://discord.com/invite/CvKUrqM","telegram":"https://t.me/Aavesome","blog":"https://medium.com/aave"},"resolutionSources":[{"text":"Aave Twitter","uri":"https://twitter.com/aaveaave"},{"text":"Aave Blog","uri":"https://medium.com/aave"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmQVtftRbnz7imWHAkc1q8jiZbRMDeB5kkiXXf8swWQf61', '{"coverKey":"0x72616469616e742d763200000000000000000000000000000000000000000000","coverName":"Radiant V2","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-RDNT","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["lending","omnichain","interoperability","leverage","LayerZero","DeFi 3.0"],"about":"Radiant Capital is a non-custodial omni-chain lending & flash loan protocol built on Layer Zero. Users can deposit any major asset on any major chain and borrow various supported assets across multiple chains.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process","list":{"type":"unordered","items":["This policy relates exclusively to  Radiant DAO’s version 2 (RDNT) deployed on Arbitrum with a migration to the LayerZero OFT format and integration with the Stargate stable router interface.","To be eligible for a claim, policyholders must hold at least 499 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from the Arbitrum blockchain."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["Risks associated with the token bridges are excluded.","All exclusions present in the standard terms and exclusions."]}}],"blockchains":[{"chainId":42161,"name":"Arbitrum"},{"chainId":56,"name":"BNB Smart Chain"}],"floor":"300","ceiling":"2000","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"350000000000000000000","stakeWithFee":"15000000000000000000000","initialReassuranceAmount":"15000000000","reassuranceRate":"2500","links":{"website":"https://radiant.capital/","app":"https://app.radiant.capital/","discord":"https://discord.gg/radiantcapital","blog":"https://medium.com/@RadiantCapital","twitter":"https://twitter.com/RDNTCapital","telegram":"https://t.me/radiantcapitalofficial","github":"https://github.com/radiant-capital","youtube":"https://www.youtube.com/c/RadiantCapital/"},"resolutionSources":[{"text":"Radiant Twitter","uri":"https://twitter.com/RDNTCapital"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmQY5QPMmz2kizsV6WDZC5pzMsHF9rVFJyWLS5irTRyF9T', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x636f6e7665782d76310000000000000000000000000000000000000000000000","productName":"Convex v1","requiresWhitelist":false,"efficiency":"9000","tags":["curve","staking","yield"],"about":"Convex Finance is a platform for CRV token holders and Curve liquidity providers to earn additional interest rewards and Curve trading fees on their tokens. Users can deposit either CRV or Curve LP tokens into Convex and be able to receive yields the native tokens are entitled to as well as CVX.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Convex v1 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://www.convexfinance.com","docs":"https://docs.convexfinance.com/","blog":"https://convexfinance.medium.com","twitter":"https://twitter.com/ConvexFinance","discord":"https://discord.com/invite/TTEVTqY488","telegram":"https://t.me/convexEthChat"},"resolutionSources":[{"text":"Convex Twitter","uri":"https://twitter.com/ConvexFinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmRmw7C2sHCLraMjByQec9xN7PXf3kTafdsc7gpTw7BrYa', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","coverName":"Prime dApps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-PRI","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"10","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"floor":"50","ceiling":"800","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"25000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500"}' UNION ALL
SELECT 'QmS5qnWfiHLkGhr78yyTBaa671x5M6TkpFHvVUyUR2mXjC', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x646f646f2d763200000000000000000000000000000000000000000000000000","productName":"DODO v2","requiresWhitelist":false,"efficiency":"7000","tags":["amm","dex","pmm","liquidity"],"about":"DODO is a DeFi  protocol and on-chain liquidity provider that differentiates itself with a proactive market maker (PMM) algorithm, with the aim to offer better liquidity and price stability compared to the AMM (automated market maker) models.  The PMM algorithm mimics human trading, utilizes oracles to gather market prices, then provides liquidity close to these prices in order to stabilize the portfolios for liquidity providers (LP).","blockchains":[{"chainId":56,"name":"BNB Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the DODO v2 protocol deployed on the BNB Smart Chain.","To be eligible for a claim, the policyholder must hold at least 399 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: BNB Smart Chain (BSC) (Previously Binance Smart Chain)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://dodoex.io","app":"https://app.dodoex.io","docs":"https://docs.dodoex.io","github":"https://github.com/DODOEX","telegram":"https://t.me/dodoex_official","twitter":"https://twitter.com/BreederDodo","discord":"https://discord.gg/tyKReUK","community":"https://community.dodoex.io/"},"resolutionSources":[{"text":"DODO Twitter","uri":"https://twitter.com/BreederDodo"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmSFTdPE2EhHECWk17WwjWKRCXdEDGjxLPYKzUwCfK5Rz8', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x70616e63616b65737761702d7632000000000000000000000000000000000000","productName":"PancakeSwap v2","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","nft"],"about":"PancakeSwap is the most popular decentralized exchange protocol for swapping BEP20 tokens on the BNB Smart Chain. The protocol, launched in December 2020, is based on the AMM (automated market maker) model, where users trade against a liquidity pool. These pools are filled by users who deposit their funds and, in return, receive liquidity provider (LP) tokens, enabling them to earn proportional trading fees.","blockchains":[{"chainId":56,"name":"BNB Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the PancakeSwap v2 deployed on the BNB Smart Chain.","To be eligible for a claim, the policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: BNB Smart Chain (BSC) (Previously Binance Smart Chain)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://pancakeswap.finance/","docs":"https://docs.pancakeswap.finance/","twitter":"https://twitter.com/pancakeswap","telegram":"https://t.me/pancakeswap","reddit":"https://reddit.com/r/pancakeswap","instagram":"https://instagram.com/pancakeswap_official","github":"https://github.com/pancakeswap/","discord":"https://discord.gg/pancakeswap","youtube":"https://www.youtube.com/@pancakeswap_official"},"resolutionSources":[{"text":"Pancakeswap Twitter","uri":"https://twitter.com/pancakeswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmSHNAZysPGjv81FEE9RRY1WVhPp7cpGNxv4GpjRb5keT4', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x7375736869737761702d76310000000000000000000000000000000000000000","productName":"Sushiswap","requiresWhitelist":false,"efficiency":"5000","tags":["exchange","dex","swap","nft"],"about":"Sushiswap is  an automated market maker (AMM), in addition to facilitating market making for LPs and traders, Sushiswap also offers token vaults for lending & borrowing.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the version 1 version of the (Swap) protocol deployed on the Ethereum and Arbitrum blockchain.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and Arbitrum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://sushi.com/","twitter":"https://twitter.com/sushiswap","blog":"https://sushichef.medium.com/","github":"https://github.com/sushiswap","documentation":"https://dev.sushi.com/"},"resolutionSources":[{"text":"Sushi Blog","uri":"https://sushichef.medium.com"},{"text":"Sushi Twitter","uri":"https://twitter.com/sushiswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmT6ukCFSBUPrP61Dz1i6Z71u3xRSWtRvQZR6FEfmPhnCA', '{"title":"Fake Dispute to Fake Report","proofOfDispute":["https://thisfakereportisfake.com"],"description":"Ignore this","stake":"2000000000000000000000","createdBy":"0x9BDAE2a084EC18528B78e90b38d1A67c79F6Cab6","permalink":"https://mumbai.neptunemutual.com/reports/0x7072696d65000000000000000000000000000000000000000000000000000000/products/0x676e6f7369732d736166652d7631000000000000000000000000000000000000/incidents/1699597506"}' UNION ALL
SELECT 'QmTGMmPURT6opok7qJUjSGtibVTvpPGcrd9gUdV2ucMpUn', '{"coverKey":"0x61746c6173737761702d76310000000000000000000000000000000000000000","coverName":"AtlasSwap v1","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-AS","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","dex","swap"],"about":"The AtlasSwap protocol is a peer-to-peer system for exchanging cryptocurrencies (ERC-20 Tokens)","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users outside of the US and US territories (not any other apps listed on the platform)","To be eligible for a claim, policyholders must hold at least 100 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"One of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["The designated exchange platform suffers a security breach of its hot or cold wallets where the minimum total loss of funds exceeds $50M","Or the exchange halts all asset withdrawals for all users for more than 15 days except for Legitimate Reasons as defined under the Standard Terms and Conditions. In this case, incident report cannot be submitted until the expiry of the 15-day withdrawal-halt period. No policy could be purchased after withdrawal halt by the exchange and if any such policy purchased after withdrawal halt will be deemed invalid. Any policies that are expired prior to the end of the 15-day withdrawal-halt period will not be eligible for payout"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"50","ceiling":"1600","reportingPeriod":86400,"cooldownPeriod":300,"claimPeriod":86400,"minStakeToReport":"50000000000000000000000","stakeWithFee":"15500000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500","links":{"website":"https://atlasswap.com/"},"resolutionSources":[{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmThidT7SXTdi6a4LkszZfWgAhVPc8x7ub6fbsMuL3S23R', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","coverName":"Prime dApps","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-PRI","requiresWhitelist":false,"supportsProducts":true,"leverageFactor":"6","tags":["nft","exchange","dex","swap","fork","stablecoin","lending","flashloan","borrowing","interest","loan","staking","yield","insurance","payment"],"about":"","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"floor":"50","ceiling":"800","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"10000000000000000000000","stakeWithFee":"30000000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500"}' UNION ALL
SELECT 'QmTwXYSsMjEZFCCcsJx7JS89Rs4gezQvgqEhf7rb7tm3z1', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x31696e63682d7632000000000000000000000000000000000000000000000000","productName":"1inch v2","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","aggregation"],"about":"The 1inch Network unites decentralized protocols whose synergy enables the most lucrative, fastest, and protected operations in the DeFi space by offering access to hundreds of liquidity sources across multiple chains. The 1inch Network was launched at the ETHGlobal New York hackathon in May 2019 with the release of its Aggregation Protocol v1. Since then, 1inch Network has developed additional DeFi tools such as the Liquidity Protocol, Limit Order Protocol, P2P transactions, and 1inch Mobile Wallet.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the 1inch V2 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://1inch.io/","twitter":"https://twitter.com/1inch","blog":"https://blog.1inch.io/","documentation":"https://docs.1inch.io/","reddit":"https://www.reddit.com/r/1inch/","discord":"https://discord.com/invite/1inch","youtube":"https://www.youtube.com/channel/UCk0nvK4bHpteQXZKv7lkq5w","telegram":"https://t.me/OneInchNetwork","github":"https://github.com/1inch"},"resolutionSources":[{"text":"1inch Blog","uri":"https://blog.1inch.io/"},{"text":"1inch Twitter","uri":"https://twitter.com/1inch"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmUsRg5QKE7sAtJwchZdiVKXpaXAv98xpwsNxPbvhUYQJf', '{"coverKey":"0x6f6b780000000000000000000000000000000000000000000000000000000000","coverName":"OKX Exchange Custody","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-OKX","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","okx","okb","okex"],"about":"Founded in 2017, OKX is a rebrand from the former OKEX exchange, it is one of the leading global crypto exchanges, particularly with strong derivatives trading volume. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users outside of the US and US territories (not any other apps listed on the platform)","To be eligible for a claim, policyholders must hold at least 100 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy"]}},{"parameter":"Cover Parameters","type":"parameter","text":"One of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["The designated exchange platform suffers a security breach of its hot or cold wallets where the minimum total loss of  funds exceeds $50M","Or the exchange halts all asset withdrawals for all users for more than 15 days except for Legitimate Reasons as defined under the Standard Terms and Conditions.  In this case, incident report cannot be submitted until the expiry of the 15-day withdrawal-halt period. No policy could be purchased after withdrawal halt by the exchange and if any such policy purchased after withdrawal halt will be deemed invalid.  Any policies that are expired prior to the end of the 15-day withdrawal-halt period will not be eligible for payout"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"unordered","items":["All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"50","ceiling":"700","reportingPeriod":604800,"cooldownPeriod":86400,"claimPeriod":604800,"minStakeToReport":"50000000000000000000000","stakeWithFee":"30000000000000000000000","initialReassuranceAmount":"0","reassuranceRate":"2500","links":{"website":"https://www.okx.com/","telegram":"https://t.me/OKXOfficial_English","twitter":"https://twitter.com/okx","blog":"https://www.okx.com/academy/en/category/Press-en","instagram":"https://www.instagram.com/okx_official/","youtube":"https://www.youtube.com/channel/UCZEp9q993DknUPrhIL51lcw","discord":"https://discord.com/invite/e6EyvM5QwM","linkedin":"https://www.linkedin.com/company/okxofficial/"},"resolutionSources":[{"text":"OKX Twitter","uri":"https://twitter.com/okx"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmVSGRGf2xrCN9U76G8S7BN9bhZbi74wX9gkDnujCixasS', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x6c69646f2d763100000000000000000000000000000000000000000000000000","productName":"Lido v1","requiresWhitelist":false,"efficiency":"9000","tags":["staking","yield"],"about":"Lido is the leading liquid staking solution - providing a simple and secure way to earn interest on your digital assets. By staking with Lido your assets remain liquid and can be used across a range of DeFi applications, earning extra yield.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://lido.fi/","documentation":"https://docs.lido.fi/","telegram":"https://t.me/lidofinance","twitter":"https://twitter.com/lidofinance","discord":"https://discord.com/invite/lido","github":"https://github.com/lidofinance","reddit":"https://www.reddit.com/r/LidoFinance/","blog":"https://blog.lido.fi/"},"resolutionSources":[{"text":"Lido Twitter","uri":"https://twitter.com/lidofinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmVUkJHNaFbHnULoVGscDAiW7P5WhLfRSXuxCxB73537Kf', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x62616c616e6365722d7632000000000000000000000000000000000000000000","productName":"Balancer v2","requiresWhitelist":false,"efficiency":"7500","tags":["exchange","swap","dex","launchpad","flashloan"],"about":"Balancer is an automated market maker (AMM ) that allows LPs to deposit more types of tokens to liquidity pools instead of a pair, also gives more flexibility for LP creator to customize trading fees or create private pools. With the launch of V2 (since May 2021) the single Vault architecture separates the token accounting and management from the Pool logic, hence assets can shift around without emitting an ERC20 transfer event on-chain improving gas efficiency for traders.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Balancer v2 deployed on the Arbitrum and Ethereum blockchains.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions."]}}],"links":{"website":"https://balancer.fi/","twitter":"https://twitter.com/BalancerLabs","discord":"https://discord.balancer.fi/","blog":"https://medium.com/balancer-protocol","linkedin":"https://www.linkedin.com/company/balancer-labs/","youtube":"https://www.youtube.com/channel/UCBRHug6Hu3nmbxwVMt8x_Ow","github":"https://github.com/balancer-labs/"},"resolutionSources":[{"text":"Balancer Blog","uri":"https://medium.com/balancer-protocol"},{"text":"Balancer Twitter","uri":"https://twitter.com/BalancerLabs"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmVVwLMVUvTYTCkLXWrGSYz2eegpcjfcfeD9ebCHkSS84G', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x616176652d76322d6e2d76330000000000000000000000000000000000000000","productName":"Aave V4","requiresWhitelist":false,"efficiency":"9000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Aave is a decentralized non-custodial liquidity protocol where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) or undercollateralized (one-block liquidity) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum One"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the AAVE v2 and v3 protocol deployed on the Arbitrum and Ethereum blockchains.","To be eligible for a claim, policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://aave.com/","documentation":"https://docs.aave.com/","twitter":"https://twitter.com/aaveaave","github":"https://github.com/aave","discord":"https://discord.com/invite/CvKUrqM","telegram":"https://t.me/Aavesome","blog":"https://medium.com/aave"},"resolutionSources":[{"text":"Aave Twitter","uri":"https://twitter.com/aaveaave"},{"text":"Aave Blog","uri":"https://medium.com/aave"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmW1bzN7xkWX5jkoZLUskeBGdzmE7VC2v59kpXhTX22fn6', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x676e6f7369732d736166652d7631000000000000000000000000000000000000","productName":"Gnosis Safe v1","requiresWhitelist":false,"efficiency":"9500","tags":["wallet","multi-sig"],"about":"Gnosis Safe is the successor to the Gnosis Multisig. Multi-signature. Multi-signature allows you define an access/control-scheme through multiple signers that need to confirm transactions. DeFi integrations. Easily interact with popular decentralized finance protocols to invest, trade and manage digital assets.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to all of the instances of Gnosis Safe v1 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gnosis-safe.io/","twitter":"https://twitter.com/gnosisSafe","discord":"https://discord.com/invite/AjG7AQD9Qn","github":"https://github.com/safe-global","documentation":"https://docs.gnosis-safe.io/"},"resolutionSources":[{"text":"Gnosis Safe Twitter","uri":"https://twitter.com/gnosisSafe"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmWBQG45NLNiWoQYFA2RYs6fF8PQiQG8E9Xd5kgHY8jReg', '{"coverKey":"0x6f6b780000000000000000000000000000000000000000000000000000000000","coverName":"OKX","projectName":null,"tokenName":"Yield Bearing USDC","tokenSymbol":"iUSDC-OKX","requiresWhitelist":false,"supportsProducts":false,"leverageFactor":"1","tags":["exchange","cex","okx","okex"],"about":"Founded in 2017, OKX is a rebrand from the former OKEX exchange, it is one of the leading global crypto exchanges,  particularly with strong derivatives trading volume. Users can trade spots, futures and derivatives via its online platform and mobile app. Centralized exchanges operate order books and take custody of users assets to facilitate trading, it also facilitates lending and borrowing as well as other services such as staking to its user base.","parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the core exchange platform serving global users (outside of US and US territories).","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $50 million.","OKX suffers a security breach of its hot or cold wallets where the user funds are permanently and irrecoverably stolen from OKX.","The loss must arise from security incidents of the crypto storage systems"]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Losses arisen due to issues with fork, merge,  any other changes of relevant underlying blockchains","Losses resulting from Key man risk where a single person controls access to the user funds at the custodian, is not covered.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions"]}}],"blockchains":null,"floor":"400","ceiling":"1600","reportingPeriod":300,"cooldownPeriod":300,"claimPeriod":300,"minStakeToReport":"2000000000000000000000","stakeWithFee":"27000000000000000000000","initialReassuranceAmount":"50000000000","reassuranceRate":"2500","links":{"website":"https://www.okx.com/","telegram":"https://t.me/OKXOfficial_English","twitter":"https://twitter.com/okx","blog":"https://www.okx.com/academy/en/category/Press-en","instagram":"https://www.instagram.com/okx_official/","youtube":"https://www.youtube.com/channel/UCZEp9q993DknUPrhIL51lcw","discord":"https://discord.com/invite/e6EyvM5QwM","linkedin":"https://www.linkedin.com/company/okxofficial/"},"resolutionSources":[{"text":"OKX Twitter","uri":"https://twitter.com/okx"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmWC9UhJVSX3C5xCVNJSMqev3cSTB4pyeqMS3BLkVsRZQn', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x6f6e65696e63682d763200000000000000000000000000000000000000000000","productName":"1inch v2","requiresWhitelist":false,"efficiency":"4000","tags":["exchange","dex","swap","aggregation"],"about":"The 1inch Network unites decentralized protocols whose synergy enables the most lucrative, fastest, and protected operations in the DeFi space by offering access to hundreds of liquidity sources across multiple chains. The 1inch Network was launched at the ETHGlobal New York hackathon in May 2019 with the release of its Aggregation Protocol v1. Since then, 1inch Network has developed additional DeFi tools such as the Liquidity Protocol, Limit Order Protocol, P2P transactions, and 1inch Mobile Wallet.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the 1inch v2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://1inch.io/","twitter":"https://twitter.com/1inch","blog":"https://blog.1inch.io/","documentation":"https://docs.1inch.io/","reddit":"https://www.reddit.com/r/1inch/","discord":"https://discord.com/invite/1inch","youtube":"https://www.youtube.com/channel/UCk0nvK4bHpteQXZKv7lkq5w","telegram":"https://t.me/OneInchNetwork","github":"https://github.com/1inch"},"resolutionSources":[{"text":"1inch Blog","uri":"https://blog.1inch.io/"},{"text":"1inch Twitter","uri":"https://twitter.com/1inch"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmWcy6Vhi85gDXBEDzSSQMhV8md1T6e9tEZnxemgdBf26B', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x616176652d763300000000000000000000000000000000000000000000000000","productName":"Aave v3","requiresWhitelist":false,"efficiency":"9000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Aave is a decentralized non-custodial liquidity protocol where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) or undercollateralized (one-block liquidity) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the AAVE v3 protocol deployed on the Arbitrum and Ethereum blockchain (if available).","To be eligible for a claim, policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Ethereum (if available)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://aave.com/","documentation":"https://docs.aave.com/","twitter":"https://twitter.com/aaveaave","github":"https://github.com/aave","discord":"https://discord.com/invite/CvKUrqM","telegram":"https://t.me/Aavesome","blog":"https://medium.com/aave"},"resolutionSources":[{"text":"Aave Twitter","uri":"https://twitter.com/aaveaave"},{"text":"Aave Blog","uri":"https://medium.com/aave"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmWJjgxNEJ1Ue3mHqGeiaHn91EDJW4JBaKsvFhdCHHsWBK', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x636f6d706f756e642d7632000000000000000000000000000000000000000000","productName":"Compound v2","requiresWhitelist":false,"efficiency":"9000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Compound  is a decentralized non-custodial liquidity protocol on Ethereum where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Compound V2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://compound.finance/","discord":"https://discord.com/invite/fq6JSPkpJn","github":"https://github.com/compound-finance/compound-protocol","blog":"https://medium.com/compound-finance","twitter":"https://twitter.com/compoundfinance","app":"https://app.compound.finance/"},"resolutionSources":[{"text":"Compound Twitter","uri":"https://twitter.com/compoundfinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmWRdPnZKhxhPfd5rqK4FwvbQ7uCd1q6JWuk9v4h9WTrFX', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x62616c616e6365722d7632000000000000000000000000000000000000000000","productName":"Balancer v2","requiresWhitelist":false,"efficiency":"7500","tags":["exchange","swap","dex","launchpad","flashloan"],"about":"Balancer is an automated market maker (AMM ) that allows LPs to deposit more types of tokens to liquidity pools instead of a pair, also gives more flexibility for LP creator to customize trading fees or create private pools. With the launch of V2 (since May 2021) the single Vault architecture separates the token accounting and management from the Pool logic, hence assets can shift around without emitting an ERC20 transfer event on-chain improving gas efficiency for traders.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Balancer v2 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and exclusions."]}}],"links":{"website":"https://balancer.fi/","twitter":"https://twitter.com/BalancerLabs","discord":"https://discord.balancer.fi/","blog":"https://medium.com/balancer-protocol","linkedin":"https://www.linkedin.com/company/balancer-labs/","youtube":"https://www.youtube.com/channel/UCBRHug6Hu3nmbxwVMt8x_Ow","github":"https://github.com/balancer-labs/"},"resolutionSources":[{"text":"Balancer Blog","uri":"https://medium.com/balancer-protocol"},{"text":"Balancer Twitter","uri":"https://twitter.com/BalancerLabs"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmX5ssdLHSpsQwu3YVGbS1CTUZG2XVgTXxyKVC2Fcyf8Rr', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x676d782d76320000000000000000000000000000000000000000000000000000","productName":"GMX v2","requiresWhitelist":false,"efficiency":"6000","tags":["perpetual","trade","dex","leverage","swap"],"about":"GMX is a permissionless, decentralized spot and perpetual swap exchange on the Arbitrum network.","blockchains":[{"chainId":42161,"name":"Arbitrum One"},{"chainId":43114,"name":"Avalanche C-Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the GMX version 1 deployed on the Arbitrum and Avalanche blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Arbitrum and Avalanche."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://gmx.io","app":"https://app.gmx.io","twitter":"https://twitter.com/GMX_IO","medium":"https://medium.com/@gmx.io","github":"https://github.com/gmx-io","telegram":"https://t.me/GMX_IO","discord":"https://discord.com/invite/ymN38YefH9"},"resolutionSources":[{"text":"GMX Blog","uri":"https://medium.com/@gmx.io"},{"text":"GMX Twitter","uri":"https://twitter.com/GMX_IO"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmXFX5NCii3nwPtVw5Ax7q73JeTS5oZnpqGPCnz33TGC2Y', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x6d616b65722d7631000000000000000000000000000000000000000000000000","productName":"Maker DAO MCD v1","requiresWhitelist":false,"efficiency":"9000","tags":["lending","borrowing","stablecoin","yield","staking","payment"],"about":"MakerDAO is a decentralized organization dedicated to bringing stability to the cryptocurrency economy. The Maker Protocol employs a two-token system. The first being, Dai, a collateral-backed stablecoin that offers stability. The Maker Foundation and the MakerDAO community believe that a decentralized stablecoin is required to have any business or individual realize the advantages of digital money. Second, there is MKR, a governance token that is used by stakeholders to maintain the system and manage Dai. MKR token holders are the decision-makers of the Maker Protocol, supported by the larger public community and various other external parties.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to Version 1 of the Maker DAO (Multi-Collateral DAI) smart contracts deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://makerdao.com/","twitter":"https://twitter.com/MakerDAO","blog":"https://medium.com/@MakerDAO","documentation":"https://docs.makerdao.com/","reddit":"https://www.reddit.com/r/MakerDAO/","telegram":"https://t.me/makerdaoOfficial","discord":"https://discord.com/invite/RBRumCpEDH","youtube":"https://www.youtube.com/MakerDAO"},"resolutionSources":[{"text":"MakerDAO Blog","uri":"https://medium.com/@MakerDAO"},{"text":"MakerDAO Twitter","uri":"https://twitter.com/MakerDAO"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmXfy1Az9Y2FKXKDVkHgc3ThfLLQUatP5qQGbeqgQrfZ6B', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x647964782d763300000000000000000000000000000000000000000000000000","productName":"DYDX v3","requiresWhitelist":false,"efficiency":"3000","tags":["exchange","dex","swap","derivatives","leverage"],"about":"dYdX is a crypto derivatives exchange that leverages a hybrid model utilizing non-custodial, on-chain settlement and an off-chain order books matching engine.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the dYdX V3 protocol deployed on the StarkEx layer 2 blockchain running on top of Ethereum.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: StarkEx layer 2 blockchain running on top of Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://dydx.exchange","app":"https://trade.dydx.exchange/","testnet":"https://trade.stage.dydx.exchange/","docs":"https://docs.dydx.exchange/","github":"https://github.com/dydxprotocol/","blog":"https://dydx.exchange/blog","support":"https://help.dydx.exchange/en/","twitter":"https://twitter.com/dydx","discord":"https://discord.gg/Tuze6tY","youtube":"https://www.youtube.com/c/dYdXprotocol","reddit":"https://www.reddit.com/r/dydxprotocol","linkedin":"https://linkedin.com/company/dydx"},"resolutionSources":[{"text":"DYDX Blog","uri":"https://dydx.exchange/blog"},{"text":"DYDX Twitter","uri":"https://twitter.com/dydx"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmXPkuacaiXrh9aUdiMybBmTjJbZjSEgqq7CnetQuTywVG', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x73757368692d7632000000000000000000000000000000000000000000000000","productName":"Sushi v2","requiresWhitelist":false,"efficiency":"7000","tags":["exchange","dex","swap","fork","flashloan"],"about":"Sushi is a community-driven organization built to solve what might be called the “liquidity problem.” One could define this problem as the inability of disparate forms of liquidity to connect with markets in a decentralized way, and vice versa. While other solutions provide incrementally progressive advances toward solving the problem of liquidity, Sushi’s progress is intended to create a broader range of network effects. Rather than limiting itself to a single solution, Sushi intertwines many decentralized markets and instruments.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the SushiSwap v2 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://sushi.com/","twitter":"https://twitter.com/sushiswap","blog":"https://sushichef.medium.com/","github":"https://github.com/sushiswap","documentation":"https://dev.sushi.com/"},"resolutionSources":[{"text":"Sushi Blog","uri":"https://sushichef.medium.com"},{"text":"Sushi Twitter","uri":"https://twitter.com/sushiswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmYHbEJEQek15WwiC283ihf1RCpcfTQeqGXHkTstWA7o3y', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x616c706163612d76310000000000000000000000000000000000000000000000","productName":"Alpaca Finance v1","requiresWhitelist":false,"efficiency":"7000","tags":["lending","farming","loan","leverage","yield"],"about":"Alpaca Finance is a lending protocol allowing leveraged yield farming on BNB Smart Chain. It offers borrowers undercollateralized loans for leveraged yield farming positions. As a result, it amplifies the liquidity layer of integrated exchanges, improving their capital efficiency by connecting LP borrowers and lenders.","blockchains":[{"chainId":56,"name":"BNB Chain"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Alpaca Finance v1 protocol deployed on the BNB Smart Chain.","To be eligible for a claim, the policyholder must hold at least 499 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: BNB Smart Chain (BSC) (Previously Binance Smart Chain)."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://www.alpacafinance.org/","docs":"https://docs.alpacafinance.org/","app":"https://app.alpacafinance.org/","twitter":"https://twitter.com/AlpacaFinance","telegram":"https://t.me/alpacafinance","discord":"https://discord.com/invite/alpacafinance","blog":"https://medium.com/alpaca-finance","youtube":"https://www.youtube.com/channel/UC8xBPBPgRD-xe_ZfyOwV_Dg","reddit":"https://www.reddit.com/r/AlpacaFinanceOfficial/","github":"https://github.com/alpaca-finance/bsc-alpaca-contract"},"resolutionSources":[{"text":"Alpaca Finance Twitter","uri":"https://twitter.com/AlpacaFinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmYvtFvKNFM8ZhfiHGyPnWYq5rsqjcRgjJixFK2w1RytNt', '{"coverKey":"0x7072696d65000000000000000000000000000000000000000000000000000000","productKey":"0x73796e7468657469782d76320000000000000000000000000000000000000000","productName":"Synthetix v2","requiresWhitelist":false,"efficiency":"8000","tags":["derivative","staking","yield"],"about":"Synthetix is a new financial primitive enabling the creation of synthetic assets, offering unique derivatives and exposure to real-world assets on the blockchain.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Synthetix Protocol (v2) deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://synthetix.io/","discord":"https://discord.com/invite/AEdUHzt","twitter":"https://twitter.com/synthetix_io","github":"https://github.com/synthetixio","blog":"https://blog.synthetix.io/","dao":"https://synthetix.io/governance","documentation":"https://docs.synthetix.io/"},"resolutionSources":[{"text":"Synthetix Twitter","uri":"https://twitter.com/synthetix_io"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmYyjCcdjmRAB21EjAVPBWe2GAuNWGeMa9M7L23DzQ3f3y', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x6f6e65696e63682d763300000000000000000000000000000000000000000000","productName":"1inch v3","requiresWhitelist":false,"efficiency":"4000","tags":["exchange","dex","swap","aggregation"],"about":"The 1inch Network unites decentralized protocols whose synergy enables the most lucrative, fastest, and protected operations in the DeFi space by offering access to hundreds of liquidity sources across multiple chains. The 1inch Network was launched at the ETHGlobal New York hackathon in May 2019 with the release of its Aggregation Protocol v1. Since then, 1inch Network has developed additional DeFi tools such as the Liquidity Protocol, Limit Order Protocol, P2P transactions, and 1inch Mobile Wallet.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":56,"name":"BNB Smart Chain Mainnet"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the 1inch v3 protocol deployed on the Ethereum and BNB blockchains.","To be eligible for a claim, policyholder must hold at least 299 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and BNB."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://1inch.io/","twitter":"https://twitter.com/1inch","blog":"https://blog.1inch.io/","documentation":"https://docs.1inch.io/","reddit":"https://www.reddit.com/r/1inch/","discord":"https://discord.com/invite/1inch","youtube":"https://www.youtube.com/channel/UCk0nvK4bHpteQXZKv7lkq5w","telegram":"https://t.me/OneInchNetwork","github":"https://github.com/1inch"},"resolutionSources":[{"text":"1inch Blog","uri":"https://blog.1inch.io/"},{"text":"1inch Twitter","uri":"https://twitter.com/1inch"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmYzbk1mWWodnUtCZ8uUwMuLosDXuoMjKpKBECf9D8UF4t', '{"coverKey":"0x6465666900000000000000000000000000000000000000000000000000000000","productKey":"0x6b79626572737761702d76310000000000000000000000000000000000000000","productName":"Kyberswap v1","requiresWhitelist":false,"efficiency":"5000","tags":["exchange","dex","swap"],"about":"Kyber Network is a multi-chain crypto trading and liquidity hub that connects liquidity from different sources to enable trades at the best rates .","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Kyberswap v1 deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 10 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://kyber.network/","documentation":"https://docs.kyberswap.com/introduction","github":"https://github.com/KyberNetwork","dao":"https://kyber.org/vote","forum":"https://gov.kyber.org/","discord":"https://discord.com/invite/NB3vc8J9uv","telegram":"https://t.me/kybernetwork","twitter":"https://twitter.com/kybernetwork/","youtube":"https://www.youtube.com/channel/UCQ-8mEqsKM3x9dTT6rrqgJw","blog":"https://blog.kyber.network/"},"resolutionSources":[{"text":"Kyber Twitter","uri":"https://twitter.com/kybernetwork"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmZ9cjxk8ye3qui8JEgPjxDaFF48CbxNswtCfBMTLKnaj6', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x636f6d706f756e642d7632000000000000000000000000000000000000000000","productName":"Compound Finance","requiresWhitelist":false,"efficiency":"7000","tags":["borrowing","loan","interest","interest-bearing","lending","yield","staking"],"about":"Compound  is a decentralized non-custodial liquidity protocol on Ethereum where users can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an overcollateralized (perpetually) fashion.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Compound V2 protocol deployed on the Ethereum blockchain.","To be eligible for a claim, policyholder must hold at least 99 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://compound.finance/","discord":"https://discord.com/invite/fq6JSPkpJn","github":"https://github.com/compound-finance/compound-protocol","blog":"https://medium.com/compound-finance","twitter":"https://twitter.com/compoundfinance","app":"https://app.compound.finance/"},"resolutionSources":[{"text":"Compound Twitter","uri":"https://twitter.com/compoundfinance"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}' UNION ALL
SELECT 'QmZXDq4Cn9ZnEGhm68UN7HLpuxduesH5cx6QrhWuRccJLY', '{"coverKey":"0x706f70756c61722d646566692d61707073000000000000000000000000000000","productKey":"0x756e69737761702d763300000000000000000000000000000000000000000000","productName":"Uniswap v3","requiresWhitelist":false,"efficiency":"9000","tags":["exchange","dex","swap","nft"],"about":"The Uniswap protocol is a peer-to-peer system designed for exchanging cryptocurrencies (ERC-20 Tokens) on the Ethereum blockchain. The protocol is implemented as a set of persistent, non-upgradable smart contracts; designed to prioritize censorship resistance, security, self-custody, and to function without any trusted intermediaries who may selectively restrict access.","blockchains":[{"chainId":1,"name":"Main Ethereum Network"},{"chainId":42161,"name":"Arbitrum"}],"parameters":[{"parameter":"Cover Policy Conditions","type":"condition","text":"This cover is not a contract of insurance. Cover is provided on a parametric basis and the decision as to whether or not an incident is validated is determined by Neptune Mutual’s incident reporting and resolution process whereby the result is based on the number of NPM tokens or vouchers staked by the community in the resolution process; this incident reporting and validation process is community driven, but in exceptional circumstances can be overridden by the Neptune Mutual Association in order to protect against certain types of on-chain consensus attacks.","list":{"type":"unordered","items":["This policy relates exclusively to the Uniswap V3 deployed on the Ethereum and Arbitrum blockchain.","To be eligible for a claim, policyholder must hold at least 49 NPM tokens in the wallet used for the policy transaction for the full duration of the cover policy."]}},{"parameter":"Cover Parameters","type":"parameter","text":"All of the following parameters must be applicable for the policy to be validated:","list":{"type":"ordered","items":["Minimum total loss of user funds from the reported incident should exceed $5 million.","The designated protocol suffers a hack of user funds in which the user funds are permanently and irrecoverably stolen from the protocol.","The loss arises from a smart contract vulnerability.","The loss must arise from one of the following blockchains: Ethereum and Arbitrum."]}},{"parameter":"Cover Exclusions","type":"exclusion","list":{"type":"ordered","items":["Incident on any blockchain that is not supported by this cover.","Frontend, hosting, server or network infrastructure, database, DNS server, CI/CD, and/or supply-chain attacks.","All exclusions present in the standard terms and conditions."]}}],"links":{"website":"https://uniswap.org/","app":"https://app.uniswap.org/#/swap?use=V2","twitter":"https://twitter.com/Uniswap","blog":"https://uniswap.org/blog","discord":"https://discord.com/invite/FCfyBSbCU5","github":"https://github.com/Uniswap","docs":"https://docs.uniswap.org/protocol/V2/introduction"},"resolutionSources":[{"text":"Uniswap Blog","uri":"https://uniswap.org/blog"},{"text":"Uniswap Twitter","uri":"https://twitter.com/Uniswap"},{"text":"Neptune Mutual Twitter","uri":"https://twitter.com/neptunemutual"}]}';

DROP VIEW IF EXISTS config_product_view CASCADE;

CREATE VIEW config_product_view
AS
SELECT
  1                                        AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('aave-v3')             AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('bancor-v3')           AS product_key,
  5000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('compound-v2')         AS product_key,
  7000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('convex-v1')           AS product_key,
  5000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('dydx-v3')             AS product_key,
  3000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('gmx-v1')              AS product_key,
  6000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('oneinch-v2')          AS product_key,
  4000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('sushiswap-v1')        AS product_key,
  5000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('uniswap-v3')          AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('aave-v2')             AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('balancer-v2')         AS product_key,
  7500                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('curve-v2')            AS product_key,
  7000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('gnosis-safe-v1')      AS product_key,
  9500                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('maker-v1')            AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('synthetix-v2')        AS product_key,
  8000                                     AS capital_efficiency
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('uniswap-v2')          AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  56                                       AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('alpaca-v1')           AS product_key,
  7000                                     AS capital_efficiency
UNION ALL
SELECT
  56                                       AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('dodo-v2')             AS product_key,
  7000                                     AS capital_efficiency
UNION ALL
SELECT
  56                                       AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('oneinch-v2')          AS product_key,
  8000                                     AS capital_efficiency
UNION ALL
SELECT
  56                                       AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('pancakeswap-v2')      AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  56                                       AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('uniswap-v3')          AS product_key,
  9500                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('aave-v3')             AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('bancor-v3')           AS product_key,
  5000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('compound-v2')         AS product_key,
  7000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('compound-v3')         AS product_key,
  7000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('convex-v1')           AS product_key,
  5000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('dydx-v3')             AS product_key,
  3000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('gmx-v1')              AS product_key,
  6000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('gmx-v2')              AS product_key,
  6000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('oneinch-v2')          AS product_key,
  4000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('oneinch-v3')          AS product_key,
  4000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('sushiswap-v1')        AS product_key,
  5000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('sushiswap-v3')        AS product_key,
  5000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  string_to_bytes32('uniswap-v3')          AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('aave-v2')             AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('aave-v2-and-v3')      AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('balancer-v2')         AS product_key,
  7500                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('curve-v2')            AS product_key,
  7000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('gnosis-safe-v1')      AS product_key,
  9500                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('maker-v1')            AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('safe-v1')             AS product_key,
  9500                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('synthetix-v2')        AS product_key,
  8000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('uniswap-v2')          AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('uniswap-v2-and-v3')   AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('defi')                AS cover_key,
  string_to_bytes32('1inch-v2')            AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('defi')                AS cover_key,
  string_to_bytes32('compound-v2')         AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('defi')                AS cover_key,
  string_to_bytes32('convex-v1')           AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('defi')                AS cover_key,
  string_to_bytes32('kyberswap-v1')        AS product_key,
  5000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('defi')                AS cover_key,
  string_to_bytes32('lido-v1')             AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('defi')                AS cover_key,
  string_to_bytes32('nexus-mutual-v1')     AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('defi')                AS cover_key,
  string_to_bytes32('rpl-v1')              AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('defi')                AS cover_key,
  string_to_bytes32('sushi-v2')            AS product_key,
  7000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('defi')                AS cover_key,
  string_to_bytes32('uniswap-v3')          AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('aave-v2')             AS product_key,
  10000                                    AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('balancer-v2')         AS product_key,
  7500                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('curve-v2')            AS product_key,
  7000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('gnosis-safe-v1')      AS product_key,
  7000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('maker-v1')            AS product_key,
  9000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('synthetix-v2')        AS product_key,
  7000                                     AS capital_efficiency
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  string_to_bytes32('uniswap-v2')          AS product_key,
  9000                                     AS capital_efficiency;

DROP MATERIALIZED VIEW IF EXISTS reassurance_transaction_view CASCADE;

CREATE MATERIALIZED VIEW reassurance_transaction_view
AS
SELECT
  'Reassurance Added' AS description,  
  reassurance.reassurance_added.chain_id,
  reassurance.reassurance_added.cover_key,
  SUM(get_stablecoin_value(reassurance.reassurance_added.chain_id, reassurance.reassurance_added.amount)) AS total
FROM reassurance.reassurance_added
GROUP BY 
  reassurance.reassurance_added.chain_id,
  reassurance.reassurance_added.cover_key
UNION ALL
SELECT
  'Pool Capitalized' AS description,  
  reassurance.pool_capitalized.chain_id,
  reassurance.pool_capitalized.cover_key,
  SUM(get_stablecoin_value(reassurance.pool_capitalized.chain_id, reassurance.pool_capitalized.amount)) * -1
FROM reassurance.pool_capitalized
GROUP BY 
  reassurance.pool_capitalized.chain_id,
  reassurance.pool_capitalized.cover_key;

CREATE UNIQUE INDEX description_chain_id_cover_key_reassurance_transaction_view
ON reassurance_transaction_view(description, chain_id, cover_key);

CREATE INDEX chain_id_cover_key_reassurance_transaction_view_inx
ON reassurance_transaction_view(chain_id, cover_key);


DROP FUNCTION IF EXISTS core.refresh_reassurance_transaction_view_trigger() CASCADE;

CREATE FUNCTION core.refresh_reassurance_transaction_view_trigger()
RETURNS trigger
AS
$$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY reassurance_transaction_view;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER refresh_reassurance_transaction_view_trigger
BEFORE INSERT OR UPDATE ON core.transactions
FOR EACH STATEMENT
EXECUTE FUNCTION core.refresh_reassurance_transaction_view_trigger();
DROP MATERIALIZED VIEW IF EXISTS stablecoin_transactions_view CASCADE;

CREATE MATERIALIZED VIEW stablecoin_transactions_view
AS
WITH transactions
AS
(
  SELECT
    'Liquidity Added' AS description,
    vault.pods_issued.chain_id,
    factory.vault_deployed.cover_key,
    SUM(get_stablecoin_value(vault.pods_issued.chain_id, vault.pods_issued.liquidity_added)) as total
  FROM vault.pods_issued
  INNER JOIN factory.vault_deployed
  ON factory.vault_deployed.vault = vault.pods_issued.address
  AND factory.vault_deployed.chain_id = vault.pods_issued.chain_id
  GROUP BY vault.pods_issued.chain_id, factory.vault_deployed.cover_key

  UNION ALL

  SELECT
    'Liquidity Removed' AS description,
    vault.pods_redeemed.chain_id,
    factory.vault_deployed.cover_key,
    SUM(get_stablecoin_value(vault.pods_redeemed.chain_id, vault.pods_redeemed.liquidity_released)) as total_liquidity
  FROM vault.pods_redeemed
  INNER JOIN factory.vault_deployed
  ON factory.vault_deployed.vault = vault.pods_redeemed.address
  AND factory.vault_deployed.chain_id = vault.pods_redeemed.chain_id
  GROUP BY vault.pods_redeemed.chain_id, factory.vault_deployed.cover_key

  UNION ALL

  SELECT
    'Fee Earned' AS description,
    chain_id,
    cover_key,
    SUM(get_stablecoin_value(chain_id, fee - platform_fee)) AS total_fee
  FROM policy.cover_purchased
  GROUP BY chain_id, cover_key
)
SELECT description, chain_id, cover_key, total
FROM transactions;


CREATE UNIQUE INDEX description_chain_id_cover_key_stablecoin_transactions_view
ON stablecoin_transactions_view(description, chain_id, cover_key);

CREATE INDEX chain_id_cover_key_stablecoin_transactions_view_inx
ON stablecoin_transactions_view(chain_id, cover_key);


DROP FUNCTION IF EXISTS core.refresh_stablecoin_transactions_view_trigger() CASCADE;

CREATE FUNCTION core.refresh_stablecoin_transactions_view_trigger()
RETURNS trigger
AS
$$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY stablecoin_transactions_view;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER refresh_stablecoin_transactions_view_trigger
BEFORE INSERT OR UPDATE ON core.transactions
FOR EACH STATEMENT
EXECUTE FUNCTION core.refresh_stablecoin_transactions_view_trigger();


DROP VIEW IF EXISTS incident_stakes_view CASCADE;

CREATE VIEW incident_stakes_view
AS
SELECT
  'Attestation' AS activity,
  consensus.attested.chain_id,
  consensus.attested.cover_key,
  consensus.attested.product_key,
  consensus.attested.incident_date,  
  consensus.attested.witness,
  consensus.attested.stake
FROM consensus.attested
UNION ALL
SELECT
  'Refutation' AS activity,
  consensus.refuted.chain_id,
  consensus.refuted.cover_key,
  consensus.refuted.product_key,
  consensus.refuted.incident_date,  
  consensus.refuted.witness,
  consensus.refuted.stake
FROM consensus.refuted;



DROP VIEW IF EXISTS commitment_by_chain_view;

CREATE VIEW commitment_by_chain_view
AS
SELECT chain_id, SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS commitment
FROM policy.cover_purchased
WHERE expires_on > EXTRACT(epoch FROM NOW() AT TIME ZONE 'UTC')
GROUP BY chain_id;


DROP VIEW IF EXISTS cover_reassurance_view;

CREATE VIEW cover_reassurance_view
AS
SELECT chain_id, cover_key, SUM(total) AS reassurance
FROM reassurance_transaction_view
GROUP BY chain_id, cover_key;


DROP VIEW IF EXISTS cx_token_deployed_view;
 
CREATE VIEW cx_token_deployed_view
AS
SELECT
  factory.cx_token_deployed.chain_id,
  factory.cx_token_deployed.cover_key,
  factory.cx_token_deployed.product_key,
  factory.cx_token_deployed.token_name,
  factory.cx_token_deployed.cx_token,
  factory.cx_token_deployed.expiry_date
FROM factory.cx_token_deployed;


DROP VIEW IF EXISTS fee_earned_by_chain_view;

CREATE VIEW fee_earned_by_chain_view
AS
SELECT
  chain_id,
  SUM(get_stablecoin_value(chain_id, fee)) AS total_fee
FROM policy.cover_purchased
GROUP BY chain_id;


DROP VIEW IF EXISTS gauge_pool_lifecycle_view;

CREATE VIEW gauge_pool_lifecycle_view
AS
SELECT
  add_or_edit.id,
  add_or_edit.block_number,
  add_or_edit.chain_id,
  CASE
    WHEN get_gauge_pool_last_added_block_number(add_or_edit.chain_id, add_or_edit.key) != add_or_edit.block_number::numeric
    THEN 'edit'
    ELSE 'add'
  END AS action,
  add_or_edit.key
FROM ve.liquidity_gauge_pool_set AS add_or_edit
UNION ALL
SELECT
  ve.gauge_controller_registry_pool_deactivated.id,
  ve.gauge_controller_registry_pool_deactivated.block_number,
  ve.gauge_controller_registry_pool_deactivated.chain_id,
  'deactivate' AS action,
  ve.gauge_controller_registry_pool_deactivated.key
FROM ve.gauge_controller_registry_pool_deactivated
UNION ALL
SELECT
  ve.gauge_controller_registry_pool_activated.id,
  ve.gauge_controller_registry_pool_activated.block_number,
  ve.gauge_controller_registry_pool_activated.chain_id,
  'activate' AS action,
  ve.gauge_controller_registry_pool_activated.key
FROM ve.gauge_controller_registry_pool_activated
UNION ALL
SELECT
  ve.gauge_controller_registry_pool_deleted.id,
  ve.gauge_controller_registry_pool_deleted.block_number,
  ve.gauge_controller_registry_pool_deleted.chain_id,
  'delete' AS action,
  ve.gauge_controller_registry_pool_deleted.key
FROM ve.gauge_controller_registry_pool_deleted;
DROP VIEW IF EXISTS incident_stakes_by_camp_view CASCADE;

CREATE VIEW incident_stakes_by_camp_view
AS
SELECT incident_stakes_view.activity AS camp,
  incident_stakes_view.chain_id,
  incident_stakes_view.cover_key,
  incident_stakes_view.product_key,
  incident_stakes_view.incident_date,
  sum(get_npm_value(incident_stakes_view.stake::numeric)) AS camp_total
  FROM incident_stakes_view
GROUP BY
  incident_stakes_view.activity,
  incident_stakes_view.chain_id,
  incident_stakes_view.cover_key,
  incident_stakes_view.product_key,
  incident_stakes_view.incident_date;

DROP VIEW IF EXISTS product_commitment_view;

CREATE VIEW product_commitment_view
AS
SELECT
  chain_id,
  cover_key,
  product_key,
  get_commitment(chain_id, cover_key, product_key) AS commitment
FROM policy.cover_purchased
GROUP BY chain_id, cover_key, product_key;

 
DROP VIEW IF EXISTS total_coverage_by_chain_view;

CREATE VIEW total_coverage_by_chain_view
AS
SELECT chain_id, SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS total_coverage
FROM policy.cover_purchased
GROUP BY chain_id;


DROP VIEW IF EXISTS total_fee_earned_view;

CREATE VIEW total_fee_earned_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Fee Earned';


DROP VIEW IF EXISTS total_liquidity_added_view;

CREATE VIEW total_liquidity_added_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Liquidity Added';

DROP VIEW IF EXISTS total_liquidity_removed_view;

CREATE VIEW total_liquidity_removed_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Liquidity Removed';


DROP VIEW IF EXISTS total_platform_fee_earned_view;

CREATE VIEW total_platform_fee_earned_view
AS
SELECT
  chain_id,
  cover_key,
  SUM(get_stablecoin_value(chain_id, platform_fee)) AS total_platform_fee
FROM policy.cover_purchased
GROUP BY chain_id, cover_key;


DROP VIEW IF EXISTS total_value_locked_by_chain_view;

CREATE VIEW total_value_locked_by_chain_view
AS
SELECT chain_id, sum(total) as total
FROM stablecoin_transactions_view
GROUP by chain_id;

DROP VIEW IF EXISTS total_value_locked_view;

CREATE VIEW total_value_locked_view
AS
SELECT sum(total) as total
FROM stablecoin_transactions_view;


DROP VIEW IF EXISTS vault_deployed_view;
 
CREATE VIEW vault_deployed_view
AS
SELECT
  factory.vault_deployed.chain_id,
  factory.vault_deployed.cover_key,
  factory.vault_deployed.vault
FROM factory.vault_deployed;

CREATE OR REPLACE VIEW ve.liquidity_gauge_pool_transactions
AS
SELECT
  ve.liquidity_gauge_deposited.chain_id,
  ve.liquidity_gauge_deposited.block_timestamp,
  ve.liquidity_gauge_deposited.transaction_hash,
  ve.liquidity_gauge_deposited.account,
  'Added' AS event,
  ve.liquidity_gauge_deposited.key,
  ve.liquidity_gauge_deposited.staking_token AS token,
  get_npm_value(ve.liquidity_gauge_deposited.amount) AS amount
FROM ve.liquidity_gauge_deposited
UNION ALL
SELECT
  ve.liquidity_gauge_withdrawn.chain_id,
  ve.liquidity_gauge_withdrawn.block_timestamp,
  ve.liquidity_gauge_withdrawn.transaction_hash,
  ve.liquidity_gauge_withdrawn.account,
  'Removed' AS event,
  ve.liquidity_gauge_withdrawn.key,
  ve.liquidity_gauge_withdrawn.staking_token AS token,
  get_npm_value(ve.liquidity_gauge_withdrawn.amount)
FROM ve.liquidity_gauge_withdrawn
UNION ALL
SELECT
  ve.liquidity_gauge_rewards_withdrawn.chain_id,
  ve.liquidity_gauge_rewards_withdrawn.block_timestamp,
  ve.liquidity_gauge_rewards_withdrawn.transaction_hash,
  ve.liquidity_gauge_rewards_withdrawn.account,
  'Get Reward' AS event,
  ve.liquidity_gauge_rewards_withdrawn.key,
  get_npm(ve.liquidity_gauge_rewards_withdrawn.chain_id) AS token,
  get_npm_value(ve.liquidity_gauge_rewards_withdrawn.rewards - ve.liquidity_gauge_rewards_withdrawn.platform_fee)
FROM ve.liquidity_gauge_rewards_withdrawn;



CREATE OR REPLACE VIEW ve_stats_view
AS
SELECT SUM(get_npm_value(amount)) AS total_vote_locked, AVG(duration_in_weeks) AS average_lock
FROM ve.vote_escrow_lock;


DROP FUNCTION IF EXISTS check_if_requires_whitelist(_chain_id uint256, _cover_key bytes32);

CREATE FUNCTION check_if_requires_whitelist(_chain_id uint256, _cover_key bytes32)
RETURNS boolean
STABLE
AS
$$
BEGIN
  RETURN requires_whitelist
  FROM cover.cover_created
  WHERE cover.cover_created.chain_id = _chain_id
  AND cover.cover_created.cover_key = _cover_key;
END
$$
LANGUAGE plpgsql;



DROP FUNCTION IF EXISTS check_if_user_whitelisted
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32,
  _account                                          address
) CASCADE;


CREATE FUNCTION check_if_user_whitelisted
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32,
  _account                                          address
)
RETURNS BOOLEAN
STABLE
AS
$$
  DECLARE _status                                   boolean;
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;

  SELECT status INTO _status
  FROM cover.cover_user_whitelist_updated
  WHERE cover.cover_user_whitelist_updated.chain_id = _chain_id
  AND cover.cover_user_whitelist_updated.cover_key = _cover_key
  AND cover.cover_user_whitelist_updated.product_key = _product_key
  AND cover.cover_user_whitelist_updated.account = _account 
  ORDER BY cover.cover_user_whitelist_updated.block_timestamp DESC
  LIMIT 1;

  RETURN COALESCE(_status, false);
END
$$
LANGUAGE plpgsql;


--SELECT * FROM check_if_user_whitelisted(84531, '0x62696e616e636500000000000000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000001');

DROP FUNCTION IF EXISTS get_active_incident_date
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
) CASCADE;

CREATE FUNCTION get_active_incident_date
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _incident_date                      uint256;
  DECLARE _finalized                          bool;
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;

  SELECT COALESCE(MAX(consensus.reported.incident_date), 0)
  INTO _incident_date
  FROM consensus.reported
  WHERE consensus.reported.chain_id = _chain_id
  AND consensus.reported.cover_key = _cover_key
  AND consensus.reported.product_key = _product_key;

  IF NOT EXISTS
  (
    SELECT * 
    FROM consensus.finalized
    WHERE consensus.finalized.chain_id = _chain_id
    AND consensus.finalized.cover_key = _cover_key
    AND consensus.finalized.product_key = _product_key
    AND consensus.finalized.incident_date = _incident_date
  ) THEN
    RETURN _incident_date;
  END IF;

  RETURN 0;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_active_incident_date(84531, string_to_bytes32('coinbase'), string_to_bytes32(''));
--SELECT * FROM get_active_incident_date(84531, string_to_bytes32('defi'), string_to_bytes32('lido-v1'));


DROP FUNCTION IF EXISTS get_product_status
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32,
  _incident_date                                    uint256
);


CREATE FUNCTION get_product_status
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32,
  _incident_date                                    uint256
)
RETURNS product_status_type
STABLE
AS
$$
  DECLARE _resolution_decision                      boolean;
  DECLARE _status                                   product_status_type = 'Normal'; 
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');  
  END IF;

  IF(COALESCE(_incident_date, 0) = 0) THEN
    RETURN _status;
  END IF;

  _status := 'IncidentHappened';

  IF EXISTS
  (
    SELECT *
    FROM get_stakes(_chain_id, _cover_key, _product_key, _incident_date)
    WHERE no > yes
  ) THEN
    _status := 'FalseReporting';  
  END IF;
  
  SELECT
    consensus.resolved.decision
  INTO
    _resolution_decision
  FROM consensus.resolved
  WHERE consensus.resolved.chain_id = _chain_id
  AND consensus.resolved.cover_key = _cover_key
  AND consensus.resolved.product_key = _product_key
  AND consensus.resolved.incident_date = _incident_date
  ORDER BY consensus.resolved.emergency DESC, consensus.resolved.block_timestamp DESC
  LIMIT 1;
  
  IF(_resolution_decision = true) THEN
    _status := 'Claimable';
  ELSIF(_resolution_decision = false) THEN
    _status := 'FalseReporting';
  END IF;
  
  RETURN _status;
END
$$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS get_active_product_status
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32
);

CREATE FUNCTION get_active_product_status
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32
)
RETURNS product_status_type
STABLE
AS
$$
  DECLARE _incident_date                            uint256;
BEGIN
  _incident_date := COALESCE(get_active_incident_date(_chain_id, _cover_key, _product_key), 0);
  RETURN get_product_status(_chain_id, _cover_key, _product_key, _incident_date);
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_active_product_status(84531, string_to_bytes32('huobi'), NULL);

DROP FUNCTION IF EXISTS get_capacity_till_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
) CASCADE;

DROP FUNCTION IF EXISTS get_total_capacity_by_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
) CASCADE;

CREATE OR REPLACE FUNCTION get_total_capacity_by_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _capacity                         uint256;
BEGIN
  WITH chains
  AS
  (
    SELECT DISTINCT core.transactions.chain_id
    FROM core.transactions
  ),
  unfiltered
  AS
  (
    SELECT chain_id, cover_key, product_key
    FROM config_product_view
    WHERE config_product_view.chain_id IN
    (
      SELECT chain_id FROM chains
    )
    UNION ALL
    SELECT  chain_id, cover_key, string_to_bytes32('') FROM config_cover_view
    WHERE config_cover_view.chain_id IN
    (
      SELECT chain_id FROM chains
    )
  ),
  products
  AS
  (
    SELECT DISTINCT chain_id, cover_key, product_key
    FROM unfiltered
    WHERE cover_key IS NOT NULL
  ),
  summary
  AS
  (
    SELECT
      chain_id,
      cover_key,
      bytes32_to_string(cover_key) AS cover,
      is_diversified(chain_id, cover_key) AS diversified,
      product_key,
      bytes32_to_string(product_key) AS product,
      get_cover_capacity_till(chain_id, cover_key, product_key, 'infinity') AS capacity,
      format_stablecoin(get_cover_capacity_till(chain_id, cover_key, product_key, 'infinity')) AS formatted_capacity
    FROM products
  )
  SELECT SUM(capacity)
  INTO _capacity
  FROM summary
  WHERE 1 = 1
  AND NOT (diversified = true AND product_key != string_to_bytes32(''))
  ORDER BY product;

  RETURN COALESCE(_capacity, 0);
END
$$
LANGUAGE plpgsql;


--SELECT get_total_capacity_by_date('infinity')
DROP FUNCTION IF EXISTS get_claim_platform_fee(_chain_id uint256) CASCADE;

CREATE FUNCTION get_claim_platform_fee(_chain_id uint256)
RETURNS uint256
STABLE
AS
$$
  DECLARE _fee                        uint256;
BEGIN
  SELECT protocol.initialized.claim_platform_fee
  INTO _fee
  FROM protocol.initialized
  WHERE protocol.initialized.chain_id = _chain_id;
  
  RETURN COALESCE(_fee, 0);
END
$$
LANGUAGE plpgsql;

--SELECT get_claim_platform_fee(42161);


DROP FUNCTION IF EXISTS get_cover_capacity_till
(
  _chain_id                                           uint256,
  _cover_key                                          bytes32,
  _till                                               TIMESTAMP WITH TIME ZONE
) CASCADE;

DROP FUNCTION IF EXISTS get_cover_capacity_till
(
  _chain_id                                           uint256,
  _cover_key                                          bytes32,
  _product_key                                        bytes32,
  _till                                               TIMESTAMP WITH TIME ZONE
) CASCADE;

CREATE FUNCTION get_cover_capacity_till
(
  _chain_id                                           uint256,
  _cover_key                                          bytes32,
  _product_key                                        bytes32,
  _till                                               TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _stablecoin_balance                         uint256;
  DECLARE _leverage                                   uint256;
  DECLARE _capital_efficiency                         numeric;
  DECLARE _average_capital_efficiency                 numeric;
  DECLARE _capacity                                   uint256;
  DECLARE _siblings                                   integer;
  DECLARE _multiplier                                 integer = 10000;
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;
  
  _stablecoin_balance   := get_tvl_till_date(_chain_id, _cover_key, _till);
  _siblings             := count_products(_chain_id, _cover_key);

  IF(_siblings = 0) THEN
    RETURN _stablecoin_balance;
  END IF;

  SELECT leverage_factor, average_capital_efficiency
  INTO _leverage, _average_capital_efficiency
  FROM get_capital_efficiency(_chain_id, _cover_key);

  SELECT capital_efficiency
  INTO _capital_efficiency
  FROM get_capital_efficiency(_chain_id, _cover_key, _product_key);

  IF(_leverage IS NULL) THEN
    _leverage := 1;
  END IF;
  
  IF(_capital_efficiency IS NULL) THEN
    _capital_efficiency := _multiplier;
  END IF;


  IF(_product_key = string_to_bytes32('')) THEN
    _capacity := (_stablecoin_balance * _leverage * _average_capital_efficiency) / _multiplier;
    RETURN _capacity;
  END IF;
  
  _capacity := (_stablecoin_balance * _leverage * _capital_efficiency) / (_siblings * _multiplier);
  RETURN _capacity;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_cover_capacity_till(84531, '0x62696e616e636500000000000000000000000000000000000000000000000000', 'infinity');

DROP FUNCTION IF EXISTS get_cover_info(_chain_id uint256, _cover_key bytes32);

CREATE FUNCTION get_cover_info(_chain_id uint256, _cover_key bytes32)
RETURNS TABLE
(
  cover_info                          text,
  cover_info_details                  text
)
STABLE
AS
$$
BEGIN
  RETURN QUERY
  WITH result AS (
    SELECT
      cover.cover_updated.info,
      config_known_ipfs_hashes_view.ipfs_details,
      cover.cover_updated.block_timestamp
    FROM cover.cover_updated
    INNER JOIN config_known_ipfs_hashes_view
    ON config_known_ipfs_hashes_view.ipfs_hash = cover.cover_updated.info
    WHERE cover.cover_updated.chain_id = _chain_id
    AND cover.cover_updated.cover_key = _cover_key
    UNION
    SELECT
      cover.cover_created.info,
      config_known_ipfs_hashes_view.ipfs_details,
      cover.cover_created.block_timestamp
    FROM cover.cover_created
    INNER JOIN config_known_ipfs_hashes_view
    ON config_known_ipfs_hashes_view.ipfs_hash = cover.cover_created.info
    WHERE cover.cover_created.chain_id = _chain_id
    AND cover.cover_created.cover_key = _cover_key
  )
  SELECT 
    info,
    ipfs_details
  FROM result
  ORDER BY block_timestamp DESC
  LIMIT 1;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_cover_info(84531, string_to_bytes32('atlasswap-v1'));

DROP FUNCTION IF EXISTS get_coverage_lag(_chain_id uint256, _cover_key bytes32) CASCADE;

CREATE FUNCTION get_coverage_lag(_chain_id uint256, _cover_key bytes32)
RETURNS uint256
STABLE
AS
$$
  DECLARE _lag                      uint256;
BEGIN
  SELECT policy.coverage_lag_set."window"
  INTO _lag
  FROM policy.coverage_lag_set
  WHERE policy.coverage_lag_set.chain_id = _chain_id
  AND policy.coverage_lag_set.cover_key = _cover_key
  ORDER BY policy.coverage_lag_set.block_timestamp DESC
  LIMIT 1;

  IF(_lag IS NOT NULL) THEN
    RETURN _lag;
  END IF;
  
  SELECT config_cover_view.coverage_lag
  INTO _lag
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _chain_id
  AND config_cover_view.cover_key = _cover_key;
  
  IF(_lag IS NOT NULL) THEN
    RETURN _lag;
  END IF;
    
  RETURN EXTRACT(epoch FROM INTERVAL '1 days');
END
$$
LANGUAGE plpgsql;

-- SELECT get_coverage_lag(42161, '0x62696e616e636500000000000000000000000000000000000000000000000000');


CREATE OR REPLACE FUNCTION get_gauge_pools()
RETURNS TABLE
(
  chain_id                                          numeric,
  key                                               bytes32,
  epoch_duration                                    uint256,
  pool_address                                      address,
  staking_token                                     address,
  name                                              text,
  info                                              text,
  platform_fee                                      uint256,
  token                                             address,
  lockup_period_in_blocks                           uint256,
  ratio                                             uint256,
  active                                            boolean,
  current_epoch                                     uint256,
  current_distribution                              uint256
)
AS
$$
  DECLARE _r                                        RECORD;
BEGIN
  DROP TABLE IF EXISTS _get_gauge_pools_result;
  CREATE TEMPORARY TABLE _get_gauge_pools_result
  (
    chain_id                                        numeric,
    key                                             bytes32,
    epoch_duration                                  uint256,
    pool_address                                    address,
    staking_token                                   address,
    name                                            text,
    info                                            text,
    platform_fee                                    uint256,
    token                                           address,
    lockup_period_in_blocks                         uint256,
    ratio                                           uint256,    
    active                                          boolean DEFAULT(true),
    current_epoch                                   uint256,
    current_distribution                            uint256
  ) ON COMMIT DROP;

  FOR _r IN
  (
    SELECT *
    FROM gauge_pool_lifecycle_view
    ORDER BY block_number::numeric
  )
  LOOP
    IF(_r.action = 'add') THEN
      INSERT INTO _get_gauge_pools_result
      SELECT
        liquidity_gauge_pool_set.chain_id,
        liquidity_gauge_pool_set.key,
        liquidity_gauge_pool_set.epoch_duration,
        liquidity_gauge_pool_set.address,
        liquidity_gauge_pool_set.staking_token,        
        liquidity_gauge_pool_set.name,
        liquidity_gauge_pool_set.info,
        liquidity_gauge_pool_set.platform_fee,
        liquidity_gauge_pool_set.staking_token,
        liquidity_gauge_pool_set.lockup_period_in_blocks,
        liquidity_gauge_pool_set.ve_boost_ratio
      FROM ve.liquidity_gauge_pool_set
      WHERE liquidity_gauge_pool_set.id = _r.id;
    END IF;
    
    IF(_r.action = 'edit') THEN
      UPDATE _get_gauge_pools_result
      SET 
        name = CASE WHEN COALESCE(liquidity_gauge_pool_set.name, '') = '' THEN _get_gauge_pools_result.name ELSE liquidity_gauge_pool_set.name END,
        info = CASE WHEN COALESCE(liquidity_gauge_pool_set.info, '') = '' THEN _get_gauge_pools_result.info ELSE liquidity_gauge_pool_set.info END,
        platform_fee = CASE WHEN COALESCE(liquidity_gauge_pool_set.platform_fee, 0) = 0 THEN _get_gauge_pools_result.platform_fee ELSE liquidity_gauge_pool_set.platform_fee END,
        lockup_period_in_blocks = CASE WHEN COALESCE(liquidity_gauge_pool_set.lockup_period_in_blocks, 0) = 0 THEN _get_gauge_pools_result.lockup_period_in_blocks ELSE liquidity_gauge_pool_set.lockup_period_in_blocks END,
        ratio = CASE WHEN COALESCE(liquidity_gauge_pool_set.ve_boost_ratio, 0) = 0 THEN _get_gauge_pools_result.ratio ELSE liquidity_gauge_pool_set.ve_boost_ratio END
      FROM ve.liquidity_gauge_pool_set AS liquidity_gauge_pool_set
      WHERE _get_gauge_pools_result.key = liquidity_gauge_pool_set.key
      AND _get_gauge_pools_result.chain_id = liquidity_gauge_pool_set.chain_id
      AND liquidity_gauge_pool_set.id = _r.id;
    END IF;
    
    IF(_r.action = 'deactivate') THEN
      UPDATE _get_gauge_pools_result
      SET active = false
      WHERE _get_gauge_pools_result.chain_id = _r.chain_id
      AND _get_gauge_pools_result.key = _r.key;      
    END IF;

    IF(_r.action = 'activate') THEN
      UPDATE _get_gauge_pools_result
      SET active = true
      WHERE _get_gauge_pools_result.chain_id = _r.chain_id
      AND _get_gauge_pools_result.key = _r.key;      
    END IF;

    IF(_r.action = 'delete') THEN
      DELETE FROM _get_gauge_pools_result
      WHERE _get_gauge_pools_result.chain_id = _r.chain_id
      AND _get_gauge_pools_result.key = _r.key;      
    END IF;
  END LOOP;
  
  --@todo: drop this when address bug of the `ve.liquidity_gauge_pool_set` is fixed
  UPDATE _get_gauge_pools_result
  SET pool_address = ve.liquidity_gauge_pool_added.pool
  FROM ve.liquidity_gauge_pool_added
  WHERE ve.liquidity_gauge_pool_added.chain_id = _get_gauge_pools_result.chain_id
  AND ve.liquidity_gauge_pool_added.key = _get_gauge_pools_result.key
  AND _get_gauge_pools_result.pool_address = '0x0000000000000000000000000000000000000000';
  
  UPDATE _get_gauge_pools_result
  SET
    current_epoch = ve.gauge_set.epoch,
    current_distribution = get_npm_value(ve.gauge_set.distribution)
  FROM ve.gauge_set
  WHERE ve.gauge_set.key = _get_gauge_pools_result.key
  AND ve.gauge_set.chain_id = _get_gauge_pools_result.chain_id
  AND ve.gauge_set.epoch = (SELECT MAX(epoch) FROM ve.gauge_set);
  

  -- @todo: The event EpochDurationUpdated hasn't been synchronized yet  
  -- UPDATE _get_gauge_pools_result
  -- SET epoch_duration =
  -- (
  --   SELECT current
  --   FROM ve.epoch_duration_updated
  --   WHERE ve.epoch_duration_updated.key = _get_gauge_pools_result.key
  --   AND ve.epoch_duration_updated.chain_id = _get_gauge_pools_result.chain_id    
  --   ORDER BY ve.epoch_duration_updated.block_timestamp DESC
  --   LIMIT 1
  -- );
  

  RETURN QUERY
  SELECT * FROM _get_gauge_pools_result;
END
$$
LANGUAGE plpgsql;


-- SELECT * FROM get_gauge_pools();





CREATE OR REPLACE FUNCTION get_incident_date_by_expiry_date
(
  _chain_id                 uint256,
  _cover_key                bytes32,
  _product_key              bytes32,
  _block_timestamp          uint256,
  _expires_on               uint256
)
RETURNS uint256 
STABLE
AS
$$ 
BEGIN
  RETURN incident_date
  FROM consensus.reported
  WHERE chain_id            = _chain_id
  AND cover_key             = _cover_key
  AND product_key           = _product_key
  AND incident_date
  BETWEEN _block_timestamp AND _expires_on
  ORDER BY incident_date DESC
  LIMIT 1;
END
$$
LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION get_latest_gauge_pool(_chain_id numeric, _key bytes32)
RETURNS address
STABLE
AS
$$
  DECLARE _pool address;
BEGIN
  WITH lgps
  AS
  (
    SELECT block_timestamp, address 
    FROM ve.liquidity_gauge_pool_added
    WHERE ve.liquidity_gauge_pool_added.chain_id = _chain_id
    AND ve.liquidity_gauge_pool_added.key = _key

    UNION ALL

    SELECT block_timestamp, current 
    FROM ve.liquidity_gauge_pool_updated
    WHERE ve.liquidity_gauge_pool_updated.chain_id = _chain_id
    AND ve.liquidity_gauge_pool_updated.key = _key
  )
  SELECT address
  INTO _pool
  FROM lgps
  ORDER BY block_timestamp DESC
  LIMIT 1;
  
  RETURN _pool;
END
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_min_first_reporting_stake(_chain_id uint256, _cover_key bytes32);

CREATE FUNCTION get_min_first_reporting_stake(_chain_id uint256, _cover_key bytes32)
RETURNS uint256
STABLE
AS
$$
  DECLARE _min_stake                            uint256;
BEGIN
  SELECT get_npm_value(consensus.first_reporting_stake_set.current)
  INTO _min_stake
  FROM consensus.first_reporting_stake_set
  WHERE consensus.first_reporting_stake_set.chain_id = _chain_id
  AND consensus.first_reporting_stake_set.cover_key = _cover_key
  ORDER BY consensus.first_reporting_stake_set.block_timestamp DESC
  LIMIT 1;

  IF(_min_stake IS NOT NULL) THEN
    RETURN _min_stake;
  END IF;

  SELECT get_npm_value(consensus.first_reporting_stake_set.current)
  INTO _min_stake
  FROM consensus.first_reporting_stake_set
  WHERE consensus.first_reporting_stake_set.chain_id = _chain_id
  AND consensus.first_reporting_stake_set.cover_key = string_to_bytes32('')
  ORDER BY consensus.first_reporting_stake_set.block_timestamp DESC
  LIMIT 1;

  IF(_min_stake IS NOT NULL) THEN
    RETURN _min_stake;
  END IF;

  SELECT get_npm_value(config_cover_view.minimum_first_reporting_stake)
  INTO _min_stake
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _chain_id
  AND config_cover_view.cover_key = _cover_key;

  IF(_min_stake IS NOT NULL) THEN
    RETURN _min_stake;
  END IF;

  SELECT get_npm_value(protocol.initialized.first_reporting_stake)
  INTO _min_stake
  FROM protocol.initialized
  WHERE protocol.initialized.chain_id = _chain_id;
  
  RETURN COALESCE(_min_stake, 0);
END
$$
LANGUAGE plpgsql;


--SELECT get_min_first_reporting_stake(84531, '0x62696e616e636500000000000000000000000000000000000000000000000000');

DROP FUNCTION IF EXISTS get_policy_ceiling
(
  _chain_id uint256,
  _cover_key bytes32
) CASCADE;

CREATE FUNCTION get_policy_ceiling
(
  _chain_id uint256,
  _cover_key bytes32
)
RETURNS uint256
STABLE
AS 
$$ 
  DECLARE _ceiling uint256;
BEGIN
  SELECT policy.cover_policy_rate_set.ceiling
  INTO _ceiling
  FROM
  policy.cover_policy_rate_set
  WHERE policy.cover_policy_rate_set.chain_id = _chain_id
  AND policy.cover_policy_rate_set.cover_key = _cover_key
  ORDER BY policy.cover_policy_rate_set.block_timestamp DESC
  LIMIT 1;

  IF(_ceiling IS NOT NULL) THEN
    RETURN _ceiling;
  END IF;

  SELECT config_cover_view.policy_ceiling
  INTO _ceiling
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _chain_id
  AND config_cover_view.cover_key = _cover_key;

  IF(_ceiling IS NOT NULL) THEN
    RETURN _ceiling;
  END IF;

	SELECT
    protocol.initialized.policy_ceiling INTO _ceiling
	FROM protocol.initialized
	WHERE protocol.initialized.chain_id = _chain_id;

  RETURN COALESCE(_ceiling, 0);
END 
$$
LANGUAGE plpgsql;

--SELECT get_policy_ceiling(42161, '0x62696e616e636500000000000000000000000000000000000000000000000000');


DROP FUNCTION IF EXISTS get_policy_floor
(
  _chain_id uint256,
  _cover_key bytes32
) CASCADE;

CREATE FUNCTION get_policy_floor
(
  _chain_id uint256,
  _cover_key bytes32
)
RETURNS uint256
STABLE
AS 
$$ 
  DECLARE _floor uint256;
BEGIN
  SELECT policy.cover_policy_rate_set.floor
  INTO _floor
  FROM
  policy.cover_policy_rate_set
  WHERE policy.cover_policy_rate_set.chain_id = _chain_id
  AND policy.cover_policy_rate_set.cover_key = _cover_key
  ORDER BY policy.cover_policy_rate_set.block_timestamp DESC
  LIMIT 1;

  IF(_floor IS NOT NULL) THEN
    RETURN _floor;
  END IF;

  SELECT config_cover_view.policy_floor
  INTO _floor
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _chain_id
  AND config_cover_view.cover_key = _cover_key;

  IF(_floor IS NOT NULL) THEN
    RETURN _floor;
  END IF;

	SELECT
    protocol.initialized.policy_floor INTO _floor
	FROM protocol.initialized
	WHERE protocol.initialized.chain_id = _chain_id;

  RETURN COALESCE(_floor, 0);
END 
$$
LANGUAGE plpgsql;
DROP FUNCTION IF EXISTS get_policy_status
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
) CASCADE;

CREATE FUNCTION get_policy_status
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
)
RETURNS TABLE
(
  disabled                                   bool,
  reason                                     text
)
STABLE
AS
$$
  DECLARE _disabled                           bool;
  DECLARE _reason                             text;
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;

  SELECT cover.product_state_updated.status, cover.product_state_updated.reason
  INTO _disabled, _reason
  FROM cover.product_state_updated
  WHERE cover.product_state_updated.chain_id = _chain_id
  AND cover.product_state_updated.cover_key = _cover_key
  AND cover.product_state_updated.product_key = _product_key
  ORDER BY cover.product_state_updated.block_timestamp DESC
  LIMIT 1;

  RETURN QUERY
  SELECT COALESCE(_disabled, false), COALESCE(_reason, '');
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_policy_status(80001, string_to_bytes32('coinbase'), string_to_bytes32(''));
-- SELECT * FROM get_policy_status(80001, string_to_bytes32('defi'), string_to_bytes32('kyberswap-v1'));


DROP FUNCTION IF EXISTS get_product_info(_chain_id uint256, _cover_key bytes32, _product_key bytes32);

CREATE FUNCTION get_product_info(_chain_id uint256, _cover_key bytes32, _product_key bytes32)
RETURNS TABLE
(
  product_info                          text,
  product_info_details                  text
)
STABLE
AS
$$
BEGIN
  RETURN QUERY
  WITH result AS (
    SELECT
      cover.product_updated.info,
      config_known_ipfs_hashes_view.ipfs_details,
      cover.product_updated.block_timestamp
    FROM cover.product_updated
    INNER JOIN config_known_ipfs_hashes_view
    ON config_known_ipfs_hashes_view.ipfs_hash = cover.product_updated.info
    WHERE cover.product_updated.chain_id = _chain_id
    AND cover.product_updated.cover_key = _cover_key
    AND cover.product_updated.product_key = _product_key
    UNION
    SELECT
      cover.product_created.info,
      config_known_ipfs_hashes_view.ipfs_details,
      cover.product_created.block_timestamp
    FROM cover.product_created
    INNER JOIN config_known_ipfs_hashes_view
    ON config_known_ipfs_hashes_view.ipfs_hash = cover.product_created.info
    WHERE cover.product_created.chain_id = _chain_id
    AND cover.product_created.cover_key = _cover_key
    AND cover.product_created.product_key = _product_key
  )
  SELECT 
    info,
    ipfs_details
  FROM result
  ORDER BY block_timestamp DESC
  LIMIT 1;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_product_info(1, string_to_bytes32('popular-defi-apps'), string_to_bytes32('compound-v2'));

CREATE OR REPLACE FUNCTION get_products_of 
(
  _chain_id             uint256,
  _cover_key            bytes32
)
RETURNS jsonb
AS
$$
BEGIN
  RETURN jsonb_agg(product_key) FROM config_product_view
  WHERE chain_id = _chain_id
  AND cover_key  = _cover_key;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_products_of(43113, string_to_bytes32('prime'))
CREATE OR REPLACE FUNCTION get_reassurance_till_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
IMMUTABLE
AS
$$
  DECLARE _added uint256;
  DECLARE _capitalized uint256;
BEGIN
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _added
  FROM reassurance.reassurance_added
  WHERE to_timestamp(block_timestamp) <= _date;
  
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _capitalized
  FROM reassurance.pool_capitalized
  WHERE to_timestamp(block_timestamp) <= _date;

  RETURN COALESCE(_added, 0) - COALESCE(_capitalized, 0);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_reassurance_till_date
(
  _chain_id                                 uint256,
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
IMMUTABLE
AS
$$
  DECLARE _added uint256;
  DECLARE _capitalized uint256;
BEGIN
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _added
  FROM reassurance.reassurance_added
  WHERE to_timestamp(block_timestamp) <= _date
  AND chain_id = _chain_id;
  
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _capitalized
  FROM reassurance.pool_capitalized
  WHERE to_timestamp(block_timestamp) <= _date
  AND chain_id = _chain_id;

  RETURN COALESCE(_added, 0) - COALESCE(_capitalized, 0);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_reassurance_till_date
(
  _chain_id                                 uint256,
  _cover_key                                bytes32,
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
IMMUTABLE
AS
$$
  DECLARE _added uint256;
  DECLARE _capitalized uint256;
BEGIN
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _added
  FROM reassurance.reassurance_added
  WHERE to_timestamp(block_timestamp) <= _date
  AND chain_id = _chain_id
  AND cover_key = _cover_key;
  
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _capitalized
  FROM reassurance.pool_capitalized
  WHERE to_timestamp(block_timestamp) <= _date
  AND chain_id = _chain_id
  AND cover_key = _cover_key;

  RETURN COALESCE(_added, 0) - COALESCE(_capitalized, 0);
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_reassurance_till_date(NOW());


DROP FUNCTION IF EXISTS get_reporter_commission(_chain_id uint256) CASCADE;

CREATE FUNCTION get_reporter_commission(_chain_id uint256)
RETURNS uint256
STABLE
AS
$$
  DECLARE _commission                      uint256;
BEGIN
  SELECT consensus.reporter_commission_set.current
  INTO _commission
  FROM consensus.reporter_commission_set
  WHERE consensus.reporter_commission_set.chain_id = _chain_id
  ORDER BY consensus.reporter_commission_set.block_timestamp DESC
  LIMIT 1;

  IF(_commission IS NOT NULL) THEN
    RETURN _commission;
  END IF;
  
  SELECT protocol.initialized.governance_reporter_commission
  INTO _commission
  FROM protocol.initialized
  WHERE protocol.initialized.chain_id = _chain_id;
  
  RETURN COALESCE(_commission, 0);
END
$$
LANGUAGE plpgsql;

--SELECT get_reporter_commission(42161);


DROP FUNCTION IF EXISTS get_reporting_period(_chain_id uint256, _cover_key bytes32);

CREATE FUNCTION get_reporting_period(_chain_id uint256, _cover_key bytes32)
RETURNS uint256
STABLE
AS
$$
BEGIN
  RETURN reporting_period
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _chain_id
  AND config_cover_view.cover_key = _cover_key;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_reporting_period(1, string_to_bytes32('popular-defi-apps'));

DROP FUNCTION IF EXISTS get_stakes
(
  _chain_id                                               uint256,
  _cover_key                                              bytes32,
  _product_key                                            bytes32,
  _incident_date                                          uint256
) CASCADE;

CREATE FUNCTION get_stakes
(
  _chain_id                                               uint256,
  _cover_key                                              bytes32,
  _product_key                                            bytes32,
  _incident_date                                          uint256
)
RETURNS TABLE
(
  yes                                                     uint256,
  no                                                      uint256
)
STABLE
AS
$$
  DECLARE _yes                                            uint256;
  DECLARE _no                                             uint256;
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key = string_to_bytes32('');
  END IF;

  SELECT camp_total INTO _yes
  FROM incident_stakes_by_camp_view
  WHERE incident_stakes_by_camp_view.camp = 'Attestation'
  AND incident_stakes_by_camp_view.chain_id = _chain_id
  AND incident_stakes_by_camp_view.cover_key = _cover_key
  AND incident_stakes_by_camp_view.product_key = _product_key
  AND incident_stakes_by_camp_view.incident_date = _incident_date;

  SELECT camp_total INTO _no
  FROM incident_stakes_by_camp_view
  WHERE incident_stakes_by_camp_view.camp != 'Attestation'
  AND incident_stakes_by_camp_view.chain_id = _chain_id
  AND incident_stakes_by_camp_view.cover_key = _cover_key
  AND incident_stakes_by_camp_view.product_key = _product_key
  AND incident_stakes_by_camp_view.incident_date = _incident_date;

  RETURN QUERY
  SELECT COALESCE(_yes, 0::uint256), COALESCE(_no, 0::uint256);
END
$$
LANGUAGE plpgsql;


--SELECT * FROM get_stakes(84531, string_to_bytes32('huobi'), NULL, 1676619751);



CREATE OR REPLACE FUNCTION get_tvl_till_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
IMMUTABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT SUM
  (
    get_stablecoin_value(core.transactions.chain_id, core.transactions.transaction_stablecoin_amount)
    *
    CASE WHEN core.transactions.event_name IN ('Claimed') THEN -1 ELSE 1 END
  )
  INTO _result
  FROM core.transactions
  WHERE core.transactions.event_name IN ('CoverPurchased', 'PodsIssued', 'PodsRedeemed', 'Claimed', 'PoolCapitalized')
  AND to_timestamp(core.transactions.block_timestamp) <= _date;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_tvl_till_date
(
  _chain_id                                 uint256,
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT SUM
  (
    get_stablecoin_value(core.transactions.chain_id, core.transactions.transaction_stablecoin_amount)
    *
    CASE WHEN core.transactions.event_name IN ('Claimed') THEN -1 ELSE 1 END
  )
  INTO _result
  FROM core.transactions
  WHERE core.transactions.chain_id = _chain_id
  AND core.transactions.event_name IN ('CoverPurchased', 'PodsIssued', 'PodsRedeemed', 'Claimed', 'PoolCapitalized')
  AND to_timestamp(core.transactions.block_timestamp) <= _date;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_tvl_till_date
(
  _chain_id                                 uint256,
  _cover_key                                bytes32,
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT SUM
  (    
    get_stablecoin_value(core.transactions.chain_id, core.transactions.transaction_stablecoin_amount)
    *
    CASE WHEN core.transactions.event_name IN ('Claimed') THEN -1 ELSE 1 END
  )
  INTO _result
  FROM core.transactions
  WHERE core.transactions.chain_id = _chain_id
  AND core.transactions.ck = _cover_key
  AND core.transactions.event_name IN ('CoverPurchased', 'PodsIssued', 'PodsRedeemed', 'Claimed', 'PoolCapitalized')
  AND to_timestamp(core.transactions.block_timestamp) <= _date;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user_milestones
(
  _account                        address
)
RETURNS TABLE
(
  total_policy_purchased          uint256,
  total_liquidity_added           uint256
)
STABLE
AS
$$ 
  DECLARE total_policy_purchased  uint256;
  DECLARE total_liquidity_added   uint256;
BEGIN
  SELECT
    SUM(get_stablecoin_value(chain_id, amount_to_cover))          INTO total_policy_purchased
  FROM policy.cover_purchased
  WHERE on_behalf_of              = _account;

  SELECT
    SUM(get_stablecoin_value(chain_id, liquidity_added))          INTO total_liquidity_added
  FROM vault.pods_issued
  WHERE account                   = _account;
  
  RETURN QUERY
  SELECT
    COALESCE(total_policy_purchased, 0::uint256),
    COALESCE(total_liquidity_added, 0::uint256);

END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_user_milestones('0x201bcc0d375f10543e585fbb883b36c715c959b3')
DROP FUNCTION IF EXISTS is_diversified
(
  _chain_id                                     uint256,
  _cover_key                                    bytes32
);

CREATE FUNCTION is_diversified
(
  _chain_id                                     uint256,
  _cover_key                                    bytes32
)
RETURNS boolean
STABLE
AS
$$
BEGIN
  IF EXISTS
  (
    SELECT * FROM cover.cover_created
    WHERE chain_id = _chain_id
    AND cover_key = _cover_key
    AND supports_products = TRUE
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sum_cover_purchased_during
(
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT
    SUM(get_stablecoin_value(policy.cover_purchased.chain_id, policy.cover_purchased.fee))
  INTO
    _result
  FROM policy.cover_purchased
  WHERE to_timestamp(policy.cover_purchased.block_timestamp)
  BETWEEN _start AND _end;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION sum_cover_purchased_during
(
  _chain_id                                   uint256,
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT
    SUM(get_stablecoin_value(policy.cover_purchased.chain_id, policy.cover_purchased.fee))
  INTO
    _result
  FROM policy.cover_purchased
  WHERE policy.cover_purchased.chain_id = _chain_id
  AND to_timestamp(policy.cover_purchased.block_timestamp)
  BETWEEN _start AND _end;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sum_cover_purchased_during
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT
    SUM(get_stablecoin_value(policy.cover_purchased.chain_id, policy.cover_purchased.fee))
  INTO
    _result
  FROM policy.cover_purchased
  WHERE policy.cover_purchased.chain_id = _chain_id
  AND policy.cover_purchased.cover_key = _cover_key
  AND to_timestamp(policy.cover_purchased.block_timestamp)
  BETWEEN _start AND _end;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;

DROP VIEW IF EXISTS capacity_view;

CREATE VIEW capacity_view
AS
WITH chains
AS
(
	SELECT DISTINCT core.transactions.chain_id
	FROM core.transactions
),
unfiltered
AS
(
  SELECT chain_id, cover_key, product_key
  FROM config_product_view
  WHERE config_product_view.chain_id IN
  (
    SELECT chain_id FROM chains
  )
  UNION ALL
  SELECT  chain_id, cover_key, string_to_bytes32('') FROM config_cover_view
  WHERE config_cover_view.chain_id IN
  (
    SELECT chain_id FROM chains
  )
),
products
AS
(
  SELECT DISTINCT chain_id, cover_key, product_key
  FROM unfiltered
  WHERE cover_key IS NOT NULL
)
SELECT
  chain_id,
  cover_key,
  bytes32_to_string(cover_key) AS cover,
  is_diversified(chain_id, cover_key) AS diversified,
  product_key,
  bytes32_to_string(product_key) AS product,
  get_cover_capacity_till(chain_id, cover_key, product_key, 'infinity') AS capacity
FROM products;

DROP VIEW IF EXISTS capacity_by_chain_view;

CREATE VIEW capacity_by_chain_view
AS
SELECT chain_id, sum(capacity) AS total_capacity
FROM capacity_view
GROUP BY chain_id;

GRANT USAGE ON SCHEMA vault TO readonlyuser;
GRANT USAGE ON SCHEMA ve TO readonlyuser;
GRANT USAGE ON SCHEMA strategy TO readonlyuser;
GRANT USAGE ON SCHEMA store TO readonlyuser;
GRANT USAGE ON SCHEMA staking TO readonlyuser;
GRANT USAGE ON SCHEMA reassurance TO readonlyuser;
GRANT USAGE ON SCHEMA public TO readonlyuser;
GRANT USAGE ON SCHEMA protocol TO readonlyuser;
GRANT USAGE ON SCHEMA policy TO readonlyuser;
GRANT USAGE ON SCHEMA factory TO readonlyuser;
GRANT USAGE ON SCHEMA cxtoken TO readonlyuser;
GRANT USAGE ON SCHEMA cover TO readonlyuser;
GRANT USAGE ON SCHEMA core TO readonlyuser;
GRANT USAGE ON SCHEMA consensus TO readonlyuser;
GRANT USAGE ON SCHEMA claim TO readonlyuser;
GRANT USAGE ON SCHEMA nft TO readonlyuser;

GRANT SELECT ON ALL TABLES IN SCHEMA factory TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA strategy TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA reassurance TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA cxtoken TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA policy TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA consensus TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA vault TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA ve TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA protocol TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA cover TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA staking TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA store TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA claim TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA nft TO readonlyuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft GRANT SELECT ON TABLES TO readonlyuser;

REVOKE CREATE ON SCHEMA factory FROM readonlyuser;
REVOKE CREATE ON SCHEMA strategy FROM readonlyuser;
REVOKE CREATE ON SCHEMA core FROM readonlyuser;
REVOKE CREATE ON SCHEMA reassurance FROM readonlyuser;
REVOKE CREATE ON SCHEMA cxtoken FROM readonlyuser;
REVOKE CREATE ON SCHEMA policy FROM readonlyuser;
REVOKE CREATE ON SCHEMA consensus FROM readonlyuser;
REVOKE CREATE ON SCHEMA vault FROM readonlyuser;
REVOKE CREATE ON SCHEMA ve FROM readonlyuser;
REVOKE CREATE ON SCHEMA protocol FROM readonlyuser;
REVOKE CREATE ON SCHEMA cover FROM readonlyuser;
REVOKE CREATE ON SCHEMA staking FROM readonlyuser;
REVOKE CREATE ON SCHEMA store FROM readonlyuser;
REVOKE CREATE ON SCHEMA claim FROM readonlyuser;
REVOKE CREATE ON SCHEMA nft FROM readonlyuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;

GRANT CREATE ON SCHEMA public TO writeuser;
GRANT CREATE ON SCHEMA factory TO writeuser;
GRANT CREATE ON SCHEMA strategy TO writeuser;
GRANT CREATE ON SCHEMA core TO writeuser;
GRANT CREATE ON SCHEMA reassurance TO writeuser;
GRANT CREATE ON SCHEMA cxtoken TO writeuser;
GRANT CREATE ON SCHEMA policy TO writeuser;
GRANT CREATE ON SCHEMA consensus TO writeuser;
GRANT CREATE ON SCHEMA vault TO writeuser;
GRANT CREATE ON SCHEMA ve TO writeuser;
GRANT CREATE ON SCHEMA protocol TO writeuser;
GRANT CREATE ON SCHEMA cover TO writeuser;
GRANT CREATE ON SCHEMA staking TO writeuser;
GRANT CREATE ON SCHEMA store TO writeuser;
GRANT CREATE ON SCHEMA claim TO writeuser;
GRANT CREATE ON SCHEMA nft TO writeuser;

GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA factory TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA strategy TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA core TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA reassurance TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA cxtoken TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA policy TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA consensus TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA vault TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA ve TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA protocol TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA cover TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA staking TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA store TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA claim TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA nft TO writeuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft GRANT INSERT, UPDATE ON TABLES TO writeuser;
CREATE OR REPLACE FUNCTION get_report_insight
(
  _chain_id                                       uint256,
  _cover_key                                      bytes32,
  _product_key                                    bytes32,
  _incident_date                                  uint256
)
RETURNS TABLE
(
  chain_id                                        uint256,
  cover_key                                       bytes32,
  product_key                                     bytes32,
  incident_date                                   uint256,
  report_resolution_timestamp                     uint256,
  report_transaction                              address,
  report_timestamp                                uint256,
  reporter                                        address,
  report_info                                     text,
  reporter_stake                                  uint256,
  dispute_transaction                             address,
  dispute_timestamp                               uint256,
  disputer                                        address,
  dispute_info                                    text,
  disputer_stake                                  uint256,
  total_attestation                               uint256,
  attestation_count                               integer,
  total_refutation                                uint256,
  refutation_count                                integer,
  resolved                                        boolean,
  resolution_transaction                          text,
  resolution_timestamp                            uint256,
  resolution_decision                             boolean,
  resolution_deadline                             uint256,
  emergency_resolved                              boolean,
  emergency_resolution_transaction                text,
  emergency_resolution_timestamp                  uint256,
  emergency_resolution_decision                   boolean,
  emergency_resolution_deadline                   uint256,
  finalized                                       boolean,
  status_enum                                     product_status_type,
  status                                          smallint,
  claim_begins_from                               uint256,
  claim_expires_at                                uint256
)
AS
$$
  DECLARE _total_attestation                      uint256;
  DECLARE _attestation_count                      integer;
  DECLARE _total_refutation                       uint256;
  DECLARE _refutation_count                       integer;
BEGIN
  DROP TABLE IF EXISTS _get_report_insight_result;
  
  CREATE TEMPORARY TABLE _get_report_insight_result
  (
    chain_id                                        uint256,
    cover_key                                       bytes32,
    product_key                                     bytes32,
    incident_date                                   uint256,
    report_resolution_timestamp                     uint256,
    report_transaction                              address,
    report_timestamp                                uint256,
    reporter                                        address,
    report_info                                     text,
    reporter_stake                                  uint256,
    dispute_transaction                             address,
    dispute_timestamp                               uint256,
    disputer                                        address,
    dispute_info                                    text,
    disputer_stake                                  uint256,
    total_attestation                               uint256,
    attestation_count                               integer,
    total_refutation                                uint256,
    refutation_count                                integer,
    resolved                                        boolean,
    resolution_transaction                          text,
    resolution_timestamp                            uint256,
    resolution_decision                             boolean,
    resolution_deadline                             uint256,
    emergency_resolved                              boolean,
    emergency_resolution_transaction                text,
    emergency_resolution_timestamp                  uint256,
    emergency_resolution_decision                   boolean,
    emergency_resolution_deadline                   uint256,
    finalized                                       boolean,
    status_enum                                     product_status_type,
    status                                          smallint,
    claim_begins_from                               uint256,
    claim_expires_at                                uint256
  ) ON COMMIT DROP;

  INSERT INTO _get_report_insight_result(chain_id, cover_key, product_key, incident_date, report_resolution_timestamp, report_transaction, report_timestamp, reporter, report_info, reporter_stake, status_enum)
  SELECT
    consensus.reported.chain_id,
    consensus.reported.cover_key,
    consensus.reported.product_key,
    consensus.reported.incident_date,
    consensus.reported.resolution_timestamp,
    consensus.reported.transaction_hash,
    consensus.reported.block_timestamp,
    consensus.reported.reporter,
    consensus.reported.info,
    get_npm_value(consensus.reported.initial_stake),
    get_product_status(_chain_id, _cover_key, _product_key, _incident_date)
  FROM consensus.reported
  WHERE consensus.reported.chain_id     = _chain_id
  AND consensus.reported.cover_key      = _cover_key
  AND consensus.reported.product_key    = _product_key
  AND consensus.reported.incident_date  = _incident_date;

  UPDATE _get_report_insight_result
  SET
    dispute_transaction   = consensus.disputed.transaction_hash,
    dispute_timestamp     = consensus.disputed.block_timestamp,
    disputer              = consensus.disputed.reporter,
    dispute_info          = consensus.disputed.info,
    disputer_stake        = get_npm_value(consensus.disputed.initial_stake)
  FROM consensus.disputed
  WHERE consensus.disputed.chain_id     = _get_report_insight_result.chain_id
  AND consensus.disputed.cover_key      = _get_report_insight_result.cover_key
  AND consensus.disputed.product_key    = _get_report_insight_result.product_key
  AND consensus.disputed.incident_date  = _get_report_insight_result.incident_date;
  
  SELECT COUNT(*), SUM(get_npm_value(consensus.attested.stake))
  INTO _attestation_count, _total_attestation
  FROM consensus.attested
  WHERE consensus.attested.chain_id     = _chain_id
  AND consensus.attested.cover_key      = _cover_key
  AND consensus.attested.product_key    = _product_key
  AND consensus.attested.incident_date  = _incident_date;

  SELECT COUNT(*), SUM(get_npm_value(consensus.refuted.stake))
  INTO _refutation_count, _total_refutation
  FROM consensus.refuted
  WHERE consensus.refuted.chain_id      = _chain_id
  AND consensus.refuted.cover_key       = _cover_key
  AND consensus.refuted.product_key     = _product_key
  AND consensus.refuted.incident_date   = _incident_date;

  UPDATE _get_report_insight_result
  SET
    total_attestation   = _total_attestation,
    attestation_count   = _attestation_count,
    total_refutation    = _total_refutation,
    refutation_count    = _refutation_count,
    status              = array_length(enum_range(NULL, _get_report_insight_result.status_enum), 1) - 1;


  WITH resolution
  AS
  (
    SELECT
      consensus.resolved.chain_id,
      consensus.resolved.cover_key,
      consensus.resolved.product_key,
      consensus.resolved.incident_date,
      true                                    AS resolved,
      consensus.resolved.transaction_hash     AS resolution_transaction,
      consensus.resolved.block_timestamp      AS resolution_timestamp,
      consensus.resolved.decision             AS resolution_decision, 
      consensus.resolved.resolution_deadline,
      consensus.resolved.claim_begins_from,
      consensus.resolved.claim_expires_at
    FROM consensus.resolved
    WHERE consensus.resolved.chain_id     = _chain_id
    AND consensus.resolved.cover_key      = _cover_key
    AND consensus.resolved.product_key    = _product_key
    AND consensus.resolved.incident_date  = _incident_date
  )
  UPDATE _get_report_insight_result
  SET
    resolved                              = resolution.resolved,
    resolution_transaction                = resolution.resolution_transaction,
    resolution_timestamp                  = resolution.resolution_timestamp,
    resolution_decision                   = resolution.resolution_decision,
    resolution_deadline                   = resolution.resolution_deadline,
    claim_begins_from                     = resolution.claim_begins_from,
    claim_expires_at                      = resolution.claim_expires_at
  FROM resolution
  WHERE resolution.chain_id               = _get_report_insight_result.chain_id
  AND resolution.cover_key                = _get_report_insight_result.cover_key
  AND resolution.product_key              = _get_report_insight_result.product_key
  AND resolution.incident_date            = _get_report_insight_result.incident_date;

  WITH emergency_resolution
  AS
  (
    SELECT
      consensus.resolved.chain_id,
      consensus.resolved.cover_key,
      consensus.resolved.product_key,
      consensus.resolved.incident_date,
      true AS resolved,
      consensus.resolved.transaction_hash     AS resolution_transaction,
      consensus.resolved.block_timestamp      AS resolution_timestamp,
      consensus.resolved.decision             AS resolution_decision, 
      consensus.resolved.resolution_deadline,
      consensus.resolved.claim_begins_from,
      consensus.resolved.claim_expires_at
    FROM consensus.resolved
    WHERE consensus.resolved.chain_id     = _chain_id
    AND consensus.resolved.cover_key      = _cover_key
    AND consensus.resolved.product_key    = _product_key
    AND consensus.resolved.incident_date  = _incident_date
    AND consensus.resolved.emergency      = true
    ORDER BY consensus.resolved.block_timestamp DESC
  )
  UPDATE _get_report_insight_result
  SET
    emergency_resolved                    = emergency_resolution.resolved,
    emergency_resolution_transaction      = emergency_resolution.resolution_transaction,
    emergency_resolution_timestamp        = emergency_resolution.resolution_timestamp,
    emergency_resolution_decision         = emergency_resolution.resolution_decision,
    emergency_resolution_deadline         = emergency_resolution.resolution_deadline,
    claim_begins_from                     = emergency_resolution.claim_begins_from,
    claim_expires_at                      = emergency_resolution.claim_expires_at
  FROM emergency_resolution
  WHERE emergency_resolution.chain_id     = _get_report_insight_result.chain_id
  AND emergency_resolution.cover_key      = _get_report_insight_result.cover_key
  AND emergency_resolution.product_key    = _get_report_insight_result.product_key
  AND emergency_resolution.incident_date  = _get_report_insight_result.incident_date;

  UPDATE _get_report_insight_result
  SET finalized = true
  WHERE EXISTS
  (
    SELECT 1
    FROM consensus.finalized
    WHERE consensus.finalized.chain_id    = _chain_id
    AND consensus.finalized.cover_key     = _cover_key
    AND consensus.finalized.product_key   = _product_key
    AND consensus.finalized.incident_date = _incident_date
  );


  RETURN QUERY
  SELECT * FROM _get_report_insight_result;
END
$$
LANGUAGE plpgsql;


DROP VIEW IF EXISTS cover_expiring_this_month_view;

CREATE VIEW cover_expiring_this_month_view
AS
SELECT
  cover_key,
  bytes32_to_string(cover_key) AS cover_key_string,
  product_key,
  bytes32_to_string(product_key) AS product_key_string,
  SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS total_protection
FROM policy.cover_purchased
WHERE to_timestamp(expires_on) = 
(
  date_trunc('MONTH', NOW() AT TIME ZONE 'UTC') + INTERVAL '1 MONTH' * 
    CASE
      WHEN EXTRACT(DAY FROM NOW() AT TIME ZONE 'UTC') > 24
      THEN 2
      ELSE 1
    END
    - INTERVAL '1 second'
) AT TIME ZONE 'UTC'
GROUP BY cover_key, product_key;



DROP VIEW IF EXISTS cover_premium_by_pool;

CREATE VIEW cover_premium_by_pool
AS
SELECT
  cover_key,
  bytes32_to_string(cover_key) AS cover_key_string,
  product_key,
  bytes32_to_string(product_key) AS product_key_string,
  SUM(get_stablecoin_value(chain_id, fee)) AS total_premium
FROM policy.cover_purchased
GROUP BY cover_key, product_key;


DROP VIEW IF EXISTS cover_sold_by_pool_view;

CREATE VIEW cover_sold_by_pool_view
AS
SELECT
  cover_key,
  bytes32_to_string(cover_key) AS cover_key_string,
  product_key,
  bytes32_to_string(product_key) AS product_key_string,
  SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS total_protection
FROM policy.cover_purchased
GROUP BY cover_key, product_key;


DROP VIEW IF EXISTS gas_price_summary_view;

CREATE VIEW gas_price_summary_view
AS
SELECT
  config_blockchain_network_view.chain_id,
  config_blockchain_network_view.network_name,
  config_blockchain_network_view.nick_name,
  FLOOR(AVG(gas_price)) AS average_gas_price,
  MIN(gas_price) AS min_gas_price,
  MAX(gas_price) AS max_gas_price
FROM core.transactions
INNER JOIN config_blockchain_network_view
ON config_blockchain_network_view.chain_id = core.transactions.chain_id
GROUP BY 
  config_blockchain_network_view.chain_id,
  config_blockchain_network_view.network_name,
  config_blockchain_network_view.nick_name;

DROP FUNCTION IF EXISTS get_capacity_chart_data() CASCADE;

CREATE OR REPLACE FUNCTION get_capacity_chart_data()
RETURNS TABLE
(
  till                          TIMESTAMP WITH TIME ZONE,
  amount                        uint256
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_total_capacity_chart_data_result;

  CREATE TEMPORARY TABLE _get_total_capacity_chart_data_result
  (
    till                          TIMESTAMP WITH TIME ZONE,
    amount                        uint256
  ) ON COMMIT DROP;
  
  INSERT INTO _get_total_capacity_chart_data_result(till)
  SELECT DISTINCT ((to_timestamp(block_timestamp) AT TIME ZONE 'UTC')::date + interval '1 day - 1 sec')::TIMESTAMP WITH TIME ZONE AT TIME ZONE 'UTC'
  FROM core.transactions
  WHERE core.transactions.event_name IN ('CoverPurchased', 'PodsIssued', 'PodsRedeemed', 'Claimed', 'PoolCapitalized');

  UPDATE _get_total_capacity_chart_data_result
  SET amount = get_total_capacity_by_date(_get_total_capacity_chart_data_result.till);

  RETURN QUERY
  SELECT * FROM _get_total_capacity_chart_data_result
  ORDER BY 1 ASC;
END
$$
LANGUAGE plpgsql;


-- SELECT  *
-- FROM get_capacity_chart_data();

CREATE OR REPLACE FUNCTION get_historical_apr_by_cover_chart_data()
RETURNS TABLE
(
  chain_id                                  uint256,
  network_name                              text,
  cover_key                                 bytes32,
  cover_key_string                          text,
  start_date                                date,
  end_date                                  date,
  duration                                  integer,
  period_name                               text,
  start_balance                             numeric,
  end_balance                               numeric,
  policy_fee_earned                         numeric,
  apr                                       numeric
)
AS
$$
BEGIN
  CREATE TEMPORARY TABLE _get_historical_apr_chart_data_result
  (
    chain_id                                  uint256,
    network_name                              text,
    cover_key                                 bytes32,
    cover_key_string                          text,
    start_date                                date,
    end_date                                  date,
    duration                                  integer,
    period_name                               text,
    start_balance                             numeric,
    end_balance                               numeric,
    policy_fee_earned                         numeric,
    apr                                       NUMERIC DEFAULT(0)
  ) ON COMMIT DROP;
  
  
  INSERT INTO _get_historical_apr_chart_data_result(chain_id, cover_key, start_date)
  WITH dates
  AS
  (
    SELECT date_trunc('month',generate_series((SELECT to_timestamp(MIN(block_timestamp))::date FROM core.transactions), now(), '1 month'))
  )
  SELECT DISTINCT core.transactions.chain_id, core.transactions.ck, dates.*
  FROM core.transactions
  CROSS JOIN dates
  WHERE core.transactions.ck IS NOT NULL;  
  
  UPDATE _get_historical_apr_chart_data_result
  SET
    cover_key_string  = bytes32_to_string(_get_historical_apr_chart_data_result.cover_key),
    end_date          = (_get_historical_apr_chart_data_result.start_date + '1 month'::interval - '1 day'::interval),
    period_name       = to_char(_get_historical_apr_chart_data_result.start_date, 'Mon-YY'),
    start_balance     = get_tvl_till_date(_get_historical_apr_chart_data_result.chain_id, _get_historical_apr_chart_data_result.cover_key, _get_historical_apr_chart_data_result.start_date);
  
  UPDATE _get_historical_apr_chart_data_result
  SET end_date = NOW()
  WHERE _get_historical_apr_chart_data_result.end_date > NOW();

  UPDATE _get_historical_apr_chart_data_result
  SET
    policy_fee_earned = sum_cover_purchased_during(_get_historical_apr_chart_data_result.chain_id, _get_historical_apr_chart_data_result.cover_key, _get_historical_apr_chart_data_result.start_date, _get_historical_apr_chart_data_result.end_date),
    duration = _get_historical_apr_chart_data_result.end_date - _get_historical_apr_chart_data_result.start_date,
    end_balance       = get_tvl_till_date(_get_historical_apr_chart_data_result.chain_id, _get_historical_apr_chart_data_result.cover_key, _get_historical_apr_chart_data_result.end_date);
  
  UPDATE _get_historical_apr_chart_data_result
  SET apr = (_get_historical_apr_chart_data_result.policy_fee_earned * 365) / (average(_get_historical_apr_chart_data_result.start_balance, _get_historical_apr_chart_data_result.end_balance) * _get_historical_apr_chart_data_result.duration)
  WHERE _get_historical_apr_chart_data_result.start_balance > 0;
  
  UPDATE _get_historical_apr_chart_data_result
  SET network_name = config_blockchain_network_view.nick_name
  FROM config_blockchain_network_view
  WHERE config_blockchain_network_view.chain_id = _get_historical_apr_chart_data_result.chain_id;

  RETURN QUERY
  SELECT * FROM _get_historical_apr_chart_data_result
  ORDER BY 2, 1;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_historical_apr_by_cover_chart_data() ORDER BY APR DESC;





DROP FUNCTION IF EXISTS get_historical_apr_chart_data() CASCADE;

CREATE FUNCTION get_historical_apr_chart_data()
RETURNS TABLE
(
  chain_id                                  uint256,
  network_name                              text,
  start_date                                date,
  end_date                                  date,
  duration                                  integer,
  period_name                               text,
  start_balance                             numeric,
  policy_fee_earned                         numeric,
  apr                                       numeric
)
AS
$$
BEGIN
  CREATE TEMPORARY TABLE _get_historical_apr_chart_data_result
  (
    chain_id                                  uint256,
    network_name                              text,
    start_date                                date,
    end_date                                  date,
    duration                                  integer,
    period_name                               text,
    start_balance                             numeric,
    policy_fee_earned                         numeric,
    apr                                       NUMERIC DEFAULT(0)
  ) ON COMMIT DROP;
  
  
  INSERT INTO _get_historical_apr_chart_data_result(chain_id, start_date)
  WITH dates
  AS
  (
    SELECT date_trunc('month',generate_series((SELECT to_timestamp(MIN(block_timestamp))::date FROM core.transactions), now(), '1 month'))
  )
  SELECT DISTINCT core.transactions.chain_id, dates.*
  FROM core.transactions
  CROSS JOIN dates;
  
  
  UPDATE _get_historical_apr_chart_data_result
  SET
    end_date = (_get_historical_apr_chart_data_result.start_date + '1 month'::interval - '1 day'::interval),
    period_name = to_char(_get_historical_apr_chart_data_result.start_date, 'Mon-YY'),
    start_balance = get_tvl_till_date(_get_historical_apr_chart_data_result.chain_id, _get_historical_apr_chart_data_result.start_date);
  
  UPDATE _get_historical_apr_chart_data_result
  SET end_date = NOW()
  WHERE _get_historical_apr_chart_data_result.end_date > NOW();

  UPDATE _get_historical_apr_chart_data_result
  SET
    policy_fee_earned = sum_cover_purchased_during(_get_historical_apr_chart_data_result.chain_id, _get_historical_apr_chart_data_result.start_date, _get_historical_apr_chart_data_result.end_date),
    duration = _get_historical_apr_chart_data_result.end_date - _get_historical_apr_chart_data_result.start_date;
  
  UPDATE _get_historical_apr_chart_data_result
  SET apr = (_get_historical_apr_chart_data_result.policy_fee_earned * 365) / (_get_historical_apr_chart_data_result.start_balance * _get_historical_apr_chart_data_result.duration)
  WHERE _get_historical_apr_chart_data_result.start_balance > 0;
  
  UPDATE _get_historical_apr_chart_data_result
  SET network_name = config_blockchain_network_view.nick_name
  FROM config_blockchain_network_view
  WHERE config_blockchain_network_view.chain_id = _get_historical_apr_chart_data_result.chain_id;

  RETURN QUERY
  SELECT * FROM _get_historical_apr_chart_data_result
  ORDER BY 2, 1;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_historical_apr_chart_data();

CREATE OR REPLACE FUNCTION get_magic_square_campaign_2_result
(
  _account                                          address
)
RETURNS TABLE
(
  result                                            boolean,
  covered_amount                                    uint256,
  nft_id                                            uint256
)
AS
$$
  /*
  Requirement:
  ------------------------------------------------------------
  policy
    - should be purchased after 12 jan 2024
    - for 3 months
    - covered amount is greater than 50 USDC

  nft
    - soulbound token should be purchased after 12 jan 2024

  (
    for both cases
    chain
      - should be 56
  )
  */
  DECLARE _CHAIN_ID CONSTANT                        uint256 = 56;
  DECLARE _MIN_COVER_AMOUNT_REQUIRED CONSTANT       uint256 = 50 * POWER(10, 18);
  DECLARE _PURCHASE_AFTER CONSTANT                  TIMESTAMP WITH TIME ZONE = '12 Jan, 2024' AT TIME ZONE 'UTC';
  DECLARE _MIN_POLICY_PURCHASE_DURATION CONSTANT    uint256 = 3;
  DECLARE _result                                   boolean = true;
  DECLARE _covered_amount                           uint256;
  DECLARE _nft_id                                   uint256;
BEGIN
  SELECT SUM(amount_to_cover) INTO _covered_amount
  FROM policy.cover_purchased
  WHERE policy.cover_purchased.on_behalf_of ILIKE _account
  AND policy.cover_purchased.chain_id = _CHAIN_ID
  AND policy.cover_purchased.block_timestamp >= EXTRACT(EPOCH FROM _PURCHASE_AFTER)
  AND policy.cover_purchased.cover_duration = _MIN_POLICY_PURCHASE_DURATION;

  SELECT token_id INTO _nft_id
  FROM nft.soulbound_minted
  WHERE nft.soulbound_minted.account ILIKE _account
  AND nft.soulbound_minted.block_timestamp >= EXTRACT(EPOCH FROM _PURCHASE_AFTER)
  LIMIT 1;
  
  IF(COALESCE(_covered_amount, 0) < _MIN_COVER_AMOUNT_REQUIRED) THEN
    _result := false;
  END IF;

  IF(COALESCE(_nft_id, 0) = 0) THEN
    _result := false;
  END IF;

  RETURN QUERY
  SELECT _result, _covered_amount, _nft_id;
END
$$
LANGUAGE plpgsql;
DROP FUNCTION IF EXISTS get_product_summary(_account address);

CREATE FUNCTION get_product_summary(_account address DEFAULT '')
RETURNS TABLE
(
  chain_id                              numeric,
  cover_key                             bytes32,
  cover_key_string                      text,
  cover_info                            text,
  cover_info_details                    text,
  product_key                           bytes32,
  product_key_string                    text,
  policy_status                         text,
  product_info                          text,
  product_info_details                  text,
  product_status_enum                   product_status_type,
  product_status                        integer,
  floor                                 numeric,
  ceiling                               numeric,
  leverage                              numeric,
  capital_efficiency                    numeric,
  capacity                              numeric,
  commitment                            numeric,
  available_for_underwriting            numeric,
  utilization_ratio                     numeric,
  reassurance                           numeric,
  tvl                                   numeric,
  coverage_lag                          numeric,
  supports_products                     boolean,
  requires_whitelist                    boolean,
  min_reporting_stake                   numeric,
  active_incident_date                  integer,
  reporter_commission                   integer,
  reporting_period                      integer,
  claim_platform_fee                    integer,
  is_user_whitelisted                   boolean
)
AS
$$
BEGIN
  CREATE TEMPORARY TABLE _get_product_summary_result
  (
    chain_id                            numeric,
    cover_key                           bytes32,
    cover_key_string                    text,
    cover_info                          text,
    cover_info_details                  text,
    product_key                         bytes32,
    product_key_string                  text,
    policy_status                       text,
    product_info                        text,
    product_info_details                text,
    product_status_enum                 product_status_type,
    product_status                      integer,
    floor                               numeric DEFAULT(0),
    ceiling                             numeric DEFAULT(0),
    leverage                            numeric DEFAULT(0),
    capital_efficiency                  numeric DEFAULT(0),
    capacity                            numeric DEFAULT(0),
    commitment                          numeric DEFAULT(0),
    available_for_underwriting          numeric DEFAULT(0),
    utilization_ratio                   numeric,
    reassurance                         numeric DEFAULT(0),
    tvl                                 numeric DEFAULT(0),
    coverage_lag                        numeric DEFAULT(0),
    supports_products                   boolean DEFAULT(false),
    requires_whitelist                  boolean DEFAULT(false),
    min_reporting_stake                 numeric,
    active_incident_date                integer,
    reporter_commission                 integer,
    reporting_period                    integer,
    claim_platform_fee                  integer,
    is_user_whitelisted                 boolean
  ) ON COMMIT DROP;
  
  INSERT INTO _get_product_summary_result(chain_id, cover_key, cover_key_string, product_key, product_key_string, capital_efficiency)
  SELECT
    config_product_view.chain_id,
    config_product_view.cover_key,
    bytes32_to_string(config_product_view.cover_key),
    config_product_view.product_key,
    bytes32_to_string(config_product_view.product_key),
    config_product_view.capital_efficiency
  FROM config_product_view
  WHERE config_product_view.chain_id IN
  (
    SELECT DISTINCT core.transactions.chain_id
    FROM core.transactions
  );
  
  INSERT INTO _get_product_summary_result(chain_id, cover_key, cover_key_string, leverage, capital_efficiency)
  SELECT
    cover.cover_created.chain_id,
    cover.cover_created.cover_key,
    bytes32_to_string(cover.cover_created.cover_key),
    1 AS leverage,
    10000 AS capital_efficiency
  FROM cover.cover_created;

  UPDATE _get_product_summary_result
  SET supports_products           = is_diversified(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key)
  WHERE _get_product_summary_result.product_key IS NULL;

  UPDATE _get_product_summary_result
  SET
    leverage                      = config_cover_view.leverage,
    floor                         = config_cover_view.policy_floor,
    ceiling                       = config_cover_view.policy_ceiling
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _get_product_summary_result.chain_id
  AND config_cover_view.cover_key = _get_product_summary_result.cover_key;
  
  UPDATE _get_product_summary_result
  SET 
    capacity                      = get_cover_capacity_till(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, _get_product_summary_result.product_key, 'infinity'),
    commitment                    = CASE 
                                    WHEN _get_product_summary_result.supports_products 
                                    THEN get_sum_commitment(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key)
                                    ELSE get_commitment(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, _get_product_summary_result.product_key)
                                    END,
    reporting_period              = get_reporting_period(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    requires_whitelist            = check_if_requires_whitelist(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    product_status_enum           = get_active_product_status(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key),
    active_incident_date          = get_active_incident_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key),
    min_reporting_stake           = get_min_first_reporting_stake(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    coverage_lag                  = get_coverage_lag(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    reporter_commission           = get_reporter_commission(_get_product_summary_result.chain_id),
    claim_platform_fee            = get_claim_platform_fee(_get_product_summary_result.chain_id),
    reassurance                   = get_reassurance_till_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, 'infinity'),
    is_user_whitelisted           = check_if_user_whitelisted(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, _get_product_summary_result.product_key, _account),
    tvl                           = get_tvl_till_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, 'infinity'),
    policy_status                 = (SELECT json_agg(p) FROM get_policy_status(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key) AS p),
    product_info                  = (SELECT p.product_info FROM get_product_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key) AS p),
    product_info_details          = (SELECT p.product_info_details FROM get_product_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key) AS p),
    cover_info                    = (SELECT c.cover_info FROM get_cover_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key) AS c),
    cover_info_details            = (SELECT c.cover_info_details FROM get_cover_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key) AS c);

  UPDATE _get_product_summary_result
  SET
    available_for_underwriting    = _get_product_summary_result.capacity - _get_product_summary_result.commitment,
    utilization_ratio             = CASE WHEN _get_product_summary_result.capacity = 0 THEN 0 ELSE _get_product_summary_result.commitment / _get_product_summary_result.capacity END,
    product_status                = array_length(enum_range(NULL, _get_product_summary_result.product_status_enum), 1) - 1;

  RETURN QUERY
  SELECT * FROM _get_product_summary_result;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_product_summary();


DROP FUNCTION IF EXISTS get_tvl_chart_data() CASCADE;

CREATE OR REPLACE FUNCTION get_tvl_chart_data()
RETURNS TABLE
(
  till                          TIMESTAMP WITH TIME ZONE,
  amount                        uint256
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_total_capacity_chart_data_result;

  CREATE TEMPORARY TABLE _get_total_capacity_chart_data_result
  (
    till                          TIMESTAMP WITH TIME ZONE,
    amount                        uint256
  ) ON COMMIT DROP;
  
  INSERT INTO _get_total_capacity_chart_data_result(till)
  SELECT DISTINCT ((to_timestamp(block_timestamp) AT TIME ZONE 'UTC')::date + interval '1 day - 1 sec')::TIMESTAMP WITH TIME ZONE AT TIME ZONE 'UTC'
  FROM core.transactions
  WHERE core.transactions.event_name IN ('CoverPurchased', 'PodsIssued', 'PodsRedeemed', 'Claimed', 'PoolCapitalized');
  
  
  UPDATE _get_total_capacity_chart_data_result
  SET amount = get_tvl_till_date(_get_total_capacity_chart_data_result.till);

  RETURN QUERY
  SELECT * FROM _get_total_capacity_chart_data_result
  ORDER BY 1 ASC;
END
$$
LANGUAGE plpgsql;


-- SELECT  *
-- FROM get_tvl_chart_data();

DROP FUNCTION IF EXISTS get_tvl_distribution();

CREATE FUNCTION get_tvl_distribution()
RETURNS TABLE
(
  chain_id                                            numeric,
  covered                                             numeric,
  commitment                                          numeric,
  cover_fee_earned                                    numeric,
  total_value_locked                                  numeric,
  capacity                                            numeric
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_tvl_distribution_result;
  CREATE TEMPORARY TABLE _get_tvl_distribution_result
  (
    chain_id                                            numeric,
    covered                                             numeric,
    commitment                                          numeric,
    cover_fee_earned                                    numeric,
    total_value_locked                                  numeric,
    capacity                                            numeric
  ) ON COMMIT DROP;
  
  INSERT INTO _get_tvl_distribution_result(chain_id, capacity)
  SELECT capacity_by_chain_view.chain_id, capacity_by_chain_view.total_capacity
  FROM capacity_by_chain_view;
  
  UPDATE _get_tvl_distribution_result
  SET commitment = commitment_by_chain_view.commitment
  FROM commitment_by_chain_view
  WHERE _get_tvl_distribution_result.chain_id = commitment_by_chain_view.chain_id;
  
  UPDATE _get_tvl_distribution_result
  SET covered = total_coverage_by_chain_view.total_coverage
  FROM total_coverage_by_chain_view
  WHERE _get_tvl_distribution_result.chain_id = total_coverage_by_chain_view.chain_id;
  
  UPDATE _get_tvl_distribution_result
  SET cover_fee_earned = fee_earned_by_chain_view.total_fee
  FROM fee_earned_by_chain_view
  WHERE _get_tvl_distribution_result.chain_id = fee_earned_by_chain_view.chain_id;
  
  UPDATE _get_tvl_distribution_result
  SET total_value_locked = total_value_locked_by_chain_view.total
  FROM total_value_locked_by_chain_view
  WHERE _get_tvl_distribution_result.chain_id = total_value_locked_by_chain_view.chain_id;
  
    
  RETURN QUERY
  SELECT * FROM _get_tvl_distribution_result;
END
$$
LANGUAGE plpgsql;


DROP VIEW IF EXISTS protection_by_month_view;

CREATE VIEW protection_by_month_view
AS
WITH info
AS
(
  SELECT
    chain_id,
    expires_on,
    cover_duration AS duration,
    to_char(to_timestamp(expires_on), 'Mon-YY') AS expiry,
    SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS protection,
    SUM(get_stablecoin_value(chain_id, fee)) AS income,
    to_timestamp(expires_on) < NOW() AS expired
  FROM policy.cover_purchased
  GROUP BY chain_id, expires_on, duration
  ORDER BY chain_id, expires_on DESC
),
summary
AS
(  
  SELECT
    chain_id,
    to_timestamp(expires_on) AS expires_on,
    expiry,
    duration,
    protection,
    income,
    expired,
    ((income * 12) / (protection * duration)) AS fee_rate
  FROM info
),
result
AS
(
  SELECT
    chain_id,
    expires_on,
    expiry,
    SUM(protection) AS protection,
    SUM(income) AS income,
    expired,
    AVG(fee_rate) AS fee_rate
  FROM summary
  GROUP BY chain_id, expires_on, expiry, expired
)
SELECT
  result.chain_id,
  config_blockchain_network_view.network_name,
  result.expires_on,
  result.expiry,
  result.protection,
  result.income,
  result.expired,
  result.fee_rate
FROM result
INNER JOIN config_blockchain_network_view
ON config_blockchain_network_view.chain_id = result.chain_id;


DROP VIEW IF EXISTS top_accounts_by_liquidity_view CASCADE;

CREATE VIEW top_accounts_by_liquidity_view
AS
WITH pool_liquidity
AS
(
  SELECT
    account,
    COUNT(*) AS transactions,
    SUM(get_stablecoin_value(chain_id, liquidity_added)) AS added,
    0 AS removed
  FROM vault.pods_issued
  GROUP BY account
  
  UNION ALL
  
  SELECT
    account,
    COUNT(*) AS transactions,
    0 AS added,
    SUM(get_stablecoin_value(chain_id, liquidity_released)) AS removed
  FROM vault.pods_redeemed
  GROUP BY account
)
SELECT 
  account,
  SUM(transactions) AS transactions,
  SUM(COALESCE(added) - COALESCE(removed)) AS liquidity
FROM pool_liquidity
GROUP BY account
ORDER BY liquidity DESC
LIMIT 10;


DROP VIEW IF EXISTS top_accounts_by_protection_view CASCADE;

CREATE VIEW top_accounts_by_protection_view
AS
SELECT
  on_behalf_of,
  COUNT(*) AS policies,
  SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS protection
FROM policy.cover_purchased
WHERE expires_on > extract(epoch FROM NOW() AT TIME ZONE 'UTC')
GROUP BY on_behalf_of
ORDER BY protection DESC
LIMIT 10;


-- Nothing here
DROP VIEW IF EXISTS my_liquidity_view;

CREATE VIEW my_liquidity_view
AS
WITH liquidity_add_txs
AS
(
  SELECT
    vault.pods_issued.chain_id,
    vault.pods_issued.address                   AS vault,
    get_cover_key_by_vault_address
    (
      vault.pods_issued.chain_id,
      vault.pods_issued.address
    )                                           AS cover_key,
    vault.pods_issued.block_timestamp,
    vault.pods_issued.transaction_hash,
    vault.pods_issued.account                   AS account,
    vault.pods_issued.issued                    AS pod_amount,
    vault.npm_staken.amount                     AS npm_amount,
    vault.pods_issued.liquidity_added           AS stablecoin_amount,
    'add'                                       AS tx_type
  FROM vault.pods_issued
  INNER JOIN vault.npm_staken
  ON vault.npm_staken.chain_id                  = vault.pods_issued.chain_id
  AND vault.npm_staken.address                  = vault.pods_issued.address
  AND vault.npm_staken.block_timestamp          = vault.pods_issued.block_timestamp
  AND vault.npm_staken.transaction_hash         = vault.pods_issued.transaction_hash
  AND vault.npm_staken.account                  = vault.pods_issued.account
),
liquidity_remove_txs
AS
(
  SELECT
    vault.pods_redeemed.chain_id,
    vault.pods_redeemed.address                 AS vault,
    get_cover_key_by_vault_address
    (
      vault.pods_redeemed.chain_id,
      vault.pods_redeemed.address
    )                                           AS cover_key,
    vault.pods_redeemed.block_timestamp,
    vault.pods_redeemed.transaction_hash,
    vault.pods_redeemed.account                 AS account,
    vault.pods_redeemed.redeemed                AS pod_amount,
    COALESCE(vault.npm_unstaken.amount, 0)      AS npm_amount,
    vault.pods_redeemed.liquidity_released      AS stablecoin_amount,
    'remove'                                    AS tx_type
  FROM vault.pods_redeemed
  LEFT JOIN vault.npm_unstaken
  ON vault.npm_unstaken.chain_id                = vault.pods_redeemed.chain_id
  AND vault.npm_unstaken.address                = vault.pods_redeemed.address
  AND vault.npm_unstaken.block_timestamp        = vault.pods_redeemed.block_timestamp
  AND vault.npm_unstaken.transaction_hash       = vault.pods_redeemed.transaction_hash
  AND vault.npm_unstaken.account                = vault.pods_redeemed.account
),
liquidity_txs
AS
(
  SELECT *, get_products_of(chain_id, cover_key) AS product_keys FROM liquidity_add_txs
  UNION ALL
  SELECT *, get_products_of(chain_id, cover_key) AS product_keys FROM liquidity_remove_txs
)
SELECT
  liquidity_txs.chain_id,
  liquidity_txs.vault,
  liquidity_txs.cover_key,
  liquidity_txs.block_timestamp,
  liquidity_txs.transaction_hash,
  liquidity_txs.account,
  liquidity_txs.pod_amount,
  liquidity_txs.npm_amount,
  liquidity_txs.stablecoin_amount,
  liquidity_txs.tx_type,
  factory.vault_deployed.name                         AS token_name,
  factory.vault_deployed.symbol                       AS token_symbol,
  liquidity_txs.product_keys
FROM liquidity_txs
INNER JOIN factory.vault_deployed
ON factory.vault_deployed.chain_id                    = liquidity_txs.chain_id
AND factory.vault_deployed.cover_key                  = liquidity_txs.cover_key
AND factory.vault_deployed.vault                      = liquidity_txs.vault;
DROP VIEW IF EXISTS active_policies_view;

CREATE VIEW active_policies_view
AS
SELECT
  chain_id,
  cover_key,
  bytes32_to_string(cover_key)                                AS cover_key_string,
  product_key,
  bytes32_to_string(product_key)                              AS product_key_string,
  cx_token,
  expires_on,
  on_behalf_of,
  SUM(get_stablecoin_value(chain_id, amount_to_cover))        AS amount,
  get_active_product_status
  (
    chain_id,
    cover_key,
    product_key
  )                                                           AS product_status_enum,
  array_length(
    enum_range(NULL,  get_active_product_status(chain_id, cover_key, product_key)),
    1
  ) - 1                                                       AS product_status,
  (get_cover_info(chain_id, cover_key)).*,
  (get_product_info(chain_id, cover_key, product_key)).*,
  get_active_incident_date(chain_id, cover_key, product_key)  AS incident_date,
  (get_report_insight(
    chain_id,
    cover_key,
    product_key,
    get_active_incident_date(chain_id, cover_key, product_key)
  )).claim_begins_from,
  (get_report_insight(
    chain_id,
    cover_key,
    product_key,
    get_active_incident_date(chain_id, cover_key, product_key)
  )).claim_expires_at
FROM policy.cover_purchased
WHERE expires_on > extract(epoch FROM NOW() AT TIME ZONE 'UTC')
GROUP BY 
  chain_id,
  cover_key,
  product_key,
  cx_token,
  expires_on,
  on_behalf_of;

-- SELECT * FROM active_policies_view
-- WHERE on_behalf_of = '0x201bcc0d375f10543e585fbb883b36c715c959b3'
-- AND chain_id = 84531
DROP VIEW IF EXISTS cover_purchase_view;

CREATE VIEW cover_purchase_view
AS
SELECT
  transaction_hash,
  chain_id,
  cover_key,
  bytes32_to_string(cover_key) AS cover_key_string,
  product_key,
  bytes32_to_string(product_key) AS product_key_string,
  on_behalf_of,
  cover_duration,
  referral_code,
  cx_token,
  fee,
  policy_id,
  expires_on,
  amount_to_cover,
  get_active_product_status(chain_id, cover_key, product_key) AS product_status_enum,
  array_length(enum_range(NULL,  get_active_product_status(chain_id, cover_key, product_key)), 1) - 1 AS product_status,
  (get_cover_info(chain_id, cover_key)).*,
  (get_product_info(chain_id, cover_key, product_key)).*
FROM policy.cover_purchased;



DROP VIEW IF EXISTS expired_policies_view;

CREATE VIEW expired_policies_view
AS
WITH summary
AS
(
  SELECT
    chain_id,
    cover_key,
    product_key,
    on_behalf_of,
    block_timestamp,
    expires_on,
    cx_token,
    get_incident_date_by_expiry_date
    (
      chain_id,
      cover_key,
      product_key,
      block_timestamp,
      expires_on
    )                                                   AS incident_date,
    get_stablecoin_value(chain_id, amount_to_cover)     AS amount_to_cover
  FROM policy.cover_purchased
  WHERE expires_on <= extract(epoch FROM NOW() AT TIME ZONE 'UTC')
)
SELECT
  chain_id,
  cover_key,
  bytes32_to_string(cover_key)            AS cover_key_string,
  product_key,
  bytes32_to_string(product_key)          AS product_key_string,
  cx_token,
  expires_on,
  on_behalf_of,
  SUM(amount_to_cover)                    AS amount,
  incident_date,
  get_product_status
  (
      chain_id,
      cover_key,
      product_key,
      incident_date
  )                                       AS product_status_enum,
  array_length(
    enum_range(
      NULL,  
      get_product_status
      (
          chain_id,
          cover_key,
          product_key,
          incident_date
      )
    ),
    1
  ) - 1                                         AS product_status,
  (get_cover_info(chain_id, cover_key)).*,
  (get_product_info(chain_id, cover_key, product_key)).*
FROM summary
GROUP BY
  chain_id,
  cover_key,
  product_key,
  on_behalf_of,
  cx_token,
  expires_on, 
  incident_date;

-- SELECT * FROM expired_policies_view
-- WHERE on_behalf_of = '0x201bcc0d375f10543e585fbb883b36c715c959b3'
-- AND chain_id = 84531
DROP VIEW IF EXISTS my_policies_view;

CREATE VIEW my_policies_view
AS
WITH policy_txs
AS
(
  SELECT
    chain_id,
    cover_key,
    product_key,
    block_timestamp,
    cx_token,
    transaction_hash,
    on_behalf_of                                        AS account,
    get_stablecoin_value(chain_id, amount_to_cover)     AS cxtoken_amount,
    get_stablecoin_value(chain_id, fee)                 AS stablecoin_amount,
    'cover_purchased'                                   AS tx_type
  FROM policy.cover_purchased
  UNION ALL
  SELECT
    chain_id,
    cover_key,
    product_key,
    block_timestamp,
    cx_token,
    transaction_hash,
    account                                     AS account,
    wei_to_ether(amount)                        AS cxtoken_amount,
    wei_to_ether(claimed)                       AS stablecoin_amount,
    'claimed'                                   AS tx_type
  FROM cxtoken.claimed
)

SELECT
  policy_txs.chain_id,
  policy_txs.cover_key,
  policy_txs.product_key,
  policy_txs.block_timestamp,
  policy_txs.cx_token,
  policy_txs.transaction_hash,
  policy_txs.account,
  policy_txs.cxtoken_amount,
  policy_txs.stablecoin_amount,
  policy_txs.tx_type,
  bytes32_to_string(policy_txs.cover_key)       AS cover_key_string,
  bytes32_to_string(policy_txs.product_key)     AS product_key_string,
  'cxUSD'                                       AS token_symbol,
  factory.cx_token_deployed.token_name
FROM policy_txs
INNER JOIN factory.cx_token_deployed
ON factory.cx_token_deployed.chain_id           = policy_txs.chain_id
AND factory.cx_token_deployed.cover_key         = policy_txs.cover_key
AND factory.cx_token_deployed.product_key       = policy_txs.product_key
AND factory.cx_token_deployed.cx_token          = policy_txs.cx_token;

DROP VIEW IF EXISTS votes_view;

CREATE VIEW votes_view
AS
WITH vote_txs
AS
(
  SELECT
    chain_id,
    cover_key,
    product_key,
    incident_date,
    block_timestamp,
    transaction_hash,
    witness,
    stake,
    'attested'                                AS tx_type
  FROM consensus.attested
  UNION ALL
  SELECT
    chain_id,
    cover_key,
    product_key,
    incident_date,
    block_timestamp,
    transaction_hash,
    witness,
    stake,
    'refuted'                                 AS tx_type
  FROM consensus.refuted
)
SELECT
  *,
  bytes32_to_string(cover_key)                AS cover_key_string,
  bytes32_to_string(product_key)              AS product_key_string
FROM vote_txs;

DROP FUNCTION IF EXISTS get_cover_stats
(
  _chain_id                               uint256,
  _cover_key                              bytes32,
  _product_key                            bytes32,
  _account                                address
);

CREATE FUNCTION get_cover_stats
(
  _chain_id                               uint256,
  _cover_key                              bytes32,
  _product_key                            bytes32,
  _account                                address
)
RETURNS TABLE
(
  cover_key                               bytes32,
  cover_key_string                        text,
  product_key                             bytes32,
  product_key_string                      text,
  tvl                                     numeric,
  active_commitment                       numeric,
  available_for_underwriting              numeric,
  capacity                                numeric,
  coverage_lag                            numeric,
  policy_rate_floor                       integer,
  policy_rate_ceiling                     integer,
  reporter_commission                     integer,
  claim_platform_fee                      integer,
  reporting_period                        integer,
  product_status_enum                     product_status_type,
  product_status                          integer,
  min_reporting_stake                     numeric,
  active_incident_date                    integer,
  requires_whitelist                      boolean,
  is_user_whitelisted                     boolean
)
AS
$$
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;

  DROP TABLE IF EXISTS _get_cover_stats_result CASCADE;
  CREATE TEMPORARY TABLE _get_cover_stats_result
  (
    cover_key                               bytes32,
    cover_key_string                        text,
    product_key                             bytes32,
    product_key_string                      text,
    tvl                                     numeric,
    active_commitment                       numeric DEFAULT 0,
    available_for_underwriting              numeric,
    capacity                                numeric,
    coverage_lag                            numeric,
    policy_rate_floor                       integer,
    policy_rate_ceiling                     integer,
    reporter_commission                     integer,
    claim_platform_fee                      integer,
    reporting_period                        integer,
    product_status_enum                     product_status_type,
    product_status                          integer,
    min_reporting_stake                     numeric,
    active_incident_date                    integer,
    requires_whitelist                      boolean,
    is_user_whitelisted                     boolean
  ) ON COMMIT DROP;
  
  INSERT INTO _get_cover_stats_result
  (
    cover_key,
    cover_key_string,
    product_key,
    product_key_string,
    tvl,
    capacity,
    coverage_lag,
    policy_rate_floor,
    policy_rate_ceiling,
    reporter_commission,
    claim_platform_fee,
    product_status_enum,
    min_reporting_stake,
    active_incident_date,
    is_user_whitelisted
  )
  SELECT
    _cover_key,
    bytes32_to_string(_cover_key),
    _product_key,
    bytes32_to_string(_product_key),
    get_tvl_till_date(_chain_id, _cover_key, 'infinity'),
    get_cover_capacity_till(_chain_id, _cover_key, _product_key, 'infinity'),
    get_coverage_lag(_chain_id, _cover_key),
    get_policy_floor(_chain_id, _cover_key),
    get_policy_ceiling(_chain_id, _cover_key),
    get_reporter_commission(_chain_id),
    get_claim_platform_fee(_chain_id),
    get_active_product_status(_chain_id, _cover_key, _product_key),
    get_min_first_reporting_stake(_chain_id, _cover_key),
    get_active_incident_date(_chain_id, _cover_key, _product_key),
    check_if_user_whitelisted(_chain_id, _cover_key, _product_key, _account);
  
  UPDATE _get_cover_stats_result
  SET active_commitment = product_commitment_view.commitment
  FROM product_commitment_view
  WHERE product_commitment_view.chain_id = _chain_id
  AND product_commitment_view.cover_key = _cover_key
  AND product_commitment_view.product_key = _product_key;
  
  
  UPDATE _get_cover_stats_result
  SET requires_whitelist = 
  (
    SELECT cover.cover_created.requires_whitelist
    FROM cover.cover_created
    WHERE cover.cover_created.chain_id = _chain_id
    AND cover.cover_created.cover_key = _cover_key
  );
  
  UPDATE _get_cover_stats_result
  SET 
    available_for_underwriting = _get_cover_stats_result.capacity - _get_cover_stats_result.active_commitment,
    product_status = array_length(enum_range(NULL, _get_cover_stats_result.product_status_enum), 1) - 1;

  UPDATE _get_cover_stats_result
  SET reporting_period = 
  (
    SELECT config_cover_view.reporting_period
    FROM config_cover_view
    WHERE config_cover_view.chain_id = _chain_id
    AND config_cover_view.cover_key = _cover_key
    LIMIT 1
  );

  RETURN QUERY
  SELECT * FROM _get_cover_stats_result;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_cover_stats(84531,'0x7072696d65000000000000000000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000001');

DROP FUNCTION IF EXISTS get_protocol_contracts_metadata(_chain_id uint256) CASCADE;

CREATE FUNCTION get_protocol_contracts_metadata(_chain_id uint256)
RETURNS TABLE
(
  chain_id                              uint256,
  network                               text,
  contracts                             jsonb,
  pods                                  jsonb,
  cx_tokens                             jsonb,
  cover_keys                            text[]
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_protocol_contracts_metadata_result CASCADE;
  CREATE TEMPORARY TABLE _get_protocol_contracts_metadata_result
  (
    chain_id                              uint256,
    network                               text,
    contracts                             jsonb,
    pods                                  jsonb,
    cx_tokens                             jsonb,
    cover_keys                            text[]
  ) ON COMMIT DROP;
  
  INSERT INTO _get_protocol_contracts_metadata_result(chain_id, contracts)
  SELECT all_contracts.chain_id, jsonb_agg(json_build_object('key', all_contracts.contract_name, 'value', all_contracts.contract_address))
  FROM get_protocol_contracts() AS all_contracts
  WHERE all_contracts.namespace NOT IN ('cns:cover:vault')
  AND all_contracts.chain_id = _chain_id
  GROUP BY all_contracts.chain_id;
  
  WITH all_pods
  AS
  (
    SELECT
      factory.vault_deployed.chain_id,
      jsonb_agg(json_build_object('key', factory.vault_deployed.cover_key, 'value', factory.vault_deployed.vault)) AS pods
    FROM factory.vault_deployed
    GROUP BY factory.vault_deployed.chain_id
  )
  UPDATE _get_protocol_contracts_metadata_result
  SET pods = all_pods.pods
  FROM all_pods
  WHERE all_pods.chain_id = _get_protocol_contracts_metadata_result.chain_id;
  
  
  WITH all_cx_tokens
  AS
  (
    SELECT
      factory.cx_token_deployed.chain_id,
      jsonb_agg
      (
        json_build_object(
          'coverKey',
          factory.cx_token_deployed.cover_key,
          'expiry',
          factory.cx_token_deployed.expiry_date,
          'productKey',
          factory.cx_token_deployed.product_key,
          'value',
          factory.cx_token_deployed.cx_token
        )
      ) AS cx_tokens
    FROM factory.cx_token_deployed
    GROUP BY factory.cx_token_deployed.chain_id
  )
  UPDATE _get_protocol_contracts_metadata_result
  SET cx_tokens = all_cx_tokens.cx_tokens
  FROM all_cx_tokens
  WHERE all_cx_tokens.chain_id = _get_protocol_contracts_metadata_result.chain_id;

  UPDATE _get_protocol_contracts_metadata_result
  SET cover_keys =
  (
    SELECT ARRAY_AGG(DISTINCT factory.cx_token_deployed.cover_key)
    FROM factory.cx_token_deployed
  );

  UPDATE _get_protocol_contracts_metadata_result
  SET network = config_blockchain_network_view.network_name
  FROM config_blockchain_network_view
  WHERE config_blockchain_network_view.chain_id = _get_protocol_contracts_metadata_result.chain_id;
  
  UPDATE _get_protocol_contracts_metadata_result
  SET cx_tokens = '[]'::jsonb
  WHERE _get_protocol_contracts_metadata_result.cx_tokens IS NULL;
  
  UPDATE _get_protocol_contracts_metadata_result
  SET cover_keys = '{}'
  WHERE _get_protocol_contracts_metadata_result.cover_keys IS NULL;

  RETURN QUERY
  SELECT * FROM _get_protocol_contracts_metadata_result;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_protocol_contracts_metadata(1);





GRANT USAGE ON SCHEMA vault TO readonlyuser;
GRANT USAGE ON SCHEMA ve TO readonlyuser;
GRANT USAGE ON SCHEMA strategy TO readonlyuser;
GRANT USAGE ON SCHEMA store TO readonlyuser;
GRANT USAGE ON SCHEMA staking TO readonlyuser;
GRANT USAGE ON SCHEMA reassurance TO readonlyuser;
GRANT USAGE ON SCHEMA public TO readonlyuser;
GRANT USAGE ON SCHEMA protocol TO readonlyuser;
GRANT USAGE ON SCHEMA policy TO readonlyuser;
GRANT USAGE ON SCHEMA factory TO readonlyuser;
GRANT USAGE ON SCHEMA cxtoken TO readonlyuser;
GRANT USAGE ON SCHEMA cover TO readonlyuser;
GRANT USAGE ON SCHEMA core TO readonlyuser;
GRANT USAGE ON SCHEMA consensus TO readonlyuser;
GRANT USAGE ON SCHEMA claim TO readonlyuser;
GRANT USAGE ON SCHEMA nft TO readonlyuser;

GRANT SELECT ON ALL TABLES IN SCHEMA factory TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA strategy TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA reassurance TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA cxtoken TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA policy TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA consensus TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA vault TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA ve TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA protocol TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA cover TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA staking TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA store TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA claim TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA nft TO readonlyuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft GRANT SELECT ON TABLES TO readonlyuser;

REVOKE CREATE ON SCHEMA factory FROM readonlyuser;
REVOKE CREATE ON SCHEMA strategy FROM readonlyuser;
REVOKE CREATE ON SCHEMA core FROM readonlyuser;
REVOKE CREATE ON SCHEMA reassurance FROM readonlyuser;
REVOKE CREATE ON SCHEMA cxtoken FROM readonlyuser;
REVOKE CREATE ON SCHEMA policy FROM readonlyuser;
REVOKE CREATE ON SCHEMA consensus FROM readonlyuser;
REVOKE CREATE ON SCHEMA vault FROM readonlyuser;
REVOKE CREATE ON SCHEMA ve FROM readonlyuser;
REVOKE CREATE ON SCHEMA protocol FROM readonlyuser;
REVOKE CREATE ON SCHEMA cover FROM readonlyuser;
REVOKE CREATE ON SCHEMA staking FROM readonlyuser;
REVOKE CREATE ON SCHEMA store FROM readonlyuser;
REVOKE CREATE ON SCHEMA claim FROM readonlyuser;
REVOKE CREATE ON SCHEMA nft FROM readonlyuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;

GRANT CREATE ON SCHEMA public TO writeuser;
GRANT CREATE ON SCHEMA factory TO writeuser;
GRANT CREATE ON SCHEMA strategy TO writeuser;
GRANT CREATE ON SCHEMA core TO writeuser;
GRANT CREATE ON SCHEMA reassurance TO writeuser;
GRANT CREATE ON SCHEMA cxtoken TO writeuser;
GRANT CREATE ON SCHEMA policy TO writeuser;
GRANT CREATE ON SCHEMA consensus TO writeuser;
GRANT CREATE ON SCHEMA vault TO writeuser;
GRANT CREATE ON SCHEMA ve TO writeuser;
GRANT CREATE ON SCHEMA protocol TO writeuser;
GRANT CREATE ON SCHEMA cover TO writeuser;
GRANT CREATE ON SCHEMA staking TO writeuser;
GRANT CREATE ON SCHEMA store TO writeuser;
GRANT CREATE ON SCHEMA claim TO writeuser;
GRANT CREATE ON SCHEMA nft TO writeuser;

GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA factory TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA strategy TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA core TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA reassurance TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA cxtoken TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA policy TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA consensus TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA vault TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA ve TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA protocol TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA cover TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA staking TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA store TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA claim TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA nft TO writeuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft GRANT INSERT, UPDATE ON TABLES TO writeuser;
DROP FUNCTION IF EXISTS get_explorer_home
(
  _sort_by                                        text,
  _sort_direction                                 text,
  _page_number                                    integer,
  _page_size                                      integer,
  _date_from                                      TIMESTAMP WITH TIME ZONE,
  _date_to                                        TIMESTAMP WITH TIME ZONE,
  _networks                                       numeric[],
  _contracts                                      text[],
  _cover_key_like                                 text,
  _event_name_like                                text,
  _coupon_code_like                               text
);

CREATE FUNCTION get_explorer_home
(
  _sort_by                                        text,
  _sort_direction                                 text,
  _page_number                                    integer,
  _page_size                                      integer,
  _date_from                                      TIMESTAMP WITH TIME ZONE,
  _date_to                                        TIMESTAMP WITH TIME ZONE,
  _networks                                       numeric[],
  _contracts                                      text[],
  _cover_key_like                                 text,
  _event_name_like                                text,
  _coupon_code_like                               text
)
RETURNS TABLE
(
  id                                              uuid,
  chain_id                                        uint256,
  date                                            TIMESTAMP WITH TIME ZONE,
  event_name                                      text,
  coupon_code                                     text,
  transaction_sender                              address,
  cover_key                                       bytes32,
  product_key                                     bytes32,
  transaction_stablecoin_amount                   uint256,
  transaction_npm_amount                          uint256,
  page_size                                       integer,
  page_number                                     integer,
  total_records                                   integer,
  total_pages                                     integer
)
STABLE
AS
$$
  DECLARE _total_records                          integer;
  DECLARE _total_pages                            integer;
  DECLARE _query                                  text;
BEGIN
  IF(COALESCE(_sort_direction, '') = '') THEN
    _sort_direction := 'ASC';
  END IF;
  
  IF(_sort_direction NOT IN ('ASC', 'DESC')) THEN
    RAISE EXCEPTION 'Access is denied. Invalid sort_direction: "%"', _sort_direction; --SQL Injection Attack
  END IF;

  IF(_networks IS NULL) THEN
    _networks := array_agg(DISTINCT core.transactions.chain_id) FROM core.transactions;
  END IF;

  IF(_contracts IS NULL) THEN
    _contracts := array_agg(DISTINCT core.transactions.address) FROM core.transactions;  
  END IF;

  IF (_sort_by NOT IN('chain_id', 'date', 'event_name', 'coupon_code', 'transaction_sender', 'ck', 'pk')) THEN
    RAISE EXCEPTION 'Access is denied. Invalid sort_by: "%"', _sort_by; --SQL Injection Attack
  END IF;
  
  IF(_sort_by = 'date') THEN
    _sort_by := 'block_timestamp';
  END IF;
      
  IF(_page_number < 1) THEN
    RAISE EXCEPTION 'Invalid page_number value %', _page_number;  
  END IF;
  
  IF(_page_size < 1) THEN
    RAISE EXCEPTION 'Invalid _page_size value %', _page_size;  
  END IF;
  
  
  _query := format('
  WITH result AS
  (
    SELECT * FROM core.transactions
    WHERE core.transactions.block_timestamp
      BETWEEN EXTRACT(epoch FROM COALESCE(%L, ''1-1-1990''::date))
      AND EXTRACT(epoch FROM COALESCE(%L, ''1-1-2990''::date))
    AND core.transactions.chain_id = ANY(%L)
    AND core.transactions.address = ANY(%L)
    AND 
    (
      REPLACE(bytes32_to_string(core.transactions.ck), ''-'', '''') ILIKE %s
      OR 
      REPLACE(bytes32_to_string(core.transactions.pk), ''-'', '''') ILIKE %s
    )
    AND core.transactions.event_name ILIKE %s
    AND bytes32_to_string(core.transactions.coupon_code) ILIKE %s
  )
  SELECT COUNT(*) FROM result;', _date_from, _date_to, _networks, _contracts, quote_literal_ilike(_cover_key_like), quote_literal_ilike(_cover_key_like), quote_literal_ilike(_event_name_like), quote_literal_ilike(_coupon_code_like));
  
  -- RAISE NOTICE '%', _query;

  EXECUTE _query
  INTO _total_records;
  
  
  _total_pages = COALESCE(CEILING(_total_records::numeric / _page_size), 0);
  
   _query := format('
    SELECT
    core.transactions.id,
    core.transactions.chain_id,
    to_timestamp(core.transactions.block_timestamp)::TIMESTAMP WITH TIME ZONE AS date,
    core.transactions.event_name,
    CASE 
      WHEN core.transactions.coupon_code = string_to_bytes32('''')
      THEN NULL 
      ELSE core.transactions.coupon_code 
    END AS coupon_code,
    core.transactions.transaction_sender,
    core.transactions.ck::bytes32 AS cover_key,
    core.transactions.pk::bytes32 AS product_key,
    core.transactions.transaction_stablecoin_amount,
    core.transactions.transaction_npm_amount,
    %s AS page_size,
    %s AS page_number,
    %s AS total_records,
    %s AS total_pages
  FROM core.transactions
  WHERE core.transactions.block_timestamp
    BETWEEN EXTRACT(epoch FROM COALESCE(%L, ''1-1-1990''::date))
    AND EXTRACT(epoch FROM COALESCE(%L, ''1-1-2990''::date))
  AND core.transactions.chain_id = ANY(%L)
  AND core.transactions.address = ANY(%L)
  AND 
  (
    REPLACE(bytes32_to_string(core.transactions.ck), ''-'', '''') ILIKE %s
    OR 
    REPLACE(bytes32_to_string(core.transactions.pk), ''-'', '''') ILIKE %s
  )
  AND core.transactions.event_name ILIKE %s
  AND bytes32_to_string(core.transactions.coupon_code) ILIKE %s
  ORDER BY %I %s
  LIMIT %s::integer
  OFFSET %s::integer * %s::integer  
  ', _page_size, _page_number, _total_records, _total_pages, _date_from, _date_to, _networks, _contracts, quote_literal_ilike(_cover_key_like), quote_literal_ilike(_cover_key_like), quote_literal_ilike(_event_name_like), quote_literal_ilike(_coupon_code_like), _sort_by, _sort_direction, _page_size, _page_number - 1, _page_size);

  --RAISE NOTICE '%', _query;
  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;


-- SELECT * FROM get_explorer_home
-- (
--   'date', --_sort_by                                        text,
--   'DESC', --_sort_direction                                 text,
--   1, --_page_number                                    integer,
--   2, --_page_size                                      integer,
--   NULL, --_date_from                                      TIMESTAMP WITH TIME ZONE,
--   '1-1-2099'::date, --_date_to                                        TIMESTAMP WITH TIME ZONE,
--   NULL, --_networks                                       numeric[],
--   NULL, --_contracts                                      text[],
--   NULL,-- _cover_key_like                                 text,
--   'Added', --_event_name_like                                text,
--   '' --_coupon_code_like                               text
-- );

DROP FUNCTION IF EXISTS get_explorer_stats();

CREATE FUNCTION get_explorer_stats()
RETURNS TABLE
(
  transaction_count                                 integer,
  policy_purchased                                  numeric,
  liquidity_added                                   numeric,
  liquidity_removed                                 numeric,
  claimed                                           numeric,
  staked                                            numeric
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_explorer_stats_result;
  CREATE TEMPORARY TABLE _get_explorer_stats_result
  (
    transaction_count                                 integer,
    policy_purchased                                  numeric,
    liquidity_added                                   numeric,
    liquidity_removed                                 numeric,
    claimed                                           numeric,
    staked                                            numeric
  ) ON COMMIT DROP;
  
  INSERT INTO _get_explorer_stats_result(transaction_count)
  SELECT COUNT(*)
  FROM core.transactions;
  
  UPDATE _get_explorer_stats_result
  SET policy_purchased = 
  COALESCE((
    SELECT SUM(get_stablecoin_value(policy.cover_purchased.chain_id, policy.cover_purchased.amount_to_cover))
    FROM policy.cover_purchased
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET liquidity_added =
  COALESCE((
    SELECT SUM(get_stablecoin_value(vault.pods_issued.chain_id, vault.pods_issued.liquidity_added))
    FROM vault.pods_issued
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET liquidity_removed =
  COALESCE((
    SELECT SUM(get_stablecoin_value(vault.pods_redeemed.chain_id, vault.pods_redeemed.liquidity_released))
    FROM vault.pods_redeemed
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET claimed =
  COALESCE((
    SELECT SUM(wei_to_ether(cxtoken.claimed.amount))
    FROM cxtoken.claimed
  ), 0);

  UPDATE _get_explorer_stats_result
  SET staked =
  COALESCE((
    SELECT SUM(get_npm_value(amount))
    FROM cover.stake_added
  ), 0);

  UPDATE _get_explorer_stats_result
  SET staked = COALESCE(_get_explorer_stats_result.staked, 0) -
  COALESCE((
    SELECT SUM(get_npm_value(amount))
    FROM cover.stake_removed
  ), 0);
  
  RETURN QUERY
  SELECT * FROM _get_explorer_stats_result;
END
$$
LANGUAGE plpgsql;
DROP FUNCTION IF EXISTS get_protocol_contracts();

CREATE FUNCTION get_protocol_contracts()
RETURNS TABLE
(
  chain_id                                          uint256,
  namespace                                         text,
  contract_name                                     text,
  contract_address                                  text,
  added_on                                          integer,
  transaction_hash                                  text
)
AS
$$
  DECLARE _r                                        RECORD;
BEGIN
  DROP TABLE IF EXISTS _get_protocol_contracts_result;

  CREATE TEMPORARY TABLE _get_protocol_contracts_result
  (
    chain_id                                          uint256,
    namespace                                         text,
    contract_name                                     text,
    contract_address                                  text,
    added_on                                          integer,
    transaction_hash                                  text
  ) ON COMMIT DROP;

  INSERT INTO _get_protocol_contracts_result(chain_id, namespace, contract_address, added_on, transaction_hash)
  SELECT
    protocol.contract_added.chain_id,
    protocol.contract_added.namespace,
    protocol.contract_added.contract_address,
    protocol.contract_added.block_timestamp,
    protocol.contract_added.transaction_hash
  FROM protocol.contract_added;

  INSERT INTO _get_protocol_contracts_result(chain_id, namespace, contract_name, contract_address, added_on, transaction_hash)
  SELECT
    cover.cover_initialized.chain_id,
    'cns:cover:sc',
    'Stablecoin',
    cover.cover_initialized.stablecoin,
    cover.cover_initialized.block_timestamp,
    cover.cover_initialized.transaction_hash
  FROM cover.cover_initialized;

  INSERT INTO _get_protocol_contracts_result(chain_id, namespace, contract_name, contract_address)
  SELECT
    config_blockchain_network_view.chain_id,
    null,
    'Store',
    config_blockchain_network_view.store_address
  FROM config_blockchain_network_view;

  INSERT INTO _get_protocol_contracts_result(chain_id, namespace, contract_name, contract_address)
  SELECT
    config_blockchain_network_view.chain_id,
    'cns:core',
    'Protocol',
    config_blockchain_network_view.protocol_address
  FROM config_blockchain_network_view;

  INSERT INTO _get_protocol_contracts_result(chain_id, namespace, contract_name, contract_address)
  SELECT
    config_blockchain_network_view.chain_id,
    'cns:core:npm:instance',
    'NPM',
    config_blockchain_network_view.npm_address
  FROM config_blockchain_network_view;

  FOR _r IN
  (
    SELECT * FROM protocol.contract_upgraded
    ORDER BY protocol.contract_upgraded.block_timestamp ASC
  )
  LOOP
    UPDATE _get_protocol_contracts_result
    SET
      contract_address = _r.current,
      added_on = _r.block_timestamp,
      transaction_hash = _r.transaction_hash
    FROM _r
    WHERE _r.chain_id = _get_protocol_contracts_result.chain_id
    AND _r.namespace = _get_protocol_contracts_result.namespace;
  END LOOP;


  UPDATE _get_protocol_contracts_result
  SET contract_name = config_contract_namespace_view.contract_name
  FROM config_contract_namespace_view
  WHERE config_contract_namespace_view.namespace = _get_protocol_contracts_result.namespace;

  RETURN QUERY
  SELECT * FROM _get_protocol_contracts_result;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_protocol_contracts();

GRANT USAGE ON SCHEMA vault TO readonlyuser;
GRANT USAGE ON SCHEMA ve TO readonlyuser;
GRANT USAGE ON SCHEMA strategy TO readonlyuser;
GRANT USAGE ON SCHEMA store TO readonlyuser;
GRANT USAGE ON SCHEMA staking TO readonlyuser;
GRANT USAGE ON SCHEMA reassurance TO readonlyuser;
GRANT USAGE ON SCHEMA public TO readonlyuser;
GRANT USAGE ON SCHEMA protocol TO readonlyuser;
GRANT USAGE ON SCHEMA policy TO readonlyuser;
GRANT USAGE ON SCHEMA factory TO readonlyuser;
GRANT USAGE ON SCHEMA cxtoken TO readonlyuser;
GRANT USAGE ON SCHEMA cover TO readonlyuser;
GRANT USAGE ON SCHEMA core TO readonlyuser;
GRANT USAGE ON SCHEMA consensus TO readonlyuser;
GRANT USAGE ON SCHEMA claim TO readonlyuser;
GRANT USAGE ON SCHEMA nft TO readonlyuser;

GRANT SELECT ON ALL TABLES IN SCHEMA factory TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA strategy TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA reassurance TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA cxtoken TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA policy TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA consensus TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA vault TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA ve TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA protocol TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA cover TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA staking TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA store TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA claim TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA nft TO readonlyuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft GRANT SELECT ON TABLES TO readonlyuser;

REVOKE CREATE ON SCHEMA factory FROM readonlyuser;
REVOKE CREATE ON SCHEMA strategy FROM readonlyuser;
REVOKE CREATE ON SCHEMA core FROM readonlyuser;
REVOKE CREATE ON SCHEMA reassurance FROM readonlyuser;
REVOKE CREATE ON SCHEMA cxtoken FROM readonlyuser;
REVOKE CREATE ON SCHEMA policy FROM readonlyuser;
REVOKE CREATE ON SCHEMA consensus FROM readonlyuser;
REVOKE CREATE ON SCHEMA vault FROM readonlyuser;
REVOKE CREATE ON SCHEMA ve FROM readonlyuser;
REVOKE CREATE ON SCHEMA protocol FROM readonlyuser;
REVOKE CREATE ON SCHEMA cover FROM readonlyuser;
REVOKE CREATE ON SCHEMA staking FROM readonlyuser;
REVOKE CREATE ON SCHEMA store FROM readonlyuser;
REVOKE CREATE ON SCHEMA claim FROM readonlyuser;
REVOKE CREATE ON SCHEMA nft FROM readonlyuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;

GRANT CREATE ON SCHEMA public TO writeuser;
GRANT CREATE ON SCHEMA factory TO writeuser;
GRANT CREATE ON SCHEMA strategy TO writeuser;
GRANT CREATE ON SCHEMA core TO writeuser;
GRANT CREATE ON SCHEMA reassurance TO writeuser;
GRANT CREATE ON SCHEMA cxtoken TO writeuser;
GRANT CREATE ON SCHEMA policy TO writeuser;
GRANT CREATE ON SCHEMA consensus TO writeuser;
GRANT CREATE ON SCHEMA vault TO writeuser;
GRANT CREATE ON SCHEMA ve TO writeuser;
GRANT CREATE ON SCHEMA protocol TO writeuser;
GRANT CREATE ON SCHEMA cover TO writeuser;
GRANT CREATE ON SCHEMA staking TO writeuser;
GRANT CREATE ON SCHEMA store TO writeuser;
GRANT CREATE ON SCHEMA claim TO writeuser;
GRANT CREATE ON SCHEMA nft TO writeuser;

GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA factory TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA strategy TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA core TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA reassurance TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA cxtoken TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA policy TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA consensus TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA vault TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA ve TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA protocol TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA cover TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA staking TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA store TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA claim TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA nft TO writeuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft GRANT INSERT, UPDATE ON TABLES TO writeuser;
CREATE OR REPLACE FUNCTION add_nft(_metadata jsonb)
RETURNS uuid
AS
$$
  DECLARE _id                         uuid;
BEGIN
  SELECT nfts.id INTO _id
  FROM nfts
  WHERE nfts.token_id = (_metadata->'edition')::uint256;

  IF(_id IS NOT NULL) THEN
    RETURN _id;
  END IF;

  INSERT INTO nfts
  (
    token_id,
    name,
    description,
    url,
    image,
    external_url,
    date_published,
    soulbound,
    attributes,
    properties
  )
  SELECT
    (_metadata->>'edition')::uint256,
    (_metadata->>'name')::text,
    (_metadata->>'description')::text,
    (_metadata->>'url')::text,
    (_metadata->>'image')::text,
    (_metadata->>'external_url')::text,
    (_metadata->>'date')::uint256,
    (_metadata->'properties'->'info'->>'soulbound')::boolean,
    _metadata->'attributes',
    _metadata->'properties'
  RETURNING id INTO _id;

  WITH nft_attributes
  AS
  (
    SELECT id, jsonb_array_elements(attributes) AS values
    FROM nfts
    WHERE nfts.id = _id
  ),
  nicknames
  AS
  (
    SELECT id, values->>'value' AS nickname
    FROM nft_attributes
    WHERE values->>'trait_type' = 'Nickname'
  )
  UPDATE nfts
  SET nickname = nicknames.nickname
  FROM nicknames
  WHERE nfts.id = nicknames.id;

  WITH nft_attributes
  AS
  (
    SELECT id, jsonb_array_elements(attributes) AS values
    FROM nfts
    WHERE nfts.id = _id
  ),
  families
  AS
  (
    SELECT id, values->>'value' AS family
    FROM nft_attributes
    WHERE values->>'trait_type' = 'Family'
  )
  UPDATE nfts
  SET family = families.family
  FROM families
  WHERE nfts.id = families.id;

  RETURN _id;
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_nft_name_info(_token_ids uint256[])
RETURNS jsonb
AS
$$
BEGIN
  RETURN
  (
    WITH intermediate
    AS
    (
      SELECT nfts.name, nfts.token_id
      FROM nfts
      WHERE token_id = ANY(_token_ids)
    )
    SELECT jsonb_agg(intermediate) FROM intermediate
  );
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_owner(_token_id uint256)
RETURNS jsonb
AS
$$
BEGIN
  RETURN
  (
    WITH intermediate
    AS
    (
      SELECT
        receiver AS owner,
        chain_id AS chain_id
      FROM      nft.neptune_legends_transfer
      WHERE     token_id = _token_id
      ORDER BY  block_timestamp DESC
      LIMIT 1
    )
    SELECT jsonb_agg(intermediate) FROM intermediate
  );
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_nft_role(_token_id uint256)
RETURNS text
STABLE
AS
$$
BEGIN
  RETURN
    CASE
      WHEN nfts.family IN('Aquavallo', 'Delphinus', 'Salacia') THEN 'Guardian'
      WHEN nfts.family IN('Merman Serpent', 'Gargantuworm', 'Grim Wyvern', 'Sabersquatch') THEN 'Beast'
      WHEN nfts.family = 'Neptune' THEN 'Neptune'
    END
  FROM nfts
  WHERE nfts.token_id = _token_id;
END
$$
LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA public TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonlyuser;

GRANT USAGE ON SCHEMA public TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT, UPDATE ON TABLES TO writeuser;




WITH nft_attributes
AS
(
  SELECT id, jsonb_array_elements(attributes) AS values
  FROM nfts
),
families
AS
(
  SELECT id, values->>'value' AS family
  FROM nft_attributes 
  WHERE values->>'trait_type' = 'Family'
)
UPDATE nfts
SET family = families.family
FROM families
WHERE nfts.id = families.id;


WITH nft_attributes
AS
(
  SELECT id, jsonb_array_elements(attributes) AS values
  FROM nfts
),
nicknames
AS
(
  SELECT id, values->>'value' AS nickname
  FROM nft_attributes 
  WHERE values->>'trait_type' = 'Nickname'
)
UPDATE nfts
SET nickname = nicknames.nickname
FROM nicknames
WHERE nfts.id = nicknames.id;


CREATE OR REPLACE FUNCTION check_user_liked
(
  _account                            address,
  _token_id                           uint256
)
RETURNS boolean
STABLE
AS
$$
DECLARE _result boolean;
BEGIN
  SELECT liked  INTO _result
  FROM likes
  WHERE token_id                      = _token_id
  AND liked_by                        = _account
  LIMIT 1;

  RETURN COALESCE(_result, false);
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM check_user_liked(1, '0x')
DROP FUNCTION IF EXISTS get_nft_merkle_tree(_live boolean);

CREATE FUNCTION get_nft_merkle_tree(_live boolean)
RETURNS TABLE
(
  id                                                                  uuid,
  account                                                             address,
  policy                                                              uint256,
  liquidity                                                           uint256,
  points                                                              uint256,
  eligible_level                                                      uint8,
  level                                                               uint8,
  family                                                              text,
  persona                                                             uint8
)
AS
$$
  DECLARE _r                                                          RECORD;
BEGIN
  DROP TABLE IF EXISTS _get_nft_merkle_tree_result;
  CREATE TEMPORARY TABLE _get_nft_merkle_tree_result
  (
    id                                                                uuid,
    account                                                           address,
    policy                                                            uint256,
    liquidity                                                         uint256,
    points                                                            uint256,
    eligible_level                                                    uint8,
    level                                                             uint8,    
    family                                                            text,
    persona                                                           uint8
  ) ON COMMIT DROP;
  
  IF(_live = false) THEN
    RETURN QUERY
    SELECT
      nft.merkle_root_update_details.id,
      nft.merkle_root_update_details.account,
      nft.merkle_root_update_details.policy,
      nft.merkle_root_update_details.liquidity,
      nft.merkle_root_update_details.points,
      nft.merkle_root_update_details.eligible_level,
      nft.merkle_root_update_details.level,
      nft.merkle_root_update_details.family,
      nft.merkle_root_update_details.persona
    FROM nft.merkle_root_update_details
    WHERE active = true;
    
    RETURN;
  END IF;
  
  FOR _r IN
  (
    SELECT * FROM nft_user_points_view
  ) LOOP
    FOR i IN 1.._r.level
    LOOP
      INSERT INTO _get_nft_merkle_tree_result(account, policy, liquidity, points, eligible_level, level)
      SELECT _r.account, _r.policy, _r.liquidity, _r.points, _r.level, i;    
    END LOOP;
  END LOOP;
  
  UPDATE _get_nft_merkle_tree_result
  SET persona = nft.persona_set.persona
  FROM nft.persona_set
  WHERE nft.persona_set.account = _get_nft_merkle_tree_result.account
  AND nft.persona_set.level = _get_nft_merkle_tree_result.level;
  
  UPDATE _get_nft_merkle_tree_result
  SET family = characters.name
  FROM characters
  WHERE _get_nft_merkle_tree_result.level = characters.level
  AND characters.role =
  CASE _get_nft_merkle_tree_result.persona 
    WHEN 1 THEN 'Guardian' 
    WHEN 2 THEN 'Beast' 
    ELSE NULL
  END;
  
  UPDATE _get_nft_merkle_tree_result
  SET
    family = 'Legendary Neptune', 
    persona = 1
  WHERE _get_nft_merkle_tree_result.eligible_level = 7
  AND _get_nft_merkle_tree_result.level = 7;

  RETURN QUERY
  SELECT * FROM _get_nft_merkle_tree_result
  ORDER BY account, level;
END
$$
LANGUAGE plpgsql;


--SELECT * FROM get_nft_merkle_tree(true);


CREATE OR REPLACE FUNCTION get_account_nft_info
(
  _account                        address
)
RETURNS TABLE
(
  account                                                     address,
  unlocked_level                                              numeric,
  minted_level                                                numeric,
  token_id                                                    uint256,
  nickname                                                    text,
  persona_info                                                jsonb
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_account_info_result;
  CREATE TEMPORARY TABLE _get_account_info_result
  (
    account                                                   address,
    unlocked_level                                            numeric,
    minted_level                                              numeric,
    token_id                                                  uint256,
    nickname                                                  text,
    persona_info                                              jsonb
  ) ON COMMIT DROP;

  -- There could be an account with one of these criteria
  -- minted soulbound token, but not set persona
  -- set persona, but not minted soulbound token
  -- minted soulbound token and set persona
  INSERT INTO _get_account_info_result(account, unlocked_level)
  SELECT _account, COALESCE(MAX(level), 0)
  FROM nft.merkle_root_update_details
  WHERE nft.merkle_root_update_details.active = true
  AND nft.merkle_root_update_details.account = _account;
  
  UPDATE _get_account_info_result
  SET token_id = nft.soulbound_minted.token_id
  FROM nft.soulbound_minted
  WHERE _get_account_info_result.account = nft.soulbound_minted.account;
  
  UPDATE _get_account_info_result
  SET nickname = nfts.nickname
  FROM nfts
  WHERE _get_account_info_result.token_id = nfts.token_id;
  
  UPDATE _get_account_info_result
  SET minted_level =
  (
    SELECT MAX(level)
    FROM nft.minted_with_proof
    WHERE _get_account_info_result.account = nft.minted_with_proof.transaction_sender --@todo: change this to `account`
  );
  
  UPDATE _get_account_info_result
  SET persona_info =
  (
    SELECT jsonb_agg(jsonb_build_object('level', level, 'persona', persona))
    FROM nft.persona_set
    WHERE nft.persona_set.account = _get_account_info_result.account
  );

  RETURN QUERY
  SELECT * FROM _get_account_info_result;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_account_nft_info('0x0000000000000000000000000000000000000000')
CREATE OR REPLACE FUNCTION get_bound_token_id(_account address)
RETURNS uint256
STABLE
AS
$$
BEGIN
  RETURN token_id
  FROM nft.soul_bound
  WHERE transaction_sender = _account;
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_nft_detail(_token_id uint256)
RETURNS TABLE
(
  token_id                                  uint256,
  token_role                                text,
  level                                     integer,
  siblings                                  integer,
  stage                                     text,
  token_owner                               text,
  name                                      text,
  nickname                                  text,
  family                                    text,
  views                                     uint256,
  want_to_mint                              uint256,
  description                               text,
  url                                       text,
  image                                     text,
  external_url                              text,
  date_published                            TIMESTAMP WITH TIME ZONE,
  soulbound                                 boolean,
  attributes                                jsonb,
  activities                                jsonb
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_nft_detail_details;
  
  CREATE TEMPORARY TABLE _get_nft_detail_details
  (
    token_id                                  uint256,
    token_role                                text,
    level                                     integer,
    siblings                                  integer,
    stage                                     text,
    token_owner                               text,
    name                                      text,
    nickname                                  text,
    family                                    text,
    views                                     uint256,
    want_to_mint                              uint256,
    description                               text,
    url                                       text,
    image                                     text,
    external_url                              text,
    date_published                            TIMESTAMP WITH TIME ZONE,
    soulbound                                 boolean,
    attributes                                jsonb,
    activities                                jsonb
  ) ON COMMIT DROP;
  
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_nft_detail(121411);

-- select * from nfts limit 1
-- SELECT * FROM CHARACTERS


CREATE OR REPLACE FUNCTION get_sibling_count(_family national character varying(128))
RETURNS integer
STABLE
AS
$$
BEGIN
  RETURN siblings
  FROM characters
  WHERE name = _family;
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_like
(
  _account                                address,
  _token_id                               uint256
)
RETURNS uint256
AS
$$
  DECLARE _previous                       boolean;
  DECLARE _like_count                     uint256;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM nfts WHERE token_id = _token_id) THEN
    RAISE EXCEPTION 'Invalid token id';
  END IF;
  
  IF NOT EXISTS(SELECT * FROM likes WHERE token_id = _token_id AND liked_by = _account) THEN
    INSERT INTO likes(token_id, liked_by, liked)
    SELECT _token_id, _account, false;
  END IF;

  SELECT likes.liked
  INTO _previous
  FROM likes
  WHERE likes.liked_by                    = _account
  AND likes.token_id                      = _token_id;

  UPDATE likes
  SET
    last_unliked_at                       = CASE WHEN liked = true  THEN NOW() ELSE last_unliked_at END,
    last_liked_at                         = CASE WHEN liked = false THEN NOW() ELSE last_liked_at   END,
    liked                                 = NOT(COALESCE(liked, false)) 
  WHERE likes.liked_by                    = _account
  AND likes.token_id                      = _token_id;

  UPDATE nfts
  SET likes                               = likes + (CASE WHEN _previous = true THEN -1 ELSE 1 END)
  WHERE token_id                          = _token_id
  RETURNING nfts.likes
  INTO _like_count;

  RETURN _like_count;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM log_like('0xB452AC021a1151AAF342c1B75aA914E03e6503b5', 100500)

CREATE OR REPLACE FUNCTION log_view(_token_id uint256)
RETURNS TABLE(token_views uint256, views uint256)
AS
$$
  DECLARE _token_views                  uint256;
  DECLARE _views                        uint256;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM nfts WHERE token_id = _token_id) THEN
    RAISE EXCEPTION 'Invalid token id';
  END IF;

  UPDATE characters
  SET views = characters.views + 1
  WHERE name = 
  (
    SELECT family
    FROM nfts
    WHERE token_id = _token_id
  )
  RETURNING characters.views INTO _views;
  
  UPDATE nfts
  SET views = nfts.views + 1
  WHERE token_id = _token_id
  RETURNING nfts.views INTO _token_views;
  
  RETURN QUERY
  SELECT _token_views, _views;
END
$$
LANGUAGE plpgsql;


--SELECT * FROM log_view((SELECT token_id FROM nfts ORDER BY random() LIMIT 1))

-- DO
-- $$
--   DECLARE i INTEGER;
-- BEGIN
--   FOR i IN 1..10000 LOOP
--   PERFORM * FROM log_view((SELECT token_id FROM nfts ORDER BY random() LIMIT 1));
--   END LOOP;
-- END;
-- $$
-- LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION log_want_to_mint(_token_id uint256)
RETURNS TABLE(token_want_to_mint uint256, want_to_mint uint256)
AS
$$
  DECLARE _token_want_to_mint                  uint256;
  DECLARE _want_to_mint                        uint256;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM nfts WHERE token_id = _token_id) THEN
    RAISE EXCEPTION 'Invalid token id';
  END IF;

  UPDATE characters
  SET want_to_mint = characters.want_to_mint + 1
  WHERE name = 
  (
    SELECT family
    FROM nfts
    WHERE token_id = _token_id
  )
  RETURNING characters.want_to_mint INTO _want_to_mint;
  
  UPDATE nfts
  SET want_to_mint = nfts.want_to_mint + 1
  WHERE token_id = _token_id
  RETURNING nfts.want_to_mint INTO _token_want_to_mint;
  
  RETURN QUERY
  SELECT _token_want_to_mint, _want_to_mint;
END
$$
LANGUAGE plpgsql;


--SELECT * FROM log_want_to_mint((SELECT token_id FROM nfts ORDER BY random() LIMIT 1))

-- DO
-- $$
--   DECLARE i INTEGER;
-- BEGIN
--   FOR i IN 1..10000 LOOP
--   PERFORM * FROM log_want_to_mint((SELECT token_id FROM nfts ORDER BY random() LIMIT 1));
--   END LOOP;
-- END;
-- $$
-- LANGUAGE plpgsql;




DROP FUNCTION IF EXISTS search_nfts
(
  _search                                         national character varying(128),
  _props                                          jsonb,
  _page_number                                    integer,
  _page_size                                      integer
);

CREATE OR REPLACE FUNCTION search_nfts
(
  _search                                         national character varying(128),
  _minted                                         boolean,
  _soulbound                                      boolean,
  _roles                                          text[],
  _props                                          jsonb,
  _page_number                                    integer,
  _page_size                                      integer
)
RETURNS TABLE
(
  nickname                                        text,
  family                                          text,
  category                                        text,
  token_id                                        uint256,
  views                                           uint256,
  want_to_mint                                    uint256,
  siblings                                        integer,
  soulbound                                       boolean,
  token_owner                                     address,
  page_size                                       integer,
  page_number                                     integer,
  total_records                                   integer,
  total_pages                                     integer  
)
AS
$$
  DECLARE _total_records                          integer;
  DECLARE _total_pages                            integer;
  DECLARE _query                                  text;
BEGIN
  IF(_page_number < 1) THEN
    RAISE EXCEPTION 'Invalid page_number value %', _page_number;  
  END IF;
  
  IF(_page_size NOT IN (10, 25, 50)) THEN
    RAISE EXCEPTION 'Invalid _page_size value %', _page_size;  
  END IF;

  DROP TABLE IF EXISTS _search_nfts_result;

  CREATE TEMPORARY TABLE _search_nfts_result
  (
    nickname                                        text,
    family                                          text,
    category                                        text,
    token_id                                        uint256,
    views                                           uint256,
    want_to_mint                                    uint256,
    siblings                                        integer,
    soulbound                                       boolean,
    token_owner                                     address,
    page_size                                       integer,
    page_number                                     integer,
    total_records                                   integer,
    total_pages                                     integer  
  ) ON COMMIT DROP;
  
   _query := format('
  WITH result
  AS
  (
    SELECT nfts.nickname, nfts.family, nfts.category, nfts.token_id, nfts.views, nfts.want_to_mint, get_sibling_count(nfts.category)
    FROM nfts
    WHERE 1 = 1
    AND (%1$L IS NULL OR attributes @> %1$L)
    AND CONCAT(nfts.family, nfts.description, nfts.token_id, nfts.attributes::text) ILIKE %2$s
    AND (%3$L IS NULL OR %3$L = (get_owner(nfts.token_id) IS NOT NULL))
    AND (%4$L IS NULL OR nfts.soulbound = %4$L)
    AND (array_length(%5$L::text[], 1) IS NULL OR get_nft_role(nfts.token_id) = ANY(%5$L::text[]))
  )
  SELECT COUNT(*) FROM result;', _props, quote_literal_ilike(_search), _minted, _soulbound, _roles);

  EXECUTE _query
  INTO _total_records;

  INSERT INTO _search_nfts_result(
    nickname,
    family,
    category,
    token_id,
    views,
    want_to_mint,
    siblings,
    soulbound,
    token_owner
  )
  SELECT
    nfts.nickname,
    nfts.family,
    nfts.category,
    nfts.token_id,
    nfts.views,
    nfts.want_to_mint,
    get_sibling_count(nfts.category),
    nfts.soulbound,
    get_owner(nfts.token_id)
  FROM nfts
  WHERE 1 = 1
  AND (_props     IS NULL OR attributes @> _props)
  AND CONCAT(nfts.family, nfts.description, nfts.token_id, nfts.attributes::text) ILIKE CONCAT('%', TRIM(_search), '%')
  AND (_soulbound IS NULL OR nfts.soulbound = _soulbound)
  AND (_minted    IS NULL OR _minted = (get_owner(nfts.token_id) IS NOT NULL))
  AND (array_length(_roles,1) IS NULL OR get_nft_role(nfts.token_id) = ANY(_roles))
  ORDER BY nfts.views DESC, nfts.nickname
  LIMIT _page_size
  OFFSET _page_size * (_page_number -1);

  UPDATE _search_nfts_result
  SET
    page_number   = _page_number,
    page_size     = _page_size,
    total_records = _total_records,
    total_pages   = COALESCE(CEILING(_total_records::numeric / _page_size), 0);

  RETURN QUERY
  SELECT * FROM _search_nfts_result;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM search_nfts
-- (
--   '',
--   true,
--   true,
--   array[]::text[],
--   '[]'::jsonb,
--   1,
--   10
-- );

DROP FUNCTION IF EXISTS nft.update_merkle_root_details
(
  _id                                                       uuid,
  _transaction_hash                                         text,
  _info                                                     text,
  _leaves                                                   jsonb
);

CREATE FUNCTION nft.update_merkle_root_details
(
  _id                                                       uuid,
  _transaction_hash                                         text,
  _info                                                     text,
  _leaves                                                   jsonb
)
RETURNS void
AS
$$
BEGIN  
  UPDATE nft.merkle_root_update_details
  SET active = false;

  INSERT INTO nft.merkle_root_updates(id, updated_on, info, transaction_hash)
  SELECT _id, extract(epoch FROM NOW() AT TIME ZONE 'UTC'), _info, _transaction_hash;
  
  INSERT INTO nft.merkle_root_update_details(id, account, policy, liquidity, points, eligible_level, level, family, persona)
  SELECT _id, * FROM jsonb_to_recordset((SELECT jsonb_agg(t) AS leaves FROM get_nft_merkle_tree(true) AS t))
  AS (account address, policy uint256, liquidity uint256, points uint256, eligible_level uint8, level uint8, family text, persona uint8);
END
$$
LANGUAGE plpgsql;


--SELECT * FROM nft.update_merkle_root_details('2588fd26-7017-4fb9-b2b1-1b37a03e3603', 'test', (SELECT jsonb_agg(t) AS leaves FROM get_nft_merkle_tree(true) AS t))



DROP VIEW IF EXISTS know_the_characters_view;

CREATE VIEW know_the_characters_view
AS
SELECT
  level,
  role,
  name,
  description,
  start_index,
  CONCAT('https://nft.neptunemutual.net/images/', start_index + 1, '.png') AS image,
  CONCAT('https://nft.neptunemutual.net/thumbnails/', start_index + 1, '.webp') AS thumbnail,
  CONCAT('https://nft.neptunemutual.net/covers/', start_index + 1, '.webp') AS cover,
  siblings,
  rarity,
  stage
FROM characters;

DROP VIEW IF EXISTS all_property_view;

CREATE VIEW all_property_view
AS
WITH parsed
AS
(
  SELECT DISTINCT jsonb_array_elements(attributes) AS values
  FROM nfts
),
key_value_pairs
AS
(
  SELECT values->>'trait_type' AS key, values->>'value' AS value
  FROM parsed
)
SELECT * FROM key_value_pairs
WHERE key NOT IN ('Nickname')
ORDER BY key;

CREATE OR REPLACE VIEW nft_bridge_transactions_view
AS
SELECT
  transaction_hash,
  block_timestamp,
  block_number,
  transaction_sender,
  chain_id,
  sender,
  receiver,
  get_nft_name_info(token_ids) AS tokens,
  dst_chain_id
FROM nft.send_to_chain;

CREATE OR REPLACE VIEW nft_user_collection_view
AS
SELECT
  token_id,
  name,
  nickname,
  family,
  soulbound,
  attributes,
  get_owner(token_id) AS token_owner
FROM nfts
WHERE get_owner(token_id) IS NOT NULL;

CREATE OR REPLACE VIEW nft_user_persona_view
AS
SELECT
  COALESCE(nft.persona_set.account, nft.soul_bound.transaction_sender) AS account,
  level,
  persona,
  nft.soul_bound.token_id AS bound_token_id
FROM nft.soul_bound
FULL OUTER JOIN nft.persona_set
ON nft.persona_set.account = nft.soul_bound.transaction_sender;

DROP VIEW IF EXISTS minting_level_view;

CREATE VIEW minting_level_view
AS
SELECT
  characters.name,
  characters.role,
  characters.description,
  characters.level,
  CONCAT('https://nft.neptunemutual.net/images/', start_index + 1, '.png') AS image,
  CONCAT('https://nft.neptunemutual.net/thumbnails/', start_index + 1, '.webp') AS thumbnail,
  CONCAT('https://nft.neptunemutual.net/covers/', start_index + 1, '.webp') AS cover,
  characters.stage,
  characters.siblings
FROM characters
WHERE level IS NOT NULL;


DROP VIEW IF EXISTS most_viewed_nft_view;

CREATE VIEW most_viewed_nft_view
AS
SELECT
  level,
  role,
  name,
  description,
  views,
  start_index,
  CONCAT('https://nft.neptunemutual.net/images/', start_index + 1, '.png') AS image,
  CONCAT('https://nft.neptunemutual.net/thumbnails/', start_index + 1, '.webp') AS thumbnail,
  CONCAT('https://nft.neptunemutual.net/covers/', start_index + 1, '.webp') AS cover,
  siblings,
  rarity,
  stage
FROM characters
ORDER BY views DESC
LIMIT 5;

DROP VIEW IF EXISTS nft_activity_view CASCADE;

CREATE VIEW nft_activity_view
AS
SELECT id, token_id, 'Soulbound'     AS event, chain_id, transaction_hash, block_timestamp, transaction_sender AS "from", NULL AS "to" FROM nft.soul_bound
UNION ALL
SELECT id, token_id, 'Transfer'      AS event, chain_id, transaction_hash, block_timestamp, sender AS "from", receiver AS "to" FROM nft.neptune_legends_transfer
--UNION ALL
--@todo: transfer_batch
;

DROP VIEW IF EXISTS nft_detail_view;

CREATE VIEW nft_detail_view
AS
SELECT
  nfts.token_id,
  characters.role,
  characters.level,
  characters.siblings,
  characters.stage,
  get_owner(nfts.token_id) AS token_owner,
  nfts.name,
  nfts.category,
  nfts.nickname,
  nfts.family,
  nfts.views,
  nfts.likes,
  nfts.want_to_mint,
  nfts.description,
  nfts.url,
  CONCAT('https://nft.neptunemutual.net/images/', nfts.token_id, '.png') AS image,
  CONCAT('https://nft.neptunemutual.net/thumbnails/', nfts.token_id, '.webp') AS thumbnail,
  CONCAT('https://nft.neptunemutual.net/covers/', nfts.token_id, '.webp') AS cover,
  nfts.external_url,
  nfts.date_published,
  nfts.soulbound,
  nfts.attributes,
  jsonb_agg(nft_activity_view) as activities
FROM nfts
INNER JOIN characters
ON characters.name = nfts.category
LEFT OUTER JOIN nft_activity_view
ON nft_activity_view.token_id = nfts.token_id
GROUP BY
  nfts.token_id, 
  characters.role,
  characters.level,
  characters.siblings,
  characters.stage,
  token_owner,
  nfts.name,
  nfts.category,
  nfts.nickname,
  nfts.family,
  nfts.views,
  nfts.likes,
  nfts.want_to_mint,
  nfts.description,
  nfts.url,
  nfts.image,
  nfts.external_url,
  nfts.date_published,
  nfts.soulbound,
  nfts.attributes;

CREATE OR REPLACE VIEW nft_user_points_view
AS
WITH policy_purchasers
AS
(
  SELECT
    on_behalf_of                                                        AS account,
    SUM(get_stablecoin_value(chain_id, amount_to_cover))                AS policy
  FROM policy.cover_purchased
  GROUP BY on_behalf_of
),
liquidity_providers
AS
(
  SELECT
    account,
    SUM(get_stablecoin_value(chain_id, liquidity_added))                AS liquidity
  FROM vault.pods_issued
  GROUP BY account
),
points
AS
(
  SELECT
    COALESCE(policy_purchasers.account, liquidity_providers.account)    AS account,
    COALESCE(policy_purchasers.policy, 0)                               AS policy,
    COALESCE(liquidity_providers.liquidity, 0)                          AS liquidity
  FROM policy_purchasers
  FULL OUTER JOIN liquidity_providers
  ON policy_purchasers.account = liquidity_providers.account
),
summary
AS
(
  SELECT
    account,
    policy,
    liquidity,
    FLOOR(policy * 0.00625 + liquidity * 0.0375)                        AS points
  FROM points
)
SELECT 
  account,
  policy,
  liquidity,
  points,
  CASE
    WHEN points >= 50000 THEN 7
    WHEN points >= 25000 THEN 6
    WHEN points >= 10000 THEN 5
    WHEN points >= 7500 THEN 4
    WHEN points >= 5000 THEN 3
    WHEN points >= 1000 THEN 2
    WHEN points >= 100 THEN 1
    WHEN points < 100 THEN 0
  END                                                                   AS level
FROM summary
WHERE points >= 100
ORDER BY points DESC;


DROP VIEW IF EXISTS premium_nft_view;

CREATE VIEW premium_nft_view
AS
SELECT
  level,
  role,
  name,
  description,
  start_index,
  CONCAT('https://nft.neptunemutual.net/images/', start_index + 1, '.png') AS image,
  CONCAT('https://nft.neptunemutual.net/thumbnails/', start_index + 1, '.webp') AS thumbnail,
  CONCAT('https://nft.neptunemutual.net/covers/', start_index + 1, '.webp') AS cover,
  siblings,
  rarity,
  stage
FROM characters
WHERE siblings <= 100
AND siblings > 0;


DROP VIEW IF EXISTS regular_nft_view;

CREATE VIEW regular_nft_view
AS
SELECT
  level,
  role,
  name,
  description,
  start_index,
  CONCAT('https://nft.neptunemutual.net/images/', start_index + 1, '.png') AS image,
  CONCAT('https://nft.neptunemutual.net/thumbnails/', start_index + 1, '.webp') AS thumbnail,
  CONCAT('https://nft.neptunemutual.net/covers/', start_index + 1, '.webp') AS cover,
  siblings,
  rarity,
  stage
FROM characters
WHERE (siblings > 100 OR siblings = - 1);

DROP VIEW IF EXISTS trending_nft_view;

CREATE VIEW trending_nft_view
AS
SELECT
  level,
  role,
  name,
  description,
  want_to_mint,
  start_index,
  CONCAT('https://nft.neptunemutual.net/images/', start_index + 1, '.png') AS image,
  CONCAT('https://nft.neptunemutual.net/thumbnails/', start_index + 1, '.webp') AS thumbnail,
  CONCAT('https://nft.neptunemutual.net/covers/', start_index + 1, '.webp') AS cover,
  siblings,
  rarity,
  stage
FROM characters
ORDER BY want_to_mint DESC
LIMIT 4;

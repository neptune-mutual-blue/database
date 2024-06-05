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
  contract                                          address /* NOT NULL */,
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
  statuses                                          bool[] NOT NULL,
  PRIMARY KEY (id)
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
  npm_to_top_up_now                                 uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

/****************************************************************************************************
event BondCreated(address indexed account, uint256 lpTokens, uint256 npmToVest, uint256 unlockDate);
****************************************************************************************************/
CREATE TABLE staking.bond_created
(
  account                                           address NOT NULL,
  lp_tokens                                         uint256 NOT NULL,
  npm_to_vest                                       uint256 NOT NULL,
  unlock_date                                       uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX bond_created_account_inx
ON staking.bond_created(account);

/***********************************************************
event BondClaimed(address indexed account, uint256 amount);
***********************************************************/
CREATE TABLE staking.bond_claimed
(
  account                                           address NOT NULL,
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  claimed                                           uint256 NOT NULL,
  PRIMARY KEY (id)
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
  current                                           uint256 NOT NULL,
  PRIMARY KEY (id)
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
  status                                            bool NOT NULL,
  PRIMARY KEY (id)
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
  requires_whitelist                                bool NOT NULL,
  PRIMARY KEY (id)
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
  info                                              text NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX product_created_cover_key_inx
ON cover.product_created(cover_key);

/**********************************************************
event CoverUpdated(bytes32 indexed coverKey, string info);
**********************************************************/
CREATE TABLE cover.cover_updated
(
  cover_key                                         bytes32 NOT NULL,
  info                                              text NOT NULL,
  PRIMARY KEY (id)
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
  info                                              text NOT NULL,
  PRIMARY KEY (id)
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
  reason                                            text NOT NULL,
  PRIMARY KEY (id)
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
  status                                            bool NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

/*************************************************************
event CoverCreationFeeSet(uint256 previous, uint256 current);
*************************************************************/
CREATE TABLE cover.cover_creation_fee_set
(
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

/******************************************************************
event MinCoverCreationStakeSet(uint256 previous, uint256 current);
******************************************************************/
CREATE TABLE cover.min_cover_creation_stake_set
(
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

/*******************************************************************
event MinStakeToAddLiquiditySet(uint256 previous, uint256 current);
*******************************************************************/
CREATE TABLE cover.min_stake_to_add_liquidity_set
(
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

/*********************************************************************
event CoverInitialized(address indexed stablecoin, bytes32 withName);
*********************************************************************/
CREATE TABLE cover.cover_initialized
(
  stablecoin                                        address NOT NULL,
  with_name                                         bytes32 NOT NULL,
  PRIMARY KEY (id)
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
  status                                            bool NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  weight                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  expiry_date                                       uint256 NOT NULL,
  PRIMARY KEY (id)
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
  incident_date                                     uint256 NOT NULL,
  PRIMARY KEY (id)
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
  resolution_timestamp                              uint256 NOT NULL,
  PRIMARY KEY (id)
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
  initial_stake                                     uint256 NOT NULL,
  PRIMARY KEY (id)
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
  current                                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

/**********************************************************************************
event FirstReportingStakeSet(bytes32 coverKey, uint256 previous, uint256 current);
**********************************************************************************/
CREATE TABLE consensus.first_reporting_stake_set
(
  cover_key                                         bytes32 NOT NULL,
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

/***************************************************************
event ReporterCommissionSet(uint256 previous, uint256 current);
***************************************************************/
CREATE TABLE consensus.reporter_commission_set
(
  previous                                          uint256 NOT NULL,
  current                                           uint256 NOT NULL,
  PRIMARY KEY (id)
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
  stake                                             uint256 NOT NULL,
  PRIMARY KEY (id)
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
  stake                                             uint256 NOT NULL,
  PRIMARY KEY (id)
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
  reward                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  reporter_reward                                   uint256 NOT NULL,
  PRIMARY KEY (id)
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
  burned_amount                                     uint256 NOT NULL,
  PRIMARY KEY (id)
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
  claim_expires_at                                  uint256 NOT NULL,
  PRIMARY KEY (id)
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
  period                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  incident_date                                     uint256 NOT NULL,
  PRIMARY KEY (id)
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
  withdrawal_total                                  uint256 NOT NULL,
  PRIMARY KEY (id)
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
  certificate_token_issued                          uint256 NOT NULL,
  PRIMARY KEY (id)
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
  withdrawal_total                                  uint256 NOT NULL,
  PRIMARY KEY (id)
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
  certificate_token_redeemed                        uint256 NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX drained_asset_inx
ON strategy.drained(asset);



/*************************************************
event StrategyDisabled(address indexed strategy);
*************************************************/
CREATE TABLE strategy.strategy_disabled
(
  strategy                                          address NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX strategy_disabled_strategy_inx
ON strategy.strategy_disabled(strategy);

/************************************************
event StrategyDeleted(address indexed strategy);
************************************************/
CREATE TABLE strategy.strategy_deleted
(
  strategy                                          address NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX strategy_deleted_strategy_inx
ON strategy.strategy_deleted(strategy);

/********************************************************
event LiquidityStateUpdateIntervalSet(uint256 duration);
********************************************************/
CREATE TABLE strategy.liquidity_state_update_interval_set
(
  duration                                          uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

/**********************************************
event StrategyAdded(address indexed strategy);
**********************************************/
CREATE TABLE strategy.strategy_added
(
  strategy                                          address NOT NULL,
  PRIMARY KEY (id)
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
  withdrawal_window                                 uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX risk_pooling_period_set_key_inx
ON strategy.risk_pooling_period_set(key);

/****************************************
event MaxLendingRatioSet(uint256 ratio);
****************************************/
CREATE TABLE strategy.max_lending_ratio_set
(
  ratio                                             uint256 NOT NULL,
  PRIMARY KEY (id)
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
  policy_id                                         uint256 NOT NULL,
  PRIMARY KEY (id)
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
  ceiling                                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX cover_policy_rate_set_cover_key_inx
ON policy.cover_policy_rate_set(cover_key);

/***************************************************************
event CoverageLagSet(bytes32 indexed coverKey, uint256 window);
***************************************************************/
CREATE TABLE policy.coverage_lag_set
(
  cover_key                                         bytes32 NOT NULL,
  "window"                                          uint256 NOT NULL,
  PRIMARY KEY (id)
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
  policy_ceiling                                    uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);


/*****************************************************************************************************
event ContractAdded(bytes32 indexed namespace, bytes32 indexed key, address indexed contractAddress);
*****************************************************************************************************/
CREATE TABLE protocol.contract_added
(
  namespace                                         bytes32 NOT NULL,
  key                                               bytes32 NOT NULL,
  contract_address                                  address NOT NULL,
  PRIMARY KEY (id)
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
  current                                           address NOT NULL,
  PRIMARY KEY (id)
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
  member                                            address NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

/************************************
event MemberRemoved(address member);
************************************/
CREATE TABLE protocol.member_removed
(
  member                                            address NOT NULL,
  PRIMARY KEY (id)
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
  reward_token_to_deposit                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX pool_updated_key_inx
ON staking.pool_updated(key);

/***************************************************
event PoolClosed(bytes32 indexed key, string name);
***************************************************/
CREATE TABLE staking.pool_closed
(
  key                                               bytes32 NOT NULL,
  name                                              text NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  platform_fee                                      uint256 NOT NULL,
  PRIMARY KEY (id)
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
  statuses                                          bool[] NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX pausers_set_added_by_inx
ON store.pausers_set(added_by);

/*************************************************************
event GovernanceTransfer(address indexed to, uint256 amount);
*************************************************************/
CREATE TABLE vault.governance_transfer
(
  "to"                                              address NOT NULL,
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  loss                                              uint256 NOT NULL,
  PRIMARY KEY (id)
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
  referral_code                                     bytes32 NOT NULL,
  PRIMARY KEY (id)
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
  liquidity_released                                uint256 NOT NULL,
  PRIMARY KEY (id)
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
  fee                                               uint256 NOT NULL,
  PRIMARY KEY (id)
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
  amount                                          uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX npm_staken_account_inx
ON vault.npm_staken(account);

/***********************************************************
event NpmUnstaken(address indexed account, uint256 amount);
***********************************************************/
CREATE TABLE vault.npm_unstaken
(
  account                                         address NOT NULL,
  amount                                          uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX npm_unstaken_account_inx
ON vault.npm_unstaken(account);

/************************************************
event InterestAccrued(bytes32 indexed coverKey);
************************************************/
CREATE TABLE vault.interest_accrued
(
  cover_key                                       bytes32 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX interest_accrued_cover_key_inx
ON vault.interest_accrued(cover_key);

/*****************************************************************
event Entered(bytes32 indexed coverKey, address indexed account);
*****************************************************************/
CREATE TABLE vault.entered
(
  cover_key                                       bytes32 NOT NULL,
  account                                         address NOT NULL,
  PRIMARY KEY (id)
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
  account                                         address NOT NULL,
  PRIMARY KEY (id)
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
  symbol                                          text NOT NULL,
  PRIMARY KEY (id)
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
  balance                                           uint256 NOT NULL  ,
  PRIMARY KEY (id)
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
  statuses                                          boolean[] NOT NULL  ,
  PRIMARY KEY (id)
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
  penalty                                           uint256 NOT NULL,
  PRIMARY KEY (id)
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
  treasury                                          address NOT NULL,
  PRIMARY KEY (id)
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
  treasury                                          address NOT NULL,
  PRIMARY KEY (id)
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
  current                                           uint256 NOT NULL,
  PRIMARY KEY (id)
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
  rewards                                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX epoch_reward_set_key_inx
ON ve.epoch_reward_set(key);


/*************************************************************************
event LiquidityGaugePoolAdded(bytes32 key, ILiquidityGaugePool pool);
*************************************************************************/
CREATE TABLE ve.liquidity_gauge_pool_added
(
  key                                               bytes32 NOT NULL,
  pool                                              address NOT NULL,
  PRIMARY KEY (id)
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
  current                                           address NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX liquidity_gauge_pool_updated_key_inx
ON ve.liquidity_gauge_pool_updated(key);

/*************************************************************************
event GaugeControllerRegistryPoolDeactivated(address indexed sender, bytes32 indexed key);
*************************************************************************/
CREATE TABLE ve.gauge_controller_registry_pool_deactivated
(
  sender                                            address NOT NULL,
  key                                               bytes32 NOT NULL,
  PRIMARY KEY (id)
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
  key                                               bytes32 NOT NULL,
  PRIMARY KEY (id)
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
  key                                               bytes32 NOT NULL,
  PRIMARY KEY (id)
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
  distribution                                      uint256 NOT NULL,
  PRIMARY KEY (id)
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
  total_allocation                                  uint256 NOT NULL,
  PRIMARY KEY (id)
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
  current_total                                     uint256 NOT NULL,
  PRIMARY KEY (id)
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
  platform_fee                                      uint256 NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
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
  amount                                            uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE INDEX liquidity_gauge_withdrawn_key_inx
ON ve.liquidity_gauge_withdrawn(key);

CREATE INDEX liquidity_gauge_withdrawn_account_inx
ON ve.liquidity_gauge_withdrawn(account);

CREATE INDEX liquidity_gauge_withdrawn_staking_token_inx
ON ve.liquidity_gauge_withdrawn(staking_token);

CREATE TABLE approval_for_all
(
  owner                                             address NOT NULL,
  operator                                          address NOT NULL,
  approved                                          boolean NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE TABLE core.role_admin_changed
(
  role                                              bytes32 NOT NULL,
  previous_admin_role                               bytes32 NOT NULL,
  new_admin_role                                    bytes32 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE TABLE core.ownership_transferred
(
  previous_owner                                    bytes32 NOT NULL,
  new_owner                                         bytes32 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE TABLE core.transfer
(
  "from"                                            address NOT NULL,
  "to"                                              address NOT NULL,
  value                                             uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE TABLE core.role_granted
(
  role                                              bytes32 NOT NULL,
  account                                           address NOT NULL,
  sender                                            address NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);

CREATE TABLE core.transparent_upgradeable_proxy_initialized
(
  version                                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS(core.transactions);


CREATE TABLE core.nft_transfer
(
  "from"                                            address NOT NULL,
  "to"                                              address NOT NULL,
  token_id                                          uint256 NOT NULL,
  PRIMARY KEY (id)
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
  AND factory.vault_deployed.vault = _vault
  LIMIT 1;
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
  NEW.ck = public.get_cover_key_by_vault_address(NEW.chain_id, NEW.address);
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
  NEW.ck = public.get_cover_key_by_vault_address(NEW.chain_id, NEW.address);
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
RETURNS numeric
IMMUTABLE
AS
$$
BEGIN
  RETURN COALESCE(amount, 0) * POWER(10, 18);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION wei_to_ether(amount uint256)
RETURNS numeric
IMMUTABLE
AS
$$
BEGIN
  RETURN COALESCE(amount, 0) / POWER(10, 18)::numeric(100, 32);
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION wei_to_ether OWNER TO writeuser;


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


CREATE OR REPLACE FUNCTION get_stablecoin_value(_chain_id uint256, _amount numeric(100, 32))
RETURNS numeric(100, 32)
IMMUTABLE
AS
$$
BEGIN
  IF(_chain_id IN (56)) THEN
    RETURN wei_to_ether(_amount);
  END IF;

  RETURN _amount / POWER(10, 6)::numeric(100, 32);
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_stablecoin_value OWNER TO writeuser;

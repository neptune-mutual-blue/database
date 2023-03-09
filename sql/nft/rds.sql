DROP DOMAIN IF EXISTS tx;
DROP DOMAIN IF EXISTS bytes32;
DROP DOMAIN IF EXISTS address;
DROP DOMAIN IF EXISTS ipfs_url;
DROP DOMAIN IF EXISTS uint256;
DROP DOMAIN IF EXISTS transaction_type;

CREATE DOMAIN bytes32 AS text;
CREATE DOMAIN address AS text;
CREATE DOMAIN ipfs_url AS text;
CREATE DOMAIN uint256 AS numeric(180,0);
CREATE DOMAIN uint96 AS numeric(180,0);

CREATE TABLE nfts
(
  id                                                uuid PRIMARY KEY DEFAULT(gen_random_uuid()),
  token_id                                          uint256 NOT NULL UNIQUE,
  name                                              national character varying(128) NOT NULL,
  description                                       text NOT NULL,
  url                                               text NOT NULL,
  image                                             text NOT NULL,
  external_url                                      text NOT NULL,
  date_published                                    uint256 NOT NULL,
  soulbound                                         boolean NOT NULL,
  attributes                                        jsonb NOT NULL,
  properties                                        jsonb NOT NULL
);

CREATE TABLE transactions
(
  transaction_id                                    uuid PRIMARY KEY DEFAULT(gen_random_uuid()),
  transaction_hash                                  text NOT NULL,
  address                                           address /* NOT NULL */,
  block_timestamp                                   integer NOT NULL,
  block_number                                      text NOT NULL,
  transaction_sender                                address,
  chain_id                                          uint256 NOT NULL,
  gas_price                                         uint256,
  event_name                                        text
);

CREATE UNIQUE INDEX transaction_hash_chain_id_uix
ON transactions(LOWER(transaction_hash), chain_id, LOWER(event_name));

CREATE INDEX transactions_block_timestamp_inx
ON transactions(block_timestamp);

CREATE INDEX transactions_block_number_inx
ON transactions(block_number);

CREATE INDEX transactions_chain_id_inx
ON transactions(chain_id);

/***************************************************************************************
event BaseUriSet(string previous, string current);
***************************************************************************************/
CREATE TABLE base_uri_set
(
  previous                                          text,
  current                                           text
) INHERITS(transactions);

/***************************************************************************************
event SoulBound(uint256 id);
***************************************************************************************/
CREATE TABLE soulbound
(
  id                                                uint256 UNIQUE
) INHERITS(transactions);


/***************************************************************************************
event DefaultRoyaltySet(address indexed sender, address indexed receiver, uint96 feeNumerator);
***************************************************************************************/
CREATE TABLE default_royalty_set
(
  sender                                            address,
  receiver                                          address,
  fee_numerator                                     uint96
) INHERITS(transactions);

CREATE INDEX default_royalty_set_sender_inx
ON default_royalty_set(sender);

CREATE INDEX default_royalty_set_receiver_inx
ON default_royalty_set(receiver);

/***************************************************************************************
event DefaultRoyaltyDeleted(address indexed sender);
***************************************************************************************/
CREATE TABLE default_royalty_deleted
(
  sender                                            address
) INHERITS(transactions);

CREATE INDEX default_royalty_deleted_sender_inx
ON default_royalty_deleted(sender);


/***************************************************************************************
event TokenRoyaltySet(address indexed sender, uint256 tokenId, address indexed receiver, uint96 feeNumerator);
***************************************************************************************/
CREATE TABLE token_royalty_set
(
  sender                                            address,
  token_id                                          uint256,
  receiver                                          address,
  fee_numerator                                     uint96
) INHERITS(transactions);


CREATE INDEX token_royalty_set_sender_inx
ON token_royalty_set(sender);

CREATE INDEX token_royalty_set_token_id_inx
ON token_royalty_set(token_id);

CREATE INDEX token_royalty_set_receiver_inx
ON token_royalty_set(receiver);

/***************************************************************************************
event TokenRoyaltyReset(address indexed sender, uint256 tokenId);
***************************************************************************************/
CREATE TABLE token_royalty_reset
(
  sender                                            address,
  token_id                                          uint256
) INHERITS(transactions);

CREATE INDEX token_royalty_reset_sender_inx
ON token_royalty_reset(sender);

/***************************************************************************************
event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
***************************************************************************************/
CREATE TABLE transfer_single
(
  operator                                          address,
  "from"                                            address,
  "to"                                              address,
  id                                                uint256,
  value                                             uint256
) INHERITS(transactions);

CREATE INDEX transfer_single_operator_inx
ON transfer_single(operator);

CREATE INDEX transfer_single_from_inx
ON transfer_single("from");

CREATE INDEX transfer_single_to_inx
ON transfer_single("to");

CREATE INDEX transfer_single_id_inx
ON transfer_single(id);

/***************************************************************************************
event TransferBatch(
    address indexed operator,
    address indexed from,
    address indexed to,
    uint256[] ids,
    uint256[] values
);
***************************************************************************************/
CREATE TABLE transfer_batch
(
  operator                                          address,
  "from"                                            address,
  "to"                                              address,
  ids                                               uint256[],
  values                                            uint256[]
) INHERITS(transactions);

CREATE INDEX transfer_batch_operator_inx
ON transfer_batch(operator);

CREATE INDEX transfer_batch_from_inx
ON transfer_batch("from");

CREATE INDEX transfer_batch_to_inx
ON transfer_batch("to");

/***************************************************************************************
event ApprovalForAll(address indexed account, address indexed operator, bool approved);
***************************************************************************************/
CREATE TABLE approval_for_all
(
  account                                           address,
  operator                                          address,
  approved                                          boolean
) INHERITS(transactions);

CREATE INDEX approval_for_all_account_inx
ON approval_for_all(account);

CREATE INDEX approval_for_all_operator_inx
ON approval_for_all(operator);

/***************************************************************************************
event URI(string value, uint256 indexed id);
***************************************************************************************/
CREATE TABLE uri
(
  value                                             text,
  id                                                uint256
) INHERITS(transactions);

CREATE INDEX uri_id_inx
ON uri(id);

/***************************************************************************************
event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
***************************************************************************************/
CREATE TABLE role_admin_changed
(
  role                                              bytes32,
  previous_admin_role                               bytes32,
  new_admin_role                                    bytes32
) INHERITS(transactions);

CREATE INDEX role_admin_changed_role_inx
ON role_admin_changed(role);

CREATE INDEX role_admin_changed_previous_admin_role_inx
ON role_admin_changed(previous_admin_role);

CREATE INDEX role_admin_changed_new_admin_role_inx
ON role_admin_changed(new_admin_role);

/***************************************************************************************
event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
***************************************************************************************/
CREATE TABLE role_granted
(
  role                                              bytes32,
  account                                           address,
  sender                                            address
) INHERITS(transactions);


CREATE INDEX role_granted_role_inx
ON role_granted(role);

CREATE INDEX role_granted_account_inx
ON role_granted(account);

CREATE INDEX role_granted_sender_inx
ON role_granted(sender);

/***************************************************************************************
event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
***************************************************************************************/
CREATE TABLE role_revoked
(
  role                                              bytes32,
  account                                           address,
  sender                                            address
) INHERITS(transactions);


CREATE INDEX role_revoked_role_inx
ON role_revoked(role);

CREATE INDEX role_revoked_account_inx
ON role_revoked(account);

CREATE INDEX role_revoked_sender_inx
ON role_revoked(sender);


/***************************************************************************************
event Paused(address account);
***************************************************************************************/
CREATE TABLE paused
(
  account                                           bytes32
) INHERITS(transactions);


CREATE INDEX paused_account_inx
ON paused(account);

/***************************************************************************************
event Unpaused(address account);
***************************************************************************************/
CREATE TABLE unpaused
(
  account                                           bytes32
) INHERITS(transactions);

CREATE INDEX unpaused_account_inx
ON unpaused(account);


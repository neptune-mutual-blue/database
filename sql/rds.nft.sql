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
  category                                          text GENERATED ALWAYS AS(split_part(name, '#', 1)) STORED,
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


CREATE TABLE IF NOT EXISTS transactions
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

CREATE UNIQUE INDEX IF NOT EXISTS transaction_hash_chain_id_uix
ON transactions(LOWER(transaction_hash), chain_id, LOWER(event_name));

CREATE INDEX IF NOT EXISTS transactions_block_timestamp_inx
ON transactions(block_timestamp);

CREATE INDEX IF NOT EXISTS transactions_block_number_inx
ON transactions(block_number);

CREATE INDEX IF NOT EXISTS transactions_chain_id_inx
ON transactions(chain_id);

/***************************************************************************************
event BaseUriSet(string previous, string current);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS base_uri_set
(
  previous                                          text,
  current                                           text
) INHERITS(transactions);

/***************************************************************************************
event SoulBound(uint256 id);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS soulbound
(
  id                                                uint256 UNIQUE
) INHERITS(transactions);


/***************************************************************************************
event DefaultRoyaltySet(address indexed sender, address indexed receiver, uint96 feeNumerator);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS default_royalty_set
(
  sender                                            address,
  receiver                                          address,
  fee_numerator                                     uint96
) INHERITS(transactions);

CREATE INDEX IF NOT EXISTS default_royalty_set_sender_inx
ON default_royalty_set(sender);

CREATE INDEX IF NOT EXISTS default_royalty_set_receiver_inx
ON default_royalty_set(receiver);

/***************************************************************************************
event DefaultRoyaltyDeleted(address indexed sender);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS default_royalty_deleted
(
  sender                                            address
) INHERITS(transactions);

CREATE INDEX IF NOT EXISTS default_royalty_deleted_sender_inx
ON default_royalty_deleted(sender);


/***************************************************************************************
event TokenRoyaltySet(address indexed sender, uint256 tokenId, address indexed receiver, uint96 feeNumerator);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS token_royalty_set
(
  sender                                            address,
  token_id                                          uint256,
  receiver                                          address,
  fee_numerator                                     uint96
) INHERITS(transactions);


CREATE INDEX IF NOT EXISTS token_royalty_set_sender_inx
ON token_royalty_set(sender);

CREATE INDEX IF NOT EXISTS token_royalty_set_token_id_inx
ON token_royalty_set(token_id);

CREATE INDEX IF NOT EXISTS token_royalty_set_receiver_inx
ON token_royalty_set(receiver);

/***************************************************************************************
event TokenRoyaltyReset(address indexed sender, uint256 tokenId);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS token_royalty_reset
(
  sender                                            address,
  token_id                                          uint256
) INHERITS(transactions);

CREATE INDEX IF NOT EXISTS token_royalty_reset_sender_inx
ON token_royalty_reset(sender);

/***************************************************************************************
event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS transfer_single
(
  operator                                          address,
  "from"                                            address,
  "to"                                              address,
  id                                                uint256,
  value                                             uint256
) INHERITS(transactions);

CREATE INDEX IF NOT EXISTS transfer_single_operator_inx
ON transfer_single(operator);

CREATE INDEX IF NOT EXISTS transfer_single_from_inx
ON transfer_single("from");

CREATE INDEX IF NOT EXISTS transfer_single_to_inx
ON transfer_single("to");

CREATE INDEX IF NOT EXISTS transfer_single_id_inx
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
CREATE TABLE IF NOT EXISTS transfer_batch
(
  operator                                          address,
  "from"                                            address,
  "to"                                              address,
  ids                                               uint256[],
  values                                            uint256[]
) INHERITS(transactions);

CREATE INDEX IF NOT EXISTS transfer_batch_operator_inx
ON transfer_batch(operator);

CREATE INDEX IF NOT EXISTS transfer_batch_from_inx
ON transfer_batch("from");

CREATE INDEX IF NOT EXISTS transfer_batch_to_inx
ON transfer_batch("to");

/***************************************************************************************
event ApprovalForAll(address indexed account, address indexed operator, bool approved);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS approval_for_all
(
  account                                           address,
  operator                                          address,
  approved                                          boolean
) INHERITS(transactions);

CREATE INDEX IF NOT EXISTS approval_for_all_account_inx
ON approval_for_all(account);

CREATE INDEX IF NOT EXISTS approval_for_all_operator_inx
ON approval_for_all(operator);

/***************************************************************************************
event URI(string value, uint256 indexed id);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS uri
(
  value                                             text,
  id                                                uint256
) INHERITS(transactions);

CREATE INDEX IF NOT EXISTS uri_id_inx
ON uri(id);

/***************************************************************************************
event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS role_admin_changed
(
  role                                              bytes32,
  previous_admin_role                               bytes32,
  new_admin_role                                    bytes32
) INHERITS(transactions);

CREATE INDEX IF NOT EXISTS role_admin_changed_role_inx
ON role_admin_changed(role);

CREATE INDEX IF NOT EXISTS role_admin_changed_previous_admin_role_inx
ON role_admin_changed(previous_admin_role);

CREATE INDEX IF NOT EXISTS role_admin_changed_new_admin_role_inx
ON role_admin_changed(new_admin_role);

/***************************************************************************************
event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS role_granted
(
  role                                              bytes32,
  account                                           address,
  sender                                            address
) INHERITS(transactions);


CREATE INDEX IF NOT EXISTS role_granted_role_inx
ON role_granted(role);

CREATE INDEX IF NOT EXISTS role_granted_account_inx
ON role_granted(account);

CREATE INDEX IF NOT EXISTS role_granted_sender_inx
ON role_granted(sender);

/***************************************************************************************
event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS role_revoked
(
  role                                              bytes32,
  account                                           address,
  sender                                            address
) INHERITS(transactions);


CREATE INDEX IF NOT EXISTS role_revoked_role_inx
ON role_revoked(role);

CREATE INDEX IF NOT EXISTS role_revoked_account_inx
ON role_revoked(account);

CREATE INDEX IF NOT EXISTS role_revoked_sender_inx
ON role_revoked(sender);


/***************************************************************************************
event Paused(address account);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS paused
(
  account                                           address
) INHERITS(transactions);


CREATE INDEX IF NOT EXISTS paused_account_inx
ON paused(account);

/***************************************************************************************
event Unpaused(address account);
***************************************************************************************/
CREATE TABLE IF NOT EXISTS unpaused
(
  account                                           address
) INHERITS(transactions);

CREATE INDEX IF NOT EXISTS unpaused_account_inx
ON unpaused(account);


CREATE TABLE IF NOT EXISTS persona_set
(
  account                                           address NOT NULL,
  persona                                           uint8 NOT NULL
) INHERITS(transactions);

CREATE UNIQUE INDEX IF NOT EXISTS persona_set_account_uix
ON persona_set(LOWER(account));

CREATE INDEX IF NOT EXISTS persona_set_persona_inx
ON persona_set(persona);

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
SELECT NULL AS level, 'Beast' AS role, 'Diabolic Grim Wyvern' AS name, 'A monstrous flying dragon vengefully targeting the chain' AS description, 190000 AS start_index, 100 AS siblings, 10 AS rarity, NULL AS stage
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

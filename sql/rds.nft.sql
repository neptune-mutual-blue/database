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

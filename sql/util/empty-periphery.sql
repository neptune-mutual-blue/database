DELETE FROM core.transactions
WHERE event_name IN 
(
  'PersonaSet',
  'BoundariesSet',
  'MerkleRootSet',
  'MintedWithProof',
  'PersonaSet',
  'SoulboundMinted',
  'DefaultRoyaltySet',
  'DefaultRoyaltyDeleted',
  'TokenRoyaltySet',
  'TokenRoyaltyReset',
  'BaseUriSet',
  'SoulBound',
  'VoteEscrowLock',
  'TransferWhitelistUpdated',
  'VoteEscrowUnlock',
  'BlocksPerEpochSet',
  'GaugeControllerRegistryOperatorSet',
  'GaugeControllerRegistryRewardsWithdrawn',
  'GaugeControllerRegistryPoolAddedOrEdited',
  'GaugeControllerRegistryPoolDeactivated',
  'GaugeControllerRegistryPoolActivated',
  'GaugeControllerRegistryPoolDeleted',
  'GaugeSet',
  'GaugeAllocationTransferred',
  'VotingPowersUpdated',
  'LiquidityGaugeRewardsWithdrawn',
  'LiquidityGaugeDeposited',
  'LiquidityGaugeWithdrawn',
  'LiquidityGaugePoolInitialized'
);


UPDATE vault.pods_issued SET ck = get_cover_key_by_vault_address(chain_id, address);
UPDATE vault.pods_redeemed SET ck = get_cover_key_by_vault_address(chain_id, address);

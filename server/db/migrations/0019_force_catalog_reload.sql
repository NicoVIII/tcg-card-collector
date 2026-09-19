-- migrate:up

-- 0018 added `cmc` and asked for a reload by nulling last_upstream_updated_at.
-- That is not the gate: refresh_record.is_probe_due keys off last_probe_at and
-- returns before decide() ever reads the upstream version, so instances that
-- probed within 24h skipped the reload and still hold NULL cmc. Clearing the
-- record is the reset that works — "never probed" is the one state both gates
-- read as "contact upstream and import".
DELETE FROM catalog_sync_metadata;

-- migrate:down

-- Nothing to restore: the record is sync bookkeeping the next probe rebuilds.

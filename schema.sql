-- Safe to re-run: psql $DATABASE_URL -f db/schema.sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS entities (
  uen                  TEXT,
  issuance_agency_desc TEXT,
  uen_status_desc      TEXT,
  entity_name          TEXT,
  entity_type_desc     TEXT,
  uen_issue_date       DATE,
  reg_street_name      TEXT,
  reg_postal_code      TEXT
);
-- Other indexes are created by scripts/ingest.js after each bulk load.

-- Required for sync upserts (ON CONFLICT (uen)).
-- If this fails with "could not create unique index", the table has duplicate UENs: re-run the ingest script (it removes duplicates).
CREATE UNIQUE INDEX IF NOT EXISTS entities_uen_key ON entities (uen);

CREATE TABLE IF NOT EXISTS sync_jobs (
  id            BIGSERIAL PRIMARY KEY,
  dataset_id    TEXT        NOT NULL,
  status        TEXT        NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed')),
  batch_size    INT         NOT NULL,
  next_offset   INT         NOT NULL DEFAULT 0,   -- checkpoint: where to continue
  rows_fetched  INT         NOT NULL DEFAULT 0,
  rows_changed  INT         NOT NULL DEFAULT 0,   -- inserted or actually modified
  rows_skipped  INT         NOT NULL DEFAULT 0,   -- invalid rows (e.g. missing UEN)
  source_total  INT,
  db_total      INT,
  note          TEXT,
  error         TEXT,
  started_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at   TIMESTAMPTZ
);
-- Database-enforced rule: only one running sync at a time.
CREATE UNIQUE INDEX IF NOT EXISTS sync_jobs_one_running ON sync_jobs ((true)) WHERE status = 'running';

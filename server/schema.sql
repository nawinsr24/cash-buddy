CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,            -- Google's permanent user number
  email TEXT NOT NULL,
  blocked INTEGER NOT NULL DEFAULT 0,
  consent_version INTEGER NOT NULL,
  consented_at INTEGER NOT NULL,
  first_seen INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  account_id TEXT,
  blocked INTEGER NOT NULL DEFAULT 0,
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS devices_first_seen ON devices(first_seen);

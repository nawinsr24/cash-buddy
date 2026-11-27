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
-- Shared groups. Notes are locked on the phones; the server cannot read them.
CREATE TABLE IF NOT EXISTS groups (
  id TEXT PRIMARY KEY, join_hash TEXT NOT NULL, join_until INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS members (
  group_id TEXT, member_id TEXT, account_id TEXT NOT NULL,
  PRIMARY KEY (group_id, member_id));
CREATE TABLE IF NOT EXISTS notes (
  group_id TEXT, note_id TEXT, sealed TEXT NOT NULL, expires INTEGER NOT NULL,
  PRIMARY KEY (group_id, note_id));
CREATE TABLE IF NOT EXISTS waiting (
  group_id TEXT, note_id TEXT, member_id TEXT,
  PRIMARY KEY (group_id, note_id, member_id));
CREATE TABLE IF NOT EXISTS highest (
  group_id TEXT, writer TEXT, seq INTEGER NOT NULL, PRIMARY KEY (group_id, writer));
CREATE TABLE IF NOT EXISTS requests (
  group_id TEXT, member_id TEXT, missing TEXT NOT NULL,
  PRIMARY KEY (group_id, member_id));

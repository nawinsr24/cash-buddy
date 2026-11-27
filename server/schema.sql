CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  blocked INTEGER NOT NULL DEFAULT 0,
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS devices_first_seen ON devices(first_seen);

CREATE TABLE IF NOT EXISTS app_migrations (
  id TEXT PRIMARY KEY,
  applied_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS owner_settings (
  key TEXT PRIMARY KEY,
  value_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

UPDATE owner_settings
   SET value_json = '{"enabled":true}',
       updated_at = CAST(strftime('%s','now') AS INTEGER) * 1000
 WHERE key = 'feature.room_creation'
   AND NOT EXISTS (
     SELECT 1 FROM app_migrations WHERE id = '20261013_room_creation_repair'
   );

INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at)
SELECT 'feature.room_creation',
       '{"enabled":true}',
       CAST(strftime('%s','now') AS INTEGER) * 1000
 WHERE NOT EXISTS (
   SELECT 1 FROM app_migrations WHERE id = '20261013_room_creation_repair'
 );

INSERT OR IGNORE INTO app_migrations (id, applied_at)
VALUES (
  '20261013_room_creation_repair',
  CAST(strftime('%s','now') AS INTEGER) * 1000
);

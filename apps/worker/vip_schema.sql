CREATE TABLE IF NOT EXISTS user_vip (
  user_id TEXT PRIMARY KEY,
  level INTEGER NOT NULL DEFAULT 0 CHECK (level BETWEEN 0 AND 18),
  exp_balance INTEGER NOT NULL DEFAULT 0 CHECK (exp_balance >= 0),
  total_received_coins INTEGER NOT NULL DEFAULT 0 CHECK (total_received_coins >= 0),
  active_until INTEGER,
  custom_id TEXT UNIQUE,
  last_id_change_at INTEGER,
  id_change_level INTEGER NOT NULL DEFAULT 0,
  preferences_json TEXT NOT NULL DEFAULT '{}',
  free_say_hi_used INTEGER NOT NULL DEFAULT 0 CHECK (free_say_hi_used BETWEEN 0 AND 4),
  free_say_hi_cycle TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS vip_events (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  coin_amount INTEGER NOT NULL DEFAULT 0,
  exp_delta INTEGER NOT NULL DEFAULT 0,
  level_before INTEGER NOT NULL DEFAULT 0,
  level_after INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_vip_level ON user_vip(level, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_vip_events_user_time ON vip_events(user_id, created_at DESC);

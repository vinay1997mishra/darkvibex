PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL DEFAULT '',
  avatar_key TEXT,
  role TEXT NOT NULL DEFAULT 'user'
    CHECK (role IN (
      'user',
      'room_owner',
      'room_admin',
      'moderator',
      'coin_seller',
      'merchant',
      'platform_owner'
    )),
  coins INTEGER NOT NULL DEFAULT 0 CHECK (coins >= 0),
  diamonds INTEGER NOT NULL DEFAULT 0 CHECK (diamonds >= 0),
  vip_level INTEGER NOT NULL DEFAULT 0 CHECK (vip_level >= 0),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS rooms (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  seat_count INTEGER NOT NULL DEFAULT 12 CHECK (seat_count BETWEEN 8 AND 42),
  locked INTEGER NOT NULL DEFAULT 0 CHECK (locked IN (0,1)),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (owner_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS room_members (
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  seat_index INTEGER,
  mic_muted INTEGER NOT NULL DEFAULT 1 CHECK (mic_muted IN (0,1)),
  joined_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, user_id),
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS room_messages (
  id TEXT PRIMARY KEY,
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  text TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS direct_messages (
  id TEXT PRIMARY KEY,
  sender_user_id TEXT NOT NULL,
  receiver_user_id TEXT NOT NULL,
  text TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  read_at INTEGER,
  FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (receiver_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS wallet_ledger (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  amount INTEGER NOT NULL,
  balance_after INTEGER NOT NULL,
  reference_id TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS gift_events (
  id TEXT PRIMARY KEY,
  room_id TEXT,
  sender_user_id TEXT NOT NULL,
  receiver_user_id TEXT NOT NULL,
  gift_id TEXT NOT NULL,
  coin_cost INTEGER NOT NULL CHECK (coin_cost > 0),
  created_at INTEGER NOT NULL,
  FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (receiver_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS game_bets (
  id TEXT PRIMARY KEY,
  game_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  stake INTEGER NOT NULL CHECK (stake > 0),
  result TEXT NOT NULL,
  payout INTEGER NOT NULL DEFAULT 0 CHECK (payout >= 0),
  created_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_rooms_owner ON rooms(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_room_members_room ON room_members(room_id);
CREATE INDEX IF NOT EXISTS idx_room_messages_room_time ON room_messages(room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dm_receiver_time ON direct_messages(receiver_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_user_time ON wallet_ledger(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gifts_receiver_time ON gift_events(receiver_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_game_bets_user_time ON game_bets(user_id, created_at DESC);


CREATE TABLE IF NOT EXISTS owner_user_controls (
  user_id TEXT PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','suspended','banned')),
  muted_until INTEGER,
  banned_until INTEGER,
  note TEXT NOT NULL DEFAULT '',
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS owner_settings (
  key TEXT PRIMARY KEY,
  value_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS owner_catalog (
  kind TEXT NOT NULL,
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
  sort_order INTEGER NOT NULL DEFAULT 0,
  price_coins INTEGER NOT NULL DEFAULT 0 CHECK (price_coins >= 0),
  country TEXT NOT NULL DEFAULT '',
  json_data TEXT NOT NULL DEFAULT '{}',
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (kind, id)
);

CREATE TABLE IF NOT EXISTS owner_staff (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL
    CHECK (role IN ('super_admin','admin','manager','moderator')),
  token_hash TEXT NOT NULL UNIQUE,
  permissions_json TEXT NOT NULL DEFAULT '[]',
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  last_used_at INTEGER
);

CREATE TABLE IF NOT EXISTS owner_audit (
  id TEXT PRIMARY KEY,
  actor_type TEXT NOT NULL,
  actor_id TEXT NOT NULL,
  action TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  summary TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS owner_announcements (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
  starts_at INTEGER,
  ends_at INTEGER,
  country TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_owner_catalog_kind
  ON owner_catalog(kind, sort_order, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_owner_audit_time
  ON owner_audit(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_owner_announcements_time
  ON owner_announcements(updated_at DESC);


-- Aladdin's Lamp / room daily tasks.
CREATE TABLE IF NOT EXISTS lamp_task_progress (
  room_id TEXT NOT NULL,
  day_key INTEGER NOT NULL,
  task_id TEXT NOT NULL,
  progress INTEGER NOT NULL DEFAULT 0,
  claimed_at INTEGER,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, day_key, task_id)
);

CREATE TABLE IF NOT EXISTS lamp_daily_uniques (
  room_id TEXT NOT NULL,
  day_key INTEGER NOT NULL,
  scope TEXT NOT NULL,
  user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, day_key, scope, user_id)
);

CREATE TABLE IF NOT EXISTS lamp_room_user_first_seen (
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  first_seen_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS lamp_room_user_days (
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  day_key INTEGER NOT NULL,
  first_entered_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, user_id, day_key)
);

CREATE TABLE IF NOT EXISTS room_followers (
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  followed_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS lamp_mic_invites (
  room_id TEXT NOT NULL,
  day_key INTEGER NOT NULL,
  invitee_user_id TEXT NOT NULL,
  invited_by_user_id TEXT NOT NULL,
  invited_at INTEGER NOT NULL,
  accepted_at INTEGER,
  PRIMARY KEY (room_id, day_key, invitee_user_id)
);

CREATE TABLE IF NOT EXISTS lamp_room_clock (
  room_id TEXT NOT NULL,
  day_key INTEGER NOT NULL,
  last_sample_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, day_key)
);

CREATE INDEX IF NOT EXISTS idx_lamp_progress_room_day
  ON lamp_task_progress(room_id, day_key);
CREATE INDEX IF NOT EXISTS idx_lamp_user_days_room_day
  ON lamp_room_user_days(room_id, day_key);
CREATE INDEX IF NOT EXISTS idx_room_followers_room
  ON room_followers(room_id);

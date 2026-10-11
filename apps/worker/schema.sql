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


CREATE TABLE IF NOT EXISTS user_entitlements (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  item_id TEXT NOT NULL,
  item_name TEXT NOT NULL,
  starts_at INTEGER NOT NULL,
  expires_at INTEGER,
  active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_entitlements_user ON user_entitlements(user_id, kind, expires_at);

CREATE TABLE IF NOT EXISTS families (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  owner_user_id TEXT NOT NULL,
  level INTEGER NOT NULL DEFAULT 1,
  experience INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS family_members (
  family_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  joined_at INTEGER NOT NULL,
  PRIMARY KEY (family_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_family_member_user ON family_members(user_id);
CREATE TABLE IF NOT EXISTS family_signins (
  family_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  day_key TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (family_id, user_id, day_key)
);

CREATE TABLE IF NOT EXISTS dollar_wallets (
  user_id TEXT PRIMARY KEY,
  balance_cents INTEGER NOT NULL DEFAULT 0 CHECK (balance_cents >= 0),
  updated_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS dollar_wallet_ledger (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,
  balance_after_cents INTEGER NOT NULL,
  destination_type TEXT NOT NULL DEFAULT '',
  destination_ref TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_dollar_ledger_user_time
  ON dollar_wallet_ledger(user_id, created_at DESC);


CREATE TABLE IF NOT EXISTS social_follows (
  follower_user_id TEXT NOT NULL,
  target_user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (follower_user_id, target_user_id)
);
CREATE TABLE IF NOT EXISTS user_blocks (
  user_id TEXT NOT NULL,
  target_user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, target_user_id)
);
CREATE TABLE IF NOT EXISTS user_reports (
  id TEXT PRIMARY KEY,
  reporter_user_id TEXT NOT NULL,
  target_user_id TEXT NOT NULL,
  room_id TEXT NOT NULL DEFAULT '',
  categories_json TEXT NOT NULL DEFAULT '[]',
  details TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'open',
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_reports_target_time
  ON user_reports(target_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS dynamic_posts (
  id TEXT PRIMARY KEY,
  author_user_id TEXT NOT NULL,
  text TEXT NOT NULL,
  topic TEXT NOT NULL DEFAULT '',
  state TEXT NOT NULL DEFAULT 'published',
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS dynamic_likes (
  post_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (post_id, user_id)
);
CREATE TABLE IF NOT EXISTS dynamic_comments (
  id TEXT PRIMARY KEY,
  post_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  text TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS parties (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  owner_user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  dress_up TEXT NOT NULL DEFAULT 'default',
  active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS party_members (
  party_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  joined_at INTEGER NOT NULL,
  PRIMARY KEY (party_id, user_id)
);

CREATE TABLE IF NOT EXISTS room_progress (
  room_id TEXT PRIMARY KEY,
  experience INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 1,
  active_exp INTEGER NOT NULL DEFAULT 0,
  sending_exp INTEGER NOT NULL DEFAULT 0,
  receiving_exp INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL DEFAULT '',
  avatar_key TEXT,
  date_of_birth TEXT,
  country_code TEXT,
  country_name TEXT,
  flag_emoji TEXT,
  gender TEXT,
  bio TEXT NOT NULL DEFAULT '',
  age_change_count INTEGER NOT NULL DEFAULT 0,
  country_change_count INTEGER NOT NULL DEFAULT 0,
  gender_change_count INTEGER NOT NULL DEFAULT 0,
  language TEXT NOT NULL DEFAULT 'English',
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
  country_code TEXT NOT NULL DEFAULT '',
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

CREATE TABLE IF NOT EXISTS room_message_images (
  message_id TEXT PRIMARY KEY,
  image_key TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (message_id) REFERENCES room_messages(id) ON DELETE CASCADE
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

CREATE TABLE IF NOT EXISTS inbox_red_envelopes (
  id TEXT PRIMARY KEY,
  sender_user_id TEXT NOT NULL,
  receiver_user_id TEXT NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','claimed','expired')),
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  claimed_at INTEGER,
  refund_token TEXT
);

CREATE TABLE IF NOT EXISTS inbox_red_envelope_claims (
  envelope_id TEXT PRIMARY KEY,
  claim_token TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  claimed_at INTEGER NOT NULL,
  FOREIGN KEY (envelope_id) REFERENCES inbox_red_envelopes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_inbox_envelopes_pair_time
  ON inbox_red_envelopes(sender_user_id, receiver_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS room_settings (
  room_id TEXT PRIMARY KEY,
  announcement TEXT NOT NULL DEFAULT '',
  theme_id TEXT NOT NULL DEFAULT 'dark',
  group_pk_enabled INTEGER NOT NULL DEFAULT 0 CHECK (group_pk_enabled IN (0,1)),
  welcome_image_key TEXT NOT NULL DEFAULT '',
  party_mode TEXT NOT NULL DEFAULT 'Friends-making Party',
  room_mode TEXT NOT NULL DEFAULT 'voice' CHECK (room_mode IN ('voice','game','live')),
  seat_theme_id TEXT NOT NULL DEFAULT 'royal-gold',
  lock_password_hash TEXT NOT NULL DEFAULT '',
  mic_mode TEXT NOT NULL DEFAULT 'free' CHECK (mic_mode IN ('free','apply')),
  public_screen_enabled INTEGER NOT NULL DEFAULT 1 CHECK (public_screen_enabled IN (0,1)),
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS room_seat_controls (
  room_id TEXT NOT NULL,
  seat_index INTEGER NOT NULL,
  locked INTEGER NOT NULL DEFAULT 0 CHECK (locked IN (0,1)),
  room_muted INTEGER NOT NULL DEFAULT 0 CHECK (room_muted IN (0,1)),
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, seat_index),
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS room_seat_requests (
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  seat_index INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, user_id),
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS room_chat_bans (
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  banned_by TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, user_id),
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS room_seat_invites (
  room_id TEXT NOT NULL,
  target_user_id TEXT NOT NULL,
  seat_index INTEGER NOT NULL,
  invited_by TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, target_user_id),
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (target_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS legal_consents (
  user_id TEXT NOT NULL,
  version TEXT NOT NULL,
  accepted_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, version),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS room_images (
  room_id TEXT PRIMARY KEY,
  image_key TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS direct_message_images (
  message_id TEXT PRIMARY KEY,
  image_key TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS user_cosmetics (
  user_id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('frame','vehicle')),
  acquired_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  active INTEGER NOT NULL DEFAULT 0 CHECK (active IN (0,1)),
  PRIMARY KEY (user_id, item_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_user_cosmetics_active
  ON user_cosmetics(user_id, kind, active, expires_at);

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

CREATE TABLE IF NOT EXISTS user_friends (
  user_id TEXT NOT NULL,
  friend_user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, friend_user_id),
  CHECK (user_id <> friend_user_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (friend_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS game_rooms (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  shared_score INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS game_room_members (
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  seat_index INTEGER NOT NULL,
  joined_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, user_id),
  UNIQUE (room_id, seat_index),
  FOREIGN KEY (room_id) REFERENCES game_rooms(id) ON DELETE CASCADE,
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


-- Tinnistar-style social surfaces used by DarkVibeX.
CREATE TABLE IF NOT EXISTS official_notices (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS user_follows (
  follower_id TEXT NOT NULL,
  target_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (follower_id, target_id),
  CHECK (follower_id <> target_id)
);

CREATE TABLE IF NOT EXISTS user_task_claims (
  user_id TEXT NOT NULL,
  task_id TEXT NOT NULL,
  reward_coins INTEGER NOT NULL,
  claimed_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, task_id)
);

CREATE TABLE IF NOT EXISTS user_feedback (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  category TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'submitted',
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS families (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  tag TEXT NOT NULL,
  leader_user_id TEXT NOT NULL,
  notice TEXT NOT NULL DEFAULT '',
  experience INTEGER NOT NULL DEFAULT 0,
  wallet_coins INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS family_members (
  family_id TEXT NOT NULL,
  user_id TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL DEFAULT 'member',
  joined_at INTEGER NOT NULL,
  PRIMARY KEY (family_id, user_id)
);

CREATE TABLE IF NOT EXISTS family_join_requests (
  family_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (family_id, user_id)
);

CREATE TABLE IF NOT EXISTS family_daily_logins (
  family_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  day_key TEXT NOT NULL,
  exp_awarded INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (family_id, user_id, day_key)
);

CREATE TABLE IF NOT EXISTS cp_relationships (
  user_a TEXT NOT NULL,
  user_b TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'pending',
  intimacy INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 1,
  requested_by TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_a, user_b)
);

CREATE TABLE IF NOT EXISTS cp_memories (
  id TEXT PRIMARY KEY,
  user_a TEXT NOT NULL,
  user_b TEXT NOT NULL,
  body TEXT NOT NULL,
  created_by TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS vs_relationships (
  user_a TEXT NOT NULL,
  user_b TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'pending',
  rivalry INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 1,
  requested_by TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_a, user_b)
);


CREATE TABLE IF NOT EXISTS direct_calls (
  id TEXT PRIMARY KEY,
  caller_user_id TEXT NOT NULL,
  receiver_user_id TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'ringing',
  created_at INTEGER NOT NULL,
  answered_at INTEGER,
  ended_at INTEGER,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_direct_calls_receiver_state
  ON direct_calls(receiver_user_id,state,created_at DESC);

CREATE INDEX IF NOT EXISTS idx_direct_calls_caller_state
  ON direct_calls(caller_user_id,state,created_at DESC);

-- Invite & Share direct-referral commission.
-- Invitation code is the inviter's unique DarkVibeX public user ID.
CREATE TABLE IF NOT EXISTS invite_bindings (
  invitee_user_id TEXT PRIMARY KEY,
  inviter_user_id TEXT NOT NULL,
  invitation_code TEXT NOT NULL,
  bound_at INTEGER NOT NULL,
  CHECK (invitee_user_id <> inviter_user_id),
  FOREIGN KEY (invitee_user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (inviter_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_invite_bindings_inviter
  ON invite_bindings(inviter_user_id, bound_at DESC);

CREATE TABLE IF NOT EXISTS invite_commission_rewards (
  id TEXT PRIMARY KEY,
  inviter_user_id TEXT NOT NULL,
  invitee_user_id TEXT NOT NULL,
  source_transfer_id TEXT NOT NULL UNIQUE,
  source_coins INTEGER NOT NULL CHECK (source_coins > 0),
  rate_bps INTEGER NOT NULL CHECK (rate_bps >= 0),
  reward_coins INTEGER NOT NULL CHECK (reward_coins >= 0),
  created_at INTEGER NOT NULL,
  FOREIGN KEY (inviter_user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (invitee_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_invite_rewards_inviter_time
  ON invite_commission_rewards(inviter_user_id, created_at DESC);


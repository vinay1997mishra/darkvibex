export async function ensureSupportSchema(db) {
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS vip_support_tickets (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      subject TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS vip_support_messages (
      id TEXT PRIMARY KEY,
      ticket_id TEXT NOT NULL,
      sender_type TEXT NOT NULL CHECK (sender_type IN ('user','staff')),
      sender_id TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (ticket_id) REFERENCES vip_support_tickets(id) ON DELETE CASCADE
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_vip_support_user_updated ON vip_support_tickets(user_id, updated_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_vip_support_messages_ticket ON vip_support_messages(ticket_id, created_at ASC)"),
  ]);
}

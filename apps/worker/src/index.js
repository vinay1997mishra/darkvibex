import { normalizeRole } from "./role_policy.js";
import { handleOwnerApi } from "./owner_api.js";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,PUT,DELETE,OPTIONS",
  "access-control-allow-headers": "authorization,content-type,x-file-key",
};

const json = (data, init = {}) =>
  new Response(JSON.stringify(data), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...corsHeaders,
      ...(init.headers ?? {}),
    },
  });

const now = () => Date.now();
const id = () => crypto.randomUUID();

const encoder = new TextEncoder();
const decoder = new TextDecoder();

function base64UrlBytes(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlText(value) {
  return base64UrlBytes(encoder.encode(value));
}

function decodeBase64UrlText(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = Uint8Array.from(binary, (ch) => ch.charCodeAt(0));
  return decoder.decode(bytes);
}

async function hmacSignature(secret, input) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(input));
  return base64UrlBytes(new Uint8Array(signature));
}

async function signJwt(secret, header, payload) {
  const head = base64UrlText(JSON.stringify(header));
  const body = base64UrlText(JSON.stringify(payload));
  const input = head + "." + body;
  return input + "." + await hmacSignature(secret, input);
}

async function verifySessionToken(token, secret) {
  const parts = String(token ?? "").split(".");
  if (parts.length !== 3) throw new Error("invalid_session");
  const input = parts[0] + "." + parts[1];
  const expected = await hmacSignature(secret, input);
  if (expected !== parts[2]) throw new Error("invalid_session");
  const payload = JSON.parse(decodeBase64UrlText(parts[1]));
  const seconds = Math.floor(Date.now() / 1000);
  if (!payload?.sub || Number(payload.exp ?? 0) <= seconds) {
    throw new Error("session_expired");
  }
  return payload;
}


async function createSessionToken(env, userId, displayName) {
  if (!env.SESSION_SECRET) throw new Error("session_secret_not_configured");
  const seconds = Math.floor(Date.now() / 1000);
  return signJwt(
    String(env.SESSION_SECRET),
    { alg: "HS256", typ: "JWT" },
    {
      sub: String(userId),
      name: String(displayName ?? userId),
      iat: seconds,
      exp: seconds + 60 * 60 * 24 * 7,
    },
  );
}

async function verifyGoogleIdToken(idToken, expectedAudience) {
  const audience = String(expectedAudience ?? "").trim();
  if (!audience) throw new Error("google_auth_not_configured");
  const token = String(idToken ?? "").trim();
  if (!token) throw new Error("google_id_token_required");

  const response = await fetch(
    "https://oauth2.googleapis.com/tokeninfo?id_token=" + encodeURIComponent(token),
    { headers: { accept: "application/json" } },
  );
  if (!response.ok) throw new Error("invalid_google_token");
  const claims = await response.json();

  if (String(claims.aud ?? "") !== audience) {
    throw new Error("invalid_google_audience");
  }
  const issuer = String(claims.iss ?? "");
  if (issuer !== "accounts.google.com" && issuer !== "https://accounts.google.com") {
    throw new Error("invalid_google_issuer");
  }
  if (!claims.sub) throw new Error("invalid_google_subject");

  const verified = claims.email_verified === true || String(claims.email_verified ?? "") === "true";
  if (claims.email && !verified) throw new Error("google_email_not_verified");
  return claims;
}

function bearerToken(request) {
  const value = String(request.headers.get("authorization") ?? "");
  return value.startsWith("Bearer ") ? value.slice(7).trim() : "";
}

async function bodyJson(request) {
  const value = await request.json();
  if (!value || typeof value !== "object") throw new Error("invalid_json");
  return value;
}

function requireDb(env) {
  if (!env.DB) throw new Error("database_not_bound");
  return env.DB;
}

async function ownerSetting(db, key, fallback = {}) {
  try {
    const row = await db.prepare("SELECT value_json FROM owner_settings WHERE key = ?").bind(key).first();
    if (!row?.value_json) return fallback;
    const parsed = JSON.parse(String(row.value_json));
    return parsed && typeof parsed === "object" ? parsed : fallback;
  } catch (error) {
    if (String(error?.message ?? error).includes("no such table")) return fallback;
    throw error;
  }
}

async function ensureUserAllowed(db, userId, { checkMute = false } = {}) {
  try {
    const control = await db.prepare(
      "SELECT status, muted_until, banned_until FROM owner_user_controls WHERE user_id = ?"
    ).bind(userId).first();
    if (!control) return;
    const ts = now();
    const bannedActive = control.status === "banned" &&
      (control.banned_until == null || Number(control.banned_until) <= 0 || Number(control.banned_until) > ts);
    if (bannedActive) throw new Error("user_banned");
    if (control.status === "suspended") throw new Error("user_suspended");
    if (checkMute && Number(control.muted_until ?? 0) > ts) throw new Error("user_muted");
  } catch (error) {
    if (String(error?.message ?? error).includes("no such table")) return;
    throw error;
  }
}

async function activeAnnouncements(db) {
  try {
    const ts = now();
    const rows = await db.prepare(
      `SELECT id,title,body,country,starts_at,ends_at,updated_at
         FROM owner_announcements
        WHERE enabled = 1
          AND (starts_at IS NULL OR starts_at <= ?)
          AND (ends_at IS NULL OR ends_at >= ?)
        ORDER BY updated_at DESC LIMIT 20`
    ).bind(ts, ts).all();
    return rows.results ?? [];
  } catch (error) {
    if (String(error?.message ?? error).includes("no such table")) return [];
    throw error;
  }
}

async function publicCatalog(db, kind) {
  try {
    const rows = await db.prepare(
      "SELECT kind,id,name,sort_order,price_coins,country,json_data,updated_at FROM owner_catalog WHERE kind = ? AND enabled = 1 ORDER BY sort_order ASC, updated_at DESC LIMIT 300"
    ).bind(kind).all();
    return (rows.results ?? []).map((row) => {
      let data = {};
      try { data = JSON.parse(String(row.json_data ?? "{}")); } catch (_) {}
      return { ...row, data };
    });
  } catch (error) {
    if (String(error?.message ?? error).includes("no such table")) return [];
    throw error;
  }
}

async function ensureUser(db, userId, displayName = "DarkVibeX User") {
  const ts = now();
  await db.prepare(
    `INSERT INTO users (id, display_name, role, coins, diamonds, vip_level, created_at, updated_at)
     VALUES (?, ?, 'user', 2500000, 120, 1, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       display_name = CASE WHEN excluded.display_name <> '' THEN excluded.display_name ELSE users.display_name END,
       updated_at = excluded.updated_at`
  ).bind(userId, displayName, ts, ts).run();
  return db.prepare(
    "SELECT id, display_name, role, coins, diamonds, vip_level, avatar_key FROM users WHERE id = ?"
  ).bind(userId).first();
}

async function listRooms(db) {
  const cutoff = now() - 60000;
  const result = await db.prepare(
    `SELECT r.id, r.name, r.owner_user_id, r.seat_count, r.locked,
            COALESCE(u.display_name, '') AS owner_name,
            (SELECT COUNT(*) FROM room_members m WHERE m.room_id = r.id AND m.updated_at > ?) AS online
       FROM rooms r
       LEFT JOIN users u ON u.id = r.owner_user_id
      ORDER BY r.updated_at DESC
      LIMIT 100`
  ).bind(cutoff).all();
  return result.results ?? [];
}

async function walletChange(db, userId, amount, kind, referenceId = null) {
  const user = await db.prepare("SELECT coins FROM users WHERE id = ?").bind(userId).first();
  if (!user) throw new Error("user_not_found");
  const current = Number(user.coins ?? 0);
  const next = current + Number(amount);
  if (!Number.isSafeInteger(next) || next < 0) throw new Error("insufficient_coins");

  const ts = now();
  await db.batch([
    db.prepare("UPDATE users SET coins = ?, updated_at = ? WHERE id = ?").bind(next, ts, userId),
    db.prepare(
      "INSERT INTO wallet_ledger (id, user_id, kind, amount, balance_after, reference_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
    ).bind(id(), userId, kind, amount, next, referenceId, ts),
  ]);
  return next;
}


const DEFAULT_GIFTS = [
  {id:"rose",name:"Rose",emoji:"🌹",category:"popular",price_coins:1000,effect:"compact"},
  {id:"star",name:"Shining Star",emoji:"⭐",category:"popular",price_coins:5000,effect:"compact"},
  {id:"crown",name:"Golden Crown",emoji:"👑",category:"popular",price_coins:50000,effect:"overlay"},
  {id:"sports-car",name:"Sports Car",emoji:"🏎️",category:"popular",price_coins:500000,effect:"cinematic"},
  {id:"dragon",name:"Royal Dragon",emoji:"🐉",category:"popular",price_coins:5000000,effect:"cinematic"},
  {id:"lucky-candy-star",name:"Candy Star",emoji:"🍬",category:"lucky",price_coins:10000,effect:"overlay"},
  {id:"lucky-rainbow-heart",name:"Rainbow Heart",emoji:"💖",category:"lucky",price_coins:25000,effect:"overlay"},
  {id:"lucky-galaxy-ring",name:"Galaxy Ring",emoji:"💍",category:"lucky",price_coins:100000,effect:"cinematic"},
  {id:"lucky-unicorn",name:"Shining Unicorn",emoji:"🦄",category:"lucky",price_coins:500000,effect:"cinematic"},
  {id:"music-mic",name:"Golden Mic",emoji:"🎤",category:"music",price_coins:20000,effect:"overlay"},
  {id:"music-guitar",name:"Electric Guitar",emoji:"🎸",category:"music",price_coins:50000,effect:"overlay"},
  {id:"music-dj",name:"DJ Stage",emoji:"🎧",category:"music",price_coins:200000,effect:"cinematic"},
  {id:"lucky-bag-bronze",name:"Lucky Bag",emoji:"🧧",category:"lucky_bag",price_coins:100000,effect:"overlay"},
  {id:"lucky-bag-gold",name:"Royal Lucky Bag",emoji:"🎁",category:"lucky_bag",price_coins:500000,effect:"cinematic"},
  {id:"four-box",name:"4 Box",emoji:"🎁",category:"four_box",price_coins:100000,effect:"overlay"},
  {id:"rank-crown",name:"Rank Crown",emoji:"🏆",category:"rank_hall",price_coins:500000,effect:"cinematic"},
  {id:"custom-spark",name:"Custom Spark",emoji:"✨",category:"custom",price_coins:50000,effect:"overlay"},
  {id:"peace",name:"Peace",emoji:"🕊️",category:"moderation",price_coins:10000,effect:"compact"},
  {id:"respect",name:"Respect",emoji:"🤝",category:"moderation",price_coins:25000,effect:"compact"},
  {id:"cp-rose",name:"CP Rose",emoji:"🌹",category:"cp",price_coins:44444,effect:"compact"},
  {id:"cp-heart",name:"CP Heart",emoji:"💞",category:"cp",price_coins:150000,effect:"overlay"},
  {id:"cp-ring",name:"CP Ring",emoji:"💍",category:"cp",price_coins:500000,effect:"overlay"},
  {id:"cp-castle",name:"CP Castle",emoji:"🏰",category:"cp",price_coins:2500000,effect:"cinematic"},
  {id:"cp-forever",name:"Forever CP",emoji:"♾️",category:"cp",price_coins:10000000,effect:"cinematic"},
  {id:"enemy-broken-rose",name:"Broken Rose",emoji:"🥀",category:"enemy",price_coins:44444,effect:"compact"},
  {id:"enemy-cracked-heart",name:"Cracked Heart",emoji:"💔",category:"enemy",price_coins:150000,effect:"overlay"},
  {id:"enemy-poison-bottle",name:"Poison Bottle",emoji:"🧪",category:"enemy",price_coins:350000,effect:"overlay"},
  {id:"enemy-dagger",name:"Dagger",emoji:"🗡️",category:"enemy",price_coins:500000,effect:"overlay"},
  {id:"enemy-black-scorpion",name:"Black Scorpion",emoji:"🦂",category:"enemy",price_coins:850000,effect:"overlay"},
  {id:"enemy-venom-snake",name:"Venom Snake",emoji:"🐍",category:"enemy",price_coins:1200000,effect:"overlay"},
  {id:"enemy-skull",name:"Skull",emoji:"💀",category:"enemy",price_coins:1550000,effect:"overlay"},
  {id:"enemy-broken-crown",name:"Broken Crown",emoji:"♛",category:"enemy",price_coins:1900000,effect:"overlay"},
  {id:"enemy-dark-chains",name:"Dark Chains",emoji:"⛓️",category:"enemy",price_coins:2250000,effect:"cinematic"},
  {id:"enemy-war-hammer",name:"War Hammer",emoji:"🔨",category:"enemy",price_coins:2600000,effect:"cinematic"},
  {id:"enemy-thunder-axe",name:"Thunder Axe",emoji:"🪓",category:"enemy",price_coins:2950000,effect:"cinematic"},
  {id:"enemy-demon-mask",name:"Demon Mask",emoji:"👹",category:"enemy",price_coins:3300000,effect:"cinematic"},
  {id:"enemy-hell-hound",name:"Hell Hound",emoji:"🐕",category:"enemy",price_coins:3650000,effect:"cinematic"},
  {id:"enemy-shadow-panther",name:"Shadow Panther",emoji:"🐆",category:"enemy",price_coins:4000000,effect:"cinematic"},
  {id:"enemy-blood-wolf",name:"Blood Wolf",emoji:"🐺",category:"enemy",price_coins:4350000,effect:"cinematic"},
  {id:"enemy-dark-phoenix",name:"Dark Phoenix",emoji:"🔥",category:"enemy",price_coins:6000000,effect:"cinematic"},
  {id:"enemy-demon-dragon",name:"Demon Dragon",emoji:"🐉",category:"enemy",price_coins:8000000,effect:"cinematic"},
  {id:"enemy-war-of-rivals",name:"War of Rivals",emoji:"⚔️",category:"enemy",price_coins:12000000,effect:"cinematic"},
  {id:"enemy-throne",name:"Throne of Enemies",emoji:"♜",category:"enemy",price_coins:15000000,effect:"cinematic"},
  {id:"enemy-apocalypse",name:"Apocalypse",emoji:"🌩️",category:"enemy",price_coins:20000000,effect:"cinematic"}
];

const DEFAULT_STORE = {
  vip:[
    {id:"vip-1",name:"VIP 1",price_coins:2000000,data:{duration_days:30,level:1}},
    {id:"vip-2",name:"VIP 2",price_coins:5000000,data:{duration_days:30,level:2}},
    {id:"vip-3",name:"VIP 3",price_coins:10000000,data:{duration_days:30,level:3}}
  ],
  frame:[
    {id:"frame-gold",name:"Gold Frame",price_coins:1000000,data:{duration_days:7}},
    {id:"frame-neon",name:"Neon Frame",price_coins:2500000,data:{duration_days:7}}
  ],
  ring:[
    {id:"ring-galaxy",name:"Galaxy Ring",price_coins:2000000,data:{duration_days:7}},
    {id:"ring-flame",name:"Flame Ring",price_coins:3500000,data:{duration_days:7}}
  ],
  bubble:[
    {id:"bubble-gold",name:"Gold Chat Bubble",price_coins:500000,data:{duration_days:7}},
    {id:"bubble-neon",name:"Neon Chat Bubble",price_coins:1000000,data:{duration_days:7}}
  ],
  profile_background:[
    {id:"bg-midnight",name:"Midnight Profile",price_coins:1500000,data:{duration_days:7}},
    {id:"bg-royal",name:"Royal Profile",price_coins:3000000,data:{duration_days:7}}
  ],
  vehicle:[
    {id:"vehicle-supercar",name:"Supercar Entry",price_coins:3000000,data:{duration_days:7}},
    {id:"vehicle-dragon",name:"Dragon Entry",price_coins:8000000,data:{duration_days:7}}
  ],
  theme:[
    {id:"theme-black-gold",name:"Black Gold Room",price_coins:10000000,data:{duration_days:7}},
    {id:"theme-neon-night",name:"Neon Night Room",price_coins:10000000,data:{duration_days:7}}
  ],
  tag:[
    {id:"tag-vibe",name:"VIBE",price_coins:500000,data:{duration_days:30}},
    {id:"tag-royal",name:"ROYAL",price_coins:1500000,data:{duration_days:30}}
  ]
};

const FRUITS = {
  lemon:{key:"lemon",emoji:"🍋",label:"Lemon",multiplier:5},
  raspberry:{key:"raspberry",emoji:"🫐",label:"Raspberry",multiplier:5},
  kiwi:{key:"kiwi",emoji:"🥝",label:"Kiwi",multiplier:5},
  plum:{key:"plum",emoji:"🍑",label:"Plum",multiplier:5},
  banana:{key:"banana",emoji:"🍌",label:"Banana",multiplier:10},
  strawberry:{key:"strawberry",emoji:"🍓",label:"Strawberry",multiplier:15},
  watermelon:{key:"watermelon",emoji:"🍉",label:"Watermelon",multiplier:25},
  cherry:{key:"cherry",emoji:"🍒",label:"Cherry",multiplier:45}
};
const FRUIT_STAKES = new Set([5000,25000,100000,500000,2000000,10000000]);

function defaultCatalog(kind) {
  if (kind === "gift") return DEFAULT_GIFTS.map((g,index)=>({
    kind:"gift",id:g.id,name:g.name,sort_order:index,price_coins:g.price_coins,country:"",
    data:{emoji:g.emoji,category:g.category,effect:g.effect}
  }));
  const rows = DEFAULT_STORE[kind] ?? [];
  return rows.map((g,index)=>({kind,id:g.id,name:g.name,sort_order:index,price_coins:g.price_coins,country:"",data:g.data??{}}));
}

function mergeCatalog(defaults, ownerRows) {
  const byId = new Map(defaults.map((row)=>[row.id,row]));
  for (const row of ownerRows) byId.set(row.id,row);
  return [...byId.values()].sort((a,b)=>Number(a.sort_order??0)-Number(b.sort_order??0));
}

async function catalogItem(db, kind, itemId) {
  const ownerRows = await publicCatalog(db, kind);
  const merged = mergeCatalog(defaultCatalog(kind), ownerRows);
  return merged.find((row)=>String(row.id)===String(itemId)) ?? null;
}

function relationshipLevel(progress) {
  const thresholds=[0,500000,1500000,3000000,6000000,10000000,20000000,35000000,55000000,80000000];
  let level=1;
  for (let i=1;i<thresholds.length;i+=1) if (progress>=thresholds[i]) level=i+1;
  const previous=thresholds[Math.min(level-1,thresholds.length-1)];
  const next=thresholds[level] ?? null;
  return {level,previous_threshold:previous,next_threshold:next};
}

async function relationshipProgress(db, userA, userB, kind) {
  const prefix = kind === "enemy" ? "enemy-%" : "cp-%";
  const row = await db.prepare(
    "SELECT COALESCE(SUM(coin_cost),0) AS progress FROM gift_events WHERE gift_id LIKE ? AND ((sender_user_id=? AND receiver_user_id=?) OR (sender_user_id=? AND receiver_user_id=?))"
  ).bind(prefix,userA,userB,userB,userA).first();
  const progress=Number(row?.progress??0);
  return {kind,progress,...relationshipLevel(progress)};
}

async function ensureParityTables(db) {
  await db.batch([
    db.prepare("CREATE TABLE IF NOT EXISTS user_entitlements (id TEXT PRIMARY KEY,user_id TEXT NOT NULL,kind TEXT NOT NULL,item_id TEXT NOT NULL,item_name TEXT NOT NULL,starts_at INTEGER NOT NULL,expires_at INTEGER,active INTEGER NOT NULL DEFAULT 1 CHECK(active IN(0,1)),created_at INTEGER NOT NULL)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_entitlements_user ON user_entitlements(user_id,kind,expires_at)"),
    db.prepare("CREATE TABLE IF NOT EXISTS families (id TEXT PRIMARY KEY,name TEXT NOT NULL,owner_user_id TEXT NOT NULL,level INTEGER NOT NULL DEFAULT 1,experience INTEGER NOT NULL DEFAULT 0,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL)"),
    db.prepare("CREATE TABLE IF NOT EXISTS family_members (family_id TEXT NOT NULL,user_id TEXT NOT NULL,role TEXT NOT NULL DEFAULT 'member',joined_at INTEGER NOT NULL,PRIMARY KEY(family_id,user_id))"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_family_member_user ON family_members(user_id)"),
    db.prepare("CREATE TABLE IF NOT EXISTS family_signins (family_id TEXT NOT NULL,user_id TEXT NOT NULL,day_key TEXT NOT NULL,created_at INTEGER NOT NULL,PRIMARY KEY(family_id,user_id,day_key))")
  ]);
}

function mixRound(value) {
  let x=(Number(value)>>>0)+0x9e3779b9;
  x^=x>>>16;x=Math.imul(x,0x21f0aaad);x^=x>>>15;x=Math.imul(x,0x735a2d97);x^=x>>>15;
  return x>>>0;
}
function fruitOutcome(roundId) {
  const seed=mixRound(roundId);
  const bucket=seed%1000;
  let pool;
  if (bucket<750) pool=["lemon","raspberry","kiwi","plum"];
  else if (bucket<950) pool=["banana","strawberry","watermelon"];
  else pool=["cherry"];
  const winner=pool[mixRound(seed+17)%pool.length];
  const lucky=(mixRound(seed+31)%67)===0;
  const all=Object.keys(FRUITS);
  const bonus=[];
  if (lucky) {
    let cursor=seed;
    while (bonus.length<4) {
      cursor=mixRound(cursor+bonus.length+1);
      const key=all[cursor%all.length];
      if (!bonus.includes(key)) bonus.push(key);
    }
  }
  return {round_id:roundId,winner,lucky11:lucky,bonus_fruits:bonus};
}
function fruitRound(ts=now()) {
  const cycle=26000,betting=21000;
  const roundId=Math.floor(ts/cycle);
  const pos=((ts%cycle)+cycle)%cycle;
  const phase=pos<betting?"betting":"result";
  const remaining=phase==="betting"?betting-pos:cycle-pos;
  return {...fruitOutcome(roundId),phase,remaining_ms:remaining,round_end:ts+remaining,cycle_end:ts+(cycle-pos),round_duration_ms:betting};
}

async function settleFruitBets(db,userId) {
  const current=fruitRound();
  const pending=await db.prepare(
    "SELECT id,stake,result FROM game_bets WHERE game_id='fruit-party' AND user_id=? AND result LIKE 'pending|%' ORDER BY created_at ASC LIMIT 200"
  ).bind(userId).all();
  for (const bet of pending.results??[]) {
    const parts=String(bet.result??"").split("|");
    if (parts.length<3) continue;
    const roundId=Number(parts[1]),choice=parts[2];
    const ready=roundId<current.round_id || (roundId===current.round_id && current.phase==="result");
    if (!ready || !FRUITS[choice]) continue;
    const outcome=fruitOutcome(roundId);
    const hit=choice===outcome.winner || (outcome.lucky11 && outcome.bonus_fruits.includes(choice));
    const payout=hit?Number(bet.stake)*FRUITS[choice].multiplier:0;
    const settled="settled|"+roundId+"|"+outcome.winner+"|"+choice+"|"+(outcome.lucky11?"lucky11":"normal");
    const changed=await db.prepare(
      "UPDATE game_bets SET result=?,payout=? WHERE id=? AND result LIKE 'pending|%'"
    ).bind(settled,payout,bet.id).run();
    if (Number(changed.meta?.changes??0)>0 && payout>0) {
      await walletChange(db,userId,payout,"game_win",bet.id);
    }
  }
}

async function fruitState(db,userId) {
  await ensureUser(db,userId);
  await settleFruitBets(db,userId);
  const current=fruitRound();
  const wallet=await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
  const bets=await db.prepare(
    "SELECT id,stake,result,payout,created_at FROM game_bets WHERE game_id='fruit-party' AND user_id=? ORDER BY created_at DESC LIMIT 100"
  ).bind(userId).all();
  const history=[];
  for (let i=1;i<=7;i+=1) {
    const outcome=fruitOutcome(current.round_id-i);
    history.push({...outcome,fruit:FRUITS[outcome.winner]});
  }
  const top=await db.prepare(
    "SELECT b.user_id,u.display_name,b.payout,b.result,b.created_at FROM game_bets b LEFT JOIN users u ON u.id=b.user_id WHERE b.game_id='fruit-party' AND b.payout>0 ORDER BY b.created_at DESC,b.payout DESC LIMIT 30"
  ).all();
  const topWinners=(top.results??[]).sort((a,b)=>Number(b.payout??0)-Number(a.payout??0)).slice(0,3);
  const myBets={};
  for (const bet of bets.results??[]) {
    const parts=String(bet.result??"").split("|");
    if (parts[0]==="pending" && Number(parts[1])===current.round_id) {
      myBets[parts[2]]=(myBets[parts[2]]??0)+Number(bet.stake??0);
    }
  }
  return {
    ok:true,server_time:now(),wallet_balance:Number(wallet?.coins??0),round:current,
    fruits:Object.values(FRUITS),my_bets:myBets,history,top_winners:topWinners
  };
}

async function handleApi(request, env, url) {
  const db = requireDb(env);
  const parts = url.pathname.split("/").filter(Boolean);

  if (url.pathname === "/api/auth/config" && request.method === "GET") {
    return json({
      ok: true,
      google_web_client_id: String(env.GOOGLE_WEB_CLIENT_ID ?? ""),
    });
  }

  const maintenance = await ownerSetting(db, "maintenance", { enabled: false, message: "" });
  if (maintenance.enabled === true && url.pathname !== "/api/config") {
    return json({ ok: false, error: "maintenance", message: String(maintenance.message ?? "") }, { status: 503 });
  }

  if (url.pathname === "/api/config" && request.method === "GET") {
    const keys = ["feature.voice", "feature.gifts", "feature.games", "feature.messages", "feature.room_creation", "feature.store", "feature.family", "feature.relationships", "feature.music", "maintenance"];
    const settings = {};
    for (const key of keys) settings[key] = await ownerSetting(db, key, {});
    return json({ ok: true, settings, announcements: await activeAnnouncements(db) });
  }

  if (url.pathname === "/api/catalog" && request.method === "GET") {
    const kind = String(url.searchParams.get("kind") ?? "").trim().slice(0, 60);
    if (!kind) return json({ ok: false, error: "kind_required" }, { status: 400 });
    const ownerItems = await publicCatalog(db, kind);
    return json({ ok: true, items: mergeCatalog(defaultCatalog(kind), ownerItems).slice(0, 300) });
  }

  if (url.pathname === "/api/search" && request.method === "GET") {
    const q=String(url.searchParams.get("q")??"").trim().slice(0,80);
    if (!q) return json({ok:true,rooms:[],users:[]});
    const like="%"+q+"%";
    const rooms=await db.prepare("SELECT id,name,owner_user_id,seat_count,locked FROM rooms WHERE id LIKE ? OR name LIKE ? ORDER BY updated_at DESC LIMIT 30").bind(like,like).all();
    const users=await db.prepare("SELECT id,display_name,vip_level,avatar_key FROM users WHERE id LIKE ? OR display_name LIKE ? ORDER BY updated_at DESC LIMIT 30").bind(like,like).all();
    return json({ok:true,rooms:rooms.results??[],users:users.results??[]});
  }

  if (url.pathname === "/api/roles/validate" && request.method === "POST") {
    const body = await bodyJson(request);
    return json({ ok: true, role: normalizeRole(body.role) });
  }

  if (url.pathname === "/api/session/google" && request.method === "POST") {
    if (!env.SESSION_SECRET) {
      return json({ ok: false, error: "session_secret_not_configured" }, { status: 503 });
    }
    const body = await bodyJson(request);
    const idToken = String(body.id_token ?? "").trim();
    if (!idToken) return json({ ok: false, error: "google_id_token_required" }, { status: 400 });

    let claims;
    try {
      claims = await verifyGoogleIdToken(idToken, env.GOOGLE_WEB_CLIENT_ID);
    } catch (error) {
      const code = String(error?.message ?? error);
      const status = code === "google_auth_not_configured" ? 503 : 401;
      return json({ ok: false, error: code }, { status });
    }

    const userId = "g_" + String(claims.sub);
    const displayName = String(
      claims.name ?? claims.given_name ?? claims.email ?? "DarkVibeX User"
    ).trim().slice(0, 60);
    const user = await ensureUser(db, userId, displayName);
    await ensureUserAllowed(db, userId);
    const token = await createSessionToken(env, userId, user.display_name);
    return json({ ok: true, token, user, provider: "google" });
  }

  if (url.pathname === "/api/session/guest" && request.method === "POST") {
    if (!env.SESSION_SECRET) {
      return json({ ok: false, error: "session_secret_not_configured" }, { status: 503 });
    }
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim() ||
      String(Math.floor(10000000 + Math.random() * 90000000));
    const displayName = String(body.display_name ?? "DarkVibeX User").trim().slice(0, 60);
    const user = await ensureUser(db, userId, displayName);
    await ensureUserAllowed(db, userId);
    const token = await createSessionToken(env, userId, user.display_name);
    return json({ ok: true, token, user, provider: "guest" });
  }

  if (url.pathname === "/api/users/upsert" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    const user = await ensureUser(db, userId, String(body.display_name ?? "").trim());
    await ensureUserAllowed(db, userId);
    return json({ ok: true, user });
  }

  if (parts[0] === "api" && parts[1] === "users" && parts.length === 3 && request.method === "GET") {
    const user = await db.prepare(
      "SELECT id, display_name, role, coins, diamonds, vip_level, avatar_key FROM users WHERE id = ?"
    ).bind(parts[2]).first();
    return user ? json({ ok: true, user }) : json({ ok: false, error: "not_found" }, { status: 404 });
  }

  if (url.pathname === "/api/rooms" && request.method === "GET") {
    return json({ ok: true, rooms: await listRooms(db) });
  }

  if (url.pathname === "/api/rooms" && request.method === "POST") {
    const roomCreation = await ownerSetting(db, "feature.room_creation", { enabled: true });
    if (roomCreation.enabled === false) return json({ ok: false, error: "room_creation_disabled" }, { status: 403 });
    const body = await bodyJson(request);
    const ownerId = String(body.owner_user_id ?? "").trim();
    const name = String(body.name ?? "").trim().slice(0, 80);
    const seatCount = Math.max(8, Math.min(42, Number(body.seat_count ?? 12)));
    if (!ownerId || !name) return json({ ok: false, error: "owner_and_name_required" }, { status: 400 });
    await ensureUser(db, ownerId, String(body.owner_name ?? "DarkVibeX User"));
    await ensureUserAllowed(db, ownerId);
    const roomId = String(body.id ?? "").trim() || String(Math.floor(100000 + Math.random() * 900000));
    const ts = now();
    await db.prepare(
      "INSERT INTO rooms (id, owner_user_id, name, seat_count, locked, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?)"
    ).bind(roomId, ownerId, name, seatCount, ts, ts).run();
    await db.prepare(
      "INSERT OR REPLACE INTO room_members (room_id, user_id, seat_index, mic_muted, joined_at, updated_at) VALUES (?, ?, NULL, 1, ?, ?)"
    ).bind(roomId, ownerId, ts, ts).run();
    return json({ ok: true, room_id: roomId }, { status: 201 });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "join" && request.method === "POST") {
    const roomId = parts[2];
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    await ensureUser(db, userId, String(body.display_name ?? "DarkVibeX User"));
    await ensureUserAllowed(db, userId);
    const ts = now();
    await db.prepare(
      "INSERT INTO room_members (room_id, user_id, seat_index, mic_muted, joined_at, updated_at) VALUES (?, ?, NULL, 1, ?, ?) ON CONFLICT(room_id,user_id) DO UPDATE SET updated_at = excluded.updated_at"
    ).bind(roomId, userId, ts, ts).run();
    return json({ ok: true });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "leave" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    await db.prepare(
      "UPDATE room_members SET seat_index = NULL, mic_muted = 1, updated_at = 0 WHERE room_id = ? AND user_id = ?"
    ).bind(parts[2], userId).run();
    return json({ ok: true });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "seat" && request.method === "POST") {
    const roomId = parts[2];
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    await ensureUserAllowed(db, userId);
    const seatIndex = body.seat_index == null ? null : Number(body.seat_index);
    const muted = body.mic_muted === false ? 0 : 1;
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    if (seatIndex != null) {
      const occupied = await db.prepare(
        "SELECT user_id FROM room_members WHERE room_id = ? AND seat_index = ? AND user_id <> ? LIMIT 1"
      ).bind(roomId, seatIndex, userId).first();
      if (occupied) return json({ ok: false, error: "seat_occupied" }, { status: 409 });
    }
    await db.prepare(
      "UPDATE room_members SET seat_index = ?, mic_muted = ?, updated_at = ? WHERE room_id = ? AND user_id = ?"
    ).bind(seatIndex, muted, now(), roomId, userId).run();
    return json({ ok: true, seat_index: seatIndex, mic_muted: Boolean(muted) });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "members" && request.method === "GET") {
    const viewerId=String(url.searchParams.get("viewer_id")??"").trim();
    if(viewerId){
      await db.prepare("UPDATE room_members SET updated_at=? WHERE room_id=? AND user_id=?").bind(now(),parts[2],viewerId).run();
    }
    const rows=await db.prepare(
      "SELECT m.user_id,m.seat_index,m.mic_muted,m.joined_at,u.display_name,u.avatar_key,u.vip_level FROM room_members m LEFT JOIN users u ON u.id=m.user_id WHERE m.room_id=? AND m.updated_at>? ORDER BY CASE WHEN m.seat_index IS NULL THEN 1 ELSE 0 END,m.seat_index ASC,m.joined_at ASC LIMIT 200"
    ).bind(parts[2],now()-60000).all();
    return json({ok:true,members:rows.results??[]});
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "messages") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const roomId = parts[2];
    if (request.method === "GET") {
      const rows = await db.prepare(
        `SELECT m.id, m.user_id, u.display_name, m.text, m.created_at
           FROM room_messages m
           LEFT JOIN users u ON u.id = m.user_id
          WHERE m.room_id = ?
          ORDER BY m.created_at DESC LIMIT 100`
      ).bind(roomId).all();
      return json({ ok: true, messages: (rows.results ?? []).reverse() });
    }
    if (request.method === "POST") {
      const body = await bodyJson(request);
      const userId = String(body.user_id ?? "").trim();
      await ensureUserAllowed(db, userId, { checkMute: true });
      const textValue = String(body.text ?? "").trim().slice(0, 500);
      if (!userId || !textValue) return json({ ok: false, error: "message_required" }, { status: 400 });
      const messageId = id();
      await db.prepare(
        "INSERT INTO room_messages (id, room_id, user_id, text, created_at) VALUES (?, ?, ?, ?, ?)"
      ).bind(messageId, roomId, userId, textValue, now()).run();
      return json({ ok: true, message_id: messageId }, { status: 201 });
    }
  }

  if (url.pathname === "/api/messages/send" && request.method === "POST") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const body = await bodyJson(request);
    const sender = String(body.sender_user_id ?? "").trim();
    const receiver = String(body.receiver_user_id ?? "").trim();
    const textValue = String(body.text ?? "").trim().slice(0, 1000);
    if (!sender || !receiver || !textValue) {
      return json({ ok: false, error: "invalid_message" }, { status: 400 });
    }
    await ensureUser(db, sender);
    await ensureUser(db, receiver);
    await ensureUserAllowed(db, sender, { checkMute: true });
    await ensureUserAllowed(db, receiver);
    const messageId = id();
    await db.prepare(
      "INSERT INTO direct_messages (id, sender_user_id, receiver_user_id, text, created_at, read_at) VALUES (?, ?, ?, ?, ?, NULL)"
    ).bind(messageId, sender, receiver, textValue, now()).run();
    return json({ ok: true, message_id: messageId }, { status: 201 });
  }

  if (url.pathname === "/api/messages/thread" && request.method === "GET") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const otherId = String(url.searchParams.get("other_user_id") ?? "").trim();
    if (!userId || !otherId) {
      return json({ ok: false, error: "user_ids_required" }, { status: 400 });
    }
    const rows = await db.prepare(
      `SELECT id, sender_user_id, receiver_user_id, text, created_at, read_at
         FROM direct_messages
        WHERE (sender_user_id = ? AND receiver_user_id = ?)
           OR (sender_user_id = ? AND receiver_user_id = ?)
        ORDER BY created_at ASC
        LIMIT 200`
    ).bind(userId, otherId, otherId, userId).all();
    await db.prepare(
      "UPDATE direct_messages SET read_at = ? WHERE receiver_user_id = ? AND sender_user_id = ? AND read_at IS NULL"
    ).bind(now(), userId, otherId).run();
    return json({ ok: true, messages: rows.results ?? [] });
  }

  if (url.pathname === "/api/messages/inbox" && request.method === "GET") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    if (!userId) {
      return json({ ok: false, error: "user_id_required" }, { status: 400 });
    }
    const rows = await db.prepare(
      `SELECT m.id, m.sender_user_id, m.receiver_user_id, m.text, m.created_at, m.read_at,
              s.display_name AS sender_name, r.display_name AS receiver_name
         FROM direct_messages m
         LEFT JOIN users s ON s.id = m.sender_user_id
         LEFT JOIN users r ON r.id = m.receiver_user_id
        WHERE m.sender_user_id = ? OR m.receiver_user_id = ?
        ORDER BY m.created_at DESC
        LIMIT 200`
    ).bind(userId, userId).all();

    const seen = new Set();
    const inbox = [];
    for (const row of rows.results ?? []) {
      const otherId = row.sender_user_id === userId ? row.receiver_user_id : row.sender_user_id;
      if (seen.has(otherId)) continue;
      seen.add(otherId);
      inbox.push({
        id: otherId,
        name: row.sender_user_id === userId ? row.receiver_name : row.sender_name,
        preview: row.text,
        created_at: row.created_at,
        unread: row.receiver_user_id === userId && row.read_at == null ? 1 : 0,
      });
    }
    return json({ ok: true, inbox });
  }

  if (parts[0] === "api" && parts[1] === "wallet" && parts.length === 3 && request.method === "GET") {
    const user = await ensureUser(db, parts[2]);
    const ledger = await db.prepare(
      "SELECT id, kind, amount, balance_after, reference_id, created_at FROM wallet_ledger WHERE user_id = ? ORDER BY created_at DESC LIMIT 100"
    ).bind(parts[2]).all();
    return json({ ok: true, wallet: user, ledger: ledger.results ?? [] });
  }

  if (url.pathname === "/api/gifts/send" && request.method === "POST") {
    const giftsFeature = await ownerSetting(db, "feature.gifts", { enabled: true });
    if (giftsFeature.enabled === false) return json({ ok: false, error: "gifts_disabled" }, { status: 403 });
    const body = await bodyJson(request);
    const sender = String(body.sender_user_id ?? "").trim();
    const receiver = String(body.receiver_user_id ?? "").trim();
    const giftId = String(body.gift_id ?? "").trim().slice(0, 80);
    if (!sender || !receiver || !giftId) return json({ok:false,error:"invalid_gift"},{status:400});
    await ensureUser(db,sender);await ensureUser(db,receiver);
    await ensureUserAllowed(db,sender);await ensureUserAllowed(db,receiver);
    const gift=await catalogItem(db,"gift",giftId);
    if (!gift) return json({ok:false,error:"gift_not_found"},{status:404});
    const unitCost=Number(gift.price_coins??0);
    const quantity=Math.max(1,Math.min(9999,Number(body.quantity??1)));
    const cost=unitCost*quantity;
    if (!Number.isSafeInteger(unitCost) || unitCost<=0 || !Number.isInteger(quantity) || !Number.isSafeInteger(cost)) {
      return json({ok:false,error:"invalid_gift_price"},{status:400});
    }
    const eventId=id();
    const beforeCp=giftId.startsWith("cp-")?await relationshipProgress(db,sender,receiver,"cp"):null;
    const beforeEnemy=giftId.startsWith("enemy-")?await relationshipProgress(db,sender,receiver,"enemy"):null;
    const balance=await walletChange(db,sender,-cost,"gift_sent",eventId);
    await db.batch([
      db.prepare("UPDATE users SET diamonds=diamonds+?,updated_at=? WHERE id=?").bind(cost,now(),receiver),
      db.prepare("INSERT INTO gift_events (id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,created_at) VALUES (?,?,?,?,?,?,?)").bind(eventId,body.room_id??null,sender,receiver,giftId,cost,now())
    ]);
    const relation=giftId.startsWith("cp-")?await relationshipProgress(db,sender,receiver,"cp"):
      giftId.startsWith("enemy-")?await relationshipProgress(db,sender,receiver,"enemy"):null;
    return json({ok:true,event_id:eventId,sender_coin_balance:balance,receiver_diamonds_added:cost,gift,quantity,unit_cost:unitCost,relation,
      level_before:beforeCp?.level??beforeEnemy?.level??null,level_after:relation?.level??null});
  }

  if (url.pathname === "/api/relationships" && request.method === "GET") {
    const relationshipFeature=await ownerSetting(db,"feature.relationships",{enabled:true});
    if(relationshipFeature.enabled===false)return json({ok:false,error:"relationships_disabled"},{status:403});
    const userA=String(url.searchParams.get("user_a")??"").trim();
    const userB=String(url.searchParams.get("user_b")??"").trim();
    if (!userA || !userB) return json({ok:false,error:"user_ids_required"},{status:400});
    return json({ok:true,cp:await relationshipProgress(db,userA,userB,"cp"),enemy:await relationshipProgress(db,userA,userB,"enemy")});
  }

  if (url.pathname === "/api/store/purchase" && request.method === "POST") {
    const storeFeature=await ownerSetting(db,"feature.store",{enabled:true});
    if(storeFeature.enabled===false)return json({ok:false,error:"store_disabled"},{status:403});
    await ensureParityTables(db);
    const body=await bodyJson(request);
    const userId=String(body.user_id??"").trim(),kind=String(body.kind??"").trim(),itemId=String(body.item_id??"").trim();
    if (!userId||!kind||!itemId) return json({ok:false,error:"purchase_fields_required"},{status:400});
    await ensureUser(db,userId);await ensureUserAllowed(db,userId);
    const item=await catalogItem(db,kind,itemId);
    if (!item) return json({ok:false,error:"item_not_found"},{status:404});
    const price=Number(item.price_coins??0);
    const purchaseId=id();
    const balance=price>0?await walletChange(db,userId,-price,"store_purchase",purchaseId):(await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first())?.coins??0;
    const days=Math.max(0,Number(item.data?.duration_days??7));
    const starts=now(),expires=days>0?starts+days*86400000:null;
    await db.prepare("INSERT INTO user_entitlements (id,user_id,kind,item_id,item_name,starts_at,expires_at,active,created_at) VALUES (?,?,?,?,?,?,?,1,?)")
      .bind(purchaseId,userId,kind,itemId,String(item.name??itemId),starts,expires,starts).run();
    if (kind==="vip") {
      const level=Math.max(0,Number(item.data?.level??0));
      if (level>0) await db.prepare("UPDATE users SET vip_level=MAX(vip_level,?),updated_at=? WHERE id=?").bind(level,now(),userId).run();
    }
    return json({ok:true,purchase_id:purchaseId,coin_balance:Number(balance),expires_at:expires});
  }

  if (url.pathname === "/api/store/entitlements" && request.method === "GET") {
    const storeFeature=await ownerSetting(db,"feature.store",{enabled:true});
    if(storeFeature.enabled===false)return json({ok:false,error:"store_disabled"},{status:403});
    await ensureParityTables(db);
    const userId=String(url.searchParams.get("user_id")??"").trim();
    const rows=await db.prepare("SELECT id,kind,item_id,item_name,starts_at,expires_at,active FROM user_entitlements WHERE user_id=? AND active=1 AND (expires_at IS NULL OR expires_at>?) ORDER BY created_at DESC LIMIT 200").bind(userId,now()).all();
    return json({ok:true,items:rows.results??[]});
  }

  if (url.pathname === "/api/family" && request.method === "GET") {
    const familyFeature=await ownerSetting(db,"feature.family",{enabled:true});
    if(familyFeature.enabled===false)return json({ok:false,error:"family_disabled"},{status:403});
    await ensureParityTables(db);
    const userId=String(url.searchParams.get("user_id")??"").trim();
    const family=await db.prepare("SELECT f.* FROM families f JOIN family_members m ON m.family_id=f.id WHERE m.user_id=? LIMIT 1").bind(userId).first();
    if (!family) return json({ok:true,family:null,members:[]});
    const members=await db.prepare("SELECT m.user_id,m.role,m.joined_at,u.display_name,u.vip_level FROM family_members m LEFT JOIN users u ON u.id=m.user_id WHERE m.family_id=? ORDER BY CASE m.role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END,m.joined_at ASC LIMIT 200").bind(family.id).all();
    return json({ok:true,family,members:members.results??[]});
  }

  if (url.pathname === "/api/family/create" && request.method === "POST") {
    const familyFeature=await ownerSetting(db,"feature.family",{enabled:true});
    if(familyFeature.enabled===false)return json({ok:false,error:"family_disabled"},{status:403});
    await ensureParityTables(db);
    const body=await bodyJson(request),userId=String(body.user_id??"").trim(),name=String(body.name??"").trim().slice(0,60);
    if(!userId||!name)return json({ok:false,error:"family_fields_required"},{status:400});
    await ensureUser(db,userId);await ensureUserAllowed(db,userId);
    const existing=await db.prepare("SELECT family_id FROM family_members WHERE user_id=? LIMIT 1").bind(userId).first();
    if(existing)return json({ok:false,error:"already_in_family"},{status:409});
    const familyId=String(Math.floor(100000+Math.random()*900000)),ts=now();
    await db.batch([
      db.prepare("INSERT INTO families (id,name,owner_user_id,level,experience,created_at,updated_at) VALUES (?,?,?,1,0,?,?)").bind(familyId,name,userId,ts,ts),
      db.prepare("INSERT INTO family_members (family_id,user_id,role,joined_at) VALUES (?,?,'owner',?)").bind(familyId,userId,ts)
    ]);
    return json({ok:true,family_id:familyId},{status:201});
  }

  if (url.pathname === "/api/family/join" && request.method === "POST") {
    const familyFeature=await ownerSetting(db,"feature.family",{enabled:true});
    if(familyFeature.enabled===false)return json({ok:false,error:"family_disabled"},{status:403});
    await ensureParityTables(db);
    const body=await bodyJson(request),userId=String(body.user_id??"").trim(),familyId=String(body.family_id??"").trim();
    if(!userId||!familyId)return json({ok:false,error:"family_fields_required"},{status:400});
    await ensureUser(db,userId);await ensureUserAllowed(db,userId);
    const family=await db.prepare("SELECT id FROM families WHERE id=?").bind(familyId).first();
    if(!family)return json({ok:false,error:"family_not_found"},{status:404});
    const existing=await db.prepare("SELECT family_id FROM family_members WHERE user_id=? LIMIT 1").bind(userId).first();
    if(existing)return json({ok:false,error:"already_in_family"},{status:409});
    await db.prepare("INSERT INTO family_members (family_id,user_id,role,joined_at) VALUES (?,?,'member',?)").bind(familyId,userId,now()).run();
    return json({ok:true});
  }

  if (url.pathname === "/api/family/signin" && request.method === "POST") {
    const familyFeature=await ownerSetting(db,"feature.family",{enabled:true});
    if(familyFeature.enabled===false)return json({ok:false,error:"family_disabled"},{status:403});
    await ensureParityTables(db);
    const body=await bodyJson(request),userId=String(body.user_id??"").trim();
    const member=await db.prepare("SELECT family_id FROM family_members WHERE user_id=? LIMIT 1").bind(userId).first();
    if(!member)return json({ok:false,error:"not_in_family"},{status:404});
    const dayKey=new Date().toISOString().slice(0,10),ts=now();
    try{
      await db.prepare("INSERT INTO family_signins (family_id,user_id,day_key,created_at) VALUES (?,?,?,?)").bind(member.family_id,userId,dayKey,ts).run();
      await db.prepare("UPDATE families SET experience=experience+100,level=1+CAST((experience+100)/5000 AS INTEGER),updated_at=? WHERE id=?").bind(ts,member.family_id).run();
      return json({ok:true,experience_added:100});
    }catch(error){
      if(String(error?.message??error).toLowerCase().includes("unique"))return json({ok:true,already_signed_in:true,experience_added:0});
      throw error;
    }
  }

  if (url.pathname === "/api/games/fruit-party/state" && request.method === "GET") {
    const gamesFeature=await ownerSetting(db,"feature.games",{enabled:true});
    if(gamesFeature.enabled===false)return json({ok:false,error:"games_disabled"},{status:403});
    const userId=String(url.searchParams.get("user_id")??"").trim();
    if(!userId)return json({ok:false,error:"user_id_required"},{status:400});
    return json(await fruitState(db,userId));
  }

  if (url.pathname === "/api/games/fruit-party/bet" && request.method === "POST") {
    const gamesFeature=await ownerSetting(db,"feature.games",{enabled:true});
    if(gamesFeature.enabled===false)return json({ok:false,error:"games_disabled"},{status:403});
    const body=await bodyJson(request),userId=String(body.user_id??"").trim(),fruit=String(body.fruit??"").trim(),stake=Number(body.stake??0);
    if(!userId||!FRUITS[fruit]||!FRUIT_STAKES.has(stake))return json({ok:false,error:"invalid_bet"},{status:400});
    await ensureUser(db,userId);await ensureUserAllowed(db,userId);await settleFruitBets(db,userId);
    const round=fruitRound();
    if(round.phase!=="betting")return json({ok:false,error:"betting_closed",round},{status:409});
    const betId=id();
    const balance=await walletChange(db,userId,-stake,"game_bet",betId);
    await db.prepare("INSERT INTO game_bets (id,game_id,user_id,stake,result,payout,created_at) VALUES (?,'fruit-party',?,?,?,0,?)")
      .bind(betId,userId,stake,"pending|"+round.round_id+"|"+fruit,now()).run();
    return json({ok:true,bet_id:betId,coin_balance:balance,round_id:round.round_id,fruit});
  }

  if (url.pathname === "/api/files" && request.method === "PUT") {
    if (!env.FILES) return json({ ok: false, error: "files_not_bound" }, { status: 503 });
    const rawKey = String(request.headers.get("x-file-key") ?? "").trim();
    const key = rawKey.replace(/[^a-zA-Z0-9._/-]/g, "").replace(/^\/+/, "");
    if (!key || key.includes("..")) return json({ ok: false, error: "invalid_file_key" }, { status: 400 });
    await env.FILES.put(key, request.body, {
      httpMetadata: { contentType: request.headers.get("content-type") ?? "application/octet-stream" },
    });
    return json({ ok: true, key }, { status: 201 });
  }

  return json({ ok: false, error: "not_found" }, { status: 404 });
}

async function handleLiveKitToken(request, env) {
  if (request.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }
  if (!env.SESSION_SECRET || !env.LIVEKIT_URL || !env.LIVEKIT_API_KEY || !env.LIVEKIT_API_SECRET) {
    return json({ ok: false, error: "voice_not_configured" }, { status: 503 });
  }

  const session = await verifySessionToken(
    bearerToken(request),
    String(env.SESSION_SECRET),
  );
  const db = requireDb(env);
  const voiceFeature = await ownerSetting(db, "feature.voice", { enabled: true });
  if (voiceFeature.enabled === false) {
    return json({ ok: false, error: "voice_disabled" }, { status: 403 });
  }
  await ensureUserAllowed(db, String(session.sub));
  const body = await bodyJson(request);
  const roomId = String(body.room_id ?? "").trim().slice(0, 100);
  if (!roomId) {
    return json({ ok: false, error: "room_id_required" }, { status: 400 });
  }

  const seconds = Math.floor(Date.now() / 1000);
  const token = await signJwt(
    String(env.LIVEKIT_API_SECRET),
    { alg: "HS256", typ: "JWT" },
    {
      iss: String(env.LIVEKIT_API_KEY),
      sub: String(session.sub),
      name: String(session.name ?? session.sub),
      nbf: seconds - 5,
      exp: seconds + 60 * 60,
      video: {
        room: roomId,
        roomJoin: true,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
      },
    },
  );

  return json({
    ok: true,
    server_url: String(env.LIVEKIT_URL),
    token,
  });
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({
        ok: true,
        service: "darkvibex-api",
        db_bound: Boolean(env.DB),
        files_bound: Boolean(env.FILES),
      });
    }

    try {
      if (url.pathname === "/livekit/token") {
        return await handleLiveKitToken(request, env);
      }
      if (url.pathname.startsWith("/api/owner/")) {
        return await handleOwnerApi(request, env, url);
      }
      if (url.pathname.startsWith("/api/")) {
        return await handleApi(request, env, url);
      }
      if (env.ASSETS) return env.ASSETS.fetch(request);
      return json({ ok: false, error: "not_found" }, { status: 404 });
    } catch (error) {
      const message = String(error?.message ?? error);
      const status = message === "database_not_bound" ? 503 : 400;
      return json({ ok: false, error: message }, { status });
    }
  },
};

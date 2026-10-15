const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
const state = {
  token: sessionStorage.getItem("dvxOwnerToken") || "",
  actor: null,
  view: "overview",
  selectedUser: null,
  settings: new Map(),
  catalog: [],
  selectedTicket: null,
  treasury: null,
  economyUser: null,
  storeItems: [],
  messageSelected: new Map(),
  selectedRoomId: null,
  rolesPosts: [],
  banners: [],
  games: [],
  policies: [],
  globalThemes: [],
  vipRules: [],
  giftItems: [],
  assetItems: [],
  pricingOverrides: [],
  auditRows: [],
};
const viewTitles = {overview:"Dashboard",users:"Users",notifications:"Notifications",messaging:"Messages & Tags",rooms:"Rooms",roles:"Roles / Posts",banners:"Banners",games:"Games",policies:"Policies",wallets:"Wallets / Treasury",economy:"Unique ID / Coin Rate",vip:"VIP Manager",gifts:"Gifts",assets:"Entries / Frames",store:"App Store",catalog:"Advanced Catalog",settings:"Master Switches",announcements:"Announcements",staff:"Custom Panels",support:"VIP Support",audit:"Audit Log"};
const featureLabels = {"feature.voice":"Voice rooms","feature.gifts":"Gifts","feature.games":"Games","feature.messages":"Messages","feature.room_creation":"Room creation","feature.aladdin_lamp":"Aladdin's Lamp","feature.red_pocket":"Red Pocket / LP","feature.friends_call":"Friends call","feature.visitors":"Profile visitors"};
const staffPermissionOptions = [
  ["dashboard","Dashboard"],["users.read","Users: view/search"],["users.write","Users: edit profile/VIP/role"],["users.moderate","Users: ban/suspend/moderate"],["wallet.write","User wallets"],
  ["treasury.read","Owner Treasury: view"],["treasury.write","Owner Treasury: distribute"],["economy.read","Economy: view coin rate / ID tools"],["economy.write","Economy: change coin rate"],
  ["messaging.read","Messages/Tags: view"],["messaging.write","Official messages: send"],["tags.write","Tags/V Official: manage"],
  ["users.device","Users: device ban"],["users.override","Users: invisible/bypass/freeze"],["wallet.freeze","Wallet security freeze"],
  ["rooms.read","Rooms: view"],["rooms.write","Rooms: edit/remove"],["rooms.live","Rooms: live users/seats"],["rooms.media","Rooms: DP/background"],["rooms.theme","Rooms: theme override"],
  ["roles.read","Roles/Posts: view"],["roles.write","Roles/Posts: manage"],["banners.read","Banners: view"],["banners.write","Banners: manage"],
  ["games.read","Games: view/stats"],["games.write","Games: manage"],["policies.read","Policies: view"],["policies.write","Policies: manage"],
  ["catalog.read","VIP/Gifts/Assets: view"],["catalog.write","VIP/Gifts/Assets: edit"],["settings.read","Master switches: view"],["settings.write","Master switches: edit"],
  ["announcements.read","Announcements: view"],["announcements.write","Announcements: publish"],["support.read","VIP support: view"],["support.write","VIP support: reply/close"],
  ["staff.read","Custom panels: view"],["staff.write","Custom panels: manage"],["audit.read","Audit log"]
];

function authHeaders(){return {authorization:"Bearer "+state.token,"content-type":"application/json"};}
async function api(path, options={}){
  const res=await fetch(path,{...options,headers:{...authHeaders(),...(options.headers||{})}});
  const data=await res.json().catch(()=>({ok:false,error:"invalid_response"}));
  if(!res.ok) throw new Error(data.error||("HTTP "+res.status));
  return data;
}
function esc(v){return String(v??"").replace(/[&<>'"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;","\"":"&quot;"}[c]));}
function num(v){return Number(v||0).toLocaleString();}
function time(v){if(!v)return "—";return new Date(Number(v)).toLocaleString();}
function duration(v){const ms=Math.max(0,Number(v||0));const total=Math.floor(ms/1000);const h=Math.floor(total/3600);const m=Math.floor((total%3600)/60);const sec=total%60;return h>0?`${h}h ${m}m`:m>0?`${m}m ${sec}s`:`${sec}s`;}
function can(p){return (!!state.actor&&(state.actor.permissions||[]).includes("*"))||(state.actor?.permissions||[]).includes(p);}
function empty(text){return `<div class="empty">${esc(text)}</div>`;}
function toast(message,good=true){const el=$("#toast");el.textContent=message;el.className="toast "+(good?"good":"bad");el.hidden=false;clearTimeout(toast.t);toast.t=setTimeout(()=>el.hidden=true,2600);}
function showApp(on){$("#loginCard").hidden=on;$("#workspace").hidden=!on;$("#sidebar").hidden=!on;}
function actorCard(){if(!state.actor)return;$("#actorCard").innerHTML=`<b>${esc(state.actor.name||"Authorized user")}</b><span>${esc(state.actor.role||"")}</span>`;}
function applyPermissions(){
  const map={overview:"dashboard",users:"users.read",notifications:"notifications.read",messaging:"messaging.read",rooms:"rooms.read",roles:"roles.read",banners:"banners.read",games:"games.read",policies:"policies.read",wallets:"treasury.read",economy:"economy.read",vip:"catalog.read",gifts:"catalog.read",assets:"catalog.read",store:"catalog.read",catalog:"catalog.read",settings:"settings.read",announcements:"announcements.read",staff:"staff.read",support:"support.read",audit:"audit.read"};
  $$(".nav-btn").forEach(btn=>{const p=map[btn.dataset.view];btn.hidden=(btn.dataset.view==="notifications"&&state.actor?.type!=="owner")||(!!p&&!can(p));});
}
function setView(name){state.view=name;$("#viewTitle").textContent=viewTitles[name]||name;$$('.nav-btn').forEach(b=>b.classList.toggle('active',b.dataset.view===name));$$('.view').forEach(v=>v.classList.toggle('active',v.dataset.viewPanel===name));loadView(name).catch(e=>toast(e.message,false));}
async function loadView(name){if(name==="overview")return loadOverview();if(name==="users")return loadUsers();if(name==="notifications")return loadNotifications();if(name==="messaging")return loadMessaging();if(name==="rooms")return loadRooms();if(name==="roles")return loadRolesPosts();if(name==="banners")return loadBanners();if(name==="games")return loadGames();if(name==="policies")return loadPolicies();if(name==="wallets")return loadWallets();if(name==="economy")return loadEconomy();if(name==="vip")return loadVipRules();if(name==="gifts")return loadGifts();if(name==="assets")return loadAssets();if(name==="store")return loadStore();if(name==="catalog")return loadCatalog();if(name==="settings")return loadSettings();if(name==="announcements")return loadAnnouncements();if(name==="staff")return loadStaff();if(name==="support")return loadSupport();if(name==="audit")return loadAudit();}

async function connect(){
  state.token=$("#token").value.trim()||state.token;if(!state.token)return;
  $("#loginStatus").textContent="Checking protected access…";
  try{
    const session=await api("/api/owner/session");state.actor=session.actor;sessionStorage.setItem("dvxOwnerToken",state.token);showApp(true);actorCard();applyPermissions();$("#loginStatus").textContent="";const first=$$(".nav-btn").find(b=>!b.hidden);if(!first)throw new Error("no_panel_permissions");setView(first.dataset.view);
  }catch(e){state.token="";state.actor=null;sessionStorage.removeItem("dvxOwnerToken");showApp(false);$("#loginStatus").textContent=e.message;}
}

async function loadOverview(){
  const d=await api("/api/owner/overview");state.actor=d.actor||state.actor;actorCard();
  const labels=[["Users",d.stats.users],["Rooms",d.stats.rooms],["Online",d.stats.online],["Owner Treasury",d.stats.treasury],["Coins",d.stats.coins],["Diamonds",d.stats.diamonds],["Banned",d.stats.banned],["Gift events",d.stats.gifts],["Game bets",d.stats.bets]];
  $("#stats").innerHTML=labels.map(([k,v])=>`<article class="stat-card"><span>${esc(k)}</span><strong>${num(v)}</strong></article>`).join("");
  $("#overviewRooms").innerHTML=(d.rooms||[]).length?(d.rooms||[]).slice(0,10).map(room=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(room.name)}</div><div class="item-meta">ID ${esc(room.id)} · ${num(room.online)} online · ${num(room.seat_count)} seats · ${esc(room.owner_name||room.owner_user_id)}</div></div><span class="pill ${Number(room.locked)?'banned':'active'}">${Number(room.locked)?'Locked':'Open'}</span></div></div>`).join(""):empty("No rooms yet");
  $("#overviewAudit").innerHTML=(d.audit||[]).length?(d.audit||[]).map(a=>`<div class="item-card"><div class="item-title">${esc(a.action.replaceAll('_',' '))}</div><div class="item-meta">${esc(a.target_type)} ${esc(a.target_id)} · ${esc(a.summary||'')}<br>${time(a.created_at)}</div></div>`).join(""):empty("No owner activity yet");
}

async function loadUsers(){if(!can("users.read"))return;const q=$("#userSearch").value.trim();const d=await api("/api/owner/users?q="+encodeURIComponent(q));$("#userList").innerHTML=(d.users||[]).length?d.users.map(u=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(u.display_name||'Unnamed user')} <span class="pill ${u.status==='banned'?'banned':'active'}">${esc(u.status)}</span></div><div class="item-meta">Public ID ${esc(u.public_id||'—')} · Internal ${esc(u.id)} · ${esc(u.role)} · VIP ${num(u.vip_level)}<br>${num(u.coins)} coins · ${num(u.diamonds)} diamonds</div></div><div class="item-actions"><button class="secondary mini" data-user-open="${esc(u.id)}">Manage</button></div></div></div>`).join(""):empty("No matching users");$$('[data-user-open]').forEach(b=>b.onclick=()=>openUser(b.dataset.userOpen));}
async function openUser(id){
  const d=await api("/api/owner/users/"+encodeURIComponent(id));
  const u=d.user;
  state.selectedUser=u;
  $("#userEditor").hidden=false;
  $("#userEditorTitle").textContent=u.display_name||"Manage user";
  $("#userMeta").textContent=`ID ${u.id} · Updated ${time(u.updated_at)}`;
  $("#editUserName").value=u.display_name||"";
  $("#editUserRole").value=u.role||"user";
  $("#editVip").value=u.vip_level||0;
  $("#editStatus").value=u.status||"active";
  $("#editNote").value=u.moderation_note||"";
  $("#walletBalance").textContent=`Current balance: ${num(u.coins)} coins · ${num(u.diamonds)} diamonds`;
  const inv=u.investigation||{};
  const invCards=[
    ["Room",inv.room_id?(String(inv.room_id)+(inv.room_name?" · "+String(inv.room_name):"")):"Offline"],
    ["Current room time",inv.room_id?duration(inv.online_duration_ms):"—"],
    ["Sent gifts",num(inv.sent_gift_coins||0)+" coins · "+num(inv.sent_gift_count||0)+" gifts"],
    ["Received gifts",num(inv.received_gift_coins||0)+" coins · "+num(inv.received_gift_count||0)+" gifts"],
    ["Purchases",num(inv.purchase_coins||0)+" coins · "+num(inv.purchase_count||0)+" records"],
    ["Wallet dollar value","$"+Number(inv.wallet_usd||0).toFixed(2)+" @ "+num(inv.coin_rate_coins_per_usd||5000000)+" coins/$"],
    ["Game bets",num(inv.game_wagered||0)+" wagered · "+num(inv.game_bet_count||0)+" bets"],
    ["Game payout",num(inv.game_payout||0)+" · house result "+num(inv.game_house_result||0)],
    ["Diamonds",num(inv.diamonds||u.diamonds||0)],
  ];
  $("#userInvestigation").innerHTML=invCards.map(([label,value])=>`<div class="module-card"><b>${esc(label)}</b><span>${esc(value)}</span></div>`).join("");
  const recentGames=(inv.recent_games||[]).map(x=>`<div class="item-card"><div class="item-title">Game · ${esc(x.game_id)}</div><div class="item-meta">Stake ${num(x.stake)} · payout ${num(x.payout)} · ${esc(x.result)} · ${time(x.created_at)}</div></div>`);
  const recentGifts=(inv.recent_gifts||[]).map(x=>`<div class="item-card"><div class="item-title">Gift · ${esc(x.direction)} · ${esc(x.gift_id)}</div><div class="item-meta">${num(x.coin_cost)} coins · ${time(x.created_at)}</div></div>`);
  $("#userInvestigationActivity").innerHTML=[...recentGames,...recentGifts].slice(0,16).join("")||empty("No recent game/gift activity");
  renderLedger(u.wallet_ledger||[]);
  const roleType=(u.role==="coin_seller"||u.role==="merchant")?u.role:"";
  $("#roleWalletType").value=roleType;
  const rw=roleType?u.role_wallets?.[roleType]:null;
  $("#roleWalletBalance").textContent=rw?`${roleType.replaceAll("_"," ")} balance: ${num(rw.balance_coins)} coins · ${rw.banned?"BANNED":"Active"}`:"Select Coin Seller or Merchant wallet to manage a dedicated role balance.";
  $("#roleWalletBanned").checked=Boolean(rw?.banned);
  $("#roleCoinDelta").value="";
  $("#editPublicId").value=u.public_id||"";
  $("#oldPublicIds").innerHTML=(u.old_public_ids||[]).length?(u.old_public_ids||[]).map(x=>`<div class="item-card"><div class="item-meta"><b>${esc(x.public_id)}</b> · ${time(x.changed_at)}</div></div>`).join(""):empty("No previous public IDs");

  const o=u.owner_overrides||{};
  $("#userInvisibleId").checked=Number(o.invisible_id||0)===1;
  $("#userLockedBypass").checked=Number(o.locked_room_bypass||0)===1;
  $("#userWalletBanned").checked=Number(o.wallet_banned||0)===1;
  $("#userWalletFrozen").checked=Number(o.wallet_frozen||0)===1;

  const devices=u.devices||[];
  $("#userDevices").innerHTML=devices.length?devices.map(device=>{
    const key=String(device.device_key||device.token||"");
    const banned=Number(device.banned||0)===1;
    const label=key.length>42?key.slice(0,20)+"…"+key.slice(-12):key;
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(device.platform||"device")} <span class="pill ${banned?"banned":"active"}">${banned?"Banned":"Allowed"}</span></div><div class="item-meta">${esc(label)} · ${time(device.updated_at)}${device.ban_note?" · "+esc(device.ban_note):""}</div></div><button class="${banned?"secondary":"danger"} mini" data-device-key="${esc(key)}" data-device-banned="${banned?1:0}">${banned?"Unban":"Ban"}</button></div></div>`;
  }).join(""):empty("No registered device yet");
  $$("[data-device-key]").forEach(b=>b.onclick=()=>toggleDeviceBan(b.dataset.deviceKey,Number(b.dataset.deviceBanned)===1).catch(e=>toast(e.message,false)));
  $("#userEditor").scrollIntoView({behavior:"smooth",block:"start"});
}
function renderLedger(rows){$("#walletLedger").innerHTML=rows.length?`<div class="small-table">${rows.map(r=>`<div class="ledger-row"><span>${time(r.created_at)}</span><span>${esc(r.kind.replaceAll('_',' '))}</span><b>${Number(r.amount)>0?'+':''}${num(r.amount)} → ${num(r.balance_after)}</b></div>`).join("")}</div>`:empty("No coin ledger entries");}
async function saveUserProfile(){if(!state.selectedUser)return;await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/profile`,{method:"POST",body:JSON.stringify({display_name:$("#editUserName").value,role:$("#editUserRole").value,vip_level:Number($("#editVip").value||0)})});toast("User profile saved");await openUser(state.selectedUser.id);await loadUsers();}
async function saveModeration(){if(!state.selectedUser)return;await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/moderation`,{method:"POST",body:JSON.stringify({status:$("#editStatus").value,note:$("#editNote").value})});toast("Moderation status saved");await openUser(state.selectedUser.id);await loadUsers();}
async function savePublicId(){if(!state.selectedUser)return;const publicId=$("#editPublicId").value.trim();if(!/^\d{7}$/.test(publicId)||Number(publicId)<1000001)return toast("Public ID must be between 1000001 and 9999999",false);await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/public-id`,{method:"POST",body:JSON.stringify({public_id:publicId})});toast("Public ID changed");await openUser(state.selectedUser.id);await loadUsers();}
async function applyWallet(){if(!state.selectedUser)return;const coin=Number($("#coinDelta").value||0),diamond=Number($("#diamondDelta").value||0);if(!coin&&!diamond)return toast("Enter a coin or diamond change",false);await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/wallet`,{method:"POST",body:JSON.stringify({coin_delta:coin,diamond_delta:diamond})});$("#coinDelta").value="";$("#diamondDelta").value="";toast("Wallet adjustment applied");await openUser(state.selectedUser.id);await loadUsers();}
async function applyRoleWallet(){if(!state.selectedUser)return;const walletType=$("#roleWalletType").value;const delta=Number($("#roleCoinDelta").value||0);if(!walletType)return toast("Select Coin Seller or Merchant wallet",false);await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/wallet`,{method:"POST",body:JSON.stringify({role_wallet_type:walletType,role_coin_delta:delta,role_wallet_banned:$("#roleWalletBanned").checked})});toast("Role wallet balance/status updated");await openUser(state.selectedUser.id);await loadUsers();}

async function loadRooms(){
  if(!can("rooms.read"))return;
  const q=$("#roomSearch").value.trim();
  const d=await api("/api/owner/rooms?q="+encodeURIComponent(q));
  $("#roomList").innerHTML=(d.rooms||[]).length?d.rooms.map(r=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(r.name)} <span class="pill ${Number(r.banned)?"banned":(Number(r.locked)?"banned":"active")}">${Number(r.banned)?"BANNED":(Number(r.locked)?"Locked":"Open")}</span></div><div class="item-meta">ID ${esc(r.id)} · Owner ${esc(r.owner_name||r.owner_user_id)} · ${num(r.online)} online · ${num(r.seat_count)} seats</div></div><div class="item-actions"><button class="secondary mini" data-room-live="${esc(r.id)}">Investigate</button><button class="${Number(r.banned)?"secondary":"danger"} mini" data-room-ban="${esc(r.id)}" data-banned="${Number(r.banned)}">${Number(r.banned)?"Unban":"Ban"}</button><button class="secondary mini" data-room-lock="${esc(r.id)}" data-locked="${Number(r.locked)}">${Number(r.locked)?"Unlock":"Lock"}</button><button class="secondary mini" data-room-edit="${esc(r.id)}" data-name="${esc(r.name)}" data-seats="${num(r.seat_count)}">Edit</button><button class="danger mini" data-room-delete="${esc(r.id)}">Remove</button></div></div></div>`).join(""):empty("No matching rooms");
  $$("[data-room-live]").forEach(b=>b.onclick=()=>openRoomInvestigation(b.dataset.roomLive).catch(e=>toast(e.message,false)));
  $$("[data-room-ban]").forEach(b=>b.onclick=async()=>{const isBanned=Number(b.dataset.banned)===1;if(!isBanned&&!confirm("Ban this room and remove all current members?"))return;await api("/api/owner/rooms/"+encodeURIComponent(b.dataset.roomBan)+"/ban",{method:"POST",body:JSON.stringify({banned:!isBanned})});toast(isBanned?"Room unbanned":"Room banned");await loadRooms();});
  $$("[data-room-lock]").forEach(b=>b.onclick=async()=>{await api("/api/owner/rooms/"+encodeURIComponent(b.dataset.roomLock),{method:"POST",body:JSON.stringify({locked:!Number(b.dataset.locked)})});toast("Room lock updated");loadRooms();});
  $$("[data-room-edit]").forEach(b=>b.onclick=async()=>{const name=prompt("Room name",b.dataset.name);if(name===null)return;const seats=prompt("Seat count (8–42)",b.dataset.seats);if(seats===null)return;await api("/api/owner/rooms/"+encodeURIComponent(b.dataset.roomEdit),{method:"POST",body:JSON.stringify({name,seat_count:Number(seats)})});toast("Room updated");loadRooms();});
  $$("[data-room-delete]").forEach(b=>b.onclick=async()=>{if(!confirm("Remove this room? This deletes the room and its current room records."))return;await api("/api/owner/rooms/"+encodeURIComponent(b.dataset.roomDelete),{method:"DELETE"});toast("Room removed");loadRooms();});
}
async function openRoomInvestigation(roomId){
  if(!can("rooms.live"))return toast("Room live permission required",false);
  const d=await api("/api/owner/rooms/"+encodeURIComponent(roomId)+"/live");
  state.selectedRoomId=roomId;
  const room=d.room||{};
  $("#roomInvestigation").hidden=false;
  $("#roomInvestigationTitle").textContent=room.name||("Room "+roomId);
  $("#roomInvestigationMeta").textContent=`Room ID ${roomId} · Owner ${room.owner_name||room.owner_user_id||"—"} · ${Number(room.locked)?"Locked":"Open"}${room.lock_code?" · Lock code "+room.lock_code:""}`;
  $("#ownerRoomDpKey").value=room.image_key||"";
  $("#ownerRoomBackgroundKey").value=room.background_key||"";
  $("#ownerRoomThemeId").value=room.theme_id||"dark";
  const members=d.members||[];
  $("#roomLiveMembers").innerHTML=members.length?members.map(m=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(m.display_name||"User")} · ID ${esc(m.public_id||m.user_id)}</div><div class="item-meta">${m.seat_index==null?"Off-seat":"Seat "+(Number(m.seat_index)+1)} · Mic ${Number(m.mic_muted)?"muted":"open"} · VIP ${num(m.vip_level||0)} · joined ${time(m.joined_at)}</div></div></div></div>`).join(""):empty("No users in room");
  $("#roomInvestigation").scrollIntoView({behavior:"smooth",block:"start"});
}
async function saveOwnerRoomMedia(){
  if(!state.selectedRoomId)return toast("Open a room first",false);
  await api("/api/owner/rooms/"+encodeURIComponent(state.selectedRoomId)+"/media",{method:"POST",body:JSON.stringify({image_key:$("#ownerRoomDpKey").value.trim(),background_key:$("#ownerRoomBackgroundKey").value.trim()})});
  toast("Room DP / background updated");
  await openRoomInvestigation(state.selectedRoomId);
}
async function saveOwnerRoomTheme(){
  if(!state.selectedRoomId)return toast("Open a room first",false);
  await api("/api/owner/rooms/"+encodeURIComponent(state.selectedRoomId)+"/theme",{method:"POST",body:JSON.stringify({theme_id:$("#ownerRoomThemeId").value.trim()||"dark"})});
  toast("Room theme updated");
  await openRoomInvestigation(state.selectedRoomId);
}

async function loadWallets(){
  if(!can("treasury.read"))return;
  const d=await api("/api/owner/treasury");
  state.treasury=d.treasury||{balance:0};
  $("#treasuryBalance").textContent=num(state.treasury.balance||0);
  const rows=d.ledger||[];
  $("#treasuryLedger").innerHTML=rows.length?rows.map(r=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(r.kind.replaceAll('_',' '))}</div><div class="item-meta">${time(r.created_at)} · actor ${esc(r.actor_id||'owner')}${r.target_user_id?' · target '+esc(r.target_user_id):''}${r.note?' · '+esc(r.note):''}</div></div><b>${Number(r.amount)>0?'+':''}${num(r.amount)} → ${num(r.balance_after)}</b></div></div>`).join(""):empty("No treasury activity yet");
  const ownerOnly=state.actor?.role==="owner";
  $("#treasuryAdd").hidden=!ownerOnly;
  $("#treasuryDeduct").hidden=!ownerOnly;
  $("#treasurySend").disabled=!can("treasury.write");
}
async function treasuryAction(action){
  if(!can("treasury.write"))return toast("Treasury write permission required",false);
  const amount=Number($("#treasuryAmount").value||0);
  if(!Number.isFinite(amount)||amount<=0)return toast("Enter a valid amount",false);
  const payload={action,amount,user_id:$("#treasuryUserId").value.trim(),note:$("#treasuryNote").value.trim()};
  if(action==="send"&&!payload.user_id)return toast("Target user ID is required",false);
  await api("/api/owner/treasury",{method:"POST",body:JSON.stringify(payload)});
  $("#treasuryAmount").value="";
  if(action!=="send")$("#treasuryUserId").value="";
  toast(action==="send"?"Treasury coins sent":"Treasury updated");
  await loadWallets();
  await loadOverview();
}


async function loadEconomy(){
  if(!can("economy.read"))return;
  const d=await api("/api/owner/economy");
  const rate=Number(d.coins_per_usd||5000000);
  $("#coinRateCoinsPerUsd").value=String(rate);
  renderCoinRate(rate,d.updated_at);
  $("#saveCoinRate").disabled=!can("economy.write");
  if(!can("users.read")){
    $("#economyUserSearch").disabled=true;
    $("#searchEconomyUsers").disabled=true;
    $("#economyUserResults").innerHTML=empty("Users read permission is required for Unique ID lookup.");
  }
}
function renderCoinRate(rate,updatedAt){
  const perMillion=rate>0?(1000000/rate):0;
  $("#coinRateSummary").textContent=`Current rate: $1 = ${num(rate)} coins · 1,000,000 coins ≈ $${perMillion.toFixed(4)}${updatedAt?" · Updated "+time(updatedAt):""}`;
}
async function searchEconomyUsers(){
  if(!can("users.read"))return toast("Users read permission required",false);
  const q=$("#economyUserSearch").value.trim();
  if(!q)return toast("Enter a user name or ID",false);
  const d=await api("/api/owner/users?q="+encodeURIComponent(q)+"&limit=30");
  const rows=d.users||[];
  $("#economyUserResults").innerHTML=rows.length?rows.map(u=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(u.display_name||"Unnamed user")}</div><div class="item-meta">Public ID ${esc(u.public_id||"—")} · Internal ${esc(u.id)} · ${esc(u.role)}</div></div><button class="secondary mini" data-economy-user="${esc(u.id)}">Select</button></div></div>`).join(""):empty("No matching users");
  $$("[data-economy-user]").forEach(b=>b.onclick=()=>selectEconomyUser(b.dataset.economyUser).catch(e=>toast(e.message,false)));
}
async function selectEconomyUser(id){
  const d=await api("/api/owner/users/"+encodeURIComponent(id));
  state.economyUser=d.user;
  $("#economySelectedUser").hidden=false;
  $("#economySelectedUserName").textContent=d.user.display_name||"Selected user";
  const old=(d.user.old_public_ids||[]).map(x=>x.public_id).join(", ");
  $("#economySelectedUserMeta").textContent=`Internal ID ${d.user.id} · Current public ID ${d.user.public_id||"—"}${old?" · Old IDs: "+old:""}`;
  $("#economyPublicId").value=d.user.public_id||"";
  $("#saveEconomyPublicId").disabled=!can("users.write");
}
async function saveEconomyPublicId(){
  if(!state.economyUser)return toast("Select a user first",false);
  if(!can("users.write"))return toast("Users write permission required",false);
  const publicId=$("#economyPublicId").value.trim();
  if(!/^\d{7}$/.test(publicId)||Number(publicId)<1000001)return toast("Unique ID must be between 1000001 and 9999999",false);
  await api(`/api/owner/users/${encodeURIComponent(state.economyUser.id)}/public-id`,{method:"POST",body:JSON.stringify({public_id:publicId})});
  toast("Unique ID changed");
  await selectEconomyUser(state.economyUser.id);
  await searchEconomyUsers();
}
async function saveCoinRate(){
  if(!can("economy.write"))return toast("Economy write permission required",false);
  const rate=Number($("#coinRateCoinsPerUsd").value);
  if(!Number.isSafeInteger(rate)||rate<1)return toast("Enter a valid whole-number coin rate",false);
  const d=await api("/api/owner/economy",{method:"POST",body:JSON.stringify({coins_per_usd:rate})});
  renderCoinRate(Number(d.coins_per_usd),d.updated_at);
  toast("Coin price updated");
}


function clearStoreForm(){
  $("#storeId").value="";
  $("#storeName").value="";
  $("#storePrice").value=0;
  $("#storeVip").value=0;
  $("#storeDuration").value=$("#storeKind").value==="unique_id"?0:30;
  $("#storeTier").value=0;
  $("#storeOrder").value=0;
  $("#storeAsset").value="";
  $("#storeEmoji").value="";
  $("#storeCategory").value="";
  $("#storeDescription").value="";
  $("#storeEnabled").checked=true;
}
async function loadStore(){
  if(!can("catalog.read"))return;
  const kind=$("#storeKind").value.trim();
  if(!kind)return;
  const d=await api("/api/owner/store?kind="+encodeURIComponent(kind));
  state.storeItems=d.items||[];
  $("#storeList").innerHTML=state.storeItems.length?state.storeItems.map(item=>{
    const data=item.data||{};
    const enabled=Number(item.enabled)!==0;
    const meta=[
      `ID ${esc(item.id)}`,
      `${num(item.price_coins)} coins`,
      `VIP ${num(data.min_vip_level??data.vip_level??0)}`,
      `${num(data.duration_days??0)} days`,
      esc(item.source||"custom"),
    ].join(" · ");
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name||item.id)} <span class="pill ${enabled?'active':'banned'}">${enabled?'Enabled':'Removed'}</span></div><div class="item-meta">${meta}<br>${esc(data.description||data.asset_key||data.asset||data.emoji||'')}</div></div><div class="item-actions"><button class="secondary mini" data-store-edit="${esc(item.id)}">Edit</button><button class="danger mini" data-store-remove="${esc(item.id)}">Remove</button></div></div></div>`;
  }).join(""):empty("No items in this store category");
  $$("[data-store-edit]").forEach(b=>b.onclick=()=>editStoreItem(b.dataset.storeEdit));
  $$("[data-store-remove]").forEach(b=>b.onclick=()=>removeStoreItem(b.dataset.storeRemove).catch(e=>toast(e.message,false)));
}
function editStoreItem(id){
  const item=state.storeItems.find(x=>x.id===id);
  if(!item)return;
  const data=item.data||{};
  $("#storeId").value=item.id||"";
  $("#storeName").value=item.name||"";
  $("#storePrice").value=Number(item.price_coins||0);
  $("#storeVip").value=Number(data.min_vip_level??data.vip_level??0);
  $("#storeDuration").value=Number(data.duration_days??0);
  $("#storeTier").value=Number(data.tier??0);
  $("#storeOrder").value=Number(item.sort_order||0);
  $("#storeAsset").value=data.asset_key||data.asset||"";
  $("#storeEmoji").value=data.emoji||"";
  $("#storeCategory").value=data.category||"";
  $("#storeDescription").value=data.description||"";
  $("#storeEnabled").checked=Number(item.enabled)!==0;
  $("#storeId").scrollIntoView({behavior:"smooth",block:"center"});
}
async function saveStoreItem(){
  if(!can("catalog.write"))return toast("Store write permission required",false);
  const kind=$("#storeKind").value.trim();
  const itemId=$("#storeId").value.trim();
  const name=$("#storeName").value.trim()||itemId;
  if(!kind||!itemId||!name)return toast("Category, item ID and name are required",false);
  const payload={
    kind,
    id:itemId,
    name,
    price_coins:Number($("#storePrice").value||0),
    sort_order:Number($("#storeOrder").value||0),
    enabled:$("#storeEnabled").checked,
    data:{
      min_vip_level:Number($("#storeVip").value||0),
      vip_level:Number($("#storeVip").value||0),
      duration_days:Number($("#storeDuration").value||0),
      tier:Number($("#storeTier").value||0),
      asset_key:$("#storeAsset").value.trim(),
      asset:$("#storeAsset").value.trim(),
      emoji:$("#storeEmoji").value.trim(),
      category:$("#storeCategory").value.trim(),
      description:$("#storeDescription").value.trim(),
    },
  };
  await api("/api/owner/store",{method:"POST",body:JSON.stringify(payload)});
  toast("App Store item saved");
  clearStoreForm();
  await loadStore();
}
async function removeStoreItem(id){
  if(!can("catalog.write"))return toast("Store write permission required",false);
  const kind=$("#storeKind").value.trim();
  if(!confirm("Remove this item from the app store?"))return;
  await api("/api/owner/store/"+encodeURIComponent(kind)+"/"+encodeURIComponent(id),{method:"DELETE"});
  toast("Item removed from app store");
  await loadStore();
}


function fillVipRuleForm(rule){
  if(!rule)return;
  $("#vipRuleLevel").value=Number(rule.level||1);
  $("#vipRuleName").value=rule.name||("VIP "+Number(rule.level||1));
  $("#vipRuleUpgradeExp").value=Number(rule.upgrade_exp||0);
  $("#vipRuleMaintainExp").value=Number(rule.maintain_exp||0);
  $("#vipRuleValidityDays").value=Number(rule.validity_days||30);
  $("#vipRuleEntryId").value=rule.entry_id||"";
  $("#vipRuleFrameId").value=rule.frame_id||"";
  $("#vipRuleEnabled").checked=Number(rule.enabled)!==0;
}
async function loadVipRules(){
  if(!can("catalog.read"))return;
  const d=await api("/api/owner/vip-rules");
  state.vipRules=d.levels||[];
  $("#vipRuleList").innerHTML=state.vipRules.length?state.vipRules.map(rule=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(rule.name||("VIP "+rule.level))} <span class="pill ${Number(rule.enabled)?"active":"banned"}">${Number(rule.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">Level ${num(rule.level)} · upgrade ${num(rule.upgrade_exp)} EXP · maintain ${num(rule.maintain_exp)} EXP · ${num(rule.validity_days)} days · ${esc(rule.source||"base")}${rule.entry_id?" · entry "+esc(rule.entry_id):""}${rule.frame_id?" · frame "+esc(rule.frame_id):""}</div></div><button class="secondary mini" data-vip-rule-edit="${rule.level}">Edit</button></div></div>`).join(""):empty("No VIP rules");
  $$("[data-vip-rule-edit]").forEach(b=>b.onclick=()=>{const rule=state.vipRules.find(x=>Number(x.level)===Number(b.dataset.vipRuleEdit));fillVipRuleForm(rule);$("#vipRuleLevel").scrollIntoView({behavior:"smooth",block:"center"});});
  const selected=state.vipRules.find(x=>Number(x.level)===Number($("#vipRuleLevel").value||1))||state.vipRules[0];
  if(selected)fillVipRuleForm(selected);
}
async function saveVipRule(){
  if(!can("catalog.write"))return toast("Catalog write permission required",false);
  const level=Number($("#vipRuleLevel").value);
  const upgrade=Number($("#vipRuleUpgradeExp").value);
  const maintain=Number($("#vipRuleMaintainExp").value);
  const days=Number($("#vipRuleValidityDays").value);
  if(!Number.isSafeInteger(level)||level<1||level>18)return toast("VIP level must be 1–18",false);
  if(!Number.isSafeInteger(upgrade)||upgrade<0)return toast("Upgrade EXP is invalid",false);
  if(!Number.isSafeInteger(maintain)||maintain<0)return toast("Maintenance EXP is invalid",false);
  if(!Number.isSafeInteger(days)||days<1)return toast("Validity days are invalid",false);
  await api("/api/owner/vip-rules",{method:"POST",body:JSON.stringify({
    level,name:$("#vipRuleName").value.trim()||("VIP "+level),upgrade_exp:upgrade,maintain_exp:maintain,
    validity_days:days,entry_id:$("#vipRuleEntryId").value.trim(),frame_id:$("#vipRuleFrameId").value.trim(),
    enabled:$("#vipRuleEnabled").checked
  })});
  toast("VIP rule saved and active in leveling logic");
  await loadVipRules();
}
async function resetVipRule(){
  if(!can("catalog.write"))return toast("Catalog write permission required",false);
  const level=Number($("#vipRuleLevel").value);
  if(!Number.isSafeInteger(level)||level<1||level>18)return toast("Select VIP1–VIP18",false);
  if(!confirm("Reset VIP "+level+" to the DarkVibeX base rule?"))return;
  await api("/api/owner/vip-rules/"+level,{method:"DELETE"});
  toast("VIP rule reset to base");
  await loadVipRules();
}

function clearGiftForm(){
  $("#giftId").value="";$("#giftName").value="";$("#giftPrice").value=0;$("#giftVip").value=0;
  $("#giftEmoji").value="";$("#giftCategory").value="";$("#giftAsset").value="";$("#giftOrder").value=0;
  $("#giftStart").value="";$("#giftEnd").value="";$("#giftEnabled").checked=true;$("#giftDescription").value="";
}
async function loadGifts(){
  if(!can("catalog.read"))return;
  const d=await api("/api/owner/store?kind=gift");
  state.giftItems=d.items||[];
  $("#giftList").innerHTML=state.giftItems.length?state.giftItems.map(item=>{
    const data=item.data||{},enabled=Number(item.enabled)!==0;
    const windowText=(data.starts_at||data.ends_at)?` · ${data.starts_at?time(data.starts_at):"now"} → ${data.ends_at?time(data.ends_at):"no end"}`:"";
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name||item.id)} <span class="pill ${enabled?"active":"banned"}">${enabled?"Enabled":"Removed"}</span></div><div class="item-meta">ID ${esc(item.id)} · ${num(item.price_coins)} coins · VIP ${num(data.min_vip_level??data.vip_level??0)} · ${esc(item.source||"custom")}${windowText}<br>${esc(data.description||data.asset_key||data.emoji||"")}</div></div><div class="item-actions"><button class="secondary mini" data-gift-edit="${esc(item.id)}">Edit</button><button class="danger mini" data-gift-remove="${esc(item.id)}">Remove</button></div></div></div>`;
  }).join(""):empty("No gifts");
  $$("[data-gift-edit]").forEach(b=>b.onclick=()=>editGift(b.dataset.giftEdit));
  $$("[data-gift-remove]").forEach(b=>b.onclick=()=>removeGift(b.dataset.giftRemove).catch(e=>toast(e.message,false)));
}
function editGift(id){
  const item=state.giftItems.find(x=>x.id===id);if(!item)return;const d=item.data||{};
  $("#giftId").value=item.id||"";$("#giftName").value=item.name||"";$("#giftPrice").value=Number(item.price_coins||0);
  $("#giftVip").value=Number(d.min_vip_level??d.vip_level??0);$("#giftEmoji").value=d.emoji||"";$("#giftCategory").value=d.category||"";
  $("#giftAsset").value=d.asset_key||d.asset||"";$("#giftOrder").value=Number(item.sort_order||0);
  $("#giftStart").value=d.starts_at||"";$("#giftEnd").value=d.ends_at||"";$("#giftEnabled").checked=Number(item.enabled)!==0;$("#giftDescription").value=d.description||"";
}
async function saveGift(){
  if(!can("catalog.write"))return toast("Catalog write permission required",false);
  const id=$("#giftId").value.trim(),name=$("#giftName").value.trim()||id;
  if(!id||!name)return toast("Gift ID and name are required",false);
  const starts=Number($("#giftStart").value||0)||null,ends=Number($("#giftEnd").value||0)||null;
  if(starts&&ends&&ends<=starts)return toast("Gift end time must be after start time",false);
  await api("/api/owner/store",{method:"POST",body:JSON.stringify({
    kind:"gift",id,name,price_coins:Number($("#giftPrice").value||0),sort_order:Number($("#giftOrder").value||0),enabled:$("#giftEnabled").checked,
    data:{min_vip_level:Number($("#giftVip").value||0),vip_level:Number($("#giftVip").value||0),emoji:$("#giftEmoji").value.trim(),category:$("#giftCategory").value.trim(),asset_key:$("#giftAsset").value.trim(),asset:$("#giftAsset").value.trim(),description:$("#giftDescription").value.trim(),starts_at:starts,ends_at:ends}
  })});
  toast("Gift saved to live catalog");clearGiftForm();await loadGifts();
}
async function removeGift(id){
  if(!can("catalog.write"))return toast("Catalog write permission required",false);
  if(!confirm("Remove this gift from the app?"))return;
  await api("/api/owner/store/gift/"+encodeURIComponent(id),{method:"DELETE"});toast("Gift removed");await loadGifts();
}

function clearAssetForm(){
  $("#assetId").value="";$("#assetName").value="";$("#assetPrice").value=0;$("#assetVip").value=0;$("#assetDuration").value=30;
  $("#assetTier").value=0;$("#assetOrder").value=0;$("#assetFileKey").value="";$("#assetStart").value="";$("#assetEnd").value="";
  $("#assetEnabled").checked=true;$("#assetDescription").value="";
}
async function loadAssets(){
  if(!can("catalog.read"))return;
  const kind=$("#assetKind").value;
  const d=await api("/api/owner/store?kind="+encodeURIComponent(kind));
  state.assetItems=d.items||[];
  $("#assetList").innerHTML=state.assetItems.length?state.assetItems.map(item=>{
    const data=item.data||{},enabled=Number(item.enabled)!==0;
    const windowText=(data.starts_at||data.ends_at)?` · ${data.starts_at?time(data.starts_at):"now"} → ${data.ends_at?time(data.ends_at):"no end"}`:"";
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name||item.id)} <span class="pill ${enabled?"active":"banned"}">${enabled?"Enabled":"Removed"}</span></div><div class="item-meta">${esc(kind)} · ID ${esc(item.id)} · ${num(item.price_coins)} coins · VIP ${num(data.min_vip_level??0)} · ${num(data.duration_days??0)} days · tier ${num(data.tier??0)}${windowText}<br>${esc(data.description||data.asset_key||"")}</div></div><div class="item-actions"><button class="secondary mini" data-asset-edit="${esc(item.id)}">Edit</button><button class="danger mini" data-asset-remove="${esc(item.id)}">Remove</button></div></div></div>`;
  }).join(""):empty("No assets in this type");
  $$("[data-asset-edit]").forEach(b=>b.onclick=()=>editAsset(b.dataset.assetEdit));
  $$("[data-asset-remove]").forEach(b=>b.onclick=()=>removeAsset(b.dataset.assetRemove).catch(e=>toast(e.message,false)));
}
function editAsset(id){
  const item=state.assetItems.find(x=>x.id===id);if(!item)return;const d=item.data||{};
  $("#assetId").value=item.id||"";$("#assetName").value=item.name||"";$("#assetPrice").value=Number(item.price_coins||0);
  $("#assetVip").value=Number(d.min_vip_level??d.vip_level??0);$("#assetDuration").value=Number(d.duration_days??30);$("#assetTier").value=Number(d.tier??0);
  $("#assetOrder").value=Number(item.sort_order||0);$("#assetFileKey").value=d.asset_key||d.asset||"";$("#assetStart").value=d.starts_at||"";$("#assetEnd").value=d.ends_at||"";
  $("#assetEnabled").checked=Number(item.enabled)!==0;$("#assetDescription").value=d.description||"";
}
async function saveAsset(){
  if(!can("catalog.write"))return toast("Catalog write permission required",false);
  const kind=$("#assetKind").value,id=$("#assetId").value.trim(),name=$("#assetName").value.trim()||id;
  if(!kind||!id||!name)return toast("Asset type, ID and name are required",false);
  const starts=Number($("#assetStart").value||0)||null,ends=Number($("#assetEnd").value||0)||null;
  if(starts&&ends&&ends<=starts)return toast("Asset end time must be after start time",false);
  await api("/api/owner/store",{method:"POST",body:JSON.stringify({
    kind,id,name,price_coins:Number($("#assetPrice").value||0),sort_order:Number($("#assetOrder").value||0),enabled:$("#assetEnabled").checked,
    data:{min_vip_level:Number($("#assetVip").value||0),vip_level:Number($("#assetVip").value||0),duration_days:Number($("#assetDuration").value||0),tier:Number($("#assetTier").value||0),asset_key:$("#assetFileKey").value.trim(),asset:$("#assetFileKey").value.trim(),description:$("#assetDescription").value.trim(),starts_at:starts,ends_at:ends}
  })});
  toast("Asset saved to live store");clearAssetForm();await loadAssets();
}
async function removeAsset(id){
  if(!can("catalog.write"))return toast("Catalog write permission required",false);
  const kind=$("#assetKind").value;if(!confirm("Remove this "+kind+" from the app?"))return;
  await api("/api/owner/store/"+encodeURIComponent(kind)+"/"+encodeURIComponent(id),{method:"DELETE"});toast("Asset removed");await loadAssets();
}

function clearCatalogForm(){$("#catalogId").value="";$("#catalogName").value="";$("#catalogPrice").value=0;$("#catalogOrder").value=0;$("#catalogAsset").value="";$("#catalogLevel").value="";$("#catalogDescription").value="";$("#catalogEnabled").checked=true;}
async function loadCatalog(){if(!can("catalog.read"))return;const kind=$("#catalogKind").value;const d=await api('/api/owner/catalog?kind='+encodeURIComponent(kind));state.catalog=d.items||[];$("#catalogList").innerHTML=state.catalog.length?state.catalog.map(i=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(i.name)} <span class="pill ${Number(i.enabled)?'active':'banned'}">${Number(i.enabled)?'Enabled':'Disabled'}</span></div><div class="item-meta">ID ${esc(i.id)} · ${num(i.price_coins)} coins · order ${num(i.sort_order)}<br>${esc(i.data?.description||i.data?.level||i.data?.asset||'')}</div></div><div class="item-actions"><button class="secondary mini" data-catalog-edit="${esc(i.id)}">Edit</button><button class="danger mini" data-catalog-delete="${esc(i.id)}">Delete</button></div></div></div>`).join(""):empty("No items in this category");$$('[data-catalog-edit]').forEach(b=>b.onclick=()=>editCatalog(b.dataset.catalogEdit));$$('[data-catalog-delete]').forEach(b=>b.onclick=()=>deleteCatalog(b.dataset.catalogDelete));}
function editCatalog(id){const i=state.catalog.find(x=>x.id===id);if(!i)return;$("#catalogId").value=i.id;$("#catalogName").value=i.name;$("#catalogPrice").value=i.price_coins||0;$("#catalogOrder").value=i.sort_order||0;$("#catalogAsset").value=i.data?.asset||"";$("#catalogLevel").value=i.data?.level||"";$("#catalogDescription").value=i.data?.description||"";$("#catalogEnabled").checked=!!Number(i.enabled);window.scrollTo({top:0,behavior:'smooth'});}
async function saveCatalog(){const payload={kind:$("#catalogKind").value,id:$("#catalogId").value.trim()||undefined,name:$("#catalogName").value.trim(),price_coins:Number($("#catalogPrice").value||0),sort_order:Number($("#catalogOrder").value||0),enabled:$("#catalogEnabled").checked,data:{asset:$("#catalogAsset").value.trim(),level:$("#catalogLevel").value.trim(),description:$("#catalogDescription").value.trim()}};if(!payload.name)return toast('Enter a display name',false);await api('/api/owner/catalog',{method:'POST',body:JSON.stringify(payload)});toast('Content item saved');clearCatalogForm();await loadCatalog();}

async function deleteCatalog(id){if(!confirm('Delete this content item?'))return;const kind=$("#catalogKind").value;await api(`/api/owner/catalog/${encodeURIComponent(kind)}/${encodeURIComponent(id)}`,{method:'DELETE'});toast('Content item deleted');loadCatalog();}

async function loadSettings(){if(!can("settings.read"))return;const d=await api('/api/owner/settings');state.settings=new Map((d.settings||[]).map(s=>[s.key,s.value]));$("#featureSettings").innerHTML=Object.entries(featureLabels).map(([key,label])=>{const enabled=state.settings.get(key)?.enabled!==false;return `<label class="toggle-card"><span><b>${esc(label)}</b><small class="muted"> ${enabled?'On':'Off'}</small></span><input type="checkbox" data-setting-toggle="${esc(key)}" ${enabled?'checked':''}></label>`}).join('');$$('[data-setting-toggle]').forEach(i=>i.onchange=()=>saveFeature(i.dataset.settingToggle,i.checked));const m=state.settings.get('maintenance')||{};$("#maintenanceEnabled").checked=!!m.enabled;$("#maintenanceMessage").value=m.message||"";}
async function saveFeature(key,enabled){await api('/api/owner/settings/'+encodeURIComponent(key),{method:'POST',body:JSON.stringify({value:{enabled}})});toast(featureLabels[key]+' '+(enabled?'enabled':'disabled'));}
async function saveMaintenance(){await api('/api/owner/settings/maintenance',{method:'POST',body:JSON.stringify({value:{enabled:$("#maintenanceEnabled").checked,message:$("#maintenanceMessage").value.trim()}})});toast('Maintenance setting saved');}

async function loadAnnouncements(){if(!can("announcements.read"))return;const d=await api('/api/owner/announcements');$("#announcementList").innerHTML=(d.announcements||[]).length?d.announcements.map(a=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(a.title)} <span class="pill ${Number(a.enabled)?'active':'banned'}">${Number(a.enabled)?'Enabled':'Disabled'}</span></div><div class="item-meta">${esc(a.body)}</div></div><button class="danger mini" data-ann-delete="${esc(a.id)}">Delete</button></div></div>`).join(''):empty('No announcements');$$('[data-ann-delete]').forEach(b=>b.onclick=async()=>{if(!confirm('Delete this announcement?'))return;await api('/api/owner/announcements/'+encodeURIComponent(b.dataset.annDelete),{method:'DELETE'});toast('Announcement deleted');loadAnnouncements();});}
async function saveAnnouncement(){const payload={title:$("#announcementTitle").value.trim(),body:$("#announcementBody").value.trim(),enabled:$("#announcementEnabled").checked};if(!payload.title||!payload.body)return toast('Title and message are required',false);await api('/api/owner/announcements',{method:'POST',body:JSON.stringify(payload)});$("#announcementTitle").value='';$("#announcementBody").value='';toast('Announcement published');loadAnnouncements();}

async function loadStaff(){
  if(!can("staff.read"))return;
  if(!$("#staffPermissions").dataset.ready){
    $("#staffPermissions").innerHTML=staffPermissionOptions.map(([value,label])=>`<label class="permission-item"><input type="checkbox" value="${esc(value)}" /> <span>${esc(label)}</span></label>`).join("");
    $("#staffPermissions").dataset.ready="1";
  }
  const d=await api('/api/owner/staff');
  $("#staffList").innerHTML=(d.staff||[]).length?d.staff.map(s=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(s.display_name)} <span class="pill ${Number(s.enabled)?'active':'banned'}">${Number(s.enabled)?'Enabled':'Disabled'}</span></div><div class="item-meta">${esc(s.role.replaceAll('_',' '))} · last used ${time(s.last_used_at)}<br>${(s.permissions||[]).length?esc((s.permissions||[]).join(', ')):'Role defaults'}</div></div><div class="item-actions">${can('staff.write')?`<button class="secondary mini" data-staff-edit="${esc(s.id)}">Permissions</button><button class="secondary mini" data-staff-toggle="${esc(s.id)}" data-enabled="${Number(s.enabled)}">${Number(s.enabled)?'Disable':'Enable'}</button><button class="danger mini" data-staff-delete="${esc(s.id)}">Delete</button>`:''}</div></div></div>`).join(''):empty('No custom panels created');
  $$('[data-staff-edit]').forEach(b=>b.onclick=async()=>{
    const item=(d.staff||[]).find(x=>x.id===b.dataset.staffEdit); if(!item)return;
    const current=new Set(item.permissions||[]);
    const raw=prompt("Comma-separated permissions. Use * for full access.",[...current].join(", "));
    if(raw===null)return;
    const permissions=raw.split(",").map(x=>x.trim()).filter(Boolean);
    await api('/api/owner/staff/'+encodeURIComponent(item.id),{method:'POST',body:JSON.stringify({permissions})});
    toast('Custom panel permissions updated');loadStaff();
  });
  $$('[data-staff-toggle]').forEach(b=>b.onclick=async()=>{await api('/api/owner/staff/'+encodeURIComponent(b.dataset.staffToggle),{method:'POST',body:JSON.stringify({enabled:!Number(b.dataset.enabled)})});toast('Staff access updated');loadStaff();});
  $$('[data-staff-delete]').forEach(b=>b.onclick=async()=>{if(!confirm('Delete this staff access?'))return;await api('/api/owner/staff/'+encodeURIComponent(b.dataset.staffDelete),{method:'DELETE'});toast('Staff access deleted');loadStaff();});
}

async function loadSupport(){if(!can('support.read'))return;const status=$("#supportStatus").value;const d=await api('/api/owner/support-tickets?status='+encodeURIComponent(status));const rows=d.tickets||[];$("#supportList").innerHTML=rows.length?rows.map(t=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(t.subject)} <span class="pill ${t.status==='open'?'active':'banned'}">${esc(t.status)}</span></div><div class="item-meta">${esc(t.display_name||'VIP user')} · ID ${esc(t.user_id)} · VIP ${num(t.vip_level)} · ${time(t.updated_at)}<br>${t.last_message?esc(t.last_message):''}</div></div><button class="secondary mini" data-ticket-open="${esc(t.id)}">View thread</button></div></div>`).join(''):empty('No tickets for this status');$$('[data-ticket-open]').forEach(b=>b.onclick=()=>openSupportTicket(b.dataset.ticketOpen).catch(e=>toast(e.message,false)));}
async function openSupportTicket(id){const d=await api('/api/owner/support-tickets/'+encodeURIComponent(id));state.selectedTicket=d.ticket;$("#supportThread").hidden=false;$("#supportThreadTitle").textContent=d.ticket.subject;$("#supportThreadMeta").textContent=`${d.ticket.display_name||'VIP user'} · ${d.ticket.user_id} · VIP ${num(d.ticket.vip_level)} · ${d.ticket.status} · ${time(d.ticket.created_at)}`;$("#supportMessages").innerHTML=(d.messages||[]).map(m=>`<div class="item-card"><div class="item-title">${m.sender_type==='staff'?'Support team':'VIP user'} · ${time(m.created_at)}</div><div>${esc(m.body)}</div></div>`).join('')||empty('No messages');$("#closeSupportTicket").hidden=d.ticket.status!=='open'||!can('support.write');$("#sendSupportReply").disabled=d.ticket.status!=='open'||!can('support.write');$("#supportReply").disabled=d.ticket.status!=='open'||!can('support.write');$("#supportThread").scrollIntoView({behavior:'smooth',block:'start'});}
async function sendSupportReply(){if(!state.selectedTicket)return;const message=$("#supportReply").value.trim();if(!message)return toast('Write a reply first',false);await api(`/api/owner/support-tickets/${encodeURIComponent(state.selectedTicket.id)}/reply`,{method:'POST',body:JSON.stringify({message})});$("#supportReply").value='';toast('Reply sent');await openSupportTicket(state.selectedTicket.id);await loadSupport();}
async function closeSupportTicket(){if(!state.selectedTicket)return;if(!confirm('Close this VIP support ticket?'))return;await api(`/api/owner/support-tickets/${encodeURIComponent(state.selectedTicket.id)}/close`,{method:'POST',body:'{}'});toast('Ticket closed');await openSupportTicket(state.selectedTicket.id);await loadSupport();}
async function createStaff(){if(!can('staff.write'))return toast('Only owner or authorized super admin can create staff access',false);const name=$("#staffName").value.trim();if(!name)return toast('Enter staff name',false);const permissions=$$("#staffPermissions input:checked").map(x=>x.value);const payload={display_name:name,role:$("#staffRole").value};if(permissions.length)payload.permissions=permissions;const d=await api('/api/owner/staff',{method:'POST',body:JSON.stringify(payload)});$("#staffName").value='';$$("#staffPermissions input").forEach(x=>x.checked=false);const box=$("#newStaffToken");box.hidden=false;box.innerHTML=`<b>One-time access token</b><br>${esc(d.token)}<br><small>Save it securely now. It cannot be viewed again from this panel.</small>`;toast('Custom panel access created');loadStaff();}


async function saveUserOverrides(){
  if(!state.selectedUser)return toast("Select a user first",false);
  if(!can("users.override"))return toast("User override permission required",false);
  await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/owner-overrides`,{
    method:"POST",
    body:JSON.stringify({
      invisible_id:$("#userInvisibleId").checked,
      locked_room_bypass:$("#userLockedBypass").checked,
      wallet_banned:$("#userWalletBanned").checked,
      wallet_frozen:$("#userWalletFrozen").checked,
    }),
  });
  toast("Owner overrides saved");
  await openUser(state.selectedUser.id);
}
async function toggleDeviceBan(deviceKey,currentlyBanned){
  if(!state.selectedUser)return;
  if(!can("users.device"))return toast("Device-ban permission required",false);
  await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/device-ban`,{
    method:"POST",
    body:JSON.stringify({device_key:deviceKey,banned:!currentlyBanned}),
  });
  toast(currentlyBanned?"Device unbanned":"Device banned");
  await openUser(state.selectedUser.id);
}

async function loadNotifications(){
  if(!can("notifications.read"))return;
  const d=await api("/api/owner/notifications");
  const rows=d.notifications||[];
  $("#notificationList").innerHTML=rows.length?rows.map(n=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(n.title)} <span class="pill ${n.read_at?"active":"banned"}">${n.read_at?"Read":"Unread"}</span></div><div class="item-meta">${esc(n.kind)}${n.user_id?" · user "+esc(n.user_id):""} · ${time(n.created_at)}<br>${esc(n.body)}</div></div><div class="item-actions">${!n.read_at&&can("notifications.write")?`<button class="secondary mini" data-notification-read="${esc(n.id)}">Mark read</button>`:""}${can("notifications.write")?`<button class="danger mini" data-notification-delete="${esc(n.id)}">Delete</button>`:""}</div></div></div>`).join(""):empty("No owner notifications");
  $$("[data-notification-read]").forEach(b=>b.onclick=async()=>{await api("/api/owner/notifications/"+encodeURIComponent(b.dataset.notificationRead)+"/read",{method:"POST",body:"{}"});await loadNotifications();});
  $$("[data-notification-delete]").forEach(b=>b.onclick=async()=>{if(!confirm("Delete this notification?"))return;await api("/api/owner/notifications/"+encodeURIComponent(b.dataset.notificationDelete),{method:"DELETE"});await loadNotifications();});
}

function renderSelectedMessageUsers(){
  $("#selectedMessageUsers").textContent=`${state.messageSelected.size} selected`;
}
async function searchMessagingUsers(){
  if(!can("users.read"))return toast("Users read permission required",false);
  const q=$("#messageUserSearch").value.trim();
  if(!q)return toast("Enter a user ID or name",false);
  const d=await api("/api/owner/users?q="+encodeURIComponent(q)+"&limit=80");
  const rows=(d.users||[]).filter(u=>u.id!=="darkvibex_official");
  $("#messageUserResults").innerHTML=rows.length?rows.map(u=>`<label class="item-card"><div class="item-main"><div><div class="item-title">${esc(u.display_name||"User")}</div><div class="item-meta">Public ID ${esc(u.public_id||"—")} · Internal ${esc(u.id)}</div></div><input type="checkbox" data-message-user="${esc(u.id)}" ${state.messageSelected.has(String(u.id))?"checked":""}></div></label>`).join(""):empty("No matching users");
  $$("[data-message-user]").forEach(box=>box.onchange=()=>{
    const id=String(box.dataset.messageUser);
    if(box.checked){
      const u=rows.find(x=>String(x.id)===id);
      state.messageSelected.set(id,u||{id});
    }else state.messageSelected.delete(id);
    renderSelectedMessageUsers();
  });
}
async function loadOwnerTags(){
  if(!can("messaging.read"))return;
  const d=await api("/api/owner/tags");
  const rows=d.tags||[];
  $("#ownerTagList").innerHTML=rows.length?rows.map(t=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(t.name)}${t.designation?" · "+esc(t.designation):""}</div><div class="item-meta">${esc(t.kind)} · ${esc(t.display_name||t.user_id)} · Public ID ${esc(t.public_id||"—")} · ${time(t.updated_at)}</div></div>${can("tags.write")?`<button class="danger mini" data-tag-user="${esc(t.user_id)}" data-tag-id="${esc(t.tag_id)}">Remove</button>`:""}</div></div>`).join(""):empty("No custom tags / V Officials");
  $$("[data-tag-user]").forEach(b=>b.onclick=async()=>{await api("/api/owner/tags/"+encodeURIComponent(b.dataset.tagUser)+"/"+encodeURIComponent(b.dataset.tagId),{method:"DELETE"});toast("Tag removed");await loadOwnerTags();});
}
async function loadMessaging(){
  renderSelectedMessageUsers();
  await loadOwnerTags();
}
async function sendOfficialMessage(allUsers=false){
  if(!can("messaging.write"))return toast("Messaging write permission required",false);
  const text=$("#officialMessageBody").value.trim();
  if(!text)return toast("Write a message first",false);
  const ids=[...state.messageSelected.keys()];
  if(!allUsers&&!ids.length)return toast("Select at least one user",false);
  if(allUsers&&!confirm("Send this DarkVibeX Official message to all users?"))return;
  const d=await api("/api/owner/messages",{method:"POST",body:JSON.stringify({text,user_ids:ids,all_users:allUsers})});
  toast(`Official message sent to ${num(d.sent||0)} users`);
  $("#officialMessageBody").value="";
}
async function applyOwnerTag(){
  if(!can("tags.write"))return toast("Tags write permission required",false);
  const ids=[...state.messageSelected.keys()];
  if(!ids.length)return toast("Select at least one user",false);
  const kind=$("#ownerTagKind").value;
  const designation=$("#ownerTagDesignation").value.trim();
  let name=$("#ownerTagName").value.trim();
  if(kind==="v_official"&&!designation)return toast("V Official designation is required",false);
  if(kind==="v_official"&&!name)name="V Official";
  if(!name)return toast("Tag name is required",false);
  const color=$("#ownerTagColor").value;
  const d=await api("/api/owner/tags",{method:"POST",body:JSON.stringify({user_ids:ids,name,color,kind,designation,background_color:color})});
  toast(`${d.name||name} applied to ${num(d.tagged||0)} users`);
  await loadOwnerTags();
}

async function loadRolesPosts(){
  if(!can("roles.read"))return;
  const kind=$("#rolePostKind").value;
  const d=await api("/api/owner/roles-posts?kind="+encodeURIComponent(kind));
  state.rolesPosts=d.items||[];
  $("#rolePostList").innerHTML=state.rolesPosts.length?state.rolesPosts.map(item=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name)} <span class="pill ${Number(item.enabled)?"active":"banned"}">${Number(item.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">${esc(item.id)} · ${esc(item.data?.details||"")}</div></div><div class="item-actions"><button class="secondary mini" data-role-post-edit="${esc(item.id)}">Edit</button><button class="danger mini" data-role-post-delete="${esc(item.id)}">Delete</button></div></div></div>`).join(""):empty("No roles/posts configured");
  $$("[data-role-post-edit]").forEach(b=>b.onclick=()=>{const item=state.rolesPosts.find(x=>x.id===b.dataset.rolePostEdit);if(!item)return;$("#rolePostId").value=item.id;$("#rolePostName").value=item.name||"";$("#rolePostOrder").value=Number(item.sort_order||0);$("#rolePostEnabled").checked=Number(item.enabled)!==0;$("#rolePostDetails").value=item.data?.details||"";});
  $$("[data-role-post-delete]").forEach(b=>b.onclick=async()=>{if(!confirm("Delete this "+kind+"?"))return;await api("/api/owner/roles-posts/"+encodeURIComponent(b.dataset.rolePostDelete)+"?kind="+encodeURIComponent(kind),{method:"DELETE"});toast("Deleted");await loadRolesPosts();});
}
async function saveRolePost(){
  if(!can("roles.write"))return toast("Roles write permission required",false);
  const kind=$("#rolePostKind").value;
  const name=$("#rolePostName").value.trim();
  if(!name)return toast("Name is required",false);
  await api("/api/owner/roles-posts?kind="+encodeURIComponent(kind),{method:"POST",body:JSON.stringify({id:$("#rolePostId").value.trim()||undefined,name,enabled:$("#rolePostEnabled").checked,sort_order:Number($("#rolePostOrder").value||0),data:{details:$("#rolePostDetails").value.trim()}})});
  toast((kind==="post"?"Post":"Role")+" saved");
  await loadRolesPosts();
}

async function loadBanners(){
  if(!can("banners.read"))return;
  const d=await api("/api/owner/banners");
  state.banners=d.banners||[];
  $("#bannerList").innerHTML=state.banners.length?state.banners.map(item=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name)} <span class="pill ${Number(item.enabled)?"active":"banned"}">${Number(item.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">${esc(item.id)} · ${esc(item.data?.asset_key||"")}${item.data?.link?" · "+esc(item.data.link):""}</div></div><div class="item-actions"><button class="secondary mini" data-banner-edit="${esc(item.id)}">Edit</button><button class="danger mini" data-banner-delete="${esc(item.id)}">Delete</button></div></div></div>`).join(""):empty("No banners configured");
  $$("[data-banner-edit]").forEach(b=>b.onclick=()=>{const x=state.banners.find(i=>i.id===b.dataset.bannerEdit);if(!x)return;$("#bannerId").value=x.id;$("#bannerName").value=x.name||"";$("#bannerAsset").value=x.data?.asset_key||"";$("#bannerLink").value=x.data?.link||"";$("#bannerStart").value=x.data?.starts_at||"";$("#bannerEnd").value=x.data?.ends_at||"";$("#bannerEnabled").checked=Number(x.enabled)!==0;});
  $$("[data-banner-delete]").forEach(b=>b.onclick=async()=>{if(!confirm("Delete this banner?"))return;await api("/api/owner/banners/"+encodeURIComponent(b.dataset.bannerDelete),{method:"DELETE"});toast("Banner deleted");await loadBanners();});
}
async function saveBanner(){
  if(!can("banners.write"))return toast("Banner write permission required",false);
  const name=$("#bannerName").value.trim();
  if(!name)return toast("Banner name is required",false);
  await api("/api/owner/banners",{method:"POST",body:JSON.stringify({id:$("#bannerId").value.trim()||undefined,name,asset_key:$("#bannerAsset").value.trim(),link:$("#bannerLink").value.trim(),starts_at:Number($("#bannerStart").value||0)||null,ends_at:Number($("#bannerEnd").value||0)||null,enabled:$("#bannerEnabled").checked})});
  toast("Banner saved");
  await loadBanners();
}

async function loadGames(){
  if(!can("games.read"))return;
  const d=await api("/api/owner/games");
  state.games=d.games||[];
  $("#gameList").innerHTML=state.games.length?state.games.map(item=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name)} <span class="pill ${Number(item.enabled)?"active":"banned"}">${Number(item.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">${esc(item.id)} · bet ${num(item.data?.min_bet||1)}–${num(item.data?.max_bet||0)}</div></div><button class="secondary mini" data-game-edit="${esc(item.id)}">Edit</button></div></div>`).join(""):empty("No game overrides configured");
  $("#gameStats").innerHTML=(d.stats||[]).length?(d.stats||[]).map(x=>`<div class="item-card"><div class="item-title">${esc(x.game_id)}</div><div class="item-meta">${num(x.bets)} bets · wagered ${num(x.wagered)} · payout ${num(x.payout)} · house result ${num(x.house_result)}</div></div>`).join(""):empty("No game-bet statistics yet");
  $$("[data-game-edit]").forEach(b=>b.onclick=()=>{const x=state.games.find(i=>i.id===b.dataset.gameEdit);if(!x)return;$("#gameConfigId").value=x.id;$("#gameConfigName").value=x.name||"";$("#gameMinBet").value=Number(x.data?.min_bet||1);$("#gameMaxBet").value=Number(x.data?.max_bet||1000000);$("#gameEnabled").checked=Number(x.enabled)!==0;});
}
async function saveGameConfig(){
  if(!can("games.write"))return toast("Games write permission required",false);
  const id=$("#gameConfigId").value.trim();
  if(!id)return toast("Game ID is required",false);
  const min=Number($("#gameMinBet").value||1),max=Number($("#gameMaxBet").value||1);
  if(min<1||max<min)return toast("Bet limits are invalid",false);
  await api("/api/owner/games",{method:"POST",body:JSON.stringify({id,name:$("#gameConfigName").value.trim()||id,min_bet:min,max_bet:max,enabled:$("#gameEnabled").checked})});
  toast("Game config saved");
  await loadGames();
}

async function loadPolicies(){
  if(!can("policies.read"))return;
  const d=await api("/api/owner/policies");
  state.policies=d.policies||[];
  $("#policyList").innerHTML=state.policies.length?state.policies.map(p=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(p.key)}</div><div class="item-meta">${esc(JSON.stringify(p.value))} · ${time(p.updated_at)}</div></div><div class="item-actions"><button class="secondary mini" data-policy-edit="${esc(p.key)}">Edit</button><button class="danger mini" data-policy-delete="${esc(p.key)}">Delete</button></div></div></div>`).join(""):empty("No custom allowed policies");
  $$("[data-policy-edit]").forEach(b=>b.onclick=()=>{const p=state.policies.find(x=>x.key===b.dataset.policyEdit);if(!p)return;$("#policyKey").value=p.key.replace(/^policy\./,"");$("#policyValue").value=JSON.stringify(p.value,null,2);});
  $$("[data-policy-delete]").forEach(b=>b.onclick=async()=>{if(!confirm("Delete this policy?"))return;await api("/api/owner/policies/"+encodeURIComponent(b.dataset.policyDelete),{method:"DELETE"});toast("Policy deleted");await loadPolicies();});
  await loadPricingOverrides();
}
async function savePolicy(){
  if(!can("policies.write"))return toast("Policies write permission required",false);
  const key=$("#policyKey").value.trim();
  if(!key)return toast("Policy key is required",false);
  let value={};
  try{value=JSON.parse($("#policyValue").value.trim()||"{}");}catch(_){return toast("Policy value must be valid JSON",false);}
  await api("/api/owner/policies",{method:"POST",body:JSON.stringify({key,value})});
  toast("Policy saved");
  await loadPolicies();
}



function clearPricingOverride(){
  $("#pricingUserId").value="";
  $("#pricingItemId").value="*";
  $("#pricingPrice").value="";
  $("#pricingDuration").value="";
  $("#pricingFree").checked=false;
  updatePricingFreeState();
}
function updatePricingFreeState(){
  const gift=$("#pricingKind").value==="gift";
  $("#pricingFree").disabled=gift;
  if(gift)$("#pricingFree").checked=false;
}
async function loadPricingOverrides(){
  if(!can("policies.read"))return;
  const user=$("#pricingUserId").value.trim();
  const kind=$("#pricingKind").value.trim();
  const query=new URLSearchParams();
  if(user)query.set("user_id",user);
  if(kind)query.set("kind",kind);
  const d=await api("/api/owner/pricing-overrides?"+query.toString());
  state.pricingOverrides=d.overrides||[];
  $("#pricingOverrideList").innerHTML=state.pricingOverrides.length?state.pricingOverrides.map(row=>{
    const free=Number(row.free||0)===1;
    const price=free?"FREE":(row.price_coins==null?"base price":num(row.price_coins)+" coins");
    const days=row.duration_days==null?"base validity":(Number(row.duration_days)===0?"permanent":num(row.duration_days)+" days");
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(row.display_name||row.public_id||row.user_id)} · ${esc(row.kind)} · ${esc(row.item_id)}</div><div class="item-meta">User ${esc(row.public_id||row.user_id)} · ${esc(price)} · ${esc(days)} · ${time(row.updated_at)}</div></div><div class="item-actions"><button class="secondary mini" data-pricing-edit-user="${esc(row.user_id)}" data-pricing-kind="${esc(row.kind)}" data-pricing-item="${esc(row.item_id)}">Edit</button><button class="danger mini" data-pricing-delete-user="${esc(row.user_id)}" data-pricing-delete-kind="${esc(row.kind)}" data-pricing-delete-item="${esc(row.item_id)}">Remove</button></div></div></div>`;
  }).join(""):empty("No per-user pricing overrides for this filter");
  $$("[data-pricing-edit-user]").forEach(b=>b.onclick=()=>{
    const row=state.pricingOverrides.find(x=>String(x.user_id)===b.dataset.pricingEditUser&&String(x.kind)===b.dataset.pricingKind&&String(x.item_id)===b.dataset.pricingItem);
    if(!row)return;
    $("#pricingUserId").value=row.public_id||row.user_id;
    $("#pricingKind").value=row.kind;
    $("#pricingItemId").value=row.item_id||"*";
    $("#pricingPrice").value=row.price_coins==null?"":Number(row.price_coins);
    $("#pricingDuration").value=row.duration_days==null?"":Number(row.duration_days);
    $("#pricingFree").checked=Number(row.free||0)===1;
    updatePricingFreeState();
  });
  $$("[data-pricing-delete-user]").forEach(b=>b.onclick=async()=>{
    if(!can("policies.write"))return toast("Policies write permission required",false);
    if(!confirm("Remove this per-user pricing override?"))return;
    await api("/api/owner/pricing-overrides/"+encodeURIComponent(b.dataset.pricingDeleteUser)+"/"+encodeURIComponent(b.dataset.pricingDeleteKind)+"/"+encodeURIComponent(b.dataset.pricingDeleteItem),{method:"DELETE"});
    toast("Pricing override removed");
    await loadPricingOverrides();
  });
}
async function savePricingOverride(){
  if(!can("policies.write"))return toast("Policies write permission required",false);
  const userId=$("#pricingUserId").value.trim();
  const kind=$("#pricingKind").value.trim();
  const itemId=$("#pricingItemId").value.trim()||"*";
  if(!userId)return toast("User ID is required",false);
  const free=$("#pricingFree").checked;
  if(kind==="gift"&&free)return toast("Gifts cannot be zero-cost; use a positive custom price",false);
  const rawPrice=$("#pricingPrice").value.trim();
  const rawDuration=$("#pricingDuration").value.trim();
  const price=rawPrice===""?null:Number(rawPrice);
  const days=rawDuration===""?null:Number(rawDuration);
  if(price!=null&&(!Number.isSafeInteger(price)||price<0))return toast("Price must be a non-negative whole number",false);
  if(days!=null&&(!Number.isSafeInteger(days)||days<0||days>3650))return toast("Validity must be 0–3650 days",false);
  await api("/api/owner/pricing-overrides",{method:"POST",body:JSON.stringify({user_id:userId,kind,item_id:itemId,price_coins:price,free,duration_days:days})});
  toast("Per-user pricing override saved");
  await loadPricingOverrides();
}

async function loadGlobalThemes(){
  if(!can("catalog.read"))return;
  const d=await api("/api/owner/store?kind=theme");
  state.globalThemes=d.items||[];
  $("#globalThemeList").innerHTML=state.globalThemes.length?state.globalThemes.map(item=>{
    const data=item.data||{};
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name)} <span class="pill ${Number(item.enabled)?"active":"banned"}">${Number(item.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">${esc(item.id)} · ${esc(data.asset_key||data.asset||"")} · ${data.permanent?"Permanent":((data.starts_at?time(data.starts_at):"Now")+" → "+(data.ends_at?time(data.ends_at):"No end"))}</div></div><div class="item-actions"><button class="secondary mini" data-global-theme-edit="${esc(item.id)}">Edit</button><button class="danger mini" data-global-theme-remove="${esc(item.id)}">Remove</button></div></div></div>`;
  }).join(""):empty("No global room themes");
  $$("[data-global-theme-edit]").forEach(b=>b.onclick=()=>{
    const x=state.globalThemes.find(item=>item.id===b.dataset.globalThemeEdit);if(!x)return;
    const data=x.data||{};
    $("#globalThemeId").value=x.id;$("#globalThemeName").value=x.name||"";$("#globalThemeAsset").value=data.asset_key||data.asset||"";
    $("#globalThemeStart").value=data.starts_at||"";$("#globalThemeEnd").value=data.ends_at||"";
    $("#globalThemePermanent").checked=data.permanent===true||!data.ends_at;$("#globalThemeEnabled").checked=Number(x.enabled)!==0;
  });
  $$("[data-global-theme-remove]").forEach(b=>b.onclick=async()=>{if(!confirm("Remove this global room theme?"))return;await api("/api/owner/store/theme/"+encodeURIComponent(b.dataset.globalThemeRemove),{method:"DELETE"});toast("Global theme removed");await loadGlobalThemes();});
}
async function saveGlobalTheme(){
  if(!can("catalog.write"))return toast("Catalog write permission required",false);
  const id=$("#globalThemeId").value.trim(),name=$("#globalThemeName").value.trim(),asset=$("#globalThemeAsset").value.trim();
  if(!id||!name||!asset)return toast("Theme ID, name and asset are required",false);
  const permanent=$("#globalThemePermanent").checked;
  const starts=Number($("#globalThemeStart").value||0)||null;
  const ends=permanent?null:(Number($("#globalThemeEnd").value||0)||null);
  if(!permanent&&starts&&ends&&ends<=starts)return toast("End time must be after start time",false);
  await api("/api/owner/store",{method:"POST",body:JSON.stringify({
    kind:"theme",id,name,price_coins:0,sort_order:0,enabled:$("#globalThemeEnabled").checked,
    data:{asset_key:asset,asset,starts_at:starts,ends_at:ends,permanent}
  })});
  toast("Global room theme saved");
  await loadGlobalThemes();
}

async function loadAudit(){
  if(!can("audit.read"))return;
  const d=await api("/api/owner/audit?limit=500");
  state.auditRows=d.audit||[];
  const canDelete=d.owner_can_delete===true||state.actor?.type==="owner";
  $("#clearAudit").hidden=!canDelete;
  $("#auditList").innerHTML=state.auditRows.length?`<div class="small-table">${state.auditRows.map(a=>`<div class="audit-row"><span>${time(a.created_at)}</span><span><b>${esc(a.action.replaceAll("_"," "))}</b><br><span class="muted">${esc(a.actor_type)} ${esc(a.actor_id)} → ${esc(a.target_type)} ${esc(a.target_id)}${a.summary?" · "+esc(a.summary):""}</span></span>${canDelete?`<button class="danger mini" data-audit-delete="${esc(a.id)}">Delete</button>`:""}</div>`).join("")}</div>`:empty("No audit records yet");
  $$("[data-audit-delete]").forEach(b=>b.onclick=async()=>{if(!confirm("Delete this audit record?"))return;await api("/api/owner/audit/"+encodeURIComponent(b.dataset.auditDelete),{method:"DELETE"});toast("Audit record deleted");await loadAudit();});
}
function exportAuditCsv(){
  const rows=state.auditRows||[];
  const quote=value=>'"'+String(value??"").replaceAll('"','""')+'"';
  const lines=[["Date","Panel Type","Panel ID","Action","Target Type","Target ID","Details"].map(quote).join(",")];
  for(const a of rows)lines.push([new Date(Number(a.created_at||0)).toISOString(),a.actor_type,a.actor_id,a.action,a.target_type,a.target_id,a.summary].map(quote).join(","));
  const blob=new Blob([lines.join("\n")],{type:"text/csv;charset=utf-8"});
  const url=URL.createObjectURL(blob);const link=document.createElement("a");link.href=url;link.download="darkvibex-owner-audit.csv";document.body.appendChild(link);link.click();link.remove();URL.revokeObjectURL(url);
}
async function clearAudit(){
  if(state.actor?.type!=="owner")return toast("Only the main Owner can delete audit records",false);
  if(!confirm("Delete ALL audit records?"))return;
  await api("/api/owner/audit",{method:"DELETE"});toast("All audit records deleted");await loadAudit();
}

$("#connect").onclick=connect;$("#token").addEventListener('keydown',e=>{if(e.key==='Enter')connect();});
$("#logout").onclick=()=>{state.token='';state.actor=null;sessionStorage.removeItem('dvxOwnerToken');showApp(false);$("#token").value='';};
$$('.nav-btn').forEach(b=>b.onclick=()=>setView(b.dataset.view));
$$('[data-catalog-shortcut]').forEach(b=>b.onclick=()=>{$("#catalogKind").value=b.dataset.catalogShortcut;clearCatalogForm();loadCatalog().catch(e=>toast(e.message,false));});
$("#refreshCurrent").onclick=()=>loadView(state.view).catch(e=>toast(e.message,false));
$("#searchUsers").onclick=()=>loadUsers().catch(e=>toast(e.message,false));$("#userSearch").addEventListener('keydown',e=>{if(e.key==='Enter')loadUsers().catch(x=>toast(x.message,false));});
$("#saveUserOverrides").onclick=()=>saveUserOverrides().catch(e=>toast(e.message,false));
$("#reloadNotifications").onclick=()=>loadNotifications().catch(e=>toast(e.message,false));
$("#searchMessageUsers").onclick=()=>searchMessagingUsers().catch(e=>toast(e.message,false));$("#messageUserSearch").addEventListener("keydown",e=>{if(e.key==="Enter")searchMessagingUsers().catch(x=>toast(x.message,false));});
$("#sendOfficialSelected").onclick=()=>sendOfficialMessage(false).catch(e=>toast(e.message,false));$("#sendOfficialAll").onclick=()=>sendOfficialMessage(true).catch(e=>toast(e.message,false));$("#applyOwnerTag").onclick=()=>applyOwnerTag().catch(e=>toast(e.message,false));

$("#closeUser").onclick=()=>{$("#userEditor").hidden=true;state.selectedUser=null;};$("#saveUserProfile").onclick=()=>saveUserProfile().catch(e=>toast(e.message,false));$("#saveModeration").onclick=()=>saveModeration().catch(e=>toast(e.message,false));$("#savePublicId").onclick=()=>savePublicId().catch(e=>toast(e.message,false));$("#applyWallet").onclick=()=>applyWallet().catch(e=>toast(e.message,false));$("#applyRoleWallet").onclick=()=>applyRoleWallet().catch(e=>toast(e.message,false));$("#roleWalletType").onchange=()=>{$("#roleWalletBalance").textContent="Selected "+($("#roleWalletType").value||"role")+" wallet. Enter a coin change or change ban status and apply.";$("#roleWalletBanned").checked=false;};
$("#searchRooms").onclick=()=>loadRooms().catch(e=>toast(e.message,false));$("#roomSearch").addEventListener('keydown',e=>{if(e.key==='Enter')loadRooms().catch(x=>toast(x.message,false));});
$("#closeRoomInvestigation").onclick=()=>{$("#roomInvestigation").hidden=true;state.selectedRoomId=null;};$("#saveOwnerRoomMedia").onclick=()=>saveOwnerRoomMedia().catch(e=>toast(e.message,false));$("#saveOwnerRoomTheme").onclick=()=>saveOwnerRoomTheme().catch(e=>toast(e.message,false));
$("#reloadGlobalThemes").onclick=()=>loadGlobalThemes().catch(e=>toast(e.message,false));$("#saveGlobalTheme").onclick=()=>saveGlobalTheme().catch(e=>toast(e.message,false));

$("#rolePostKind").onchange=()=>loadRolesPosts().catch(e=>toast(e.message,false));$("#reloadRolesPosts").onclick=()=>loadRolesPosts().catch(e=>toast(e.message,false));$("#saveRolePost").onclick=()=>saveRolePost().catch(e=>toast(e.message,false));
$("#reloadBanners").onclick=()=>loadBanners().catch(e=>toast(e.message,false));$("#saveBanner").onclick=()=>saveBanner().catch(e=>toast(e.message,false));
$("#reloadGames").onclick=()=>loadGames().catch(e=>toast(e.message,false));$("#saveGameConfig").onclick=()=>saveGameConfig().catch(e=>toast(e.message,false));
$("#reloadPolicies").onclick=()=>loadPolicies().catch(e=>toast(e.message,false));$("#savePolicy").onclick=()=>savePolicy().catch(e=>toast(e.message,false));$("#reloadPricingOverrides").onclick=()=>loadPricingOverrides().catch(e=>toast(e.message,false));$("#savePricingOverride").onclick=()=>savePricingOverride().catch(e=>toast(e.message,false));$("#clearPricingOverride").onclick=clearPricingOverride;$("#pricingKind").onchange=()=>{updatePricingFreeState();loadPricingOverrides().catch(e=>toast(e.message,false));};

$("#searchEconomyUsers").onclick=()=>searchEconomyUsers().catch(e=>toast(e.message,false));$("#economyUserSearch").addEventListener("keydown",e=>{if(e.key==="Enter")searchEconomyUsers().catch(x=>toast(x.message,false));});$("#saveEconomyPublicId").onclick=()=>saveEconomyPublicId().catch(e=>toast(e.message,false));$("#saveCoinRate").onclick=()=>saveCoinRate().catch(e=>toast(e.message,false));
$("#vipRuleLevel").onchange=()=>{const rule=state.vipRules.find(x=>Number(x.level)===Number($("#vipRuleLevel").value));if(rule)fillVipRuleForm(rule);};$("#reloadVipRules").onclick=()=>loadVipRules().catch(e=>toast(e.message,false));$("#saveVipRule").onclick=()=>saveVipRule().catch(e=>toast(e.message,false));$("#resetVipRule").onclick=()=>resetVipRule().catch(e=>toast(e.message,false));
$("#reloadGifts").onclick=()=>loadGifts().catch(e=>toast(e.message,false));$("#saveGift").onclick=()=>saveGift().catch(e=>toast(e.message,false));$("#clearGift").onclick=clearGiftForm;
$("#assetKind").onchange=()=>{clearAssetForm();loadAssets().catch(e=>toast(e.message,false));};$("#reloadAssets").onclick=()=>loadAssets().catch(e=>toast(e.message,false));$("#saveAsset").onclick=()=>saveAsset().catch(e=>toast(e.message,false));$("#clearAsset").onclick=clearAssetForm;
$("#storeKind").onchange=()=>{clearStoreForm();loadStore().catch(e=>toast(e.message,false));};$("#reloadStore").onclick=()=>loadStore().catch(e=>toast(e.message,false));$("#saveStoreItem").onclick=()=>saveStoreItem().catch(e=>toast(e.message,false));$("#clearStoreItem").onclick=clearStoreForm;
$("#catalogKind").onchange=()=>{clearCatalogForm();loadCatalog().catch(e=>toast(e.message,false));};$("#reloadTreasury").onclick=()=>loadWallets().catch(e=>toast(e.message,false));$("#treasuryAdd").onclick=()=>treasuryAction("add").catch(e=>toast(e.message,false));$("#treasuryDeduct").onclick=()=>treasuryAction("deduct").catch(e=>toast(e.message,false));$("#treasurySend").onclick=()=>treasuryAction("send").catch(e=>toast(e.message,false));$("#saveCatalog").onclick=()=>saveCatalog().catch(e=>toast(e.message,false));$("#clearCatalog").onclick=clearCatalogForm;$("#reloadCatalog").onclick=()=>loadCatalog().catch(e=>toast(e.message,false));
$("#saveMaintenance").onclick=()=>saveMaintenance().catch(e=>toast(e.message,false));$("#saveAnnouncement").onclick=()=>saveAnnouncement().catch(e=>toast(e.message,false));$("#createStaff").onclick=()=>createStaff().catch(e=>toast(e.message,false));$("#reloadAudit").onclick=()=>loadAudit().catch(e=>toast(e.message,false));$("#exportAudit").onclick=exportAuditCsv;$("#clearAudit").onclick=()=>clearAudit().catch(e=>toast(e.message,false));
$("#clearPermissions").onclick=()=>{$$("#staffPermissions input").forEach(x=>x.checked=false);};
$("#supportStatus").onchange=()=>loadSupport().catch(e=>toast(e.message,false));$("#sendSupportReply").onclick=()=>sendSupportReply().catch(e=>toast(e.message,false));$("#closeSupportTicket").onclick=()=>closeSupportTicket().catch(e=>toast(e.message,false));

if(state.token){connect();}else{showApp(false);}

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
};
const viewTitles = {overview:"Dashboard",users:"Users",rooms:"Rooms",wallets:"Wallets / Treasury",catalog:"VIP / Gifts / Assets",settings:"Master Switches",announcements:"Announcements",staff:"Custom Panels",support:"VIP Support",audit:"Audit Log"};
const featureLabels = {"feature.voice":"Voice rooms","feature.gifts":"Gifts","feature.games":"Games","feature.messages":"Messages","feature.room_creation":"Room creation","feature.aladdin_lamp":"Aladdin's Lamp","feature.red_pocket":"Red Pocket / LP","feature.friends_call":"Friends call","feature.visitors":"Profile visitors"};
const staffPermissionOptions = [
  ["dashboard","Dashboard"],["users.read","Users: view/search"],["users.write","Users: edit profile/VIP/role"],["users.moderate","Users: ban/suspend/moderate"],["wallet.write","User wallets"],
  ["treasury.read","Owner Treasury: view"],["treasury.write","Owner Treasury: distribute"],["rooms.read","Rooms: view"],["rooms.write","Rooms: edit/remove"],
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
function can(p){return (!!state.actor&&(state.actor.permissions||[]).includes("*"))||(state.actor?.permissions||[]).includes(p);}
function empty(text){return `<div class="empty">${esc(text)}</div>`;}
function toast(message,good=true){const el=$("#toast");el.textContent=message;el.className="toast "+(good?"good":"bad");el.hidden=false;clearTimeout(toast.t);toast.t=setTimeout(()=>el.hidden=true,2600);}
function showApp(on){$("#loginCard").hidden=on;$("#workspace").hidden=!on;$("#sidebar").hidden=!on;}
function actorCard(){if(!state.actor)return;$("#actorCard").innerHTML=`<b>${esc(state.actor.name||"Authorized user")}</b><span>${esc(state.actor.role||"")}</span>`;}
function applyPermissions(){
  const map={overview:"dashboard",users:"users.read",rooms:"rooms.read",wallets:"treasury.read",catalog:"catalog.read",settings:"settings.read",announcements:"announcements.read",staff:"staff.read",support:"support.read",audit:"audit.read"};
  $$(".nav-btn").forEach(btn=>{const p=map[btn.dataset.view];btn.hidden=!!p&&!can(p);});
}
function setView(name){state.view=name;$("#viewTitle").textContent=viewTitles[name]||name;$$('.nav-btn').forEach(b=>b.classList.toggle('active',b.dataset.view===name));$$('.view').forEach(v=>v.classList.toggle('active',v.dataset.viewPanel===name));loadView(name).catch(e=>toast(e.message,false));}
async function loadView(name){if(name==="overview")return loadOverview();if(name==="users")return loadUsers();if(name==="rooms")return loadRooms();if(name==="wallets")return loadWallets();if(name==="catalog")return loadCatalog();if(name==="settings")return loadSettings();if(name==="announcements")return loadAnnouncements();if(name==="staff")return loadStaff();if(name==="support")return loadSupport();if(name==="audit")return loadAudit();}

async function connect(){
  state.token=$("#token").value.trim()||state.token;if(!state.token)return;
  $("#loginStatus").textContent="Checking protected access…";
  try{
    const session=await api("/api/owner/session");state.actor=session.actor;sessionStorage.setItem("dvxOwnerToken",state.token);showApp(true);actorCard();applyPermissions();$("#loginStatus").textContent="";const first=$(".nav-btn").find(b=>!b.hidden);if(!first)throw new Error("no_panel_permissions");setView(first.dataset.view);
  }catch(e){state.token="";state.actor=null;sessionStorage.removeItem("dvxOwnerToken");showApp(false);$("#loginStatus").textContent=e.message;}
}

async function loadOverview(){
  const d=await api("/api/owner/overview");state.actor=d.actor||state.actor;actorCard();
  const labels=[["Users",d.stats.users],["Rooms",d.stats.rooms],["Online",d.stats.online],["Owner Treasury",d.stats.treasury],["Coins",d.stats.coins],["Diamonds",d.stats.diamonds],["Banned",d.stats.banned],["Gift events",d.stats.gifts],["Game bets",d.stats.bets]];
  $("#stats").innerHTML=labels.map(([k,v])=>`<article class="stat-card"><span>${esc(k)}</span><strong>${num(v)}</strong></article>`).join("");
  $("#overviewRooms").innerHTML=(d.rooms||[]).length?(d.rooms||[]).slice(0,10).map(room=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(room.name)}</div><div class="item-meta">ID ${esc(room.id)} · ${num(room.online)} online · ${num(room.seat_count)} seats · ${esc(room.owner_name||room.owner_user_id)}</div></div><span class="pill ${Number(room.locked)?'banned':'active'}">${Number(room.locked)?'Locked':'Open'}</span></div></div>`).join(""):empty("No rooms yet");
  $("#overviewAudit").innerHTML=(d.audit||[]).length?(d.audit||[]).map(a=>`<div class="item-card"><div class="item-title">${esc(a.action.replaceAll('_',' '))}</div><div class="item-meta">${esc(a.target_type)} ${esc(a.target_id)} · ${esc(a.summary||'')}<br>${time(a.created_at)}</div></div>`).join(""):empty("No owner activity yet");
}

async function loadUsers(){if(!can("users.read"))return;const q=$("#userSearch").value.trim();const d=await api("/api/owner/users?q="+encodeURIComponent(q));$("#userList").innerHTML=(d.users||[]).length?d.users.map(u=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(u.display_name||'Unnamed user')} <span class="pill ${u.status==='banned'?'banned':'active'}">${esc(u.status)}</span></div><div class="item-meta">ID ${esc(u.id)} · ${esc(u.role)} · VIP ${num(u.vip_level)}<br>${num(u.coins)} coins · ${num(u.diamonds)} diamonds</div></div><div class="item-actions"><button class="secondary mini" data-user-open="${esc(u.id)}">Manage</button></div></div></div>`).join(""):empty("No matching users");$$('[data-user-open]').forEach(b=>b.onclick=()=>openUser(b.dataset.userOpen));}
async function openUser(id){const d=await api("/api/owner/users/"+encodeURIComponent(id));const u=d.user;state.selectedUser=u;$("#userEditor").hidden=false;$("#userEditorTitle").textContent=u.display_name||"Manage user";$("#userMeta").textContent=`ID ${u.id} · Updated ${time(u.updated_at)}`;$("#editUserName").value=u.display_name||"";$("#editUserRole").value=u.role||"user";$("#editVip").value=u.vip_level||0;$("#editStatus").value=u.status||"active";$("#editNote").value=u.moderation_note||"";$("#walletBalance").textContent=`Current balance: ${num(u.coins)} coins · ${num(u.diamonds)} diamonds`;renderLedger(u.wallet_ledger||[]);const roleType=(u.role==="coin_seller"||u.role==="merchant")?u.role:"";$("#roleWalletType").value=roleType;const rw=roleType?u.role_wallets?.[roleType]:null;$("#roleWalletBalance").textContent=rw?`${roleType.replaceAll('_',' ')} balance: ${num(rw.balance_coins)} coins`:"Select Coin Seller or Merchant wallet to manage a dedicated role balance.";$("#roleCoinDelta").value="";$("#userEditor").scrollIntoView({behavior:"smooth",block:"start"});}
function renderLedger(rows){$("#walletLedger").innerHTML=rows.length?`<div class="small-table">${rows.map(r=>`<div class="ledger-row"><span>${time(r.created_at)}</span><span>${esc(r.kind.replaceAll('_',' '))}</span><b>${Number(r.amount)>0?'+':''}${num(r.amount)} → ${num(r.balance_after)}</b></div>`).join("")}</div>`:empty("No coin ledger entries");}
async function saveUserProfile(){if(!state.selectedUser)return;await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/profile`,{method:"POST",body:JSON.stringify({display_name:$("#editUserName").value,role:$("#editUserRole").value,vip_level:Number($("#editVip").value||0)})});toast("User profile saved");await openUser(state.selectedUser.id);await loadUsers();}
async function saveModeration(){if(!state.selectedUser)return;await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/moderation`,{method:"POST",body:JSON.stringify({status:$("#editStatus").value,note:$("#editNote").value})});toast("Moderation status saved");await openUser(state.selectedUser.id);await loadUsers();}
async function applyWallet(){if(!state.selectedUser)return;const coin=Number($("#coinDelta").value||0),diamond=Number($("#diamondDelta").value||0);if(!coin&&!diamond)return toast("Enter a coin or diamond change",false);await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/wallet`,{method:"POST",body:JSON.stringify({coin_delta:coin,diamond_delta:diamond})});$("#coinDelta").value="";$("#diamondDelta").value="";toast("Wallet adjustment applied");await openUser(state.selectedUser.id);await loadUsers();}
async function applyRoleWallet(){if(!state.selectedUser)return;const walletType=$("#roleWalletType").value;const delta=Number($("#roleCoinDelta").value||0);if(!walletType)return toast("Select Coin Seller or Merchant wallet",false);if(!delta)return toast("Enter a role-wallet coin change",false);await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/wallet`,{method:"POST",body:JSON.stringify({role_wallet_type:walletType,role_coin_delta:delta})});toast("Role wallet adjustment applied");await openUser(state.selectedUser.id);await loadUsers();}

async function loadRooms(){if(!can("rooms.read"))return;const q=$("#roomSearch").value.trim();const d=await api("/api/owner/rooms?q="+encodeURIComponent(q));$("#roomList").innerHTML=(d.rooms||[]).length?d.rooms.map(r=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(r.name)} <span class="pill ${Number(r.locked)?'banned':'active'}">${Number(r.locked)?'Locked':'Open'}</span></div><div class="item-meta">ID ${esc(r.id)} · Owner ${esc(r.owner_name||r.owner_user_id)} · ${num(r.online)} online · ${num(r.seat_count)} seats</div></div><div class="item-actions"><button class="secondary mini" data-room-lock="${esc(r.id)}" data-locked="${Number(r.locked)}">${Number(r.locked)?'Unlock':'Lock'}</button><button class="secondary mini" data-room-edit="${esc(r.id)}" data-name="${esc(r.name)}" data-seats="${num(r.seat_count)}">Edit</button><button class="danger mini" data-room-delete="${esc(r.id)}">Remove</button></div></div></div>`).join(""):empty("No matching rooms");
  $$('[data-room-lock]').forEach(b=>b.onclick=async()=>{await api('/api/owner/rooms/'+encodeURIComponent(b.dataset.roomLock),{method:'POST',body:JSON.stringify({locked:!Number(b.dataset.locked)})});toast('Room lock updated');loadRooms();});
  $$('[data-room-edit]').forEach(b=>b.onclick=async()=>{const name=prompt('Room name',b.dataset.name);if(name===null)return;const seats=prompt('Seat count (8–42)',b.dataset.seats);if(seats===null)return;await api('/api/owner/rooms/'+encodeURIComponent(b.dataset.roomEdit),{method:'POST',body:JSON.stringify({name,seat_count:Number(seats)})});toast('Room updated');loadRooms();});
  $$('[data-room-delete]').forEach(b=>b.onclick=async()=>{if(!confirm('Remove this room? This deletes the room and its current room records.'))return;await api('/api/owner/rooms/'+encodeURIComponent(b.dataset.roomDelete),{method:'DELETE'});toast('Room removed');loadRooms();});
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
async function createStaff(){if(!can('staff.write'))return toast('Only owner or authorized super admin can create staff access',false);const name=$("#staffName").value.trim();if(!name)return toast('Enter staff name',false);const permissions=$("#staffPermissions input:checked").map(x=>x.value);const payload={display_name:name,role:$("#staffRole").value};if(permissions.length)payload.permissions=permissions;const d=await api('/api/owner/staff',{method:'POST',body:JSON.stringify(payload)});$("#staffName").value='';$("#staffPermissions input").forEach(x=>x.checked=false);const box=$("#newStaffToken");box.hidden=false;box.innerHTML=`<b>One-time access token</b><br>${esc(d.token)}<br><small>Save it securely now. It cannot be viewed again from this panel.</small>`;toast('Custom panel access created');loadStaff();}

async function loadAudit(){if(!can('audit.read'))return;const d=await api('/api/owner/audit?limit=200');$("#auditList").innerHTML=(d.audit||[]).length?`<div class="small-table">${d.audit.map(a=>`<div class="audit-row"><span>${time(a.created_at)}</span><span><b>${esc(a.action.replaceAll('_',' '))}</b><br><span class="muted">${esc(a.actor_type)} ${esc(a.actor_id)} → ${esc(a.target_type)} ${esc(a.target_id)}${a.summary?' · '+esc(a.summary):''}</span></span></div>`).join('')}</div>`:empty('No audit records yet');}

$("#connect").onclick=connect;$("#token").addEventListener('keydown',e=>{if(e.key==='Enter')connect();});
$("#logout").onclick=()=>{state.token='';state.actor=null;sessionStorage.removeItem('dvxOwnerToken');showApp(false);$("#token").value='';};
$('.nav-btn').forEach(b=>b.onclick=()=>setView(b.dataset.view));
$('[data-catalog-shortcut]').forEach(b=>b.onclick=()=>{$("#catalogKind").value=b.dataset.catalogShortcut;clearCatalogForm();loadCatalog().catch(e=>toast(e.message,false));});
$("#refreshCurrent").onclick=()=>loadView(state.view).catch(e=>toast(e.message,false));
$("#searchUsers").onclick=()=>loadUsers().catch(e=>toast(e.message,false));$("#userSearch").addEventListener('keydown',e=>{if(e.key==='Enter')loadUsers().catch(x=>toast(x.message,false));});
$("#closeUser").onclick=()=>{$("#userEditor").hidden=true;state.selectedUser=null;};$("#saveUserProfile").onclick=()=>saveUserProfile().catch(e=>toast(e.message,false));$("#saveModeration").onclick=()=>saveModeration().catch(e=>toast(e.message,false));$("#applyWallet").onclick=()=>applyWallet().catch(e=>toast(e.message,false));$("#applyRoleWallet").onclick=()=>applyRoleWallet().catch(e=>toast(e.message,false));$("#roleWalletType").onchange=()=>{$("#roleWalletBalance").textContent="Selected "+($("#roleWalletType").value||"role")+" wallet. Enter a coin change and apply.";};
$("#searchRooms").onclick=()=>loadRooms().catch(e=>toast(e.message,false));$("#roomSearch").addEventListener('keydown',e=>{if(e.key==='Enter')loadRooms().catch(x=>toast(x.message,false));});
$("#catalogKind").onchange=()=>{clearCatalogForm();loadCatalog().catch(e=>toast(e.message,false));};$("#reloadTreasury").onclick=()=>loadWallets().catch(e=>toast(e.message,false));$("#treasuryAdd").onclick=()=>treasuryAction("add").catch(e=>toast(e.message,false));$("#treasuryDeduct").onclick=()=>treasuryAction("deduct").catch(e=>toast(e.message,false));$("#treasurySend").onclick=()=>treasuryAction("send").catch(e=>toast(e.message,false));$("#saveCatalog").onclick=()=>saveCatalog().catch(e=>toast(e.message,false));$("#clearCatalog").onclick=clearCatalogForm;$("#reloadCatalog").onclick=()=>loadCatalog().catch(e=>toast(e.message,false));
$("#saveMaintenance").onclick=()=>saveMaintenance().catch(e=>toast(e.message,false));$("#saveAnnouncement").onclick=()=>saveAnnouncement().catch(e=>toast(e.message,false));$("#createStaff").onclick=()=>createStaff().catch(e=>toast(e.message,false));$("#reloadAudit").onclick=()=>loadAudit().catch(e=>toast(e.message,false));
$("#clearPermissions").onclick=()=>{$("#staffPermissions input").forEach(x=>x.checked=false);};
$("#supportStatus").onchange=()=>loadSupport().catch(e=>toast(e.message,false));$("#sendSupportReply").onclick=()=>sendSupportReply().catch(e=>toast(e.message,false));$("#closeSupportTicket").onclick=()=>closeSupportTicket().catch(e=>toast(e.message,false));

if(state.token){connect();}else{showApp(false);}

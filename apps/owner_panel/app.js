const $ = (s) => document.querySelector(s);
const $ = (s) => [...document.querySelectorAll(s)];
const initialLoginMode = new URLSearchParams(window.location.search).get("staff")==="1" ? "staff" : "owner";
const state = {
  token: sessionStorage.getItem("dvxOwnerToken") || "",
  actor: null,
  loginMode: initialLoginMode,
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
  themeCropImage: null,
  themeCropObjectUrl: null,
  vipRules: [],
  giftItems: [],
  assetItems: [],
  pricingOverrides: [],
  auditRows: [],
  ownerMessageConversations: [],
  ownerMessageThreadOtherId: null,
  staffEditingId: null,
};
const viewTitles = {overview:"Dashboard",users:"Users",notifications:"Notifications",messaging:"Messages & Tags",rooms:"Rooms",roles:"Roles / Posts",banners:"Banners",games:"Games",policies:"Policies",wallets:"Wallets / Treasury",economy:"Unique ID / Coin Rate",vip:"VIP Manager",gifts:"Gifts",assets:"Entries / Frames",store:"App Store",catalog:"Advanced Catalog",settings:"Master Switches",announcements:"Announcements",staff:"Custom Panels",support:"VIP Support",audit:"Audit Log"};
const featureLabels = {"feature.voice":"Voice rooms","feature.gifts":"Gifts","feature.games":"Games","feature.messages":"Messages","feature.room_creation":"Room creation","feature.aladdin_lamp":"Aladdin's Lamp","feature.red_pocket":"Red Pocket / LP","feature.friends_call":"Friends call","feature.visitors":"Profile visitors"};
const staffPermissionOptions = [
  ["dashboard.view","Dashboard · view"],

  ["users.search","Users · search/list"],
  ["users.detail","Users · open Full ID View"],
  ["users.name.edit","Users · change display name"],
  ["users.role.edit","Users · change role"],
  ["users.vip.edit","Users · change VIP level"],
  ["users.public_id.change","Users · change 7-digit Public ID"],
  ["users.moderation","Users · ban/suspend/moderation"],
  ["users.wallet.adjust","Users · normal wallet coin/diamond adjustment"],
  ["users.role_wallet.adjust","Users · Coin Seller/Merchant wallet balance"],
  ["users.role_wallet.ban","Users · Coin Seller/Merchant wallet ban/unban"],
  ["users.override.invisible","Users · Invisible ID"],
  ["users.override.lock_bypass","Users · locked-room bypass"],
  ["users.wallet.ban","Users · normal wallet ban/unban"],
  ["users.wallet.freeze","Users · wallet security freeze"],
  ["users.device.ban","Users · device ban/unban"],

  ["treasury.view","Treasury · view balance/ledger"],
  ["treasury.send","Treasury · send coins to user"],
  ["economy.view","Economy · view coin rate"],
  ["economy.coin_rate.edit","Economy · change coin rate"],

  ["messaging.view","Official messaging · open page"],
  ["messaging.send.selected","Official messaging · send to selected users"],
  ["messaging.send.all","Official messaging · send to all users"],
  ["tags.view","Tags / V Official · view"],
  ["tags.apply","Tags / V Official · apply"],
  ["tags.remove","Tags / V Official · remove"],

  ["rooms.view","Rooms · search/list"],
  ["rooms.edit","Rooms · edit name/seats"],
  ["rooms.lock","Rooms · lock/unlock"],
  ["rooms.delete","Rooms · remove room"],
  ["rooms.ban","Rooms · ban/unban room"],
  ["rooms.live","Rooms · live users/seats investigation"],
  ["rooms.media","Rooms · DP/background override"],
  ["rooms.theme","Rooms · per-room theme override"],
  ["themes.global.view","Room Themes · view global themes"],
  ["themes.global.save","Room Themes · add/edit global theme"],
  ["themes.global.remove","Room Themes · remove global theme"],

  ["roles.view","Roles/Posts · view"],
  ["roles.save","Roles/Posts · add/edit"],
  ["roles.delete","Roles/Posts · delete"],
  ["banners.view","Banners · view"],
  ["banners.save","Banners · add/edit"],
  ["banners.delete","Banners · delete"],
  ["games.view","Games · view/stats/investigation"],
  ["games.configure","Games · enable/disable/bet limits"],

  ["policies.view","Policies · view"],
  ["policies.save","Policies · add/edit"],
  ["policies.delete","Policies · delete"],
  ["pricing.view","Per-user pricing · view"],
  ["pricing.save","Per-user pricing · add/edit"],
  ["pricing.delete","Per-user pricing · delete"],

  ["vip.view","VIP Manager · view VIP1–VIP18 rules"],
  ["vip.save","VIP Manager · edit rule"],
  ["vip.reset","VIP Manager · reset rule"],
  ["gifts.view","Gifts · view"],
  ["gifts.save","Gifts · add/edit"],
  ["gifts.remove","Gifts · remove"],
  ["assets.view","Entries/Frames/Assets · view"],
  ["assets.save","Entries/Frames/Assets · add/edit"],
  ["assets.remove","Entries/Frames/Assets · remove"],
  ["store.view","App Store · view"],
  ["store.save","App Store · add/edit"],
  ["store.remove","App Store · remove"],
  ["catalog.view","Advanced Catalog · view"],
  ["catalog.save","Advanced Catalog · add/edit"],
  ["catalog.remove","Advanced Catalog · delete"],

  ["settings.view","Master Switches · view"],
  ["settings.feature.voice","Master Switch · Voice rooms"],
  ["settings.feature.gifts","Master Switch · Gifts"],
  ["settings.feature.games","Master Switch · Games"],
  ["settings.feature.messages","Master Switch · Messages"],
  ["settings.feature.room_creation","Master Switch · Room creation"],
  ["settings.feature.aladdin_lamp","Master Switch · Aladdin's Lamp"],
  ["settings.feature.red_pocket","Master Switch · Red Pocket / LP"],
  ["settings.feature.friends_call","Master Switch · Friends call"],
  ["settings.feature.visitors","Master Switch · Profile visitors"],
  ["settings.maintenance","Maintenance · enable/message"],

  ["announcements.view","Announcements · view"],
  ["announcements.save","Announcements · add/edit"],
  ["announcements.delete","Announcements · delete"],

  ["support.view","VIP Support · view tickets/threads"],
  ["support.reply","VIP Support · reply"],
  ["support.close","VIP Support · close ticket"],

  ["staff.view","Custom Staff Panels · view"],
  ["staff.create","Custom Staff Panels · create"],
  ["staff.permissions.edit","Custom Staff Panels · edit name/role/permissions"],
  ["staff.toggle","Custom Staff Panels · enable/disable"],
  ["staff.delete","Custom Staff Panels · delete"],

  ["audit.view","Audit · view own panel audit"],
  ["audit.export","Audit · export CSV"]
];

const frontendPermissionAliases = {
  "dashboard.view":["dashboard"],
  "users.search":["users.read"],"users.detail":["users.read"],
  "users.name.edit":["users.write"],"users.role.edit":["users.write"],"users.vip.edit":["users.write"],"users.public_id.change":["users.write"],
  "users.moderation":["users.moderate","users.write"],
  "users.wallet.adjust":["wallet.write"],"users.role_wallet.adjust":["wallet.write"],"users.role_wallet.ban":["wallet.write"],
  "users.override.invisible":["users.override"],"users.override.lock_bypass":["users.override"],
  "users.wallet.ban":["users.override"],"users.wallet.freeze":["users.override","wallet.freeze"],"users.device.ban":["users.device"],
  "treasury.view":["treasury.read"],"treasury.send":["treasury.write"],
  "economy.view":["economy.read"],"economy.coin_rate.edit":["economy.write"],
  "messaging.view":["messaging.read"],"messaging.send.selected":["messaging.write"],"messaging.send.all":["messaging.write"],
  "tags.view":["messaging.read"],"tags.apply":["tags.write"],"tags.remove":["tags.write"],
  "rooms.view":["rooms.read"],"rooms.edit":["rooms.write"],"rooms.lock":["rooms.write"],"rooms.delete":["rooms.write"],"rooms.ban":["rooms.write"],
  "rooms.live":["rooms.live"],"rooms.media":["rooms.media"],"rooms.theme":["rooms.theme"],
  "themes.global.view":["catalog.read"],"themes.global.save":["catalog.write"],"themes.global.remove":["catalog.write"],
  "roles.view":["roles.read"],"roles.save":["roles.write"],"roles.delete":["roles.write"],
  "banners.view":["banners.read"],"banners.save":["banners.write"],"banners.delete":["banners.write"],
  "games.view":["games.read"],"games.configure":["games.write"],
  "policies.view":["policies.read"],"policies.save":["policies.write"],"policies.delete":["policies.write"],
  "pricing.view":["policies.read"],"pricing.save":["policies.write"],"pricing.delete":["policies.write"],
  "vip.view":["catalog.read"],"vip.save":["catalog.write"],"vip.reset":["catalog.write"],
  "gifts.view":["catalog.read"],"gifts.save":["catalog.write"],"gifts.remove":["catalog.write"],
  "assets.view":["catalog.read"],"assets.save":["catalog.write"],"assets.remove":["catalog.write"],
  "store.view":["catalog.read"],"store.save":["catalog.write"],"store.remove":["catalog.write"],
  "catalog.view":["catalog.read"],"catalog.save":["catalog.write"],"catalog.remove":["catalog.write"],
  "settings.view":["settings.read"],
  "settings.feature.voice":["settings.write"],"settings.feature.gifts":["settings.write"],"settings.feature.games":["settings.write"],
  "settings.feature.messages":["settings.write"],"settings.feature.room_creation":["settings.write"],"settings.feature.aladdin_lamp":["settings.write"],
  "settings.feature.red_pocket":["settings.write"],"settings.feature.friends_call":["settings.write"],"settings.feature.visitors":["settings.write"],
  "settings.maintenance":["settings.write"],
  "announcements.view":["announcements.read"],"announcements.save":["announcements.write"],"announcements.delete":["announcements.write"],
  "support.view":["support.read"],"support.reply":["support.write"],"support.close":["support.write"],
  "staff.view":["staff.read"],"staff.create":["staff.write"],"staff.permissions.edit":["staff.write"],"staff.toggle":["staff.write"],"staff.delete":["staff.write"],
  "audit.view":["audit.read"],"audit.export":["audit.read"]
};

const viewPermissionMap = {
  overview:["dashboard.view"],
  users:["users.search","users.detail","users.name.edit","users.role.edit","users.vip.edit","users.public_id.change","users.moderation","users.wallet.adjust","users.role_wallet.adjust","users.role_wallet.ban","users.override.invisible","users.override.lock_bypass","users.wallet.ban","users.wallet.freeze","users.device.ban"],
  notifications:[],
  messaging:["messaging.view","messaging.send.selected","messaging.send.all","tags.view","tags.apply","tags.remove"],
  rooms:["rooms.view","rooms.edit","rooms.lock","rooms.delete","rooms.ban","rooms.live","rooms.media","rooms.theme","themes.global.view","themes.global.save","themes.global.remove"],
  roles:["roles.view","roles.save","roles.delete"],
  banners:["banners.view","banners.save","banners.delete"],
  games:["games.view","games.configure"],
  policies:["policies.view","policies.save","policies.delete","pricing.view","pricing.save","pricing.delete"],
  wallets:["treasury.view","treasury.send"],
  economy:["economy.view","economy.coin_rate.edit","users.search","users.detail","users.public_id.change"],
  vip:["vip.view","vip.save","vip.reset"],
  gifts:["gifts.view","gifts.save","gifts.remove"],
  assets:["assets.view","assets.save","assets.remove"],
  store:["store.view","store.save","store.remove"],
  catalog:["catalog.view","catalog.save","catalog.remove"],
  settings:["settings.view","settings.feature.voice","settings.feature.gifts","settings.feature.games","settings.feature.messages","settings.feature.room_creation","settings.feature.aladdin_lamp","settings.feature.red_pocket","settings.feature.friends_call","settings.feature.visitors","settings.maintenance"],
  announcements:["announcements.view","announcements.save","announcements.delete"],
  staff:["staff.view","staff.create","staff.permissions.edit","staff.toggle","staff.delete"],
  support:["support.view","support.reply","support.close"],
  audit:["audit.view","audit.export"]
};

const selectorPermissionRules = [
  ["#userSearch",["users.search"],"self"],["#searchUsers",["users.search"],"self"],
  ["#editUserName",["users.name.edit"],"label"],["#editUserRole",["users.role.edit"],"label"],["#editVip",["users.vip.edit"],"label"],
  ["#saveUserProfile",["users.name.edit","users.role.edit","users.vip.edit"],"self"],
  ["#editStatus",["users.moderation"],"label"],["#editNote",["users.moderation"],"label"],["#saveModeration",["users.moderation"],"self"],
  ["#editPublicId",["users.public_id.change"],"label"],["#savePublicId",["users.public_id.change"],"self"],
  ["#coinDelta",["users.wallet.adjust"],"label"],["#diamondDelta",["users.wallet.adjust"],"label"],["#applyWallet",["users.wallet.adjust"],"self"],
  ["#roleWalletType",["users.role_wallet.adjust","users.role_wallet.ban"],"label"],["#roleCoinDelta",["users.role_wallet.adjust"],"label"],
  ["#roleWalletBanned",["users.role_wallet.ban"],"label"],["#applyRoleWallet",["users.role_wallet.adjust","users.role_wallet.ban"],"self"],
  ["#userInvisibleId",["users.override.invisible"],"label"],["#userLockedBypass",["users.override.lock_bypass"],"label"],
  ["#userWalletBanned",["users.wallet.ban"],"label"],["#userWalletFrozen",["users.wallet.freeze"],"label"],
  ["#saveUserOverrides",["users.override.invisible","users.override.lock_bypass","users.wallet.ban","users.wallet.freeze"],"self"],

  ["#roomSearch",["rooms.view"],"self"],["#searchRooms",["rooms.view"],"self"],
  ["#ownerRoomDpKey",["rooms.media"],"label"],["#ownerRoomBackgroundKey",["rooms.media"],"label"],["#saveOwnerRoomMedia",["rooms.media"],"self"],
  ["#ownerRoomThemeId",["rooms.theme"],"label"],["#saveOwnerRoomTheme",["rooms.theme"],"self"],
  ["#reloadGlobalThemes",["themes.global.view"],"self"],
  ["#globalThemeId",["themes.global.save"],"label"],["#globalThemeName",["themes.global.save"],"label"],["#globalThemeFile",["themes.global.save"],"label"],
  ["#globalThemeWidth",["themes.global.save"],"label"],["#globalThemeHeight",["themes.global.save"],"label"],["#globalThemeZoom",["themes.global.save"],"label"],
  ["#globalThemeCropX",["themes.global.save"],"label"],["#globalThemeCropY",["themes.global.save"],"label"],["#globalThemeAsset",["themes.global.save"],"label"],
  ["#globalThemeCropCanvas",["themes.global.save"],"self"],["#resetGlobalThemeCrop",["themes.global.save"],"self"],["#uploadGlobalThemeImage",["themes.global.save"],"self"],
  ["#globalThemeStart",["themes.global.save"],"label"],["#globalThemeEnd",["themes.global.save"],"label"],["#globalThemePermanent",["themes.global.save"],"label"],
  ["#globalThemeEnabled",["themes.global.save"],"label"],["#saveGlobalTheme",["themes.global.save"],"self"],["#clearGlobalTheme",["themes.global.save"],"self"],

  ["#messageUserSearch",["users.search"],"self"],["#searchMessageUsers",["users.search"],"self"],
  ["#officialMessageBody",["messaging.send.selected","messaging.send.all"],"label"],["#sendOfficialSelected",["messaging.send.selected"],"self"],["#sendOfficialAll",["messaging.send.all"],"self"],
  ["#ownerTagName",["tags.apply"],"label"],["#ownerTagColor",["tags.apply"],"label"],["#ownerTagDesignation",["tags.apply"],"label"],["#ownerTagKind",["tags.apply"],"label"],["#applyOwnerTag",["tags.apply"],"self"],

  ["#rolePostKind",["roles.view","roles.save","roles.delete"],"label"],["#rolePostId",["roles.save"],"label"],["#rolePostName",["roles.save"],"label"],
  ["#rolePostOrder",["roles.save"],"label"],["#rolePostEnabled",["roles.save"],"label"],["#rolePostDetails",["roles.save"],"label"],["#saveRolePost",["roles.save"],"self"],["#reloadRolesPosts",["roles.view"],"self"],

  ["#bannerId",["banners.save"],"label"],["#bannerName",["banners.save"],"label"],["#bannerAsset",["banners.save"],"label"],["#bannerLink",["banners.save"],"label"],
  ["#bannerStart",["banners.save"],"label"],["#bannerEnd",["banners.save"],"label"],["#bannerEnabled",["banners.save"],"label"],["#saveBanner",["banners.save"],"self"],["#reloadBanners",["banners.view"],"self"],

  ["#gameConfigId",["games.configure"],"label"],["#gameConfigName",["games.configure"],"label"],["#gameMinBet",["games.configure"],"label"],["#gameMaxBet",["games.configure"],"label"],
  ["#gameEnabled",["games.configure"],"label"],["#saveGameConfig",["games.configure"],"self"],["#reloadGames",["games.view"],"self"],["#gameInvestigationUser",["games.view"],"label"],["#loadGameInvestigation",["games.view"],"self"],

  ["#policyKey",["policies.save"],"label"],["#policyValue",["policies.save"],"label"],["#savePolicy",["policies.save"],"self"],["#reloadPolicies",["policies.view"],"self"],
  ["#pricingUserId",["pricing.view","pricing.save"],"label"],["#pricingKind",["pricing.view","pricing.save"],"label"],["#pricingItemId",["pricing.save"],"label"],
  ["#pricingPrice",["pricing.save"],"label"],["#pricingDuration",["pricing.save"],"label"],["#pricingFree",["pricing.save"],"label"],["#savePricingOverride",["pricing.save"],"self"],
  ["#clearPricingOverride",["pricing.save"],"self"],["#reloadPricingOverrides",["pricing.view"],"self"],

  ["#treasuryAmount",["treasury.send"],"label"],["#treasuryUserId",["treasury.send"],"label"],["#treasuryNote",["treasury.send"],"label"],["#treasurySend",["treasury.send"],"self"],["#reloadTreasury",["treasury.view"],"self"],

  ["#economyUserSearch",["users.search"],"self"],["#searchEconomyUsers",["users.search"],"self"],["#economyPublicId",["users.public_id.change"],"label"],["#saveEconomyPublicId",["users.public_id.change"],"self"],
  ["#coinRateCoinsPerUsd",["economy.coin_rate.edit"],"label"],["#saveCoinRate",["economy.coin_rate.edit"],"self"],

  ["#reloadVipRules",["vip.view"],"self"],["#vipRuleLevel",["vip.save"],"label"],["#vipRuleName",["vip.save"],"label"],["#vipRuleUpgradeExp",["vip.save"],"label"],
  ["#vipRuleMaintainExp",["vip.save"],"label"],["#vipRuleValidityDays",["vip.save"],"label"],["#vipRuleEntryId",["vip.save"],"label"],["#vipRuleFrameId",["vip.save"],"label"],
  ["#vipRuleEnabled",["vip.save"],"label"],["#saveVipRule",["vip.save"],"self"],["#resetVipRule",["vip.reset"],"self"],

  ["#reloadGifts",["gifts.view"],"self"],["#giftId",["gifts.save"],"label"],["#giftName",["gifts.save"],"label"],["#giftPrice",["gifts.save"],"label"],["#giftVip",["gifts.save"],"label"],
  ["#giftEmoji",["gifts.save"],"label"],["#giftCategory",["gifts.save"],"label"],["#giftAsset",["gifts.save"],"label"],["#giftVideoFile",["gifts.save"],"label"],["#giftVideoKey",["gifts.save"],"label"],["#uploadGiftVideo",["gifts.save"],"self"],["#removeGiftVideo",["gifts.save"],"self"],["#giftOrder",["gifts.save"],"label"],["#giftStart",["gifts.save"],"label"],
  ["#giftEnd",["gifts.save"],"label"],["#giftEnabled",["gifts.save"],"label"],["#giftDescription",["gifts.save"],"label"],["#saveGift",["gifts.save"],"self"],["#clearGift",["gifts.save"],"self"],

  ["#reloadAssets",["assets.view"],"self"],["#assetKind",["assets.view","assets.save","assets.remove"],"label"],["#assetId",["assets.save"],"label"],["#assetName",["assets.save"],"label"],
  ["#assetPrice",["assets.save"],"label"],["#assetVip",["assets.save"],"label"],["#assetDuration",["assets.save"],"label"],["#assetTier",["assets.save"],"label"],["#assetOrder",["assets.save"],"label"],
  ["#assetFileKey",["assets.save"],"label"],["#assetStart",["assets.save"],"label"],["#assetEnd",["assets.save"],"label"],["#assetEnabled",["assets.save"],"label"],["#assetDescription",["assets.save"],"label"],
  ["#saveAsset",["assets.save"],"self"],["#clearAsset",["assets.save"],"self"],

  ["#reloadStore",["store.view"],"self"],["#storeKind",["store.view","store.save","store.remove"],"label"],["#storeId",["store.save"],"label"],["#storeName",["store.save"],"label"],
  ["#storePrice",["store.save"],"label"],["#storeVip",["store.save"],"label"],["#storeDuration",["store.save"],"label"],["#storeTier",["store.save"],"label"],["#storeOrder",["store.save"],"label"],
  ["#storeAsset",["store.save"],"label"],["#storeEmoji",["store.save"],"label"],["#storeCategory",["store.save"],"label"],["#storeEnabled",["store.save"],"label"],["#storeDescription",["store.save"],"label"],
  ["#saveStoreItem",["store.save"],"self"],["#clearStoreItem",["store.save"],"self"],

  ["#catalogKind",["catalog.view","catalog.save","catalog.remove"],"label"],["#catalogId",["catalog.save"],"label"],["#catalogName",["catalog.save"],"label"],["#catalogPrice",["catalog.save"],"label"],
  ["#catalogOrder",["catalog.save"],"label"],["#catalogAsset",["catalog.save"],"label"],["#catalogLevel",["catalog.save"],"label"],["#catalogEnabled",["catalog.save"],"label"],["#catalogDescription",["catalog.save"],"label"],
  ["#saveCatalog",["catalog.save"],"self"],["#clearCatalog",["catalog.save"],"self"],["#reloadCatalog",["catalog.view"],"self"],

  ["#maintenanceEnabled",["settings.maintenance"],"label"],["#maintenanceMessage",["settings.maintenance"],"label"],["#saveMaintenance",["settings.maintenance"],"self"],

  ["#announcementTitle",["announcements.save"],"label"],["#announcementEnabled",["announcements.save"],"label"],["#announcementStart",["announcements.save"],"label"],
  ["#announcementEnd",["announcements.save"],"label"],["#announcementBody",["announcements.save"],"label"],["#saveAnnouncement",["announcements.save"],"self"],["#clearAnnouncement",["announcements.save"],"self"],

  ["#supportStatus",["support.view"],"label"],["#supportReply",["support.reply"],"label"],["#sendSupportReply",["support.reply"],"self"],["#closeSupportTicket",["support.close"],"self"],

  ["#staffName",["staff.create","staff.permissions.edit"],"label"],["#staffRole",["staff.create","staff.permissions.edit"],"label"],["#clearPermissions",["staff.create","staff.permissions.edit"],"self"],
  ["#createStaff",["staff.create","staff.permissions.edit"],"self"],["#cancelStaffEdit",["staff.permissions.edit"],"self"],

  ["#reloadAudit",["audit.view"],"self"],["#exportAudit",["audit.export"],"self"]
];

const dynamicPermissionRules = [
  ["[data-user-open]",["users.detail"]],
  ["[data-device-key]",["users.device.ban"]],
  ["[data-room-live]",["rooms.live"]],["[data-room-ban]",["rooms.ban"]],["[data-room-lock]",["rooms.lock"]],["[data-room-edit]",["rooms.edit"]],["[data-room-delete]",["rooms.delete"]],
  ["[data-global-theme-edit]",["themes.global.save"]],["[data-global-theme-remove]",["themes.global.remove"]],
  ["[data-tag-user]",["tags.remove"]],
  ["[data-role-post-edit]",["roles.save"]],["[data-role-post-delete]",["roles.delete"]],
  ["[data-banner-edit]",["banners.save"]],["[data-banner-delete]",["banners.delete"]],
  ["[data-game-edit]",["games.configure"]],
  ["[data-policy-edit]",["policies.save"]],["[data-policy-delete]",["policies.delete"]],
  ["[data-pricing-edit-user]",["pricing.save"]],["[data-pricing-delete-user]",["pricing.delete"]],
  ["[data-economy-user]",["users.detail"]],
  ["[data-vip-rule-edit]",["vip.save"]],
  ["[data-gift-edit]",["gifts.save"]],["[data-gift-remove]",["gifts.remove"]],
  ["[data-asset-edit]",["assets.save"]],["[data-asset-remove]",["assets.remove"]],
  ["[data-store-edit]",["store.save"]],["[data-store-remove]",["store.remove"]],
  ["[data-catalog-edit]",["catalog.save"]],["[data-catalog-delete]",["catalog.remove"]],
  ["[data-ann-edit]",["announcements.save"]],["[data-ann-delete]",["announcements.delete"]],
  ["[data-staff-edit]",["staff.permissions.edit"]],["[data-staff-toggle]",["staff.toggle"]],["[data-staff-delete]",["staff.delete"]],
  ["[data-ticket-open]",["support.view"]]
];

function authHeaders(){return {authorization:"Bearer "+state.token,"content-type":"application/json"};}
async function api(path, options={}){
  const res=await fetch(path,{...options,headers:{...authHeaders(),...(options.headers||{})}});
  const data=await res.json().catch(()=>({ok:false,error:"invalid_response"}));
  if(!res.ok) throw new Error(data.error||("HTTP "+res.status));
  return data;
}
async function apiBlob(path){
  const res=await fetch(path,{headers:{authorization:"Bearer "+state.token}});
  if(!res.ok){
    const data=await res.json().catch(()=>({error:"HTTP "+res.status}));
    throw new Error(data.error||("HTTP "+res.status));
  }
  return res.blob();
}
function esc(v){return String(v??"").replace(/[&<>'"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;","\"":"&quot;"}[c]));}
function num(v){return Number(v||0).toLocaleString();}
function time(v){if(!v)return "—";return new Date(Number(v)).toLocaleString();}
function duration(v){const ms=Math.max(0,Number(v||0));const total=Math.floor(ms/1000);const h=Math.floor(total/3600);const m=Math.floor((total%3600)/60);const sec=total%60;return h>0?`${h}h ${m}m`:m>0?`${m}m ${sec}s`:`${sec}s`;}
function can(p){
  if(!state.actor)return false;
  const permissions=state.actor.permissions||[];
  if(state.actor.type==="owner"||permissions.includes("*"))return true;
  if(permissions.includes(p))return true;
  return (frontendPermissionAliases[p]||[]).some(alias=>permissions.includes(alias));
}
function canAny(list){return (list||[]).some(can);}
function empty(text){return `<div class="empty">${esc(text)}</div>`;}
function toast(message,good=true){const el=$("#toast");el.textContent=message;el.className="toast "+(good?"good":"bad");el.hidden=false;clearTimeout(toast.t);toast.t=setTimeout(()=>el.hidden=true,2600);}
function showApp(on){
  document.body.classList.toggle("panel-locked",!on);
  $("#loginCard").hidden=on;
  $("#workspace").hidden=!on;
  $("#sidebar").hidden=!on;
}
function setLoginMode(mode,updateUrl=false){
  state.loginMode=mode==="staff"?"staff":"owner";
  const staff=state.loginMode==="staff";
  if($("#ownerLoginPane"))$("#ownerLoginPane").hidden=staff;
  if($("#staffLoginPane"))$("#staffLoginPane").hidden=!staff;
  if($("#ownerLoginTab")){
    $("#ownerLoginTab").classList.toggle("active",!staff);
    $("#ownerLoginTab").setAttribute("aria-selected",String(!staff));
  }
  if($("#staffLoginTab")){
    $("#staffLoginTab").classList.toggle("active",staff);
    $("#staffLoginTab").setAttribute("aria-selected",String(staff));
  }
  if(updateUrl){
    const url=new URL(window.location.href);
    if(staff)url.searchParams.set("staff","1");else url.searchParams.delete("staff");
    history.replaceState(null,"",url);
  }
  if($("#loginStatus"))$("#loginStatus").textContent="";
  if($("#googleOwnerStatus"))$("#googleOwnerStatus").textContent="";
  applyPanelBranding();
  if(!staff&&!state.actor)initOwnerGoogleLogin();
}
function applyPanelBranding(){
  const isOwner=state.actor?.type==="owner";
  const isStaff=state.actor?.type==="staff";
  const title=isOwner
    ?"DarkVibeX Owner Panel"
    :isStaff
      ?"DarkVibeX Staff Panel"
      :(state.loginMode==="staff"?"DarkVibeX Staff Panel":"DarkVibeX Owner Panel");
  document.title=title;
  if($("#panelBrandLabel"))$("#panelBrandLabel").textContent=title;
  if($("#loginPanelTitle")&&!state.actor)$("#loginPanelTitle").textContent=title;
}
function actorCard(){
  if(!state.actor)return;
  applyPanelBranding();
  $("#actorCard").innerHTML=`<b>${esc(state.actor.name||"Authorized user")}</b><span>${esc(state.actor.role||"")}</span>`;
}

function permissionTarget(element,mode){
  if(mode==="label")return element.closest("label")||element;
  return element;
}
function setPermissionVisibility(selector,permissions,mode="self"){
  document.querySelectorAll(selector).forEach(element=>{
    permissionTarget(element,mode).hidden=!canAny(permissions);
  });
}
function applyActionPermissions(){
  selectorPermissionRules.forEach(([selector,permissions,mode])=>setPermissionVisibility(selector,permissions,mode));
  dynamicPermissionRules.forEach(([selector,permissions])=>setPermissionVisibility(selector,permissions,"self"));
  document.querySelectorAll("[data-setting-toggle]").forEach(element=>{
    const key=String(element.dataset.settingToggle||"");
    element.closest("label").hidden=!can("settings."+key);
  });
  if($("#clearAudit"))$("#clearAudit").hidden=state.actor?.type!=="owner";
  if($("#ownerPrivateMessages"))$("#ownerPrivateMessages").hidden=state.actor?.type!=="owner";
  const ownerCredentials=state.actor?.type==="owner";
  if($("#staffEmailLabel"))$("#staffEmailLabel").hidden=!ownerCredentials;
  if($("#staffPasswordLabel"))$("#staffPasswordLabel").hidden=!ownerCredentials;
  if($("#staffCredentialHelp"))$("#staffCredentialHelp").hidden=!ownerCredentials;
}
function applyPermissions(){
  $$(".nav-btn").forEach(btn=>{
    const view=btn.dataset.view;
    const ownerOnly=view==="notifications";
    const allowed=ownerOnly ? state.actor?.type==="owner" : canAny(viewPermissionMap[view]||[]);
    btn.hidden=!allowed;
  });
  applyActionPermissions();
}
function setView(name){state.view=name;$("#viewTitle").textContent=viewTitles[name]||name;$$('.nav-btn').forEach(b=>b.classList.toggle('active',b.dataset.view===name));$$('.view').forEach(v=>v.classList.toggle('active',v.dataset.viewPanel===name));loadView(name).catch(e=>toast(e.message,false));}
async function loadView(name){if(name==="overview")return loadOverview();if(name==="users")return loadUsers();if(name==="notifications")return loadNotifications();if(name==="messaging")return loadMessaging();if(name==="rooms")return loadRooms();if(name==="roles")return loadRolesPosts();if(name==="banners")return loadBanners();if(name==="games")return loadGames();if(name==="policies")return loadPolicies();if(name==="wallets")return loadWallets();if(name==="economy")return loadEconomy();if(name==="vip")return loadVipRules();if(name==="gifts")return loadGifts();if(name==="assets")return loadAssets();if(name==="store")return loadStore();if(name==="catalog")return loadCatalog();if(name==="settings")return loadSettings();if(name==="announcements")return loadAnnouncements();if(name==="staff")return loadStaff();if(name==="support")return loadSupport();if(name==="audit")return loadAudit();}

async function connectWithToken(token){
  state.token=String(token||"").trim();
  if(!state.token)return;
  $("#loginStatus").textContent="Checking protected access…";
  try{
    const session=await api("/api/owner/session");
    state.actor=session.actor;
    sessionStorage.setItem("dvxOwnerToken",state.token);
    showApp(true);
    actorCard();
    applyPermissions();
    $("#loginStatus").textContent="";
    const first=$$(".nav-btn").find(b=>!b.hidden);
    if(!first)throw new Error("no_panel_permissions");
    setView(first.dataset.view);
  }catch(e){
    state.token="";
    state.actor=null;
    sessionStorage.removeItem("dvxOwnerToken");
    showApp(false);
    $("#loginStatus").textContent=e.message==="unauthorized"?"Login expired or invalid. Sign in again.":e.message;
  }
}

async function connect(){
  const email=$("#loginEmail").value.trim().toLowerCase();
  const password=$("#loginPassword").value;
  if(!email||!password){
    $("#loginStatus").textContent="Enter the staff Gmail ID and panel password.";
    return;
  }
  $("#loginStatus").textContent="Signing in…";
  try{
    const res=await fetch("/api/owner/login",{
      method:"POST",
      headers:{"content-type":"application/json"},
      body:JSON.stringify({email,password})
    });
    const data=await res.json().catch(()=>({ok:false,error:"invalid_response"}));
    if(!res.ok||!data.ok)throw new Error(data.error||("HTTP "+res.status));
    $("#loginPassword").value="";
    await connectWithToken(data.token);
  }catch(e){
    $("#loginPassword").value="";
    const message=e.message==="invalid_email_or_password"
      ?"Gmail ID or panel password is incorrect."
      :e.message;
    $("#loginStatus").textContent=message;
  }
}

async function handleOwnerGoogleCredential(response){
  const credential=String(response?.credential||"").trim();
  if(!credential){
    $("#googleOwnerStatus").textContent="Google Login could not be completed.";
    return;
  }
  $("#googleOwnerStatus").textContent="Signing in…";
  try{
    const res=await fetch("/api/owner/google-login",{
      method:"POST",
      headers:{"content-type":"application/json"},
      body:JSON.stringify({id_token:credential})
    });
    const data=await res.json().catch(()=>({ok:false,error:"invalid_response"}));
    if(!res.ok||!data.ok)throw new Error(data.error||("HTTP "+res.status));
    $("#googleOwnerStatus").textContent="";
    await connectWithToken(data.token);
  }catch(e){
    $("#googleOwnerStatus").textContent=e.message==="owner_google_account_not_authorized"
      ?"This Google account is not authorized for Main Owner access."
      :"Google Login could not be completed.";
  }
}

async function initOwnerGoogleLogin(attempt=0){
  if(state.actor||state.loginMode!=="owner")return;
  const googleApi=window.google?.accounts?.id;
  if(!googleApi){
    if(attempt<40)setTimeout(()=>initOwnerGoogleLogin(attempt+1),250);
    return;
  }
  try{
    const res=await fetch("/api/auth/config",{headers:{"accept":"application/json"}});
    const data=await res.json();
    const clientId=String(data?.google_web_client_id||"").trim();
    if(!clientId){
      $("#googleOwnerStatus").textContent="Google Login is temporarily unavailable.";
      return;
    }
    googleApi.disableAutoSelect();
    googleApi.initialize({
      client_id:clientId,
      callback:handleOwnerGoogleCredential,
      auto_select:false,
      use_fedcm_for_button:true,
      button_auto_select:false,
      cancel_on_tap_outside:true
    });
    const target=$("#googleOwnerButton");
    target.innerHTML="";
    googleApi.renderButton(target,{
      theme:"filled_black",
      size:"large",
      type:"standard",
      shape:"pill",
      text:"signin_with",
      width:320
    });
  }catch(_){
    $("#googleOwnerStatus").textContent="Google Login is temporarily unavailable.";
  }
}

async function loadOverview(){
  const d=await api("/api/owner/overview");state.actor=d.actor||state.actor;actorCard();
  const labels=[["Users",d.stats.users],["Rooms",d.stats.rooms],["Online",d.stats.online],["Owner Treasury",d.stats.treasury],["Coins",d.stats.coins],["Diamonds",d.stats.diamonds],["Banned",d.stats.banned],["Gift events",d.stats.gifts],["Game bets",d.stats.bets]];
  $("#stats").innerHTML=labels.map(([k,v])=>`<article class="stat-card"><span>${esc(k)}</span><strong>${num(v)}</strong></article>`).join("");
  $("#overviewRooms").innerHTML=(d.rooms||[]).length?(d.rooms||[]).slice(0,10).map(room=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(room.name)}</div><div class="item-meta">ID ${esc(room.id)} · ${num(room.online)} online · ${num(room.seat_count)} seats · ${esc(room.owner_name||room.owner_user_id)}</div></div><span class="pill ${Number(room.locked)?'banned':'active'}">${Number(room.locked)?'Locked':'Open'}</span></div></div>`).join(""):empty("No rooms yet");
  $("#overviewAudit").innerHTML=(d.audit||[]).length?(d.audit||[]).map(a=>`<div class="item-card"><div class="item-title">${esc(a.action.replaceAll('_',' '))}</div><div class="item-meta">${esc(a.target_type)} ${esc(a.target_id)} · ${esc(a.summary||'')}<br>${time(a.created_at)}</div></div>`).join(""):empty("No owner activity yet");
}

async function loadUsers(){if(!can("users.search"))return;const q=$("#userSearch").value.trim();const d=await api("/api/owner/users?q="+encodeURIComponent(q));$("#userList").innerHTML=(d.users||[]).length?d.users.map(u=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(u.display_name||'Unnamed user')} <span class="pill ${u.status==='banned'?'banned':'active'}">${esc(u.status)}</span></div><div class="item-meta">Public ID ${esc(u.public_id||'—')} · Internal ${esc(u.id)} · ${esc(u.role)} · VIP ${num(u.vip_level)}<br>${num(u.coins)} coins · ${num(u.diamonds)} diamonds</div></div><div class="item-actions"><button class="secondary mini" data-user-open="${esc(u.id)}">Manage</button></div></div></div>`).join(""):empty("No matching users");$$('[data-user-open]').forEach(b=>b.onclick=()=>openUser(b.dataset.userOpen));}
async function openUser(id){
  if(!can("users.detail"))return toast("Full ID View permission required",false);
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
  const ownerMessageAccess=state.actor?.type==="owner";
  $("#ownerPrivateMessages").hidden=!ownerMessageAccess;
  $("#ownerMessageThreadPanel").hidden=true;
  state.ownerMessageConversations=[];
  state.ownerMessageThreadOtherId=null;
  if(ownerMessageAccess){
    $("#ownerMessageSummary").textContent="Message history is not loaded until the Owner opens it.";
    $("#ownerConversationList").innerHTML=empty("Click “Load Message Inbox” to inspect this ID's chats.");
    $("#ownerMessageThread").innerHTML="";
    $("#ownerMessageRedPockets").innerHTML="";
  }
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

async function loadOwnerMessageInbox(){
  if(state.actor?.type!=="owner")return toast("Only the main Owner can inspect private messages",false);
  if(!state.selectedUser)return toast("Select a user first",false);
  const d=await api("/api/owner/users/"+encodeURIComponent(state.selectedUser.id)+"/messages");
  state.ownerMessageConversations=d.conversations||[];
  state.ownerMessageThreadOtherId=null;
  $("#ownerMessageThreadPanel").hidden=true;
  $("#ownerMessageSummary").textContent=`${state.ownerMessageConversations.length} conversation(s) found. Opening a thread is also audited.`;
  $("#ownerConversationList").innerHTML=state.ownerMessageConversations.length?state.ownerMessageConversations.map(row=>{
    const id=row.other_user_id||"";
    const name=row.other_name||"User";
    const publicId=row.other_public_id||id;
    const preview=row.preview||"(No text)";
    const unread=Number(row.unread_for_user||0);
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(name)} · ID ${esc(publicId)} ${unread?`<span class="pill banned">${num(unread)} unread</span>`:""}</div><div class="item-meta">${esc(preview)}<br>${num(row.message_count||0)} messages · ${time(row.created_at)}</div></div><button class="secondary mini" data-owner-message-thread="${esc(id)}">Open Thread</button></div></div>`;
  }).join(""):empty("No private conversations found for this user.");
  document.querySelectorAll("[data-owner-message-thread]").forEach(b=>b.onclick=()=>loadOwnerMessageThread(b.dataset.ownerMessageThread).catch(e=>toast(e.message,false)));
}

async function loadOwnerMessageThread(otherId){
  if(state.actor?.type!=="owner")return toast("Only the main Owner can inspect private messages",false);
  if(!state.selectedUser)return;
  const id=String(otherId||"").trim();
  if(!id)return;
  const d=await api("/api/owner/users/"+encodeURIComponent(state.selectedUser.id)+"/messages?other_user_id="+encodeURIComponent(id)+"&limit=1000");
  state.ownerMessageThreadOtherId=id;
  const other=d.other_user||{};
  $("#ownerMessageThreadPanel").hidden=false;
  $("#ownerMessageThreadTitle").textContent="Chat with "+(other.display_name||"User");
  $("#ownerMessageThreadMeta").textContent=`ID ${other.public_id||other.id||id} · ${(d.messages||[]).length} message(s) · inspection does not change read status`;

  const selectedId=String(state.selectedUser.id);
  const timeline=[];
  for(const m of d.messages||[]) timeline.push({type:"message",created_at:Number(m.created_at||0),data:m});
  for(const e of d.red_envelopes||[]) timeline.push({type:"red",created_at:Number(e.created_at||0),data:e});
  timeline.sort((a,b)=>a.created_at-b.created_at);

  $("#ownerMessageThread").innerHTML=timeline.length?timeline.map(entry=>{
    if(entry.type==="red"){
      const e=entry.data;
      const sender=String(e.sender_user_id)===selectedId?"Selected ID":"Other user";
      return `<div class="item-card"><div class="item-title">🧧 Red Pocket · ${esc(sender)} → ${String(e.receiver_user_id)===selectedId?"Selected ID":"Other user"}</div><div class="item-meta">${num(e.amount)} coins · ${esc(e.status||"")} · ${time(e.created_at)}${e.claimed_at?" · claimed "+time(e.claimed_at):""}</div></div>`;
    }
    const m=entry.data;
    const fromSelected=String(m.sender_user_id)===selectedId;
    const senderName=m.sender_name||m.sender_public_id||m.sender_user_id||"User";
    const receiverName=m.receiver_name||m.receiver_public_id||m.receiver_user_id||"User";
    const readText=m.read_at?"Read "+time(m.read_at):"Unread";
    const imageButton=m.image_key?`<button class="secondary mini" data-owner-message-image="${esc(m.image_key)}">View Photo</button>`:"";
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${fromSelected?"→":"←"} ${esc(senderName)} → ${esc(receiverName)}</div><div class="item-meta">${m.text?esc(m.text):"(Photo message)"}<br>${time(m.created_at)} · ${esc(readText)}${m.image_key?" · photo attached":""}</div></div>${imageButton}</div></div>`;
  }).join(""):empty("No messages in this thread.");

  $("#ownerMessageRedPockets").innerHTML=(d.red_envelopes||[]).length?(d.red_envelopes||[]).map(e=>`<div class="item-card"><div class="item-title">${num(e.amount)} coins · ${esc(e.status||"")}</div><div class="item-meta">${esc(e.sender_user_id)} → ${esc(e.receiver_user_id)} · ${time(e.created_at)}${e.claimed_at?" · claimed "+time(e.claimed_at):""}</div></div>`).join(""):empty("No Red Pocket history in this thread.");

  document.querySelectorAll("[data-owner-message-image]").forEach(b=>b.onclick=()=>openOwnerMessageImage(b.dataset.ownerMessageImage));
  $("#ownerMessageThreadPanel").scrollIntoView({behavior:"smooth",block:"start"});
}

async function openOwnerMessageImage(key){
  const popup=window.open("","_blank");
  try{
    if(popup){
      popup.document.write("<title>DarkVibeX message photo</title><p>Loading protected message photo…</p>");
    }
    const blob=await apiBlob("/api/owner/message-media?key="+encodeURIComponent(key));
    const url=URL.createObjectURL(blob);
    if(popup) popup.location.href=url;
    else window.location.href=url;
    setTimeout(()=>URL.revokeObjectURL(url),120000);
  }catch(error){
    if(popup)popup.close();
    toast(error.message,false);
  }
}

function renderLedger(rows){$("#walletLedger").innerHTML=rows.length?`<div class="small-table">${rows.map(r=>`<div class="ledger-row"><span>${time(r.created_at)}</span><span>${esc(r.kind.replaceAll('_',' '))}</span><b>${Number(r.amount)>0?'+':''}${num(r.amount)} → ${num(r.balance_after)}</b></div>`).join("")}</div>`:empty("No coin ledger entries");}
async function saveUserProfile(){
  if(!state.selectedUser)return;
  const payload={};
  if(can("users.name.edit"))payload.display_name=$("#editUserName").value;
  if(can("users.role.edit"))payload.role=$("#editUserRole").value;
  if(can("users.vip.edit"))payload.vip_level=Number($("#editVip").value||0);
  if(!Object.keys(payload).length)return toast("No profile edit permission selected",false);
  await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/profile`,{method:"POST",body:JSON.stringify(payload)});
  toast("User profile saved");await openUser(state.selectedUser.id);if(can("users.search"))await loadUsers();
}
async function saveModeration(){if(!state.selectedUser)return;if(!can("users.moderation"))return toast("Moderation permission required",false);await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/moderation`,{method:"POST",body:JSON.stringify({status:$("#editStatus").value,note:$("#editNote").value})});toast("Moderation status saved");await openUser(state.selectedUser.id);await loadUsers();}
async function savePublicId(){if(!state.selectedUser)return;if(!can("users.public_id.change"))return toast("Public ID permission required",false);const publicId=$("#editPublicId").value.trim();if(!/^\d{7}$/.test(publicId)||Number(publicId)<1000001)return toast("Public ID must be between 1000001 and 9999999",false);await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/public-id`,{method:"POST",body:JSON.stringify({public_id:publicId})});toast("Public ID changed");await openUser(state.selectedUser.id);await loadUsers();}
async function applyWallet(){if(!state.selectedUser)return;if(!can("users.wallet.adjust"))return toast("Wallet adjustment permission required",false);const coin=Number($("#coinDelta").value||0),diamond=Number($("#diamondDelta").value||0);if(!coin&&!diamond)return toast("Enter a coin or diamond change",false);await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/wallet`,{method:"POST",body:JSON.stringify({coin_delta:coin,diamond_delta:diamond})});$("#coinDelta").value="";$("#diamondDelta").value="";toast("Wallet adjustment applied");await openUser(state.selectedUser.id);await loadUsers();}
async function applyRoleWallet(){
  if(!state.selectedUser)return;
  const walletType=$("#roleWalletType").value;
  if(!walletType)return toast("Select Coin Seller or Merchant wallet",false);
  const payload={role_wallet_type:walletType};
  if(can("users.role_wallet.adjust"))payload.role_coin_delta=Number($("#roleCoinDelta").value||0);
  if(can("users.role_wallet.ban"))payload.role_wallet_banned=$("#roleWalletBanned").checked;
  if(!Object.prototype.hasOwnProperty.call(payload,"role_coin_delta")&&!Object.prototype.hasOwnProperty.call(payload,"role_wallet_banned"))return toast("No role-wallet permission selected",false);
  await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/wallet`,{method:"POST",body:JSON.stringify(payload)});
  toast("Role wallet balance/status updated");await openUser(state.selectedUser.id);if(can("users.search"))await loadUsers();
}

async function loadRooms(){
  if(!can("rooms.view"))return;
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
  if(!can("treasury.view"))return;
  const d=await api("/api/owner/treasury");
  state.treasury=d.treasury||{balance:0};
  $("#treasuryBalance").textContent=num(state.treasury.balance||0);
  const rows=d.ledger||[];
  $("#treasuryLedger").innerHTML=rows.length?rows.map(r=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(r.kind.replaceAll('_',' '))}</div><div class="item-meta">${time(r.created_at)} · actor ${esc(r.actor_id||'owner')}${r.target_user_id?' · target '+esc(r.target_user_id):''}${r.note?' · '+esc(r.note):''}</div></div><b>${Number(r.amount)>0?'+':''}${num(r.amount)} → ${num(r.balance_after)}</b></div></div>`).join(""):empty("No treasury activity yet");
  const ownerOnly=state.actor?.role==="owner";
  $("#treasuryAdd").hidden=!ownerOnly;
  $("#treasuryDeduct").hidden=!ownerOnly;
  $("#treasurySend").disabled=!can("treasury.send");
}
async function treasuryAction(action){
  if(!can("treasury.send"))return toast("Treasury write permission required",false);
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
  if(!can("economy.view"))return;
  const d=await api("/api/owner/economy");
  const rate=Number(d.coins_per_usd||5000000);
  $("#coinRateCoinsPerUsd").value=String(rate);
  renderCoinRate(rate,d.updated_at);
  $("#saveCoinRate").disabled=!can("economy.coin_rate.edit");
  if(!can("users.search")){
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
  if(!can("users.search"))return toast("Users read permission required",false);
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
  $("#saveEconomyPublicId").disabled=!can("users.public_id.change");
}
async function saveEconomyPublicId(){
  if(!state.economyUser)return toast("Select a user first",false);
  if(!can("users.public_id.change"))return toast("Users write permission required",false);
  const publicId=$("#economyPublicId").value.trim();
  if(!/^\d{7}$/.test(publicId)||Number(publicId)<1000001)return toast("Unique ID must be between 1000001 and 9999999",false);
  await api(`/api/owner/users/${encodeURIComponent(state.economyUser.id)}/public-id`,{method:"POST",body:JSON.stringify({public_id:publicId})});
  toast("Unique ID changed");
  await selectEconomyUser(state.economyUser.id);
  await searchEconomyUsers();
}
async function saveCoinRate(){
  if(!can("economy.coin_rate.edit"))return toast("Economy write permission required",false);
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
  if(!can("store.view"))return;
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
  if(!can("store.save"))return toast("Store save permission required",false);
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
  if(!can("store.remove"))return toast("Store remove permission required",false);
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
  if(!can("vip.view"))return;
  const d=await api("/api/owner/vip-rules");
  state.vipRules=d.levels||[];
  $("#vipRuleList").innerHTML=state.vipRules.length?state.vipRules.map(rule=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(rule.name||("VIP "+rule.level))} <span class="pill ${Number(rule.enabled)?"active":"banned"}">${Number(rule.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">Level ${num(rule.level)} · upgrade ${num(rule.upgrade_exp)} EXP · maintain ${num(rule.maintain_exp)} EXP · ${num(rule.validity_days)} days · ${esc(rule.source||"base")}${rule.entry_id?" · entry "+esc(rule.entry_id):""}${rule.frame_id?" · frame "+esc(rule.frame_id):""}</div></div><button class="secondary mini" data-vip-rule-edit="${rule.level}">Edit</button></div></div>`).join(""):empty("No VIP rules");
  $$("[data-vip-rule-edit]").forEach(b=>b.onclick=()=>{const rule=state.vipRules.find(x=>Number(x.level)===Number(b.dataset.vipRuleEdit));fillVipRuleForm(rule);$("#vipRuleLevel").scrollIntoView({behavior:"smooth",block:"center"});});
  const selected=state.vipRules.find(x=>Number(x.level)===Number($("#vipRuleLevel").value||1))||state.vipRules[0];
  if(selected)fillVipRuleForm(selected);
}
async function saveVipRule(){
  if(!can("vip.save"))return toast("VIP save permission required",false);
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
  if(!can("vip.reset"))return toast("VIP reset permission required",false);
  const level=Number($("#vipRuleLevel").value);
  if(!Number.isSafeInteger(level)||level<1||level>18)return toast("Select VIP1–VIP18",false);
  if(!confirm("Reset VIP "+level+" to the DarkVibeX base rule?"))return;
  await api("/api/owner/vip-rules/"+level,{method:"DELETE"});
  toast("VIP rule reset to base");
  await loadVipRules();
}

function clearGiftForm(){
  $("#giftId").value="";$("#giftName").value="";$("#giftPrice").value=0;$("#giftVip").value=0;
  $("#giftEmoji").value="";$("#giftCategory").value="normal";$("#giftAsset").value="";$("#giftVideoKey").value="";$("#giftVideoFile").value="";$("#giftVideoStatus").textContent="";$("#giftOrder").value=0;
  $("#giftStart").value="";$("#giftEnd").value="";$("#giftEnabled").checked=true;$("#giftDescription").value="";
}

async function uploadGiftVideo(){
  if(!can("gifts.save"))return toast("Gift save permission required",false);
  const giftId=$("#giftId").value.trim();
  const file=$("#giftVideoFile").files?.[0];
  if(!giftId)return toast("Enter Gift ID before uploading video",false);
  if(!file)return toast("Choose an MP4 gift video first",false);
  if(file.type!=="video/mp4"&&!/\.mp4$/i.test(file.name))return toast("Only MP4 gift video is supported",false);
  if(file.size<=0||file.size>11*1024*1024)return toast("Gift video can be maximum 11 MB. Choose a smaller MP4 file.",false);
  $("#giftVideoStatus").textContent="Uploading to R2…";
  const res=await fetch("/api/owner/gift-media",{
    method:"PUT",
    headers:{
      authorization:"Bearer "+state.token,
      "content-type":"video/mp4",
      "x-gift-id":giftId
    },
    body:file
  });
  const data=await res.json().catch(()=>({ok:false,error:"invalid_response"}));
  if(!res.ok||!data.ok){
    $("#giftVideoStatus").textContent="";
    const message=data.error==="gift_video_max_11mb"
      ?"Gift video can be maximum 11 MB. Choose a smaller MP4 file."
      :data.error==="gift_video_mp4_required"
        ?"Only MP4 gift video is supported."
        :data.error==="gift_video_invalid"
          ?"This MP4 file is invalid. Choose another video."
          :data.error;
    throw new Error(message||("HTTP "+res.status));
  }
  $("#giftVideoKey").value=String(data.key||"");
  $("#giftVideoStatus").textContent="Video saved in R2";
  toast("Gift video uploaded to R2");
}
async function loadGifts(){
  if(!can("gifts.view"))return;
  const d=await api("/api/owner/store?kind=gift");
  state.giftItems=d.items||[];
  $("#giftList").innerHTML=state.giftItems.length?state.giftItems.map(item=>{
    const data=item.data||{},enabled=Number(item.enabled)!==0;
    const windowText=(data.starts_at||data.ends_at)?` · ${data.starts_at?time(data.starts_at):"now"} → ${data.ends_at?time(data.ends_at):"no end"}`:"";
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name||item.id)} <span class="pill ${enabled?"active":"banned"}">${enabled?"Enabled":"Removed"}</span></div><div class="item-meta">ID ${esc(item.id)} · ${num(item.price_coins)} coins · VIP ${num(data.min_vip_level??data.vip_level??0)} · ${esc(item.source||"custom")}${windowText}<br>${esc(data.description||data.video_key||data.asset_key||data.emoji||"")}</div></div><div class="item-actions"><button class="secondary mini" data-gift-edit="${esc(item.id)}">Edit</button><button class="danger mini" data-gift-remove="${esc(item.id)}">Remove</button></div></div></div>`;
  }).join(""):empty("No gifts");
  $$("[data-gift-edit]").forEach(b=>b.onclick=()=>editGift(b.dataset.giftEdit));
  $$("[data-gift-remove]").forEach(b=>b.onclick=()=>removeGift(b.dataset.giftRemove).catch(e=>toast(e.message,false)));
}
function editGift(id){
  const item=state.giftItems.find(x=>x.id===id);if(!item)return;const d=item.data||{};
  $("#giftId").value=item.id||"";$("#giftName").value=item.name||"";$("#giftPrice").value=Number(item.price_coins||0);
  $("#giftVip").value=Number(d.min_vip_level??d.vip_level??0);$("#giftEmoji").value=d.emoji||"";$("#giftCategory").value=d.category||"normal";
  $("#giftAsset").value=d.asset_key||d.asset||"";$("#giftVideoKey").value=d.video_key||"";$("#giftVideoFile").value="";$("#giftVideoStatus").textContent=d.video_key?"R2 video attached":"";$("#giftOrder").value=Number(item.sort_order||0);
  $("#giftStart").value=d.starts_at||"";$("#giftEnd").value=d.ends_at||"";$("#giftEnabled").checked=Number(item.enabled)!==0;$("#giftDescription").value=d.description||"";
}
async function saveGift(){
  if(!can("gifts.save"))return toast("Gift save permission required",false);
  const id=$("#giftId").value.trim(),name=$("#giftName").value.trim()||id;
  if(!id||!name)return toast("Gift ID and name are required",false);
  const starts=Number($("#giftStart").value||0)||null,ends=Number($("#giftEnd").value||0)||null;
  if(starts&&ends&&ends<=starts)return toast("Gift end time must be after start time",false);
  await api("/api/owner/store",{method:"POST",body:JSON.stringify({
    kind:"gift",id,name,price_coins:Number($("#giftPrice").value||0),sort_order:Number($("#giftOrder").value||0),enabled:$("#giftEnabled").checked,
    data:{min_vip_level:Number($("#giftVip").value||0),vip_level:Number($("#giftVip").value||0),emoji:$("#giftEmoji").value.trim(),category:$("#giftCategory").value.trim(),asset_key:$("#giftAsset").value.trim(),asset:$("#giftAsset").value.trim(),video_key:$("#giftVideoKey").value.trim(),description:$("#giftDescription").value.trim(),starts_at:starts,ends_at:ends}
  })});
  toast("Gift saved to live catalog");clearGiftForm();await loadGifts();
}
async function removeGift(id){
  if(!can("gifts.remove"))return toast("Gift remove permission required",false);
  if(!confirm("Remove this gift from the app?"))return;
  await api("/api/owner/store/gift/"+encodeURIComponent(id),{method:"DELETE"});toast("Gift removed");await loadGifts();
}

function clearAssetForm(){
  $("#assetId").value="";$("#assetName").value="";$("#assetPrice").value=0;$("#assetVip").value=0;$("#assetDuration").value=30;
  $("#assetTier").value=0;$("#assetOrder").value=0;$("#assetFileKey").value="";$("#assetStart").value="";$("#assetEnd").value="";
  $("#assetEnabled").checked=true;$("#assetDescription").value="";
}
async function loadAssets(){
  if(!can("assets.view"))return;
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
  if(!can("assets.save"))return toast("Asset save permission required",false);
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
  if(!can("assets.remove"))return toast("Asset remove permission required",false);
  const kind=$("#assetKind").value;if(!confirm("Remove this "+kind+" from the app?"))return;
  await api("/api/owner/store/"+encodeURIComponent(kind)+"/"+encodeURIComponent(id),{method:"DELETE"});toast("Asset removed");await loadAssets();
}

function clearCatalogForm(){$("#catalogId").value="";$("#catalogName").value="";$("#catalogPrice").value=0;$("#catalogOrder").value=0;$("#catalogAsset").value="";$("#catalogLevel").value="";$("#catalogDescription").value="";$("#catalogEnabled").checked=true;}
async function loadCatalog(){if(!can("catalog.view"))return;const kind=$("#catalogKind").value;const d=await api('/api/owner/catalog?kind='+encodeURIComponent(kind));state.catalog=d.items||[];$("#catalogList").innerHTML=state.catalog.length?state.catalog.map(i=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(i.name)} <span class="pill ${Number(i.enabled)?'active':'banned'}">${Number(i.enabled)?'Enabled':'Disabled'}</span></div><div class="item-meta">ID ${esc(i.id)} · ${num(i.price_coins)} coins · order ${num(i.sort_order)}<br>${esc(i.data?.description||i.data?.level||i.data?.asset||'')}</div></div><div class="item-actions"><button class="secondary mini" data-catalog-edit="${esc(i.id)}">Edit</button><button class="danger mini" data-catalog-delete="${esc(i.id)}">Delete</button></div></div></div>`).join(""):empty("No items in this category");$$('[data-catalog-edit]').forEach(b=>b.onclick=()=>editCatalog(b.dataset.catalogEdit));$$('[data-catalog-delete]').forEach(b=>b.onclick=()=>deleteCatalog(b.dataset.catalogDelete));}
function editCatalog(id){const i=state.catalog.find(x=>x.id===id);if(!i)return;$("#catalogId").value=i.id;$("#catalogName").value=i.name;$("#catalogPrice").value=i.price_coins||0;$("#catalogOrder").value=i.sort_order||0;$("#catalogAsset").value=i.data?.asset||"";$("#catalogLevel").value=i.data?.level||"";$("#catalogDescription").value=i.data?.description||"";$("#catalogEnabled").checked=!!Number(i.enabled);window.scrollTo({top:0,behavior:'smooth'});}
async function saveCatalog(){const payload={kind:$("#catalogKind").value,id:$("#catalogId").value.trim()||undefined,name:$("#catalogName").value.trim(),price_coins:Number($("#catalogPrice").value||0),sort_order:Number($("#catalogOrder").value||0),enabled:$("#catalogEnabled").checked,data:{asset:$("#catalogAsset").value.trim(),level:$("#catalogLevel").value.trim(),description:$("#catalogDescription").value.trim()}};if(!payload.name)return toast('Enter a display name',false);await api('/api/owner/catalog',{method:'POST',body:JSON.stringify(payload)});toast('Content item saved');clearCatalogForm();await loadCatalog();}

async function deleteCatalog(id){if(!confirm('Delete this content item?'))return;const kind=$("#catalogKind").value;await api(`/api/owner/catalog/${encodeURIComponent(kind)}/${encodeURIComponent(id)}`,{method:'DELETE'});toast('Content item deleted');loadCatalog();}

async function loadSettings(){
  if(!canAny(viewPermissionMap.settings))return;
  const d=await api("/api/owner/settings");
  state.settings=new Map((d.settings||[]).map(row=>[row.key,row.value]));
  const mayViewAll=can("settings.view");
  $("#featureSettings").innerHTML=Object.entries(featureLabels).filter(([key])=>mayViewAll||can("settings."+key)).map(([key,label])=>{
    const enabled=state.settings.get(key)?.enabled!==false;
    const editable=can("settings."+key);
    return `<label class="toggle-card"><span><b>${esc(label)}</b><small class="muted"> ${enabled?"On":"Off"}</small></span><input type="checkbox" data-setting-toggle="${esc(key)}" ${enabled?"checked":""} ${editable?"":"disabled"}></label>`;
  }).join("")||empty("No settings functions selected");
  $$("[data-setting-toggle]").forEach(input=>input.onchange=()=>saveFeature(input.dataset.settingToggle,input.checked));
  const maintenance=state.settings.get("maintenance")||{};
  $("#maintenanceEnabled").checked=!!maintenance.enabled;
  $("#maintenanceMessage").value=maintenance.message||"";
  applyActionPermissions();
}
async function saveFeature(key,enabled){
  const permission="settings."+String(key||"");
  if(!can(permission))return toast("This setting permission is not selected",false);
  await api("/api/owner/settings/"+encodeURIComponent(key),{method:"POST",body:JSON.stringify({value:{enabled}})});
  toast(featureLabels[key]+" "+(enabled?"enabled":"disabled"));
}
async function saveMaintenance(){
  if(!can("settings.maintenance"))return toast("Maintenance permission required",false);
  await api("/api/owner/settings/maintenance",{method:"POST",body:JSON.stringify({value:{enabled:$("#maintenanceEnabled").checked,message:$("#maintenanceMessage").value.trim()}})});
  toast("Maintenance setting saved");
}

function localInputValue(ts){if(!ts)return "";const d=new Date(Number(ts));const pad=n=>String(n).padStart(2,"0");return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;}
function clearAnnouncementForm(){$("#announcementId").value="";$("#announcementTitle").value="";$("#announcementBody").value="";$("#announcementEnabled").checked=true;$("#announcementStart").value="";$("#announcementEnd").value="";}
async function loadAnnouncements(){
  if(!can("announcements.view"))return;
  const d=await api("/api/owner/announcements");
  const rows=d.announcements||[];
  $("#announcementList").innerHTML=rows.length?rows.map(a=>{
    const windowText=(a.starts_at||a.ends_at)?` · ${a.starts_at?time(a.starts_at):"now"} → ${a.ends_at?time(a.ends_at):"no end"}`:"";
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(a.title)} <span class="pill ${Number(a.enabled)?"active":"banned"}">${Number(a.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">${esc(a.body)}${windowText}</div></div><div class="item-actions"><button class="secondary mini" data-ann-edit="${esc(a.id)}">Edit</button><button class="danger mini" data-ann-delete="${esc(a.id)}">Delete</button></div></div></div>`;
  }).join(""):empty("No announcements");
  $$("[data-ann-edit]").forEach(b=>b.onclick=()=>{
    const a=rows.find(x=>x.id===b.dataset.annEdit);if(!a)return;
    $("#announcementId").value=a.id||"";$("#announcementTitle").value=a.title||"";$("#announcementBody").value=a.body||"";
    $("#announcementEnabled").checked=Number(a.enabled)!==0;$("#announcementStart").value=localInputValue(a.starts_at);$("#announcementEnd").value=localInputValue(a.ends_at);
  });
  $$("[data-ann-delete]").forEach(b=>b.onclick=async()=>{if(!confirm("Delete this announcement?"))return;await api("/api/owner/announcements/"+encodeURIComponent(b.dataset.annDelete),{method:"DELETE"});toast("Announcement deleted");await loadAnnouncements();});
}
async function saveAnnouncement(){
  const startRaw=$("#announcementStart").value,endRaw=$("#announcementEnd").value;
  const starts=startRaw?new Date(startRaw).getTime():null,ends=endRaw?new Date(endRaw).getTime():null;
  if(starts!=null&&ends!=null&&ends<=starts)return toast("Announcement end must be after start",false);
  const payload={id:$("#announcementId").value.trim()||undefined,title:$("#announcementTitle").value.trim(),body:$("#announcementBody").value.trim(),enabled:$("#announcementEnabled").checked,starts_at:starts,ends_at:ends};
  if(!payload.title||!payload.body)return toast("Title and message are required",false);
  await api("/api/owner/announcements",{method:"POST",body:JSON.stringify(payload)});
  clearAnnouncementForm();toast("Announcement saved");await loadAnnouncements();
}

function renderStaffPermissionEditor(selected=[]){
  const selectedSet=new Set((selected||[]).map(String));
  const available=staffPermissionOptions.filter(([value])=>state.actor?.type==="owner"||can(value));
  $("#staffPermissions").innerHTML=available.map(([value,label])=>
    `<label class="permission-item"><input type="checkbox" value="${esc(value)}" ${selectedSet.has(value)?"checked":""} /> <span>${esc(label)}</span></label>`
  ).join("")||empty("No assignable functions for this panel.");
  $("#staffPermissions").dataset.ready="1";
}
function cancelStaffEdit(){
  state.staffEditingId=null;
  $("#staffName").value="";
  $("#staffRole").value="manager";
  $("#staffEmail").value="";
  $("#staffPassword").value="";
  $("#staffPassword").placeholder="Minimum 8 characters";
  renderStaffPermissionEditor([]);
  $("#createStaff").textContent="Create Custom Panel Access";
  $("#cancelStaffEdit").hidden=true;
  $("#newStaffToken").hidden=true;
  applyActionPermissions();
}
async function loadStaff(){
  renderStaffPermissionEditor(
    state.staffEditingId
      ? $$("#staffPermissions input:checked").map(x=>x.value)
      : []
  );
  if(!can("staff.view")){
    $("#staffList").innerHTML=empty("Staff list permission is not selected for this panel.");
    applyActionPermissions();
    return;
  }
  const d=await api("/api/owner/staff");
  const rows=d.staff||[];
  const owner=state.actor?.type==="owner";
  $("#staffList").innerHTML=rows.length?rows.map(item=>{
    const permissions=item.permissions||[];
    const actions=[];
    if(can("staff.permissions.edit"))actions.push(`<button class="secondary mini" data-staff-edit="${esc(item.id)}">Edit Functions</button>`);
    if(can("staff.toggle"))actions.push(`<button class="secondary mini" data-staff-toggle="${esc(item.id)}" data-enabled="${Number(item.enabled)}">${Number(item.enabled)?"Disable":"Enable"}</button>`);
    if(can("staff.delete"))actions.push(`<button class="danger mini" data-staff-delete="${esc(item.id)}">Delete</button>`);
    const gmail=owner&&item.email?` · ${esc(item.email)}`:"";
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.display_name)} <span class="pill ${Number(item.enabled)?"active":"banned"}">${Number(item.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">${esc(item.role.replaceAll("_"," "))}${gmail} · last used ${time(item.last_used_at)}<br>${permissions.length?esc(permissions.join(", ")):"No functions selected"}</div></div><div class="item-actions">${actions.join("")}</div></div></div>`;
  }).join(""):empty("No custom panels created");

  $$("[data-staff-edit]").forEach(b=>b.onclick=()=>{
    const item=rows.find(x=>x.id===b.dataset.staffEdit);
    if(!item)return;
    if(!can("staff.permissions.edit"))return toast("Staff permission-edit access required",false);
    state.staffEditingId=item.id;
    $("#staffName").value=item.display_name||"";
    $("#staffRole").value=item.role||"manager";
    $("#staffEmail").value=owner?(item.email||""):"";
    $("#staffPassword").value="";
    $("#staffPassword").placeholder=owner
      ?"Leave blank to keep current password"
      :"Password can only be changed by Main Owner";
    renderStaffPermissionEditor(item.permissions||[]);
    $("#createStaff").textContent=owner?"Save Staff Panel / Credentials":"Save Staff Panel Functions";
    $("#cancelStaffEdit").hidden=false;
    $("#staffName").scrollIntoView({behavior:"smooth",block:"center"});
    applyActionPermissions();
  });
  $$("[data-staff-toggle]").forEach(b=>b.onclick=async()=>{
    if(!can("staff.toggle"))return toast("Staff enable/disable permission required",false);
    await api("/api/owner/staff/"+encodeURIComponent(b.dataset.staffToggle),{method:"POST",body:JSON.stringify({enabled:!Number(b.dataset.enabled)})});
    toast("Staff access updated");
    await loadStaff();
  });
  $$("[data-staff-delete]").forEach(b=>b.onclick=async()=>{
    if(!can("staff.delete"))return toast("Staff delete permission required",false);
    if(!confirm("Delete this staff access?"))return;
    await api("/api/owner/staff/"+encodeURIComponent(b.dataset.staffDelete),{method:"DELETE"});
    toast("Staff access deleted");
    if(state.staffEditingId===b.dataset.staffDelete)cancelStaffEdit();
    await loadStaff();
  });
  applyActionPermissions();
}

async function createStaff(){
  const editing=Boolean(state.staffEditingId);
  if(editing&&!can("staff.permissions.edit"))return toast("Staff permission-edit access required",false);
  if(!editing&&!can("staff.create"))return toast("Staff create permission required",false);
  if(!editing&&state.actor?.type!=="owner"){
    return toast("Only the Main Owner can create staff Gmail/password access.",false);
  }

  const name=$("#staffName").value.trim();
  if(!name)return toast("Enter staff name",false);
  const permissions=$$("#staffPermissions input:checked").map(x=>x.value);
  const payload={display_name:name,role:$("#staffRole").value,permissions};

  if(state.actor?.type==="owner"){
    const email=$("#staffEmail").value.trim().toLowerCase();
    const password=$("#staffPassword").value;
    if(!editing){
      if(!email.endsWith("@gmail.com")&&!email.endsWith("@googlemail.com")){
        return toast("Enter a valid Gmail ID",false);
      }
      if(password.length<8||password.length>128){
        return toast("Panel password must be 8 to 128 characters",false);
      }
    }
    if(email)payload.email=email;
    if(password)payload.password=password;
  }

  if(editing){
    await api("/api/owner/staff/"+encodeURIComponent(state.staffEditingId),{
      method:"POST",
      body:JSON.stringify(payload)
    });
    toast(state.actor?.type==="owner"&&payload.password
      ?"Staff panel and password updated"
      :"Staff panel functions updated");
    cancelStaffEdit();
    await loadStaff();
    return;
  }

  const d=await api("/api/owner/staff",{method:"POST",body:JSON.stringify(payload)});
  const box=$("#newStaffToken");
  const staffLoginUrl=new URL(window.location.pathname,window.location.origin);
  staffLoginUrl.searchParams.set("staff","1");
  box.hidden=false;
  box.innerHTML=`<b>Staff login ready</b><br>Gmail: ${esc(d.staff?.email||payload.email)}<br>Staff Panel: <a href="${esc(staffLoginUrl.toString())}" target="_blank" rel="noopener">${esc(staffLoginUrl.toString())}</a><br><small>Staff login uses only this Gmail ID and the panel password set by the Main Owner. Google Sign-In is not shown in Staff Panel mode.</small>`;
  $("#staffPassword").value="";
  toast(permissions.length?"Custom staff panel created":"Custom staff panel created with zero functions");
  state.staffEditingId=null;
  $("#staffName").value="";
  $("#staffEmail").value="";
  $("#staffRole").value="manager";
  renderStaffPermissionEditor([]);
  await loadStaff();
}

async function loadSupport(){if(!can('support.view'))return;const status=$("#supportStatus").value;const d=await api('/api/owner/support-tickets?status='+encodeURIComponent(status));const rows=d.tickets||[];$("#supportList").innerHTML=rows.length?rows.map(t=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(t.subject)} <span class="pill ${t.status==='open'?'active':'banned'}">${esc(t.status)}</span></div><div class="item-meta">${esc(t.display_name||'VIP user')} · ID ${esc(t.user_id)} · VIP ${num(t.vip_level)} · ${time(t.updated_at)}<br>${t.last_message?esc(t.last_message):''}</div></div><button class="secondary mini" data-ticket-open="${esc(t.id)}">View thread</button></div></div>`).join(''):empty('No tickets for this status');$$('[data-ticket-open]').forEach(b=>b.onclick=()=>openSupportTicket(b.dataset.ticketOpen).catch(e=>toast(e.message,false)));}
async function openSupportTicket(id){const d=await api('/api/owner/support-tickets/'+encodeURIComponent(id));state.selectedTicket=d.ticket;$("#supportThread").hidden=false;$("#supportThreadTitle").textContent=d.ticket.subject;$("#supportThreadMeta").textContent=`${d.ticket.display_name||'VIP user'} · ${d.ticket.user_id} · VIP ${num(d.ticket.vip_level)} · ${d.ticket.status} · ${time(d.ticket.created_at)}`;$("#supportMessages").innerHTML=(d.messages||[]).map(m=>`<div class="item-card"><div class="item-title">${m.sender_type==='staff'?'Support team':'VIP user'} · ${time(m.created_at)}</div><div>${esc(m.body)}</div></div>`).join('')||empty('No messages');$("#closeSupportTicket").hidden=d.ticket.status!=='open'||!can('support.close');$("#sendSupportReply").disabled=d.ticket.status!=='open'||!can('support.reply');$("#supportReply").disabled=d.ticket.status!=='open'||!can('support.reply');$("#supportThread").scrollIntoView({behavior:'smooth',block:'start'});}
async function sendSupportReply(){if(!state.selectedTicket)return;if(!can('support.reply'))return toast('Support reply permission required',false);const message=$("#supportReply").value.trim();if(!message)return toast('Write a reply first',false);await api(`/api/owner/support-tickets/${encodeURIComponent(state.selectedTicket.id)}/reply`,{method:'POST',body:JSON.stringify({message})});$("#supportReply").value='';toast('Reply sent');await openSupportTicket(state.selectedTicket.id);await loadSupport();}
async function closeSupportTicket(){if(!state.selectedTicket)return;if(!can('support.close'))return toast('Support close permission required',false);if(!confirm('Close this VIP support ticket?'))return;await api(`/api/owner/support-tickets/${encodeURIComponent(state.selectedTicket.id)}/close`,{method:'POST',body:'{}'});toast('Ticket closed');await openSupportTicket(state.selectedTicket.id);await loadSupport();}

async function saveUserOverrides(){
  if(!state.selectedUser)return toast("Select a user first",false);
  const payload={};
  if(can("users.override.invisible"))payload.invisible_id=$("#userInvisibleId").checked;
  if(can("users.override.lock_bypass"))payload.locked_room_bypass=$("#userLockedBypass").checked;
  if(can("users.wallet.ban"))payload.wallet_banned=$("#userWalletBanned").checked;
  if(can("users.wallet.freeze"))payload.wallet_frozen=$("#userWalletFrozen").checked;
  if(!Object.keys(payload).length)return toast("No Owner override permission selected",false);
  await api(`/api/owner/users/${encodeURIComponent(state.selectedUser.id)}/owner-overrides`,{
    method:"POST",body:JSON.stringify(payload),
  });
  toast("Owner overrides saved");
  await openUser(state.selectedUser.id);
}
async function toggleDeviceBan(deviceKey,currentlyBanned){
  if(!state.selectedUser)return;
  if(!can("users.device.ban"))return toast("Device-ban permission required",false);
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
  if(!can("users.search"))return toast("Users read permission required",false);
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
  if(!can("tags.view"))return;
  const d=await api("/api/owner/tags");
  const rows=d.tags||[];
  $("#ownerTagList").innerHTML=rows.length?rows.map(t=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(t.name)}${t.designation?" · "+esc(t.designation):""}</div><div class="item-meta">${esc(t.kind)} · ${esc(t.display_name||t.user_id)} · Public ID ${esc(t.public_id||"—")} · ${time(t.updated_at)}</div></div>${can("tags.remove")?`<button class="danger mini" data-tag-user="${esc(t.user_id)}" data-tag-id="${esc(t.tag_id)}">Remove</button>`:""}</div></div>`).join(""):empty("No custom tags / V Officials");
  $$("[data-tag-user]").forEach(b=>b.onclick=async()=>{if(!can("tags.remove"))return toast("Tag remove permission required",false);await api("/api/owner/tags/"+encodeURIComponent(b.dataset.tagUser)+"/"+encodeURIComponent(b.dataset.tagId),{method:"DELETE"});toast("Tag removed");await loadOwnerTags();});
}
async function loadMessaging(){
  renderSelectedMessageUsers();
  await loadOwnerTags();
}
async function sendOfficialMessage(allUsers=false){
  if(!can(allUsers?"messaging.send.all":"messaging.send.selected"))return toast("Messaging write permission required",false);
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
  if(!can("tags.apply"))return toast("Tags write permission required",false);
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
  if(!can("roles.view"))return;
  const kind=$("#rolePostKind").value;
  const d=await api("/api/owner/roles-posts?kind="+encodeURIComponent(kind));
  state.rolesPosts=d.items||[];
  $("#rolePostList").innerHTML=state.rolesPosts.length?state.rolesPosts.map(item=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name)} <span class="pill ${Number(item.enabled)?"active":"banned"}">${Number(item.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">${esc(item.id)} · ${esc(item.data?.details||"")}</div></div><div class="item-actions"><button class="secondary mini" data-role-post-edit="${esc(item.id)}">Edit</button><button class="danger mini" data-role-post-delete="${esc(item.id)}">Delete</button></div></div></div>`).join(""):empty("No roles/posts configured");
  $$("[data-role-post-edit]").forEach(b=>b.onclick=()=>{const item=state.rolesPosts.find(x=>x.id===b.dataset.rolePostEdit);if(!item)return;$("#rolePostId").value=item.id;$("#rolePostName").value=item.name||"";$("#rolePostOrder").value=Number(item.sort_order||0);$("#rolePostEnabled").checked=Number(item.enabled)!==0;$("#rolePostDetails").value=item.data?.details||"";});
  $$("[data-role-post-delete]").forEach(b=>b.onclick=async()=>{if(!confirm("Delete this "+kind+"?"))return;await api("/api/owner/roles-posts/"+encodeURIComponent(b.dataset.rolePostDelete)+"?kind="+encodeURIComponent(kind),{method:"DELETE"});toast("Deleted");await loadRolesPosts();});
}
async function saveRolePost(){
  if(!can("roles.save"))return toast("Roles write permission required",false);
  const kind=$("#rolePostKind").value;
  const name=$("#rolePostName").value.trim();
  if(!name)return toast("Name is required",false);
  await api("/api/owner/roles-posts?kind="+encodeURIComponent(kind),{method:"POST",body:JSON.stringify({id:$("#rolePostId").value.trim()||undefined,name,enabled:$("#rolePostEnabled").checked,sort_order:Number($("#rolePostOrder").value||0),data:{details:$("#rolePostDetails").value.trim()}})});
  toast((kind==="post"?"Post":"Role")+" saved");
  await loadRolesPosts();
}

async function loadBanners(){
  if(!can("banners.view"))return;
  const d=await api("/api/owner/banners");
  state.banners=d.banners||[];
  $("#bannerList").innerHTML=state.banners.length?state.banners.map(item=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name)} <span class="pill ${Number(item.enabled)?"active":"banned"}">${Number(item.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">${esc(item.id)} · ${esc(item.data?.asset_key||"")}${item.data?.link?" · "+esc(item.data.link):""}</div></div><div class="item-actions"><button class="secondary mini" data-banner-edit="${esc(item.id)}">Edit</button><button class="danger mini" data-banner-delete="${esc(item.id)}">Delete</button></div></div></div>`).join(""):empty("No banners configured");
  $$("[data-banner-edit]").forEach(b=>b.onclick=()=>{const x=state.banners.find(i=>i.id===b.dataset.bannerEdit);if(!x)return;$("#bannerId").value=x.id;$("#bannerName").value=x.name||"";$("#bannerAsset").value=x.data?.asset_key||"";$("#bannerLink").value=x.data?.link||"";$("#bannerStart").value=x.data?.starts_at||"";$("#bannerEnd").value=x.data?.ends_at||"";$("#bannerEnabled").checked=Number(x.enabled)!==0;});
  $$("[data-banner-delete]").forEach(b=>b.onclick=async()=>{if(!confirm("Delete this banner?"))return;await api("/api/owner/banners/"+encodeURIComponent(b.dataset.bannerDelete),{method:"DELETE"});toast("Banner deleted");await loadBanners();});
}
async function saveBanner(){
  if(!can("banners.save"))return toast("Banner write permission required",false);
  const name=$("#bannerName").value.trim();
  if(!name)return toast("Banner name is required",false);
  await api("/api/owner/banners",{method:"POST",body:JSON.stringify({id:$("#bannerId").value.trim()||undefined,name,asset_key:$("#bannerAsset").value.trim(),link:$("#bannerLink").value.trim(),starts_at:Number($("#bannerStart").value||0)||null,ends_at:Number($("#bannerEnd").value||0)||null,enabled:$("#bannerEnabled").checked})});
  toast("Banner saved");
  await loadBanners();
}

async function loadGames(){
  if(!can("games.view"))return;
  const userQuery=$("#gameInvestigationUser").value.trim();
  const d=await api("/api/owner/games"+(userQuery?"?user_id="+encodeURIComponent(userQuery):""));
  state.games=d.games||[];
  $("#gameList").innerHTML=state.games.length?state.games.map(item=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name)} <span class="pill ${Number(item.enabled)?"active":"banned"}">${Number(item.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">${esc(item.id)} · bet ${num(item.data?.min_bet||1)}–${num(item.data?.max_bet||0)}</div></div><button class="secondary mini" data-game-edit="${esc(item.id)}">Edit</button></div></div>`).join(""):empty("No game overrides configured");
  $("#gameStats").innerHTML=(d.stats||[]).length?(d.stats||[]).map(x=>`<div class="item-card"><div class="item-title">${esc(x.game_id)}</div><div class="item-meta">${num(x.bets)} bets · wagered ${num(x.wagered)} · payout ${num(x.payout)} · house result ${num(x.house_result)}</div></div>`).join(""):empty("No game-bet statistics yet");
  $$("[data-game-edit]").forEach(b=>b.onclick=()=>{const x=state.games.find(i=>i.id===b.dataset.gameEdit);if(!x)return;$("#gameConfigId").value=x.id;$("#gameConfigName").value=x.name||"";$("#gameMinBet").value=Number(x.data?.min_bet||1);$("#gameMaxBet").value=Number(x.data?.max_bet||1000000);$("#gameEnabled").checked=Number(x.enabled)!==0;});
  if(!userQuery){
    $("#gameUserStats").innerHTML=empty("Enter a user ID to investigate betting history");
  }else if(d.user_error==="user_not_found"){
    $("#gameUserStats").innerHTML=empty("User not found");
  }else{
    const inv=d.user_investigation;
    if(!inv){
      $("#gameUserStats").innerHTML=empty("No investigation data");
    }else{
      const u=inv.user||{};
      const summary=`<div class="item-card"><div class="item-title">${esc(u.display_name||"User")} · ID ${esc(u.public_id||u.id||"—")}</div><div class="item-meta">${num(inv.bet_count)} bets · wagered ${num(inv.wagered)} · payout ${num(inv.payout)} · house result ${num(inv.house_result)}</div></div>`;
      const perGame=(inv.by_game||[]).map(x=>`<div class="item-card"><div class="item-title">${esc(x.game_id)}</div><div class="item-meta">${num(x.bets)} bets · ${num(x.wagered)} wagered · ${num(x.payout)} payout · house result ${num(x.house_result)}</div></div>`).join("");
      const recent=(inv.recent||[]).map(x=>`<div class="item-card"><div class="item-title">${esc(x.game_id)} · ${time(x.created_at)}</div><div class="item-meta">Stake ${num(x.stake)} · result ${esc(x.result)} · payout ${num(x.payout)}</div></div>`).join("");
      $("#gameUserStats").innerHTML=summary+(perGame?`<h3>By Game</h3>${perGame}`:"")+(recent?`<h3>Recent Bets</h3>${recent}`:"");
    }
  }
}
async function saveGameConfig(){
  if(!can("games.configure"))return toast("Games write permission required",false);
  const id=$("#gameConfigId").value.trim();
  if(!id)return toast("Game ID is required",false);
  const min=Number($("#gameMinBet").value||1),max=Number($("#gameMaxBet").value||1);
  if(min<1||max<min)return toast("Bet limits are invalid",false);
  await api("/api/owner/games",{method:"POST",body:JSON.stringify({id,name:$("#gameConfigName").value.trim()||id,min_bet:min,max_bet:max,enabled:$("#gameEnabled").checked})});
  toast("Game config saved");
  await loadGames();
}

async function loadPolicies(){
  if(!can("policies.view"))return;
  const d=await api("/api/owner/policies");
  state.policies=d.policies||[];
  $("#policyList").innerHTML=state.policies.length?state.policies.map(p=>`<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(p.key)}</div><div class="item-meta">${esc(JSON.stringify(p.value))} · ${time(p.updated_at)}</div></div><div class="item-actions"><button class="secondary mini" data-policy-edit="${esc(p.key)}">Edit</button><button class="danger mini" data-policy-delete="${esc(p.key)}">Delete</button></div></div></div>`).join(""):empty("No custom allowed policies");
  $$("[data-policy-edit]").forEach(b=>b.onclick=()=>{const p=state.policies.find(x=>x.key===b.dataset.policyEdit);if(!p)return;$("#policyKey").value=p.key.replace(/^policy\./,"");$("#policyValue").value=JSON.stringify(p.value,null,2);});
  $$("[data-policy-delete]").forEach(b=>b.onclick=async()=>{if(!confirm("Delete this policy?"))return;await api("/api/owner/policies/"+encodeURIComponent(b.dataset.policyDelete),{method:"DELETE"});toast("Policy deleted");await loadPolicies();});
  await loadPricingOverrides();
}
async function savePolicy(){
  if(!can("policies.save"))return toast("Policies write permission required",false);
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
  if(!can("pricing.view"))return;
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
    if(!can("policies.save"))return toast("Policies write permission required",false);
    if(!confirm("Remove this per-user pricing override?"))return;
    await api("/api/owner/pricing-overrides/"+encodeURIComponent(b.dataset.pricingDeleteUser)+"/"+encodeURIComponent(b.dataset.pricingDeleteKind)+"/"+encodeURIComponent(b.dataset.pricingDeleteItem),{method:"DELETE"});
    toast("Pricing override removed");
    await loadPricingOverrides();
  });
}
async function savePricingOverride(){
  if(!can("policies.save"))return toast("Policies write permission required",false);
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

function globalThemeOutputSize(){
  const width=Number($("#globalThemeWidth").value||1080);
  const height=Number($("#globalThemeHeight").value||1920);
  if(!Number.isSafeInteger(width)||width<320||width>2160)throw new Error("Theme width must be 320–2160 px");
  if(!Number.isSafeInteger(height)||height<320||height>3840)throw new Error("Theme height must be 320–3840 px");
  return {width,height};
}

function drawThemeCover(ctx,img,width,height,zoom,cropX,cropY){
  const imageWidth=Number(img.naturalWidth||img.width||0);
  const imageHeight=Number(img.naturalHeight||img.height||0);
  if(!imageWidth||!imageHeight)return;
  const cover=Math.max(width/imageWidth,height/imageHeight);
  const scale=cover*Math.max(1,Number(zoom||1));
  const drawWidth=imageWidth*scale;
  const drawHeight=imageHeight*scale;
  const overflowX=Math.max(0,drawWidth-width);
  const overflowY=Math.max(0,drawHeight-height);
  const x=-overflowX*(Math.max(0,Math.min(100,Number(cropX||50)))/100);
  const y=-overflowY*(Math.max(0,Math.min(100,Number(cropY||50)))/100);
  ctx.drawImage(img,x,y,drawWidth,drawHeight);
}

function drawGlobalThemeCropPreview(){
  const canvas=$("#globalThemeCropCanvas");
  if(!canvas)return;
  let size;
  try{size=globalThemeOutputSize();}catch(_){size={width:1080,height:1920};}
  const ratio=size.width/size.height;
  let previewWidth=ratio>=1?480:Math.max(180,Math.round(480*ratio));
  let previewHeight=ratio>=1?Math.max(180,Math.round(480/ratio)):480;
  canvas.width=previewWidth;
  canvas.height=previewHeight;
  const ctx=canvas.getContext("2d");
  ctx.clearRect(0,0,previewWidth,previewHeight);
  ctx.fillStyle="#0b0c12";
  ctx.fillRect(0,0,previewWidth,previewHeight);
  if(!state.themeCropImage){
    ctx.fillStyle="rgba(255,255,255,.62)";
    ctx.font="14px sans-serif";
    ctx.textAlign="center";
    ctx.fillText("Choose a theme image",previewWidth/2,previewHeight/2);
    return;
  }
  drawThemeCover(
    ctx,
    state.themeCropImage,
    previewWidth,
    previewHeight,
    Number($("#globalThemeZoom").value||1),
    Number($("#globalThemeCropX").value||50),
    Number($("#globalThemeCropY").value||50)
  );
}

function clearThemeCropImage(){
  if(state.themeCropObjectUrl){
    URL.revokeObjectURL(state.themeCropObjectUrl);
    state.themeCropObjectUrl=null;
  }
  state.themeCropImage=null;
}

async function setThemeCropImageFromSource(src,{objectUrl=false}={}){
  clearThemeCropImage();
  if(objectUrl)state.themeCropObjectUrl=src;
  const image=new Image();
  await new Promise((resolve,reject)=>{
    image.onload=resolve;
    image.onerror=()=>reject(new Error("Theme image could not be opened"));
    image.src=src;
  });
  state.themeCropImage=image;
  drawGlobalThemeCropPreview();
}

async function chooseGlobalThemeImage(){
  const file=$("#globalThemeFile").files?.[0];
  if(!file)return;
  if(!["image/jpeg","image/png","image/webp"].includes(file.type)) {
    $("#globalThemeFile").value="";
    throw new Error("Choose a JPG, PNG or WebP theme image");
  }
  if(file.size<=0||file.size>15*1024*1024){
    $("#globalThemeFile").value="";
    throw new Error("Theme source image can be maximum 15 MB");
  }
  $("#globalThemeUploadStatus").textContent=file.name+" · "+Math.round(file.size/1024)+" KB";
  const url=URL.createObjectURL(file);
  await setThemeCropImageFromSource(url,{objectUrl:true});
}

function resetGlobalThemeCrop(){
  $("#globalThemeZoom").value="1";
  $("#globalThemeCropX").value="50";
  $("#globalThemeCropY").value="50";
  drawGlobalThemeCropPreview();
}

async function croppedGlobalThemeBlob(){
  const img=state.themeCropImage;
  if(!img)throw new Error("Choose a theme image first");
  const {width,height}=globalThemeOutputSize();
  const canvas=document.createElement("canvas");
  canvas.width=width;
  canvas.height=height;
  const ctx=canvas.getContext("2d");
  ctx.fillStyle="#000";
  ctx.fillRect(0,0,width,height);
  drawThemeCover(
    ctx,img,width,height,
    Number($("#globalThemeZoom").value||1),
    Number($("#globalThemeCropX").value||50),
    Number($("#globalThemeCropY").value||50)
  );
  for(const quality of [0.92,0.85,0.75,0.65]){
    const blob=await new Promise(resolve=>canvas.toBlob(resolve,"image/webp",quality));
    if(blob&&blob.size>0&&blob.size<=8*1024*1024)return blob;
  }
  throw new Error("Cropped theme is still over 8 MB. Use a smaller output size.");
}

async function uploadGlobalThemeImage(){
  if(!can("themes.global.save"))return toast("Global theme save permission required",false);
  const themeId=$("#globalThemeId").value.trim();
  if(!themeId)return toast("Enter Theme ID before uploading image",false);
  $("#globalThemeUploadStatus").textContent="Cropping and uploading…";
  const blob=await croppedGlobalThemeBlob();
  const res=await fetch("/api/owner/theme-media",{
    method:"PUT",
    headers:{
      authorization:"Bearer "+state.token,
      "content-type":"image/webp",
      "x-theme-id":themeId
    },
    body:blob
  });
  const data=await res.json().catch(()=>({ok:false,error:"invalid_response"}));
  if(!res.ok||!data.ok){
    const message=data.error==="theme_image_max_8mb"
      ?"Cropped theme image can be maximum 8 MB."
      :data.error==="theme_image_type_invalid"
        ?"Theme image must be JPG, PNG or WebP."
        :data.error==="theme_image_invalid"
          ?"Theme image file is invalid."
          :data.error;
    $("#globalThemeUploadStatus").textContent="";
    throw new Error(message||("HTTP "+res.status));
  }
  $("#globalThemeAsset").value=String(data.key||"");
  const {width,height}=globalThemeOutputSize();
  $("#globalThemeUploadStatus").textContent="Uploaded "+width+"×"+height+" to R2. Save theme to publish.";
  toast("Cropped theme image uploaded to R2");
}

function clearGlobalThemeForm(){
  $("#globalThemeId").value="";
  $("#globalThemeName").value="";
  $("#globalThemeFile").value="";
  $("#globalThemeAsset").value="";
  $("#globalThemeWidth").value="1080";
  $("#globalThemeHeight").value="1920";
  $("#globalThemeStart").value="";
  $("#globalThemeEnd").value="";
  $("#globalThemePermanent").checked=false;
  $("#globalThemeEnabled").checked=true;
  $("#globalThemeUploadStatus").textContent="";
  clearThemeCropImage();
  resetGlobalThemeCrop();
}

async function loadGlobalThemes(){
  if(!can("themes.global.view"))return;
  const d=await api("/api/owner/store?kind=theme");
  state.globalThemes=d.items||[];
  $("#globalThemeList").innerHTML=state.globalThemes.length?state.globalThemes.map(item=>{
    const data=item.data||{};
    const sizeText=data.output_width&&data.output_height?" · "+num(data.output_width)+"×"+num(data.output_height):"";
    return `<div class="item-card"><div class="item-main"><div><div class="item-title">${esc(item.name)} <span class="pill ${Number(item.enabled)?"active":"banned"}">${Number(item.enabled)?"Enabled":"Disabled"}</span></div><div class="item-meta">${esc(item.id)} · ${esc(data.asset_key||data.asset||"")}${sizeText} · ${data.permanent?"Permanent":((data.starts_at?time(data.starts_at):"Now")+" → "+(data.ends_at?time(data.ends_at):"No end"))}</div></div><div class="item-actions"><button class="secondary mini" data-global-theme-edit="${esc(item.id)}">Edit</button><button class="danger mini" data-global-theme-remove="${esc(item.id)}">Remove</button></div></div></div>`;
  }).join(""):empty("No global room themes");
  $$("[data-global-theme-edit]").forEach(b=>b.onclick=async()=>{
    const x=state.globalThemes.find(item=>item.id===b.dataset.globalThemeEdit);if(!x)return;
    const data=x.data||{};
    $("#globalThemeId").value=x.id;$("#globalThemeName").value=x.name||"";$("#globalThemeAsset").value=data.asset_key||data.asset||"";
    $("#globalThemeWidth").value=Number(data.output_width||1080);$("#globalThemeHeight").value=Number(data.output_height||1920);
    $("#globalThemeStart").value=data.starts_at||"";$("#globalThemeEnd").value=data.ends_at||"";
    $("#globalThemePermanent").checked=data.permanent===true||!data.ends_at;$("#globalThemeEnabled").checked=Number(x.enabled)!==0;
    $("#globalThemeFile").value="";$("#globalThemeUploadStatus").textContent="";
    resetGlobalThemeCrop();
    const key=data.asset_key||data.asset||"";
    if(key){
      try{
        await setThemeCropImageFromSource("/api/files?key="+encodeURIComponent(key));
        $("#globalThemeUploadStatus").textContent="Current theme loaded. Adjust size/crop and upload again to replace it.";
      }catch(_){
        clearThemeCropImage();
        drawGlobalThemeCropPreview();
      }
    }
  });
  $$("[data-global-theme-remove]").forEach(b=>b.onclick=async()=>{if(!confirm("Remove this global room theme?"))return;await api("/api/owner/store/theme/"+encodeURIComponent(b.dataset.globalThemeRemove),{method:"DELETE"});toast("Global theme removed");await loadGlobalThemes();});
  applyActionPermissions();
}
async function saveGlobalTheme(){
  if(!can("themes.global.save"))return toast("Global theme save permission required",false);
  const id=$("#globalThemeId").value.trim(),name=$("#globalThemeName").value.trim(),asset=$("#globalThemeAsset").value.trim();
  if(!id||!name||!asset)return toast("Theme ID, name and cropped image are required",false);
  const permanent=$("#globalThemePermanent").checked;
  const starts=Number($("#globalThemeStart").value||0)||null;
  const ends=permanent?null:(Number($("#globalThemeEnd").value||0)||null);
  if(!permanent&&starts&&ends&&ends<=starts)return toast("End time must be after start time",false);
  const {width,height}=globalThemeOutputSize();
  await api("/api/owner/store",{method:"POST",body:JSON.stringify({
    kind:"theme",id,name,price_coins:0,sort_order:0,enabled:$("#globalThemeEnabled").checked,
    data:{asset_key:asset,asset,starts_at:starts,ends_at:ends,permanent,output_width:width,output_height:height}
  })});
  toast("Global room theme saved");
  await loadGlobalThemes();
}

async function loadAudit(){
  if(!can("audit.view"))return;
  const d=await api("/api/owner/audit?limit=500");
  state.auditRows=d.audit||[];
  const canDelete=d.owner_can_delete===true||state.actor?.type==="owner";
  $("#clearAudit").hidden=!canDelete;
  $("#auditList").innerHTML=state.auditRows.length?`<div class="small-table">${state.auditRows.map(a=>`<div class="audit-row"><span>${time(a.created_at)}</span><span><b>${esc(a.action.replaceAll("_"," "))}</b><br><span class="muted">${esc(a.actor_type)} ${esc(a.actor_id)} → ${esc(a.target_type)} ${esc(a.target_id)}${a.summary?" · "+esc(a.summary):""}</span></span>${canDelete?`<button class="danger mini" data-audit-delete="${esc(a.id)}">Delete</button>`:""}</div>`).join("")}</div>`:empty("No audit records yet");
  $$("[data-audit-delete]").forEach(b=>b.onclick=async()=>{if(!confirm("Delete this audit record?"))return;await api("/api/owner/audit/"+encodeURIComponent(b.dataset.auditDelete),{method:"DELETE"});toast("Audit record deleted");await loadAudit();});
}
function exportAuditCsv(){
  if(!can("audit.export"))return toast("Audit export permission required",false);
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

$("#ownerLoginTab").onclick=()=>setLoginMode("owner",true);
$("#staffLoginTab").onclick=()=>setLoginMode("staff",true);
$("#connect").onclick=()=>connect().catch(e=>$("#loginStatus").textContent=e.message);
$("#loginEmail").addEventListener("keydown",e=>{if(e.key==="Enter")$("#loginPassword").focus();});
$("#loginPassword").addEventListener("keydown",e=>{if(e.key==="Enter")connect().catch(x=>$("#loginStatus").textContent=x.message);});
$("#logout").onclick=()=>{
  const previousType=state.actor?.type;
  state.token="";
  state.actor=null;
  state.loginMode=previousType==="staff"?"staff":"owner";
  sessionStorage.removeItem("dvxOwnerToken");
  showApp(false);
  setLoginMode(state.loginMode,true);
  $("#loginPassword").value="";
};
$$('.nav-btn').forEach(b=>b.onclick=()=>setView(b.dataset.view));
$$('[data-catalog-shortcut]').forEach(b=>b.onclick=()=>{$("#catalogKind").value=b.dataset.catalogShortcut;clearCatalogForm();loadCatalog().catch(e=>toast(e.message,false));});
$("#refreshCurrent").onclick=()=>loadView(state.view).catch(e=>toast(e.message,false));
$("#searchUsers").onclick=()=>loadUsers().catch(e=>toast(e.message,false));$("#userSearch").addEventListener('keydown',e=>{if(e.key==='Enter')loadUsers().catch(x=>toast(x.message,false));});
$("#saveUserOverrides").onclick=()=>saveUserOverrides().catch(e=>toast(e.message,false));
$("#loadOwnerMessageInbox").onclick=()=>loadOwnerMessageInbox().catch(e=>toast(e.message,false));
$("#closeOwnerMessageThread").onclick=()=>{$("#ownerMessageThreadPanel").hidden=true;state.ownerMessageThreadOtherId=null;};
$("#reloadNotifications").onclick=()=>loadNotifications().catch(e=>toast(e.message,false));
$("#searchMessageUsers").onclick=()=>searchMessagingUsers().catch(e=>toast(e.message,false));$("#messageUserSearch").addEventListener("keydown",e=>{if(e.key==="Enter")searchMessagingUsers().catch(x=>toast(x.message,false));});
$("#sendOfficialSelected").onclick=()=>sendOfficialMessage(false).catch(e=>toast(e.message,false));$("#sendOfficialAll").onclick=()=>sendOfficialMessage(true).catch(e=>toast(e.message,false));$("#applyOwnerTag").onclick=()=>applyOwnerTag().catch(e=>toast(e.message,false));

$("#closeUser").onclick=()=>{$("#userEditor").hidden=true;state.selectedUser=null;};$("#saveUserProfile").onclick=()=>saveUserProfile().catch(e=>toast(e.message,false));$("#saveModeration").onclick=()=>saveModeration().catch(e=>toast(e.message,false));$("#savePublicId").onclick=()=>savePublicId().catch(e=>toast(e.message,false));$("#applyWallet").onclick=()=>applyWallet().catch(e=>toast(e.message,false));$("#applyRoleWallet").onclick=()=>applyRoleWallet().catch(e=>toast(e.message,false));$("#roleWalletType").onchange=()=>{$("#roleWalletBalance").textContent="Selected "+($("#roleWalletType").value||"role")+" wallet. Enter a coin change or change ban status and apply.";$("#roleWalletBanned").checked=false;};
$("#searchRooms").onclick=()=>loadRooms().catch(e=>toast(e.message,false));$("#roomSearch").addEventListener('keydown',e=>{if(e.key==='Enter')loadRooms().catch(x=>toast(x.message,false));});
$("#closeRoomInvestigation").onclick=()=>{$("#roomInvestigation").hidden=true;state.selectedRoomId=null;};$("#saveOwnerRoomMedia").onclick=()=>saveOwnerRoomMedia().catch(e=>toast(e.message,false));$("#saveOwnerRoomTheme").onclick=()=>saveOwnerRoomTheme().catch(e=>toast(e.message,false));
$("#reloadGlobalThemes").onclick=()=>loadGlobalThemes().catch(e=>toast(e.message,false));$("#saveGlobalTheme").onclick=()=>saveGlobalTheme().catch(e=>toast(e.message,false));
$("#globalThemeFile").onchange=()=>chooseGlobalThemeImage().catch(e=>toast(e.message,false));
$("#globalThemeWidth").oninput=drawGlobalThemeCropPreview;$("#globalThemeHeight").oninput=drawGlobalThemeCropPreview;
$("#globalThemeZoom").oninput=drawGlobalThemeCropPreview;$("#globalThemeCropX").oninput=drawGlobalThemeCropPreview;$("#globalThemeCropY").oninput=drawGlobalThemeCropPreview;
$("#resetGlobalThemeCrop").onclick=resetGlobalThemeCrop;
$("#uploadGlobalThemeImage").onclick=()=>uploadGlobalThemeImage().catch(e=>toast(e.message,false));
$("#clearGlobalTheme").onclick=clearGlobalThemeForm;
drawGlobalThemeCropPreview();

$("#rolePostKind").onchange=()=>loadRolesPosts().catch(e=>toast(e.message,false));$("#reloadRolesPosts").onclick=()=>loadRolesPosts().catch(e=>toast(e.message,false));$("#saveRolePost").onclick=()=>saveRolePost().catch(e=>toast(e.message,false));
$("#reloadBanners").onclick=()=>loadBanners().catch(e=>toast(e.message,false));$("#saveBanner").onclick=()=>saveBanner().catch(e=>toast(e.message,false));
$("#reloadGames").onclick=()=>loadGames().catch(e=>toast(e.message,false));$("#saveGameConfig").onclick=()=>saveGameConfig().catch(e=>toast(e.message,false));$("#loadGameInvestigation").onclick=()=>loadGames().catch(e=>toast(e.message,false));$("#gameInvestigationUser").addEventListener("keydown",e=>{if(e.key==="Enter")loadGames().catch(x=>toast(x.message,false));});
$("#reloadPolicies").onclick=()=>loadPolicies().catch(e=>toast(e.message,false));$("#savePolicy").onclick=()=>savePolicy().catch(e=>toast(e.message,false));$("#reloadPricingOverrides").onclick=()=>loadPricingOverrides().catch(e=>toast(e.message,false));$("#savePricingOverride").onclick=()=>savePricingOverride().catch(e=>toast(e.message,false));$("#clearPricingOverride").onclick=clearPricingOverride;$("#pricingKind").onchange=()=>{updatePricingFreeState();loadPricingOverrides().catch(e=>toast(e.message,false));};

$("#searchEconomyUsers").onclick=()=>searchEconomyUsers().catch(e=>toast(e.message,false));$("#economyUserSearch").addEventListener("keydown",e=>{if(e.key==="Enter")searchEconomyUsers().catch(x=>toast(x.message,false));});$("#saveEconomyPublicId").onclick=()=>saveEconomyPublicId().catch(e=>toast(e.message,false));$("#saveCoinRate").onclick=()=>saveCoinRate().catch(e=>toast(e.message,false));
$("#vipRuleLevel").onchange=()=>{const rule=state.vipRules.find(x=>Number(x.level)===Number($("#vipRuleLevel").value));if(rule)fillVipRuleForm(rule);};$("#reloadVipRules").onclick=()=>loadVipRules().catch(e=>toast(e.message,false));$("#saveVipRule").onclick=()=>saveVipRule().catch(e=>toast(e.message,false));$("#resetVipRule").onclick=()=>resetVipRule().catch(e=>toast(e.message,false));
$("#reloadGifts").onclick=()=>loadGifts().catch(e=>toast(e.message,false));
$("#uploadGiftVideo").onclick=()=>uploadGiftVideo().catch(e=>{ $("#giftVideoStatus").textContent=""; toast(e.message,false); });
$("#removeGiftVideo").onclick=()=>{ $("#giftVideoKey").value=""; $("#giftVideoFile").value=""; $("#giftVideoStatus").textContent="Video removed from this gift after Save"; };$("#saveGift").onclick=()=>saveGift().catch(e=>toast(e.message,false));$("#clearGift").onclick=clearGiftForm;
$("#assetKind").onchange=()=>{clearAssetForm();loadAssets().catch(e=>toast(e.message,false));};$("#reloadAssets").onclick=()=>loadAssets().catch(e=>toast(e.message,false));$("#saveAsset").onclick=()=>saveAsset().catch(e=>toast(e.message,false));$("#clearAsset").onclick=clearAssetForm;
$("#storeKind").onchange=()=>{clearStoreForm();loadStore().catch(e=>toast(e.message,false));};$("#reloadStore").onclick=()=>loadStore().catch(e=>toast(e.message,false));$("#saveStoreItem").onclick=()=>saveStoreItem().catch(e=>toast(e.message,false));$("#clearStoreItem").onclick=clearStoreForm;
$("#catalogKind").onchange=()=>{clearCatalogForm();loadCatalog().catch(e=>toast(e.message,false));};$("#reloadTreasury").onclick=()=>loadWallets().catch(e=>toast(e.message,false));$("#treasuryAdd").onclick=()=>treasuryAction("add").catch(e=>toast(e.message,false));$("#treasuryDeduct").onclick=()=>treasuryAction("deduct").catch(e=>toast(e.message,false));$("#treasurySend").onclick=()=>treasuryAction("send").catch(e=>toast(e.message,false));$("#saveCatalog").onclick=()=>saveCatalog().catch(e=>toast(e.message,false));$("#clearCatalog").onclick=clearCatalogForm;$("#reloadCatalog").onclick=()=>loadCatalog().catch(e=>toast(e.message,false));
$("#saveMaintenance").onclick=()=>saveMaintenance().catch(e=>toast(e.message,false));$("#saveAnnouncement").onclick=()=>saveAnnouncement().catch(e=>toast(e.message,false));$("#clearAnnouncement").onclick=clearAnnouncementForm;$("#createStaff").onclick=()=>createStaff().catch(e=>toast(e.message,false));$("#reloadAudit").onclick=()=>loadAudit().catch(e=>toast(e.message,false));$("#exportAudit").onclick=exportAuditCsv;$("#clearAudit").onclick=()=>clearAudit().catch(e=>toast(e.message,false));
$("#clearPermissions").onclick=()=>{$$("#staffPermissions input").forEach(x=>x.checked=false);};$("#cancelStaffEdit").onclick=cancelStaffEdit;
$("#supportStatus").onchange=()=>loadSupport().catch(e=>toast(e.message,false));$("#sendSupportReply").onclick=()=>sendSupportReply().catch(e=>toast(e.message,false));$("#closeSupportTicket").onclick=()=>closeSupportTicket().catch(e=>toast(e.message,false));

const permissionObserver=new MutationObserver(()=>applyActionPermissions());
permissionObserver.observe(document.body,{childList:true,subtree:true});
showApp(false);
setLoginMode(state.loginMode,false);
if(state.token){
  connectWithToken(state.token);
}

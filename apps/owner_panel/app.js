const $=s=>document.querySelector(s);
const state={token:sessionStorage.getItem("dvxOwnerToken")||""};

function auth(){return {"authorization":"Bearer "+state.token,"content-type":"application/json"};}
async function api(path,options={}){
  const res=await fetch(path,{...options,headers:{...auth(),...(options.headers||{})}});
  const data=await res.json().catch(()=>({ok:false,error:"invalid_response"}));
  if(!res.ok) throw new Error(data.error||("HTTP "+res.status));
  return data;
}
function showDashboard(on){$("#loginCard").hidden=on;$("#dashboard").hidden=!on;}
function number(v){return Number(v||0).toLocaleString();}

async function load(){
  const data=await api("/api/owner/overview");
  $("#users").textContent=number(data.stats.users);
  $("#rooms").textContent=number(data.stats.rooms);
  $("#online").textContent=number(data.stats.online);
  $("#coins").textContent=number(data.stats.coins);
  $("#roomList").innerHTML="";
  for(const room of data.rooms){
    const row=document.createElement("div"); row.className="room";
    const info=document.createElement("div");
    info.innerHTML="<strong></strong><br><small></small>";
    info.querySelector("strong").textContent=room.name;
    info.querySelector("small").textContent="ID "+room.id+" • "+room.online+" online • "+room.seat_count+" seats";
    const owner=document.createElement("span"); owner.textContent=room.owner_name||room.owner_user_id;
    const lock=document.createElement("button"); lock.className="ghost";
    lock.textContent=Number(room.locked)===1?"Unlock":"Lock";
    lock.onclick=async()=>{await api("/api/owner/room-lock",{method:"POST",body:JSON.stringify({room_id:room.id,locked:Number(room.locked)!==1})});await load();};
    row.append(info,owner,lock); $("#roomList").append(row);
  }
}

$("#connect").onclick=async()=>{
  state.token=$("#token").value.trim();
  if(!state.token)return;
  sessionStorage.setItem("dvxOwnerToken",state.token);
  $("#loginStatus").textContent="Checking…";
  try{await load();showDashboard(true);$("#loginStatus").textContent="";}
  catch(e){$("#loginStatus").textContent=e.message;state.token="";sessionStorage.removeItem("dvxOwnerToken");}
};
$("#logout").onclick=()=>{state.token="";sessionStorage.removeItem("dvxOwnerToken");showDashboard(false);};
$("#refresh").onclick=()=>load().catch(e=>alert(e.message));
$("#searchUser").onclick=async()=>{
  const id=$("#userId").value.trim(); if(!id)return;
  try{const data=await api("/api/owner/users/"+encodeURIComponent(id));$("#userResult").textContent=JSON.stringify(data.user,null,2);}
  catch(e){$("#userResult").textContent=e.message;}
};
if(state.token){load().then(()=>showDashboard(true)).catch(()=>showDashboard(false));}

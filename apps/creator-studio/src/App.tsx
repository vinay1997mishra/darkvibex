import { useEffect, useMemo, useRef, useState } from 'react';
import { ThreeStage, type StageHandle, type QualityCheckResult, type ScenePart } from './ThreeStage';
import { AdvancedComposer, type ComposerApplyPayload, type ComposerCategory } from './AdvancedComposer';
import {
  WandSparkles, Gift, CircleUserRound, CarFront, MessageCircle, Sparkles,
  Download, Play, RotateCcw, LoaderCircle, Check, Layers3, Volume2, VolumeX,
  ShieldCheck, Upload, MonitorPlay, FileUp, X, CheckCircle2, AlertTriangle
} from 'lucide-react';

type Kind = 'gift' | 'frame' | 'entry' | 'vehicle' | 'bubble';
type Design = {
  title: string;
  concept: string;
  icon: string;
  primaryColor: string;
  secondaryColor: string;
  motion: string;
  particles: string;
  shape: string;
  background: string;
  durationSeconds: number;
  loop: boolean;
  sound: boolean;
  rarity: string;
  previewText: string;
};
const kinds: { id: Kind; label: string; icon: typeof Gift; detail: string }[] = [
  { id: 'gift', label: 'Gift effect', icon: Gift, detail: 'Send animation / reveal' },
  { id: 'frame', label: 'Profile frame', icon: CircleUserRound, detail: 'Round DP border animation' },
  { id: 'entry', label: 'Entry effect', icon: Sparkles, detail: 'Room / video arrival' },
  { id: 'vehicle', label: 'Vehicle entry', icon: CarFront, detail: 'Car, bike, dragon, anything' },
  { id: 'bubble', label: 'Chat bubble', icon: MessageCircle, detail: 'Message bubble + effects' },
];
const initial: Record<Kind, Design> = {
  gift: { title: 'Cosmic Heart Gift', concept: 'A premium glowing heart opens into a star field', icon: '💎', primaryColor: '#8ceaff', secondaryColor: '#9066ff', motion: 'burst', particles: 'stars', shape: 'crystal', background: 'cosmic', durationSeconds: 5, loop: false, sound: true, rarity: 'Legendary', previewText: 'A gift from the stars' },
  frame: { title: 'Royal Halo Frame', concept: 'Circular royal frame with orbiting jewels', icon: '👑', primaryColor: '#ffd66b', secondaryColor: '#a46cff', motion: 'orbit', particles: 'sparkles', shape: 'round', background: 'royal', durationSeconds: 4, loop: true, sound: false, rarity: 'Legendary', previewText: 'PROFILE' },
  entry: { title: 'Aurora Portal Entry', concept: 'A portal opens with aurora ribbons and a light sweep', icon: '🌌', primaryColor: '#8cfff0', secondaryColor: '#9a72ff', motion: 'portal', particles: 'aurora', shape: 'portal', background: 'cosmic', durationSeconds: 6, loop: false, sound: true, rarity: 'Epic', previewText: 'PLAYER ARRIVED' },
  vehicle: { title: 'Nebula Supercar', concept: 'Futuristic supercar enters through a neon trail', icon: '🏎️', primaryColor: '#70e9ff', secondaryColor: '#985cff', motion: 'drive', particles: 'trail', shape: 'vehicle', background: 'night', durationSeconds: 7, loop: false, sound: true, rarity: 'Mythic', previewText: 'GRAND ARRIVAL' },
  bubble: { title: 'Royal Chat Bubble', concept: 'Rounded glass bubble with a moving rainbow edge', icon: '💬', primaryColor: '#9deaff', secondaryColor: '#ca8cff', motion: 'float', particles: 'sparkles', shape: 'bubble', background: 'glass', durationSeconds: 3, loop: false, sound: false, rarity: 'Rare', previewText: 'Hey! Welcome to the room ✨' },
};
const esc = (value: string) => value.replace(/[<>&"]/g, ch => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;' }[ch] || ch));

const readVideoDuration = (file: File) => new Promise<number>((resolve, reject) => {
  const objectUrl = URL.createObjectURL(file);
  const video = document.createElement('video');
  video.preload = 'metadata';
  const cleanup = () => {
    URL.revokeObjectURL(objectUrl);
    video.onloadedmetadata = null;
    video.onerror = null;
  };
  video.onloadedmetadata = () => {
    const seconds = video.duration;
    cleanup();
    if (Number.isFinite(seconds) && seconds > 0) resolve(seconds);
    else reject(new Error('Video duration could not be read. Export the clip again and retry.'));
  };
  video.onerror = () => {
    cleanup();
    reject(new Error('Video metadata could not be read. Choose a valid MP4/WebM clip.'));
  };
  video.src = objectUrl;
});
function App() {
  const [kind, setKind] = useState<Kind>('gift');
  const [designs, setDesigns] = useState<Record<Kind, Design>>(initial);
  const [prompt, setPrompt] = useState('Make a premium 3D neon dragon gift that flies out of a purple portal, circles once, then bursts into blue crystal particles. Dark royal style, smooth cinematic animation.');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');
  const [soundOn, setSoundOn] = useState(true);
  const [showSpec, setShowSpec] = useState(false);
  const stageRef = useRef<StageHandle>(null);
  const appPreviewRef = useRef<StageHandle>(null);
  const [exporting3d, setExporting3d] = useState(false);
  const [modelUrl, setModelUrl] = useState<string | undefined>();
  const [modelName, setModelName] = useState('');
  const [qualityState, setQualityState] = useState<'not-run' | 'running' | 'passed' | 'failed'>('not-run');
  const [qualityResults, setQualityResults] = useState<QualityCheckResult[]>([]);
  const [showAppPreview, setShowAppPreview] = useState(false);
  const [showAdvancedComposer, setShowAdvancedComposer] = useState(true);
  const [apiBase, setApiBase] = useState(() => {
    const { protocol, hostname, origin } = window.location;
    if (protocol === 'https:' && (hostname.endsWith('.workers.dev') || hostname === 'darkvibex.pages.dev')) return origin;
    return 'https://darkvibex-api.mishrajii7991.workers.dev';
  });
  const [ownerToken, setOwnerToken] = useState(() => {
    try { return window.sessionStorage.getItem('dvxOwnerToken') || ''; } catch { return ''; }
  });
  const [uploadFile, setUploadFile] = useState<File | null>(null);
  const [assetId, setAssetId] = useState('cosmic-heart-gift');
  const [assetPrice, setAssetPrice] = useState('0');
  const [giftCategory, setGiftCategory] = useState('normal');
  const [uploadBusy, setUploadBusy] = useState(false);
  const [uploadKey, setUploadKey] = useState('');
  const [customParts, setCustomParts] = useState<ScenePart[]>([]);
  useEffect(() => () => { if (modelUrl?.startsWith('blob:')) URL.revokeObjectURL(modelUrl); }, [modelUrl]);
  const design = designs[kind];
  const applyComposer = (payload: ComposerApplyPayload) => {
    const kindByCategory: Record<ComposerCategory, Kind> = {
      entry: 'entry',
      vehicle: 'vehicle',
      animal: 'vehicle',
      frame: 'frame',
      'profile-card': 'frame',
      'rocket-banner': 'entry',
      'gift-banner': 'gift',
      'game-banner': 'entry',
      gift: 'gift',
      bubble: 'bubble',
      medal: 'gift',
    };
    const nextKind = kindByCategory[payload.category];
    setKind(nextKind);
    setDesigns(old => ({
      ...old,
      [nextKind]: {
        ...old[nextKind],
        title: payload.design.title,
        concept: payload.design.concept,
        icon: payload.design.icon,
        primaryColor: payload.design.primaryColor,
        secondaryColor: payload.design.secondaryColor,
        motion: payload.design.motion,
        particles: payload.design.particles,
        durationSeconds: Math.max(2, Math.min(15, payload.design.durationSeconds)),
        loop: payload.design.loop,
        rarity: payload.design.rarity,
        previewText: payload.design.previewText,
      },
    }));
    setPrompt(payload.design.concept);
    setAssetId(nextKind + '-' + payload.design.title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 65));
    setCustomParts(payload.parts);
    setQualityState('not-run');
    setQualityResults([]);
    setUploadFile(null);
    setUploadKey('');
    setShowAdvancedComposer(false);
    setNotice('Advanced composition loaded into the main creator. Run the quality test, export the final asset, then choose that file for publishing.');
  };
  const update = (patch: Partial<Design>) => {
    setDesigns(old => ({ ...old, [kind]: { ...old[kind], ...patch } }));
    setQualityState('not-run'); setQualityResults([]); setUploadKey('');
  };
  const selectKind = (next: Kind) => {
    setKind(next);
    setPrompt(next === 'frame' ? 'Create a perfectly round premium animated 3D profile frame, royal purple and electric blue, orbiting diamonds, never egg-shaped.' : next === 'vehicle' ? 'Create a premium futuristic sports car entrance, glossy 3D body, blue-purple neon underglow, drives in and stops with a particle trail.' : next === 'entry' ? 'Create a dramatic cinematic portal entry with swirling energy, a light sweep and floating particles.' : next === 'bubble' ? 'Create a floating glass chat bubble with a moving neon outline and soft sparkles.' : 'Make a premium 3D neon dragon gift that flies out of a purple portal, circles once, then bursts into blue crystal particles. Dark royal style, smooth cinematic animation.');
    setAssetId(next + '-' + initial[next].title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''));
    setCustomParts([]);
    setQualityState('not-run'); setQualityResults([]); setUploadFile(null); setUploadKey('');
    setModelUrl(currentUrl => { if (currentUrl?.startsWith('blob:')) URL.revokeObjectURL(currentUrl); return undefined; });
    setModelName(''); setNotice('');
  };
  const handleModelFile = (file?: File) => {
    if (!file) return;
    if (!/\.glb$/i.test(file.name)) { setNotice('Realistic model preview ke liye single-file .glb upload karo.'); return; }
    const nextUrl = URL.createObjectURL(file);
    setModelUrl(currentUrl => { if (currentUrl?.startsWith('blob:')) URL.revokeObjectURL(currentUrl); return nextUrl; });
    setModelName(file.name); setQualityState('not-run'); setQualityResults([]);
    setNotice('GLB model load ho raha hai—preview aur Quality Test run karke verify karo.');
  };
  const runQualityTest = async () => {
    setQualityState('running'); setQualityResults([]); setNotice('Final export checks chal rahe hain: WebGL, geometry, transparent PNG, GLB integrity aur short WebM capture.');
    try {
      if (!stageRef.current) throw new Error('3D preview abhi load ho raha hai.');
      const results = await stageRef.current.qualityCheck();
      setQualityResults(results);
      const failed = results.some(item => item.status === 'fail');
      setQualityState(failed ? 'failed' : 'passed');
      setNotice(failed ? 'Quality gate fail hua. Red checks ko fix karke dobara test karo; upload disabled rahega.' : results.some(item => item.status === 'warn') ? 'Core quality checks pass; video codec limitation warning ke roop mein dikhi hai. Uploaded file format phir bhi server par validate hoga.' : 'Quality gate pass. Preview approve karne ke baad selected asset ko DarkVibeX R2 aur live catalog mein bhej sakte ho.');
    } catch (error) {
      setQualityState('failed'); setNotice(error instanceof Error ? error.message : 'Quality test nahi chal paya.');
    }
  };
  const uploadToDarkVibeX = async () => {
    if (qualityState !== 'passed') { setNotice('Pehle preview dekho aur Final Quality Test pass karo.'); return; }
    if (!uploadFile) { setNotice('Upload karne ke liye exported GLB / MP4 / WebM / PNG / WebP file choose karo.'); return; }
    if (!ownerToken.trim()) { setNotice('Owner Panel ka active session token enter karo. Google password yahan mat dalna.'); return; }
    const id = assetId.trim().toLowerCase().replace(/[^a-z0-9_-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80);
    if (!id) { setNotice('Asset ID required hai.'); return; }
    let base = '';
    try {
      const parsed = new URL(apiBase.trim().replace(/\/+$/, ''));
      if (parsed.protocol !== 'https:' || !parsed.hostname.includes('darkvibex') || !(parsed.hostname.endsWith('.workers.dev') || parsed.hostname === 'darkvibex.pages.dev')) {
        throw new Error('Security check: HTTPS DarkVibeX workers.dev ya darkvibex.pages.dev URL use karo.');
      }
      base = parsed.origin;
    } catch (error) { setNotice(error instanceof Error ? error.message : 'Worker URL invalid hai.'); return; }
    const ext = (uploadFile.name.split('.').pop() || '').toLowerCase();
    const extensionTypes: Record<string, string> = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp', mp4: 'video/mp4', webm: 'video/webm', glb: 'model/gltf-binary' };
    const type = extensionTypes[ext] || uploadFile.type;
    const limits: Record<string, number> = { 'image/jpeg': 5 * 1024 * 1024, 'image/png': 5 * 1024 * 1024, 'image/webp': 5 * 1024 * 1024, 'video/mp4': 11 * 1024 * 1024, 'video/webm': 11 * 1024 * 1024, 'model/gltf-binary': 25 * 1024 * 1024 };
    if (!limits[type]) { setNotice('Allowed formats: JPG, PNG, WebP (5 MB), MP4/WebM (11 MB), GLB (25 MB).'); return; }
    if (uploadFile.size <= 0 || uploadFile.size > limits[type]) { setNotice(`File limit exceeded. ${Math.round(limits[type] / 1024 / 1024)} MB max for ${type}.`); return; }
    setUploadBusy(true); setUploadKey(''); setNotice('Owner session verify ho raha hai; phir media R2 par upload aur catalog save hoga.');
    const headers = { authorization: 'Bearer ' + ownerToken.trim() };
    try {
      const sessionResponse = await fetch(base + '/api/owner/session', { headers });
      const session = await sessionResponse.json().catch(() => ({ ok: false, error: 'invalid_response' }));
      if (!sessionResponse.ok || !session.ok) throw new Error(sessionResponse.status === 401 ? 'Owner session invalid/expired. Owner Panel mein dobara sign in karo.' : `Owner session check failed: ${session.error || sessionResponse.status}`);
      const binary = await uploadFile.arrayBuffer();
      const bytes = new Uint8Array(binary);
      const ascii = (from: number, to: number) => String.fromCharCode(...bytes.slice(from, to));
      let signatureValid = false;
      if (type === 'image/png') signatureValid = bytes.length >= 8 && bytes[0] === 137 && ascii(1, 4) === 'PNG';
      else if (type === 'image/jpeg') signatureValid = bytes.length >= 3 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
      else if (type === 'image/webp') signatureValid = bytes.length >= 12 && ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WEBP';
      else if (type === 'video/mp4') signatureValid = bytes.length >= 12 && ascii(4, 8) === 'ftyp';
      else if (type === 'video/webm') signatureValid = bytes.length >= 4 && bytes[0] === 0x1a && bytes[1] === 0x45 && bytes[2] === 0xdf && bytes[3] === 0xa3;
      else if (type === 'model/gltf-binary') signatureValid = bytes.length >= 12 && ascii(0, 4) === 'glTF' && new DataView(binary).getUint32(4, true) === 2 && new DataView(binary).getUint32(8, true) === bytes.byteLength;
      if (!signatureValid) throw new Error('File signature check failed. Please choose a valid, complete export of the selected type.');
      if (type === 'video/mp4' || type === 'video/webm') {
        const actualDuration = await readVideoDuration(uploadFile);
        const maxDuration = kind === 'gift' ? Math.min(5, design.durationSeconds) : design.durationSeconds;
        if (actualDuration > maxDuration + 0.12) {
          const message = kind === 'gift'
            ? 'Animated gift videos must be 5 seconds or less. Trim the clip and export it again.'
            : 'Video is ' + actualDuration.toFixed(1) + ' seconds; this design allows ' + maxDuration + ' seconds or less. Trim it and retry.';
          throw new Error(message);
        }
      }

      const uploadResponse = await fetch(base + '/api/owner/creator-media', {
        method: 'PUT',
        headers: { ...headers, 'content-type': type, 'x-asset-id': id, 'x-asset-kind': kind },
        body: uploadFile
      });
      const uploaded = await uploadResponse.json().catch(() => ({ ok: false, error: 'invalid_response' }));
      if (!uploadResponse.ok || !uploaded.ok || !uploaded.key) {
        const errorText = uploaded.error === 'unauthorized' ? 'Owner session expired.' : uploaded.error === 'creator_asset_too_large' ? 'Selected file is larger than DarkVibeX server limit.' : uploaded.error === 'creator_asset_kind_invalid' ? 'This asset category is not supported by the current DarkVibeX Worker.' : uploaded.error || `Upload failed (${uploadResponse.status}).`;
        throw new Error(errorText);
      }
      const key = String(uploaded.key);
      setUploadKey(key);
      const isImage = type.startsWith('image/');
      const isVideo = type.startsWith('video/');
      const isGlb = type === 'model/gltf-binary';
      const itemData = {
        asset_key: isImage ? key : '', asset: isImage ? key : '',
        video_key: isVideo ? key : '', glb_key: isGlb ? key : '', media_type: type,
        animation_type: design.motion, animation_ms: design.durationSeconds * 1000,
        min_vip_level: 0, vip_level: 0, tier: design.rarity === 'Mythic' ? 3 : design.rarity === 'Legendary' ? 2 : 1,
        category: kind === 'gift' ? giftCategory : kind, description: design.concept,
        creator_studio: true, creator_design_title: design.title
      };
      const saveResponse = await fetch(base + '/api/owner/store', {
        method: 'POST',
        headers: { ...headers, 'content-type': 'application/json' },
        body: JSON.stringify({ kind, id, name: design.title || id, price_coins: Math.max(0, Number(assetPrice) || 0), sort_order: 0, enabled: true, data: itemData })
      });
      const saved = await saveResponse.json().catch(() => ({ ok: false, error: 'invalid_response' }));
      if (!saveResponse.ok || !saved.ok) throw new Error(`File R2 par upload ho gayi (${key}), lekin live catalog save nahi hua: ${saved.error || saveResponse.status}. Owner Panel se asset key manually save kar sakte ho.`);
      setNotice(`Success: ${key} R2 par upload hua aur ${kind} catalog mein ${id} ke naam se save/publish ho gaya.`);
      setOwnerToken('');
    } catch (error) {
      setNotice(error instanceof Error ? error.message : 'Upload failed. Worker URL, CORS aur Owner permission check karo.');
    } finally { setUploadBusy(false); }
  };
  const generate = () => {
    const brief = prompt.trim();
    if (!brief) { setNotice('Pehle apna design brief likho.'); return; }
    setBusy(true);
    const lower = brief.toLowerCase();
    const colors: Record<string, string> = { blue: '#55cfff', cyan: '#55f1ed', purple: '#9a72ff', violet: '#9a72ff', pink: '#ff70c8', red: '#ff526d', green: '#61edb1', gold: '#ffd66b', golden: '#ffd66b', orange: '#ff9a55', white: '#f4f5ff', silver: '#d9e1f4' };
    const colorNames = Object.keys(colors).filter(name => lower.includes(name));
    const primaryColor = colorNames.length ? colors[colorNames[0]] : design.primaryColor;
    const secondaryColor = colorNames.length > 1 ? colors[colorNames[1]] : (primaryColor === '#9a72ff' ? '#55cfff' : '#9a72ff');
    const motion = /drive|drive in|vehicle|car|bike|ride|enter|arriv|road|highway/.test(lower) ? 'drive' : /portal|warp|gate/.test(lower) ? 'portal' : /orbit|circle|around/.test(lower) ? 'orbit' : /burst|explode|explosion|explode/.test(lower) ? 'burst' : /float|hover|slow|fly|flying|udaan|udta/.test(lower) ? 'float' : design.motion;
    const background = /road|highway|street|racetrack|race track/.test(lower) ? 'road' : /cloud|badal/.test(lower) ? 'clouds' : /sky|fly|flying|air|udaan|udta/.test(lower) ? 'sky-flight' : /mountain|pahad|fire|flame|aag|volcano/.test(lower) ? 'mountain-fire' : /storm|thunder|lightning|rain|barish/.test(lower) ? 'storm-mountains' : /city|urban/.test(lower) ? 'city-night' : design.background;
    const particles = /smoke|fog/.test(lower) ? 'smoke' : /fire|flame/.test(lower) ? 'fire' : /heart/.test(lower) ? 'hearts' : /diamond|crystal|gem/.test(lower) ? 'crystals' : /star|spark|glitter/.test(lower) ? 'stars' : design.particles;
    const icon = /dragon/.test(lower) ? '🐉' : /car|supercar|vehicle/.test(lower) ? '🏎️' : /bike|motorcycle/.test(lower) ? '🏍️' : /rocket/.test(lower) ? '🚀' : /phoenix|bird/.test(lower) ? '🦅' : /heart/.test(lower) ? '💖' : /crown|royal|king|queen/.test(lower) ? '👑' : /flower|rose/.test(lower) ? '🌹' : /gift|present/.test(lower) ? '🎁' : /crystal|diamond|gem/.test(lower) ? '💎' : design.icon;
    const title = brief.split(/[.!?\n]/)[0].replace(/^(make|create|build|design|banao|bana|ek|a|an)\s+/i, '').trim().slice(0, 58) || design.title;
    const next = { ...design, title: title.charAt(0).toUpperCase() + title.slice(1), concept: brief, icon, primaryColor, secondaryColor, motion, particles, background, shape: kind === 'frame' ? 'round' : design.shape, durationSeconds: kind === 'gift' ? Math.min(5, design.durationSeconds) : design.durationSeconds };
    setDesigns(old => ({ ...old, [kind]: next }));
    setAssetId(kind + '-' + next.title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 65));
    setQualityState('not-run'); setQualityResults([]); setUploadFile(null); setUploadKey('');
    setNotice('Design brief locally apply ho gaya — koi AI/API call ya paid credit use nahi hua. Ab 3D Animation Effects Editor mein parts, materials, transforms aur timeline ko manually fine-tune karo.');
    setBusy(false);
  };
  const exportJson = () => {
    const data = { format: 'darkvibex-creator-asset', version: 3, kind, design, userPrompt: prompt, qualityState, qualityResults, modelFile: modelName || null, productionStatus: qualityState === 'passed' ? 'studio-quality-gate-passed-not-yet-uploaded' : 'preview-only', note: 'Studio quality results describe the tested browser scene. Uploading to DarkVibeX requires an authorized Owner Panel session and a selected final media file.' };
    const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }));
    const a = document.createElement('a'); a.href = url; a.download = 'darkvibex-' + kind + '-design.json'; a.click(); URL.revokeObjectURL(url);
    setNotice('Design JSON export ho gaya. Production app integration alag step hai.');
  };
  const exportHtml = () => {
    const d = design;
    const html = `<!doctype html><html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(d.title)}</title><style>*{box-sizing:border-box}body{margin:0;min-height:100vh;display:grid;place-items:center;background:radial-gradient(circle,#24265c,#080a18 70%);font-family:Arial;color:white}.scene{text-align:center;padding:24px}.object{width:220px;height:220px;margin:20px auto;display:grid;place-items:center;font-size:90px;border-radius:${kind === 'frame' ? '50%' : kind === 'bubble' ? '34px' : '44%'};border:2px solid ${d.primaryColor};background:linear-gradient(145deg,#ffffff18,#ffffff03);box-shadow:0 0 35px ${d.primaryColor},inset 0 0 28px ${d.secondaryColor};animation:move ${Math.max(2,d.durationSeconds)}s ease-in-out infinite alternate}.frame{border-radius:50%;outline:8px double ${d.secondaryColor};outline-offset:8px}@keyframes move{to{transform:translateY(-18px) rotate(5deg);filter:hue-rotate(35deg);box-shadow:0 0 70px ${d.secondaryColor}}}.name{font-size:28px}.sub{color:#adb4d9}${d.loop ? '' : '.object{animation-iteration-count:1}'}</style><main class="scene"><div class="sub">DARKVIBEX · ${kind.toUpperCase()} CONCEPT</div><div class="object ${kind === 'frame' ? 'frame' : ''}">${esc(d.icon)}</div><div class="name">${esc(d.title)}</div><p>${esc(d.concept)}</p><div class="sub">${d.durationSeconds}s · ${esc(d.rarity)} · ${d.loop ? 'Loop' : 'One-shot'}</div></main></html>`;
    const url = URL.createObjectURL(new Blob([html], { type: 'text/html' }));
    const a = document.createElement('a'); a.href = url; a.download = 'darkvibex-' + kind + '-preview.html'; a.click(); URL.revokeObjectURL(url);
    setNotice('Browser preview file export ho gayi. Ye final 3D video nahi hai.');
  };
  const styleVars = useMemo(() => ({ '--a': design.primaryColor, '--b': design.secondaryColor } as React.CSSProperties), [design.primaryColor, design.secondaryColor]);
  const run3dExport = async (mode: 'glb' | 'webm' | 'mp4' | 'png') => {
    setExporting3d(true); setNotice(mode === 'mp4' ? 'Recording the 3D scene and preparing MP4 conversion. This may use significant browser memory.' : mode === 'png' ? 'Rendering a transparent PNG for frame, bubble or gift artwork...' : 'Preparing 3D export...');
    try {
      if (!stageRef.current) throw new Error('3D preview is still loading');
      if (mode === 'glb') {
        await stageRef.current.exportGlb();
        setNotice('Free procedural 3D GLB starter exported. It is editable starter geometry, not a hand-sculpted commercial model.');
      } else if (mode === 'mp4') {
        await stageRef.current.recordMp4();
        setNotice('MP4 animation rendered and exported.');
      } else if (mode === 'png') {
        await stageRef.current.exportPng();
        setNotice('Transparent PNG exported. Upload it as the poster/image key in Owner Panel; use transparent artwork for frames and chat bubbles.');
      } else {
        await stageRef.current.recordWebm();
        setNotice('WebM animation preview exported.');
      }
    } catch (e) { setNotice(e instanceof Error ? e.message : 'Export failed in this browser.'); }
    finally { setExporting3d(false); }
  };
  return <div className="studio-new">{showAdvancedComposer && <AdvancedComposer onClose={() => setShowAdvancedComposer(false)} onApply={applyComposer} />}
    <style>{`
      .studio-new{min-height:100vh;color:#f5f4ff;background:radial-gradient(ellipse at 80% 0%,#29215c 0,transparent 38%),#090b17;font-family:Inter,system-ui,sans-serif}.newbar{height:72px;display:flex;align-items:center;justify-content:space-between;padding:0 26px;border-bottom:1px solid #ffffff15;background:#0d0f20;position:sticky;top:0;z-index:5}.newbrand{display:flex;gap:12px;align-items:center}.newmark{background:linear-gradient(145deg,#6751cb,#24234c);padding:10px;border-radius:13px;color:#fff}.newbrand strong{font-size:16px}.newbrand small{display:block;color:#858bad;font-size:10px;letter-spacing:1.5px;margin-top:4px}.newbtn{border:0;border-radius:10px;padding:11px 14px;background:linear-gradient(100deg,#9c83ff,#70dfff);color:#111126;font-weight:800;display:inline-flex;gap:8px;align-items:center;justify-content:center}.newlayout{max-width:1500px;margin:auto;padding:28px;display:grid;grid-template-columns:245px minmax(0,1fr);gap:25px}.newside,.newpanel{background:#111426;border:1px solid #ffffff12;border-radius:18px}.newside{padding:16px;height:max-content}.sidetitle{font-size:10px;letter-spacing:1.6px;color:#858bad;margin:8px 10px 14px}.kindbtn{width:100%;display:flex;gap:12px;align-items:center;text-align:left;padding:13px 11px;background:transparent;border:1px solid transparent;border-radius:12px;color:#aeb4d4;margin-bottom:5px}.kindbtn.active{background:#8d78ff19;border-color:#a08aff55;color:#fff}.kindbtn small{display:block;color:#7e86a7;font-size:10px;margin-top:4px}.newcontent{min-width:0}.newheading{display:flex;justify-content:space-between;gap:14px;align-items:flex-start;margin-bottom:22px}.newheading h1{margin:5px 0 8px;font-size:clamp(25px,3vw,36px);letter-spacing:-1px}.newheading p{margin:0;color:#969fbe;font-size:13px;line-height:1.6}.eyebrow2{font-size:10px;letter-spacing:1.8px;color:#a79aff;font-weight:800}.tag{border:1px solid #8b7bff45;color:#bdb0ff;border-radius:99px;padding:8px 11px;font-size:10px;white-space:nowrap}.newgrid{display:grid;grid-template-columns:minmax(0,1.05fr) minmax(300px,.95fr);gap:18px}.newpanel{padding:20px;min-width:0}.newpanel h2{font-size:16px;margin:0 0 8px}.muted{color:#9098b7;font-size:12px;line-height:1.6}.promptbox{width:100%;min-height:130px;resize:vertical;background:#090c19;border:1px solid #383653;border-radius:12px;padding:14px;color:#f4f2ff;line-height:1.6;outline:none;margin:13px 0}.promptbox:focus,.fieldnew:focus{border-color:#9d86ff}.hint{display:flex;gap:7px;flex-wrap:wrap;margin:0 0 14px}.hint button{background:#1c2038;color:#b8bce0;border:1px solid #ffffff12;border-radius:99px;padding:7px 10px;font-size:10px}.newfields{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:17px}.fieldwrap label{display:block;color:#9ea5c4;font-size:11px;margin-bottom:7px}.fieldnew{width:100%;background:#090c19;color:#f6f5ff;border:1px solid #292d49;border-radius:9px;padding:10px;min-width:0}.swatches{display:flex;align-items:center;gap:8px;margin-top:16px;color:#9299b8;font-size:11px}.swatch{width:25px;height:25px;border-radius:50%;border:2px solid #ffffff55;padding:0}.previewbox{margin-top:15px;min-height:390px;border-radius:15px;overflow:hidden;position:relative;display:flex;align-items:center;justify-content:center;flex-direction:column;background:radial-gradient(ellipse at 50% 43%,color-mix(in srgb,var(--a) 24%,#171a38),#090b18 70%);border:1px solid #ffffff16;isolation:isolate}.previewbox:before,.previewbox:after{content:'';position:absolute;border:1px solid var(--a);border-radius:50%;width:230px;height:230px;opacity:.25;animation:ring 5s linear infinite;z-index:-1}.previewbox:after{width:290px;height:290px;border-color:var(--b);animation-direction:reverse;animation-duration:8s}.preview-icon{width:160px;height:160px;border-radius:${kind === 'frame' ? '50%' : kind === 'bubble' ? '28px' : '43%'};display:grid;place-items:center;font-size:72px;background:linear-gradient(145deg,#ffffff1b,#ffffff03);border:2px solid var(--a);box-shadow:0 0 26px var(--a),inset 0 0 35px var(--b);animation:hero 2.8s ease-in-out infinite alternate;position:relative}.preview-icon.frame-shape{border-radius:50%;outline:8px double var(--b);outline-offset:7px}.preview-icon.motion-drive{animation:drive 3.5s ease-in-out infinite alternate}.preview-icon.motion-portal{animation:portal 3s ease-in-out infinite alternate}.preview-icon.motion-burst{animation:burst 2.2s ease-in-out infinite alternate}.preview-icon.motion-orbit{animation:orbit 5s linear infinite}.preview-icon.motion-float{animation:hero 2.3s ease-in-out infinite alternate}.previewname{font-weight:800;font-size:19px;margin-top:28px;text-align:center;padding:0 15px}.previewconcept{font-size:11px;color:#a9b0d3;text-align:center;max-width:320px;line-height:1.6;margin:8px 18px}.previewmeta{font-size:9px;letter-spacing:1.5px;color:var(--a);margin-top:12px;text-transform:uppercase}.previewstars{position:absolute;inset:0;pointer-events:none;overflow:hidden}.previewstars i{position:absolute;width:4px;height:4px;border-radius:50%;background:var(--a);box-shadow:0 0 12px var(--a);animation:twinkle 1.5s ease-in-out infinite alternate}.preview-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:13px}.ghostbtn{background:#1b1e34;border:1px solid #ffffff16;color:#cdd0ea;border-radius:10px;padding:10px 12px;display:inline-flex;align-items:center;gap:7px;font-size:11px}.newfooter{margin-top:18px;padding:16px;border-radius:14px;background:#15182b;border:1px solid #ffffff10;color:#9da5c3;font-size:11px;line-height:1.7}.newfooter b{color:#e3e4ff}.notice{margin-top:14px;padding:12px 14px;background:#172d2d;border:1px solid #56ddb344;border-radius:10px;color:#a8f4dc;font-size:12px}.pipeline-panel{margin-bottom:18px}.quality-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px;margin-top:14px}.quality-item,.quality-empty{min-width:0;padding:12px;border-radius:11px;background:#090c19;border:1px solid #ffffff12}.quality-empty{grid-column:1/-1;color:#8e97b7;font-size:12px}.quality-item.pass{border-color:#42d9a055}.quality-item.warn{border-color:#ffc36a55}.quality-item.fail{border-color:#ff6f8b65}.quality-item-head{display:flex;align-items:center;gap:7px;font-size:11px}.quality-item.pass .quality-item-head svg,.quality-item.pass .quality-item-head span{color:#78e8be}.quality-item.warn .quality-item-head svg,.quality-item.warn .quality-item-head span{color:#ffc36a}.quality-item.fail .quality-item-head svg,.quality-item.fail .quality-item-head span{color:#ff7b9e}.quality-item-head span{margin-left:auto;font-size:9px;font-weight:800}.quality-item p{margin:8px 0 0;color:#9098b7;font-size:11px;line-height:1.55;overflow-wrap:anywhere}.uploadfields{margin-top:14px}.uploadfile-wrap small{display:block;color:#7f87a7;font-size:10px;margin-top:6px;line-height:1.5}.publish-kind{min-height:38px;display:flex;align-items:center;overflow-wrap:anywhere}.studio-modal{position:fixed;inset:0;background:#050610ef;backdrop-filter:blur(12px);z-index:100;display:flex;align-items:center;justify-content:center;padding:16px;overflow:auto}.studio-modal-card{width:min(720px,100%);max-height:95vh;overflow:auto;background:#101426;border:1px solid #8171ff55;border-radius:20px;padding:18px;box-shadow:0 25px 80px #000b}.modal-header{display:flex;justify-content:space-between;gap:10px;align-items:flex-start;margin-bottom:14px}.modal-header h2{margin:5px 0;font-size:22px}.modal-header small{color:#a79aff;font-size:9px;letter-spacing:1.5px}.modal-header p,.modal-footer-note{color:#929abc;font-size:11px;line-height:1.6;margin:0}.mock-phone{width:min(390px,100%);margin:0 auto;border:5px solid #30334c;border-radius:30px;padding:0 10px 12px;background:#0a0d1b;overflow:hidden;box-shadow:0 0 35px #6450cc25}.mock-status{display:flex;justify-content:space-between;padding:10px 7px 6px;font-size:9px;color:#d4d7f7}.mock-room-header{display:flex;justify-content:space-between;align-items:center;padding:12px 8px;border-bottom:1px solid #ffffff17}.mock-room-header b{font-size:13px}.mock-room-header span{font-size:9px;color:#929abc}.mock-room-content{padding:12px 4px}.mock-room-tag{font-size:9px;letter-spacing:1.3px;color:#9d8cff}.mock-stage{height:240px;position:relative;background:radial-gradient(ellipse at center,#26224e,#090b18 76%);border-radius:15px;overflow:hidden;margin-top:10px}.mock-avatar{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);width:86px;height:86px;border-radius:50%;border:3px solid #e5dcff;background:linear-gradient(135deg,#3f5ac7,#b351b7);display:grid;place-items:center;font-size:30px;font-weight:800;pointer-events:none}.mock-chat-text{position:absolute;bottom:22px;left:20px;right:20px;background:#1a2043ed;border:1px solid #8a78ff88;border-radius:13px;padding:10px;font-size:10px;color:#eff1ff;pointer-events:none}.mock-caption{padding:12px 4px 4px}.mock-caption b,.mock-caption span{display:block}.mock-caption b{font-size:13px}.mock-caption span{color:#a094ff;font-size:9px;margin-top:5px}.mock-caption p{font-size:10px;color:#969fbe;line-height:1.5;margin:7px 0}.mock-seat-row{display:flex;gap:10px;padding:10px 4px}.mock-seat{width:38px;height:38px;border-radius:50%;display:grid;place-items:center;background:#242846;border:1px solid #7767d3;color:#d9d7ff}.mock-chatbar{margin-top:5px;padding:11px;border-radius:999px;background:#181d31;color:#858ead;font-size:10px;display:flex;justify-content:space-between}.mock-chatbar span{color:#a18cff}.modal-footer-note{max-width:390px;margin:12px auto 0;text-align:center}.newtoggle{display:flex;justify-content:space-between;align-items:center;margin-top:13px;font-size:11px;color:#aab0ce}.newtoggle input{accent-color:#a48bff}.statuspill{display:inline-flex;gap:6px;align-items:center;font-size:10px;color:#7ee8c1}.statuspill i{width:6px;height:6px;border-radius:50%;background:#65e7b5}@keyframes hero{to{transform:translateY(-10px) rotate(4deg);box-shadow:0 0 55px var(--b),inset 0 0 35px var(--a)}}@keyframes drive{0%{transform:translateX(-18px) rotate(-5deg)}100%{transform:translateX(18px) rotate(3deg)}}@keyframes portal{to{transform:scale(1.08) rotate(12deg);filter:hue-rotate(30deg)}}@keyframes burst{to{transform:scale(1.09) rotate(-8deg);box-shadow:0 0 80px var(--a)}}@keyframes orbit{to{transform:rotate(360deg)}}@keyframes ring{to{transform:rotate(360deg) scale(1.12)}}@keyframes twinkle{to{opacity:.15;transform:translateY(-12px) scale(.6)}}@media(max-width:950px){.newlayout{grid-template-columns:1fr;padding:16px}.newside{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:5px}.sidetitle{grid-column:1/-1}.newgrid{grid-template-columns:1fr}.newbar{padding:0 14px}.newheading{flex-direction:column}.previewbox{min-height:340px}}@media(max-width:480px){.newlayout{padding:10px;gap:12px}.newpanel{padding:14px}.newside{padding:10px}.kindbtn{font-size:11px;padding:10px 8px}.kindbtn svg{width:17px}.newbrand small{font-size:8px}.newbrand strong{font-size:13px}.newbar .newbtn{padding:9px;font-size:11px}.newfields{gap:8px}.preview-icon{width:135px;height:135px;font-size:60px}.previewbox{min-height:315px}.quality-grid{grid-template-columns:1fr}.studio-modal{padding:7px}.studio-modal-card{padding:12px}.modal-header h2{font-size:18px}.uploadfields{grid-template-columns:1fr}}`}</style>
    <header className="newbar"><div className="newbrand"><div className="newmark"><WandSparkles size={22}/></div><div><strong>DarkVibeX Creator Studio</strong><small>EDIT PARTS · ANIMATE · EXPORT — NO AI CREDITS</small></div></div><div style={{display:'flex',gap:8,alignItems:'center'}}><button className="ghostbtn" onClick={() => setShowAdvancedComposer(true)}><Layers3 size={14}/> 3D Effects Editor</button><button className="newbtn" onClick={exportJson}><Download size={15}/> Export spec</button></div></header>
    <div className="newlayout">
      <aside className="newside"><div className="sidetitle">WHAT DO YOU WANT TO CREATE?</div>{kinds.map(item => { const Icon = item.icon; return <button key={item.id} className={'kindbtn ' + (kind === item.id ? 'active' : '')} onClick={() => selectKind(item.id)}><Icon size={20}/><span>{item.label}<small>{item.detail}</small></span></button>; })}<div className="newfooter"><b>Free manual creation</b><br/>No AI generator, no paid credits. Brief se local style settings apply karo, phir Advanced Composer mein har part, material, position, scale, rotation aur timeline manually edit karo.</div></aside>
      <main className="newcontent">
        <div className="newheading"><div><div className="eyebrow2">PREMIUM 3D EFFECT WORKSHOP</div><h1>Build your animated 3D effects.</h1><p>Round VIP frames, glass chat bubbles, cinematic entry portals aur luxury vehicle arrivals — live preview aur video export ke saath.</p></div><span className="tag">FREE · NO AI · NO CREDITS</span></div>
        <div className="newgrid">
          <section className="newpanel"><h2>01 · Design brief & quick styling</h2><div className="muted">Brief ke words se browser mein local colour, icon aur motion settings apply hongi. Ye AI generation nahi hai; detailed parts ko Composer mein khud edit karo.</div>
            <textarea className="promptbox" value={prompt} onChange={e => setPrompt(e.target.value)} placeholder="Example: Ek royal blue dragon gift banao jo crystal portal se bahar aaye, receiver ke DP ke around fly kare aur purple sparks ke saath finish ho..."/>
            <div className="hint"><button onClick={() => setPrompt('Perfectly round 3D VIP profile frame, never oval, with orbiting blue diamonds and purple royal flames.')}>Round premium frame</button><button onClick={() => setPrompt('A realistic luxury supercar driving fast on a cinematic mountain highway, road markings moving, low camera angle, glossy metallic body and sunset haze.')}>Road supercar</button><button onClick={() => setPrompt('A realistic vehicle flying through a blue sky above clouds and distant mountains, cinematic camera movement, drifting clouds and premium light.')}>Sky flight</button><button onClick={() => setPrompt('A cinematic vehicle entrance across dark mountains, volumetric smoke, animated fire and glowing embers, premium realistic lighting.')}>Mountain + fire</button><button onClick={() => setPrompt('A magical gift opens, a 3D phoenix rises from it, then gold and violet particles burst outward.')}>Fantasy gift</button></div>
            <button className="newbtn" style={{width:'100%',padding:13}} onClick={generate} disabled={busy}>{busy ? <><LoaderCircle size={17}/> Designing...</> : <><Check size={17}/> Apply brief locally (free)</>}</button>
            <div className="muted" style={{marginTop:10,padding:12,borderRadius:10,background:'#151a2d',border:'1px solid #ffffff12'}}><b style={{color:'#b8aaff'}}>Free manual 3D workflow</b><br/>No AI service, API key, or paid credits. This applies simple styling locally; use Advanced Composer for real editable scene parts, materials, transforms, keyframes and browser export. Premium hand-sculpted models still need authored 3D assets.</div>
            <div className="newfields">
              <div className="fieldwrap"><label>Display name</label><input className="fieldnew" value={design.title} onChange={e => update({title:e.target.value})}/></div>
              <div className="fieldwrap"><label>Rarity / tier</label><select className="fieldnew" value={design.rarity} onChange={e => update({rarity:e.target.value})}>{['Common','Rare','Epic','Legendary','Mythic','VIP Premium'].map(x => <option key={x}>{x}</option>)}</select></div>
              <div className="fieldwrap"><label>Animation duration</label><select className="fieldnew" value={design.durationSeconds} onChange={e => update({durationSeconds:Number(e.target.value)})}>{[2,3,4,5,6,8,10,12,15].map(x => <option key={x} value={x}>{x} seconds</option>)}</select></div>
              <div className="fieldwrap"><label>Cinematic environment</label><select className="fieldnew" value={design.background} onChange={e => update({background:e.target.value})}>{[['studio','Transparent studio'],['road','Real-road scene'],['sky-flight','Sky flight'],['clouds','Cloud fly-through'],['mountain-fire','Mountain + fire'],['storm-mountains','Storm mountains'],['city-night','Night city']].map(([value,label]) => <option key={value} value={value}>{label}</option>)}</select><small className="muted">Choose a moving 3D environment. For near-photoreal vehicles, import a detailed GLB model or use a real video layer in 3D Effects Editor.</small></div>
              <div className="fieldwrap"><label>Preview icon / symbol</label><input className="fieldnew" value={design.icon} onChange={e => update({icon:e.target.value})} maxLength={8}/></div>
              <div className="fieldwrap"><label>Primary color</label><input className="fieldnew" type="color" value={design.primaryColor} onChange={e => update({primaryColor:e.target.value})}/></div>
              <div className="fieldwrap"><label>Glow / secondary color</label><input className="fieldnew" type="color" value={design.secondaryColor} onChange={e => update({secondaryColor:e.target.value})}/></div>
              <div className="fieldwrap"><label>Animation movement</label><select className="fieldnew" value={design.motion} onChange={e => update({motion:e.target.value})}>{[['float','Float / hover'],['burst','Burst reveal'],['orbit','Orbit / rotate'],['portal','Portal / energy'],['drive','Vehicle movement']].map(([v,l]) => <option key={v} value={v}>{l}</option>)}</select></div>
              <div className="fieldwrap"><label>Particles</label><select className="fieldnew" value={design.particles} onChange={e => update({particles:e.target.value})}>{['none','stars','sparkles','crystals','flames','aurora','trail','hearts','coins'].map(x => <option key={x}>{x}</option>)}</select></div>
            </div>
            <div className="newtoggle"><label htmlFor="loop">Loop animation in preview</label><input id="loop" type="checkbox" checked={design.loop} onChange={e => update({loop:e.target.checked})}/></div>
            <div className="newtoggle"><label htmlFor="sound">Include sound preference in spec</label><input id="sound" type="checkbox" checked={design.sound} onChange={e => update({sound:e.target.checked})}/></div>
            <div className="swatches"><span>Current palette</span><i style={{background:design.primaryColor,width:18,height:18,borderRadius:20}}/><i style={{background:design.secondaryColor,width:18,height:18,borderRadius:20}}/><span>{design.primaryColor.toUpperCase()}</span></div>
          </section>
          <section className="newpanel"><h2>02 · Preview the animation</h2><div className="muted">Cinematic 3D scene builder: choose a road, sky/cloud, mountain-fire, storm or city environment; animate the subject and render a short video in this browser. For truly realistic vehicles, import a detailed GLB model or composite real footage in 3D Effects Editor.</div>
            <div className="previewbox" style={styleVars}><div style={{position:'absolute',inset:0,zIndex:0}}><ThreeStage ref={stageRef} kind={kind} design={design} modelUrl={modelUrl} parts={customParts}/></div><div style={{position:'absolute',top:12,left:12,zIndex:1,pointerEvents:'none',fontSize:9,letterSpacing:1.4,color:'#c6c7f1',background:'#080b1bbd',padding:'6px 8px',borderRadius:8}}>LIVE WEBGL 3D · {kind.toUpperCase()}</div><div style={{position:'absolute',bottom:12,left:12,right:12,zIndex:1,pointerEvents:'none',textAlign:'center',background:'#080b1bcc',padding:'10px 12px',borderRadius:10}}><div className="previewname" style={{marginTop:0}}>{design.title || 'Your custom effect'}</div><div className="previewconcept">{design.concept}</div><div className="previewmeta">{kind} · {design.durationSeconds}s · {design.rarity} · {design.background}</div></div></div>
            <div className="preview-actions"><button className="ghostbtn" onClick={() => { update({}); setNotice('Preview refresh ho gaya.'); }}><RotateCcw size={14}/> Refresh preview</button><button className="ghostbtn" onClick={() => setSoundOn(v=>!v)}>{soundOn ? <Volume2 size={14}/> : <VolumeX size={14}/>} {soundOn ? 'Preview sound preference on' : 'Preview muted'}</button><button className="ghostbtn" onClick={() => setShowSpec(v=>!v)}><Layers3 size={14}/>{showSpec ? 'Hide design spec' : 'View design spec'}</button></div>
            <div className="preview-actions"><label className="ghostbtn" style={{cursor:'pointer'}}><FileUp size={14}/> Import realistic GLB model<input type="file" accept=".glb,model/gltf-binary" hidden onChange={event => handleModelFile(event.target.files?.[0])}/></label>{modelName && <span className="muted">Loaded source: {modelName}</span>}</div>
            {showSpec && <pre style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere',fontSize:10,color:'#c8c9e7',background:'#090c19',padding:12,borderRadius:10,marginTop:12}}>{JSON.stringify({kind, ...design, userPrompt:prompt},null,2)}</pre>}
            <div className="preview-actions"><button className="newbtn" onClick={() => run3dExport('glb')} disabled={exporting3d}><Download size={14}/> Export GLB starter</button><button className="newbtn" onClick={() => run3dExport('mp4')} disabled={exporting3d}><Play size={14}/> Render MP4</button></div><div className="preview-actions"><button className="ghostbtn" onClick={() => run3dExport('png')} disabled={exporting3d}><Download size={14}/> Export transparent PNG</button><span className="muted">Frames / bubbles: upload PNG as image key.</span></div><div className="preview-actions"><button className="ghostbtn" onClick={() => run3dExport('webm')} disabled={exporting3d}><Play size={14}/> Export WebM fallback</button></div><div className="preview-actions"><button className="ghostbtn" onClick={exportHtml}><Play size={14}/> Export HTML concept</button><button className="ghostbtn" onClick={exportJson}><Download size={14}/> Export JSON spec</button></div>
          </section>
        </div>
        <section className="newpanel pipeline-panel" style={{marginTop:18}}>
          <h2>03 · Final quality gate & DarkVibeX upload</h2>
          <div className="muted">Pehle Creator Studio ke andar hi scene dekho, phir actual render/GLB/PNG export smoke-tests chalao. Upload tabhi enable hota hai jab critical quality checks pass hon. Selected final file upload ke waqt server-side signature aur size validation bhi hoti hai.</div>
          <div className="preview-actions">
            <button className="newbtn" onClick={runQualityTest} disabled={qualityState === 'running' || exporting3d}><ShieldCheck size={15}/>{qualityState === 'running' ? 'Running export tests…' : 'Run final quality test'}</button>
            <button className="ghostbtn" onClick={() => setShowAppPreview(true)}><MonitorPlay size={15}/> Preview in DarkVibeX (not published)</button>
          </div>
          <div className="quality-grid">
            {qualityResults.length === 0 ? <div className="quality-empty">{qualityState === 'running' ? 'WebGL, GLB, PNG aur video capture test chal raha hai…' : 'Quality report abhi nahi hai. Final design edit complete karke test run karo.'}</div> : qualityResults.map((item, index) => <div className={'quality-item ' + item.status} key={item.label + index}><div className="quality-item-head">{item.status === 'pass' ? <CheckCircle2 size={16}/> : item.status === 'warn' ? <AlertTriangle size={16}/> : <X size={16}/>}<b>{item.label}</b><span>{item.status.toUpperCase()}</span></div><p>{item.detail}</p></div>)}
          </div>
          <div className="newfooter" style={{marginTop:12}}><b>{qualityState === 'passed' ? 'QUALITY GATE: PASS' : qualityState === 'failed' ? 'QUALITY GATE: FAIL — FIX BEFORE UPLOAD' : qualityState === 'running' ? 'QUALITY GATE: TESTING' : 'QUALITY GATE: NOT RUN'}</b><br/>This tests export pipelines and scene health in your current browser; it cannot certify hand-sculpted realism, every Android GPU, or the final appearance in every device.</div>
          <div className="newfields uploadfields">
            <div className="fieldwrap"><label>DarkVibeX Worker / API base URL</label><input className="fieldnew" value={apiBase} onChange={event => setApiBase(event.target.value)} placeholder="https://your-darkvibex-worker.workers.dev" autoComplete="url"/></div>
            <div className="fieldwrap"><label>Owner Panel session token (memory only)</label><input className="fieldnew" type="password" value={ownerToken} onChange={event => setOwnerToken(event.target.value)} placeholder="Paste active owner session token" autoComplete="off"/></div>
            <div className="fieldwrap"><label>Asset ID (unique)</label><input className="fieldnew" value={assetId} onChange={event => setAssetId(event.target.value)} maxLength={80} placeholder="royal-halo-frame"/></div>
            <div className="fieldwrap"><label>Coin price</label><input className="fieldnew" type="number" min="0" value={assetPrice} onChange={event => setAssetPrice(event.target.value)}/></div>
            {kind === 'gift' && <div className="fieldwrap"><label>Gift category</label><select className="fieldnew" value={giftCategory} onChange={event => setGiftCategory(event.target.value)}>{[['normal','Normal'],['cp','CP'],['vs','VS'],['luxury','Luxury'],['backpack','Backpack'],['exclusive','Exclusive'],['custom','Custom']].map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>}
            <div className="fieldwrap uploadfile-wrap"><label>Final exported file</label><input className="fieldnew" type="file" accept=".glb,.mp4,.webm,.png,.webp,.jpg,.jpeg,model/gltf-binary,video/mp4,video/webm,image/png,image/webp,image/jpeg" onChange={event => {setUploadFile(event.target.files?.[0] || null);setUploadKey('');}}/><small>{uploadFile ? `${uploadFile.name} · ${Math.max(1, Math.round(uploadFile.size / 1024))} KB` : 'Export GLB / MP4 / WebM / PNG / WebP first, then choose the file here.'}</small></div>
            <div className="fieldwrap uploadfile-wrap"><label>Publication target</label><div className="fieldnew publish-kind">{kind === 'gift' ? 'Gift Catalog' : `${kind.charAt(0).toUpperCase() + kind.slice(1)} Asset Catalog`} · {design.title}</div><small>Uploading with this button writes the file to R2 and publishes/updates the live catalog item.</small></div>
          </div>
          <div className="preview-actions"><button className="newbtn" onClick={uploadToDarkVibeX} disabled={uploadBusy || qualityState !== 'passed' || !uploadFile}><Upload size={15}/>{uploadBusy ? 'Uploading to DarkVibeX…' : 'Upload & publish in DarkVibeX'}</button><span className="muted">Owner token is sent only to the HTTPS API base entered above; it is not saved to localStorage or sent to Creator Studio backend.</span></div>
          {uploadKey && <div className="notice"><Check size={15} style={{verticalAlign:'middle',marginRight:7}}/>R2 media key: <code>{uploadKey}</code></div>}
        </section>
        {notice && <div className="notice" role="status"><Check size={15} style={{verticalAlign:'middle',marginRight:7}}/>{notice}</div>}
        <div className="newfooter"><b>Free procedural 3D workflow · No Tripo</b><br/>Import a single-file realistic GLB, view it in the studio, check the render pipelines, and optionally publish the selected media directly to DarkVibeX after Owner Panel authorization. Procedural shapes remain original starter geometry rather than guaranteed hand-sculpted commercial assets; use imported detailed GLB models for more realistic results. No paid 3D API or Tripo key is used.</div>
      </main>
    </div>
    {showAppPreview && <div className="studio-modal" role="dialog" aria-modal="true" aria-label="DarkVibeX effect preview"><div className="studio-modal-card"><div className="modal-header"><div><small>DARKVIBEX · PRIVATE PREVIEW</small><h2>Check the effect before publishing</h2><p>This is a studio simulation; it does not add anything to the live app.</p></div><button className="ghostbtn" onClick={() => setShowAppPreview(false)} aria-label="Close preview"><X size={16}/> Close</button></div><div className="mock-phone"><div className="mock-status"><span>9:41</span><span>● ● ● ▰</span></div><div className="mock-room-header"><b>DarkVibeX</b><span>Voice Room · 8 users</span></div><div className="mock-room-content"><div className="mock-room-tag">{kind === 'entry' ? 'PLAYER ARRIVAL' : kind === 'vehicle' ? 'VEHICLE ENTRANCE' : kind === 'gift' ? 'GIFT REVEAL' : kind === 'bubble' ? 'ROOM CHAT' : 'PROFILE COSMETIC'}</div><div className="mock-stage"><ThreeStage ref={appPreviewRef} kind={kind} design={design} modelUrl={modelUrl} parts={customParts}/>{kind === 'frame' && <div className="mock-avatar">V</div>}{kind === 'bubble' && <div className="mock-chat-text">{design.previewText || 'Hey! Welcome to the room ✨'}</div>}</div><div className="mock-caption"><b>{design.title}</b><span>{design.rarity} · {design.durationSeconds}s · {kind}</span><p>{design.concept}</p></div><div className="mock-seat-row"><div className="mock-seat">V</div><div className="mock-seat">A</div><div className="mock-seat">R</div><div className="mock-seat">✦</div></div><div className="mock-chatbar">Message the room… <span>➤</span></div></div></div><div className="modal-footer-note">Private preview only · no publish action has been run. Close this preview, review the quality report, then upload when approved.</div></div></div>}
  </div>;
}
export default App;

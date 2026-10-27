import { useEffect, useMemo, useRef, useState } from 'react';
import { X, Layers3, Plus, Trash2, Copy, Save, Download, Upload, Film, Play, Pause, RotateCcw, CheckCircle2, ChevronUp, ChevronDown, Eye, EyeOff } from 'lucide-react';
import { ThreeStage, type StageHandle, type ScenePart } from './ThreeStage';

export type ComposerCategory = 'entry' | 'vehicle' | 'animal' | 'frame' | 'profile-card' | 'rocket-banner' | 'gift-banner' | 'game-banner' | 'gift' | 'bubble' | 'medal';
type CategoryId = ComposerCategory;
type BaseKind = 'gift' | 'frame' | 'entry' | 'vehicle' | 'bubble';
type EditorDesign = { title: string; concept: string; icon: string; primaryColor: string; secondaryColor: string; motion: string; particles: string; durationSeconds: number; loop: boolean; rarity: string; previewText: string };
type Keyframe = {
  id: string; partId: string; time: number; label: string;
  x?: number; y?: number; z?: number; scale?: number; rotation?: number;
};
type SavedProject = { id: string; name: string; category: CategoryId; design: EditorDesign; parts: ScenePart[]; keyframes: Keyframe[]; savedAt: string };
type TemplateRecipe = { id: string; name: string; category: CategoryId; description: string; design: EditorDesign; parts: ScenePart[] };
export type ComposerApplyPayload = { category: ComposerCategory; design: EditorDesign; parts: ScenePart[] };
type Props = { onClose: () => void; onApply: (payload: ComposerApplyPayload) => void };

const categories: { id: CategoryId; label: string; base: BaseKind; icon: string; subtitle: string }[] = [
  { id: 'entry', label: 'Entry Effect', base: 'entry', icon: '✨', subtitle: 'DP + name + VIP ribbon' },
  { id: 'vehicle', label: 'Vehicle Entry', base: 'vehicle', icon: '🏎️', subtitle: '3D vehicle + video timeline' },
  { id: 'animal', label: 'Animal Entry', base: 'vehicle', icon: '🐉', subtitle: 'Model-based movement' },
  { id: 'frame', label: 'Profile Frame', base: 'frame', icon: '🦋', subtitle: 'Round DP frame + ornaments' },
  { id: 'profile-card', label: 'Profile Card', base: 'frame', icon: '👑', subtitle: 'Full card artwork' },
  { id: 'rocket-banner', label: 'Rocket Banner', base: 'entry', icon: '🚀', subtitle: 'Level visuals + 9s countdown' },
  { id: 'gift-banner', label: 'Gift Banner', base: 'gift', icon: '🎁', subtitle: 'Sender / receiver announcement' },
  { id: 'game-banner', label: 'Game Banner', base: 'entry', icon: '🎮', subtitle: 'Game / event announcements' },
  { id: 'gift', label: 'Animated Gift', base: 'gift', icon: '💎', subtitle: 'Gift reveal and particles' },
  { id: 'bubble', label: 'Chat Bubble', base: 'bubble', icon: '💬', subtitle: 'Message-safe decoration' },
  { id: 'medal', label: 'Medal / Badge', base: 'gift', icon: '🏅', subtitle: 'Achievement artwork' },
];

const library: { name: string; shape: ScenePart['shape']; color: string; material: ScenePart['material']; animation: string; category: string }[] = [
  { name: 'Butterfly', shape: 'butterfly', color: '#d9a4ff', material: 'crystal', animation: 'wing-flap', category: 'Nature' },
  { name: 'Rose flowers', shape: 'flower', color: '#ff83c6', material: 'glossy', animation: 'bloom', category: 'Nature' },
  { name: 'Silver leaves', shape: 'leaf', color: '#a6f4da', material: 'metallic', animation: 'float', category: 'Nature' },
  { name: 'Blue crystal', shape: 'crystal', color: '#78dfff', material: 'crystal', animation: 'shine', category: 'Jewels' },
  { name: 'Royal star', shape: 'star', color: '#ffe28a', material: 'metallic', animation: 'twinkle', category: 'Jewels' },
  { name: 'Gold orbit ring', shape: 'ring', color: '#ffd66b', material: 'metallic', animation: 'spin', category: 'Structure' },
  { name: 'Neon orb', shape: 'orb', color: '#a58aff', material: 'neon', animation: 'pulse', category: 'Energy' },
  { name: 'Fire plume', shape: 'flame', color: '#ff744d', material: 'neon', animation: 'flicker', category: 'Energy' },
  { name: 'Heart charm', shape: 'heart', color: '#ff6baf', material: 'glossy', animation: 'pulse', category: 'Ornaments' },
  { name: 'Spark burst', shape: 'spark', color: '#f8fbff', material: 'neon', animation: 'twinkle', category: 'Particles' },
  { name: 'Rocket ornament', shape: 'rocket', color: '#ffb36c', material: 'metallic', animation: 'flyby', category: 'Vehicle parts' },
  { name: 'Chrome crystal', shape: 'crystal', color: '#e7e9ff', material: 'metallic', animation: 'orbit', category: 'Jewels' },
  { name: 'Hypercar body', shape: 'car-body', color: '#70e9ff', material: 'glossy', animation: 'drive', category: 'Vehicle parts' },
  { name: 'Performance wheel', shape: 'car-wheel', color: '#c8d5f5', material: 'metallic', animation: 'spin', category: 'Vehicle parts' },
  { name: 'Tinted windshield', shape: 'car-glass', color: '#6e9dff', material: 'glass', animation: 'shine', category: 'Vehicle parts' },
  { name: 'LED headlight', shape: 'car-light', color: '#b9f7ff', material: 'neon', animation: 'pulse', category: 'Vehicle parts' },
  { name: 'Rear spoiler', shape: 'car-spoiler', color: '#986cff', material: 'metallic', animation: 'float', category: 'Vehicle parts' },
  { name: 'Neon exhaust', shape: 'car-exhaust', color: '#ff744d', material: 'neon', animation: 'flicker', category: 'Vehicle parts' },
];

const partAnimations: Record<ScenePart['shape'], string[]> = {
  butterfly: ['wing-flap', 'float', 'orbit', 'flyby', 'twinkle', 'pulse'],
  flower: ['bloom', 'float', 'spin', 'shine', 'pulse'],
  leaf: ['float', 'spin', 'orbit', 'shine'],
  crystal: ['spin', 'orbit', 'shine', 'pulse', 'float'],
  star: ['twinkle', 'orbit', 'spin', 'pulse'],
  ring: ['spin', 'orbit', 'pulse', 'shine'],
  orb: ['pulse', 'float', 'orbit', 'shine'],
  flame: ['flicker', 'float', 'flyby', 'pulse'],
  heart: ['pulse', 'float', 'orbit', 'shine'],
  spark: ['twinkle', 'flyby', 'orbit', 'pulse'],
  rocket: ['flyby', 'spin', 'flicker', 'float'],
  'car-body': ['drive', 'float', 'shine'],
  'car-wheel': ['spin', 'drive'],
  'car-glass': ['shine', 'pulse'],
  'car-light': ['pulse', 'twinkle'],
  'car-spoiler': ['float', 'drive'],
  'car-exhaust': ['flicker', 'flyby', 'pulse'],
};
const animationDescriptions: Record<string, string> = {
  none: 'No extra motion; keeps the selected transform.',
  'wing-flap': 'Wing-like rocking motion for the butterfly component.',
  float: 'Gentle independent up/down movement.',
  orbit: 'Small orbital motion around the selected placement.',
  flyby: 'Sweeping pass across its current position.',
  twinkle: 'Pulsing sparkle with scale and rotation changes.',
  pulse: 'Breathing scale/glow rhythm.',
  bloom: 'Petal group expands and contracts softly.',
  spin: 'Continuous rotation around the component pivot.',
  shine: 'Light-catching movement with a subtle rotation and pulse.',
  flicker: 'Fast intensity/scale movement suitable for flames.',
};

const makeId = () => 'part-' + Math.random().toString(36).slice(2, 9);
const defaultPart = (item: typeof library[number], x: number, y: number): ScenePart => ({
  id: makeId(), name: item.name, shape: item.shape, color: item.color, material: item.material,
  animation: item.animation, x, y, z: 0.25, scale: 0.42, rotation: 0, enabled: true,
});
const initialParts = (category: CategoryId): ScenePart[] => {
  if (category === 'frame') return [defaultPart(library[0], -1.25, 0.55), defaultPart(library[1], 1.18, 0.55), defaultPart(library[3], 1.24, -0.7), defaultPart(library[4], -1.22, -0.72)];
  if (category === 'vehicle') return [
    { ...defaultPart(library[12], 0, -0.32), scale: 0.64 },
    { ...defaultPart(library[13], -0.62, -0.59), scale: 0.42 },
    { ...defaultPart(library[13], 0.62, -0.59), scale: 0.42 },
    { ...defaultPart(library[14], -0.08, -0.08), scale: 0.58 },
    { ...defaultPart(library[15], 0.86, -0.35), scale: 0.45 },
    { ...defaultPart(library[15], -0.86, -0.35), scale: 0.45 },
    { ...defaultPart(library[16], -0.72, -0.06), scale: 0.42 },
    { ...defaultPart(library[17], -1.0, -0.32), scale: 0.38 },
  ];
  if (category === 'rocket-banner') return [defaultPart(library[10], 0.0, -0.1), defaultPart(library[7], -0.6, -0.8), defaultPart(library[3], 1.15, 0.45), defaultPart(library[4], -1.2, 0.6)];
  return [defaultPart(library[3], -1.2, 0.5), defaultPart(library[4], 1.2, 0.45), defaultPart(library[9], -1.1, -0.7)];
};
const initialDesign = (category: CategoryId): EditorDesign => {
  const item = categories.find(entry => entry.id === category) || categories[0];
  return {
    title: item.id === 'vehicle' ? 'Aurora Hypercar Entry' : item.id === 'frame' ? 'Butterfly Crystal Halo' : item.id === 'rocket-banner' ? 'Royal Rocket Countdown' : 'DarkVibeX Premium Creation',
    concept: item.subtitle + ' — independent parts, premium materials and editable animation tracks.',
    icon: item.icon, primaryColor: '#8ceaff', secondaryColor: '#986cff', motion: item.id === 'vehicle' ? 'drive' : 'orbit',
    particles: 'sparkles', durationSeconds: item.id === 'rocket-banner' ? 9 : 5, loop: item.id === 'frame', rarity: 'Mythic', previewText: 'DARKVIBEX · VIP 18',
  };
};


const templatePalettes = [
  ['#8ceaff', '#986cff', '#ffd66b', '#f7f8ff'], ['#ff83c6', '#a58aff', '#78dfff', '#ffffff'],
  ['#ffd66b', '#ff744d', '#ffb36c', '#fff1ad'], ['#a6f4da', '#78dfff', '#d9a4ff', '#f8fbff'],
  ['#f7f8ff', '#e7e9ff', '#78dfff', '#986cff'], ['#ff6baf', '#ff83c6', '#ffe28a', '#ffffff'],
  ['#78dfff', '#a58aff', '#8ceaff', '#f7f8ff'], ['#9dffad', '#a6f4da', '#78dfff', '#ffffff'],
  ['#ff744d', '#ffd66b', '#ffb36c', '#fff1ad'], ['#c6a6ff', '#986cff', '#ffd66b', '#f7f8ff'],
  ['#e7e9ff', '#a6f4da', '#d9a4ff', '#78dfff'], ['#ffb3d9', '#ffd66b', '#a58aff', '#ffffff'],
];
const templateNames = ['Aurora Bloom', 'Royal Butterfly', 'Crystal Crown', 'Neon Phoenix', 'Moonlit Garden', 'Golden Orbit', 'Prism Jewel', 'Frost Empress', 'Velvet Flame', 'Celestial Wings'];
const templateRecipes: TemplateRecipe[] = categories.flatMap((category, categoryIndex) =>
  Array.from({ length: 100 }, (_, variant) => {
    const palette = templatePalettes[(variant * 3 + categoryIndex) % templatePalettes.length];
    const partCount = 3 + (variant % 2);
    const parts = Array.from({ length: partCount }, (_, slot) => {
      const itemIndex = (variant * (slot + 2) + categoryIndex * 3 + slot * 5 + Math.floor(variant / 7)) % library.length;
      const item = library[itemIndex];
      const animations = partAnimations[item.shape];
      const part = defaultPart(item, slot === 0 ? -1.08 : slot === 1 ? 1.08 : slot === 2 ? -0.1 : 0.75, slot === 0 ? 0.52 : slot === 1 ? 0.48 : slot === 2 ? -0.88 : -0.72);
      return { ...part, id: category.id + '-' + (variant + 1) + '-part-' + slot,
        color: palette[(slot + variant) % palette.length],
        material: (['metallic', 'crystal', 'neon', 'glass', 'glossy', 'matte'] as ScenePart['material'][])[(variant + slot + categoryIndex) % 6],
        animation: animations[(variant + slot * 2) % animations.length],
        scale: 0.28 + ((variant + slot) % 5) * 0.09,
        rotation: ((variant * 17 + slot * 23) % 120) - 60,
        z: 0.1 + ((slot + variant) % 5) * 0.08 };
    });
    const name = templateNames[(variant + categoryIndex) % templateNames.length] + ' ' + String(variant + 1).padStart(3, '0');
    const design = { ...initialDesign(category.id), title: name,
      concept: category.subtitle + ' · Procedural recipe ' + (variant + 1) + ' with independently editable component combinations.',
      primaryColor: palette[0], secondaryColor: palette[1],
      durationSeconds: category.id === 'rocket-banner' ? 9 : category.id === 'vehicle' ? 7 : 5,
      loop: category.id === 'frame',
      previewText: category.id === 'entry' ? 'ShadowKing · VIP 18' : category.id === 'rocket-banner' ? 'ROCKET LEVEL ' + ((variant % 12) + 1) : 'DARKVIBEX · PREMIUM' };
    return { id: category.id + '-' + (variant + 1), name, category: category.id, description: category.subtitle, design, parts };
  })
);

export function AdvancedComposer({ onClose, onApply }: Props) {
  const [category, setCategory] = useState<CategoryId>('vehicle');
  const [design, setDesign] = useState<EditorDesign>(() => initialDesign('vehicle'));
  const [parts, setParts] = useState<ScenePart[]>(() => initialParts('vehicle'));
  const [selectedId, setSelectedId] = useState('');
  const [filter, setFilter] = useState('');
  const [search, setSearch] = useState('');
  const [templateSearch, setTemplateSearch] = useState('');
  const [selectedRecipeId, setSelectedRecipeId] = useState('vehicle-1');
  const [keyframes, setKeyframes] = useState<Keyframe[]>([]);
  const [duration, setDuration] = useState(7);
  const [playhead, setPlayhead] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [videoUrl, setVideoUrl] = useState('');
  const [videoName, setVideoName] = useState('');
  const [videoError, setVideoError] = useState('');
  const [notice, setNotice] = useState('Choose parts from different templates, then customize every part separately.');
  const [savedProjects, setSavedProjects] = useState<SavedProject[]>(() => {
    try { return JSON.parse(localStorage.getItem('darkvibex-advanced-projects') || '[]') as SavedProject[]; } catch { return []; }
  });
  const [projectName, setProjectName] = useState('My Premium Creation');
  const [loadedProjectId, setLoadedProjectId] = useState('');
  const [recording, setRecording] = useState(false);
  const previewRef = useRef<HTMLDivElement>(null);
  const stageRef = useRef<StageHandle>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const projectFileRef = useRef<HTMLInputElement>(null);
  const videoFileRef = useRef<HTMLInputElement>(null);
  const selected = parts.find(part => part.id === selectedId) || parts[0];
  const currentCategory = categories.find(item => item.id === category) || categories[0];
  const baseKind = currentCategory.base;
  const stageDesign = useMemo(() => ({
    title: design.title, concept: design.concept, icon: design.icon, primaryColor: design.primaryColor,
    secondaryColor: design.secondaryColor, motion: design.motion, particles: design.particles,
    durationSeconds: duration, loop: design.loop, rarity: design.rarity, previewText: design.previewText,
  }), [design, duration]);
  const timelineParts = useMemo(() => parts.map(part => ({
    ...part,
    keyframes: keyframes
      .filter(frame => frame.partId === part.id)
      .slice()
      .sort((left, right) => left.time - right.time)
      .map(frame => ({
        time: frame.time,
        x: frame.x ?? part.x,
        y: frame.y ?? part.y,
        z: frame.z ?? part.z,
        scale: frame.scale ?? part.scale,
        rotation: frame.rotation ?? part.rotation,
      })),
  })), [parts, keyframes]);

  useEffect(() => {
    if (!selectedId && parts[0]) setSelectedId(parts[0].id);
    if (selectedId && !parts.some(part => part.id === selectedId)) setSelectedId(parts[0]?.id || '');
  }, [parts, selectedId]);

  useEffect(() => {
    if (!playing) return;
    const timer = window.setInterval(() => setPlayhead(old => old >= duration ? 0 : Math.min(duration, old + 0.1)), 100);
    return () => window.clearInterval(timer);
  }, [playing, duration]);

  useEffect(() => () => { if (videoUrl.startsWith('blob:')) URL.revokeObjectURL(videoUrl); }, [videoUrl]);

  const changeCategory = (next: CategoryId) => {
    setCategory(next);
    const nextDesign = initialDesign(next);
    setDesign(nextDesign);
    setParts(initialParts(next));
    setSelectedId('');
    setDuration(next === 'rocket-banner' ? 9 : next === 'vehicle' ? 7 : 5);
    setKeyframes([]);
    setSelectedRecipeId(next + '-1');
    setTemplateSearch('');
    setVideoError('');
    setNotice('Category changed. Choose one of 100 editable procedural recipes or compose your own.');
  };
  const applySelectedRecipe = () => {
    const recipe = templateRecipes.find(item => item.id === selectedRecipeId);
    if (!recipe) { setNotice('Choose a template recipe for the current category.'); return; }
    if (recipe.category !== category) { setNotice('Choose a recipe from the selected category.'); return; }
    setDesign(recipe.design);
    setParts(recipe.parts.map(part => ({ ...part, id: makeId() })));
    setSelectedId('');
    setProjectName(recipe.name);
    setLoadedProjectId('');
    setDuration(recipe.design.durationSeconds);
    setKeyframes([]);
    setNotice(recipe.name + ' loaded. Every generated part remains editable.');
  };
  const updatePart = (patch: Partial<ScenePart>) => {
    if (!selected) return;
    setParts(old => old.map(part => part.id === selected.id ? { ...part, ...patch } : part));
  };
  const addLibraryPart = (item: typeof library[number]) => {
    const next = defaultPart(item, (Math.random() - 0.5) * 2.2, (Math.random() - 0.5) * 1.7);
    setParts(old => [...old, next]);
    setSelectedId(next.id);
    setNotice(item.name + ' added as an independent editable component.');
  };
  const replaceSelected = (item: typeof library[number]) => {
    if (!selected) { addLibraryPart(item); return; }
    setParts(old => old.map(part => part.id === selected.id ? { ...defaultPart(item, part.x, part.y), id: part.id, scale: part.scale, rotation: part.rotation, z: part.z, enabled: part.enabled } : part));
    setNotice('Selected part replaced; layer position and transform were preserved.');
  };
  const updateDesign = (patch: Partial<EditorDesign>) => setDesign(old => ({ ...old, ...patch }));
  const duplicateSelected = () => {
    if (!selected) return;
    const copy = { ...selected, id: makeId(), name: selected.name + ' copy', x: Math.min(2, selected.x + 0.22), y: Math.min(1.8, selected.y - 0.18) };
    setParts(old => [...old, copy]); setSelectedId(copy.id); setNotice('Component duplicated.');
  };
  const deleteSelected = () => {
    if (!selected) return;
    setParts(old => old.filter(part => part.id !== selected.id));
    setKeyframes(old => old.filter(frame => frame.partId !== selected.id));
    setNotice('Component removed from this composition only.');
  };
  const useInMainCreator = () => {
    onApply({ category, design, parts: timelineParts });
  };
  const addKeyframe = () => {
    if (!selected) { setNotice('Select a component before adding a keyframe.'); return; }
    const frame: Keyframe = {
      id: makeId(), partId: selected.id, time: Number(playhead.toFixed(1)),
      label: selected.name + ' · ' + (selected.animation || 'none'),
      x: selected.x, y: selected.y, z: selected.z, scale: selected.scale, rotation: selected.rotation,
    };
    setKeyframes(old => [...old.filter(existing => !(existing.partId === selected.id && Math.abs(existing.time - frame.time) < 0.05)), frame].sort((a, b) => a.time - b.time));
    setNotice('Transform keyframe saved. Move the playhead, change this part’s transform, and add another keyframe to animate between poses.');
  };
  const deleteNearestKeyframe = () => {
    if (!selected) { setNotice('Select a component first.'); return; }
    const related = keyframes.filter(frame => frame.partId === selected.id);
    if (!related.length) { setNotice('This component has no keyframes to remove.'); return; }
    const nearest = related.reduce((best, frame) => Math.abs(frame.time - playhead) < Math.abs(best.time - playhead) ? frame : best);
    setKeyframes(old => old.filter(frame => frame.id !== nearest.id));
    setNotice('Nearest transform keyframe removed.');
  };
  const saveProject = () => {
    const name = projectName.trim() || design.title || 'Untitled creation';
    const record: SavedProject = { id: loadedProjectId || makeId(), name, category, design, parts, keyframes, savedAt: new Date().toISOString() };
    const next = [record, ...savedProjects.filter(project => project.id !== record.id)].slice(0, 100);
    try {
      localStorage.setItem('darkvibex-advanced-projects', JSON.stringify(next));
      setSavedProjects(next);
      setLoadedProjectId(record.id);
      setNotice('Project saved in this browser. Export JSON to move it to another device.');
    } catch {
      setNotice('Browser storage is full or unavailable. Export project JSON to keep a backup.');
    }
  };
  const loadProject = (id: string) => {
    const project = savedProjects.find(item => item.id === id);
    if (!project) return;
    setLoadedProjectId(id); setCategory(project.category); setDesign(project.design); setParts(project.parts); setKeyframes(project.keyframes || []);
    setDuration(project.category === 'rocket-banner' ? 9 : project.design.durationSeconds || 5);
    setProjectName(project.name); setSelectedId(project.parts[0]?.id || ''); setNotice('Saved project loaded.');
  };
  const exportProject = () => {
    const record: SavedProject = { id: loadedProjectId || makeId(), name: projectName.trim() || design.title, category, design, parts, keyframes, savedAt: new Date().toISOString() };
    const blob = new Blob([JSON.stringify({ format: 'darkvibex-advanced-creator-project', version: 1, project: record, sourceVideo: videoName || null }, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob); const anchor = document.createElement('a'); anchor.href = url; anchor.download = 'darkvibex-creator-project.json'; anchor.click(); window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    setNotice('Editable project JSON exported. Source video bytes are not embedded; keep the original video file separately.');
  };
  const importProject = async (file?: File) => {
    if (!file) return;
    try {
      const parsed = JSON.parse(await file.text()) as { project?: SavedProject; format?: string };
      const project = parsed.project || parsed as unknown as SavedProject;
      if (!project.category || !categories.some(item => item.id === project.category) || !Array.isArray(project.parts) || !project.design) throw new Error('This file is not a valid DarkVibeX Creator project.');
      setCategory(project.category); setDesign(project.design); setParts(project.parts); setKeyframes(project.keyframes || []);
      setDuration(project.category === 'rocket-banner' ? 9 : project.design.durationSeconds || 5); setProjectName(project.name || project.design.title);
      setLoadedProjectId(''); setSelectedId(project.parts[0]?.id || ''); setNotice('Project imported and ready to edit.');
    } catch (error) { setNotice(error instanceof Error ? error.message : 'Project import failed.'); }
    finally { if (projectFileRef.current) projectFileRef.current.value = ''; }
  };
  const importVideo = (file?: File) => {
    if (!file) return;
    if (!file.type.startsWith('video/')) { setVideoError('Please choose an actual video file.'); return; }
    if (file.size > 100 * 1024 * 1024) { setVideoError('Editor source video limit is 100 MB. Trim it before importing.'); return; }
    if (videoUrl.startsWith('blob:')) URL.revokeObjectURL(videoUrl);
    setVideoUrl(URL.createObjectURL(file)); setVideoName(file.name); setVideoError('');
    setNotice('Video clip loaded for preview/compositing. The project stores a reference name; keep the source file separately.');
  };
  const renderComposite = async () => {
    const stageCanvas = previewRef.current?.querySelector('canvas');
    if (!(stageCanvas instanceof HTMLCanvasElement)) { setNotice('3D preview canvas is not ready.'); return; }
    if (typeof MediaRecorder === 'undefined' || !HTMLCanvasElement.prototype.captureStream) { setNotice('This browser lacks MediaRecorder/canvas capture. Use the 3D video export in the main studio instead.'); return; }
    setRecording(true);
    setPlayhead(0);
    setPlaying(true);
    const canvas = document.createElement('canvas'); canvas.width = 1280; canvas.height = 720;
    const ctx = canvas.getContext('2d');
    if (!ctx) { setRecording(false); setNotice('Canvas compositor is unavailable.'); return; }
    const stream = canvas.captureStream(30);
    const mimeType = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'].find(type => MediaRecorder.isTypeSupported(type));
    if (!mimeType) { stream.getTracks().forEach(track => track.stop()); setRecording(false); setNotice('No supported WebM encoder in this browser.'); return; }
    const chunks: BlobPart[] = [];
    const recorder = new MediaRecorder(stream, { mimeType });
    let active = true;
    const paint = () => {
      if (!active || !ctx) return;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      const sourceVideo = videoRef.current;
      if (sourceVideo && sourceVideo.readyState >= 2 && sourceVideo.videoWidth > 0) {
        const scale = Math.max(canvas.width / sourceVideo.videoWidth, canvas.height / sourceVideo.videoHeight);
        const width = sourceVideo.videoWidth * scale; const height = sourceVideo.videoHeight * scale;
        ctx.drawImage(sourceVideo, (canvas.width - width) / 2, (canvas.height - height) / 2, width, height);
      } else {
        const gradient = ctx.createRadialGradient(640, 320, 30, 640, 360, 700);
        gradient.addColorStop(0, '#292050'); gradient.addColorStop(1, '#080b18');
        ctx.fillStyle = gradient; ctx.fillRect(0, 0, canvas.width, canvas.height);
      }
      const scale = Math.min(canvas.width / stageCanvas.width, canvas.height / stageCanvas.height);
      const width = stageCanvas.width * scale; const height = stageCanvas.height * scale;
      ctx.drawImage(stageCanvas, (canvas.width - width) / 2, (canvas.height - height) / 2, width, height);
      ctx.fillStyle = '#ffffff'; ctx.font = '700 26px system-ui'; ctx.textAlign = 'center';
      ctx.shadowColor = design.primaryColor; ctx.shadowBlur = 16;
      ctx.fillText(design.title.slice(0, 60), 640, 660); ctx.shadowBlur = 0;
      window.requestAnimationFrame(paint);
    };
    try {
      if (videoRef.current && videoUrl) { videoRef.current.muted = true; await videoRef.current.play().catch(() => undefined); }
      paint();
      recorder.ondataavailable = event => { if (event.data.size) chunks.push(event.data); };
      const completed = new Promise<Blob>((resolve, reject) => {
        recorder.onstop = () => resolve(new Blob(chunks, { type: mimeType }));
        recorder.onerror = () => reject(new Error('Video recording failed.'));
      });
      recorder.start(200);
      await new Promise(resolve => window.setTimeout(resolve, Math.max(2, Math.min(15, duration)) * 1000));
      active = false; if (recorder.state !== 'inactive') recorder.stop();
      const blob = await completed;
      stream.getTracks().forEach(track => track.stop());
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a'); a.href = url; a.download = 'darkvibex-' + category + '-composite.webm'; a.click();
      window.setTimeout(() => URL.revokeObjectURL(url), 5000);
      setNotice('Composite WebM exported (video layer + transparent 3D preview + title). Validate codec/runtime support before publishing to Android.');
    } catch (error) {
      active = false; stream.getTracks().forEach(track => track.stop());
      setNotice(error instanceof Error ? error.message : 'Composite video render failed.');
    } finally { setRecording(false); setPlaying(false); setPlayhead(0); }
  };

  const shownLibrary = library.filter(item => (!filter || item.category === filter) && (item.name.toLowerCase().includes(search.toLowerCase()) || item.category.toLowerCase().includes(search.toLowerCase())));
  const animationChoices = selected ? ['none', ...partAnimations[selected.shape]] : ['none'];
  const styleText = `
    .ac-backdrop{position:fixed;inset:0;z-index:200;background:#050610f5;backdrop-filter:blur(14px);overflow:auto;color:#f4f3ff;font-family:Inter,system-ui,sans-serif}
    .ac-shell{max-width:1700px;margin:0 auto;padding:18px}.ac-top{display:flex;gap:16px;align-items:center;justify-content:space-between;position:sticky;top:0;background:#0c0e1df5;border:1px solid #ffffff16;border-radius:16px;padding:13px 16px;z-index:5;backdrop-filter:blur(16px)}
    .ac-brand{display:flex;align-items:center;gap:10px}.ac-mark{width:38px;height:38px;display:grid;place-items:center;border-radius:12px;background:linear-gradient(145deg,#896fff,#3c3a82);font-size:21px}.ac-brand b{display:block;font-size:14px}.ac-brand small{display:block;color:#8e96b8;font-size:9px;letter-spacing:1.3px;margin-top:4px}
    .ac-actions{display:flex;gap:7px;flex-wrap:wrap;justify-content:flex-end}.ac-btn{display:inline-flex;gap:7px;align-items:center;justify-content:center;border:1px solid #ffffff18;border-radius:9px;background:#1b2037;color:#dfe1fa;padding:9px 11px;font-size:11px;font-weight:700}.ac-btn.primary{background:linear-gradient(100deg,#9c83ff,#70dfff);color:#111126;border:0}.ac-btn:disabled{opacity:.55;cursor:not-allowed}
    .ac-layout{display:grid;grid-template-columns:220px minmax(350px,1fr) 300px;gap:12px;margin-top:14px;align-items:start}.ac-panel{background:#111426;border:1px solid #ffffff14;border-radius:15px;padding:13px;min-width:0}.ac-panel h2{font-size:13px;margin:0 0 7px}.ac-muted{font-size:10px;line-height:1.6;color:#929bbc}.ac-label{display:block;font-size:10px;color:#aab0cf;margin:12px 0 6px}.ac-input,.ac-select,.ac-textarea{width:100%;min-width:0;background:#090c19;color:#f4f3ff;border:1px solid #313653;border-radius:8px;padding:9px;font:inherit;font-size:11px}.ac-textarea{min-height:72px;resize:vertical}.ac-cat{display:flex;align-items:center;gap:9px;width:100%;padding:10px;border-radius:9px;border:1px solid transparent;background:transparent;color:#b9c0dc;text-align:left;margin:3px 0}.ac-cat.active{background:#8870ff1e;border-color:#9d89ff70;color:white}.ac-cat i{font-style:normal;font-size:20px}.ac-cat span{font-size:11px}.ac-cat small{display:block;color:#8189aa;font-size:9px;margin-top:3px}
    .ac-library{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:7px;margin-top:10px}.ac-partcard{position:relative;text-align:left;padding:9px 7px;border:1px solid #ffffff14;border-radius:10px;background:#0b0e1c;color:#f3f2ff}.ac-partcard i{display:grid;place-items:center;width:34px;height:34px;border-radius:10px;background:linear-gradient(145deg,#302d5b,#121426);font-style:normal;font-size:19px;margin-bottom:6px}.ac-partcard b{display:block;font-size:10px}.ac-partcard small{font-size:9px;color:#8992b2}.ac-searchrow{display:flex;gap:6px}.ac-searchrow>*{min-width:0}.ac-preview{height:390px;position:relative;overflow:hidden;border:1px solid #ffffff18;border-radius:13px;background:radial-gradient(ellipse at center,#292050,#080b18 76%);isolation:isolate}.ac-preview video{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;z-index:0;opacity:.75}.ac-stage{position:absolute;inset:0;z-index:1}.ac-previewlabel{position:absolute;top:10px;left:10px;z-index:3;border:1px solid #ffffff22;border-radius:8px;background:#080b1bbd;color:#d5d8f5;padding:6px 8px;font-size:9px;letter-spacing:1px}.ac-previewtitle{position:absolute;bottom:14px;left:10px;right:10px;text-align:center;z-index:3;font-size:15px;font-weight:800;text-shadow:0 0 18px var(--ac-glow)}.ac-videoTag{position:absolute;right:9px;top:10px;z-index:3;color:#fff;background:#7d46baaa;padding:5px 8px;border-radius:7px;font-size:9px}
    .ac-partlist{display:flex;flex-direction:column;gap:5px;margin-top:9px}.ac-partrow{display:flex;align-items:center;gap:6px;border:1px solid #ffffff13;background:#0b0e1c;border-radius:8px;padding:7px;color:#ccd0eb}.ac-partrow.active{border-color:#a38bff;background:#8b71ff18}.ac-partrow button{border:0;background:transparent;color:inherit;padding:3px}.ac-partrow span{flex:1;text-align:left;font-size:10px;min-width:0;overflow-wrap:anywhere}.ac-pill{font-size:8px;color:#a99bff;border:1px solid #8d78ff44;border-radius:99px;padding:4px 6px}
    .ac-grid2{display:grid;grid-template-columns:1fr 1fr;gap:8px}.ac-slider{width:100%;accent-color:#9e8aff}.ac-timeline{margin-top:12px;background:#0b0e1b;border:1px solid #ffffff12;border-radius:11px;padding:12px}.ac-track{height:28px;display:flex;align-items:center;gap:5px;margin:6px 0}.ac-trackname{width:100px;flex-shrink:0;color:#acb3d2;font-size:9px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.ac-trackline{flex:1;height:18px;position:relative;background:#181c32;border-radius:5px;overflow:hidden}.ac-trackbar{position:absolute;top:3px;height:12px;border-radius:4px;background:linear-gradient(90deg,#8e71ff,#69dfff);min-width:8px}.ac-marker{position:absolute;top:0;bottom:0;width:2px;background:#ffdb7a;box-shadow:0 0 8px #ffdb7a;z-index:2;pointer-events:none}.ac-alert{margin-top:11px;border:1px solid #5fdcb444;background:#122827;border-radius:9px;padding:10px;color:#a9f3db;font-size:10px;line-height:1.5}.ac-video{display:flex;gap:7px;align-items:center;flex-wrap:wrap}.ac-chip{font-size:9px;color:#b4a8ff;background:#8e7aff15;border:1px solid #9a87ff32;padding:6px 8px;border-radius:9px}.ac-divider{border:0;border-top:1px solid #ffffff12;margin:13px 0}.ac-empty{padding:12px;color:#8d96b5;font-size:10px}
    @media(max-width:1200px){.ac-layout{grid-template-columns:200px minmax(0,1fr)}.ac-layout>.ac-panel:last-child{grid-column:1/-1}.ac-layout>.ac-panel:last-child .ac-partlist{display:grid;grid-template-columns:repeat(2,minmax(0,1fr))}}
    @media(max-width:760px){.ac-shell{padding:8px}.ac-top{position:relative;align-items:flex-start;flex-direction:column}.ac-actions{justify-content:flex-start}.ac-layout{grid-template-columns:1fr}.ac-layout>.ac-panel:last-child{grid-column:auto}.ac-layout>.ac-panel:last-child .ac-partlist{display:flex}.ac-preview{height:320px}.ac-library{grid-template-columns:repeat(3,minmax(0,1fr))}.ac-partcard i{width:28px;height:28px}.ac-trackname{width:68px}.ac-btn{font-size:10px;padding:8px}.ac-grid2{grid-template-columns:1fr 1fr}}
  `;

  return <div className="ac-backdrop" role="dialog" aria-modal="true" aria-label="Advanced component-based cosmetic editor">
    <style>{styleText}</style>
    <div className="ac-shell">
      <header className="ac-top">
        <div className="ac-brand"><div className="ac-mark">✦</div><div><b>DarkVibeX · 3D Animation Effects Editor</b><small>REAL 3D PREVIEW · PART EDITING · KEYFRAMES · VIDEO</small></div></div>
        <div className="ac-actions">
          <button className="ac-btn" onClick={exportProject}><Download size={14}/> Export project</button>
          <button className="ac-btn" onClick={() => projectFileRef.current?.click()}><Upload size={14}/> Import project</button>
          <button className="ac-btn primary" onClick={saveProject}><Save size={14}/> Save project</button>
          <button className="ac-btn" onClick={useInMainCreator}><CheckCircle2 size={14}/> Use in main creator</button>
          <button className="ac-btn" onClick={onClose} aria-label="Close advanced composer"><X size={15}/> Close</button>
          <input ref={projectFileRef} type="file" accept=".json,application/json" hidden onChange={event => void importProject(event.target.files?.[0])}/>
        </div>
      </header>
      <div className="ac-layout">
        <aside className="ac-panel">
          <h2>01 · Cosmetic category</h2><p className="ac-muted">Har category ka project alag save hota hai. Existing basic editor aur Owner publishing workflow ko overwrite nahi karta.</p>
          {categories.map(item => <button key={item.id} className={'ac-cat ' + (category === item.id ? 'active' : '')} onClick={() => changeCategory(item.id)}><i>{item.icon}</i><span>{item.label}<small>{item.subtitle}</small></span></button>)}
          <hr className="ac-divider"/>
          <h2>Template recipes · 100 in each category</h2><p className="ac-muted">1,100 procedural combinations generated from reusable component parts. These are editable starter recipes, not 1,100 hand-modelled source assets.</p>
          <input className="ac-input" value={templateSearch} onChange={event => setTemplateSearch(event.target.value)} placeholder="Find a recipe…"/>
          <select className="ac-select" value={selectedRecipeId} onChange={event => setSelectedRecipeId(event.target.value)} style={{marginTop:7}}>
            {templateRecipes.filter(recipe => recipe.category === category && recipe.name.toLowerCase().includes(templateSearch.toLowerCase())).map(recipe => <option key={recipe.id} value={recipe.id}>{recipe.id.split('-').pop()?.padStart(3,'0')} · {recipe.name}</option>)}
          </select>
          <button className="ac-btn primary" style={{width:'100%',marginTop:8}} onClick={applySelectedRecipe}>Apply template recipe</button>
          <hr className="ac-divider"/>
          <h2>Saved projects</h2>
          <select className="ac-select" value={loadedProjectId} onChange={event => loadProject(event.target.value)}><option value="">Select saved project…</option>{savedProjects.map(item => <option key={item.id} value={item.id}>{item.name} · {item.category}</option>)}</select>
          <label className="ac-label">Project name</label><input className="ac-input" value={projectName} onChange={event => setProjectName(event.target.value)} maxLength={100}/>
          <label className="ac-label">Final display duration · {duration}s</label><input className="ac-slider" type="range" min="2" max="15" step="1" value={duration} onChange={event => { const next = Number(event.target.value); setDuration(next); updateDesign({ durationSeconds: next }); }}/>
          {category === 'rocket-banner' && <div className="ac-chip" style={{display:'inline-block',marginTop:10}}>Countdown design target: 9 → 1</div>}
        </aside>

        <main className="ac-panel">
          <div style={{display:'flex',alignItems:'start',justifyContent:'space-between',gap:10,marginBottom:10}}><div><h2>02 · Live composition preview</h2><p className="ac-muted">Custom 3D scene plus individual ornament parts. Video clip can be layered with the preview and rendered into a WebM composition.</p></div><span className="ac-chip">3D PREVIEW</span></div>
          <div className="ac-preview" ref={previewRef} style={{['--ac-glow' as string]:design.primaryColor}}>
            {videoUrl && <video ref={videoRef} src={videoUrl} muted autoPlay loop playsInline controls aria-label="Imported vehicle-entry video preview"/>}
            <div className="ac-stage"><ThreeStage ref={stageRef} kind={baseKind} design={stageDesign} parts={timelineParts} timelineTime={playhead}/></div>
            <div className="ac-previewlabel">{currentCategory.label.toUpperCase()} · {parts.length} PARTS</div>
            {videoUrl && <div className="ac-videoTag">VIDEO LAYER · MUTED</div>}
            <div className="ac-previewtitle">{design.title}</div>
          </div>
          <div className="ac-actions" style={{marginTop:10,justifyContent:'flex-start'}}>
            <button className="ac-btn" onClick={() => setPlaying(value => !value)}>{playing ? <Pause size={14}/> : <Play size={14}/>} {playing ? 'Pause timeline' : 'Play timeline'}</button>
            <button className="ac-btn" onClick={() => { setPlayhead(0); setPlaying(false); }}><RotateCcw size={14}/> Reset timeline</button>
            <button className="ac-btn primary" onClick={() => void renderComposite()} disabled={recording}><Film size={14}/>{recording ? 'Rendering…' : 'Render composite WebM'}</button>
          </div>

          <section className="ac-timeline">
            <div style={{display:'flex',justifyContent:'space-between',gap:8,alignItems:'center'}}><b style={{fontSize:11}}>Animation timeline</b><span className="ac-chip">{playhead.toFixed(1)}s / {duration}s</span></div>
            <label className="ac-label">Playhead</label><input className="ac-slider" type="range" min="0" max={duration} step="0.1" value={Math.min(playhead,duration)} onChange={event => setPlayhead(Number(event.target.value))}/>
            {parts.map(part => {
              const related = keyframes.filter(frame => frame.partId === part.id);
              const hasAnimation = part.animation !== 'none';
              return <div className="ac-track" key={part.id}><span className="ac-trackname">{part.name}</span><div className="ac-trackline"><div className="ac-marker" style={{left:(Math.min(playhead,duration)/duration*100)+'%'}}/>{hasAnimation && <div className="ac-trackbar" style={{left:'2%',width:'96%',opacity:part.enabled?0.95:0.25}}/>}{related.map(frame => <button key={frame.id} title={frame.label+' at '+frame.time+'s'} onClick={() => setPlayhead(frame.time)} style={{position:'absolute',left:(frame.time/duration*100)+'%',top:0,width:7,height:'100%',border:0,padding:0,background:'#ffe17b',zIndex:2}}/> )}</div></div>;
            })}
            <div className="ac-actions" style={{justifyContent:'space-between',alignItems:'center'}}><span className="ac-muted">Set a pose, add a keyframe, move the playhead, then change the pose and add another.</span><div style={{display:'flex',gap:6,flexWrap:'wrap'}}><button className="ac-btn" onClick={addKeyframe}><Plus size={13}/> Add keyframe</button><button className="ac-btn" onClick={deleteNearestKeyframe}><Trash2 size={13}/> Delete nearest</button></div></div>
          </section>

          <hr className="ac-divider"/>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',gap:8}}><div><h2>03 · Choose any component</h2><p className="ac-muted">Butterfly from one template, flowers from another, crystals or other ornaments — combine them in the same design.</p></div><span className="ac-chip">{parts.filter(part => part.enabled).length} enabled</span></div>
          <div className="ac-searchrow" style={{marginTop:10}}><input className="ac-input" value={search} onChange={event => setSearch(event.target.value)} placeholder="Search parts (butterfly, crystal…)"/><select className="ac-select" value={filter} onChange={event => setFilter(event.target.value)} style={{width:125}}><option value="">All groups</option>{Array.from(new Set(library.map(item => item.category))).map(item => <option key={item}>{item}</option>)}</select></div>
          <div className="ac-library">{shownLibrary.map(item => <button className="ac-partcard" key={item.name} onClick={() => addLibraryPart(item)}><i>{item.shape==='butterfly'?'🦋':item.shape==='flower'?'🌸':item.shape==='leaf'?'🍃':item.shape==='crystal'?'💎':item.shape==='star'?'⭐':item.shape==='ring'?'⭕':item.shape==='orb'?'🔮':item.shape==='flame'?'🔥':item.shape==='heart'?'💗':item.shape==='spark'?'✨':'🚀'}</i><b>{item.name}</b><small>{item.category} · {item.animation}</small><span style={{display:'block',height:4,borderRadius:9,marginTop:7,background:item.color}}/></button>)}</div>

          <hr className="ac-divider"/>
          <h2>04 · Video layer / vehicle video maker</h2><p className="ac-muted">Import a real clip, preview it muted with the 3D scene, then render a composite WebM. The source video is kept locally and is not uploaded automatically.</p>
          <div className="ac-video"><button className="ac-btn" onClick={() => videoFileRef.current?.click()}><Film size={14}/> Import video</button><input ref={videoFileRef} type="file" hidden accept="video/*,.mp4,.webm,.mov" onChange={event => importVideo(event.target.files?.[0])}/>{videoName && <span className="ac-chip">{videoName}</span>}{videoUrl && <button className="ac-btn" onClick={() => { URL.revokeObjectURL(videoUrl); setVideoUrl(''); setVideoName(''); setVideoError(''); }}><Trash2 size={13}/> Remove video</button>}</div>
          {videoError && <p className="ac-muted" style={{color:'#ff96ae'}}>{videoError}</p>}
          <div className="ac-grid2"><div><label className="ac-label">Project title</label><input className="ac-input" value={design.title} onChange={event => updateDesign({title:event.target.value})}/></div><div><label className="ac-label">Subtitle / preview text</label><input className="ac-input" value={design.previewText} onChange={event => updateDesign({previewText:event.target.value})}/></div><div><label className="ac-label">Primary colour</label><input className="ac-input" type="color" value={design.primaryColor} onChange={event => updateDesign({primaryColor:event.target.value})}/></div><div><label className="ac-label">Secondary colour</label><input className="ac-input" type="color" value={design.secondaryColor} onChange={event => updateDesign({secondaryColor:event.target.value})}/></div></div>
        </main>

        <aside className="ac-panel">
          <h2>05 · Layers & part settings</h2><p className="ac-muted">Select one layer to change its colour, material, position, size, rotation and its own animation independently.</p>
          <div className="ac-partlist">{parts.map((part,index) => <div className={'ac-partrow '+(selected?.id===part.id?'active':'')} key={part.id}><button onClick={() => setSelectedId(part.id)} title="Select component"><Layers3 size={13}/></button><span onClick={() => setSelectedId(part.id)} style={{cursor:'pointer'}}>{part.name}<small style={{display:'block',color:'#8189aa',fontSize:8}}>{part.shape} · {part.animation}</small></span><button onClick={() => setParts(old => old.map(p => p.id===part.id?{...p,enabled:!p.enabled}:p))} title={part.enabled?'Hide layer':'Show layer'}>{part.enabled?<Eye size={13}/>:<EyeOff size={13}/>}</button><button disabled={index===0} onClick={() => setParts(old => {const next=[...old];[next[index-1],next[index]]=[next[index],next[index-1]];return next;})} title="Move up"><ChevronUp size={13}/></button><button disabled={index===parts.length-1} onClick={() => setParts(old => {const next=[...old];[next[index+1],next[index]]=[next[index],next[index+1]];return next;})} title="Move down"><ChevronDown size={13}/></button></div>)}</div>
          <div className="ac-actions" style={{marginTop:9,justifyContent:'flex-start'}}><button className="ac-btn" onClick={duplicateSelected} disabled={!selected}><Copy size={13}/> Duplicate</button><button className="ac-btn" onClick={deleteSelected} disabled={!selected}><Trash2 size={13}/> Remove</button></div>
          {selected ? <>
            <label className="ac-label">Selected component</label><input className="ac-input" value={selected.name} onChange={event => updatePart({name:event.target.value})}/>
            <label className="ac-label">Replace selected part</label><select className="ac-select" value="" onChange={event => {const item=library.find(entry=>entry.name===event.target.value);if(item)replaceSelected(item);}}><option value="">Select another library part…</option>{library.map(item=><option key={item.name} value={item.name}>{item.name} · {item.category}</option>)}</select>
            <div className="ac-grid2"><div><label className="ac-label">Colour</label><input className="ac-input" type="color" value={selected.color} onChange={event => updatePart({color:event.target.value})}/></div><div><label className="ac-label">Material</label><select className="ac-select" value={selected.material} onChange={event => updatePart({material:event.target.value as ScenePart['material']})}>{['metallic','crystal','neon','glass','glossy','matte'].map(value=><option key={value} value={value}>{value}</option>)}</select></div></div>
            <label className="ac-label">Independent animation</label><select className="ac-select" value={selected.animation} onChange={event => updatePart({animation:event.target.value})}>{animationChoices.map(value=><option key={value} value={value}>{value}</option>)}</select><p className="ac-muted" style={{marginTop:6}}>{animationDescriptions[selected.animation] || 'Motion is applied to this component independently in the preview.'}</p>
            <div className="ac-grid2"><div><label className="ac-label">X position · {selected.x.toFixed(2)}</label><input className="ac-slider" type="range" min="-2.3" max="2.3" step=".05" value={selected.x} onChange={event => updatePart({x:Number(event.target.value)})}/></div><div><label className="ac-label">Y position · {selected.y.toFixed(2)}</label><input className="ac-slider" type="range" min="-1.8" max="1.8" step=".05" value={selected.y} onChange={event => updatePart({y:Number(event.target.value)})}/></div><div><label className="ac-label">Depth · {selected.z.toFixed(2)}</label><input className="ac-slider" type="range" min="-1.0" max="1.2" step=".05" value={selected.z} onChange={event => updatePart({z:Number(event.target.value)})}/></div><div><label className="ac-label">Size · {selected.scale.toFixed(2)}×</label><input className="ac-slider" type="range" min=".1" max="1.1" step=".05" value={selected.scale} onChange={event => updatePart({scale:Number(event.target.value)})}/></div></div>
            <label className="ac-label">Rotation · {selected.rotation}°</label><input className="ac-slider" type="range" min="-180" max="180" step="5" value={selected.rotation} onChange={event => updatePart({rotation:Number(event.target.value)})}/>
          </> : <div className="ac-empty">Add a component from the library to begin editing.</div>}
          <hr className="ac-divider"/>
          <h2>06 · Export and compatibility</h2><p className="ac-muted">Transform keyframes animate component position, depth, scale and rotation; they are saved with the project and move with the composition when applied to the main creator. GLB export preserves the current 3D pose; use WebM/MP4 for timed motion.</p>
          <div className="ac-alert"><CheckCircle2 size={14} style={{verticalAlign:'middle',marginRight:6}}/>Local project ready · {parts.length} component(s) · {keyframes.length} keyframe marker(s)</div>
        </aside>
      </div>
      {notice && <div className="ac-alert" role="status">{notice}</div>}
    </div>
  </div>;
}

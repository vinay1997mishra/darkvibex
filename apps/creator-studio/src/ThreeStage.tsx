import { forwardRef, useEffect, useImperativeHandle, useRef } from 'react';
import * as THREE from 'three';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';

export type TransformKeyframe = {
  time: number;
  x: number;
  y: number;
  z: number;
  scale: number;
  rotation: number;
};

export type ScenePart = {
  id: string;
  name: string;
  shape: 'butterfly' | 'flower' | 'leaf' | 'crystal' | 'star' | 'ring' | 'orb' | 'flame' | 'heart' | 'spark' | 'rocket' | 'car-body' | 'car-wheel' | 'car-glass' | 'car-light' | 'car-spoiler' | 'car-exhaust';
  color: string;
  material: 'metallic' | 'crystal' | 'neon' | 'glass' | 'glossy' | 'matte';
  animation: string;
  x: number;
  y: number;
  z: number;
  scale: number;
  rotation: number;
  enabled: boolean;
  keyframes?: TransformKeyframe[];
};

export type QualityCheckResult = {
  label: string;
  status: 'pass' | 'warn' | 'fail';
  detail: string;
};

export type StageHandle = {
  exportGlb: () => Promise<void>;
  recordWebm: () => Promise<void>;
  recordMp4: () => Promise<void>;
  exportPng: () => Promise<void>;
  qualityCheck: () => Promise<QualityCheckResult[]>;
};

type Props = {
  kind: 'gift' | 'frame' | 'entry' | 'vehicle' | 'bubble';
  modelUrl?: string;
  design: {
    title: string; concept: string; icon: string; primaryColor: string;
    secondaryColor: string; motion: string; particles: string; durationSeconds: number;
    loop: boolean; rarity: string; previewText: string;
  };
  parts?: ScenePart[];
  timelineTime?: number;
};

const download = (blob: Blob, name: string) => {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  a.click();
  window.setTimeout(() => URL.revokeObjectURL(url), 1500);
};

export const ThreeStage = forwardRef<StageHandle, Props>(function ThreeStage({ kind, design, modelUrl, parts = [], timelineTime }, ref) {
  const host = useRef<HTMLDivElement>(null);
  const runtime = useRef<{ renderer: THREE.WebGLRenderer; scene: THREE.Scene; camera: THREE.PerspectiveCamera; group: THREE.Group; particles: THREE.Points; raf: number } | null>(null);
  const partsKey = JSON.stringify(parts);
  const latest = useRef({ kind, design, modelUrl, parts, timelineTime });
  latest.current = { kind, design, modelUrl, parts, timelineTime };

  useImperativeHandle(ref, () => ({
    qualityCheck: async () => {
      const state = runtime.current;
      if (!state) throw new Error('3D preview is still loading');
      const results: QualityCheckResult[] = [];
      const canvas = state.renderer.domElement as HTMLCanvasElement & { captureStream?: (fps?: number) => MediaStream };
      const contextLost = state.renderer.getContext().isContextLost();
      results.push({
        label: 'WebGL renderer',
        status: !contextLost && canvas.width >= 320 && canvas.height >= 240 ? 'pass' : 'fail',
        detail: !contextLost && canvas.width >= 320 && canvas.height >= 240
          ? `Live canvas ${canvas.width}×${canvas.height}; WebGL context is active.`
          : 'WebGL context or canvas dimensions are invalid.'
      });

      let meshCount = 0;
      let triangleCount = 0;
      state.scene.traverse(object => {
        if (!(object instanceof THREE.Mesh) || !object.visible) return;
        meshCount += 1;
        const geometry = object.geometry;
        const position = geometry.getAttribute('position');
        triangleCount += geometry.index ? geometry.index.count / 3 : (position?.count ?? 0) / 3;
      });
      results.push({
        label: '3D geometry',
        status: meshCount > 0 && triangleCount >= 12 ? 'pass' : 'fail',
        detail: `${meshCount} visible mesh(es), approximately ${Math.round(triangleCount)} triangles in the current scene.`
      });

      const previousFog = state.scene.fog;
      const previousBackground = state.scene.background;
      const previousParticlesVisible = state.particles.visible;
      try {
        state.scene.fog = null;
        state.scene.background = null;
        state.particles.visible = false;
        state.renderer.render(state.scene, state.camera);
        const png = await new Promise<Blob>((resolve, reject) => {
          canvas.toBlob(blob => blob ? resolve(blob) : reject(new Error('Canvas PNG capture returned an empty result')), 'image/png');
        });
        results.push({
          label: 'PNG render pipeline',
          status: png.type === 'image/png' && png.size > 300 ? 'pass' : 'fail',
          detail: `Transparent-canvas capture: ${Math.round(png.size / 1024)} KB; ${canvas.width}×${canvas.height}.`
        });
      } catch (error) {
        results.push({ label: 'PNG render pipeline', status: 'fail', detail: error instanceof Error ? error.message : 'PNG capture failed.' });
      } finally {
        state.scene.fog = previousFog;
        state.scene.background = previousBackground;
        state.particles.visible = previousParticlesVisible;
        state.renderer.render(state.scene, state.camera);
      }

      try {
        const exporter = new GLTFExporter();
        const glb = await new Promise<ArrayBuffer>((resolve, reject) => {
          exporter.parse(state.scene, result => {
            if (result instanceof ArrayBuffer) resolve(result);
            else reject(new Error('Exporter returned JSON instead of binary GLB'));
          }, error => reject(error), { binary: true, onlyVisible: true });
        });
        const valid = glb.byteLength >= 12 &&
          String.fromCharCode(glb[0], glb[1], glb[2], glb[3]) === 'glTF' &&
          new DataView(glb).getUint32(4, true) === 2 &&
          new DataView(glb).getUint32(8, true) === glb.byteLength;
        results.push({
          label: 'GLB export integrity',
          status: valid ? 'pass' : 'fail',
          detail: valid ? `Binary GLB header/version/length verified (${Math.round(glb.byteLength / 1024)} KB).` : 'GLB signature, version, or declared length did not validate.'
        });
      } catch (error) {
        results.push({ label: 'GLB export integrity', status: 'fail', detail: error instanceof Error ? error.message : 'GLB export failed.' });
      }

      const videoMime = typeof MediaRecorder !== 'undefined'
        ? ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'].find(type => MediaRecorder.isTypeSupported(type))
        : undefined;
      if (!canvas.captureStream || !videoMime) {
        results.push({ label: 'WebM video capture', status: 'warn', detail: 'This browser does not expose a supported MediaRecorder/WebM codec; still-image and GLB checks can be used, but render video here is not verified.' });
      } else {
        const stream = canvas.captureStream(15);
        try {
          const recorder = new MediaRecorder(stream, { mimeType: videoMime });
          const videoBlob = await new Promise<Blob>((resolve, reject) => {
            const chunks: BlobPart[] = [];
            recorder.ondataavailable = event => { if (event.data.size) chunks.push(event.data); };
            recorder.onerror = () => reject(new Error('MediaRecorder emitted an error during its smoke test.'));
            recorder.onstop = () => resolve(new Blob(chunks, { type: videoMime }));
            recorder.start(100);
            window.setTimeout(() => { if (recorder.state !== 'inactive') recorder.stop(); }, 800);
          });
          results.push({
            label: 'WebM video capture',
            status: videoBlob.size > 0 ? 'pass' : 'fail',
            detail: videoBlob.size > 0 ? `Short recording produced ${Math.round(videoBlob.size / 1024)} KB of ${videoBlob.type || videoMime}.` : 'Video capture completed without recording any bytes.'
          });
        } catch (error) {
          results.push({ label: 'WebM video capture', status: 'warn', detail: error instanceof Error ? error.message : 'Video capture is unavailable in this browser.' });
        } finally {
          stream.getTracks().forEach(track => track.stop());
        }
      }
      return results;
    },
    exportGlb: async () => {
      const state = runtime.current;
      if (!state) throw new Error('3D scene is not ready');
      const exporter = new GLTFExporter();
      const output = await new Promise<ArrayBuffer>((resolve, reject) => {
        exporter.parse(state.scene, result => {
          if (result instanceof ArrayBuffer) resolve(result);
          else reject(new Error('GLB exporter did not return binary data'));
        }, error => reject(error), { binary: true, onlyVisible: true });
      });
      download(new Blob([output], { type: 'model/gltf-binary' }), 'darkvibex-' + latest.current.kind + '.glb');
    },
    exportPng: async () => {
      const state = runtime.current;
      if (!state) throw new Error('3D scene is not ready');
      const previousFog = state.scene.fog;
      const previousBackground = state.scene.background;
      const previousParticlesVisible = state.particles.visible;
      state.scene.fog = null;
      state.scene.background = null;
      state.particles.visible = false;
      state.renderer.render(state.scene, state.camera);
      try {
        const blob = await new Promise<Blob>((resolve, reject) => {
          state.renderer.domElement.toBlob(value => value ? resolve(value) : reject(new Error('Transparent PNG export failed in this browser')), 'image/png');
        });
        download(blob, 'darkvibex-' + latest.current.kind + '-transparent.png');
      } finally {
        state.scene.fog = previousFog;
        state.scene.background = previousBackground;
        state.particles.visible = previousParticlesVisible;
        state.renderer.render(state.scene, state.camera);
      }
    },
    recordWebm: async () => {
      const state = runtime.current;
      if (!state) throw new Error('3D scene is not ready');
      const canvas = state.renderer.domElement as HTMLCanvasElement & { captureStream?: (fps?: number) => MediaStream };
      if (!canvas.captureStream || typeof MediaRecorder === 'undefined') throw new Error('This browser does not support WebM capture');
      const stream = canvas.captureStream(30);
      const mime = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'].find(type => MediaRecorder.isTypeSupported(type));
      const recorder = new MediaRecorder(stream, mime ? { mimeType: mime } : undefined);
      const chunks: BlobPart[] = [];
      recorder.ondataavailable = event => { if (event.data.size) chunks.push(event.data); };
      const done = new Promise<void>((resolve, reject) => {
        recorder.onerror = () => reject(new Error('Recording failed'));
        recorder.onstop = () => resolve();
      });
      recorder.start(250);
      await new Promise(resolve => window.setTimeout(resolve, Math.max(3, Math.min(12, latest.current.design.durationSeconds)) * 1000));
      recorder.stop();
      await done;
      stream.getTracks().forEach(track => track.stop());
      download(new Blob(chunks, { type: mime || 'video/webm' }), 'darkvibex-' + latest.current.kind + '-animation.webm');
    },
    recordMp4: async () => {
      const state = runtime.current;
      if (!state) throw new Error('3D scene is not ready');
      const canvas = state.renderer.domElement as HTMLCanvasElement & { captureStream?: (fps?: number) => MediaStream };
      if (!canvas.captureStream || typeof MediaRecorder === 'undefined') throw new Error('This browser cannot record the 3D canvas');
      const mp4Type = ['video/mp4;codecs=avc1.42E01E', 'video/mp4'].find(type => MediaRecorder.isTypeSupported(type));
      const stream = canvas.captureStream(30);
      const targetType = mp4Type || ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'].find(type => MediaRecorder.isTypeSupported(type));
      if (!targetType) throw new Error('No supported browser recording codec was found');
      const recorder = new MediaRecorder(stream, { mimeType: targetType });
      const chunks: BlobPart[] = [];
      recorder.ondataavailable = event => { if (event.data.size) chunks.push(event.data); };
      const finished = new Promise<void>((resolve, reject) => { recorder.onerror = () => reject(new Error('Canvas recording failed')); recorder.onstop = resolve; });
      recorder.start(250);
      await new Promise(resolve => window.setTimeout(resolve, Math.max(3, Math.min(12, latest.current.design.durationSeconds)) * 1000));
      recorder.stop();
      await finished;
      stream.getTracks().forEach(track => track.stop());
      const source = new Blob(chunks, { type: targetType });
      if (targetType.startsWith('video/mp4')) {
        download(source, 'darkvibex-' + latest.current.kind + '-animation.mp4');
        return;
      }
      try {
        const { FFmpeg } = await import('@ffmpeg/ffmpeg');
        const { toBlobURL } = await import('@ffmpeg/util');
        const ffmpeg = new FFmpeg();
        const coreBase = 'https://unpkg.com/@ffmpeg/core@0.12.10/dist/umd';
        await ffmpeg.load({
          coreURL: await toBlobURL(coreBase + '/ffmpeg-core.js', 'text/javascript'),
          wasmURL: await toBlobURL(coreBase + '/ffmpeg-core.wasm', 'application/wasm')
        });
        await ffmpeg.writeFile('input.webm', new Uint8Array(await source.arrayBuffer()));
        await ffmpeg.exec(['-i', 'input.webm', '-an', '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', 'output.mp4']);
        const output = await ffmpeg.readFile('output.mp4');
        if (typeof output === 'string') throw new Error('MP4 encoder returned invalid output');
        const mp4Buffer = output.buffer.slice(output.byteOffset, output.byteOffset + output.byteLength) as ArrayBuffer;
        download(new Blob([mp4Buffer], { type: 'video/mp4' }), 'darkvibex-' + latest.current.kind + '-animation.mp4');
        await ffmpeg.terminate();
      } catch (e) {
        download(source, 'darkvibex-' + latest.current.kind + '-animation.webm');
        const reason = e instanceof Error ? e.message : 'FFmpeg failed to load';
        throw new Error('MP4 conversion failed in this browser; WebM fallback was downloaded. ' + reason);
      }
    }
  }), []);

  useEffect(() => {
    if (!host.current) return;
    const element = host.current;
    const scene = new THREE.Scene();
    scene.background = null;
    scene.fog = new THREE.Fog('#090b18', 6, 15);
    const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100);
    camera.position.set(0, 0.15, 6.7);
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.2;
    renderer.domElement.style.width = '100%';
    renderer.domElement.style.height = '100%';
    renderer.domElement.style.display = 'block';
    element.appendChild(renderer.domElement);
    scene.add(new THREE.AmbientLight(0xffffff, 1.5));
    const key = new THREE.PointLight(0xffffff, 38); key.position.set(3, 4, 5); scene.add(key);
    const rim = new THREE.PointLight(0x8066ff, 25); rim.position.set(-3, 1, -2); scene.add(rim);
    const group = new THREE.Group(); scene.add(group);
    const particleGeometry = new THREE.BufferGeometry();
    const particleCount = 160;
    const positions = new Float32Array(particleCount * 3);
    for (let i = 0; i < particleCount; i++) {
      positions[i * 3] = (Math.random() - 0.5) * 6;
      positions[i * 3 + 1] = (Math.random() - 0.5) * 4.8;
      positions[i * 3 + 2] = (Math.random() - 0.5) * 3;
    }
    particleGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    const particles = new THREE.Points(particleGeometry, new THREE.PointsMaterial({ color: 0x91eaff, size: 0.035, transparent: true, opacity: 0.9, depthWrite: false }));
    scene.add(particles);
    let modelRoot: THREE.Object3D | null = null;
    let mixer: THREE.AnimationMixer | null = null;
    let loadActive = true;
    if (modelUrl) {
      group.visible = false;
      const loader = new GLTFLoader();
      loader.load(modelUrl, gltf => {
        if (!loadActive) return;
        modelRoot = gltf.scene;
        const bounds = new THREE.Box3().setFromObject(modelRoot);
        const size = bounds.getSize(new THREE.Vector3());
        const center = bounds.getCenter(new THREE.Vector3());
        modelRoot.position.sub(center);
        const maxDimension = Math.max(size.x, size.y, size.z) || 1;
        modelRoot.scale.setScalar(2.7 / maxDimension);
        scene.add(modelRoot);
        if (gltf.animations.length) {
          mixer = new THREE.AnimationMixer(modelRoot);
          gltf.animations.forEach(clip => mixer?.clipAction(clip).play());
        }
      }, undefined, () => { /* download link remains available if remote preview is blocked */ });
    }
    const material = (color: string, metalness = 0.55, roughness = 0.22) => new THREE.MeshStandardMaterial({ color, metalness, roughness, emissive: color, emissiveIntensity: 0.13 });
    const addMesh = (geometry: THREE.BufferGeometry, mat: THREE.Material, parent = group, position: [number, number, number] = [0, 0, 0]) => {
      const mesh = new THREE.Mesh(geometry, mat);
      mesh.position.set(...position);
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      parent.add(mesh);
      return mesh;
    };
    const rebuild = () => {
      while (group.children.length) {
        const child = group.children[group.children.length - 1];
        group.remove(child);
        child.traverse(object => {
          if (object instanceof THREE.Mesh || object instanceof THREE.Line) {
            object.geometry.dispose();
            const mats = Array.isArray(object.material) ? object.material : [object.material];
            mats.forEach(m => m.dispose());
          }
        });
      }
      const { kind: k, design: d } = latest.current;
      const a = material(d.primaryColor, 0.72, 0.2);
      const b = material(d.secondaryColor, 0.62, 0.24);
      const dark = material('#171a31', 0.35, 0.3);
      const gold = material('#f7d778', 0.85, 0.18);
      if (k === 'frame') {
        const outer = addMesh(new THREE.TorusGeometry(1.17, 0.105, 24, 160), a);
        outer.userData.spinSpeed = 0.16;
        const inner = addMesh(new THREE.TorusGeometry(1.00, 0.035, 12, 140), b);
        inner.userData.spinSpeed = -0.24;
        const halo = addMesh(new THREE.TorusGeometry(1.31, 0.018, 8, 140), gold);
        halo.rotation.set(0.18, 0.2, 0.38);
        halo.userData.spinSpeed = 0.42;
        const innerHalo = addMesh(new THREE.TorusGeometry(0.87, 0.018, 8, 120), a);
        innerHalo.rotation.set(-0.12, 0.15, -0.28);
        innerHalo.userData.spinSpeed = -0.32;
        const center = addMesh(new THREE.CircleGeometry(0.82, 96), dark);
        center.position.z = -0.06;
        for (let i = 0; i < 12; i++) {
          const angle = i * Math.PI / 6;
          const radius = i % 3 === 0 ? 1.15 : 1.08;
          const gem = addMesh(new THREE.OctahedronGeometry(i % 3 === 0 ? 0.14 : 0.075, 1), i % 2 ? gold : b, group, [Math.cos(angle) * radius, Math.sin(angle) * radius, 0.12]);
          gem.rotation.set(angle, angle * 0.5, angle);
          gem.userData.orbitAngle = angle;
          gem.userData.orbitRadius = radius;
          gem.userData.orbitSpeed = i % 2 ? 0.22 : -0.16;
        }
        for (let i = 0; i < 16; i++) {
          const angle = i * Math.PI / 8;
          const bead = addMesh(new THREE.SphereGeometry(0.027, 12, 10), i % 2 ? a : gold, group, [Math.cos(angle) * 1.25, Math.sin(angle) * 1.25, 0.04]);
          bead.userData.orbitAngle = angle;
          bead.userData.orbitRadius = 1.25;
          bead.userData.orbitSpeed = i % 2 ? 0.3 : -0.24;
        }
        for (let i = 0; i < 24; i++) {
          const angle = i * Math.PI / 12;
          const radius = i % 2 ? 1.2 : 1.28;
          const crystal = addMesh(new THREE.TetrahedronGeometry(i % 3 === 0 ? 0.065 : 0.038, 1), i % 2 ? b : gold, group, [Math.cos(angle) * radius, Math.sin(angle) * radius, 0.14]);
          crystal.rotation.set(angle, angle * 0.7, angle * 0.35);
          crystal.userData.pulseOffset = i * 0.11;
        }
      } else if (k === 'vehicle') {
        const body = addMesh(new RoundedBoxGeometry(2.35, 0.43, 0.92, 5, 0.12), a, group, [0, -0.12, 0]);
        body.rotation.z = -0.025;
        addMesh(new RoundedBoxGeometry(1.22, 0.42, 0.72, 5, 0.1), b, group, [0.08, 0.24, 0]);
        addMesh(new RoundedBoxGeometry(0.95, 0.065, 0.96, 3, 0.025), gold, group, [0, -0.39, 0]);
        addMesh(new RoundedBoxGeometry(0.68, 0.16, 0.66, 4, 0.06), dark, group, [-0.1, 0.3, 0.02]);
        for (const x of [-0.72, 0.72]) for (const z of [-0.48, 0.48]) {
          const wheel = addMesh(new THREE.CylinderGeometry(0.25, 0.25, 0.16, 32), dark, group, [x, -0.38, z]);
          wheel.rotation.x = Math.PI / 2;
          wheel.userData.wheel = true;
          const hub = addMesh(new THREE.CylinderGeometry(0.13, 0.13, 0.17, 24), gold, group, [x, -0.38, z * 1.02]);
          hub.rotation.x = Math.PI / 2;
          hub.userData.wheel = true;
        }
        for (const x of [-0.91, 0.91]) {
          const lamp = addMesh(new RoundedBoxGeometry(0.24, 0.085, 0.07, 3, 0.025), gold, group, [x, -0.05, 0.47]);
          lamp.material = new THREE.MeshStandardMaterial({ color: '#fff1ad', emissive: '#ffe38a', emissiveIntensity: 2.4, metalness: 0.25, roughness: 0.18 });
        }
        const underglow = addMesh(new THREE.BoxGeometry(1.9, 0.018, 0.72), b, group, [0, -0.43, 0]);
        underglow.material = new THREE.MeshBasicMaterial({ color: d.secondaryColor, transparent: true, opacity: 0.7 });
        const frontSplitter = addMesh(new RoundedBoxGeometry(1.42, 0.06, 0.98, 3, 0.025), dark, group, [0.18, -0.34, 0]);
        const rearSpoiler = addMesh(new RoundedBoxGeometry(0.72, 0.055, 0.18, 3, 0.025), gold, group, [-0.86, 0.18, 0]);
        for (const z of [-0.35, 0.35]) addMesh(new RoundedBoxGeometry(0.08, 0.22, 0.08, 3, 0.02), b, group, [-0.82, 0.08, z]);
        for (const x of [-0.95, 0.95]) {
          const exhaust = addMesh(new THREE.CylinderGeometry(0.065, 0.085, 0.18, 20), dark, group, [x * 0.72, -0.27, -0.32]);
          exhaust.rotation.z = Math.PI / 2;
        }
        for (let i = 0; i < 6; i++) {
          const streak = addMesh(new THREE.SphereGeometry(0.035 + (i % 2) * 0.018, 12, 10), i % 2 ? a : b, group, [-1.35 - i * 0.13, -0.18 + Math.sin(i) * 0.16, -0.08]);
          streak.userData.trailOffset = i;
          streak.userData.pulseOffset = i * 0.2;
        }
      } else if (k === 'entry') {
        const portal = addMesh(new THREE.TorusGeometry(1.12, 0.105, 24, 144), a);
        portal.scale.y = 1.28;
        portal.userData.spinSpeed = 0.16;
        const inner = addMesh(new THREE.TorusGeometry(0.91, 0.035, 12, 128), b);
        inner.scale.y = 1.28;
        inner.userData.spinSpeed = -0.28;
        const outerHalo = addMesh(new THREE.TorusGeometry(1.35, 0.022, 8, 144), gold);
        outerHalo.scale.y = 1.28;
        outerHalo.rotation.z = 0.28;
        outerHalo.userData.spinSpeed = 0.38;
        const portalCore = addMesh(new THREE.CircleGeometry(0.89, 96), dark, group, [0, 0, -0.34]);
        portalCore.scale.y = 1.25;
        portalCore.material = new THREE.MeshBasicMaterial({ color: d.secondaryColor, transparent: true, opacity: 0.16, side: THREE.DoubleSide, depthWrite: false });
        const energy = addMesh(new THREE.IcosahedronGeometry(0.52, 2), b, group, [0, 0, -0.12]);
        energy.material = new THREE.MeshStandardMaterial({ color: d.secondaryColor, emissive: d.secondaryColor, emissiveIntensity: 1.05, metalness: 0.5, roughness: 0.18, transparent: true, opacity: 0.82, wireframe: true });
        energy.userData.spinSpeed = 0.7;
        const coreGem = addMesh(new THREE.OctahedronGeometry(0.23, 2), a, group, [0, 0, 0.04]);
        coreGem.material = new THREE.MeshPhysicalMaterial({ color: d.primaryColor, emissive: d.primaryColor, emissiveIntensity: 0.7, metalness: 0.4, roughness: 0.12, transmission: 0.12, clearcoat: 1 });
        coreGem.userData.pulseOffset = 0.15;
        for (let i = 0; i < 12; i++) {
          const angle = i * Math.PI / 6;
          const radius = i % 2 ? 1.22 : 1.34;
          const shard = addMesh(new THREE.OctahedronGeometry(i % 3 === 0 ? 0.09 : 0.055, 1), i % 2 ? a : gold, group, [Math.cos(angle) * radius, Math.sin(angle) * radius * 1.22, 0.08]);
          shard.userData.orbitAngle = angle;
          shard.userData.orbitRadius = radius;
          shard.userData.orbitSpeed = i % 2 ? 0.34 : -0.22;
        }
        for (let i = 0; i < 5; i++) {
          const ribbon = addMesh(new THREE.TorusGeometry(0.66 + i * 0.055, 0.012, 6, 96), i % 2 ? a : b, group, [0, 0, -0.22 + i * 0.045]);
          ribbon.scale.y = 1.18;
          ribbon.rotation.z = i * 0.34;
          ribbon.userData.spinSpeed = i % 2 ? 0.24 : -0.2;
        }
      } else if (k === 'bubble') {
        const glass = addMesh(new RoundedBoxGeometry(2.48, 1.34, 0.24, 8, 0.16), dark);
        glass.material = new THREE.MeshPhysicalMaterial({ color: '#20284a', metalness: 0.28, roughness: 0.16, transmission: 0.18, transparent: true, opacity: 0.94, clearcoat: 1, clearcoatRoughness: 0.12 });
        const outline = addMesh(new RoundedBoxGeometry(2.55, 1.4, 0.12, 8, 0.18), a);
        outline.material = new THREE.MeshStandardMaterial({ color: d.primaryColor, emissive: d.primaryColor, emissiveIntensity: 0.42, metalness: 0.78, roughness: 0.18, wireframe: true });
        outline.userData.spinSpeed = 0.12;
        const innerRim = addMesh(new RoundedBoxGeometry(2.34, 1.2, 0.055, 8, 0.15), b, group, [0, 0, 0.14]);
        innerRim.material = new THREE.MeshBasicMaterial({ color: d.secondaryColor, transparent: true, opacity: 0.45, wireframe: true });
        innerRim.userData.spinSpeed = -0.1;
        const highlight = addMesh(new THREE.TorusGeometry(0.35, 0.012, 6, 64, Math.PI * 1.2), gold, group, [0.74, 0.48, 0.17]);
        highlight.rotation.z = -0.4;
        highlight.userData.spinSpeed = 0.4;
        const tail = addMesh(new THREE.ConeGeometry(0.2, 0.34, 4), b, group, [-0.78, -0.77, 0.02]);
        tail.rotation.z = Math.PI;
        const dot1 = addMesh(new THREE.SphereGeometry(0.075, 20, 16), b, group, [-0.76, -0.42, 0.16]);
        const dot2 = addMesh(new THREE.SphereGeometry(0.075, 20, 16), a, group, [-0.5, -0.42, 0.16]);
        const dot3 = addMesh(new THREE.SphereGeometry(0.075, 20, 16), b, group, [-0.24, -0.42, 0.16]);
        dot1.userData.pulseOffset = 0;
        dot2.userData.pulseOffset = 0.4;
        dot3.userData.pulseOffset = 0.8;
        for (let i = 0; i < 4; i++) {
          const sparkle = addMesh(new THREE.OctahedronGeometry(0.055, 0), i % 2 ? a : gold, group, [1.08, 0.42 - i * 0.22, 0.2]);
          sparkle.userData.pulseOffset = i * 0.35;
        }
      } else {
        const box = addMesh(new THREE.BoxGeometry(1.22, 1.05, 1.0), a);
        box.rotation.set(0.12, 0.2, 0.1);
        addMesh(new THREE.BoxGeometry(0.18, 1.08, 1.03), gold);
        addMesh(new THREE.BoxGeometry(1.24, 0.16, 1.03), gold);
        const top = addMesh(new THREE.TorusKnotGeometry(0.28, 0.09, 80, 12), b, group, [0, 0.76, 0]);
        top.scale.set(1.1, 0.8, 0.7);
        const gem = addMesh(new THREE.IcosahedronGeometry(0.28, 1), b, group, [0, 0.25, 0.62]);
        gem.material = new THREE.MeshPhysicalMaterial({ color: d.secondaryColor, metalness: 0.35, roughness: 0.12, transmission: 0.15, emissive: d.secondaryColor, emissiveIntensity: 0.25 });
      }
      const customParts = latest.current.parts || [];
      const customMaterial = (color: string, type: ScenePart['material']) => {
        if (type === 'crystal') return new THREE.MeshPhysicalMaterial({ color, metalness: 0.35, roughness: 0.12, transmission: 0.08, clearcoat: 1, emissive: color, emissiveIntensity: 0.35 });
        if (type === 'glass') return new THREE.MeshPhysicalMaterial({ color, metalness: 0.15, roughness: 0.08, transmission: 0.42, transparent: true, opacity: 0.88, clearcoat: 1 });
        if (type === 'neon') return new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: 1.65, metalness: 0.3, roughness: 0.2 });
        if (type === 'metallic') return new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: 0.2, metalness: 0.92, roughness: 0.16 });
        if (type === 'glossy') return new THREE.MeshPhysicalMaterial({ color, metalness: 0.32, roughness: 0.1, clearcoat: 1 });
        return new THREE.MeshStandardMaterial({ color, metalness: 0.08, roughness: 0.78 });
      };
      for (let index = 0; index < customParts.length; index++) {
        const part = customParts[index];
        if (!part.enabled) continue;
        const node = new THREE.Group(); node.name = part.name;
        node.position.set(part.x, part.y, part.z); node.rotation.z = part.rotation * Math.PI / 180; node.scale.setScalar(part.scale);
        node.userData.partAnimation = part.animation; node.userData.partSeed = index * 1.31;
        node.userData.partBaseX = part.x; node.userData.partBaseY = part.y; node.userData.partBaseZ = part.z;
        node.userData.partBaseScale = part.scale; node.userData.partBaseRotation = part.rotation * Math.PI / 180;
        node.userData.partKeyframes = (part.keyframes || [])
          .filter(frame => Number.isFinite(frame.time))
          .slice()
          .sort((left, right) => left.time - right.time);
        group.add(node);
        const mat = customMaterial(part.color, part.material);
        const addPartMesh = (geometry: THREE.BufferGeometry, position: [number, number, number] = [0, 0, 0], scale: [number, number, number] = [1, 1, 1]) => {
          const mesh = new THREE.Mesh(geometry, mat.clone()); mesh.position.set(...position); mesh.scale.set(...scale); mesh.castShadow = true; mesh.receiveShadow = true; node.add(mesh); return mesh;
        };
        if (part.shape === 'butterfly') {
          const left = addPartMesh(new THREE.SphereGeometry(0.42, 24, 18), [-0.28, 0.04, 0], [0.82, 1.1, 0.32]);
          const right = addPartMesh(new THREE.SphereGeometry(0.42, 24, 18), [0.28, 0.04, 0], [0.82, 1.1, 0.32]);
          left.rotation.z = 0.5; right.rotation.z = -0.5;
          addPartMesh(new THREE.CapsuleGeometry(0.055, 0.3, 4, 8), [0, -0.04, 0.12]);
          const antenna = addPartMesh(new THREE.TorusGeometry(0.12, 0.018, 6, 24, Math.PI), [-0.04, 0.22, 0.1]); antenna.rotation.z = Math.PI / 2;
        } else if (part.shape === 'flower') {
          for (let petal = 0; petal < 8; petal++) { const angle = petal * Math.PI / 4; const mesh = addPartMesh(new THREE.SphereGeometry(0.22, 18, 14), [Math.cos(angle) * 0.27, Math.sin(angle) * 0.27, 0], [0.8, 1.35, 0.38]); mesh.rotation.z = angle; }
          const centre = addPartMesh(new THREE.SphereGeometry(0.16, 20, 16), [0, 0, 0.1]); centre.material = new THREE.MeshStandardMaterial({ color: '#ffe69a', metalness: 0.55, roughness: 0.2, emissive: '#9c6722', emissiveIntensity: 0.3 });
        } else if (part.shape === 'leaf') {
          const leaf = addPartMesh(new THREE.SphereGeometry(0.44, 20, 14), [0, 0, 0], [0.55, 1.35, 0.22]); leaf.rotation.z = -0.6;
          const vein = addPartMesh(new THREE.CylinderGeometry(0.012, 0.012, 0.78, 8), [0, 0, 0.06]); vein.rotation.z = -0.6;
        } else if (part.shape === 'crystal' || part.shape === 'spark') {
          const crystal = addPartMesh(new THREE.OctahedronGeometry(part.shape === 'spark' ? 0.35 : 0.42, 1)); crystal.rotation.set(0.35, 0.2, 0.35); if (part.shape === 'spark') crystal.scale.set(0.8, 0.8, 0.25);
        } else if (part.shape === 'star') {
          const star = new THREE.Shape(); for (let point = 0; point < 10; point++) { const radius = point % 2 === 0 ? 0.48 : 0.22; const angle = -Math.PI / 2 + point * Math.PI / 5; const x = Math.cos(angle) * radius; const y = Math.sin(angle) * radius; if (point === 0) star.moveTo(x, y); else star.lineTo(x, y); } star.closePath();
          addPartMesh(new THREE.ExtrudeGeometry(star, { depth: 0.12, bevelEnabled: true, bevelSegments: 2, steps: 1, bevelSize: 0.035, bevelThickness: 0.03 }));
        } else if (part.shape === 'ring') {
          addPartMesh(new THREE.TorusGeometry(0.42, 0.07, 12, 72)); const gem = addPartMesh(new THREE.OctahedronGeometry(0.13, 1), [0.42, 0, 0.05]); gem.material = customMaterial(part.color, 'crystal');
        } else if (part.shape === 'orb') {
          addPartMesh(new THREE.SphereGeometry(0.38, 32, 24)); addPartMesh(new THREE.TorusGeometry(0.48, 0.025, 8, 64)).rotation.x = Math.PI / 2.8;
        } else if (part.shape === 'flame') {
          const flame = addPartMesh(new THREE.ConeGeometry(0.34, 0.92, 24), [0, 0, 0], [0.75, 1, 0.65]); flame.rotation.z = 0.08;
          const core = addPartMesh(new THREE.ConeGeometry(0.14, 0.48, 18), [0, -0.08, 0.12], [0.8, 0.9, 0.8]); core.material = new THREE.MeshBasicMaterial({ color: '#ffe5a0' });
        } else if (part.shape === 'heart') {
          const heart = new THREE.Shape(); heart.moveTo(0, -0.34); heart.bezierCurveTo(-0.55, 0.02, -0.48, 0.46, -0.2, 0.45); heart.bezierCurveTo(-0.02, 0.45, 0, 0.29, 0, 0.25); heart.bezierCurveTo(0, 0.29, 0.02, 0.45, 0.2, 0.45); heart.bezierCurveTo(0.48, 0.46, 0.55, 0.02, 0, -0.34); heart.closePath();
          addPartMesh(new THREE.ExtrudeGeometry(heart, { depth: 0.18, bevelEnabled: true, bevelSegments: 3, steps: 1, bevelSize: 0.04, bevelThickness: 0.04 }));
        } else if (part.shape === 'rocket') {
          const body = addPartMesh(new THREE.CylinderGeometry(0.19, 0.22, 0.72, 24)); body.rotation.z = -0.14;
          const nose = addPartMesh(new THREE.ConeGeometry(0.2, 0.32, 24), [0, 0.5, 0]); nose.rotation.z = -0.14;
          addPartMesh(new THREE.ConeGeometry(0.18, 0.32, 18), [0, -0.47, 0], [0.7, 1.1, 0.7]);
        } else if (part.shape === 'car-body') {
          addPartMesh(new RoundedBoxGeometry(2.15, 0.42, 0.72, 5, 0.13), [0, 0, 0]);
          addPartMesh(new RoundedBoxGeometry(0.92, 0.38, 0.58, 5, 0.12), [-0.08, 0.29, 0], [1, 0.82, 1]);
          addPartMesh(new RoundedBoxGeometry(0.52, 0.12, 0.76, 4, 0.04), [0.73, -0.1, 0]);
        } else if (part.shape === 'car-wheel') {
          addPartMesh(new THREE.TorusGeometry(0.27, 0.095, 14, 36), [0, 0, 0]);
          addPartMesh(new THREE.CylinderGeometry(0.17, 0.17, 0.12, 24), [0, 0, 0]).rotation.x = Math.PI / 2;
          addPartMesh(new THREE.TorusGeometry(0.1, 0.025, 8, 24), [0, 0, 0.08]);
        } else if (part.shape === 'car-glass') {
          addPartMesh(new RoundedBoxGeometry(0.78, 0.25, 0.48, 4, 0.07), [0, 0, 0]);
        } else if (part.shape === 'car-light') {
          addPartMesh(new RoundedBoxGeometry(0.18, 0.09, 0.16, 3, 0.035), [0, 0, 0]);
          addPartMesh(new THREE.SphereGeometry(0.065, 16, 12), [0.025, 0, 0.09]);
        } else if (part.shape === 'car-spoiler') {
          addPartMesh(new THREE.BoxGeometry(0.12, 0.25, 0.12), [0, -0.04, 0]);
          addPartMesh(new RoundedBoxGeometry(0.58, 0.09, 0.28, 3, 0.025), [0, 0.1, 0]);
        } else if (part.shape === 'car-exhaust') {
          addPartMesh(new THREE.CylinderGeometry(0.075, 0.1, 0.24, 18), [0, 0, 0]).rotation.z = Math.PI / 2;
          const glow = addPartMesh(new THREE.SphereGeometry(0.11, 16, 12), [-0.13, 0, 0]); glow.material = new THREE.MeshBasicMaterial({ color: part.color });
        }
      }
      const particlesMat = new THREE.PointsMaterial({ color: d.primaryColor, size: k === 'frame' ? 0.045 : 0.055, transparent: true, opacity: 0.95, depthWrite: false });
      particles.material = particlesMat;
    };
    rebuild();
    const resize = () => {
      const width = Math.max(1, element.clientWidth);
      const height = Math.max(1, element.clientHeight);
      renderer.setSize(width, height, false);
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
    };
    const observer = new ResizeObserver(resize);
    observer.observe(element);
    resize();
    const start = performance.now();
    const animate = (now: number) => {
      const t = (now - start) / 1000;
      const { kind: k, design: d } = latest.current;
      const motion = d.motion || '';
      const activeDuration = Math.max(0.1, Number(d.durationSeconds) || 5);
      const frameTime = latest.current.timelineTime !== undefined
        ? Math.max(0, Math.min(activeDuration, latest.current.timelineTime))
        : d.loop ? t % activeDuration : Math.min(t, activeDuration);
      // In editor mode, the playhead drives the scene motion and the part keyframes.
      const animationTime = latest.current.timelineTime !== undefined ? frameTime : t;
      const oneShot = !d.loop && k !== 'frame' && k !== 'bubble';
      const entrance = oneShot ? Math.min(1, animationTime / Math.max(0.8, d.durationSeconds * 0.24)) : 1;
      const easedEntrance = 1 - Math.pow(1 - entrance, 3);
      group.rotation.y = k === 'frame' ? Math.sin(animationTime * 0.4) * 0.035 : k === 'vehicle' ? Math.sin(animationTime * 1.6) * 0.08 : motion === 'orbit' ? animationTime * 0.32 : animationTime * 0.12;
      group.rotation.x = k === 'entry' ? Math.sin(animationTime * 1.2) * 0.08 : Math.sin(animationTime * 0.7) * 0.035;
      group.position.x = k === 'vehicle' ? Math.sin(animationTime * 1.05) * 0.16 : k === 'entry' ? Math.sin(animationTime * 0.5) * 0.025 : 0;
      group.position.y = k === 'vehicle' ? Math.sin(animationTime * 1.8) * 0.08 : Math.sin(animationTime * 1.4) * 0.08;
      if (k === 'vehicle') group.position.x += (1 - easedEntrance) * -2.2;
      if (k === 'entry') group.scale.setScalar((0.84 + easedEntrance * 0.16) * (1 + Math.sin(animationTime * 2.2) * 0.018));
      else if (k === 'gift' && motion === 'burst') group.scale.setScalar((0.25 + easedEntrance * 0.75) * (1 + Math.sin(animationTime * 3) * 0.025));
      else group.scale.setScalar(1 + Math.sin(animationTime * 2) * 0.025);
      group.children.forEach(child => {
        const data = child.userData as {
          spinSpeed?: number; orbitAngle?: number; orbitRadius?: number; orbitSpeed?: number;
          wheel?: boolean; pulseOffset?: number; partAnimation?: string; partSeed?: number;
          partBaseX?: number; partBaseY?: number; partBaseZ?: number;
          partBaseScale?: number; partBaseRotation?: number;
          partKeyframes?: TransformKeyframe[];
        };
        if (data.partAnimation) {
          const seed = data.partSeed || 0;
          let baseX = data.partBaseX || 0;
          let baseY = data.partBaseY || 0;
          let baseZ = data.partBaseZ || 0;
          let baseScale = data.partBaseScale || 1;
          let baseRotation = data.partBaseRotation || 0;
          const frames = data.partKeyframes || [];
          if (frames.length > 0) {
            let left = frames[0];
            let right = frames[frames.length - 1];
            if (frameTime <= frames[0].time) {
              left = right = frames[0];
            } else if (frameTime >= frames[frames.length - 1].time) {
              left = right = frames[frames.length - 1];
            } else {
              for (let frameIndex = 0; frameIndex < frames.length - 1; frameIndex++) {
                if (frameTime >= frames[frameIndex].time && frameTime <= frames[frameIndex + 1].time) {
                  left = frames[frameIndex];
                  right = frames[frameIndex + 1];
                  break;
                }
              }
            }
            const span = right.time - left.time;
            const ratio = span > 0 ? Math.max(0, Math.min(1, (frameTime - left.time) / span)) : 0;
            const mix = (from: number, to: number) => from + (to - from) * ratio;
            baseX = mix(left.x, right.x);
            baseY = mix(left.y, right.y);
            baseZ = mix(left.z, right.z);
            baseScale = mix(left.scale, right.scale);
            baseRotation = mix(left.rotation, right.rotation) * Math.PI / 180;
          }
          const wave = Math.sin(animationTime * (data.partAnimation === 'flicker' ? 9 : data.partAnimation === 'wing-flap' ? 12 : 2.6) + seed);
          child.position.set(baseX, baseY, baseZ); child.scale.setScalar(baseScale); child.rotation.z = baseRotation;
          if (data.partAnimation === 'float' || data.partAnimation === 'bloom') child.position.y = baseY + wave * (data.partAnimation === 'bloom' ? 0.035 : 0.11);
          if (data.partAnimation === 'orbit') { child.position.x = baseX + Math.cos(animationTime * 0.9 + seed) * 0.12; child.position.y = baseY + Math.sin(animationTime * 0.9 + seed) * 0.12; }
          if (data.partAnimation === 'flyby') child.position.x = baseX + Math.sin(animationTime * 0.75 + seed) * 0.28;
          if (data.partAnimation === 'spin' || data.partAnimation === 'shine') child.rotation.y += data.partAnimation === 'shine' ? 0.015 : 0.03;
          if (data.partAnimation === 'wing-flap') child.rotation.y = wave * 0.42;
          if (data.partAnimation === 'flicker') child.scale.setScalar(baseScale * (0.86 + Math.abs(wave) * 0.22));
          if (data.partAnimation === 'pulse' || data.partAnimation === 'twinkle' || data.partAnimation === 'bloom' || data.partAnimation === 'shine') child.scale.setScalar(baseScale * (0.9 + Math.abs(wave) * 0.18));
        }
        if (typeof data.spinSpeed === 'number') child.rotation.z += data.spinSpeed / 60;
        if (typeof data.orbitAngle === 'number' && typeof data.orbitRadius === 'number' && typeof data.orbitSpeed === 'number') {
          const angle = data.orbitAngle + animationTime * data.orbitSpeed;
          child.position.x = Math.cos(angle) * data.orbitRadius;
          child.position.y = Math.sin(angle) * data.orbitRadius;
          child.rotation.x += 0.018;
          child.rotation.y += 0.025;
        }
        if (data.wheel) child.rotation.y += 0.045;
        if (typeof data.pulseOffset === 'number') {
          const pulse = 0.8 + (Math.sin(animationTime * 4 + data.pulseOffset * 6) + 1) * 0.22;
          child.scale.setScalar(pulse);
        }
      });
      particles.rotation.y = animationTime * 0.025;
      particles.rotation.x = Math.sin(animationTime * 0.12) * 0.08;
      if (modelRoot) { modelRoot.rotation.y = animationTime * 0.22; modelRoot.position.y = Math.sin(animationTime * 1.3) * 0.04; }
      mixer?.update(1 / 60);
      renderer.render(scene, camera);
      runtime.current!.raf = requestAnimationFrame(animate);
    };
    runtime.current = { renderer, scene, camera, group, particles, raf: requestAnimationFrame(animate) };
    const handleContext = () => { /* browser may restore the WebGL context automatically */ };
    renderer.domElement.addEventListener('webglcontextrestored', handleContext);
    return () => {
      loadActive = false;
      observer.disconnect();
      cancelAnimationFrame(runtime.current?.raf || 0);
      renderer.domElement.removeEventListener('webglcontextrestored', handleContext);
      renderer.dispose();
      scene.traverse(object => {
        if (object instanceof THREE.Mesh || object instanceof THREE.Points) {
          object.geometry.dispose();
          const mats = Array.isArray(object.material) ? object.material : [object.material];
          mats.forEach(m => m.dispose());
        }
      });
      if (element.contains(renderer.domElement)) element.removeChild(renderer.domElement);
      runtime.current = null;
    };
  }, [kind, design.title, design.primaryColor, design.secondaryColor, design.particles, modelUrl, partsKey]);

  return <div ref={host} aria-label={'Interactive 3D preview of ' + design.title} style={{ width: '100%', height: '100%', minHeight: 320, cursor: 'grab' }} />;
});

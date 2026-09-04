/**
 * Three.js 3D viewer.
 *
 * - Loads the GLB model and wires the "TD_Fabric" material to the composited
 *   atlas texture; other materials (collar etc.) are tinted to match.
 * - Orbit / zoom / pan via OrbitControls, animated view presets.
 * - Click-to-select: a raycast resolves the UV under the pointer and finds
 *   the print area containing it.
 */
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const TARGET = new THREE.Vector3(0, 0.36, 0);

export class Viewer {
  constructor(container, { onAreaClick, onReady, i18n }) {
    this.container = container;
    this.onAreaClick = onAreaClick || null;
    this.onReady = onReady || null;
    this.i18n = i18n || {};
    this.printAreas = [];
    this.areas = [];
    this.fabricMaterial = null;
    this.trimMaterials = [];
    this.camera = null;
    this.controls = null;
    this.renderer = null;
    this.scene = null;
    this.animation = null;
    this.downPos = null;
    this.clock = new THREE.Clock();

    this._init();
  }

  static webglAvailable() {
    try {
      const canvas = document.createElement('canvas');
      return !!(window.WebGLRenderingContext
        && (canvas.getContext('webgl2') || canvas.getContext('webgl')));
    } catch {
      return false;
    }
  }

  _init() {
    if (!Viewer.webglAvailable()) return;

    const width = this.container.clientWidth || 480;
    const height = this.container.clientHeight || 600;

    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setSize(width, height);
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.domElement.classList.add('td-stage__webgl');
    this.container.appendChild(this.renderer.domElement);

    this.scene = new THREE.Scene();

    this.camera = new THREE.PerspectiveCamera(38, width / height, 0.05, 20);
    this.camera.position.set(0, 0.62, 1.55);

    const pmrem = new THREE.PMREMGenerator(this.renderer);
    this.scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;

    const key = new THREE.DirectionalLight(0xffffff, 2.0);
    key.position.set(1.2, 1.8, 1.6);
    this.scene.add(key);
    const rim = new THREE.DirectionalLight(0xdde7ff, 0.9);
    rim.position.set(-1.4, 1.0, -1.2);
    this.scene.add(rim);

    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.target.copy(TARGET);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.08;
    this.controls.minDistance = 0.55;
    this.controls.maxDistance = 2.8;
    this.controls.enablePan = true;
    this.controls.update();

    // Resize handling.
    if (typeof ResizeObserver !== 'undefined') {
      this._ro = new ResizeObserver(() => this._resize());
      this._ro.observe(this.container);
    } else {
      window.addEventListener('resize', () => this._resize());
    }

    // Click-to-select (distinguish from orbit drags).
    this.renderer.domElement.addEventListener('pointerdown', (e) => {
      this.downPos = { x: e.clientX, y: e.clientY };
    });
    this.renderer.domElement.addEventListener('pointerup', (e) => {
      if (!this.downPos) return;
      const moved = Math.hypot(e.clientX - this.downPos.x, e.clientY - this.downPos.y);
      this.downPos = null;
      if (moved > 6) return;
      this._handleClick(e);
    });

    this._loop();
  }

  _resize() {
    if (!this.renderer) return;
    const w = this.container.clientWidth;
    const h = this.container.clientHeight;
    if (!w || !h) return;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
  }

  _loop() {
    const tick = () => {
      this.animation = requestAnimationFrame(tick);
      if (this._camAnim) this._stepCamAnim();
      this.controls.update();
      this.renderer.render(this.scene, this.camera);
    };
    tick();
  }

  _stepCamAnim() {
    const a = this._camAnim;
    const t = Math.min(1, (performance.now() - a.t0) / a.duration);
    const e = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; // easeInOut
    this.camera.position.lerpVectors(a.from, a.to, e);
    if (t >= 1) this._camAnim = null;
  }

  /**
   * Load a GLB and wire materials.
   */
  loadModel(url, compositor) {
    if (!this.renderer) return Promise.reject(new Error('no-webgl'));
    return new Promise((resolve, reject) => {
      const loader = new GLTFLoader();
      loader.load(
        url,
        (gltf) => {
          if (this.modelRoot) {
            this.scene.remove(this.modelRoot);
          }
          this.modelRoot = gltf.scene;
          this.trimMaterials = [];

          this.modelRoot.traverse((obj) => {
            if (!obj.isMesh) return;
            const name = (obj.material && obj.material.name) || '';
            if (name === 'TD_Fabric') {
              this.fabricMaterial = new THREE.MeshStandardMaterial({
                map: compositor.texture,
                roughness: 0.92,
                metalness: 0.0,
                side: THREE.DoubleSide,
              });
              obj.material = this.fabricMaterial;
            } else {
              const mat = new THREE.MeshStandardMaterial({
                color: 0xdadada,
                roughness: 0.85,
                metalness: 0.0,
                side: THREE.DoubleSide,
              });
              obj.material = mat;
              this.trimMaterials.push(mat);
            }
          });

          this.modelRoot.scale.setScalar(1.0);
          this.scene.add(this.modelRoot);
          if (this.onReady) this.onReady();
          resolve(gltf);
        },
        undefined,
        (err) => reject(err)
      );
    });
  }

  /**
   * Match trim material to the garment color (slightly shaded).
   */
  applyColor(hex) {
    const c = new THREE.Color(hex);
    c.multiplyScalar(0.88);
    for (const mat of this.trimMaterials) mat.color.copy(c);
  }

  setPrintAreas(areas) {
    this.printAreas = areas || [];
  }

  /** View preset buttons: front / back / left / right / reset. */
  setView(name) {
    const fallback = {
      front: { azimuth: 0, polar: 78, distance: 1.55 },
      back: { azimuth: 180, polar: 78, distance: 1.55 },
      left: { azimuth: -80, polar: 72, distance: 1.5 },
      right: { azimuth: 80, polar: 72, distance: 1.5 },
      reset: { azimuth: 0, polar: 72, distance: 1.6 },
    };
    const typeMap = { front: 'front', back: 'back', left: 'left_sleeve', right: 'right_sleeve' };
    let preset = fallback[name] || fallback.reset;
    if (typeMap[name]) {
      const area = this.printAreas.find((a) => a.type === typeMap[name] && a.camera);
      if (area && area.camera) preset = { ...preset, ...area.camera };
    }
    this.setCameraPreset(preset);
  }

  /** Animate the camera to a spherical preset around the target. */
  setCameraPreset({ azimuth = 0, polar = 75, distance = 1.55 }) {
    if (!this.camera) return;
    const az = (azimuth * Math.PI) / 180;
    const po = (polar * Math.PI) / 180;
    const to = new THREE.Vector3(
      TARGET.x + distance * Math.sin(po) * Math.sin(az),
      TARGET.y + distance * Math.cos(po),
      TARGET.z + distance * Math.sin(po) * Math.cos(az)
    );
    this._camAnim = {
      from: this.camera.position.clone(),
      to,
      t0: performance.now(),
      duration: 600,
    };
  }

  _handleClick(event) {
    if (!this.modelRoot || !this.printAreas.length) return;
    const rect = this.renderer.domElement.getBoundingClientRect();
    const ndc = new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1
    );
    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(ndc, this.camera);

    const meshes = [];
    this.modelRoot.traverse((o) => { if (o.isMesh) meshes.push(o); });
    const hits = raycaster.intersectObjects(meshes, false);
    const hit = hits.find((h) => h.uv);
    if (!hit) return;

    const { x: u, y: v } = hit.uv;
    const area = this.printAreas.find((a) => {
      if (!a.uv_rect) return false;
      const [u0, v0, u1, v1] = a.uv_rect;
      return u >= u0 && u <= u1 && v >= v0 && v <= v1;
    });
    if (area && this.onAreaClick) this.onAreaClick(area.id);
  }

  /** Snapshot of the current render (PNG data URL) for design previews. */
  snapshot() {
    if (!this.renderer) return '';
    try {
      this.renderer.render(this.scene, this.camera);
      return this.renderer.domElement.toDataURL('image/png');
    } catch {
      return '';
    }
  }

  dispose() {
    if (this.animation) cancelAnimationFrame(this.animation);
    if (this._ro) this._ro.disconnect();
    if (this.controls) this.controls.dispose();
    if (this.renderer) {
      this.renderer.dispose();
      this.renderer.domElement.remove();
    }
  }
}

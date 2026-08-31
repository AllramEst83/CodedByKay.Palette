import { logger } from './logger.js';
import { showToast } from './dom-utils.js';

const STORAGE_KEY = 'palette-app-state-v1';
const SIZE_SOFT_CAP = 4.5 * 1024 * 1024;
const PERSIST_IMAGE_MAX_DIM = 800;

let debounceTimer = null;
let warnedOnce = false;

export function scheduleSave(getSnapshot) {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => saveNow(getSnapshot()), 400);
}

function downscaleForStorage(img, maxDim) {
  if (!img) return null;
  const w = img.naturalWidth || img.width;
  const h = img.naturalHeight || img.height;
  if (!w || !h) return null;
  if (Math.max(w, h) <= maxDim) {
    return img.src && img.src.startsWith('data:') ? img.src : null;
  }
  const scale = maxDim / Math.max(w, h);
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(w * scale);
  canvas.height = Math.round(h * scale);
  try {
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL('image/jpeg', 0.82);
  } catch (err) {
    logger.warn('storage', 'Could not downscale image for storage', err);
    return null;
  }
}

export function buildMoodBoardImagePayload(images) {
  return images.map(item => ({
    id: item.id, name: item.name,
    x: item.x, y: item.y, w: item.w, h: item.h,
    rotation: item.rotation, zIndex: item.zIndex, order: item.order,
    src: downscaleForStorage(item.img, PERSIST_IMAGE_MAX_DIM),
  }));
}

function saveNow(snapshot) {
  try {
    let payload = JSON.stringify(snapshot);
    if (payload.length > SIZE_SOFT_CAP) {
      const trimmed = {
        ...snapshot,
        moodboard: { ...snapshot.moodboard, images: snapshot.moodboard.images.map(i => ({ ...i, src: null })) },
      };
      payload = JSON.stringify(trimmed);
      if (!warnedOnce) {
        warnedOnce = true;
        showToast('Board images too large to save — layout saved, re-add images next visit', false);
      }
    }
    localStorage.setItem(STORAGE_KEY, payload);
  } catch (err) {
    logger.warn('storage', 'Persist failed, retrying with reduced payload', err);
    try {
      const minimal = { ...snapshot, moodboard: { ...snapshot.moodboard, images: [], stickyNotes: [] } };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(minimal));
    } catch (err2) {
      logger.error('storage', 'Could not persist app state', err2);
    }
  }
}

export function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed || parsed.version !== 1) return null;
    return parsed;
  } catch (err) {
    logger.error('storage', 'Could not read persisted state, clearing', err);
    try { localStorage.removeItem(STORAGE_KEY); } catch (_e) { /* ignore */ }
    return null;
  }
}

export function clearState() {
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch (err) {
    logger.warn('storage', 'Could not clear persisted state', err);
  }
}

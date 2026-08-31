import { showToast, reportError } from './dom-utils.js';
import {
  getMoodBoardState, addMoodBoardImage, removeMoodBoardImage as removeImageState,
  moveMoodBoardImage as moveImageState, clearMoodBoard as clearBoardState,
  setMbMode, setMbColumns as setColumnsState, setMbGutter as setGutterState,
  setMbPadding as setPaddingState, setMbRadius as setRadiusState,
  setMbRatio as setRatioState, setMbBg as setBgState, addStickyNote,
  removeStickyNote as removeStickyNoteState, selectMoodBoardItem, getSelectedImage,
  addSwatchGroup,
} from './moodboard-state.js';
import {
  updateMoodBoardUI, updateMbColumnButtons, updateMbRatioButtons,
  updateMbModeButtons, updateExtractButtonState,
} from './moodboard-ui.js';
import { renderMoodBoardGridCanvas } from './moodboard-grid.js';
import { renderDynamicCanvas, initDynamicCanvas, editSelectedNote } from './moodboard-dynamic.js';
import { $ } from './dom-utils.js';

let persistCallback = null;
export function onMoodBoardChange(callback) {
  persistCallback = callback;
}

function notifyChange() {
  if (persistCallback) persistCallback();
}

export function renderMoodBoard() {
  const state = getMoodBoardState();
  const gridCanvasWrap = $('#mb-composite-canvas');
  const dynamicWrap = $('#mb-dynamic-canvas');
  if (gridCanvasWrap) gridCanvasWrap.classList.toggle('hidden', state.mode !== 'grid');
  if (dynamicWrap) dynamicWrap.classList.toggle('hidden', state.mode !== 'dynamic');

  if (state.mode === 'grid') {
    renderMoodBoardGridCanvas();
  } else {
    renderDynamicCanvas();
  }
}

export function initMoodBoard() {
  initDynamicCanvas();
}

export function addImagesToMoodBoard(fileList, onLoadingChange) {
  if (!fileList || fileList.length === 0) return;
  const files = Array.from(fileList).filter(f => f.type && f.type.startsWith('image/'));
  if (!files.length) {
    showToast('Please provide valid image files', false);
    return;
  }

  if (onLoadingChange) onLoadingChange(true);
  let loadedCount = 0;
  files.forEach(file => {
    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        addMoodBoardImage({ img, src: e.target.result, name: file.name });
        loadedCount++;
        if (loadedCount >= files.length) {
          updateMoodBoardUI();
          renderMoodBoard();
          notifyChange();
          if (onLoadingChange) onLoadingChange(false);
          showToast(`Added ${loadedCount} image${loadedCount > 1 ? 's' : ''} to board!`);
        }
      };
      img.onerror = () => {
        loadedCount++;
        if (loadedCount >= files.length && onLoadingChange) onLoadingChange(false);
        reportError('moodboard', `Could not load ${file.name}`, new Error('Image decode failed'));
      };
      img.src = e.target.result;
    };
    reader.onerror = () => {
      loadedCount++;
      if (loadedCount >= files.length && onLoadingChange) onLoadingChange(false);
      reportError('moodboard', `Could not read ${file.name}`, reader.error);
    };
    reader.readAsDataURL(file);
  });
}

export function removeMoodBoardImageAction(id) {
  removeImageState(id);
  updateMoodBoardUI();
  updateExtractButtonState(!!getSelectedImage());
  renderMoodBoard();
  notifyChange();
  showToast('Image removed');
}

export function moveMoodBoardImageAction(index, direction) {
  moveImageState(index, direction);
  updateMoodBoardUI();
  renderMoodBoard();
  notifyChange();
}

export function clearMoodBoardAction() {
  const state = getMoodBoardState();
  if (!state.images.length && !state.stickyNotes.length && !state.swatchGroups.length) return;
  clearBoardState();
  updateMoodBoardUI();
  updateExtractButtonState(false);
  renderMoodBoard();
  notifyChange();
  showToast('Mood board cleared');
}

export function selectMoodBoardImageAction(id) {
  selectMoodBoardItem(id);
  updateMoodBoardUI();
  updateExtractButtonState(!!getSelectedImage());
  renderMoodBoard();
}

export function setMbModeAction(mode) {
  setMbMode(mode);
  updateMbModeButtons(mode);
  renderMoodBoard();
  notifyChange();
}

export function setMbColumnsAction(cols) {
  setColumnsState(cols);
  updateMbColumnButtons(cols);
  renderMoodBoard();
  notifyChange();
}

export function setMbGutterAction(px) {
  setGutterState(px);
  renderMoodBoard();
  notifyChange();
}

export function setMbPaddingAction(px) {
  setPaddingState(px);
  renderMoodBoard();
  notifyChange();
}

export function setMbRadiusAction(px) {
  setRadiusState(px);
  renderMoodBoard();
  notifyChange();
}

export function setMbRatioAction(ratio) {
  setRatioState(ratio);
  updateMbRatioButtons(ratio);
  renderMoodBoard();
  notifyChange();
}

export function setMbBgAction(color) {
  setBgState(color);
  renderMoodBoard();
  notifyChange();
}

export function addStickyNoteAction() {
  const note = addStickyNote();
  selectMoodBoardItem(note.id);
  renderMoodBoard();
  notifyChange();
  editSelectedNote();
}

export function removeStickyNoteAction(id) {
  removeStickyNoteState(id);
  renderMoodBoard();
  notifyChange();
}

export function addSwatchGroupAction({ colors, sourceName, x, y, w, h }) {
  const group = addSwatchGroup({ colors, sourceName, x, y, w, h });
  selectMoodBoardItem(group.id);
  renderMoodBoard();
  notifyChange();
  return group;
}

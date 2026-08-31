import { logger } from './logger.js';
import { $, $$, refreshIcons, showToast } from './dom-utils.js';
import { switchTab, getCurrentTab } from './nav.js';
import {
  processPaletteImageFile, setPaletteSort, setPaletteCount,
  setShowHexText, setShowRgbText, applyPaletteTheme, applyPaletteHarmony,
  resetPaletteToSource, getPaletteSnapshot, applyPaletteSettings, syncPaletteControlsUI,
  renderPaletteCompositeCanvas,
} from './palette.js';
import { createSampleImage, loadSampleMoodBoard } from './sample-data.js';
import {
  addImagesToMoodBoard, removeMoodBoardImageAction, moveBoardItemAction,
  clearMoodBoardAction, selectMoodBoardImageAction, setMbModeAction,
  setMbColumnsAction, setMbGutterAction, setMbPaddingAction, setMbRadiusAction,
  setMbRatioAction, setMbBgAction, addStickyNoteAction, removeSwatchGroupAction,
  renderMoodBoard, initMoodBoard, onMoodBoardChange,
} from './moodboard.js';
import {
  getMoodBoardState, applyMoodBoardSettings, hydrateMoodBoardImage,
  hydrateStickyNote, hydrateSwatchGroup, getSelectedImage,
} from './moodboard-state.js';
import { updateMoodBoardUI, updateMbColumnButtons, updateMbRatioButtons, updateMbModeButtons, updateMbBgButtons, updateExtractButtonState } from './moodboard-ui.js';
import { extractSelectedImagePalette } from './moodboard-extract.js';
import { downloadCanvasById, downloadDynamicBoardAsPNG } from './download.js';
import { loadState, scheduleSave, buildMoodBoardImagePayload } from './storage.js';

function setLoading(id, isLoading) {
  const el = $(`#${id}`);
  if (el) el.classList.toggle('hidden', !isLoading);
}

function persistState() {
  const mbState = getMoodBoardState();
  scheduleSave(() => ({
    version: 1,
    palette: getPaletteSnapshot(),
    moodboard: {
      mode: mbState.mode, columns: mbState.columns, gutter: mbState.gutter,
      padding: mbState.padding, radius: mbState.radius, ratio: mbState.ratio, bgColor: mbState.bgColor,
      images: buildMoodBoardImagePayload(mbState.images),
      stickyNotes: mbState.stickyNotes.map(n => ({
        id: n.id, text: n.text, x: n.x, y: n.y, w: n.w, h: n.h,
        rotation: n.rotation, zIndex: n.zIndex, color: n.color, textColor: n.textColor,
      })),
      swatchGroups: mbState.swatchGroups.map(g => ({
        id: g.id, colors: g.colors, sourceName: g.sourceName,
        x: g.x, y: g.y, w: g.w, h: g.h, rotation: g.rotation, zIndex: g.zIndex, order: g.order,
      })),
    },
  }));
}

async function hydrateMoodBoardFromStorage(mb) {
  if (!mb) return;
  applyMoodBoardSettings({
    mode: mb.mode || 'grid',
    columns: mb.columns ?? 3, gutter: mb.gutter ?? 16, padding: mb.padding ?? 24,
    radius: mb.radius ?? 12, ratio: mb.ratio || '1:1', bgColor: mb.bgColor || '#0f172a',
  });

  const loads = (mb.images || []).filter(item => item.src).map(item => new Promise(resolve => {
    const img = new Image();
    img.onload = () => {
      hydrateMoodBoardImage({ ...item, img });
      resolve();
    };
    img.onerror = () => {
      logger.warn('main', `Could not restore image ${item.name}`);
      resolve();
    };
    img.src = item.src;
  }));

  await Promise.all(loads);
  (mb.stickyNotes || []).forEach(note => hydrateStickyNote(note));
  (mb.swatchGroups || []).forEach(group => hydrateSwatchGroup(group));
}

function wireTabs() {
  $('#tab-palette')?.addEventListener('click', () => switchTab('palette'));
  $('#tab-moodboard')?.addEventListener('click', () => switchTab('moodboard'));
}

function wirePaletteControls() {
  const paletteInput = $('#palette-file-input');
  const paletteDropzone = $('#palette-dropzone');
  const paletteCountSlider = $('#palette-count');
  const paletteCountLabel = $('#palette-count-label');

  paletteInput?.addEventListener('change', (e) => {
    if (e.target.files && e.target.files[0]) {
      processPaletteImageFile(e.target.files[0], (loading) => setLoading('palette-loading', loading));
    }
  });

  paletteCountSlider?.addEventListener('input', (e) => {
    const count = parseInt(e.target.value, 10);
    if (paletteCountLabel) paletteCountLabel.textContent = `${count} Colors`;
    setPaletteCount(count);
    persistState();
  });

  $('#show-hex-text')?.addEventListener('change', (e) => {
    setShowHexText(e.target.checked);
    persistState();
  });
  $('#show-rgb-text')?.addEventListener('change', (e) => {
    setShowRgbText(e.target.checked);
    persistState();
  });

  $$('#sort-prominence, #sort-luminance, #sort-hue').forEach(btn => {
    btn.addEventListener('click', () => {
      const mode = btn.id.replace('sort-', '');
      setPaletteSort(mode);
      persistState();
    });
  });

  $$('#theme-button-group button[data-theme]').forEach(btn => {
    btn.addEventListener('click', () => {
      applyPaletteTheme(btn.dataset.theme);
      persistState();
    });
  });

  $$('#harmony-button-group button[data-harmony]').forEach(btn => {
    btn.addEventListener('click', () => {
      applyPaletteHarmony(btn.dataset.harmony);
      persistState();
    });
  });

  $('#btn-sample-palette')?.addEventListener('click', () => createSampleImage('sunset'));
  $('#btn-download-palette')?.addEventListener('click', () => {
    downloadCanvasById('palette-composite-canvas', 'palette-composite.png');
  });

  ['dragenter', 'dragover'].forEach(name => {
    paletteDropzone?.addEventListener(name, (e) => {
      e.preventDefault();
      paletteDropzone.classList.add('dropzone-active');
    });
  });
  ['dragleave', 'drop'].forEach(name => {
    paletteDropzone?.addEventListener(name, (e) => {
      e.preventDefault();
      paletteDropzone.classList.remove('dropzone-active');
    });
  });
  paletteDropzone?.addEventListener('drop', (e) => {
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      processPaletteImageFile(e.dataTransfer.files[0], (loading) => setLoading('palette-loading', loading));
    }
  });
}

function wireMoodBoardControls() {
  const mbInput = $('#mb-file-input');
  const mbDropzone = $('#mb-dropzone');

  mbInput?.addEventListener('change', (e) => {
    if (e.target.files && e.target.files.length > 0) {
      addImagesToMoodBoard(e.target.files, (loading) => setLoading('mb-loading', loading));
    }
  });

  ['dragenter', 'dragover'].forEach(name => {
    mbDropzone?.addEventListener(name, (e) => {
      e.preventDefault();
      mbDropzone.classList.add('dropzone-active');
    });
  });
  ['dragleave', 'drop'].forEach(name => {
    mbDropzone?.addEventListener(name, (e) => {
      e.preventDefault();
      mbDropzone.classList.remove('dropzone-active');
    });
  });
  mbDropzone?.addEventListener('drop', (e) => {
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      addImagesToMoodBoard(e.dataTransfer.files, (loading) => setLoading('mb-loading', loading));
    }
  });

  $('#mb-mode-grid')?.addEventListener('click', () => setMbModeAction('grid'));
  $('#mb-mode-dynamic')?.addEventListener('click', () => setMbModeAction('dynamic'));

  $$('.mb-col-btn').forEach(btn => {
    btn.addEventListener('click', () => setMbColumnsAction(parseInt(btn.dataset.cols, 10)));
  });
  $$('.mb-ratio-btn').forEach(btn => {
    btn.addEventListener('click', () => setMbRatioAction(btn.dataset.ratio));
  });

  const mbGutterSlider = $('#mb-gutter');
  mbGutterSlider?.addEventListener('input', (e) => {
    const px = parseInt(e.target.value, 10);
    const label = $('#mb-gutter-label');
    if (label) label.textContent = `${px} px`;
    setMbGutterAction(px);
  });

  const mbPaddingSlider = $('#mb-padding');
  mbPaddingSlider?.addEventListener('input', (e) => {
    const px = parseInt(e.target.value, 10);
    const label = $('#mb-padding-label');
    if (label) label.textContent = `${px} px`;
    setMbPaddingAction(px);
  });

  const mbRadiusSlider = $('#mb-radius');
  mbRadiusSlider?.addEventListener('input', (e) => {
    const px = parseInt(e.target.value, 10);
    const label = $('#mb-radius-label');
    if (label) label.textContent = `${px} px`;
    setMbRadiusAction(px);
  });

  $$('[data-bg]').forEach(btn => {
    btn.addEventListener('click', () => {
      setMbBgAction(btn.dataset.bg);
      const custom = $('#mb-custom-bg');
      if (custom) custom.value = btn.dataset.bg;
    });
  });
  $('#mb-custom-bg')?.addEventListener('input', (e) => setMbBgAction(e.target.value));

  $('#btn-load-sample-board')?.addEventListener('click', loadSampleMoodBoard);
  $('#btn-download-moodboard')?.addEventListener('click', () => {
    const state = getMoodBoardState();
    if (state.mode === 'dynamic') {
      downloadDynamicBoardAsPNG('mood-board.png');
    } else {
      downloadCanvasById('mb-composite-canvas', 'mood-board.png');
    }
  });

  $('#btn-add-sticky')?.addEventListener('click', addStickyNoteAction);
  $('#btn-extract-selected')?.addEventListener('click', () => extractSelectedImagePalette(5));

  $('#btn-clear-board')?.addEventListener('click', clearMoodBoardAction);

  $('#mb-thumbs-list')?.addEventListener('click', (e) => {
    const actionEl = e.target.closest('[data-action]');
    if (!actionEl) return;
    const { action, id } = actionEl.dataset;
    if (action === 'select') selectMoodBoardImageAction(id);
    else if (action === 'remove') removeMoodBoardImageAction(id);
    else if (action === 'remove-swatch-group') removeSwatchGroupAction(id);
    else if (action === 'move-item-left') moveBoardItemAction(id, -1);
    else if (action === 'move-item-right') moveBoardItemAction(id, 1);
  });
  $('#mb-thumbs-list')?.addEventListener('keydown', (e) => {
    const target = e.target.closest('[data-action="select"]');
    if (target && (e.key === 'Enter' || e.key === ' ')) {
      e.preventDefault();
      selectMoodBoardImageAction(target.dataset.id);
    }
  });

  document.addEventListener('moodboard:state-change', () => {
    updateMoodBoardUI();
    updateExtractButtonState(!!getSelectedImage());
    persistState();
  });

  onMoodBoardChange(persistState);
}

function wireGlobalPaste() {
  window.addEventListener('paste', (e) => {
    const items = (e.clipboardData || e.originalEvent?.clipboardData)?.items;
    if (!items) return;
    for (const item of items) {
      if (item.kind === 'file' && item.type.startsWith('image/')) {
        const blob = item.getAsFile();
        if (getCurrentTab() === 'palette') {
          processPaletteImageFile(blob, (loading) => setLoading('palette-loading', loading));
        } else {
          addImagesToMoodBoard([blob], (loading) => setLoading('mb-loading', loading));
        }
        break;
      }
    }
  });
}

async function boot() {
  refreshIcons();
  wireTabs();
  wirePaletteControls();
  wireMoodBoardControls();
  wireGlobalPaste();
  initMoodBoard();

  const persisted = loadState();
  if (persisted) {
    applyPaletteSettings(persisted.palette || {});
    await hydrateMoodBoardFromStorage(persisted.moodboard);
    logger.info('main', 'Restored persisted state');
  }

  syncPaletteControlsUI();
  renderPaletteCompositeCanvas();
  const mbState = getMoodBoardState();
  updateMbColumnButtons(mbState.columns);
  updateMbRatioButtons(mbState.ratio);
  updateMbModeButtons(mbState.mode);
  updateMbBgButtons(mbState.bgColor);
  const gutterSlider = $('#mb-gutter');
  const paddingSlider = $('#mb-padding');
  const radiusSlider = $('#mb-radius');
  const customBg = $('#mb-custom-bg');
  if (gutterSlider) gutterSlider.value = String(mbState.gutter);
  if (paddingSlider) paddingSlider.value = String(mbState.padding);
  if (radiusSlider) radiusSlider.value = String(mbState.radius);
  if (customBg) customBg.value = mbState.bgColor;
  $('#mb-gutter-label') && ($('#mb-gutter-label').textContent = `${mbState.gutter} px`);
  $('#mb-padding-label') && ($('#mb-padding-label').textContent = `${mbState.padding} px`);
  $('#mb-radius-label') && ($('#mb-radius-label').textContent = `${mbState.radius} px`);

  updateMoodBoardUI();
  updateExtractButtonState(!!getSelectedImage());
  renderMoodBoard();

  if (!persisted) {
    createSampleImage('sunset');
  }
}

window.addEventListener('DOMContentLoaded', () => {
  boot().catch(err => logger.error('main', 'Failed to initialize app', err));
});

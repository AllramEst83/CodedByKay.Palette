import { extractImagePalette } from './kmeans.js';
import { $, reportError, copyToClipboard, refreshIcons, showToast } from './dom-utils.js';
import { getSelectedImage, getMoodBoardState, DYNAMIC_CANVAS_W } from './moodboard-state.js';
import { addSwatchGroupAction } from './moodboard.js';
import { logger } from './logger.js';

const SWATCH_GROUP_WIDTH = 180;
const SWATCH_GROUP_ROW_HEIGHT = 34;
const SWATCH_GROUP_GAP = 24;

function rectsOverlap(a, b) {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

function getOtherItems(sourceItem) {
  const state = getMoodBoardState();
  return [...state.images, ...state.stickyNotes, ...state.swatchGroups]
    .filter(item => item.id !== sourceItem.id);
}

// Prefers a spot directly to the right of the source image, falling back to
// its left or below it — whichever doesn't collide with another board item.
function computeAdjacentPosition(sourceItem, objW, objH) {
  const others = getOtherItems(sourceItem);
  const candidates = [
    { x: sourceItem.x + sourceItem.w + SWATCH_GROUP_GAP, y: sourceItem.y },
    { x: sourceItem.x - objW - SWATCH_GROUP_GAP, y: sourceItem.y },
    { x: sourceItem.x, y: sourceItem.y + sourceItem.h + SWATCH_GROUP_GAP },
  ];

  for (const pos of candidates) {
    if (pos.x < 0 || pos.x + objW > DYNAMIC_CANVAS_W) continue;
    const rect = { x: pos.x, y: pos.y, w: objW, h: objH };
    const collides = others.some(item => rectsOverlap(rect, item));
    if (!collides) return pos;
  }

  // Board is packed tight around the source — drop below everything instead
  // of stacking on top of a neighboring item.
  const lowestBottom = others.reduce((max, item) => Math.max(max, item.y + item.h), sourceItem.y + sourceItem.h);
  return {
    x: Math.max(0, Math.min(sourceItem.x, DYNAMIC_CANVAS_W - objW)),
    y: lowestBottom + SWATCH_GROUP_GAP,
  };
}

export function extractSelectedImagePalette(kCount = 5) {
  const item = getSelectedImage();
  const container = $('#mb-extracted-swatches');
  if (!container) return;

  if (!item) {
    reportError('moodboard-extract', 'Select a mood board image first', new Error('No selection'));
    return;
  }

  try {
    const colors = extractImagePalette(item.img, kCount, 'prominence');
    renderExtractedSwatches(colors, container);
    logger.info('moodboard-extract', `Extracted palette from ${item.name}`);

    const boardState = getMoodBoardState();
    if (boardState.mode === 'dynamic') {
      const h = Math.max(80, colors.length * SWATCH_GROUP_ROW_HEIGHT);
      const { x, y } = computeAdjacentPosition(item, SWATCH_GROUP_WIDTH, h);
      addSwatchGroupAction({ colors, sourceName: item.name, x, y, w: SWATCH_GROUP_WIDTH, h });
      showToast('Palette added to the board!');
    } else {
      showToast('Palette extracted — switch to Dynamic mode to drag it onto the board');
    }
  } catch (err) {
    reportError('moodboard-extract', 'Could not extract colors from that image', err);
  }
}

function renderExtractedSwatches(colors, container) {
  container.innerHTML = '';
  container.classList.remove('hidden');

  colors.forEach((color, index) => {
    const isLight = color.luminance > 140;
    const chip = document.createElement('button');
    chip.type = 'button';
    chip.className = 'group relative flex flex-col justify-between p-2 rounded-lg cursor-pointer border border-slate-700/60 shadow-md transition-all hover:scale-[1.03] active:scale-[0.98]';
    chip.style.backgroundColor = color.hex;
    chip.setAttribute('aria-label', `Copy ${color.hex}`);
    chip.innerHTML = `
      <span class="text-[9px] font-bold ${isLight ? 'text-slate-900' : 'text-white'}">#${index + 1}</span>
      <span class="font-mono text-[10px] font-bold ${isLight ? 'text-slate-900' : 'text-white'}">${color.hex}</span>
    `;
    chip.addEventListener('click', () => copyToClipboard(color.hex));
    container.appendChild(chip);
  });

  refreshIcons();
}

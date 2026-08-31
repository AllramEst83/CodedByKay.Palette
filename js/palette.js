import { extractImagePalette, sortPalette } from './kmeans.js';
import { applyTheme, applyHarmony, THEME_NAMES, HARMONY_NAMES } from './palette-theme.js';
import { $, copyToClipboard, refreshIcons, reportError, showToast } from './dom-utils.js';

const state = {
  paletteImage: null,
  sourceExtractedColors: [],
  displayedColors: [],
  sortMode: 'prominence',
  paletteCount: 5,
  showHexText: true,
  showRgbText: false,
  activeTheme: null,
  activeHarmony: null,
  baseColorIndex: 0,
};

export function getPaletteState() {
  return state;
}

export function applyPaletteSettings(settings = {}) {
  if (settings.paletteCountK !== undefined) state.paletteCount = settings.paletteCountK;
  if (settings.sortMode !== undefined) state.sortMode = settings.sortMode;
  if (settings.showHexText !== undefined) state.showHexText = settings.showHexText;
  if (settings.showRgbText !== undefined) state.showRgbText = settings.showRgbText;
  if (settings.activeTheme !== undefined) state.activeTheme = settings.activeTheme;
  if (settings.activeHarmony !== undefined) state.activeHarmony = settings.activeHarmony;
  if (settings.baseColorIndex !== undefined) state.baseColorIndex = settings.baseColorIndex;
}

function activeButtonClass(active) {
  return active
    ? 'py-1.5 rounded-lg font-medium transition-all text-white bg-indigo-600'
    : 'py-1.5 rounded-lg font-medium transition-all text-slate-400 hover:text-slate-200';
}

function findDominantIndex(colors) {
  if (!colors.length) return 0;
  let idx = 0;
  colors.forEach((c, i) => { if (c.count > colors[idx].count) idx = i; });
  return idx;
}

function recomputeDisplayedColors() {
  if (state.activeTheme) {
    state.displayedColors = applyTheme(state.sourceExtractedColors, state.activeTheme);
  } else if (state.activeHarmony) {
    state.displayedColors = applyHarmony(
      state.sourceExtractedColors,
      state.baseColorIndex,
      state.activeHarmony,
      state.sourceExtractedColors.length
    );
  } else {
    state.displayedColors = state.sourceExtractedColors;
  }
}

function updateThemeButtonStates() {
  ['original', ...THEME_NAMES].forEach(name => {
    const btn = $(`#theme-${name}`);
    if (!btn) return;
    const active = name === 'original'
      ? !state.activeTheme && !state.activeHarmony
      : name === state.activeTheme;
    btn.className = activeButtonClass(active);
    btn.setAttribute('aria-pressed', String(active));
  });
}

function updateHarmonyButtonStates() {
  HARMONY_NAMES.forEach(name => {
    const btn = $(`#harmony-${name}`);
    if (!btn) return;
    const active = name === state.activeHarmony;
    btn.className = activeButtonClass(active);
    btn.setAttribute('aria-pressed', String(active));
  });
}

function updateBaseColorIndicator() {
  const swatch = $('#palette-base-color-swatch');
  const label = $('#palette-base-color-label');
  const base = state.sourceExtractedColors[state.baseColorIndex];
  if (swatch) swatch.style.backgroundColor = base ? base.hex : '#6366f1';
  if (label) label.textContent = base ? base.hex : '—';
}

export function setPaletteSort(mode) {
  state.sortMode = mode;
  ['prominence', 'luminance', 'hue'].forEach(m => {
    const btn = $(`#sort-${m}`);
    if (!btn) return;
    const active = m === mode;
    btn.className = activeButtonClass(active);
    btn.setAttribute('aria-pressed', String(active));
  });

  if (state.sourceExtractedColors.length > 0) {
    state.sourceExtractedColors = sortPalette(state.sourceExtractedColors, mode);
    state.baseColorIndex = findDominantIndex(state.sourceExtractedColors);
    recomputeDisplayedColors();
    renderPaletteUI();
    renderPaletteCompositeCanvas();
  }
}

export function setBaseColorIndex(index) {
  if (index < 0 || index >= state.sourceExtractedColors.length) return;
  state.baseColorIndex = index;
  updateBaseColorIndicator();
  if (state.activeHarmony) {
    recomputeDisplayedColors();
    renderPaletteUI();
    renderPaletteCompositeCanvas();
  } else {
    renderPaletteUI();
  }
}

export function applyPaletteTheme(themeName) {
  state.activeHarmony = null;
  state.activeTheme = themeName === 'original' ? null : themeName;
  recomputeDisplayedColors();
  updateThemeButtonStates();
  updateHarmonyButtonStates();
  renderPaletteUI();
  renderPaletteCompositeCanvas();
}

export function applyPaletteHarmony(schemeName) {
  state.activeTheme = null;
  state.activeHarmony = schemeName;
  recomputeDisplayedColors();
  updateThemeButtonStates();
  updateHarmonyButtonStates();
  renderPaletteUI();
  renderPaletteCompositeCanvas();
}

export function resetPaletteToSource() {
  applyPaletteTheme('original');
}

export function renderPaletteUI() {
  const container = $('#swatches-container');
  if (!container) return;
  container.innerHTML = '';

  if (!state.displayedColors || state.displayedColors.length === 0) return;

  state.displayedColors.forEach((color, index) => {
    const isLight = color.luminance > 140;
    const baseRing = index === state.baseColorIndex ? ' ring-2 ring-indigo-500' : '';
    const chip = document.createElement('div');
    chip.className = `group relative flex flex-col justify-between p-2.5 rounded-xl cursor-pointer border border-slate-700/60 shadow-md transition-all duration-150 hover:scale-[1.03] active:scale-[0.98] select-none${baseRing}`;
    chip.style.backgroundColor = color.hex;
    chip.setAttribute('role', 'button');
    chip.setAttribute('tabindex', '0');
    chip.setAttribute('aria-label', `Swatch ${index + 1}, ${color.hex}. Click to copy, shift-click to use as harmony base.`);

    chip.innerHTML = `
      <div class="flex justify-between items-start">
        <span class="text-[10px] font-bold px-1.5 py-0.5 rounded-md ${isLight ? 'bg-black/15 text-slate-900' : 'bg-white/20 text-white'} backdrop-blur-sm">
          #${index + 1}
        </span>
        <span class="opacity-0 group-hover:opacity-100 transition-opacity p-1 rounded-md ${isLight ? 'bg-black/20 text-slate-900' : 'bg-white/25 text-white'}">
          <i data-lucide="copy" class="w-3 h-3"></i>
        </span>
      </div>
      <div class="mt-4">
        <p class="font-mono text-xs font-bold ${isLight ? 'text-slate-900' : 'text-white'} tracking-wider drop-shadow-sm">${color.hex}</p>
        <p class="font-mono text-[9px] ${isLight ? 'text-slate-800/80' : 'text-slate-200/80'}">${color.r}, ${color.g}, ${color.b}</p>
      </div>
    `;

    chip.addEventListener('click', (e) => {
      if (e.shiftKey) {
        setBaseColorIndex(index);
      } else {
        copyToClipboard(color.hex);
      }
    });
    chip.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        copyToClipboard(color.hex);
      }
    });

    container.appendChild(chip);
  });

  updateBaseColorIndicator();
  refreshIcons();
}

const SWATCH_PADDING_X = 12;
const MIN_SWATCH_WIDTH = 48;
const MIN_FONT_SIZE = 9;
const MIN_SUB_FONT_SIZE = 7;

function measureSwatchWidths(ctx, colors, fontSize, subFontSize, showHex, showRgb) {
  return colors.map(color => {
    let needed = MIN_SWATCH_WIDTH;
    if (showHex && showRgb) {
      ctx.font = `bold ${fontSize}px 'JetBrains Mono', monospace`;
      const hexW = ctx.measureText(color.hex).width;
      ctx.font = `500 ${subFontSize}px 'JetBrains Mono', monospace`;
      const rgbW = ctx.measureText(`${color.r}, ${color.g}, ${color.b}`).width;
      needed = Math.max(needed, Math.max(hexW, rgbW) + SWATCH_PADDING_X * 2);
    } else if (showHex) {
      ctx.font = `bold ${fontSize + 2}px 'JetBrains Mono', monospace`;
      needed = Math.max(needed, ctx.measureText(color.hex).width + SWATCH_PADDING_X * 2);
    } else if (showRgb) {
      ctx.font = `bold ${fontSize}px 'JetBrains Mono', monospace`;
      const label = `rgb(${color.r},${color.g},${color.b})`;
      needed = Math.max(needed, ctx.measureText(label).width + SWATCH_PADDING_X * 2);
    }
    return needed;
  });
}

// Shrinks font size until each swatch's natural (content-driven) width fits
// within the fixed strip width, then allocates widths proportional to each
// swatch's label length so long labels get more room than short ones.
function fitSwatchTypography(ctx, colors, totalWidth, swatchStripHeight, showHex, showRgb) {
  let fontSize = Math.max(14, Math.round(swatchStripHeight * 0.18));
  let subFontSize = Math.max(10, Math.round(swatchStripHeight * 0.12));
  let naturalWidths = measureSwatchWidths(ctx, colors, fontSize, subFontSize, showHex, showRgb);

  while (
    naturalWidths.reduce((a, b) => a + b, 0) > totalWidth
    && (fontSize > MIN_FONT_SIZE || subFontSize > MIN_SUB_FONT_SIZE)
  ) {
    fontSize = Math.max(MIN_FONT_SIZE, fontSize - 1);
    subFontSize = Math.max(MIN_SUB_FONT_SIZE, subFontSize - 1);
    naturalWidths = measureSwatchWidths(ctx, colors, fontSize, subFontSize, showHex, showRgb);
  }

  const naturalTotal = naturalWidths.reduce((a, b) => a + b, 0);
  const scale = naturalTotal > 0 ? totalWidth / naturalTotal : 1;
  const swatchWidths = naturalWidths.map(w => w * scale);

  return { fontSize, subFontSize, swatchWidths };
}

function renderBelowStripComposite(ctx, canvas, image, imgW, imgH, colors, showHex, showRgb) {
  const numSwatches = colors.length;
  const swatchStripHeight = Math.max(80, Math.round(imgH * 0.18));
  const totalWidth = imgW;
  const totalHeight = imgH + swatchStripHeight;

  canvas.width = totalWidth;
  canvas.height = totalHeight;

  ctx.drawImage(image, 0, 0, imgW, imgH);

  const { fontSize, subFontSize, swatchWidths } = fitSwatchTypography(
    ctx, colors, totalWidth, swatchStripHeight, showHex, showRgb
  );

  let cursorX = 0;
  colors.forEach((color, i) => {
    const x = cursorX;
    const y = imgH;
    const w = i === numSwatches - 1 ? totalWidth - x : swatchWidths[i];
    cursorX += w;

    ctx.fillStyle = color.hex;
    ctx.fillRect(x, y, w, swatchStripHeight);

    const isLight = color.luminance > 140;
    ctx.fillStyle = isLight ? '#0f172a' : '#ffffff';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    if (showHex && showRgb) {
      ctx.font = `bold ${fontSize}px 'JetBrains Mono', monospace`;
      ctx.fillText(color.hex, x + w / 2, y + swatchStripHeight * 0.38);
      ctx.font = `500 ${subFontSize}px 'JetBrains Mono', monospace`;
      ctx.fillStyle = isLight ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.75)';
      ctx.fillText(`${color.r}, ${color.g}, ${color.b}`, x + w / 2, y + swatchStripHeight * 0.68);
    } else if (showHex) {
      ctx.font = `bold ${fontSize + 2}px 'JetBrains Mono', monospace`;
      ctx.fillText(color.hex, x + w / 2, y + swatchStripHeight / 2);
    } else if (showRgb) {
      ctx.font = `bold ${fontSize}px 'JetBrains Mono', monospace`;
      ctx.fillText(`rgb(${color.r},${color.g},${color.b})`, x + w / 2, y + swatchStripHeight / 2);
    }
  });

  ctx.strokeStyle = 'rgba(0, 0, 0, 0.15)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(0, imgH);
  ctx.lineTo(totalWidth, imgH);
  ctx.stroke();
}

const SIDEBAR_MIN_WIDTH = 200;
const SIDEBAR_ROW_MIN_HEIGHT = 44;
const SIDEBAR_PADDING_X = 16;

// Used when the image is too narrow for a horizontal strip beneath it to stay
// legible — instead lists swatches as a vertical column next to the image,
// so text width is decoupled from the image's own width.
function renderSidebarComposite(ctx, canvas, image, imgW, imgH, colors, showHex, showRgb) {
  const numSwatches = colors.length;

  const rowHeight = Math.max(SIDEBAR_ROW_MIN_HEIGHT, Math.round(imgH / numSwatches));
  const sidebarHeight = rowHeight * numSwatches;
  const canvasHeight = Math.max(imgH, sidebarHeight);

  const rowFontSize = Math.max(13, Math.min(20, Math.round(rowHeight * 0.32)));
  const rowSubFontSize = Math.max(10, Math.min(15, Math.round(rowHeight * 0.22)));

  ctx.font = `bold ${rowFontSize}px 'JetBrains Mono', monospace`;
  let maxLabelWidth = Math.max(...colors.map(c => ctx.measureText(c.hex).width));
  if (showRgb) {
    ctx.font = `500 ${rowSubFontSize}px 'JetBrains Mono', monospace`;
    const maxRgbWidth = Math.max(...colors.map(c => ctx.measureText(`${c.r}, ${c.g}, ${c.b}`).width));
    maxLabelWidth = Math.max(maxLabelWidth, maxRgbWidth);
  }
  const sidebarWidth = Math.max(SIDEBAR_MIN_WIDTH, Math.round(maxLabelWidth + SIDEBAR_PADDING_X * 2));

  const totalWidth = imgW + sidebarWidth;

  canvas.width = totalWidth;
  canvas.height = canvasHeight;

  ctx.fillStyle = '#0f172a';
  ctx.fillRect(0, 0, totalWidth, canvasHeight);

  ctx.drawImage(image, 0, 0, imgW, imgH);

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';

  colors.forEach((color, i) => {
    const x = imgW;
    const y = i * rowHeight;
    const textX = x + SIDEBAR_PADDING_X;

    ctx.fillStyle = color.hex;
    ctx.fillRect(x, y, sidebarWidth, rowHeight);

    const isLight = color.luminance > 140;

    if (showHex && showRgb) {
      ctx.font = `bold ${rowFontSize}px 'JetBrains Mono', monospace`;
      ctx.fillStyle = isLight ? '#0f172a' : '#ffffff';
      ctx.fillText(color.hex, textX, y + rowHeight * 0.36);
      ctx.font = `500 ${rowSubFontSize}px 'JetBrains Mono', monospace`;
      ctx.fillStyle = isLight ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.75)';
      ctx.fillText(`${color.r}, ${color.g}, ${color.b}`, textX, y + rowHeight * 0.68);
    } else if (showHex) {
      ctx.font = `bold ${rowFontSize + 2}px 'JetBrains Mono', monospace`;
      ctx.fillStyle = isLight ? '#0f172a' : '#ffffff';
      ctx.fillText(color.hex, textX, y + rowHeight / 2);
    } else if (showRgb) {
      ctx.font = `bold ${rowFontSize}px 'JetBrains Mono', monospace`;
      ctx.fillStyle = isLight ? '#0f172a' : '#ffffff';
      ctx.fillText(`rgb(${color.r},${color.g},${color.b})`, textX, y + rowHeight / 2);
    }

    if (i > 0) {
      ctx.strokeStyle = 'rgba(0, 0, 0, 0.15)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + sidebarWidth, y);
      ctx.stroke();
    }
  });

  ctx.strokeStyle = 'rgba(0, 0, 0, 0.25)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(imgW, 0);
  ctx.lineTo(imgW, canvasHeight);
  ctx.stroke();
}

export function renderPaletteCompositeCanvas() {
  if (!state.paletteImage) return;
  const canvas = $('#palette-composite-canvas');
  const emptyState = $('#palette-empty-state');
  if (!canvas || !emptyState) return;
  emptyState.classList.add('hidden');

  try {
    const ctx = canvas.getContext('2d');
    const imgW = state.paletteImage.naturalWidth || state.paletteImage.width;
    const imgH = state.paletteImage.naturalHeight || state.paletteImage.height;

    const colors = state.displayedColors;
    const numSwatches = colors.length;
    if (numSwatches === 0) return;

    const showHex = $('#show-hex-text')?.checked ?? state.showHexText;
    const showRgb = $('#show-rgb-text')?.checked ?? state.showRgbText;

    const needsLabelSpace = showHex || showRgb;
    const tooNarrowForStrip = needsLabelSpace && imgW < numSwatches * MIN_SWATCH_WIDTH;

    if (tooNarrowForStrip) {
      renderSidebarComposite(ctx, canvas, state.paletteImage, imgW, imgH, colors, showHex, showRgb);
    } else {
      renderBelowStripComposite(ctx, canvas, state.paletteImage, imgW, imgH, colors, showHex, showRgb);
    }

    const dimsLabel = $('#palette-img-dimensions');
    if (dimsLabel) dimsLabel.textContent = `${canvas.width} × ${canvas.height} px`;
  } catch (err) {
    reportError('palette', 'Failed to render palette preview', err);
  }
}

export function loadImageIntoPalette(img) {
  state.paletteImage = img;
  try {
    state.sourceExtractedColors = extractImagePalette(img, state.paletteCount, state.sortMode);
    state.baseColorIndex = findDominantIndex(state.sourceExtractedColors);
    recomputeDisplayedColors();
    updateThemeButtonStates();
    updateHarmonyButtonStates();
    renderPaletteUI();
    renderPaletteCompositeCanvas();
  } catch (err) {
    reportError('palette', 'Could not extract colors from that image', err);
  }
}

export function processPaletteImageFile(file, onLoadingChange) {
  if (!file || !file.type || !file.type.startsWith('image/')) {
    showToast('Please provide a valid image file', false);
    return;
  }

  if (onLoadingChange) onLoadingChange(true);
  const reader = new FileReader();
  reader.onload = (e) => {
    const img = new Image();
    img.onload = () => {
      loadImageIntoPalette(img);
      if (onLoadingChange) onLoadingChange(false);
      showToast('Palette extracted successfully!');
    };
    img.onerror = (err) => {
      if (onLoadingChange) onLoadingChange(false);
      reportError('palette', 'Could not decode that image', err);
    };
    img.src = e.target.result;
  };
  reader.onerror = () => {
    if (onLoadingChange) onLoadingChange(false);
    reportError('palette', 'Could not read that file', reader.error);
  };
  reader.readAsDataURL(file);
}

export function setPaletteCount(count) {
  state.paletteCount = count;
  if (state.paletteImage) {
    try {
      state.sourceExtractedColors = extractImagePalette(state.paletteImage, count, state.sortMode);
      state.baseColorIndex = findDominantIndex(state.sourceExtractedColors);
      recomputeDisplayedColors();
      renderPaletteUI();
      renderPaletteCompositeCanvas();
    } catch (err) {
      reportError('palette', 'Could not re-extract colors', err);
    }
  }
}

export function setShowHexText(value) {
  state.showHexText = value;
  renderPaletteCompositeCanvas();
}

export function setShowRgbText(value) {
  state.showRgbText = value;
  renderPaletteCompositeCanvas();
}

export function getPaletteSnapshot() {
  return {
    paletteCountK: state.paletteCount,
    sortMode: state.sortMode,
    showHexText: state.showHexText,
    showRgbText: state.showRgbText,
    activeTheme: state.activeTheme,
    activeHarmony: state.activeHarmony,
    baseColorIndex: state.baseColorIndex,
  };
}

export function syncPaletteControlsUI() {
  setPaletteSort(state.sortMode);
  updateThemeButtonStates();
  updateHarmonyButtonStates();
  updateBaseColorIndicator();
  const hexBox = $('#show-hex-text');
  const rgbBox = $('#show-rgb-text');
  if (hexBox) hexBox.checked = state.showHexText;
  if (rgbBox) rgbBox.checked = state.showRgbText;
  const countSlider = $('#palette-count');
  const countLabel = $('#palette-count-label');
  if (countSlider) countSlider.value = String(state.paletteCount);
  if (countLabel) countLabel.textContent = `${state.paletteCount} Colors`;
}

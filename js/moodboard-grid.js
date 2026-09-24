import { $, reportError } from './dom-utils.js';
import { getMoodBoardState, getBoardItems } from './moodboard-state.js';

function drawImageCell(ctx, item, x, y, cellWidth, cellHeight) {
  const img = item.img;
  const imgAspect = (img.naturalWidth || img.width) / (img.naturalHeight || img.height);
  const cellAspect = cellWidth / cellHeight;

  let sx = 0, sy = 0, sWidth = img.naturalWidth || img.width, sHeight = img.naturalHeight || img.height;
  if (imgAspect > cellAspect) {
    sWidth = (img.naturalHeight || img.height) * cellAspect;
    sx = ((img.naturalWidth || img.width) - sWidth) / 2;
  } else {
    sHeight = (img.naturalWidth || img.width) / cellAspect;
    sy = ((img.naturalHeight || img.height) - sHeight) / 2;
  }

  ctx.drawImage(img, sx, sy, sWidth, sHeight, x, y, cellWidth, cellHeight);
}

function drawSwatchGroupCell(ctx, item, x, y, cellWidth, cellHeight) {
  const rowCount = item.colors.length;
  const rowHeight = cellHeight / rowCount;

  item.colors.forEach((color, i) => {
    const rowY = y + i * rowHeight;
    ctx.fillStyle = color.hex;
    ctx.fillRect(x, rowY, cellWidth, rowHeight);

    const isLight = color.luminance > 140;
    ctx.fillStyle = isLight ? '#0f172a' : '#ffffff';
    ctx.font = `700 ${Math.max(10, Math.min(20, Math.round(rowHeight * 0.4)))}px 'JetBrains Mono', monospace`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(color.hex, x + cellWidth / 2, rowY + rowHeight / 2);
  });
}

function getItemAspect(item) {
  if (item.kind === 'image' && item.img) {
    const w = item.img.naturalWidth || item.img.width;
    const h = item.img.naturalHeight || item.img.height;
    return h ? w / h : 1;
  }
  if (item.kind === 'swatch-group' && item.w && item.h) {
    return item.w / item.h;
  }
  return 1;
}

// Lays out cells into a fixed-ratio grid, or (for 'original') a Pinterest-style
// masonry of columns where each cell keeps its own image's natural aspect ratio.
function layoutGridCells(cells, cols, cellWidth, gutter, padding, ratio) {
  if (ratio === 'original') {
    const columnHeights = new Array(cols).fill(0);
    const layout = cells.map(item => {
      let colIndex = 0;
      for (let c = 1; c < cols; c++) {
        if (columnHeights[c] < columnHeights[colIndex]) colIndex = c;
      }
      const cellHeight = cellWidth / getItemAspect(item);
      const x = padding + colIndex * (cellWidth + gutter);
      const y = padding + columnHeights[colIndex];
      columnHeights[colIndex] += cellHeight + gutter;
      return { item, x, y, w: cellWidth, h: cellHeight };
    });
    const canvasHeight = padding * 2 + Math.max(...columnHeights) - gutter;
    return { layout, canvasHeight };
  }

  let cellHeight = cellWidth;
  if (ratio === '4:3') cellHeight = (cellWidth * 3) / 4;
  else if (ratio === '3:4') cellHeight = (cellWidth * 4) / 3;
  else if (ratio === '16:9') cellHeight = (cellWidth * 9) / 16;

  const rows = Math.ceil(cells.length / cols);
  const layout = cells.map((item, index) => {
    const col = index % cols;
    const row = Math.floor(index / cols);
    return {
      item,
      x: padding + col * (cellWidth + gutter),
      y: padding + row * (cellHeight + gutter),
      w: cellWidth,
      h: cellHeight,
    };
  });
  const canvasHeight = padding * 2 + rows * cellHeight + (rows - 1) * gutter;
  return { layout, canvasHeight };
}

export function renderMoodBoardGridCanvas() {
  const state = getMoodBoardState();
  const canvas = $('#mb-composite-canvas');
  const emptyState = $('#mb-empty-state');
  const dimensionsLabel = $('#mb-canvas-dimensions');
  if (!canvas || !emptyState || !dimensionsLabel) return;

  const cells = getBoardItems();

  if (!cells.length) {
    canvas.classList.add('hidden');
    emptyState.classList.remove('hidden');
    dimensionsLabel.textContent = 'Empty';
    return;
  }

  canvas.classList.remove('hidden');
  emptyState.classList.add('hidden');

  try {
    const ctx = canvas.getContext('2d');
    const totalCells = cells.length;
    const cols = Math.min(state.columns, totalCells);

    const baseCanvasWidth = 1920;
    const availableWidth = baseCanvasWidth - state.padding * 2 - (cols - 1) * state.gutter;
    const cellWidth = availableWidth / cols;

    const { layout, canvasHeight } = layoutGridCells(cells, cols, cellWidth, state.gutter, state.padding, state.ratio);

    canvas.width = baseCanvasWidth;
    canvas.height = canvasHeight;

    ctx.fillStyle = state.bgColor;
    ctx.fillRect(0, 0, baseCanvasWidth, canvasHeight);

    layout.forEach(({ item, x, y, w, h }) => {
      ctx.save();
      ctx.beginPath();
      if (typeof ctx.roundRect === 'function') {
        ctx.roundRect(x, y, w, h, state.radius);
      } else {
        const r = state.radius;
        ctx.moveTo(x + r, y);
        ctx.arcTo(x + w, y, x + w, y + h, r);
        ctx.arcTo(x + w, y + h, x, y + h, r);
        ctx.arcTo(x, y + h, x, y, r);
        ctx.arcTo(x, y, x + w, y, r);
      }
      ctx.closePath();
      ctx.clip();

      if (item.kind === 'image') {
        drawImageCell(ctx, item, x, y, w, h);
      } else {
        drawSwatchGroupCell(ctx, item, x, y, w, h);
      }
      ctx.restore();

      if (state.radius > 0) {
        ctx.save();
        ctx.beginPath();
        if (typeof ctx.roundRect === 'function') {
          ctx.roundRect(x, y, w, h, state.radius);
        }
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
        ctx.lineWidth = 2;
        ctx.stroke();
        ctx.restore();
      }
    });

    dimensionsLabel.textContent = `${baseCanvasWidth} × ${Math.round(canvasHeight)} px`;
  } catch (err) {
    reportError('moodboard-grid', 'Failed to render mood board', err);
  }
}

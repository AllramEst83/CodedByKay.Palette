import { $, reportError } from './dom-utils.js';
import { getMoodBoardState } from './moodboard-state.js';

export function renderMoodBoardGridCanvas() {
  const state = getMoodBoardState();
  const canvas = $('#mb-composite-canvas');
  const emptyState = $('#mb-empty-state');
  const dimensionsLabel = $('#mb-canvas-dimensions');
  if (!canvas || !emptyState || !dimensionsLabel) return;

  if (!state.images.length && !state.stickyNotes.length) {
    emptyState.classList.remove('hidden');
    canvas.width = 1;
    canvas.height = 1;
    dimensionsLabel.textContent = 'Empty';
    return;
  }

  emptyState.classList.add('hidden');

  try {
    const ctx = canvas.getContext('2d');
    const totalImages = Math.max(state.images.length, 1);
    const cols = Math.min(state.columns, totalImages);
    const rows = Math.ceil(totalImages / cols);

    const baseCanvasWidth = 1920;
    const availableWidth = baseCanvasWidth - state.padding * 2 - (cols - 1) * state.gutter;
    const cellWidth = availableWidth / cols;

    let cellHeight = cellWidth;
    if (state.ratio === '4:3') cellHeight = (cellWidth * 3) / 4;
    else if (state.ratio === '3:4') cellHeight = (cellWidth * 4) / 3;
    else if (state.ratio === '16:9') cellHeight = (cellWidth * 9) / 16;

    const baseCanvasHeight = state.padding * 2 + rows * cellHeight + (rows - 1) * state.gutter;

    canvas.width = baseCanvasWidth;
    canvas.height = baseCanvasHeight;

    ctx.fillStyle = state.bgColor;
    ctx.fillRect(0, 0, baseCanvasWidth, baseCanvasHeight);

    state.images.forEach((item, index) => {
      const col = index % cols;
      const row = Math.floor(index / cols);
      const x = state.padding + col * (cellWidth + state.gutter);
      const y = state.padding + row * (cellHeight + state.gutter);
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

      ctx.save();
      ctx.beginPath();
      if (typeof ctx.roundRect === 'function') {
        ctx.roundRect(x, y, cellWidth, cellHeight, state.radius);
      } else {
        const r = state.radius;
        ctx.moveTo(x + r, y);
        ctx.arcTo(x + cellWidth, y, x + cellWidth, y + cellHeight, r);
        ctx.arcTo(x + cellWidth, y + cellHeight, x, y + cellHeight, r);
        ctx.arcTo(x, y + cellHeight, x, y, r);
        ctx.arcTo(x, y, x + cellWidth, y, r);
      }
      ctx.closePath();
      ctx.clip();
      ctx.drawImage(img, sx, sy, sWidth, sHeight, x, y, cellWidth, cellHeight);
      ctx.restore();

      if (state.radius > 0) {
        ctx.save();
        ctx.beginPath();
        if (typeof ctx.roundRect === 'function') {
          ctx.roundRect(x, y, cellWidth, cellHeight, state.radius);
        }
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
        ctx.lineWidth = 2;
        ctx.stroke();
        ctx.restore();
      }
    });

    dimensionsLabel.textContent = `${baseCanvasWidth} × ${Math.round(baseCanvasHeight)} px`;
  } catch (err) {
    reportError('moodboard-grid', 'Failed to render mood board', err);
  }
}

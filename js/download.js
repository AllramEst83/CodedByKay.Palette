import { $, showToast, reportError } from './dom-utils.js';
import { logger } from './logger.js';
import { getMoodBoardState, DYNAMIC_CANVAS_W, DYNAMIC_CANVAS_H } from './moodboard-state.js';
import { wrapCanvasText } from './sticky-notes.js';

export function downloadCanvas(canvas, filename) {
  if (!canvas || canvas.width <= 1 || canvas.height <= 1) {
    showToast('Nothing to export yet!', false);
    return;
  }
  try {
    const dataURL = canvas.toDataURL('image/png');
    const link = document.createElement('a');
    link.download = filename;
    link.href = dataURL;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast('Download started!');
    logger.info('download', `Downloaded ${filename}`);
  } catch (err) {
    reportError('download', 'Error exporting image', err);
  }
}

export function downloadCanvasById(canvasId, filename) {
  downloadCanvas($(`#${canvasId}`), filename);
}

export function downloadDynamicBoardAsPNG(filename = 'mood-board-dynamic.png') {
  const state = getMoodBoardState();
  const canvas = document.createElement('canvas');
  canvas.width = DYNAMIC_CANVAS_W;
  canvas.height = DYNAMIC_CANVAS_H;
  const ctx = canvas.getContext('2d');

  try {
    ctx.fillStyle = state.bgColor;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    const allItems = [
      ...state.images.map(item => ({ ...item, kind: 'image' })),
      ...state.stickyNotes.map(note => ({ ...note, kind: 'note' })),
      ...state.swatchGroups.map(group => ({ ...group, kind: 'swatch-group' })),
    ].sort((a, b) => a.zIndex - b.zIndex);

    allItems.forEach(entry => {
      ctx.save();
      ctx.translate(entry.x + entry.w / 2, entry.y + entry.h / 2);
      ctx.rotate(((entry.rotation || 0) * Math.PI) / 180);

      if (entry.kind === 'image' && entry.img) {
        const img = entry.img;
        const imgAspect = (img.naturalWidth || img.width) / (img.naturalHeight || img.height);
        const cellAspect = entry.w / entry.h;
        let sx = 0, sy = 0, sWidth = img.naturalWidth || img.width, sHeight = img.naturalHeight || img.height;
        if (imgAspect > cellAspect) {
          sWidth = (img.naturalHeight || img.height) * cellAspect;
          sx = ((img.naturalWidth || img.width) - sWidth) / 2;
        } else {
          sHeight = (img.naturalWidth || img.width) / cellAspect;
          sy = ((img.naturalHeight || img.height) - sHeight) / 2;
        }
        ctx.drawImage(img, sx, sy, sWidth, sHeight, -entry.w / 2, -entry.h / 2, entry.w, entry.h);
      } else if (entry.kind === 'note') {
        const r = 12;
        ctx.fillStyle = entry.color;
        ctx.beginPath();
        if (typeof ctx.roundRect === 'function') {
          ctx.roundRect(-entry.w / 2, -entry.h / 2, entry.w, entry.h, r);
        } else {
          ctx.rect(-entry.w / 2, -entry.h / 2, entry.w, entry.h);
        }
        ctx.fill();

        ctx.fillStyle = entry.textColor;
        ctx.font = '600 18px "Plus Jakarta Sans", sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        wrapCanvasText(ctx, entry.text, 0, 0, entry.w - 24, 22);
      } else if (entry.kind === 'swatch-group') {
        const rowCount = entry.colors.length;
        const rowH = entry.h / rowCount;
        entry.colors.forEach((color, i) => {
          const rowY = -entry.h / 2 + i * rowH;
          ctx.fillStyle = color.hex;
          ctx.fillRect(-entry.w / 2, rowY, entry.w, rowH);

          const isLight = color.luminance > 140;
          ctx.fillStyle = isLight ? '#0f172a' : '#ffffff';
          ctx.font = `700 ${Math.max(9, Math.min(16, Math.round(rowH * 0.4)))}px 'JetBrains Mono', monospace`;
          ctx.textAlign = 'left';
          ctx.textBaseline = 'middle';
          ctx.fillText(color.hex, -entry.w / 2 + 10, rowY + rowH / 2);
        });
      }

      ctx.restore();
    });

    downloadCanvas(canvas, filename);
  } catch (err) {
    reportError('download', 'Error exporting dynamic board', err);
  }
}

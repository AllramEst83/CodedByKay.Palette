import { $, refreshIcons } from './dom-utils.js';
import {
  getMoodBoardState, DYNAMIC_CANVAS_W, DYNAMIC_CANVAS_H,
  bringToFront, selectMoodBoardItem, clearMoodBoardSelection,
  updateItemPosition, findMoodBoardItem, removeStickyNote, updateStickyNote,
  removeSwatchGroup,
} from './moodboard-state.js';
import { DEFAULT_NOTE_COLORS } from './sticky-notes.js';

const MIN_RESIZE_SIZE = 60;
const RESIZABLE_KINDS = new Set(['note', 'swatch-group']);

let dragState = null;
let resizeState = null;

function getContainer() {
  return $('#mb-dynamic-canvas');
}

function domScale(container) {
  const rect = container.getBoundingClientRect();
  return {
    scaleX: rect.width / DYNAMIC_CANVAS_W || 1,
    scaleY: rect.height / DYNAMIC_CANVAS_H || 1,
    rect,
  };
}

function clientToLogical(container, clientX, clientY) {
  const { rect, scaleX, scaleY } = domScale(container);
  return {
    x: (clientX - rect.left) / scaleX,
    y: (clientY - rect.top) / scaleY,
  };
}

function notifyStateChange() {
  document.dispatchEvent(new CustomEvent('moodboard:state-change'));
}

function clampPosition(x, y, w, h) {
  return {
    x: Math.min(Math.max(0, x), Math.max(0, DYNAMIC_CANVAS_W - w)),
    y: Math.min(Math.max(0, y), Math.max(0, DYNAMIC_CANVAS_H - h)),
  };
}

function clampSize(x, y, w, h) {
  return {
    w: Math.min(w, Math.max(MIN_RESIZE_SIZE, DYNAMIC_CANVAS_W - x)),
    h: Math.min(h, Math.max(MIN_RESIZE_SIZE, DYNAMIC_CANVAS_H - y)),
  };
}

function isEditingText(container) {
  const active = document.activeElement;
  return !!active && active.classList?.contains('note-text') && container.contains(active);
}

function focusSelectedItem() {
  const container = getContainer();
  const state = getMoodBoardState();
  if (!container || !state.selectedId) return;
  if (isEditingText(container)) return;
  const selectedEl = container.querySelector(`[data-id="${state.selectedId}"]`);
  if (selectedEl && document.activeElement !== selectedEl) selectedEl.focus({ preventScroll: true });
}

export function renderDynamicCanvas() {
  const container = getContainer();
  const emptyState = $('#mb-empty-state');
  if (!container) return;
  const state = getMoodBoardState();

  const hasContent = state.images.length > 0 || state.stickyNotes.length > 0 || state.swatchGroups.length > 0;
  if (emptyState) emptyState.classList.toggle('hidden', hasContent);

  container.style.backgroundColor = state.bgColor;
  container.innerHTML = '';

  const { scaleX, scaleY } = domScale(container);

  const allItems = [
    ...state.images.map(item => ({ ...item, kind: 'image' })),
    ...state.stickyNotes.map(note => ({ ...note, kind: 'note' })),
    ...state.swatchGroups.map(group => ({ ...group, kind: 'swatch-group' })),
  ].sort((a, b) => a.zIndex - b.zIndex);

  allItems.forEach(entry => {
    const el = document.createElement('div');
    el.dataset.id = entry.id;
    el.dataset.kind = entry.kind;
    el.setAttribute('tabindex', '0');
    el.setAttribute('role', 'button');
    el.style.position = 'absolute';
    el.style.left = `${entry.x * scaleX}px`;
    el.style.top = `${entry.y * scaleY}px`;
    el.style.width = `${entry.w * scaleX}px`;
    el.style.height = `${entry.h * scaleY}px`;
    el.style.transform = `rotate(${entry.rotation || 0}deg)`;
    el.style.zIndex = String(entry.zIndex);
    el.style.cursor = 'grab';
    el.style.touchAction = 'none';

    if (entry.selected) {
      el.style.outline = '2px solid #6366f1';
      el.style.outlineOffset = '2px';
    }

    if (entry.kind === 'image') {
      el.className = 'rounded-lg overflow-hidden shadow-lg';
      el.setAttribute('aria-label', entry.name || 'Mood board image');
      const img = document.createElement('img');
      img.src = entry.src;
      img.alt = entry.name || 'Mood board image';
      img.style.width = '100%';
      img.style.height = '100%';
      img.style.objectFit = 'cover';
      img.draggable = false;
      el.appendChild(img);
    } else if (entry.kind === 'note') {
      el.className = 'rounded-lg shadow-lg p-3';
      el.style.backgroundColor = entry.color;
      el.style.color = entry.textColor;
      el.setAttribute('aria-label', 'Sticky note');
      const text = document.createElement('div');
      text.className = 'note-text w-full h-full text-sm font-medium leading-snug outline-none overflow-hidden';
      text.textContent = entry.text;
      text.contentEditable = 'false';
      el.appendChild(text);

      if (entry.selected) {
        const toolbar = document.createElement('div');
        toolbar.className = 'absolute -top-9 left-0 flex items-center gap-1 bg-slate-900/95 border border-slate-700 rounded-lg px-1.5 py-1 shadow-lg';
        toolbar.style.zIndex = '9999';
        toolbar.innerHTML = `<button type="button" data-action="edit-note" data-id="${entry.id}" class="text-slate-300 hover:text-white" aria-label="Edit note text"><i data-lucide="pencil" class="w-3.5 h-3.5"></i></button>`
          + `<span class="w-px h-3.5 bg-slate-700 mx-0.5"></span>`
          + DEFAULT_NOTE_COLORS.map(c =>
            `<button type="button" data-action="set-note-color" data-id="${entry.id}" data-color="${c}" class="w-3.5 h-3.5 rounded-full border border-slate-600" style="background-color:${c}" aria-label="Set note color ${c}"></button>`
          ).join('') + `<button type="button" data-action="delete-note" data-id="${entry.id}" class="ml-1 text-rose-400 hover:text-rose-300" aria-label="Delete note"><i data-lucide="trash-2" class="w-3.5 h-3.5"></i></button>`;
        el.appendChild(toolbar);
      }
    } else if (entry.kind === 'swatch-group') {
      el.className = 'rounded-lg shadow-lg overflow-hidden border border-slate-700 bg-slate-900 flex flex-col';
      el.setAttribute('aria-label', `Extracted palette from ${entry.sourceName || 'image'}`);

      const rowHeightPx = (entry.h * scaleY) / entry.colors.length;
      const rowFontSize = Math.max(8, Math.min(13, Math.round(rowHeightPx * 0.4)));

      entry.colors.forEach(color => {
        const row = document.createElement('div');
        const isLight = color.luminance > 140;
        row.className = 'flex items-center px-2 overflow-hidden';
        row.style.flex = '1 1 0';
        row.style.minHeight = '0';
        row.style.backgroundColor = color.hex;
        row.style.color = isLight ? '#0f172a' : '#ffffff';
        row.style.fontFamily = "'JetBrains Mono', monospace";
        row.style.fontWeight = '700';
        row.style.fontSize = `${rowFontSize}px`;
        row.style.whiteSpace = 'nowrap';
        row.textContent = color.hex;
        el.appendChild(row);
      });

      if (entry.selected) {
        const toolbar = document.createElement('div');
        toolbar.className = 'absolute -top-9 left-0 flex items-center gap-1 bg-slate-900/95 border border-slate-700 rounded-lg px-1.5 py-1 shadow-lg';
        toolbar.style.zIndex = '9999';
        toolbar.innerHTML = `<button type="button" data-action="delete-swatch-group" data-id="${entry.id}" class="text-rose-400 hover:text-rose-300" aria-label="Delete extracted palette"><i data-lucide="trash-2" class="w-3.5 h-3.5"></i></button>`;
        el.appendChild(toolbar);
      }
    }

    if (entry.selected && RESIZABLE_KINDS.has(entry.kind)) {
      const handle = document.createElement('div');
      handle.dataset.action = 'resize-item';
      handle.dataset.id = entry.id;
      handle.className = 'absolute -right-1.5 -bottom-1.5 w-4 h-4 rounded-sm bg-indigo-500 border-2 border-white shadow';
      handle.style.cursor = 'nwse-resize';
      handle.setAttribute('aria-hidden', 'true');
      el.appendChild(handle);
    }

    container.appendChild(el);
  });

  refreshIcons();
  focusSelectedItem();
}

function onPointerDown(e) {
  const container = getContainer();
  if (!container) return;

  const actionEl = e.target.closest('[data-action]');
  if (actionEl) {
    e.preventDefault();
    const action = actionEl.dataset.action;
    if (action === 'delete-note') {
      removeStickyNote(actionEl.dataset.id);
      renderDynamicCanvas();
      notifyStateChange();
      return;
    }
    if (action === 'set-note-color') {
      updateStickyNote(actionEl.dataset.id, { color: actionEl.dataset.color });
      renderDynamicCanvas();
      notifyStateChange();
      return;
    }
    if (action === 'edit-note') {
      const noteEl = container.querySelector(`[data-id="${actionEl.dataset.id}"]`);
      if (noteEl) enterNoteEditMode(noteEl);
      return;
    }
    if (action === 'delete-swatch-group') {
      removeSwatchGroup(actionEl.dataset.id);
      renderDynamicCanvas();
      notifyStateChange();
      return;
    }
    if (action === 'resize-item') {
      const item = findMoodBoardItem(actionEl.dataset.id);
      if (item) {
        resizeState = {
          id: item.id,
          startClientX: e.clientX,
          startClientY: e.clientY,
          startW: item.w,
          startH: item.h,
        };
        try { actionEl.setPointerCapture(e.pointerId); } catch { /* not a live pointer session */ }
      }
      return;
    }
  }

  const el = e.target.closest('[data-id]');
  if (!el) {
    clearMoodBoardSelection();
    renderDynamicCanvas();
    notifyStateChange();
    return;
  }

  const id = el.dataset.id;
  const item = findMoodBoardItem(id);
  if (!item) return;

  e.preventDefault();
  selectMoodBoardItem(id);
  bringToFront(id);

  const logicalPoint = clientToLogical(container, e.clientX, e.clientY);
  dragState = {
    id,
    offsetX: logicalPoint.x - item.x,
    offsetY: logicalPoint.y - item.y,
  };

  try { el.setPointerCapture(e.pointerId); } catch { /* not a live pointer session */ }
  el.style.cursor = 'grabbing';
  renderDynamicCanvas();
  notifyStateChange();
}

function onPointerMove(e) {
  const container = getContainer();
  if (!container) return;

  if (resizeState) {
    const { scaleX, scaleY } = domScale(container);
    const deltaX = (e.clientX - resizeState.startClientX) / scaleX;
    const deltaY = (e.clientY - resizeState.startClientY) / scaleY;
    const rawW = Math.max(MIN_RESIZE_SIZE, resizeState.startW + deltaX);
    const rawH = Math.max(MIN_RESIZE_SIZE, resizeState.startH + deltaY);
    const item = findMoodBoardItem(resizeState.id);
    const { w: nextW, h: nextH } = clampSize(item ? item.x : 0, item ? item.y : 0, rawW, rawH);

    updateItemPosition(resizeState.id, { w: nextW, h: nextH });

    const el = container.querySelector(`[data-id="${resizeState.id}"]`);
    if (el) {
      el.style.width = `${nextW * scaleX}px`;
      el.style.height = `${nextH * scaleY}px`;
    }
    return;
  }

  if (!dragState) return;

  const logicalPoint = clientToLogical(container, e.clientX, e.clientY);
  const rawX = logicalPoint.x - dragState.offsetX;
  const rawY = logicalPoint.y - dragState.offsetY;
  const draggedItem = findMoodBoardItem(dragState.id);
  const { x: nextX, y: nextY } = clampPosition(rawX, rawY, draggedItem ? draggedItem.w : 0, draggedItem ? draggedItem.h : 0);

  updateItemPosition(dragState.id, { x: nextX, y: nextY });

  const el = container.querySelector(`[data-id="${dragState.id}"]`);
  if (el) {
    const { scaleX, scaleY } = domScale(container);
    el.style.left = `${nextX * scaleX}px`;
    el.style.top = `${nextY * scaleY}px`;
  }
}

function onPointerUp() {
  if (resizeState) {
    resizeState = null;
    renderDynamicCanvas();
    notifyStateChange();
    setTimeout(focusSelectedItem, 0);
    return;
  }
  if (!dragState) return;
  dragState = null;
  notifyStateChange();
  setTimeout(focusSelectedItem, 0);
}

function onKeyDown(e) {
  const state = getMoodBoardState();
  if (!state.selectedId) return;
  const step = e.shiftKey ? 20 : 4;
  const item = findMoodBoardItem(state.selectedId);
  if (!item) return;

  let handled = true;
  let nextX = item.x;
  let nextY = item.y;
  switch (e.key) {
    case 'ArrowLeft': nextX = item.x - step; break;
    case 'ArrowRight': nextX = item.x + step; break;
    case 'ArrowUp': nextY = item.y - step; break;
    case 'ArrowDown': nextY = item.y + step; break;
    case 'Escape': clearMoodBoardSelection(); handled = 'escape'; break;
    default: handled = false;
  }

  if (handled === true) {
    const clamped = clampPosition(nextX, nextY, item.w, item.h);
    updateItemPosition(item.id, clamped);
  }

  if (handled) {
    e.preventDefault();
    renderDynamicCanvas();
    notifyStateChange();
  }
}

function onFocusIn(e) {
  const el = e.target.closest('[data-id]');
  if (!el) return;
  const state = getMoodBoardState();
  if (state.selectedId === el.dataset.id) return;
  selectMoodBoardItem(el.dataset.id);
  renderDynamicCanvas();
  notifyStateChange();
}

function enterNoteEditMode(noteEl) {
  const textEl = noteEl.querySelector('.note-text');
  if (!textEl) return;
  textEl.contentEditable = 'true';
  textEl.focus({ preventScroll: true });

  const selection = window.getSelection();
  const range = document.createRange();
  range.selectNodeContents(textEl);
  selection.removeAllRanges();
  selection.addRange(range);

  const commit = () => {
    textEl.contentEditable = 'false';
    updateStickyNote(noteEl.dataset.id, { text: textEl.textContent });
    notifyStateChange();
  };
  textEl.addEventListener('blur', commit, { once: true });
  textEl.addEventListener('keydown', (e) => {
    e.stopPropagation();
    if (e.key === 'Escape') textEl.blur();
  });
}

export function editSelectedNote() {
  const container = getContainer();
  const state = getMoodBoardState();
  if (!container || !state.selectedId) return;
  const noteEl = container.querySelector(`[data-id="${state.selectedId}"][data-kind="note"]`);
  if (noteEl) enterNoteEditMode(noteEl);
}

function onDoubleClick(e) {
  const el = e.target.closest('[data-kind="note"]');
  if (!el) return;
  e.preventDefault();
  enterNoteEditMode(el);
}

let initialized = false;

export function initDynamicCanvas() {
  const container = getContainer();
  if (!container || initialized) return;
  initialized = true;
  container.addEventListener('pointerdown', onPointerDown);
  container.addEventListener('pointermove', onPointerMove);
  container.addEventListener('pointerup', onPointerUp);
  container.addEventListener('pointercancel', onPointerUp);
  container.addEventListener('keydown', onKeyDown);
  container.addEventListener('dblclick', onDoubleClick);
  container.addEventListener('focusin', onFocusIn);
  window.addEventListener('resize', () => renderDynamicCanvas());
}

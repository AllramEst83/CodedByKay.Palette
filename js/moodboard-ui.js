import { $, $$, refreshIcons } from './dom-utils.js';
import { getMoodBoardState } from './moodboard-state.js';

export function updateMoodBoardUI() {
  const state = getMoodBoardState();
  const list = $('#mb-thumbs-list');
  const countLabel = $('#mb-items-count');
  if (!list || !countLabel) return;
  countLabel.textContent = state.images.length;

  if (state.images.length === 0) {
    list.innerHTML = '<p class="text-xs text-slate-500 italic py-3">No images added yet. Add photos above.</p>';
    return;
  }

  list.innerHTML = '';
  state.images.forEach((item, index) => {
    const thumb = document.createElement('div');
    const selectedRing = item.selected ? ' ring-2 ring-indigo-500' : '';
    thumb.className = `relative flex-shrink-0 group w-16 h-16 rounded-xl overflow-hidden border border-slate-700 bg-slate-900 shadow-md cursor-pointer${selectedRing}`;
    thumb.setAttribute('role', 'button');
    thumb.setAttribute('tabindex', '0');
    thumb.setAttribute('aria-pressed', String(!!item.selected));
    thumb.setAttribute('aria-label', `${item.name || 'Mood board image'}${item.selected ? ' (selected)' : ''}`);
    thumb.dataset.action = 'select';
    thumb.dataset.id = item.id;
    thumb.innerHTML = `
      <img src="${item.src}" class="w-full h-full object-cover" alt="${item.name || 'Mood board image'}" />
      <div class="absolute inset-0 bg-slate-950/70 opacity-0 group-hover:opacity-100 focus-within:opacity-100 transition-opacity flex items-center justify-center gap-1">
        ${index > 0 ? `<button type="button" data-action="move-left" data-id="${item.id}" data-index="${index}" class="p-1 text-slate-300 hover:text-white" title="Move Left" aria-label="Move image left"><i data-lucide="chevron-left" class="w-3.5 h-3.5"></i></button>` : ''}
        <button type="button" data-action="remove" data-id="${item.id}" class="p-1 text-rose-400 hover:text-rose-300" title="Remove" aria-label="Remove image"><i data-lucide="x" class="w-3.5 h-3.5"></i></button>
        ${index < state.images.length - 1 ? `<button type="button" data-action="move-right" data-id="${item.id}" data-index="${index}" class="p-1 text-slate-300 hover:text-white" title="Move Right" aria-label="Move image right"><i data-lucide="chevron-right" class="w-3.5 h-3.5"></i></button>` : ''}
      </div>
    `;
    list.appendChild(thumb);
  });

  refreshIcons();
}

export function updateMbColumnButtons(cols) {
  $$('.mb-col-btn').forEach(btn => {
    const active = parseInt(btn.dataset.cols, 10) === cols;
    btn.className = active
      ? 'mb-col-btn py-1.5 rounded-lg font-medium transition-all text-white bg-indigo-600'
      : 'mb-col-btn py-1.5 rounded-lg font-medium transition-all text-slate-400 hover:text-slate-200';
    btn.setAttribute('aria-pressed', String(active));
  });
  const label = $('#mb-cols-label');
  if (label) label.textContent = `${cols} Cols`;
}

export function updateMbRatioButtons(ratio) {
  $$('.mb-ratio-btn').forEach(btn => {
    const active = btn.dataset.ratio === ratio;
    btn.className = active
      ? 'mb-ratio-btn py-1.5 rounded-lg font-medium transition-all text-white bg-indigo-600'
      : 'mb-ratio-btn py-1.5 rounded-lg font-medium transition-all text-slate-400 hover:text-slate-200';
    btn.setAttribute('aria-pressed', String(active));
  });
}

export function updateMbModeButtons(mode) {
  const gridBtn = $('#mb-mode-grid');
  const dynamicBtn = $('#mb-mode-dynamic');
  const activeClass = 'flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all text-white bg-indigo-600';
  const inactiveClass = 'flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all text-slate-400 hover:text-slate-200';
  if (gridBtn) {
    gridBtn.className = mode === 'grid' ? activeClass : inactiveClass;
    gridBtn.setAttribute('aria-pressed', String(mode === 'grid'));
  }
  if (dynamicBtn) {
    dynamicBtn.className = mode === 'dynamic' ? activeClass : inactiveClass;
    dynamicBtn.setAttribute('aria-pressed', String(mode === 'dynamic'));
  }
  $$('.mb-dynamic-only').forEach(el => el.classList.toggle('hidden', mode !== 'dynamic'));
  $$('.mb-grid-only').forEach(el => el.classList.toggle('hidden', mode === 'dynamic'));
}

export function updateExtractButtonState(hasSelection) {
  const btn = $('#btn-extract-selected');
  if (btn) btn.disabled = !hasSelection;
}

import { $, refreshIcons } from './dom-utils.js';
import { renderMoodBoard } from './moodboard.js';

let currentTab = 'palette';

export function getCurrentTab() {
  return currentTab;
}

export function switchTab(tab) {
  currentTab = tab;
  const paletteSec = $('#section-palette');
  const mbSec = $('#section-moodboard');
  const paletteTabBtn = $('#tab-palette');
  const mbTabBtn = $('#tab-moodboard');
  if (!paletteSec || !mbSec || !paletteTabBtn || !mbTabBtn) return;

  const activeClass = 'flex items-center gap-2 px-3.5 py-1.5 rounded-lg transition-all text-white bg-indigo-600 shadow-md';
  const inactiveClass = 'flex items-center gap-2 px-3.5 py-1.5 rounded-lg transition-all text-slate-400 hover:text-slate-200 hover:bg-slate-800/50';

  if (tab === 'palette') {
    paletteSec.classList.remove('hidden');
    mbSec.classList.add('hidden');
    paletteTabBtn.className = activeClass;
    mbTabBtn.className = inactiveClass;
  } else {
    paletteSec.classList.add('hidden');
    mbSec.classList.remove('hidden');
    mbTabBtn.className = activeClass;
    paletteTabBtn.className = inactiveClass;
    renderMoodBoard();
  }

  paletteTabBtn.setAttribute('aria-selected', String(tab === 'palette'));
  mbTabBtn.setAttribute('aria-selected', String(tab === 'moodboard'));
  paletteSec.toggleAttribute('hidden', tab !== 'palette');
  mbSec.toggleAttribute('hidden', tab !== 'moodboard');

  refreshIcons();
}

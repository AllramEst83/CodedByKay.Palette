import { logger } from './logger.js';

export const $ = (selector, root = document) => root.querySelector(selector);
export const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

let toastTimer = null;

export function refreshIcons() {
  if (window.lucide) window.lucide.createIcons();
}

export function showToast(message, isSuccess = true) {
  const toast = $('#toast');
  const toastMsg = $('#toast-msg');
  const toastIcon = $('#toast-icon');
  if (!toast || !toastMsg || !toastIcon) return;

  toastMsg.textContent = message;
  if (isSuccess) {
    toastIcon.className = 'p-1 rounded-lg bg-emerald-500/20 text-emerald-400';
    toastIcon.innerHTML = '<i data-lucide="check" class="w-4 h-4"></i>';
  } else {
    toastIcon.className = 'p-1 rounded-lg bg-amber-500/20 text-amber-400';
    toastIcon.innerHTML = '<i data-lucide="info" class="w-4 h-4"></i>';
  }
  refreshIcons();

  toast.classList.remove('translate-y-20', 'opacity-0', 'pointer-events-none');
  toast.classList.add('translate-y-0', 'opacity-100');

  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    toast.classList.remove('translate-y-0', 'opacity-100');
    toast.classList.add('translate-y-20', 'opacity-0', 'pointer-events-none');
  }, 2500);
}

export function copyToClipboard(text) {
  const helper = $('#clipboard-helper');
  if (!helper) return;
  helper.value = text;
  helper.select();
  helper.setSelectionRange(0, 99999);
  try {
    const success = document.execCommand('copy');
    showToast(success ? `Copied ${text} to clipboard!` : `Selected ${text}`);
  } catch (err) {
    logger.warn('clipboard', 'execCommand copy failed', err);
    showToast(`Selected ${text}`);
  }
}

export function reportError(scope, userMessage, err) {
  logger.error(scope, userMessage, err);
  showToast(userMessage, false);
}

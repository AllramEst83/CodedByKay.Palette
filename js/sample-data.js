import { showToast, reportError } from './dom-utils.js';
import { loadImageIntoPalette } from './palette.js';
import { addMoodBoardImage, clearMoodBoard } from './moodboard-state.js';
import { updateMoodBoardUI } from './moodboard-ui.js';
import { renderMoodBoard } from './moodboard.js';

export function createSampleImage(theme = 'sunset') {
  try {
    const canvas = document.createElement('canvas');
    canvas.width = 900;
    canvas.height = 600;
    const ctx = canvas.getContext('2d');

    if (theme === 'sunset') {
      const grad = ctx.createLinearGradient(0, 0, 0, 600);
      grad.addColorStop(0, '#fdba74');
      grad.addColorStop(0.3, '#f43f5e');
      grad.addColorStop(0.65, '#8b5cf6');
      grad.addColorStop(1, '#1e1b4b');
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, 900, 600);

      ctx.fillStyle = '#fef08a';
      ctx.beginPath();
      ctx.arc(450, 320, 110, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = '#312e81';
      ctx.beginPath();
      ctx.moveTo(0, 600);
      ctx.lineTo(200, 380);
      ctx.lineTo(400, 520);
      ctx.lineTo(650, 350);
      ctx.lineTo(900, 580);
      ctx.lineTo(900, 600);
      ctx.closePath();
      ctx.fill();

      ctx.fillStyle = '#0f172a';
      ctx.beginPath();
      ctx.moveTo(0, 600);
      ctx.lineTo(150, 480);
      ctx.lineTo(480, 560);
      ctx.lineTo(800, 470);
      ctx.lineTo(900, 600);
      ctx.closePath();
      ctx.fill();
    }

    const img = new Image();
    img.onload = () => {
      loadImageIntoPalette(img);
      showToast('Sample image loaded!');
    };
    img.onerror = (err) => reportError('sample-data', 'Could not build sample image', err);
    img.src = canvas.toDataURL();
  } catch (err) {
    reportError('sample-data', 'Could not build sample image', err);
  }
}

export function loadSampleMoodBoard() {
  const samples = [
    { color1: '#3b82f6', color2: '#1d4ed8', text: 'Azure Motion' },
    { color1: '#ec4899', color2: '#be185d', text: 'Neon Glow' },
    { color1: '#10b981', color2: '#047857', text: 'Botanical' },
    { color1: '#f59e0b', color2: '#b45309', text: 'Amber Dusk' },
    { color1: '#8b5cf6', color2: '#5b21b6', text: 'Velvet Horizon' },
    { color1: '#06b6d4', color2: '#0e7490', text: 'Cyan Tides' },
  ];

  clearMoodBoard();

  let loaded = 0;
  samples.forEach((sample, i) => {
    const c = document.createElement('canvas');
    c.width = 600;
    c.height = 600;
    const ctx = c.getContext('2d');

    const g = ctx.createLinearGradient(0, 0, 600, 600);
    g.addColorStop(0, sample.color1);
    g.addColorStop(1, sample.color2);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, 600, 600);

    ctx.fillStyle = 'rgba(255, 255, 255, 0.15)';
    ctx.beginPath();
    ctx.arc(300 + (i % 2 === 0 ? 80 : -80), 300, 180, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = 'rgba(0, 0, 0, 0.12)';
    ctx.beginPath();
    ctx.arc(300, 300, 90, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#ffffff';
    ctx.font = 'bold 32px "Plus Jakarta Sans", sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(sample.text, 300, 300);

    const img = new Image();
    img.onload = () => {
      addMoodBoardImage({ img, src: c.toDataURL(), name: sample.text });
      loaded++;
      if (loaded >= samples.length) {
        updateMoodBoardUI();
        renderMoodBoard();
        showToast('Sample mood board loaded!');
      }
    };
    img.onerror = (err) => reportError('sample-data', `Could not build sample "${sample.text}"`, err);
    img.src = c.toDataURL();
  });
}

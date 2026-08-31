import { rgbToHsl, hslToRgb, rgbToHex, getLuminance, clamp } from './color.js';

function buildSwatch(rgb, count) {
  return {
    r: rgb.r, g: rgb.g, b: rgb.b,
    hex: rgbToHex(rgb.r, rgb.g, rgb.b),
    hsl: rgbToHsl(rgb.r, rgb.g, rgb.b),
    luminance: getLuminance(rgb.r, rgb.g, rgb.b),
    count,
  };
}

const THEMES = {
  pastel: (hsl) => ({ h: hsl.h, s: clamp(hsl.s * 0.5, 20, 45), l: clamp(hsl.l * 0.4 + 60, 70, 92) }),
  neon: (hsl) => ({ h: hsl.h, s: clamp(hsl.s * 1.4 + 20, 85, 100), l: clamp(hsl.l, 45, 60) }),
  muted: (hsl) => ({ h: hsl.h, s: clamp(hsl.s * 0.35, 8, 30), l: hsl.l }),
  vivid: (hsl) => ({ h: hsl.h, s: clamp(hsl.s * 1.25, 70, 100), l: clamp(hsl.l, 40, 65) }),
  dark: (hsl) => ({ h: hsl.h, s: clamp(hsl.s * 1.1, hsl.s, 90), l: clamp(hsl.l * 0.45, 8, 35) }),
};

export const THEME_NAMES = Object.keys(THEMES);

export function applyTheme(colors, themeName) {
  const adjust = THEMES[themeName];
  if (!adjust) return colors;
  return colors.map(color => {
    const hsl = rgbToHsl(color.r, color.g, color.b);
    const next = adjust(hsl);
    const rgb = hslToRgb(next.h, next.s, next.l);
    return { ...buildSwatch(rgb, color.count) };
  });
}

const HARMONY_OFFSETS = {
  complementary: [0, 180],
  analogous: [-30, -15, 0, 15, 30],
  triadic: [0, 120, 240],
  tetradic: [0, 90, 180, 270],
};

export const HARMONY_NAMES = Object.keys(HARMONY_OFFSETS);

export function applyHarmony(colors, baseIndex, schemeName, count) {
  const offsets = HARMONY_OFFSETS[schemeName];
  if (!offsets || !colors.length) return colors;

  const base = colors[clamp(baseIndex, 0, colors.length - 1)];
  const baseHsl = rgbToHsl(base.r, base.g, base.b);
  const targetCount = count || colors.length;

  const swatches = offsets.map(offset => {
    const rgb = hslToRgb(baseHsl.h + offset, baseHsl.s, baseHsl.l);
    return buildSwatch(rgb, base.count ?? 1);
  });

  let padIndex = 0;
  while (swatches.length < targetCount) {
    const sourceOffset = offsets[padIndex % offsets.length];
    const shift = Math.floor(padIndex / offsets.length) % 2 === 0 ? 15 : -15;
    const l = clamp(baseHsl.l + shift, 10, 90);
    const rgb = hslToRgb(baseHsl.h + sourceOffset, baseHsl.s, l);
    swatches.push(buildSwatch(rgb, base.count ?? 1));
    padIndex++;
  }

  return swatches.slice(0, targetCount);
}

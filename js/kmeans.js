import { rgbToHex, rgbToHsl, getLuminance } from './color.js';

export function runKMeans(pixels, k, maxIterations = 10) {
  if (!pixels || pixels.length === 0) return [];
  if (pixels.length <= k) {
    return pixels.map(p => ({ r: p[0], g: p[1], b: p[2], count: 1 }));
  }

  const centroids = [];
  centroids.push(pixels[Math.floor(Math.random() * pixels.length)]);

  while (centroids.length < k) {
    const distances = [];
    let totalDistSq = 0;
    for (let i = 0; i < pixels.length; i++) {
      const p = pixels[i];
      let minDistSq = Infinity;
      for (let j = 0; j < centroids.length; j++) {
        const c = centroids[j];
        const distSq = (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2;
        if (distSq < minDistSq) minDistSq = distSq;
      }
      distances.push(minDistSq);
      totalDistSq += minDistSq;
    }

    let target = Math.random() * totalDistSq;
    let chosen = pixels[0];
    for (let i = 0; i < pixels.length; i++) {
      target -= distances[i];
      if (target <= 0) {
        chosen = pixels[i];
        break;
      }
    }
    centroids.push([...chosen]);
  }

  let clusters = Array.from({ length: k }, () => []);

  for (let iter = 0; iter < maxIterations; iter++) {
    clusters = Array.from({ length: k }, () => []);

    for (let i = 0; i < pixels.length; i++) {
      const p = pixels[i];
      let bestIndex = 0;
      let bestDistSq = Infinity;
      for (let j = 0; j < k; j++) {
        const c = centroids[j];
        const distSq = (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2;
        if (distSq < bestDistSq) {
          bestDistSq = distSq;
          bestIndex = j;
        }
      }
      clusters[bestIndex].push(p);
    }

    let maxMovement = 0;
    for (let j = 0; j < k; j++) {
      const cluster = clusters[j];
      if (cluster.length === 0) continue;
      let sumR = 0, sumG = 0, sumB = 0;
      for (let i = 0; i < cluster.length; i++) {
        sumR += cluster[i][0];
        sumG += cluster[i][1];
        sumB += cluster[i][2];
      }
      const newCentroid = [sumR / cluster.length, sumG / cluster.length, sumB / cluster.length];
      const movement = Math.abs(centroids[j][0] - newCentroid[0]) +
        Math.abs(centroids[j][1] - newCentroid[1]) +
        Math.abs(centroids[j][2] - newCentroid[2]);
      if (movement > maxMovement) maxMovement = movement;
      centroids[j] = newCentroid;
    }

    if (maxMovement < 1.0) break;
  }

  return centroids.map((c, index) => {
    const count = clusters[index].length;
    const r = Math.round(c[0]);
    const g = Math.round(c[1]);
    const b = Math.round(c[2]);
    const hex = rgbToHex(r, g, b);
    const hsl = rgbToHsl(r, g, b);
    const luminance = getLuminance(r, g, b);
    return { r, g, b, hex, hsl, luminance, count };
  });
}

export function sortPalette(colors, mode) {
  const copy = [...colors];
  if (mode === 'prominence') {
    copy.sort((a, b) => b.count - a.count);
  } else if (mode === 'luminance') {
    copy.sort((a, b) => a.luminance - b.luminance);
  } else if (mode === 'hue') {
    copy.sort((a, b) => a.hsl.h - b.hsl.h);
  }
  return copy;
}

export function extractImagePalette(imgElement, kCount, sortMode = 'prominence') {
  const sampleCanvas = document.createElement('canvas');
  const ctx = sampleCanvas.getContext('2d');
  const maxDim = 120;
  let w = imgElement.naturalWidth || imgElement.width;
  let h = imgElement.naturalHeight || imgElement.height;
  if (w > h) {
    if (w > maxDim) {
      h = Math.round((h * maxDim) / w);
      w = maxDim;
    }
  } else if (h > maxDim) {
    w = Math.round((w * maxDim) / h);
    h = maxDim;
  }

  sampleCanvas.width = w;
  sampleCanvas.height = h;
  ctx.drawImage(imgElement, 0, 0, w, h);

  const imageData = ctx.getImageData(0, 0, w, h).data;
  const pixelArray = [];

  for (let i = 0; i < imageData.length; i += 4) {
    const a = imageData[i + 3];
    if (a > 128) {
      pixelArray.push([imageData[i], imageData[i + 1], imageData[i + 2]]);
    }
  }

  const palette = runKMeans(pixelArray, kCount, 8);
  return sortPalette(palette, sortMode);
}

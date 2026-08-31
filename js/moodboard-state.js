export const DYNAMIC_CANVAS_W = 1600;
export const DYNAMIC_CANVAS_H = 1000;

const state = {
  images: [],
  stickyNotes: [],
  swatchGroups: [],
  mode: 'grid',
  columns: 3,
  gutter: 16,
  padding: 24,
  radius: 12,
  ratio: '1:1',
  bgColor: '#0f172a',
  selectedId: null,
  zCounter: 1,
  boardOrderCounter: 1,
};

export function getMoodBoardState() {
  return state;
}

export function applyMoodBoardSettings(settings = {}) {
  Object.assign(state, settings);
}

export function setMbMode(mode) { state.mode = mode; }
export function setMbColumns(cols) { state.columns = cols; }
export function setMbGutter(px) { state.gutter = px; }
export function setMbPadding(px) { state.padding = px; }
export function setMbRadius(px) { state.radius = px; }
export function setMbRatio(ratio) { state.ratio = ratio; }
export function setMbBg(color) { state.bgColor = color; }

function randomId(prefix) {
  return `${prefix}_${Math.random().toString(36).slice(2, 9)}`;
}

function cascadePosition(index) {
  const cols = 4;
  const cellW = 260, cellH = 200;
  const col = index % cols;
  const row = Math.floor(index / cols);
  return {
    x: 60 + col * (cellW + 24),
    y: 60 + row * (cellH + 24),
    w: cellW,
    h: cellH,
  };
}

export function addMoodBoardImage({ img, src, name }) {
  const pos = cascadePosition(state.images.length + state.stickyNotes.length + state.swatchGroups.length);
  const item = {
    id: randomId('mb'), img, src, name,
    x: pos.x, y: pos.y, w: pos.w, h: pos.h,
    rotation: 0, zIndex: state.zCounter++, order: state.boardOrderCounter++, selected: false,
  };
  state.images.push(item);
  return item;
}

export function hydrateMoodBoardImage(data) {
  const item = { ...data, selected: false };
  if (item.order === undefined) item.order = state.boardOrderCounter;
  state.images.push(item);
  state.zCounter = Math.max(state.zCounter, (data.zIndex || 0) + 1);
  state.boardOrderCounter = Math.max(state.boardOrderCounter, item.order + 1);
  return item;
}

export function hydrateStickyNote(data) {
  const note = { ...data, selected: false };
  state.stickyNotes.push(note);
  state.zCounter = Math.max(state.zCounter, (data.zIndex || 0) + 1);
  return note;
}

export function removeMoodBoardImage(id) {
  state.images = state.images.filter(item => item.id !== id);
  if (state.selectedId === id) state.selectedId = null;
}

// Images and swatch groups share one ordering (via each item's `order` field)
// so the Board Items strip and grid layout can freely interleave both kinds.
export function getBoardItems() {
  return [
    ...state.images.map(item => ({ ...item, kind: 'image' })),
    ...state.swatchGroups.map(group => ({ ...group, kind: 'swatch-group' })),
  ].sort((a, b) => a.order - b.order);
}

function findOrderedRef(id, kind) {
  return kind === 'image'
    ? state.images.find(i => i.id === id)
    : state.swatchGroups.find(g => g.id === id);
}

export function moveBoardItem(id, direction) {
  const combined = getBoardItems();
  const index = combined.findIndex(item => item.id === id);
  if (index === -1) return;
  const targetIndex = index + direction;
  if (targetIndex < 0 || targetIndex >= combined.length) return;

  const a = combined[index];
  const b = combined[targetIndex];
  const aRef = findOrderedRef(a.id, a.kind);
  const bRef = findOrderedRef(b.id, b.kind);
  if (!aRef || !bRef) return;
  [aRef.order, bRef.order] = [bRef.order, aRef.order];
}

export function clearMoodBoard() {
  state.images = [];
  state.stickyNotes = [];
  state.swatchGroups = [];
  state.selectedId = null;
}

export function addStickyNote(position = {}) {
  const index = state.images.length + state.stickyNotes.length + state.swatchGroups.length;
  const fallback = cascadePosition(index);
  const note = {
    id: randomId('note'), text: 'New note',
    x: position.x ?? fallback.x, y: position.y ?? fallback.y,
    w: 180, h: 180,
    rotation: 0, zIndex: state.zCounter++,
    color: '#fef08a', textColor: '#1c1917', selected: false,
  };
  state.stickyNotes.push(note);
  return note;
}

export function updateStickyNote(id, patch) {
  const note = state.stickyNotes.find(n => n.id === id);
  if (note) Object.assign(note, patch);
  return note;
}

export function removeStickyNote(id) {
  state.stickyNotes = state.stickyNotes.filter(n => n.id !== id);
  if (state.selectedId === id) state.selectedId = null;
}

export function addSwatchGroup({ colors, sourceName, x, y, w, h }) {
  const group = {
    id: randomId('swatch'), colors, sourceName,
    x, y, w, h, rotation: 0, zIndex: state.zCounter++, order: state.boardOrderCounter++, selected: false,
  };
  state.swatchGroups.push(group);
  return group;
}

export function hydrateSwatchGroup(data) {
  const group = { ...data, selected: false };
  if (group.order === undefined) group.order = state.boardOrderCounter;
  state.swatchGroups.push(group);
  state.zCounter = Math.max(state.zCounter, (data.zIndex || 0) + 1);
  state.boardOrderCounter = Math.max(state.boardOrderCounter, group.order + 1);
  return group;
}

export function removeSwatchGroup(id) {
  state.swatchGroups = state.swatchGroups.filter(g => g.id !== id);
  if (state.selectedId === id) state.selectedId = null;
}

export function findMoodBoardItem(id) {
  return state.images.find(i => i.id === id)
    || state.stickyNotes.find(n => n.id === id)
    || state.swatchGroups.find(g => g.id === id)
    || null;
}

export function selectMoodBoardItem(id) {
  state.images.forEach(item => { item.selected = item.id === id; });
  state.stickyNotes.forEach(note => { note.selected = note.id === id; });
  state.swatchGroups.forEach(group => { group.selected = group.id === id; });
  state.selectedId = id;
}

export function clearMoodBoardSelection() {
  state.images.forEach(item => { item.selected = false; });
  state.stickyNotes.forEach(note => { note.selected = false; });
  state.swatchGroups.forEach(group => { group.selected = false; });
  state.selectedId = null;
}

export function getSelectedImage() {
  return state.images.find(item => item.id === state.selectedId) || null;
}

export function bringToFront(id) {
  const item = findMoodBoardItem(id);
  if (item) item.zIndex = ++state.zCounter;
  return item ? item.zIndex : null;
}

export function updateItemPosition(id, patch) {
  const item = findMoodBoardItem(id);
  if (item) Object.assign(item, patch);
  return item;
}

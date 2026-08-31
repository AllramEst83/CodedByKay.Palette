const LEVELS = { debug: 0, info: 1, warn: 2, error: 3 };

const params = new URLSearchParams(window.location.search);
let minLevel = params.get('debug') === '1' ? 'debug' : 'info';

export function setLogLevel(level) {
  if (LEVELS[level] !== undefined) minLevel = level;
}

function log(level, scope, message, data) {
  if (LEVELS[level] < LEVELS[minLevel]) return;
  const prefix = `[${scope}]`;
  if (data && data.length) {
    console[level](prefix, message, ...data);
  } else {
    console[level](prefix, message);
  }
}

export const logger = {
  debug: (scope, message, ...data) => log('debug', scope, message, data),
  info: (scope, message, ...data) => log('info', scope, message, data),
  warn: (scope, message, ...data) => log('warn', scope, message, data),
  error: (scope, message, ...data) => log('error', scope, message, data),
};

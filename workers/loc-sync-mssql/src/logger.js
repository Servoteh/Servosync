/**
 * Minimalistički structured logger. Ne donosi zavisnosti — samo JSON na stdout.
 * Na produkciji se log agregira (Loki, Datadog, CloudWatch itd.) po `service` polju.
 */

const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };

export function createLogger(level = 'info', service = 'loc-sync-mssql') {
  const min = LEVELS[level] ?? LEVELS.info;
  const log = (lvl, msg, extra) => {
    if (LEVELS[lvl] < min) return;
    const entry = {
      ts: new Date().toISOString(),
      level: lvl,
      service,
      msg,
      ...(extra && typeof extra === 'object' ? extra : {}),
    };
    const line = JSON.stringify(entry);
    if (lvl === 'error' || lvl === 'warn') process.stderr.write(line + '\n');
    else process.stdout.write(line + '\n');
  };
  return {
    debug: (msg, extra) => log('debug', msg, extra),
    info: (msg, extra) => log('info', msg, extra),
    warn: (msg, extra) => log('warn', msg, extra),
    error: (msg, extra) => log('error', msg, extra),
  };
}

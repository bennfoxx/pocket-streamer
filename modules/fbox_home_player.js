/* ============================================================================
 * fbox OS — Home Launcher, Now Playing, Output & Lock Module
 * Target: 1.91" RM67162 True-Black AMOLED (536 x 240 px)
 * Design: Minimalist True-Black AMOLED + Bright Solid Circular Widgets +
 *         Lava-Lamp Metaballs + Underdamped Bouncy Spring Physics
 * Self-contained browser <script> IIFE (file:// safe, no ES import/export)
 * ========================================================================== */
(function (global) {
  'use strict';

  var WIDTH = 536;
  var HEIGHT = 240;

  var FONT_SANS = "'SF Pro Text', 'Inter', ui-sans-serif, system-ui, -apple-system, sans-serif";
  var FONT_MONO = "'SF Mono', 'JetBrains Mono', ui-monospace, Menlo, monospace";

  var COLORS = {
    bg: '#000000',
    trackBg: '#1C2430',
    textPrimary: '#FFFFFF',
    textSecondary: '#94A3B8',
    textDark: '#000000',
    amber: '#E3A84B',
    teal: '#45B09C',
    gold: '#EBD15E',
    coral: '#E0634E',
    coralGlow: '#FB7185',
    btCyan: '#38BDF8',
  };

  var SPEEDS = [1.0, 1.15, 1.25, 1.5, 2.0];

  var ABS_BOOKS = [
    {
      title: 'Project Hail Mary',
      author: 'Andy Weir',
      narrator: 'Ray Porter',
      palette: ['#131B2E', '#E0634E', '#E3A84B'],
      artType: 'nebula',
      progressPct: 28,
      chapters: [
        { num: 1, title: 'Waking Up', durationSec: 1980 },
        { num: 2, title: 'Zero-G Lab', durationSec: 2460 },
        { num: 3, title: 'Tau Ceti Signal', durationSec: 2790 },
        { num: 4, title: 'Rocky', durationSec: 3420 },
        { num: 5, title: 'Eridian Math', durationSec: 2640 },
        { num: 6, title: 'Xenonite Hull', durationSec: 2880 },
        { num: 7, title: 'Airlock Handshake', durationSec: 2510 },
        { num: 8, title: 'Astrophage Sample', durationSec: 3120 },
        { num: 9, title: 'Adrian Descent', durationSec: 3360 },
        { num: 10, title: 'Chain Reaction', durationSec: 2940 },
        { num: 11, title: 'Beetle Prep', durationSec: 2400 },
        { num: 12, title: 'Taumoeba Harvest', durationSec: 3080 },
        { num: 13, title: 'Fuel Leak', durationSec: 2750 },
        { num: 14, title: 'The Choice', durationSec: 3240 },
        { num: 15, title: 'Return Trajectory', durationSec: 2890 },
        { num: 16, title: 'Eridian Sun', durationSec: 3510 },
      ],
    },
    {
      title: 'Dungeon Crawler Carl',
      author: 'Matt Dinniman',
      narrator: 'Jeff Hays',
      palette: ['#2E0854', '#DB2777', '#EBD15E'],
      artType: 'dungeon',
      progressPct: 64,
      chapters: [
        { num: 1, title: 'Collapse', durationSec: 2120 },
        { num: 2, title: 'Welcome Crawler', durationSec: 2340 },
        { num: 3, title: 'Princess Donut', durationSec: 2580 },
        { num: 4, title: 'Goblin Loot', durationSec: 2410 },
        { num: 5, title: 'First Boss', durationSec: 2760 },
        { num: 6, title: 'Achievement Unlocked', durationSec: 2290 },
        { num: 7, title: 'The Desperado', durationSec: 2640 },
        { num: 8, title: 'Floor Two Descent', durationSec: 2820 },
        { num: 9, title: 'Juicer Encounter', durationSec: 2510 },
        { num: 10, title: 'Guild Hall', durationSec: 2460 },
        { num: 11, title: 'Bomb Squad', durationSec: 2690 },
        { num: 12, title: 'Safe Room', durationSec: 2940 },
        { num: 13, title: 'Krakkaren Plot', durationSec: 3110 },
        { num: 14, title: 'Stairwell Sprint', durationSec: 2870 },
      ],
    },
    {
      title: 'The Creative Act',
      author: 'Rick Rubin',
      narrator: 'Rick Rubin',
      palette: ['#18181B', '#475569', '#EBD15E'],
      artType: 'monolith',
      progressPct: 45,
      chapters: [
        { num: 1, title: 'Everyone Is a Creator', durationSec: 1420 },
        { num: 2, title: 'Tuning In', durationSec: 1680 },
        { num: 3, title: 'The Source', durationSec: 1540 },
        { num: 4, title: 'Awareness', durationSec: 1810 },
        { num: 5, title: 'Vessel and Filter', durationSec: 1620 },
        { num: 6, title: 'The Unseen', durationSec: 1490 },
        { num: 7, title: 'Look for Clues', durationSec: 1750 },
        { num: 8, title: 'Practice', durationSec: 1580 },
        { num: 9, title: 'Inspiration', durationSec: 1920 },
        { num: 10, title: 'Submerge', durationSec: 1840 },
      ],
    },
    {
      title: 'Chip War',
      author: 'Chris Miller',
      narrator: 'Stephen Gray',
      palette: ['#0B1528', '#38BDF8', '#45B09C'],
      artType: 'wafer',
      progressPct: 18,
      chapters: [
        { num: 1, title: 'From Sand to Silicon', durationSec: 2210 },
        { num: 2, title: 'The Switch', durationSec: 2480 },
        { num: 3, title: 'Noyce and Kilby', durationSec: 2640 },
        { num: 4, title: 'Lift-Off', durationSec: 2390 },
        { num: 5, title: 'Mass Production', durationSec: 2550 },
        { num: 6, title: "Moore's Law", durationSec: 2890 },
        { num: 7, title: 'Japanese Rise', durationSec: 2720 },
        { num: 8, title: 'EUV Lithography', durationSec: 3150 },
        { num: 9, title: 'TSMC Foundry Model', durationSec: 2960 },
        { num: 10, title: 'Silicon Chokepoint', durationSec: 3280 },
      ],
    },
  ];

  var SPOTIFY_TRACKS = [
    {
      title: 'Resonance (Lo-Fi Edit)',
      artist: 'HOME',
      playlist: 'Deep Study Focus',
      durationSec: 236,
      liked: true,
      palette: ['#0E2429', '#45B09C', '#38BDF8'],
      artType: 'synthwave',
    },
    {
      title: 'Midnight City (Synth Mix)',
      artist: 'M83',
      playlist: 'Night Drive',
      durationSec: 244,
      liked: true,
      palette: ['#1D163B', '#E0634E', '#E3A84B'],
      artType: 'skyline',
    },
    {
      title: 'Nardis (Live)',
      artist: 'Bill Evans Trio',
      playlist: 'Late Jazz',
      durationSec: 348,
      liked: false,
      palette: ['#18181B', '#E3A84B', '#EBD15E'],
      artType: 'vinyl',
    },
    {
      title: 'Weightless',
      artist: 'Marconi Union',
      playlist: 'Focus',
      durationSec: 486,
      liked: true,
      palette: ['#091B29', '#38BDF8', '#45B09C'],
      artType: 'waves',
    },
  ];

  var SD_FILES = [
    {
      title: 'Stanford CS229 Lecture 04.mp3',
      folder: '/LECTURES',
      format: 'MP3',
      bitrate: '192 kbps',
      durationSec: 4680,
      palette: ['#161F33', '#E3A84B', '#E0634E'],
      artType: 'lecture',
    },
    {
      title: 'Design Systems Deep Dive.mp3',
      folder: '/PODCASTS',
      format: 'MP3',
      bitrate: '256 kbps',
      durationSec: 2740,
      palette: ['#0F2421', '#45B09C', '#EBD15E'],
      artType: 'waveform',
    },
    {
      title: 'Chopin Nocturnes Op.9.flac',
      folder: '/MUSIC',
      format: 'FLAC',
      bitrate: '960 kbps',
      durationSec: 1840,
      palette: ['#1B1830', '#38BDF8', '#EBD15E'],
      artType: 'vinyl',
    },
    {
      title: 'Field_Rain_24bit.wav',
      folder: '/AMBIENT',
      format: 'WAV',
      bitrate: '2116 kbps',
      durationSec: 3600,
      palette: ['#091A24', '#45B09C', '#38BDF8'],
      artType: 'rain',
    },
  ];

  var SOURCE_META = {
    ABS: {
      sourceLabel: 'AUDIOBOOKSHELF',
      shortCode: 'ABS',
      badgeColor: COLORS.amber,
    },
    SPOTIFY: {
      sourceLabel: 'SPOTIFY',
      shortCode: 'SPT',
      badgeColor: COLORS.teal,
    },
    MICROSD: {
      sourceLabel: 'MICROSD',
      shortCode: 'SD',
      badgeColor: COLORS.gold,
    },
  };

  var LAUNCHER_ITEMS = [
    { label: 'Books', color: COLORS.amber, source: 'ABS' },
    { label: 'Music', color: COLORS.teal, source: 'SPOTIFY' },
    { label: 'Files', color: COLORS.gold, source: 'MICROSD' },
    { label: 'Voice', color: COLORS.coral, source: null },
  ];

  var LAUNCHER_CX = [86, 207, 329, 450];
  var LAUNCHER_CY = 104;

  var _lastHitboxes = [];

  // ---------------------------------------------------------------------------
  // Physics & Lava-Lamp State
  // ---------------------------------------------------------------------------

  var _bounceSprings = {};
  var _lastTickMs = 0;

  var _prevLauncherIdx = null;
  var _lavaTargetIdx = null;
  var _lavaAnim = 1;
  var _lavaArrivedBounced = true;
  var _launcherRadii = null;

  var _npLavaFrom = null;
  var _npLavaColor = COLORS.gold;
  var _npLavaAnim = 1;
  var _npPrevPlay = null;
  var _npPrevSpeedIdx = null;

  var _sysPrevBtOn = null;
  var _sysFromBt = false;
  var _outputLavaAnim = 1;

  var _lastBtState = null;
  var _lastScreenKey = null;
  var _lastLockFlashUntil = 0;
  var _lockWobbleSpring = { val: 0, vel: 0, target: 0, stiffness: 360, damping: 12 };

  // ---------------------------------------------------------------------------
  // Utility & Color Helpers
  // ---------------------------------------------------------------------------

  function clamp(val, min, max) {
    return val < min ? min : val > max ? max : val;
  }

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }

  function smoothstep(edge0, edge1, x) {
    var t = clamp((x - edge0) / (edge1 - edge0 || 1), 0, 1);
    return t * t * (3 - 2 * t);
  }

  function easeInOutCubic(t) {
    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) * 0.5;
  }

  function wrapIndex(idx, len) {
    if (!len) return 0;
    var n = Number(idx) || 0;
    return ((n % len) + len) % len;
  }

  function parseHexRgb(hex) {
    if (!hex || typeof hex !== 'string' || hex.charAt(0) !== '#') {
      return [255, 255, 255];
    }
    var clean = hex.slice(1);
    if (clean.length === 3) {
      clean = clean[0] + clean[0] + clean[1] + clean[1] + clean[2] + clean[2];
    }
    var num = parseInt(clean, 16);
    if (isNaN(num)) return [255, 255, 255];
    return [(num >> 16) & 255, (num >> 8) & 255, num & 255];
  }

  function hexToRgba(hex, alpha) {
    var rgb = parseHexRgb(hex);
    return 'rgba(' + rgb[0] + ', ' + rgb[1] + ', ' + rgb[2] + ', ' + alpha + ')';
  }

  function blendHex(hexA, hexB, t) {
    var a = parseHexRgb(hexA);
    var b = parseHexRgb(hexB);
    var u = clamp(t, 0, 1);
    var r = Math.round(lerp(a[0], b[0], u));
    var g = Math.round(lerp(a[1], b[1], u));
    var bl = Math.round(lerp(a[2], b[2], u));
    return 'rgb(' + r + ', ' + g + ', ' + bl + ')';
  }

  function fmtTime(totalSec) {
    var sec = Math.max(0, Math.floor(Number(totalSec) || 0));
    var h = Math.floor(sec / 3600);
    var m = Math.floor((sec % 3600) / 60);
    var s = sec % 60;
    var mm = m < 10 ? '0' + m : '' + m;
    var ss = s < 10 ? '0' + s : '' + s;
    return h > 0 ? h + ':' + mm + ':' + ss : mm + ':' + ss;
  }

  function fmtSpeed(speed) {
    var s = Number(speed) || 1.0;
    return (s % 1 === 0 ? s.toFixed(1) : String(s)) + 'x';
  }

  function roundRectPath(ctx, x, y, w, h, r) {
    var radius = Math.min(r || 0, Math.abs(w) * 0.5, Math.abs(h) * 0.5);
    ctx.beginPath();
    if (typeof ctx.roundRect === 'function') {
      ctx.roundRect(x, y, w, h, radius);
      return;
    }
    ctx.moveTo(x + radius, y);
    ctx.arcTo(x + w, y, x + w, y + h, radius);
    ctx.arcTo(x + w, y + h, x, y + h, radius);
    ctx.arcTo(x, y + h, x, y, radius);
    ctx.arcTo(x, y, x + w, y, radius);
    ctx.closePath();
  }

  function truncateText(ctx, text, maxWidth, helpers) {
    if (helpers && typeof helpers.truncateText === 'function') {
      return helpers.truncateText(ctx, text, maxWidth);
    }
    var str = String(text == null ? '' : text);
    if (maxWidth <= 8) return '';
    if (ctx.measureText(str).width <= maxWidth) return str;
    var out = str;
    while (out.length > 1 && ctx.measureText(out + '…').width > maxWidth) {
      out = out.slice(0, -1);
    }
    return out + '…';
  }

  function formatTimeWithHelpers(sec, helpers) {
    if (helpers && typeof helpers.fmtTime === 'function') {
      return helpers.fmtTime(sec);
    }
    return fmtTime(sec);
  }

  function recordHitbox(helpers, box) {
    _lastHitboxes.push(box);
    if (helpers) {
      if (typeof helpers.registerHitbox === 'function') {
        helpers.registerHitbox(box);
      } else if (Array.isArray(helpers.hitboxes)) {
        helpers.hitboxes.push(box);
      }
    }
  }

  function resetHitboxes(helpers) {
    _lastHitboxes = [];
    if (helpers && Array.isArray(helpers.hitboxes)) {
      helpers.hitboxes.length = 0;
    }
  }

  function setToast(state, text, color, durationMs) {
    if (!state) return;
    state.toast = {
      text: text,
      color: color || COLORS.gold,
      until: Date.now() + (durationMs || 1800),
    };
  }

  function getActiveSource(state) {
    var raw = String((state && state.activeSource) || 'ABS').toUpperCase();
    if (raw === 'SPOTIFY' || raw === 'MICROSD' || raw === 'ABS') return raw;
    if (raw === 'SPT') return 'SPOTIFY';
    if (raw === 'SD') return 'MICROSD';
    return 'ABS';
  }

  function getPhase(state) {
    if (state && typeof state.phase === 'number' && isFinite(state.phase)) {
      return state.phase;
    }
    return Date.now() / 1000;
  }

  function normalizeScreenName(scr) {
    var u = String(scr || 'NOW_PLAYING').toUpperCase();
    if (u === 'HOME') return 'HOME_LAUNCHER';
    if (u === 'AI' || u === 'VOICE' || u === 'AI_VOICE' || u === 'GEMINI' || u === 'GEMINI_PTT') return 'VOICE_AI';
    if (u === 'SYSTEM' || u === 'OUTPUT' || u === 'STATUS' || u === 'STATUS_POWER' || u === 'TARGET_PICKER') return 'SYSTEM_OUTPUT';
    if (u === 'LIBRARY_BROWSE') return 'LIBRARY_BROWSER';
    if (u === 'LOCK') return 'POCKET_LOCK';
    return u;
  }

  // ---------------------------------------------------------------------------
  // Spring Physics & Lava-Lamp Engine
  // ---------------------------------------------------------------------------

  function stepSpring(springObj, dtSec) {
    if (!springObj || typeof springObj !== 'object') return 0;
    var dt = Number(dtSec);
    if (!isFinite(dt) || dt <= 0) dt = 0.016;
    if (dt > 0.04) dt = 0.04;

    var val = Number(springObj.val);
    var vel = Number(springObj.vel);
    var target = Number(springObj.target);
    if (!isFinite(val)) val = 0;
    if (!isFinite(vel)) vel = 0;
    if (!isFinite(target)) target = 0;

    var stiffness = (springObj.stiffness != null && isFinite(Number(springObj.stiffness)))
      ? Number(springObj.stiffness) : 220;
    var damping = (springObj.damping != null && isFinite(Number(springObj.damping)))
      ? Number(springObj.damping) : 16;

    var subSteps = dt > 0.02 ? 2 : 1;
    var h = dt / subSteps;
    for (var i = 0; i < subSteps; i++) {
      var force = (target - val) * stiffness;
      var accel = force - vel * damping;
      vel += accel * h;
      val += vel * h;
    }

    if (Math.abs(target - val) < 0.0005 && Math.abs(vel) < 0.0005) {
      val = target;
      vel = 0;
    }

    springObj.val = val;
    springObj.vel = vel;
    return val;
  }

  function triggerBounce(name, impulseVel) {
    var key = String(name || 'global');
    var isLauncher = key.indexOf('launcher_') === 0;
    if (!_bounceSprings[key]) {
      _bounceSprings[key] = {
        val: 0,
        vel: 0,
        target: 0,
        stiffness: isLauncher ? 170 : 220,
        damping: isLauncher ? 14 : 16,
      };
    }
    var vel = (impulseVel != null && isFinite(Number(impulseVel))) ? Number(impulseVel) : 4.2;
    var maxVel = isLauncher ? 4.8 : 9.0;
    _bounceSprings[key].vel = clamp(_bounceSprings[key].vel + vel, -maxVel, maxVel);
    return _bounceSprings[key];
  }

  function getBounceVal(name) {
    var sp = _bounceSprings[String(name || '')];
    return sp ? sp.val : 0;
  }

  function applySquashStretch(ctx, cx, cy, bounceVal) {
    var b = clamp(Number(bounceVal) || 0, -0.26, 0.34);
    if (Math.abs(b) < 0.001) return;
    var scaleX = 1 + b;
    var scaleY = 1 / (1 + b * 0.65);
    ctx.translate(cx, cy);
    ctx.scale(scaleX, scaleY);
    ctx.translate(-cx, -cy);
  }

  function tickInternalAnimations(state) {
    var nowMs = (typeof performance !== 'undefined' && typeof performance.now === 'function')
      ? performance.now()
      : Date.now();
    var dtSec;
    if (_lastTickMs === 0) {
      dtSec = 0.016;
      _lastTickMs = nowMs;
    } else {
      var rawDt = (nowMs - _lastTickMs) / 1000;
      if (rawDt <= 0.0002) {
        return;
      }
      dtSec = clamp(rawDt, 0.0005, 0.04);
      _lastTickMs = nowMs;
    }

    var keys = Object.keys(_bounceSprings);
    for (var i = 0; i < keys.length; i++) {
      stepSpring(_bounceSprings[keys[i]], dtSec);
    }
    stepSpring(_lockWobbleSpring, dtSec);

    if (_lavaAnim < 1) {
      _lavaAnim = Math.min(1, _lavaAnim + dtSec / 0.85);
      if (_lavaAnim >= 0.88 && !_lavaArrivedBounced && _lavaTargetIdx != null) {
        _lavaArrivedBounced = true;
        triggerBounce('launcher_' + _lavaTargetIdx, 1.6);
      }
    }

    if (_launcherRadii && _lavaTargetIdx != null) {
      var radLerp = clamp(dtSec * 5.2, 0.01, 0.35);
      for (var ri = 0; ri < 4; ri++) {
        var targetR = ri === _lavaTargetIdx ? 45 : 31;
        _launcherRadii[ri] = lerp(_launcherRadii[ri], targetR, radLerp);
      }
    }

    if (_npLavaAnim < 1) {
      _npLavaAnim = Math.min(1, _npLavaAnim + dtSec / 0.28);
    }

    if (_outputLavaAnim < 1) {
      _outputLavaAnim = Math.min(1, _outputLavaAnim + dtSec / 0.34);
    }

    if (state) {
      var btNow = !!state.btTxOn;
      if (_lastBtState !== null && _lastBtState !== btNow) {
        triggerBounce('top_output', 5.8);
        triggerBounce('np_output', 6.2);
        _npLavaFrom = 'output';
        _npLavaColor = btNow ? COLORS.btCyan : COLORS.teal;
        _npLavaAnim = 0;
      }
      _lastBtState = btNow;

      var scrNow = normalizeScreenName(state.screen);
      if (_lastScreenKey !== null && _lastScreenKey !== scrNow) {
        triggerBounce('top_home', 5.0);
        triggerBounce('screen_enter', 5.4);
      }
      _lastScreenKey = scrNow;
    }
  }

  function makeLavaFill(ctx, x1, y1, x2, y2, color1, color2) {
    var c1 = color1 || COLORS.amber;
    var c2 = color2 || c1;
    if (typeof ctx.createLinearGradient === 'function') {
      var grad = ctx.createLinearGradient(x1, y1, x2, y2);
      grad.addColorStop(0, c1);
      grad.addColorStop(0.5, blendHex(c1, c2, 0.5));
      grad.addColorStop(1, c2);
      return grad;
    }
    return blendHex(c1, c2, 0.5);
  }

  function traceMetaballConnector(ctx, c1x, c1y, r1, c2x, c2y, r2, spread, handleRate) {
    var dx = c2x - c1x;
    var dy = c2y - c1y;
    var d = Math.hypot(dx, dy);
    if (d <= Math.abs(r1 - r2) + 0.5 || d < 0.5) return false;

    var maxDist = (r1 + r2) * 2.9;
    if (d > maxDist) return false;

    var v = clamp(spread == null ? 0.52 : spread, 0.2, 1.05);
    var angle1 = Math.atan2(dy, dx);
    var u1 = 0;
    var u2 = 0;
    if (d < r1 + r2) {
      u1 = Math.acos(clamp((r1 * r1 + d * d - r2 * r2) / (2 * r1 * d), -1, 1));
      u2 = Math.acos(clamp((r2 * r2 + d * d - r1 * r1) / (2 * r2 * d), -1, 1));
    }

    var angle2 = Math.acos(clamp((r1 - r2) / d, -1, 1));
    var angle1a = angle1 + u1 + (angle2 - u1) * v;
    var angle1b = angle1 - u1 - (angle2 - u1) * v;
    var angle2a = angle1 + Math.PI - u2 - (Math.PI - u2 - angle2) * v;
    var angle2b = angle1 - Math.PI + u2 + (Math.PI - u2 - angle2) * v;

    var p1ax = c1x + Math.cos(angle1a) * r1;
    var p1ay = c1y + Math.sin(angle1a) * r1;
    var p1bx = c1x + Math.cos(angle1b) * r1;
    var p1by = c1y + Math.sin(angle1b) * r1;
    var p2ax = c2x + Math.cos(angle2a) * r2;
    var p2ay = c2y + Math.sin(angle2a) * r2;
    var p2bx = c2x + Math.cos(angle2b) * r2;
    var p2by = c2y + Math.sin(angle2b) * r2;

    var totalRadius = r1 + r2;
    var chordDist = Math.hypot(p1ax - p2ax, p1ay - p2ay);
    var d2 = Math.min(v * (handleRate || 2.35), chordDist / totalRadius);
    d2 *= Math.min(1, (d * 2) / totalRadius);

    var h1 = r1 * d2;
    var h2 = r2 * d2;
    var pi2 = Math.PI * 0.5;

    ctx.beginPath();
    ctx.moveTo(p1ax, p1ay);
    ctx.bezierCurveTo(
      p1ax + Math.cos(angle1a - pi2) * h1,
      p1ay + Math.sin(angle1a - pi2) * h1,
      p2ax + Math.cos(angle2a + pi2) * h2,
      p2ay + Math.sin(angle2a + pi2) * h2,
      p2ax,
      p2ay
    );
    ctx.arc(c2x, c2y, r2, angle2a, angle2b, true);
    ctx.bezierCurveTo(
      p2bx + Math.cos(angle2b - pi2) * h2,
      p2by + Math.sin(angle2b - pi2) * h2,
      p1bx + Math.cos(angle1b + pi2) * h1,
      p1by + Math.sin(angle1b + pi2) * h1,
      p1bx,
      p1by
    );
    ctx.arc(c1x, c1y, r1, angle1b, angle1a, true);
    ctx.closePath();
    return true;
  }

  function drawLivingCircle(ctx, cx, cy, r, color, phase, bounceVal) {
    if (!ctx || r <= 0) return;
    var ph = Number(phase) || 0;
    var fill = color || COLORS.gold;

    ctx.save();
    applySquashStretch(ctx, cx, cy, bounceVal);

    ctx.shadowBlur = 12;
    ctx.shadowColor = hexToRgba(fill, 0.36);
    ctx.fillStyle = fill;

    // Smooth 2-lobe breathing perimeter using midpoint quadratic Bezier smoothing
    var steps = 32;
    var a1 = ph * 0.52;
    var a2 = ph * 0.52 + 2.65;
    var amp1 = r * (0.048 + 0.022 * Math.sin(ph * 0.9));
    var amp2 = r * (0.036 + 0.018 * Math.cos(ph * 0.72));
    var inv2Sig2 = 1 / (2 * 0.44 * 0.44);

    var pts = [];
    for (var i = 0; i < steps; i++) {
      var theta = (i / steps) * Math.PI * 2;
      var d1 = Math.atan2(Math.sin(theta - a1), Math.cos(theta - a1));
      var d2 = Math.atan2(Math.sin(theta - a2), Math.cos(theta - a2));
      var lobe = amp1 * Math.exp(-(d1 * d1) * inv2Sig2) + amp2 * Math.exp(-(d2 * d2) * inv2Sig2);
      var rad = r + lobe;
      pts.push({
        x: cx + Math.cos(theta) * rad,
        y: cy + Math.sin(theta) * rad,
      });
    }

    ctx.beginPath();
    var firstMidX = (pts[steps - 1].x + pts[0].x) * 0.5;
    var firstMidY = (pts[steps - 1].y + pts[0].y) * 0.5;
    ctx.moveTo(firstMidX, firstMidY);
    for (var j = 0; j < steps; j++) {
      var pCurr = pts[j];
      var pNext = pts[(j + 1) % steps];
      ctx.quadraticCurveTo(pCurr.x, pCurr.y, (pCurr.x + pNext.x) * 0.5, (pCurr.y + pNext.y) * 0.5);
    }
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawLavaBridge(ctx, x1, y1, r1, x2, y2, r2, progress, color1, color2) {
    if (!ctx) return;
    var p = Number(progress);
    if (!isFinite(p)) p = 1;
    var c1 = color1 || COLORS.amber;
    var c2 = color2 || c1;
    var ph = Date.now() * 0.0028;

    if (p <= 0) {
      drawLivingCircle(ctx, x1, y1, r1, c1, ph, 0);
      return;
    }
    if (p >= 1) {
      drawLivingCircle(ctx, x2, y2, r2, c2, ph, 0);
      return;
    }

    var dx = x2 - x1;
    var dy = y2 - y1;
    var totalDist = Math.hypot(dx, dy) || 1;
    var nx = -dy / totalDist;
    var ny = dx / totalDist;

    var tMove = smoothstep(0, 1, easeInOutCubic(p));
    var arcSway = Math.sin(p * Math.PI) * Math.min(5, totalDist * 0.025);
    var bx = lerp(x1, x2, tMove) + nx * arcSway;
    var by = lerp(y1, y2, tMove) + ny * arcSway;

    var baseR = lerp(r1, r2, tMove);
    // Plump viscous wax glob: swells softly instead of pinching thin
    var br = baseR * (0.80 - 0.05 * Math.sin(p * Math.PI) + 0.20 * smoothstep(0.55, 1.0, p));

    ctx.save();
    var fillGrad = makeLavaFill(ctx, x1, y1, x2, y2, c1, c2);
    ctx.fillStyle = fillGrad;
    ctx.shadowBlur = 10;
    ctx.shadowColor = hexToRgba(blendHex(c1, c2, tMove), 0.35);

    // 1. Source syrupy neck: stretches smoothly from (x1, y1, r1) into the traveling glob
    if (p < 0.78) {
      var srcPinch = clamp(p / 0.78, 0, 1);
      var r1Eff = Math.max(6, r1 * lerp(0.96, 0.68, srcPinch));
      var spreadSrc = lerp(0.38, 0.72, srcPinch);
      if (traceMetaballConnector(ctx, x1, y1, r1Eff, bx, by, br, spreadSrc, 2.6)) {
        ctx.fill();
      }
    }

    // 2. Traveling fluid lava glob
    ctx.beginPath();
    ctx.arc(bx, by, br, 0, Math.PI * 2);
    ctx.fill();

    // 3. Destination capture neck: gently pulls & absorbs the arriving glob
    if (p > 0.22) {
      var dstBlend = smoothstep(0.22, 0.96, p);
      var r2Eff = Math.max(6, r2 * lerp(0.68, 1.0, dstBlend));
      var spreadDst = lerp(0.72, 0.38, dstBlend);
      if (traceMetaballConnector(ctx, bx, by, br, x2, y2, r2Eff, spreadDst, 2.6)) {
        ctx.fill();
      }
    }

    // 4. Soft satellite wax droplet drifting smoothly in the wake
    if (p > 0.18 && p < 0.92) {
      var d1t = clamp((p - 0.18) / 0.74, 0, 1);
      var d1Eased = easeInOutCubic(d1t);
      var d1Off = -Math.sin(d1t * Math.PI) * Math.min(10, Math.max(5, totalDist * 0.045));
      var d1x = lerp(x1, x2, d1Eased * 0.88 + 0.08) + nx * d1Off;
      var d1y = lerp(y1, y2, d1Eased * 0.88 + 0.08) + ny * d1Off;
      var d1r = Math.max(2.0, Math.min(r1, r2) * 0.22 * Math.sin(d1t * Math.PI));
      ctx.fillStyle = blendHex(c1, c2, d1Eased);
      ctx.beginPath();
      ctx.arc(d1x, d1y, d1r, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
  }

  // ---------------------------------------------------------------------------
  // Bookmarks & Active Media Resolution
  // ---------------------------------------------------------------------------

  function getBookmarkSource(bm) {
    var raw = String((bm && bm.source) || 'ABS').toUpperCase();
    if (raw === 'SPT') return 'SPOTIFY';
    if (raw === 'SD') return 'MICROSD';
    return raw;
  }

  function getBookmarkItemIdx(bm) {
    if (!bm) return 0;
    if (bm.bookIdx != null) return Number(bm.bookIdx);
    if (bm.trackIdx != null) return Number(bm.trackIdx);
    if (bm.fileIdx != null) return Number(bm.fileIdx);
    if (bm.itemIdx != null) return Number(bm.itemIdx);
    if (bm.idx != null) return Number(bm.idx);
    return 0;
  }

  function getBookmarkChapterIdx(bm) {
    if (!bm) return null;
    if (bm.chapterIdx != null) return Number(bm.chapterIdx);
    if (bm.chapterNum != null) return Number(bm.chapterNum) - 1;
    return null;
  }

  function getBookmarkSec(bm) {
    if (!bm) return 0;
    var val = bm.positionSec != null ? bm.positionSec
      : bm.sec != null ? bm.sec
      : bm.timeSec != null ? bm.timeSec
      : bm.pos != null ? bm.pos
      : bm.time != null ? bm.time
      : 0;
    return Math.max(0, Number(val) || 0);
  }

  function getActiveItemIndex(state, src) {
    if (src === 'SPOTIFY') return wrapIndex(state && state.spotifyTrackIdx, SPOTIFY_TRACKS.length);
    if (src === 'MICROSD') return wrapIndex(state && state.sdFileIdx, SD_FILES.length);
    return wrapIndex(state && state.absBookIdx, ABS_BOOKS.length);
  }

  function getMatchingBookmarks(state) {
    var list = (state && Array.isArray(state.bookmarks)) ? state.bookmarks : [];
    var src = getActiveSource(state);
    var activeIdx = getActiveItemIndex(state, src);
    var book = ABS_BOOKS[activeIdx];
    var chIdx = src === 'ABS' ? wrapIndex(state && state.absChapterIdx, book.chapters.length) : null;

    var out = [];
    for (var i = 0; i < list.length; i++) {
      var bm = list[i];
      if (!bm || getBookmarkSource(bm) !== src) continue;
      if (getBookmarkItemIdx(bm) !== activeIdx) continue;
      if (src === 'ABS') {
        var bmCh = getBookmarkChapterIdx(bm);
        if (bmCh !== null && bmCh !== chIdx) continue;
      }
      out.push(bm);
    }
    return out;
  }

  function isBookmarkedNearCurrent(state, toleranceSec) {
    var tol = toleranceSec != null ? toleranceSec : 15;
    var pos = Number((state && state.positionSec) || 0);
    var matches = getMatchingBookmarks(state);
    for (var i = 0; i < matches.length; i++) {
      if (Math.abs(getBookmarkSec(matches[i]) - pos) <= tol) {
        return true;
      }
    }
    return false;
  }

  function getActiveMedia(state) {
    var s = state || {};
    var src = getActiveSource(s);
    var speed = SPEEDS[wrapIndex(s.speedIdx, SPEEDS.length)];
    var speedStr = fmtSpeed(speed);
    var sinkLabel = s.btTxOn ? 'BT TX · AirPods' : '3.5mm PCM5102';
    var nearBm = isBookmarkedNearCurrent(s, 15);
    var anyBm = getMatchingBookmarks(s).length > 0;

    if (src === 'SPOTIFY') {
      var tr = SPOTIFY_TRACKS[wrapIndex(s.spotifyTrackIdx, SPOTIFY_TRACKS.length)];
      return {
        sourceLabel: SOURCE_META.SPOTIFY.sourceLabel,
        shortCode: SOURCE_META.SPOTIFY.shortCode,
        badgeColor: SOURCE_META.SPOTIFY.badgeColor,
        title: tr.title,
        subtitle: tr.artist + ' · ' + tr.playlist,
        metaLine: (tr.liked ? '★ Liked' : 'Spotify Connect') + ' · ' + sinkLabel + ' · ' + speedStr,
        durationSec: tr.durationSec,
        palette: tr.palette,
        artType: tr.artType,
        isBookmarked: nearBm || (!!tr.liked && anyBm),
      };
    }

    if (src === 'MICROSD') {
      var f = SD_FILES[wrapIndex(s.sdFileIdx, SD_FILES.length)];
      return {
        sourceLabel: SOURCE_META.MICROSD.sourceLabel,
        shortCode: SOURCE_META.MICROSD.shortCode,
        badgeColor: SOURCE_META.MICROSD.badgeColor,
        title: f.title,
        subtitle: f.folder + ' · ' + f.format + ' Offline',
        metaLine: f.bitrate + ' · HSPI MicroSD · ' + speedStr,
        durationSec: f.durationSec,
        palette: f.palette,
        artType: f.artType,
        isBookmarked: nearBm,
      };
    }

    var book = ABS_BOOKS[wrapIndex(s.absBookIdx, ABS_BOOKS.length)];
    var ch = book.chapters[wrapIndex(s.absChapterIdx, book.chapters.length)];
    return {
      sourceLabel: SOURCE_META.ABS.sourceLabel,
      shortCode: SOURCE_META.ABS.shortCode,
      badgeColor: SOURCE_META.ABS.badgeColor,
      title: book.title,
      subtitle: book.author + ' · Ch. ' + ch.num + ' "' + ch.title + '"',
      metaLine: 'Narr. ' + book.narrator + ' · Ch ' + ch.num + '/' + book.chapters.length + ' · ' + speedStr,
      durationSec: ch.durationSec,
      palette: book.palette,
      artType: book.artType,
      isBookmarked: nearBm,
    };
  }

  // ---------------------------------------------------------------------------
  // Shared Chrome: Minimalist Top Bar, Empty Bottom Strip, Solid Toast
  // ---------------------------------------------------------------------------

  function resolveIndicatorColor(state) {
    var s = state || {};
    var scr = normalizeScreenName(s.screen);
    if (s.locked || scr === 'POCKET_LOCK') return COLORS.amber;
    if (scr === 'HOME_LAUNCHER') {
      var idx = wrapIndex(s.launcherIdx, LAUNCHER_ITEMS.length);
      return LAUNCHER_ITEMS[idx].color;
    }
    if (scr === 'VOICE_AI') return COLORS.coral;
    if (scr === 'SYSTEM_OUTPUT') return s.btTxOn ? COLORS.btCyan : COLORS.teal;
    var src = getActiveSource(s);
    return SOURCE_META[src].badgeColor;
  }

  function drawTopStatusBar(ctx, state, helpers) {
    if (!ctx) return;
    var s = state || {};
    var phase = getPhase(s);
    var scr = normalizeScreenName(s.screen);
    var isHome = scr === 'HOME_LAUNCHER';
    var dotColor = resolveIndicatorColor(s);

    ctx.save();

    // Top-left (x=14, y=14): pulsing solid colored dot + bold white label
    var homeBounce = getBounceVal('top_home');
    ctx.save();
    applySquashStretch(ctx, 22, 14, homeBounce);

    var pulseR = 5.5 + 0.65 * Math.sin(phase * 2.4);
    ctx.shadowBlur = 8;
    ctx.shadowColor = hexToRgba(dotColor, 0.55);
    ctx.fillStyle = dotColor;
    ctx.beginPath();
    ctx.arc(14, 14, pulseR, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;

    ctx.font = 'bold 12px ' + FONT_SANS;
    ctx.fillStyle = COLORS.textPrimary;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText(isHome ? 'fbox' : '‹ fbox', 26, 14.5);
    if (!isHome && s.topBarFocus === 'HOME') {
      ctx.strokeStyle = COLORS.textPrimary;
      ctx.lineWidth = 1.8;
      roundRectPath(ctx, 5, 4, 72, 20, 10);
      ctx.stroke();
    }
    ctx.restore();

    recordHitbox(helpers, { id: 'top_home', x: 6, y: 4, w: 96, h: 22, action: 'goHome' });

    // Top-right: Battery solid capsule + Output solid pill
    var batPct = Math.round(clamp(s.batteryPct == null ? 86 : s.batteryPct, 0, 100));
    var batColor = batPct < 20 ? COLORS.coral : batPct < 40 ? COLORS.amber : COLORS.teal;
    var batText = batPct + '%';

    ctx.font = 'bold 10px ' + FONT_SANS;
    var batTextW = Math.ceil(ctx.measureText(batText).width);
    var batW = Math.max(40, batTextW + 16);
    var batH = 18;
    var batX = WIDTH - 10 - batW;
    var batY = 5;

    ctx.fillStyle = batColor;
    roundRectPath(ctx, batX, batY, batW, batH, 9);
    ctx.fill();
    if (s.topBarFocus === 'SYSTEM') {
      ctx.strokeStyle = COLORS.textPrimary;
      ctx.lineWidth = 1.8;
      roundRectPath(ctx, batX - 2, batY - 2, batW + 4, batH + 4, 11);
      ctx.stroke();
    }

    ctx.fillStyle = COLORS.textDark;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(batText, batX + batW * 0.5, batY + batH * 0.5 + 0.5);

    recordHitbox(helpers, {
      id: 'top_telemetry',
      x: batX - 2,
      y: 4,
      w: batW + 6,
      h: 22,
      action: 'openSystem',
    });

    // Audio Output pill (BT in #38BDF8 or 3.5 in #45B09C)
    var btOn = !!s.btTxOn;
    var outText = btOn ? 'BT' : '3.5';
    var outColor = btOn ? COLORS.btCyan : COLORS.teal;
    ctx.font = 'bold 10px ' + FONT_SANS;
    var outTextW = Math.ceil(ctx.measureText(outText).width);
    var outW = Math.max(32, outTextW + 16);
    var outH = 18;
    var outX = batX - 6 - outW;
    var outY = 5;

    var outBounce = getBounceVal('top_output');
    ctx.save();
    applySquashStretch(ctx, outX + outW * 0.5, outY + outH * 0.5, outBounce);
    ctx.fillStyle = outColor;
    roundRectPath(ctx, outX, outY, outW, outH, 9);
    ctx.fill();
    if (s.topBarFocus === 'OUTPUT') {
      ctx.strokeStyle = COLORS.textPrimary;
      ctx.lineWidth = 1.8;
      roundRectPath(ctx, outX - 2, outY - 2, outW + 4, outH + 4, 11);
      ctx.stroke();
    }

    ctx.fillStyle = COLORS.textDark;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(outText, outX + outW * 0.5, outY + outH * 0.5 + 0.5);
    ctx.restore();

    recordHitbox(helpers, { id: 'top_output', x: outX - 2, y: 4, w: outW + 4, h: 22, action: 'toggleOutput' });
    ctx.restore();
  }

  function drawBottomKeyStrip(_ctx, _state, _hints) {
    // Pure minimalist AMOLED: leave the bottom edge completely open and true black.
  }

  function drawToast(ctx, state) {
    if (!ctx || !state || !state.toast || !(state.toast.until > Date.now())) return;
    var toast = state.toast;
    var remaining = toast.until - Date.now();
    var alpha = remaining < 240 ? clamp(remaining / 240, 0, 1) : 1;
    var accent = toast.color || COLORS.gold;
    var text = String(toast.text || '');

    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.font = 'bold 10.5px ' + FONT_SANS;
    var tw = Math.ceil(ctx.measureText(text).width);
    var pillW = clamp(tw + 24, 72, 290);
    var pillH = 20;
    var x = Math.round((WIDTH - pillW) * 0.5);
    var y = 4;

    ctx.shadowBlur = 12;
    ctx.shadowColor = hexToRgba(accent, 0.45);
    ctx.fillStyle = accent;
    roundRectPath(ctx, x, y, pillW, pillH, 10);
    ctx.fill();
    ctx.shadowBlur = 0;

    ctx.fillStyle = COLORS.textDark;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(truncateText(ctx, text, pillW - 14), x + pillW * 0.5, y + pillH * 0.5 + 0.5);
    ctx.restore();
  }

  // ---------------------------------------------------------------------------
  // Bold Solid-Dark Icons for Launcher Circles & Circular Buttons
  // ---------------------------------------------------------------------------

  function drawLauncherGlyph(ctx, idx, cx, cy, scale, phase, active) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(scale, scale);
    ctx.strokeStyle = COLORS.textDark;
    ctx.fillStyle = COLORS.textDark;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    if (idx === 0) {
      // Books: bold open book + bookmark notch
      ctx.lineWidth = 2.6;
      ctx.beginPath();
      ctx.moveTo(0, -8.5);
      ctx.quadraticCurveTo(-8.5, -12, -16, -8);
      ctx.lineTo(-16, 9.5);
      ctx.quadraticCurveTo(-8.5, 6, 0, 10.5);
      ctx.quadraticCurveTo(8.5, 6, 16, 9.5);
      ctx.lineTo(16, -8);
      ctx.quadraticCurveTo(8.5, -12, 0, -8.5);
      ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(0, -8.5);
      ctx.lineTo(0, 10.5);
      ctx.stroke();

      // Solid bookmark ribbon on right page
      ctx.beginPath();
      ctx.moveTo(5.5, -9.5);
      ctx.lineTo(11, -9.5);
      ctx.lineTo(11, 2);
      ctx.lineTo(8.25, -1);
      ctx.lineTo(5.5, 2);
      ctx.closePath();
      ctx.fill();
    } else if (idx === 1) {
      // Music: bold soundwave bars
      var baseHeights = [7, 15, 22, 14, 8];
      ctx.lineWidth = 3.2;
      for (var b = 0; b < baseHeights.length; b++) {
        var mod = active ? Math.sin(phase * 3.8 + b * 1.15) * 3.2 : 0;
        var h = Math.max(5, baseHeights[b] + mod);
        var bx = (b - 2) * 6.5;
        ctx.beginPath();
        ctx.moveTo(bx, -h * 0.5);
        ctx.lineTo(bx, h * 0.5);
        ctx.stroke();
      }
    } else if (idx === 2) {
      // Files: bold notched MicroSD card + waveform
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.moveTo(-11, -13);
      ctx.lineTo(5, -13);
      ctx.lineTo(12, -6);
      ctx.lineTo(12, 13);
      ctx.lineTo(-11, 13);
      ctx.closePath();
      ctx.stroke();

      // Solid contact notches
      for (var p = 0; p < 3; p++) {
        ctx.fillRect(-7 + p * 4.5, -9.5, 2.5, 5);
      }

      // Bold waveform inside card
      ctx.lineWidth = 2.4;
      var wf = [5, 9, 11, 6];
      for (var w = 0; w < wf.length; w++) {
        var wh = active ? wf[w] + Math.sin(phase * 4.2 + w) * 2 : wf[w];
        var wx = -5.5 + w * 4;
        ctx.beginPath();
        ctx.moveTo(wx, 9);
        ctx.lineTo(wx, 9 - wh);
        ctx.stroke();
      }
    } else {
      // Voice: bold 4-point AI star + mic spark bars
      var rOuter = 13.5 + (active ? Math.sin(phase * 3.2) * 1.1 : 0);
      var rInner = 4.2;
      ctx.beginPath();
      for (var s = 0; s < 8; s++) {
        var ang = (s * Math.PI) / 4 - Math.PI / 2;
        var rad = s % 2 === 0 ? rOuter : rInner;
        var px = -4 + Math.cos(ang) * rad;
        var py = Math.sin(ang) * rad;
        if (s === 0) ctx.moveTo(px, py);
        else ctx.lineTo(px, py);
      }
      ctx.closePath();
      ctx.fill();

      // Mic spark bars beside star
      ctx.lineWidth = 2.6;
      var sparkH = [7, 13, 8];
      for (var v = 0; v < 3; v++) {
        var vh = sparkH[v] + (active ? Math.sin(phase * 4.5 + v * 1.3) * 2.5 : 0);
        var vx = 9 + v * 4.2;
        ctx.beginPath();
        ctx.moveTo(vx, -vh * 0.5 + 1);
        ctx.lineTo(vx, vh * 0.5 + 1);
        ctx.stroke();
      }
    }

    ctx.restore();
  }

  function drawCoverDisc(ctx, cx, cy, r, media, state, bounceVal) {
    var pal = media.palette || [COLORS.amber, COLORS.coral, COLORS.gold];
    var phase = getPhase(state);
    var playing = !!(state && state.playing);
    var rot = playing ? phase * 0.45 : 0.28;

    // Choose vibrant bright segments from palette + media badge
    var primary = pal[1] === '#475569' ? pal[2] : (pal[1] || media.badgeColor);
    var secondary = pal[2] || media.badgeColor;
    var accent = media.badgeColor || COLORS.amber;

    ctx.save();
    applySquashStretch(ctx, cx, cy, bounceVal);

    // Subtle outer glow
    ctx.shadowBlur = playing ? 16 : 8;
    ctx.shadowColor = hexToRgba(primary, playing ? 0.42 : 0.25);

    // Clip to outer disc circle
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fillStyle = primary;
    ctx.fill();
    ctx.shadowBlur = 0;

    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.clip();

    // Bright solid geometric cover segments
    ctx.fillStyle = secondary;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, r + 2, rot, rot + Math.PI * 0.78);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = accent;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, r * 0.72, rot + Math.PI * 0.95, rot + Math.PI * 1.68);
    ctx.closePath();
    ctx.fill();

    // Crisp inner ring geometry tailored slightly to artType
    ctx.strokeStyle = COLORS.bg;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.arc(cx, cy, r * 0.54, rot - 0.5, rot + Math.PI * 1.25);
    ctx.stroke();

    // Rotating bright highlight arc when playing
    if (playing) {
      ctx.strokeStyle = COLORS.textPrimary;
      ctx.lineWidth = 3.5;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.arc(cx, cy, r - 6.5, rot * 1.5, rot * 1.5 + Math.PI * 0.48);
      ctx.stroke();
    }

    ctx.restore();

    // True-black #000000 center spindle hole (r=15)
    ctx.fillStyle = COLORS.bg;
    ctx.beginPath();
    ctx.arc(cx, cy, 15, 0, Math.PI * 2);
    ctx.fill();

    ctx.restore();

    // Subtle orbiting lava satellite dot outside disc perimeter
    var satAng = playing ? phase * 0.85 : -0.65;
    var satOrbit = r + 7;
    var sx = cx + Math.cos(satAng) * satOrbit;
    var sy = cy + Math.sin(satAng) * satOrbit;
    var satR = 4.6 + (playing ? Math.sin(phase * 3.1) * 0.8 : 0);

    ctx.save();
    ctx.fillStyle = secondary;
    ctx.shadowBlur = 8;
    ctx.shadowColor = hexToRgba(secondary, 0.55);
    ctx.beginPath();
    ctx.arc(sx, sy, satR, 0, Math.PI * 2);
    ctx.fill();

    // Tiny trailing lava droplet
    var tailAng = satAng - 0.17;
    ctx.shadowBlur = 0;
    ctx.beginPath();
    ctx.arc(cx + Math.cos(tailAng) * satOrbit, cy + Math.sin(tailAng) * satOrbit, 2.2, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // ---------------------------------------------------------------------------
  // Screen 1: Home Launcher
  // ---------------------------------------------------------------------------

  function renderHomeLauncher(ctx, state, helpers) {
    if (!ctx) return;
    var s = state || {};
    var activeIdx = wrapIndex(s.launcherIdx, 4);

    if (_lavaTargetIdx === null) {
      _prevLauncherIdx = activeIdx;
      _lavaTargetIdx = activeIdx;
      _lavaAnim = 1;
      _lavaArrivedBounced = true;
      _launcherRadii = [31, 31, 31, 31];
      _launcherRadii[activeIdx] = 45;
    } else if (activeIdx !== _lavaTargetIdx) {
      _prevLauncherIdx = _lavaTargetIdx;
      _lavaTargetIdx = activeIdx;
      _lavaAnim = 0;
      _lavaArrivedBounced = false;
      triggerBounce('launcher_' + _prevLauncherIdx, -0.8);
    }

    tickInternalAnimations(s);
    var phase = getPhase(s);
    var activeSrc = getActiveSource(s);
    var media = getActiveMedia(s);

    resetHitboxes(helpers);

    ctx.save();
    ctx.fillStyle = COLORS.bg;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    drawTopStatusBar(ctx, s, helpers);

    // Lava-lamp liquid metaball bridge when switching launcher circles
    if (_lavaAnim < 1 && _prevLauncherIdx !== null && _prevLauncherIdx !== _lavaTargetIdx) {
      drawLavaBridge(
        ctx,
        LAUNCHER_CX[_prevLauncherIdx],
        LAUNCHER_CY,
        _launcherRadii ? _launcherRadii[_prevLauncherIdx] : 38,
        LAUNCHER_CX[_lavaTargetIdx],
        LAUNCHER_CY,
        _launcherRadii ? _launcherRadii[_lavaTargetIdx] : 38,
        _lavaAnim,
        LAUNCHER_ITEMS[_prevLauncherIdx].color,
        LAUNCHER_ITEMS[_lavaTargetIdx].color
      );
    }

    // 4 Large Circular Widget Buttons
    for (var i = 0; i < LAUNCHER_ITEMS.length; i++) {
      var item = LAUNCHER_ITEMS[i];
      var selected = i === activeIdx;
      var cx = LAUNCHER_CX[i];
      var floatY = selected ? 0 : Math.sin(phase * 0.9 + i * 1.45) * 1.8;
      var cy = LAUNCHER_CY + floatY;
      var bounceVal = getBounceVal('launcher_' + i);
      var drawR = _launcherRadii ? _launcherRadii[i] : (selected ? 45 : 31);

      if (selected) {
        drawLivingCircle(ctx, cx, cy, drawR, item.color, phase * 0.8 + i * 0.8, bounceVal);
        ctx.save();
        applySquashStretch(ctx, cx, cy, bounceVal);
        drawLauncherGlyph(ctx, i, cx, cy, 0.88 + (drawR - 31) / 14 * 0.30, phase, true);
        ctx.restore();
      } else {
        ctx.save();
        applySquashStretch(ctx, cx, cy, bounceVal);
        ctx.globalAlpha = 0.88;
        ctx.fillStyle = item.color;
        ctx.beginPath();
        ctx.arc(cx, cy, drawR, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 1;
        drawLauncherGlyph(ctx, i, cx, cy, 0.88 + (drawR - 31) / 14 * 0.30, phase, item.source === activeSrc && !!s.playing);
        ctx.restore();
      }

      // Label underneath
      if (selected) {
        ctx.font = 'bold 11.5px ' + FONT_SANS;
        var lblW = Math.ceil(ctx.measureText(item.label).width) + 22;
        var pillX = Math.round(cx - lblW * 0.5);
        var pillY = 157;
        ctx.fillStyle = item.color;
        roundRectPath(ctx, pillX, pillY, lblW, 20, 10);
        ctx.fill();
        ctx.fillStyle = COLORS.textDark;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(item.label, cx, pillY + 10.5);
      } else {
        ctx.font = 'bold 11px ' + FONT_SANS;
        ctx.fillStyle = COLORS.textPrimary;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(item.label, cx, 167);
      }

      recordHitbox(helpers, {
        id: 'launcher_' + i,
        x: cx - 48,
        y: LAUNCHER_CY - 48,
        w: 96,
        h: 120,
        action: 'activateLauncher',
        idx: i,
      });
    }

    // Bottom floating Now-Playing solid/glow pill (y=204 centered)
    var dur = Math.max(1, media.durationSec || s.durationSec || 1);
    var pos = clamp(s.positionSec || 0, 0, dur);
    var glyph = s.playing ? '▶ ' : '⏸ ';
    var npText = glyph + media.title + ' · ' + formatTimeWithHelpers(pos, helpers);

    ctx.font = 'bold 11px ' + FONT_SANS;
    var maxPillW = 420;
    var measuredW = Math.ceil(ctx.measureText(npText).width);
    var npW = clamp(measuredW + 28, 160, maxPillW);
    var npH = 26;
    var npX = Math.round((WIDTH - npW) * 0.5);
    var npY = 191; // center y = 204
    var npBounce = getBounceVal('home_nowpill');

    ctx.save();
    applySquashStretch(ctx, WIDTH * 0.5, 204, npBounce);
    ctx.shadowBlur = 14;
    ctx.shadowColor = hexToRgba(media.badgeColor, 0.45);
    ctx.fillStyle = media.badgeColor;
    roundRectPath(ctx, npX, npY, npW, npH, 13);
    ctx.fill();
    ctx.shadowBlur = 0;

    if (s.homeFocusLayer === 'NOW_PILL') {
      ctx.strokeStyle = COLORS.textPrimary;
      ctx.lineWidth = 2.2;
      roundRectPath(ctx, npX - 3, npY - 3, npW + 6, npH + 6, 16);
      ctx.stroke();
    }

    ctx.fillStyle = COLORS.textDark;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(truncateText(ctx, npText, npW - 22, helpers), WIDTH * 0.5, 204.5);
    ctx.restore();

    recordHitbox(helpers, {
      id: 'mini_player',
      x: npX,
      y: npY,
      w: npW,
      h: npH,
      action: 'openNowPlaying',
    });

    if (global.FBoxFen && typeof global.FBoxFen.drawFen === 'function') {
      global.FBoxFen.drawFen(ctx, 30, 210, 0.82, {
        mood: 'RESTING',
        den: true,
        phase: phase,
        accent: COLORS.coral
      });
    }

    drawToast(ctx, s);
    ctx.restore();
  }

  // ---------------------------------------------------------------------------
  // Screen 2: Now Playing
  // ---------------------------------------------------------------------------

  function renderNowPlaying(ctx, state, helpers) {
    if (!ctx) return;
    var s = state || {};

    if (_npPrevPlay !== null && _npPrevPlay !== !!s.playing) {
      triggerBounce('np_play', s.playing ? 6.8 : 5.2);
      triggerBounce('np_disc', s.playing ? 5.2 : 4.0);
    }
    _npPrevPlay = !!s.playing;

    if (_npPrevSpeedIdx !== null && _npPrevSpeedIdx !== wrapIndex(s.speedIdx, SPEEDS.length)) {
      triggerBounce('np_speed', 6.4);
    }
    _npPrevSpeedIdx = wrapIndex(s.speedIdx, SPEEDS.length);

    tickInternalAnimations(s);
    var phase = getPhase(s);
    var media = getActiveMedia(s);
    var dur = Math.max(1, media.durationSec || s.durationSec || 1);
    var pos = clamp(s.positionSec || 0, 0, dur);
    var speed = SPEEDS[wrapIndex(s.speedIdx, SPEEDS.length)];
    var stick = s.stick || {};
    var scrubDelta = Number(stick.scrubDeltaSec || 0);
    var isScrubbing = scrubDelta !== 0;
    var previewPos = clamp(pos + scrubDelta, 0, dur);
    var nearBm = isBookmarkedNearCurrent(s, 15);
    var btOn = !!s.btTxOn;

    resetHitboxes(helpers);

    ctx.save();
    ctx.fillStyle = COLORS.bg;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    drawTopStatusBar(ctx, s, helpers);

    // Left: Giant Bouncy Circular Cover Disc (cx=92, cy=124, r=64)
    drawCoverDisc(ctx, 92, 124, 64, media, s, getBounceVal('np_disc'));
    recordHitbox(helpers, { id: 'np_cover', x: 28, y: 60, w: 128, h: 128, action: 'togglePlay' });

    // Right column (x = 180..516)
    var rx = 180;
    var rw = 336;

    // Big crisp title (19px bold #FFFFFF)
    ctx.save();
    applySquashStretch(ctx, rx + rw * 0.5, 48, getBounceVal('np_title') * 0.35);
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    ctx.font = 'bold 19px ' + FONT_SANS;
    ctx.fillStyle = COLORS.textPrimary;
    ctx.fillText(truncateText(ctx, media.title, rw, helpers), rx, 36);
    ctx.restore();

    // Bright solid colored subtitle pill
    ctx.font = 'bold 11px ' + FONT_SANS;
    var subTrunc = truncateText(ctx, media.subtitle, rw - 24, helpers);
    var subW = clamp(Math.ceil(ctx.measureText(subTrunc).width) + 22, 72, rw);
    ctx.fillStyle = media.badgeColor;
    roundRectPath(ctx, rx, 65, subW, 22, 11);
    ctx.fill();

    ctx.fillStyle = COLORS.textDark;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(subTrunc, rx + subW * 0.5, 76.5);

    // Lava-lamp droplet pulse between tapped action bubble and Play circle
    var npCenters = { rew: 204, play: 260, fwd: 322, mark: 384, output: 440, speed: 491 };
    if (_npLavaAnim < 1 && _npLavaFrom && npCenters[_npLavaFrom] != null) {
      var fromX = npCenters[_npLavaFrom];
      var fromR = _npLavaFrom === 'speed' ? 14 : 18;
      if (fromX !== 260) {
        drawLavaBridge(ctx, fromX, 130, fromR, 260, 130, 24, _npLavaAnim, _npLavaColor, COLORS.gold);
      } else {
        drawLivingCircle(ctx, 260, 130, 25 + Math.sin(_npLavaAnim * Math.PI) * 5, COLORS.gold, phase * 2, 0);
      }
    }

    // 5 Circular Action Widget Bubbles (cy = 130) + Speed badge pill (cx = 491)
    // 1. -15s Amber (cx=204, r=19)
    var bRew = getBounceVal('np_rew');
    drawLivingCircle(ctx, 204, 130, 19, COLORS.amber, phase * 0.7, bRew);
    ctx.save();
    applySquashStretch(ctx, 204, 130, bRew);
    ctx.fillStyle = COLORS.textDark;
    ctx.font = 'bold 11px ' + FONT_SANS;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('-15', 204, 130.5);
    ctx.restore();
    recordHitbox(helpers, { id: 'np_rew15', x: 183, y: 109, w: 42, h: 42, action: 'seekRel', delta: -15 });

    // 2. Play/Pause Gold (cx=260, r=24)
    var bPlay = getBounceVal('np_play');
    drawLivingCircle(ctx, 260, 130, 24, COLORS.gold, phase * 0.9 + 1.1, bPlay);
    ctx.save();
    applySquashStretch(ctx, 260, 130, bPlay);
    ctx.fillStyle = COLORS.textDark;
    if (s.playing) {
      roundRectPath(ctx, 253, 121, 5, 18, 1.5);
      ctx.fill();
      roundRectPath(ctx, 262, 121, 5, 18, 1.5);
      ctx.fill();
    } else {
      ctx.beginPath();
      ctx.moveTo(254, 120);
      ctx.lineTo(270, 130);
      ctx.lineTo(254, 140);
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();
    recordHitbox(helpers, { id: 'np_play', x: 234, y: 104, w: 52, h: 52, action: 'togglePlay' });

    // 3. +30s Teal (cx=322, r=19)
    var bFwd = getBounceVal('np_fwd');
    drawLivingCircle(ctx, 322, 130, 19, COLORS.teal, phase * 0.7 + 2.1, bFwd);
    ctx.save();
    applySquashStretch(ctx, 322, 130, bFwd);
    ctx.fillStyle = COLORS.textDark;
    ctx.font = 'bold 11px ' + FONT_SANS;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('+30', 322, 130.5);
    ctx.restore();
    recordHitbox(helpers, { id: 'np_fwd30', x: 301, y: 109, w: 42, h: 42, action: 'seekRel', delta: 30 });

    // 4. Bookmark Coral (cx=384, r=19): solid when bookmarked, thick Coral ring when unbookmarked
    var bMark = getBounceVal('np_mark');
    if (nearBm) {
      drawLivingCircle(ctx, 384, 130, 19, COLORS.coral, phase * 0.8 + 3.0, bMark);
    } else {
      ctx.save();
      applySquashStretch(ctx, 384, 130, bMark);
      ctx.fillStyle = COLORS.bg;
      ctx.beginPath();
      ctx.arc(384, 130, 18.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = COLORS.coral;
      ctx.lineWidth = 3.2;
      ctx.stroke();
      ctx.restore();
    }
    ctx.save();
    applySquashStretch(ctx, 384, 130, bMark);
    ctx.fillStyle = nearBm ? COLORS.textDark : COLORS.coral;
    ctx.font = 'bold 16px ' + FONT_SANS;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('★', 384, 130.5);
    ctx.restore();
    recordHitbox(helpers, { id: 'np_mark', x: 363, y: 109, w: 42, h: 42, action: 'toggleBookmark' });

    // 5. Output BT/3.5 circle (cx=440, r=19)
    var bOut = getBounceVal('np_output');
    var outClr = btOn ? COLORS.btCyan : COLORS.teal;
    drawLivingCircle(ctx, 440, 130, 19, outClr, phase * 0.75 + 4.1, bOut);
    ctx.save();
    applySquashStretch(ctx, 440, 130, bOut);
    ctx.fillStyle = COLORS.textDark;
    ctx.font = 'bold 11px ' + FONT_SANS;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(btOn ? 'BT' : '3.5', 440, 130.5);
    ctx.restore();
    recordHitbox(helpers, { id: 'np_output', x: 419, y: 109, w: 42, h: 42, action: 'toggleOutput' });

    // 6. Speed badge pill at cx=491 (y=118..142)
    var bSpd = getBounceVal('np_speed');
    var spdText = fmtSpeed(speed);
    var spdColor = speed > 1.0 ? COLORS.gold : COLORS.textPrimary;
    ctx.save();
    applySquashStretch(ctx, 491, 130, bSpd);
    ctx.fillStyle = spdColor;
    roundRectPath(ctx, 467, 118, 48, 24, 12);
    ctx.fill();
    ctx.fillStyle = COLORS.textDark;
    ctx.font = 'bold 10.5px ' + FONT_MONO;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(spdText, 491, 130.5);
    ctx.restore();
    recordHitbox(helpers, { id: 'np_speed', x: 467, y: 115, w: 49, h: 30, action: 'cycleSpeed' });

    if (s.npFocusRow === 'CONTROLS') {
      var npFocusIdx = clamp(Math.round(Number(s.npFocusIdx != null ? s.npFocusIdx : 1)), 0, 5);
      var npRingCoords = [
        { cx: 204, r: 22 },
        { cx: 260, r: 27 },
        { cx: 322, r: 22 },
        { cx: 384, r: 22 },
        { cx: 440, r: 22 },
        { cx: 491, pill: true },
      ];
      var ringSpec = npRingCoords[npFocusIdx];
      ctx.save();
      ctx.strokeStyle = COLORS.textPrimary;
      ctx.lineWidth = 2.2;
      if (ringSpec.pill) {
        roundRectPath(ctx, 464, 115, 54, 30, 15);
      } else {
        ctx.beginPath();
        ctx.arc(ringSpec.cx, 130, ringSpec.r, 0, Math.PI * 2);
      }
      ctx.stroke();
      ctx.restore();
    }

    // Bottom-right progress track (x=180..514, y=184, height=7)
    var trackX = 180;
    var trackW = 334;
    var trackH = 7;
    var trackY = 180.5; // center at 184
    var pct = clamp(pos / dur, 0, 1);
    var previewPct = clamp(previewPos / dur, 0, 1);
    var playheadX = trackX + trackW * pct;
    var previewX = trackX + trackW * previewPct;
    var activeColor = media.badgeColor;

    ctx.fillStyle = COLORS.trackBg;
    roundRectPath(ctx, trackX, trackY, trackW, trackH, 3.5);
    ctx.fill();

    if (pct > 0) {
      ctx.fillStyle = activeColor;
      roundRectPath(ctx, trackX, trackY, Math.max(7, trackW * pct), trackH, 3.5);
      ctx.fill();
    }

    if (isScrubbing) {
      var segX = Math.min(playheadX, previewX);
      var segW = Math.max(3, Math.abs(previewX - playheadX));
      ctx.fillStyle = scrubDelta > 0 ? COLORS.gold : COLORS.coral;
      roundRectPath(ctx, segX, trackY, segW, trackH, 3.5);
      ctx.fill();
    }

    // Subtle bookmark markers on track
    var activeBookmarks = getMatchingBookmarks(s);
    for (var bi = 0; bi < activeBookmarks.length; bi++) {
      var bmSec = clamp(getBookmarkSec(activeBookmarks[bi]), 0, dur);
      var bmX = trackX + (bmSec / dur) * trackW;
      ctx.fillStyle = COLORS.coral;
      ctx.beginPath();
      ctx.arc(bmX, 184, 3, 0, Math.PI * 2);
      ctx.fill();
    }

    // Bouncy circular lava-drop playhead (r=8, inflating to r=13 when scrubbing)
    var knobX = isScrubbing ? previewX : playheadX;
    var knobY = 184;
    var baseKnobR = isScrubbing ? 13 : 8;
    var knobColor = isScrubbing ? COLORS.coral : activeColor;
    var knobBounce = getBounceVal('np_playhead');

    ctx.save();
    applySquashStretch(ctx, knobX, knobY, knobBounce);
    ctx.shadowBlur = 12;
    ctx.shadowColor = hexToRgba(knobColor, 0.55);
    ctx.fillStyle = knobColor;
    ctx.beginPath();
    ctx.arc(knobX, knobY, baseKnobR, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;

    ctx.fillStyle = COLORS.textDark;
    ctx.beginPath();
    ctx.arc(knobX, knobY, isScrubbing ? 4 : 2.5, 0, Math.PI * 2);
    ctx.fill();
    if (s.npFocusRow === 'SCRUB') {
      ctx.strokeStyle = COLORS.textPrimary;
      ctx.lineWidth = 2.0;
      ctx.beginPath();
      ctx.arc(knobX, knobY, baseKnobR + 3, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();

    // Floating solid time pill when scrubbing
    if (isScrubbing) {
      var deltaInt = Math.round(scrubDelta);
      var scrubText = (deltaInt > 0 ? '+' : '') + deltaInt + 's · ' + formatTimeWithHelpers(previewPos, helpers);
      var pillClr = deltaInt > 0 ? COLORS.gold : COLORS.coral;
      ctx.font = 'bold 10px ' + FONT_MONO;
      var sbw = Math.ceil(ctx.measureText(scrubText).width) + 16;
      var sbh = 19;
      var sbx = clamp(knobX - sbw * 0.5, trackX, trackX + trackW - sbw);
      var sby = 152;

      ctx.fillStyle = pillClr;
      roundRectPath(ctx, sbx, sby, sbw, sbh, 9.5);
      ctx.fill();

      ctx.fillStyle = COLORS.textDark;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(scrubText, sbx + sbw * 0.5, sby + sbh * 0.5 + 0.5);
    }

    recordHitbox(helpers, { id: 'scrubber', x: trackX, y: 170, w: trackW, h: 28, action: 'scrubTo' });

    // Tabular mono timestamps
    var shownPos = isScrubbing ? previewPos : pos;
    var rem = Math.max(0, dur - shownPos);

    ctx.font = 'bold 11.5px ' + FONT_MONO;
    ctx.fillStyle = COLORS.textPrimary;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    ctx.fillText(formatTimeWithHelpers(shownPos, helpers), trackX, 202);

    // Subtle volume indicator centered between timestamps (highlights if recently adjusted)
    var vol = Math.round(clamp(s.volume == null ? 74 : s.volume, 0, 100));
    var volActive = Number(s.volHudUntil || 0) > Date.now();
    ctx.font = '600 10.5px ' + FONT_MONO;
    ctx.fillStyle = volActive ? activeColor : COLORS.textSecondary;
    ctx.textAlign = 'center';
    ctx.fillText('VOL ' + vol + '%', trackX + trackW * 0.5, 202.5);

    ctx.font = '600 11.5px ' + FONT_MONO;
    ctx.fillStyle = COLORS.textSecondary;
    ctx.textAlign = 'right';
    ctx.fillText('-' + formatTimeWithHelpers(rem, helpers), trackX + trackW, 202);

    if (global.FBoxFen && typeof global.FBoxFen.drawFen === 'function') {
      global.FBoxFen.drawFen(ctx, 36, 212, 0.82, {
        mood: 'LISTENING',
        playing: !!s.playing,
        phase: phase
      });
    }

    drawToast(ctx, s);
    ctx.restore();
  }

  // ---------------------------------------------------------------------------
  // Screen 3: System & Audio Output Modal
  // ---------------------------------------------------------------------------

  function drawOutputCircleGlyph(ctx, isBt, cx, cy, color) {
    ctx.save();
    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    if (isBt) {
      ctx.beginPath();
      ctx.moveTo(cx - 2, cy - 16);
      ctx.lineTo(cx - 2, cy + 16);
      ctx.lineTo(cx + 9, cy + 8);
      ctx.lineTo(cx - 10, cy - 7);
      ctx.moveTo(cx - 10, cy + 7);
      ctx.lineTo(cx + 9, cy - 8);
      ctx.lineTo(cx - 2, cy - 16);
      ctx.stroke();
    } else {
      // Bold 3.5mm TRS plug icon
      roundRectPath(ctx, cx - 16, cy - 7, 13, 14, 3);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(cx - 3, cy);
      ctx.lineTo(cx + 16, cy);
      ctx.stroke();
      ctx.fillRect(cx + 4, cy - 3.5, 2.5, 7);
      ctx.fillRect(cx + 11, cy - 4, 5, 8);
    }
    ctx.restore();
  }

  function renderSystemOutputModal(ctx, state, helpers) {
    if (!ctx) return;
    var s = state || {};
    var btOn = !!s.btTxOn;

    if (_sysPrevBtOn === null) {
      _sysPrevBtOn = btOn;
    } else if (_sysPrevBtOn !== btOn) {
      _sysFromBt = _sysPrevBtOn;
      _sysPrevBtOn = btOn;
      _outputLavaAnim = 0;
      triggerBounce(btOn ? 'sys_bt' : 'sys_wired', 6.8);
      triggerBounce(btOn ? 'sys_wired' : 'sys_bt', -3.6);
    }

    tickInternalAnimations(s);
    var phase = getPhase(s);
    var batPct = Math.round(clamp(s.batteryPct == null ? 86 : s.batteryPct, 0, 100));
    var batVolts = Number(s.batteryVolts == null ? 3.98 : s.batteryVolts).toFixed(2);

    resetHitboxes(helpers);

    ctx.save();
    ctx.fillStyle = COLORS.bg;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    drawTopStatusBar(ctx, s, helpers);

    // Lava bridge connecting the two circular output widgets whenever btTxOn flips
    if (_outputLavaAnim < 1) {
      var fromX = _sysFromBt ? 368 : 168;
      var toX = btOn ? 368 : 168;
      var fromC = _sysFromBt ? COLORS.btCyan : COLORS.teal;
      var toC = btOn ? COLORS.btCyan : COLORS.teal;
      drawLavaBridge(ctx, fromX, 112, 42, toX, 112, 42, _outputLavaAnim, fromC, toC);
    }

    var outputs = [
      {
        id: 'sys_pcm5102',
        cx: 168,
        cy: 112,
        r: 48,
        color: COLORS.teal,
        label: '3.5mm Wired',
        active: !btOn,
        isBt: false,
        bounceKey: 'sys_wired',
        action: 'setOutputWired',
      },
      {
        id: 'sys_bttx',
        cx: 368,
        cy: 112,
        r: 48,
        color: COLORS.btCyan,
        label: 'Bluetooth TX',
        active: btOn,
        isBt: true,
        bounceKey: 'sys_bt',
        action: 'setOutputBt',
      },
    ];

    for (var i = 0; i < outputs.length; i++) {
      var o = outputs[i];
      var bVal = getBounceVal(o.bounceKey);

      if (o.active) {
        drawLivingCircle(ctx, o.cx, o.cy, o.r, o.color, phase * 0.8 + i, bVal);
        ctx.save();
        applySquashStretch(ctx, o.cx, o.cy, bVal);
        drawOutputCircleGlyph(ctx, o.isBt, o.cx, o.cy, COLORS.textDark);
        ctx.restore();
      } else {
        ctx.save();
        applySquashStretch(ctx, o.cx, o.cy, bVal);
        ctx.fillStyle = hexToRgba(o.color, 0.22);
        ctx.beginPath();
        ctx.arc(o.cx, o.cy, o.r - 4, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = o.color;
        ctx.lineWidth = 3.2;
        ctx.stroke();
        drawOutputCircleGlyph(ctx, o.isBt, o.cx, o.cy, o.color);
        ctx.restore();
      }

      ctx.font = 'bold 12px ' + FONT_SANS;
      ctx.fillStyle = o.active ? COLORS.textPrimary : COLORS.textSecondary;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(o.label, o.cx, 173);

      recordHitbox(helpers, {
        id: o.id,
        x: o.cx - 54,
        y: o.cy - 54,
        w: 108,
        h: 126,
        action: o.action,
      });
    }

    // Bottom row (y=192): 3 solid colored telemetry pills
    var batPillColor = batPct < 20 ? COLORS.coral : batPct < 40 ? COLORS.amber : COLORS.teal;
    var pills = [
      { text: 'LiPo ' + batPct + '% · ' + batVolts + 'V', color: batPillColor },
      { text: 'PSRAM 8MB', color: COLORS.gold },
      { text: 'SD 24.8GB', color: COLORS.amber },
    ];

    ctx.font = 'bold 10.5px ' + FONT_MONO;
    var gap = 10;
    var totalW = 0;
    for (var pi = 0; pi < pills.length; pi++) {
      pills[pi].w = Math.ceil(ctx.measureText(pills[pi].text).width) + 22;
      totalW += pills[pi].w;
    }
    totalW += gap * (pills.length - 1);

    var px = Math.round((WIDTH - totalW) * 0.5);
    var py = 192;
    var ph = 24;
    for (var pj = 0; pj < pills.length; pj++) {
      var pill = pills[pj];
      ctx.fillStyle = pill.color;
      roundRectPath(ctx, px, py, pill.w, ph, 12);
      ctx.fill();

      ctx.fillStyle = COLORS.textDark;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(pill.text, px + pill.w * 0.5, py + ph * 0.5 + 0.5);

      px += pill.w + gap;
    }

    drawToast(ctx, s);
    ctx.restore();
  }

  // ---------------------------------------------------------------------------
  // Screen 4: Pocket Lock
  // ---------------------------------------------------------------------------

  function renderPocketLock(ctx, state, helpers) {
    if (!ctx) return;
    var s = state || {};
    var now = Date.now();
    var flashUntil = Number(s.lockFlashUntil || 0);
    var flashing = flashUntil > now;

    if (flashing && flashUntil !== _lastLockFlashUntil) {
      _lastLockFlashUntil = flashUntil;
      triggerBounce('lock_squash', 7.4);
      _lockWobbleSpring.vel = 42;
    }

    tickInternalAnimations(s);
    var phase = getPhase(s);

    resetHitboxes(helpers);

    ctx.save();
    ctx.fillStyle = COLORS.bg;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    var wobbleX = _lockWobbleSpring.val;
    if (flashing) {
      var flashRatio = clamp((flashUntil - now) / 900, 0, 1);
      wobbleX += Math.sin(now * 0.055) * 6 * flashRatio;
    }

    var cx = WIDTH * 0.5 + wobbleX;
    var cy = 94;
    var lockBounce = getBounceVal('lock_squash');

    // Big centered solid Amber #E3A84B circular padlock badge (r=46)
    drawLivingCircle(ctx, cx, cy, 46, COLORS.amber, phase * 0.75, lockBounce);

    // Bold #000000 Padlock Glyph inside solid Amber circle
    ctx.save();
    applySquashStretch(ctx, cx, cy, lockBounce);
    ctx.strokeStyle = COLORS.textDark;
    ctx.fillStyle = COLORS.textDark;
    ctx.lineWidth = 4;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    // Shackle
    ctx.beginPath();
    ctx.arc(cx, cy - 9, 11.5, Math.PI, 0, false);
    ctx.lineTo(cx + 11.5, cy);
    ctx.moveTo(cx - 11.5, cy - 9);
    ctx.lineTo(cx - 11.5, cy);
    ctx.stroke();

    // Solid lock body
    roundRectPath(ctx, cx - 18, cy - 1, 36, 25, 6);
    ctx.fill();

    // Amber keyhole punch inside solid dark lock body
    ctx.fillStyle = COLORS.amber;
    ctx.beginPath();
    ctx.arc(cx, cy + 9, 3.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillRect(cx - 1.5, cy + 11, 3, 6.5);
    ctx.restore();

    // Clean white "LOCKED" & "Hold B1 + B5"
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = 'bold 20px ' + FONT_SANS;
    ctx.fillStyle = COLORS.textPrimary;
    ctx.fillText('LOCKED', WIDTH * 0.5, 166);

    ctx.font = '600 12px ' + FONT_SANS;
    ctx.fillStyle = flashing ? COLORS.amber : COLORS.textSecondary;
    ctx.fillText('Hold B1 + B5', WIDTH * 0.5, 194);

    if (global.FBoxFen && typeof global.FBoxFen.drawFen === 'function') {
      global.FBoxFen.drawFen(ctx, 486, 208, 0.88, {
        mood: 'SLEEPING',
        phase: phase
      });
    }

    drawToast(ctx, s);
    ctx.restore();
  }

  // ---------------------------------------------------------------------------
  // Interaction Helpers (with Bouncy Spring Impulses)
  // ---------------------------------------------------------------------------

  function syncSourcePosition(state, nextSource) {
    if (!state) return;
    state._sourcePositions = state._sourcePositions || {};
    var prevSource = getActiveSource(state);
    if (prevSource !== nextSource) {
      state._sourcePositions[prevSource] = Number(state.positionSec || 0);
      state.activeSource = nextSource;
      var media = getActiveMedia(state);
      var dur = Math.max(1, media.durationSec || 1);
      state.durationSec = dur;
      if (state._sourcePositions[nextSource] != null) {
        state.positionSec = clamp(state._sourcePositions[nextSource], 0, dur);
      } else {
        state.positionSec = clamp(state.positionSec || 0, 0, dur);
      }
    } else {
      var curMedia = getActiveMedia(state);
      state.durationSec = Math.max(1, curMedia.durationSec || 1);
      state.positionSec = clamp(state.positionSec || 0, 0, state.durationSec);
    }
  }

  function togglePlay(state) {
    if (!state) return false;
    state.playing = !state.playing;
    var media = getActiveMedia(state);
    state.durationSec = Math.max(1, media.durationSec || state.durationSec || 1);
    state.positionSec = clamp(state.positionSec || 0, 0, state.durationSec);

    triggerBounce('np_play', state.playing ? 7.0 : 5.4);
    triggerBounce('np_disc', state.playing ? 5.6 : 4.2);
    triggerBounce('home_nowpill', 5.2);
    _npPrevPlay = state.playing;
    _npLavaFrom = 'play';
    _npLavaColor = COLORS.gold;
    _npLavaAnim = 0;

    return state.playing;
  }

  function seekRelative(state, deltaSec) {
    if (!state) return 0;
    var delta = Number(deltaSec) || 0;
    var media = getActiveMedia(state);
    var dur = Math.max(1, media.durationSec || state.durationSec || 1);
    state.durationSec = dur;
    state.positionSec = clamp((Number(state.positionSec) || 0) + delta, 0, dur);

    if (delta < 0) {
      triggerBounce('np_rew', 6.4);
      _npLavaFrom = 'rew';
      _npLavaColor = COLORS.amber;
    } else {
      triggerBounce('np_fwd', 6.4);
      _npLavaFrom = 'fwd';
      _npLavaColor = COLORS.teal;
    }
    _npLavaAnim = 0;
    triggerBounce('np_playhead', 6.2);
    triggerBounce('np_disc', delta >= 0 ? 4.8 : -4.8);

    return state.positionSec;
  }

  function cycleSpeed(state) {
    if (!state) return SPEEDS[0];
    state.speedIdx = wrapIndex((Number(state.speedIdx) || 0) + 1, SPEEDS.length);
    var spd = SPEEDS[state.speedIdx];
    _npPrevSpeedIdx = state.speedIdx;
    setToast(state, 'Playback ' + fmtSpeed(spd), COLORS.gold, 1500);

    triggerBounce('np_speed', 6.6);
    triggerBounce('np_disc', 4.6);
    _npLavaFrom = 'speed';
    _npLavaColor = COLORS.gold;
    _npLavaAnim = 0;

    return spd;
  }

  function prevItem(state) {
    if (!state) return;
    var src = getActiveSource(state);
    if (src === 'SPOTIFY') {
      state.spotifyTrackIdx = wrapIndex((Number(state.spotifyTrackIdx) || 0) - 1, SPOTIFY_TRACKS.length);
    } else if (src === 'MICROSD') {
      state.sdFileIdx = wrapIndex((Number(state.sdFileIdx) || 0) - 1, SD_FILES.length);
    } else {
      var bookIdx = wrapIndex(state.absBookIdx, ABS_BOOKS.length);
      var chIdx = wrapIndex(state.absChapterIdx, ABS_BOOKS[bookIdx].chapters.length);
      if (chIdx > 0) {
        state.absChapterIdx = chIdx - 1;
      } else {
        var prevBookIdx = wrapIndex(bookIdx - 1, ABS_BOOKS.length);
        state.absBookIdx = prevBookIdx;
        state.absChapterIdx = ABS_BOOKS[prevBookIdx].chapters.length - 1;
      }
    }
    var media = getActiveMedia(state);
    state.positionSec = 0;
    state.durationSec = media.durationSec;

    triggerBounce('np_disc', -6.8);
    triggerBounce('np_title', 5.2);
    triggerBounce('np_playhead', 5.0);

    return media;
  }

  function nextItem(state) {
    if (!state) return;
    var src = getActiveSource(state);
    if (src === 'SPOTIFY') {
      state.spotifyTrackIdx = wrapIndex((Number(state.spotifyTrackIdx) || 0) + 1, SPOTIFY_TRACKS.length);
    } else if (src === 'MICROSD') {
      state.sdFileIdx = wrapIndex((Number(state.sdFileIdx) || 0) + 1, SD_FILES.length);
    } else {
      var bookIdx = wrapIndex(state.absBookIdx, ABS_BOOKS.length);
      var chIdx = wrapIndex(state.absChapterIdx, ABS_BOOKS[bookIdx].chapters.length);
      if (chIdx + 1 < ABS_BOOKS[bookIdx].chapters.length) {
        state.absChapterIdx = chIdx + 1;
      } else {
        state.absBookIdx = wrapIndex(bookIdx + 1, ABS_BOOKS.length);
        state.absChapterIdx = 0;
      }
    }
    var media = getActiveMedia(state);
    state.positionSec = 0;
    state.durationSec = media.durationSec;

    triggerBounce('np_disc', 6.8);
    triggerBounce('np_title', 5.2);
    triggerBounce('np_playhead', 5.0);

    return media;
  }

  function toggleBookmark(state) {
    if (!state) return { added: false, bookmark: null };
    if (!Array.isArray(state.bookmarks)) state.bookmarks = [];

    var src = getActiveSource(state);
    var media = getActiveMedia(state);
    var activeIdx = getActiveItemIndex(state, src);
    var pos = Math.round(clamp(Number(state.positionSec) || 0, 0, Math.max(1, media.durationSec || 1)));
    var chIdx = src === 'ABS' ? wrapIndex(state.absChapterIdx, ABS_BOOKS[activeIdx].chapters.length) : undefined;
    var chObj = src === 'ABS' ? ABS_BOOKS[activeIdx].chapters[chIdx] : null;

    triggerBounce('np_mark', 7.2);
    triggerBounce('np_disc', 4.6);
    _npLavaFrom = 'mark';
    _npLavaColor = COLORS.coral;
    _npLavaAnim = 0;

    // Remove nearby bookmark if one exists within +-15s
    for (var i = 0; i < state.bookmarks.length; i++) {
      var bm = state.bookmarks[i];
      if (!bm || getBookmarkSource(bm) !== src) continue;
      if (getBookmarkItemIdx(bm) !== activeIdx) continue;
      if (src === 'ABS') {
        var bmCh = getBookmarkChapterIdx(bm);
        if (bmCh !== null && bmCh !== chIdx) continue;
      }
      if (Math.abs(getBookmarkSec(bm) - pos) <= 15) {
        var removed = state.bookmarks.splice(i, 1)[0];
        setToast(state, 'Bookmark removed', COLORS.amber, 1600);
        return { added: false, bookmark: removed };
      }
    }

    var entry = {
      id: 'bm_' + Date.now() + '_' + Math.floor(Math.random() * 1000),
      source: src,
      itemIdx: activeIdx,
      bookIdx: src === 'ABS' ? activeIdx : undefined,
      chapterIdx: src === 'ABS' ? chIdx : undefined,
      chapterNum: chObj ? chObj.num : undefined,
      trackIdx: src === 'SPOTIFY' ? activeIdx : undefined,
      fileIdx: src === 'MICROSD' ? activeIdx : undefined,
      title: media.title,
      subtitle: media.subtitle,
      positionSec: pos,
      sec: pos,
      label: chObj ? ('Ch.' + chObj.num + ' · ' + fmtTime(pos)) : fmtTime(pos),
      createdAt: Date.now(),
    };

    state.bookmarks.push(entry);
    setToast(state, '★ Saved @ ' + fmtTime(pos), COLORS.gold, 1800);
    return { added: true, bookmark: entry };
  }

  function activateLauncher(state, idx) {
    if (!state) return;
    var targetIdx = wrapIndex(idx == null ? state.launcherIdx : idx, 4);
    state.launcherIdx = targetIdx;

    if (targetIdx === 0) {
      state.browseMode = 'BOOKS';
      state.libTabIdx = 0;
      state.libCursor = 0;
      state.libScrollOffset = 0;
      state.libDrill = null;
      state.screen = 'LIBRARY_BROWSER';
    } else if (targetIdx === 1) {
      state.browseMode = 'MUSIC';
      state.libTabIdx = 0;
      state.libCursor = 0;
      state.libScrollOffset = 0;
      state.libDrill = null;
      state.screen = 'LIBRARY_BROWSER';
    } else if (targetIdx === 2) {
      state.browseMode = 'FILES';
      state.libTabIdx = 0;
      state.libCursor = 0;
      state.libScrollOffset = 0;
      state.libDrill = null;
      state.screen = 'LIBRARY_BROWSER';
    } else {
      state.screen = 'VOICE_AI';
    }

    triggerBounce('launcher_' + targetIdx, 6.8);
    triggerBounce('np_disc', 6.4);
    triggerBounce('screen_enter', 5.6);
    triggerBounce('top_home', 5.0);

    return state.screen;
  }

  function getHitboxes() {
    return _lastHitboxes.slice();
  }

  function hitTest(x, y) {
    for (var i = _lastHitboxes.length - 1; i >= 0; i--) {
      var b = _lastHitboxes[i];
      if (x >= b.x && x <= b.x + b.w && y >= b.y && y <= b.y + b.h) {
        return b;
      }
    }
    return null;
  }

  var api = {
    WIDTH: WIDTH,
    HEIGHT: HEIGHT,
    COLORS: COLORS,
    SPEEDS: SPEEDS,
    ABS_BOOKS: ABS_BOOKS,
    SPOTIFY_TRACKS: SPOTIFY_TRACKS,
    SD_FILES: SD_FILES,
    getActiveMedia: getActiveMedia,
    stepSpring: stepSpring,
    triggerBounce: triggerBounce,
    drawLavaBridge: drawLavaBridge,
    drawLivingCircle: drawLivingCircle,
    drawTopStatusBar: drawTopStatusBar,
    drawBottomKeyStrip: drawBottomKeyStrip,
    drawToast: drawToast,
    renderHomeLauncher: renderHomeLauncher,
    renderNowPlaying: renderNowPlaying,
    renderSystemOutputModal: renderSystemOutputModal,
    renderPocketLock: renderPocketLock,
    togglePlay: togglePlay,
    seekRelative: seekRelative,
    cycleSpeed: cycleSpeed,
    prevItem: prevItem,
    nextItem: nextItem,
    toggleBookmark: toggleBookmark,
    activateLauncher: activateLauncher,
    getHitboxes: getHitboxes,
    hitTest: hitTest,
  };

  global.FBoxHomePlayer = api;
  global.FBoxModules = global.FBoxModules || {};
  global.FBoxModules.homePlayer = api;
})(typeof window !== 'undefined' ? window : globalThis);

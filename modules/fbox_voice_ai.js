/* ============================================================================
 * fbox OS — Voice AI & Voice Memo Module (536x240 RM67162 True-Black AMOLED)
 * Self-contained browser <script> module (no ES import/export, file:// safe).
 * Attaches API to window.FBoxVoiceAI and window.FBoxModules.voiceAI.
 * ========================================================================== */
(function (root) {
  'use strict';

  var WIDTH = 536;
  var HEIGHT = 240;

  var COLORS = Object.freeze({
    VOID: '#000000',
    CARD: '#0D1117',
    CARD_ALT: '#111822',
    BORDER: '#1E293B',
    BORDER_FOCUSED: '#334155',
    TEXT_PRIMARY: '#FFFFFF',
    TEXT_SECONDARY: '#94A3B8',
    TEXT_DIM: '#64748B',
    CORAL: '#E0634E',
    CORAL_GLOW: '#FB7185',
    AMBER: '#E3A84B',
    GOLD: '#EBD15E',
    TEAL: '#45B09C',
    BT_CYAN: '#38BDF8',
    WHITE: '#FFFFFF'
  });

  var FONT_SANS = "'SF Pro Text', 'Inter', ui-sans-serif, system-ui, -apple-system, sans-serif";
  var FONT_MONO = "'SF Mono', 'JetBrains Mono', ui-monospace, Menlo, monospace";

  var ORGANISM_CX = 118;
  var ORGANISM_CY = 132;
  var MODE_Y = 42;
  var GEMINI_CX = 288;
  var MEMO_CX = 404;
  var PROMPT_BUBBLE_Y = 198;
  var PROMPT_BUBBLE_XS = [248, 304, 360, 416, 472];
  var REC_BUBBLE_X = 490;
  var REC_BUBBLE_Y = 200;
  var REC_BUBBLE_R = 21;

  var BLOB_PALETTE = [
    COLORS.CORAL,
    COLORS.GOLD,
    COLORS.TEAL,
    COLORS.CORAL_GLOW,
    COLORS.AMBER
  ];

  var PROMPT_PRESETS = [
    {
      id: 'bookmark_scene',
      prompt: 'Bookmark this & explain the scene',
      shortLabel: '1. Bookmark & Scene',
      toolCall: 'abs.addBookmark() + gemini-2.5-flash',
      accent: COLORS.GOLD
    },
    {
      id: 'switch_carl',
      prompt: 'Switch to Dungeon Crawler Carl',
      shortLabel: '2. Dungeon Crawler Carl',
      toolCall: 'abs.loadBook(idx=1) + playback.play()',
      accent: COLORS.AMBER
    },
    {
      id: 'route_bt_tx',
      prompt: 'Route audio to Bluetooth TX earbuds',
      shortLabel: '3. Route BT TX Earbuds',
      toolCall: 'audio.enableBtEmitter(BT_TX)',
      accent: COLORS.BT_CYAN
    },
    {
      id: 'sleep_timer_30',
      prompt: 'Set a 30-minute sleep timer',
      shortLabel: '4. 30m Sleep Timer',
      toolCall: 'power.armSleepTimer(minutes=30)',
      accent: COLORS.CORAL
    },
    {
      id: 'play_cs229',
      prompt: 'Play offline CS229 lecture from MicroSD',
      shortLabel: '5. CS229 Offline SD',
      toolCall: 'sd.openFile("/lectures/CS229_Lec04.mp3")',
      accent: COLORS.TEAL
    }
  ];

  var DEFAULT_VOICE_NOTES = [
    {
      id: 'VN-042',
      title: 'Hail Mary — Xenonite theory',
      linkedTo: 'Project Hail Mary · 24:18',
      durationSec: 1458,
      date: 'Today 14:22'
    },
    {
      id: 'VN-041',
      title: 'CS229 gradient norm derivation',
      linkedTo: 'CS229 Lecture 04 · 07:00',
      durationSec: 84,
      date: 'Today 11:05'
    },
    {
      id: 'VN-040',
      title: 'Chassis P5-Card fit check',
      linkedTo: 'Voice Memo',
      durationSec: 36,
      date: 'Yesterday'
    }
  ];

  var ABS_BOOKS_FALLBACK = [
    { title: 'Project Hail Mary', author: 'Andy Weir', chapter: 'Ch. 4', durationSec: 2340 },
    { title: 'Dungeon Crawler Carl', author: 'Matt Dinniman', chapter: 'Ch. 1', durationSec: 1940 },
    { title: 'Neuromancer', author: 'William Gibson', chapter: 'Ch. 7', durationSec: 1680 }
  ];

  var SD_FILES_FALLBACK = [
    { title: 'CS229 Lecture 04', path: '/lectures/CS229_Backprop_Lec04.mp3', durationSec: 2900 },
    { title: 'Embedded Linux PipeWire', path: '/lectures/Embedded_Linux_PipeWire.mp3', durationSec: 1905 },
    { title: 'Dune Ch.04 Arrakis', path: '/audiobooks/Dune_Ch04_Arrakis.mp3', durationSec: 3850 }
  ];

  // Keep async timers and spring animation state outside plain state objects so state stays JSON-serializable.
  var pendingThinkTimers = typeof WeakMap === 'function' ? new WeakMap() : null;
  var fallbackThinkTimer = null;
  var animStore = typeof WeakMap === 'function' ? new WeakMap() : null;
  var fallbackAnimState = null;

  // Cached runtime probes for optional shared helpers on window.FBoxHomePlayer.
  var springProbeCache = { fn: null, compat: false };
  var bounceProbeCache = { fn: null, compat: false };

  function clamp(v, lo, hi) {
    return v < lo ? lo : v > hi ? hi : v;
  }

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }

  function easeInOutCubic(t) {
    var x = clamp(t, 0, 1);
    return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
  }

  function easeOutBack(t) {
    var x = clamp(t, 0, 1);
    var c1 = 1.70158;
    var c3 = c1 + 1;
    return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
  }

  function pad2(n) {
    var v = Math.floor(Math.max(0, n));
    return v < 10 ? '0' + v : String(v);
  }

  function formatMmSs(sec) {
    var total = Math.max(0, Math.floor(Number(sec) || 0));
    var h = Math.floor(total / 3600);
    var m = Math.floor((total % 3600) / 60);
    var s = total % 60;
    if (h > 0) {
      return h + ':' + pad2(m) + ':' + pad2(s);
    }
    return pad2(m) + ':' + pad2(s);
  }

  function formatRecTimer(ms) {
    var clamped = Math.max(0, Number(ms) || 0);
    var totalTenths = Math.floor(clamped / 100);
    var tenths = totalTenths % 10;
    var totalSec = Math.floor(totalTenths / 10);
    var mins = Math.floor(totalSec / 60);
    var secs = totalSec % 60;
    return pad2(mins) + ':' + pad2(secs) + '.' + tenths;
  }

  function parseHexRgb(hex) {
    if (typeof hex !== 'string' || hex.charAt(0) !== '#') return { r: 255, g: 255, b: 255 };
    var clean = hex.slice(1);
    if (clean.length === 3) {
      clean = clean[0] + clean[0] + clean[1] + clean[1] + clean[2] + clean[2];
    }
    var n = parseInt(clean, 16);
    if (isNaN(n)) return { r: 255, g: 255, b: 255 };
    return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
  }

  function hexToRgba(hex, alpha) {
    var rgb = parseHexRgb(hex);
    return 'rgba(' + rgb.r + ', ' + rgb.g + ', ' + rgb.b + ', ' + alpha + ')';
  }

  function lerpHex(hexA, hexB, t) {
    var k = clamp(t, 0, 1);
    var a = parseHexRgb(hexA);
    var b = parseHexRgb(hexB);
    var r = Math.round(lerp(a.r, b.r, k));
    var g = Math.round(lerp(a.g, b.g, k));
    var bl = Math.round(lerp(a.b, b.b, k));
    return '#' + ((1 << 24) + (r << 16) + (g << 8) + bl).toString(16).slice(1).toUpperCase();
  }

  function clearPendingTimer(state) {
    if (pendingThinkTimers && state && typeof state === 'object') {
      var id = pendingThinkTimers.get(state);
      if (id) {
        clearTimeout(id);
        pendingThinkTimers.delete(state);
      }
    } else if (fallbackThinkTimer) {
      clearTimeout(fallbackThinkTimer);
      fallbackThinkTimer = null;
    }
  }

  function setPendingTimer(state, id) {
    if (pendingThinkTimers && state && typeof state === 'object') {
      pendingThinkTimers.set(state, id);
    } else {
      fallbackThinkTimer = id;
    }
  }

  // --------------------------------------------------------------------------
  // Spring & Lava-Lamp Physics (delegates to FBoxHomePlayer when compatible)
  // --------------------------------------------------------------------------
  function makeSpring(val) {
    return { val: val || 0, vel: 0 };
  }

  function stepSpringLocal(spring, target, dtSec, stiffness, damping) {
    var totalDt = clamp(typeof dtSec === 'number' && isFinite(dtSec) ? dtSec : 0.016, 0, 0.1);
    var k = typeof stiffness === 'number' ? stiffness : 260;
    var d = typeof damping === 'number' ? damping : 18;
    if (totalDt <= 0) return spring.val;
    var steps = Math.max(1, Math.ceil(totalDt / 0.01));
    var h = totalDt / steps;
    for (var s = 0; s < steps; s++) {
      var accel = (target - spring.val) * k - spring.vel * d;
      spring.vel += accel * h;
      spring.val += spring.vel * h;
    }
    return spring.val;
  }

  function stepSpring(spring, target, dtSec, stiffness, damping) {
    var hp = root && root.FBoxHomePlayer;
    if (hp && typeof hp.stepSpring === 'function') {
      if (springProbeCache.fn !== hp.stepSpring) {
        springProbeCache.fn = hp.stepSpring;
        springProbeCache.compat = false;
        try {
          var probe = { val: 0, vel: 0 };
          hp.stepSpring(probe, 10, 0.016, 260, 18);
          if (isFinite(probe.val) && probe.val > 0 && probe.val < 10 && isFinite(probe.vel) && probe.vel !== 0) {
            springProbeCache.compat = true;
          }
        } catch (_err) {
          springProbeCache.compat = false;
        }
      }
      if (springProbeCache.compat) {
        hp.stepSpring(spring, target, dtSec, stiffness, damping);
        if (isFinite(spring.val) && isFinite(spring.vel)) {
          return spring.val;
        }
      }
    }
    return stepSpringLocal(spring, target, dtSec, stiffness, damping);
  }

  function triggerBounce(spring, impulse) {
    if (!spring) return;
    var hp = root && root.FBoxHomePlayer;
    if (hp && typeof hp.triggerBounce === 'function') {
      if (bounceProbeCache.fn !== hp.triggerBounce) {
        bounceProbeCache.fn = hp.triggerBounce;
        bounceProbeCache.compat = false;
        try {
          var probe = { val: 1, vel: 0 };
          hp.triggerBounce(probe, 4);
          if (isFinite(probe.vel) && probe.vel !== 0) {
            bounceProbeCache.compat = true;
          }
        } catch (_err) {
          bounceProbeCache.compat = false;
        }
      }
      if (bounceProbeCache.compat) {
        hp.triggerBounce(spring, impulse);
        return;
      }
    }
    spring.vel = (spring.vel || 0) + (typeof impulse === 'number' ? impulse : 5);
  }

  function drawLavaBridgeLocal(ctx, x1, y1, r1, x2, y2, r2, fillOrHexA, maxSpread, hexB) {
    if (r1 <= 0.5 || r2 <= 0.5) return;
    var dx = x2 - x1;
    var dy = y2 - y1;
    var d = Math.hypot(dx, dy);
    var totalR = r1 + r2;
    var maxDist = typeof maxSpread === 'number' && maxSpread > 0 ? maxSpread : totalR * 2.5;
    if (d <= Math.abs(r1 - r2) + 0.5 || d > maxDist) return;

    var prox = 1 - clamp((d - totalR * 0.9) / Math.max(1, maxDist - totalR * 0.9), 0, 1);
    if (prox <= 0.01) return;

    var u1 = 0;
    var u2 = 0;
    if (d < totalR) {
      u1 = Math.acos(clamp((r1 * r1 + d * d - r2 * r2) / (2 * r1 * d), -1, 1));
      u2 = Math.acos(clamp((r2 * r2 + d * d - r1 * r1) / (2 * r2 * d), -1, 1));
    }

    var angleBetween = Math.atan2(dy, dx);
    var angleSpread = Math.acos(clamp((r1 - r2) / d, -1, 1));
    var sepT = clamp((d - totalR) / Math.max(1, maxDist - totalR), 0, 1);
    var v = 0.52 * (1 - 0.72 * sepT);
    var handleLenRate = 2.4 * (1 - 0.3 * sepT);

    var a1a = angleBetween + u1 + (angleSpread - u1) * v;
    var a1b = angleBetween - u1 - (angleSpread - u1) * v;
    var a2a = angleBetween + Math.PI - u2 - (Math.PI - u2 - angleSpread) * v;
    var a2b = angleBetween - Math.PI + u2 + (Math.PI - u2 - angleSpread) * v;

    var p1ax = x1 + Math.cos(a1a) * r1;
    var p1ay = y1 + Math.sin(a1a) * r1;
    var p1bx = x1 + Math.cos(a1b) * r1;
    var p1by = y1 + Math.sin(a1b) * r1;
    var p2ax = x2 + Math.cos(a2a) * r2;
    var p2ay = y2 + Math.sin(a2a) * r2;
    var p2bx = x2 + Math.cos(a2b) * r2;
    var p2by = y2 + Math.sin(a2b) * r2;

    var d2Base = Math.min(v * handleLenRate, Math.hypot(p1ax - p2ax, p1ay - p2ay) / totalR);
    var d2 = d2Base * Math.min(1, (d * 2) / totalR);
    var h1 = r1 * d2;
    var h2 = r2 * d2;

    var c1ax = p1ax + Math.cos(a1a - Math.PI * 0.5) * h1;
    var c1ay = p1ay + Math.sin(a1a - Math.PI * 0.5) * h1;
    var c2ax = p2ax + Math.cos(a2a + Math.PI * 0.5) * h2;
    var c2ay = p2ay + Math.sin(a2a + Math.PI * 0.5) * h2;
    var c2bx = p2bx + Math.cos(a2b - Math.PI * 0.5) * h2;
    var c2by = p2by + Math.sin(a2b - Math.PI * 0.5) * h2;
    var c1bx = p1bx + Math.cos(a1b + Math.PI * 0.5) * h1;
    var c1by = p1by + Math.sin(a1b + Math.PI * 0.5) * h1;

    ctx.save();
    if (typeof hexB === 'string' && typeof fillOrHexA === 'string' && fillOrHexA !== hexB) {
      var grad = ctx.createLinearGradient(x1, y1, x2, y2);
      grad.addColorStop(0, fillOrHexA);
      grad.addColorStop(1, hexB);
      ctx.fillStyle = grad;
    } else if (fillOrHexA) {
      ctx.fillStyle = fillOrHexA;
    }
    ctx.beginPath();
    ctx.moveTo(p1ax, p1ay);
    ctx.bezierCurveTo(c1ax, c1ay, c2ax, c2ay, p2ax, p2ay);
    ctx.lineTo(p2bx, p2by);
    ctx.bezierCurveTo(c2bx, c2by, c1bx, c1by, p1bx, p1by);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawLavaBridge(ctx, x1, y1, r1, x2, y2, r2, hexA, maxSpread, hexB) {
    var hp = root && root.FBoxHomePlayer;
    if (hp && typeof hp.drawLavaBridge === 'function') {
      var solidColor = typeof hexB === 'string' ? lerpHex(hexA, hexB, 0.5) : hexA;
      ctx.save();
      ctx.fillStyle = solidColor || COLORS.CORAL;
      hp.drawLavaBridge(ctx, x1, y1, r1, x2, y2, r2, solidColor, maxSpread);
      ctx.restore();
      return;
    }
    drawLavaBridgeLocal(ctx, x1, y1, r1, x2, y2, r2, hexA, maxSpread, hexB);
  }

  function createAnimState(state) {
    var mode = state.voiceSubMode === 'VOICE_NOTE' ? 'VOICE_NOTE' : 'GEMINI';
    var pIdx = clamp(Math.floor(Number(state.activePromptIdx) || 0), 0, PROMPT_PRESETS.length - 1);
    var blobs = [];
    for (var i = 0; i < 5; i++) {
      var ang = (i * Math.PI * 2) / 5;
      var dist = i === 0 ? 0 : 22;
      blobs.push({
        x: makeSpring(ORGANISM_CX + Math.cos(ang) * dist),
        y: makeSpring(ORGANISM_CY + Math.sin(ang) * dist),
        r: makeSpring(i === 0 ? 24 : 15)
      });
    }
    var promptScales = [];
    for (var p = 0; p < PROMPT_PRESETS.length; p++) {
      promptScales.push(makeSpring(1));
    }
    var barSprings = [];
    for (var b = 0; b < 16; b++) {
      barSprings.push(makeSpring(0.14));
    }
    return {
      timeSec: 0,
      hasTicked: false,
      lastSubMode: mode,
      modeFrom: mode,
      modeTo: mode,
      modeMorph: 1,
      geminiScale: makeSpring(1),
      memoScale: makeSpring(1),
      lastPromptIdx: pIdx,
      promptFromIdx: pIdx,
      promptToIdx: pIdx,
      promptMorph: 1,
      promptScales: promptScales,
      lastPttPhase: state.pttPhase || 'IDLE',
      lastBadgeText: state.lastAiActionBadge || '',
      orgPop: makeSpring(1),
      badgeScale: makeSpring(1),
      recBubbleScale: makeSpring(1),
      notePillScale: makeSpring(1),
      lastNoteIdx: state.selectedNoteIdx || 0,
      blobs: blobs,
      barSprings: barSprings
    };
  }

  function getAnim(state) {
    if (animStore && state && typeof state === 'object') {
      var entry = animStore.get(state);
      if (!entry) {
        entry = createAnimState(state);
        animStore.set(state, entry);
      }
      return entry;
    }
    if (!fallbackAnimState) {
      fallbackAnimState = createAnimState(state || {});
    }
    return fallbackAnimState;
  }

  function syncAnimTransitions(state, anim) {
    if (state.voiceSubMode !== anim.lastSubMode) {
      anim.modeFrom = anim.lastSubMode;
      anim.modeTo = state.voiceSubMode;
      anim.modeMorph = 0;
      anim.lastSubMode = state.voiceSubMode;
      triggerBounce(state.voiceSubMode === 'GEMINI' ? anim.geminiScale : anim.memoScale, 4.6);
      triggerBounce(anim.orgPop, 2.2);
    }
    if (state.activePromptIdx !== anim.lastPromptIdx) {
      anim.promptFromIdx = anim.lastPromptIdx;
      anim.promptToIdx = state.activePromptIdx;
      anim.promptMorph = 0;
      anim.lastPromptIdx = state.activePromptIdx;
      if (anim.promptScales[state.activePromptIdx]) {
        triggerBounce(anim.promptScales[state.activePromptIdx], 5.4);
      }
    }
    if (state.pttPhase !== anim.lastPttPhase) {
      if (state.pttPhase === 'RESPONSE') {
        triggerCelebrationBounce(anim);
      } else if (state.pttPhase === 'LISTENING') {
        triggerBounce(anim.orgPop, -2.8);
      }
      anim.lastPttPhase = state.pttPhase;
    }
    if ((state.lastAiActionBadge || '') !== anim.lastBadgeText) {
      anim.lastBadgeText = state.lastAiActionBadge || '';
      triggerBounce(anim.badgeScale, 4.0);
    }
    if (state.selectedNoteIdx !== anim.lastNoteIdx) {
      anim.lastNoteIdx = state.selectedNoteIdx;
      triggerBounce(anim.notePillScale, 3.8);
    }
  }

  function triggerCelebrationBounce(anim) {
    triggerBounce(anim.orgPop, 5.4);
    triggerBounce(anim.badgeScale, 4.2);
    for (var i = 0; i < anim.blobs.length; i++) {
      triggerBounce(anim.blobs[i].r, 18 + (i % 3) * 6);
    }
  }

  function computeOrganismTargets(state, t) {
    var phase = state.pttPhase || 'IDLE';
    var isMemo = state.voiceSubMode === 'VOICE_NOTE';
    var targets = [];
    var i;

    if (phase === 'LISTENING') {
      var rms = state.micRmsHistory;
      var sum = 0;
      var bands = [0, 0, 0, 0, 0];
      var counts = [0, 0, 0, 0, 0];
      for (var k = 0; k < rms.length; k++) {
        var v = clamp(rms[k] || 0.08, 0.05, 1);
        sum += v;
        var bIdx = Math.min(4, Math.floor((k * 5) / rms.length));
        bands[bIdx] += v;
        counts[bIdx] += 1;
      }
      var avgE = sum / Math.max(1, rms.length);
      for (i = 0; i < 5; i++) {
        bands[i] = counts[i] ? bands[i] / counts[i] : avgE;
      }

      targets.push({
        x: ORGANISM_CX + Math.sin(t * 5.2) * (3 + avgE * 5),
        y: ORGANISM_CY + Math.cos(t * 4.7) * (3 + avgE * 5),
        r: 22 + avgE * 14
      });
      for (i = 1; i < 5; i++) {
        var e = bands[i];
        var ang = t * 1.55 + (i - 1) * (Math.PI * 0.5) + Math.sin(t * 3.8 + i * 1.3) * 0.36;
        var dist = 18 + e * 38;
        targets.push({
          x: ORGANISM_CX + Math.cos(ang) * dist,
          y: ORGANISM_CY + Math.sin(ang) * dist,
          r: 12 + e * 10.5
        });
      }
      return targets;
    }

    if (phase === 'THINKING') {
      targets.push({
        x: ORGANISM_CX + Math.cos(-t * 4.6) * 5,
        y: ORGANISM_CY + Math.sin(-t * 4.6) * 5,
        r: 16.5 + Math.sin(t * 7.5) * 2
      });
      for (i = 1; i < 5; i++) {
        var vortexAng = t * 5.4 + (i - 1) * (Math.PI * 0.5);
        var vortexDist = 23 + Math.sin(t * 7.0 + i * 1.4) * 5.5;
        targets.push({
          x: ORGANISM_CX + Math.cos(vortexAng) * vortexDist,
          y: ORGANISM_CY + Math.sin(vortexAng) * vortexDist,
          r: 13 + Math.cos(t * 6.4 + i) * 2.5
        });
      }
      return targets;
    }

    if (phase === 'RESPONSE') {
      targets.push({
        x: ORGANISM_CX + Math.sin(t * 1.2) * 3,
        y: ORGANISM_CY + Math.cos(t * 1.5) * 3,
        r: 25 + Math.sin(t * 2.2) * 2
      });
      for (i = 1; i < 5; i++) {
        var cAng = t * 0.65 + (i - 1) * (Math.PI * 0.5) + 0.35;
        var cDist = 23 + Math.sin(t * 2.0 + i * 1.5) * 4;
        targets.push({
          x: ORGANISM_CX + Math.cos(cAng) * cDist,
          y: ORGANISM_CY + Math.sin(cAng) * cDist,
          r: 16.5 + Math.sin(t * 2.4 + i) * 1.8
        });
      }
      return targets;
    }

    // IDLE: gentle lazy breathing orbit on pure #000000
    targets.push({
      x: ORGANISM_CX + Math.sin(t * 0.65) * 5,
      y: ORGANISM_CY + Math.cos(t * 0.85) * 5,
      r: (isMemo ? 22 : 24) + Math.sin(t * 1.35) * 2.8
    });
    for (i = 1; i < 5; i++) {
      var idleAng = t * (0.48 + (i % 2) * 0.14) + i * 1.57 + Math.sin(t * 0.7 + i) * 0.25;
      var idleDist = 22 + Math.sin(t * 0.95 + i * 1.7) * 9;
      targets.push({
        x: ORGANISM_CX + Math.cos(idleAng) * idleDist,
        y: ORGANISM_CY + Math.sin(idleAng) * idleDist,
        r: 14 + Math.cos(t * 1.15 + i * 1.2) * 2.4
      });
    }
    return targets;
  }

  // --------------------------------------------------------------------------
  // State Normalization & Mutators (Public API Preserved)
  // --------------------------------------------------------------------------
  function cloneDefaultNotes() {
    return DEFAULT_VOICE_NOTES.map(function (n) {
      return {
        id: n.id,
        title: n.title,
        linkedTo: n.linkedTo,
        durationSec: n.durationSec,
        date: n.date
      };
    });
  }

  function makeSeededRmsHistory(baseLevel) {
    var arr = new Array(32);
    var level = typeof baseLevel === 'number' ? baseLevel : 0.16;
    for (var i = 0; i < 32; i++) {
      var centerWeight = 1 - Math.abs(i - 15.5) / 19;
      arr[i] = clamp(level * (0.55 + centerWeight * 0.75) + Math.sin(i * 0.7) * 0.04, 0.05, 0.96);
    }
    return arr;
  }

  function ensureState(state) {
    if (!state || typeof state !== 'object') {
      state = {};
    }
    if (state.voiceSubMode !== 'GEMINI' && state.voiceSubMode !== 'VOICE_NOTE') {
      state.voiceSubMode = 'GEMINI';
    }
    if (
      state.pttPhase !== 'IDLE' &&
      state.pttPhase !== 'LISTENING' &&
      state.pttPhase !== 'THINKING' &&
      state.pttPhase !== 'RESPONSE'
    ) {
      state.pttPhase = 'IDLE';
    }
    if (typeof state.pttHoldMs !== 'number' || isNaN(state.pttHoldMs)) {
      state.pttHoldMs = 0;
    }
    if (!Array.isArray(state.micRmsHistory) || state.micRmsHistory.length !== 32) {
      state.micRmsHistory = makeSeededRmsHistory(0.14);
    }
    if (typeof state.activePromptIdx !== 'number' || isNaN(state.activePromptIdx)) {
      state.activePromptIdx = 0;
    } else {
      state.activePromptIdx =
        ((Math.floor(state.activePromptIdx) % PROMPT_PRESETS.length) + PROMPT_PRESETS.length) %
        PROMPT_PRESETS.length;
    }
    if (typeof state.lastTranscript !== 'string') {
      state.lastTranscript = '';
    }
    if (typeof state.lastAiResponse !== 'string') {
      state.lastAiResponse = '';
    }
    if (typeof state.lastAiActionBadge !== 'string') {
      state.lastAiActionBadge = '';
    }
    if (!Array.isArray(state.voiceNotes)) {
      state.voiceNotes = cloneDefaultNotes();
    }
    if (!Array.isArray(state.bookmarks)) {
      state.bookmarks = [];
    }
    if (typeof state.selectedNoteIdx !== 'number' || isNaN(state.selectedNoteIdx)) {
      state.selectedNoteIdx = 0;
    }
    if (state.voiceNotes.length > 0) {
      state.selectedNoteIdx = clamp(Math.floor(state.selectedNoteIdx), 0, state.voiceNotes.length - 1);
    } else {
      state.selectedNoteIdx = 0;
    }
    if (state.playingNoteId === undefined) {
      state.playingNoteId = null;
    }
    if (typeof state.notePlayProgress !== 'number' || isNaN(state.notePlayProgress)) {
      state.notePlayProgress = 0;
    }
    return state;
  }

  function nextVoiceNoteId(voiceNotes) {
    var maxNum = 42;
    if (Array.isArray(voiceNotes)) {
      for (var i = 0; i < voiceNotes.length; i++) {
        var idStr = voiceNotes[i] && voiceNotes[i].id ? String(voiceNotes[i].id) : '';
        var match = idStr.match(/(\d+)/);
        if (match) {
          var num = parseInt(match[1], 10);
          if (!isNaN(num) && num > maxNum) {
            maxNum = num;
          }
        }
      }
    }
    var next = maxNum + 1;
    return 'VN-' + (next < 100 ? '0' + next : String(next));
  }

  function notifyToast(state, helpers, message, tone) {
    if (helpers && typeof helpers.triggerToast === 'function') {
      helpers.triggerToast(message, tone || 'info');
      return;
    }
    state.toast = {
      text: message,
      message: message,
      tone: tone || 'info',
      until: Date.now() + 2600
    };
  }

  function playEarconSafe(helpers, type) {
    if (helpers && typeof helpers.playEarcon === 'function') {
      try {
        helpers.playEarcon(type);
      } catch (_err) {
        // Ignore browser audio autoplay errors cleanly
      }
    }
  }

  function getActiveMediaLabel(state, helpers) {
    var src = state.activeSource || 'ABS';
    var pos = formatMmSs(state.positionSec || 0);
    if (src === 'MICROSD') {
      var sdList = (helpers && Array.isArray(helpers.sdFiles) && helpers.sdFiles) || SD_FILES_FALLBACK;
      var sdItem = sdList[state.sdFileIdx || 0] || sdList[0];
      return (sdItem.shortTitle || sdItem.title || 'MicroSD Track') + ' · ' + pos;
    }
    if (src === 'SPOTIFY') {
      var trackTitle = state.spotifyTitle || 'Spotify';
      return trackTitle + ' · ' + pos;
    }
    var absList = (helpers && Array.isArray(helpers.absBooks) && helpers.absBooks) || ABS_BOOKS_FALLBACK;
    var book = absList[state.absBookIdx || 0] || absList[0];
    return (book.title || 'Audiobook') + ' · ' + pos;
  }

  function getDurationForBook(bookIdx, chapterIdx, helpers, fallback) {
    if (helpers && Array.isArray(helpers.absBooks) && helpers.absBooks[bookIdx]) {
      var bk = helpers.absBooks[bookIdx];
      if (Array.isArray(bk.chapters) && bk.chapters[chapterIdx] && typeof bk.chapters[chapterIdx].durationSec === 'number') {
        return bk.chapters[chapterIdx].durationSec;
      }
      if (typeof bk.durationSec === 'number') {
        return bk.durationSec;
      }
    }
    var fb = ABS_BOOKS_FALLBACK[bookIdx];
    return fb ? fb.durationSec : fallback;
  }

  function getDurationForSd(fileIdx, helpers, fallback) {
    if (helpers && Array.isArray(helpers.sdFiles) && helpers.sdFiles[fileIdx]) {
      var f = helpers.sdFiles[fileIdx];
      if (typeof f.durationSec === 'number') return f.durationSec;
      if (typeof f.duration === 'number') return f.duration;
    }
    var fb = SD_FILES_FALLBACK[fileIdx];
    return fb ? fb.durationSec : fallback;
  }

  function isPositionBookmarked(bookmarks, posSec, source) {
    for (var i = 0; i < bookmarks.length; i++) {
      var b = bookmarks[i];
      if (typeof b === 'number') {
        if (Math.abs(b - posSec) <= 2) return true;
      } else if (b && typeof b === 'object') {
        var bPos = typeof b.positionSec === 'number'
          ? b.positionSec
          : typeof b.sec === 'number'
            ? b.sec
            : typeof b.time === 'number'
              ? b.time
              : -999;
        var sameSource = !b.source || !source || b.source === source;
        if (sameSource && Math.abs(bPos - posSec) <= 2) {
          return true;
        }
      }
    }
    return false;
  }

  function toggleSubMode(state, helpers) {
    ensureState(state);
    clearPendingTimer(state);
    if (state.pttPhase === 'LISTENING' || state.pttPhase === 'THINKING') {
      state.pttPhase = 'IDLE';
      state.pttHoldMs = 0;
    }
    state.voiceSubMode = state.voiceSubMode === 'GEMINI' ? 'VOICE_NOTE' : 'GEMINI';
    syncAnimTransitions(state, getAnim(state));
    playEarconSafe(helpers, 'click');
    return state.voiceSubMode;
  }

  function startPtt(state, helpers) {
    ensureState(state);
    clearPendingTimer(state);
    state.pttPhase = 'LISTENING';
    state.pttHoldMs = 0;
    state.thinkingElapsedMs = 0;
    state.playingNoteId = null;
    state.micRmsHistory = makeSeededRmsHistory(0.24);
    var anim = getAnim(state);
    syncAnimTransitions(state, anim);
    triggerBounce(anim.recBubbleScale, 4.4);
    playEarconSafe(helpers, 'ptt_start');
    return state;
  }

  function tickVoiceAI(state, dtMs) {
    ensureState(state);
    var dt = typeof dtMs === 'number' && !isNaN(dtMs) ? Math.max(0, dtMs) : 16.67;
    var dtSec = dt * 0.001;
    state._voiceAnimMs = (state._voiceAnimMs || 0) + dt;

    var anim = getAnim(state);
    anim.hasTicked = true;
    anim.timeSec += dtSec;
    syncAnimTransitions(state, anim);

    if (state.pttPhase === 'LISTENING') {
      state.pttHoldMs += dt;
      var t = state.pttHoldMs * 0.001;
      var syllable = 0.52 + 0.48 * Math.sin(t * 11.4 + Math.sin(t * 3.1) * 1.4);
      var cadence = 0.65 + 0.35 * Math.sin(t * 2.9);
      var speechEnergy = clamp(syllable * cadence, 0.12, 0.96);

      for (var i = 0; i < 32; i++) {
        var normIdx = i / 31;
        var formantA = Math.exp(-Math.pow((normIdx - 0.28) / 0.22, 2));
        var formantB = 0.62 * Math.exp(-Math.pow((normIdx - 0.64) / 0.18, 2));
        var ripple = 0.5 + 0.5 * Math.sin(t * 16.5 + i * 0.72 + Math.cos(t * 5.2 + i * 0.3));
        var target = clamp(0.12 + speechEnergy * (0.45 * formantA + 0.35 * formantB + 0.3 * ripple), 0.06, 0.98);
        var prev = typeof state.micRmsHistory[i] === 'number' ? state.micRmsHistory[i] : 0.15;
        state.micRmsHistory[i] = prev * 0.5 + target * 0.5;
      }
    } else if (state.pttPhase === 'THINKING') {
      state.thinkingElapsedMs = (state.thinkingElapsedMs || 0) + dt;
    }

    if (state.playingNoteId && state.pttPhase !== 'LISTENING') {
      var playingNote = null;
      for (var j = 0; j < state.voiceNotes.length; j++) {
        if (state.voiceNotes[j].id === state.playingNoteId) {
          playingNote = state.voiceNotes[j];
          break;
        }
      }
      if (!playingNote) {
        state.playingNoteId = null;
        state.notePlayProgress = 0;
      } else {
        var previewDurSec = clamp(Number(playingNote.durationSec) || 8, 2, 16);
        state.notePlayProgress += dtSec / previewDurSec;
        if (state.notePlayProgress >= 1) {
          state.playingNoteId = null;
          state.notePlayProgress = 0;
        }
      }
    }

    // Advance morph bridges (0.3s mode morph, 0.28s prompt bridge morph)
    if (anim.modeMorph < 1) {
      anim.modeMorph = clamp(anim.modeMorph + dtSec / 0.3, 0, 1);
    }
    if (anim.promptMorph < 1) {
      anim.promptMorph = clamp(anim.promptMorph + dtSec / 0.28, 0, 1);
    }

    // Step UI springs
    stepSpring(anim.geminiScale, 1, dtSec, 320, 16);
    stepSpring(anim.memoScale, 1, dtSec, 320, 16);
    stepSpring(anim.orgPop, 1, dtSec, 290, 13);
    stepSpring(anim.badgeScale, 1, dtSec, 300, 16);
    stepSpring(anim.recBubbleScale, 1, dtSec, 300, 15);
    stepSpring(anim.notePillScale, 1, dtSec, 320, 16);

    for (var p = 0; p < anim.promptScales.length; p++) {
      stepSpring(anim.promptScales[p], 1, dtSec, 340, 15);
    }

    // Step 16 spectrum pill springs from micRmsHistory
    for (var b = 0; b < 16; b++) {
      var rawL = state.micRmsHistory[b * 2] || 0.1;
      var rawR = state.micRmsHistory[b * 2 + 1] || 0.1;
      var barTarget = state.pttPhase === 'LISTENING' ? clamp((rawL + rawR) * 0.5, 0.06, 1) : 0.1;
      stepSpring(anim.barSprings[b], barTarget, dtSec, 340, 18);
    }

    // Step 5 organism blob springs
    var blobTargets = computeOrganismTargets(state, anim.timeSec);
    var isFastPhase = state.pttPhase === 'LISTENING' || state.pttPhase === 'THINKING';
    var blobStiff = isFastPhase ? 310 : 150;
    var blobDamp = isFastPhase ? 15 : 13;
    for (var bi = 0; bi < 5; bi++) {
      stepSpring(anim.blobs[bi].x, blobTargets[bi].x, dtSec, blobStiff, blobDamp);
      stepSpring(anim.blobs[bi].y, blobTargets[bi].y, dtSec, blobStiff, blobDamp);
      stepSpring(anim.blobs[bi].r, blobTargets[bi].r, dtSec, blobStiff + 40, blobDamp);
    }

    return state;
  }

  function triggerPresetPrompt(state, idx, helpers, customTranscript) {
    ensureState(state);
    var safeIdx = ((Math.floor(Number(idx) || 0) % PROMPT_PRESETS.length) + PROMPT_PRESETS.length) % PROMPT_PRESETS.length;
    state.activePromptIdx = safeIdx;
    var preset = PROMPT_PRESETS[safeIdx];
    var spoken = typeof customTranscript === 'string' && customTranscript.trim()
      ? customTranscript.trim()
      : preset.prompt;

    if (safeIdx === 0) {
      var posSec = Math.max(0, Math.floor(Number(state.positionSec) || 0));
      var mmss = formatMmSs(posSec);
      var src = state.activeSource || 'ABS';
      if (!isPositionBookmarked(state.bookmarks, posSec, src)) {
        if (state.bookmarks.length > 0 && typeof state.bookmarks[0] === 'number') {
          state.bookmarks.push(posSec);
        } else {
          state.bookmarks.push({
            id: 'bm-' + posSec,
            source: src,
            bookIdx: state.absBookIdx || 0,
            chapterIdx: state.absChapterIdx || 0,
            fileIdx: state.sdFileIdx || 0,
            positionSec: posSec,
            sec: posSec,
            timeStr: mmss,
            label: (src === 'ABS' ? 'Ch.' + ((state.absChapterIdx || 0) + 1) : src) + ' · ' + mmss
          });
        }
      }
      state.lastAiActionBadge = '✓ Bookmark ' + mmss;
      if (src === 'ABS' && state.absBookIdx === 1) {
        state.lastAiResponse =
          'Bookmarked ' + mmss + '. Carl and Princess Donut clear the First Floor safe room while Mordecai explains the loot modifiers.';
      } else {
        state.lastAiResponse =
          'Saved bookmark at ' + mmss + '. Ryland Grace isolates the black Astrophage fuel anomaly near Tau Ceti as hull sensors spike.';
      }
    } else if (safeIdx === 1) {
      state.activeSource = 'ABS';
      state.absBookIdx = 1;
      state.absChapterIdx = 0;
      state.positionSec = 185;
      state.playing = true;
      state.durationSec = getDurationForBook(1, 0, helpers, 1940);
      state.lastAiActionBadge = '▶ Carl · Ch.1';
      state.lastAiResponse =
        'Playing Dungeon Crawler Carl, Ch. 1 at 03:05 via ' +
        (state.btTxOn ? 'Bluetooth earbuds.' : 'wired headphones.');
    } else if (safeIdx === 2) {
      state.btTxOn = true;
      state.lastAiActionBadge = '◉ BT TX Active';
      state.lastAiResponse =
        'Switched audio output to Bluetooth TX. Streaming wirelessly to your paired earbuds.';
    } else if (safeIdx === 3) {
      state.sleepTimerMin = 30;
      state.lastAiActionBadge = '◷ Sleep Timer · 30m';
      state.lastAiResponse =
        'Armed 30-minute sleep timer. Audio will gently fade out when time is up.';
    } else if (safeIdx === 4) {
      state.activeSource = 'MICROSD';
      state.sdFileIdx = 0;
      state.positionSec = 420;
      state.playing = true;
      state.durationSec = getDurationForSd(0, helpers, 2900);
      state.lastAiActionBadge = '♪ CS229 Offline';
      state.lastAiResponse =
        'Playing CS229 Lecture 04 (Backprop & LayerNorm) offline from MicroSD at 07:00.';
    }

    state.lastTranscript = spoken;
    state.pttPhase = 'RESPONSE';

    var anim = getAnim(state);
    syncAnimTransitions(state, anim);
    triggerCelebrationBounce(anim);
    if (anim.promptScales[safeIdx]) {
      triggerBounce(anim.promptScales[safeIdx], 5.8);
    }

    notifyToast(state, helpers, state.lastAiActionBadge, preset.accent);
    playEarconSafe(helpers, safeIdx === 0 ? 'bookmark' : 'switch');
    return {
      transcript: state.lastTranscript,
      badge: state.lastAiActionBadge,
      response: state.lastAiResponse
    };
  }

  function matchPresetIdxForText(rawText) {
    var q = String(rawText || '').toLowerCase();
    if (!q) return -1;
    if (q.indexOf('bookmark') !== -1 || q.indexOf('explain') !== -1 || q.indexOf('scene') !== -1) {
      return 0;
    }
    if (q.indexOf('dungeon') !== -1 || q.indexOf('carl') !== -1) {
      return 1;
    }
    if (q.indexOf('bluetooth') !== -1 || q.indexOf('earbud') !== -1 || q.indexOf('bt tx') !== -1) {
      return 2;
    }
    if (q.indexOf('sleep') !== -1 || q.indexOf('timer') !== -1) {
      return 3;
    }
    if (q.indexOf('cs229') !== -1 || q.indexOf('lecture') !== -1 || q.indexOf('microsd') !== -1 || q.indexOf('sd') !== -1) {
      return 4;
    }
    return -1;
  }

  function handleCustomPrompt(state, rawText, helpers) {
    ensureState(state);
    var spoken = String(rawText || '').trim();
    if (!spoken) {
      return triggerPresetPrompt(state, state.activePromptIdx, helpers);
    }
    var q = spoken.toLowerCase();
    var matchedIdx = matchPresetIdxForText(q);

    if (matchedIdx === 3) {
      var mMin = q.match(/(\d{1,3})\s*(?:min|minute|m\b)/);
      if (mMin && Number(mMin[1]) > 0) {
        var mins = clamp(Number(mMin[1]), 1, 240);
        state.sleepTimerMin = mins;
        state.lastTranscript = spoken;
        state.lastAiActionBadge = '◷ Sleep Timer · ' + mins + 'm';
        state.lastAiResponse =
          'Armed ' + mins + '-minute sleep timer. Playback will fade out cleanly when time is up.';
        state.pttPhase = 'RESPONSE';
        var animMin = getAnim(state);
        syncAnimTransitions(state, animMin);
        triggerCelebrationBounce(animMin);
        notifyToast(state, helpers, state.lastAiActionBadge, COLORS.CORAL);
        playEarconSafe(helpers, 'switch');
        return { transcript: spoken, badge: state.lastAiActionBadge, response: state.lastAiResponse };
      }
    }
    if (matchedIdx !== -1) {
      return triggerPresetPrompt(state, matchedIdx, helpers, spoken);
    }

    if (q.indexOf('pause') !== -1 || q.indexOf('stop') !== -1) {
      state.playing = false;
      state.lastAiActionBadge = '⏸ Paused';
      state.lastAiResponse = 'Paused ' + getActiveMediaLabel(state, helpers) + '. Press B7 or ask to resume anytime.';
    } else if (q.indexOf('play') !== -1 || q.indexOf('resume') !== -1) {
      state.playing = true;
      state.lastAiActionBadge = '▶ Resumed';
      state.lastAiResponse = 'Resumed ' + getActiveMediaLabel(state, helpers) + ' over ' + (state.btTxOn ? 'Bluetooth.' : 'wired headphones.');
    } else if (q.indexOf('wired') !== -1 || q.indexOf('3.5') !== -1 || q.indexOf('jack') !== -1) {
      state.btTxOn = false;
      state.lastAiActionBadge = '◉ Wired 3.5mm';
      state.lastAiResponse = 'Switched audio output to wired 3.5mm headphones.';
    } else {
      var volMatch = q.match(/vol(?:ume)?\s*(\d{1,3})/);
      if (volMatch) {
        state.volume = clamp(parseInt(volMatch[1], 10), 0, 100);
        state.lastAiActionBadge = '♪ Volume · ' + state.volume + '%';
        state.lastAiResponse = 'Set output volume to ' + state.volume + '%.';
      } else {
        state.lastAiActionBadge = '✦ Gemini Ready';
        state.lastAiResponse =
          'Playing ' + getActiveMediaLabel(state, helpers) + ' · ' +
          state.voiceNotes.length + ' voice memos saved.';
      }
    }

    state.lastTranscript = spoken;
    state.pttPhase = 'RESPONSE';
    var anim = getAnim(state);
    syncAnimTransitions(state, anim);
    triggerCelebrationBounce(anim);

    notifyToast(state, helpers, state.lastAiActionBadge, COLORS.TEAL);
    playEarconSafe(helpers, 'switch');
    return {
      transcript: state.lastTranscript,
      badge: state.lastAiActionBadge,
      response: state.lastAiResponse
    };
  }

  function finishPttRelease(state, helpers, customTranscript) {
    ensureState(state);
    if (state.pttPhase !== 'LISTENING') {
      return null;
    }
    clearPendingTimer(state);

    if (state.voiceSubMode === 'VOICE_NOTE') {
      var id = nextVoiceNoteId(state.voiceNotes);
      var holdSec = Number(Math.max(1, (state.pttHoldMs || 2400) / 1000).toFixed(1));
      var linkedTo = getActiveMediaLabel(state, helpers);
      var now = new Date();
      var timeLabel = 'Today ' + pad2(now.getHours()) + ':' + pad2(now.getMinutes());
      var spokenTitle =
        typeof customTranscript === 'string' && customTranscript.trim()
          ? customTranscript.trim()
          : (state.activeSource === 'MICROSD'
              ? 'Study note · ' + formatMmSs(state.positionSec || 0)
              : state.activeSource === 'SPOTIFY'
                ? 'Listening memo · ' + formatMmSs(state.positionSec || 0)
                : 'Scene memo · Ch.' + ((state.absChapterIdx || 0) + 1) + ' @ ' + formatMmSs(state.positionSec || 0));

      var note = {
        id: id,
        title: spokenTitle,
        linkedTo: linkedTo,
        durationSec: holdSec,
        date: timeLabel
      };
      state.voiceNotes.unshift(note);
      state.selectedNoteIdx = 0;
      state.playingNoteId = null;
      state.notePlayProgress = 0;
      state.pttPhase = 'RESPONSE';

      var animNote = getAnim(state);
      syncAnimTransitions(state, animNote);
      triggerCelebrationBounce(animNote);
      triggerBounce(animNote.recBubbleScale, 4.8);
      triggerBounce(animNote.notePillScale, 4.4);

      notifyToast(state, helpers, 'Saved ' + id + ' (' + formatMmSs(Math.round(holdSec)) + ')', COLORS.AMBER);
      playEarconSafe(helpers, 'bookmark');
      return note;
    }

    // GEMINI mode: LISTENING -> THINKING -> (~750ms) RESPONSE + execute action
    var pendingText =
      typeof customTranscript === 'string' && customTranscript.trim()
        ? customTranscript.trim()
        : typeof state.pendingTranscript === 'string' && state.pendingTranscript.trim()
          ? state.pendingTranscript.trim()
          : '';
    if (state.pendingTranscript) {
      state.pendingTranscript = '';
    }

    var preset = PROMPT_PRESETS[state.activePromptIdx] || PROMPT_PRESETS[0];
    state.lastTranscript = pendingText || preset.prompt;
    state.pttPhase = 'THINKING';
    state.thinkingElapsedMs = 0;
    syncAnimTransitions(state, getAnim(state));
    playEarconSafe(helpers, 'ptt_send');

    var targetIdx = state.activePromptIdx;
    var timerId = setTimeout(function () {
      if (pendingThinkTimers) {
        pendingThinkTimers.delete(state);
      } else {
        fallbackThinkTimer = null;
      }
      if (state.pttPhase !== 'THINKING') {
        return;
      }
      if (pendingText) {
        handleCustomPrompt(state, pendingText, helpers);
      } else {
        triggerPresetPrompt(state, targetIdx, helpers);
      }
      if (helpers && typeof helpers.requestRender === 'function') {
        helpers.requestRender();
      }
    }, 750);

    setPendingTimer(state, timerId);
    return state;
  }

  function cancelPtt(state) {
    ensureState(state);
    clearPendingTimer(state);
    if (state.pttPhase === 'LISTENING' || state.pttPhase === 'THINKING') {
      state.pttPhase = state.lastAiResponse ? 'RESPONSE' : 'IDLE';
      state.pttHoldMs = 0;
      syncAnimTransitions(state, getAnim(state));
    }
    return state;
  }

  function cycleSelection(state, delta, helpers) {
    ensureState(state);
    var step = Number(delta) || 0;
    if (!step) return;
    if (state.voiceSubMode === 'VOICE_NOTE') {
      var len = state.voiceNotes.length;
      if (len > 0) {
        state.selectedNoteIdx = ((state.selectedNoteIdx + step) % len + len) % len;
      }
    } else {
      var pLen = PROMPT_PRESETS.length;
      state.activePromptIdx = ((state.activePromptIdx + step) % pLen + pLen) % pLen;
    }
    syncAnimTransitions(state, getAnim(state));
    playEarconSafe(helpers, 'click');
  }

  function toggleNotePreview(state, idx, helpers) {
    ensureState(state);
    if (!state.voiceNotes.length) return null;
    var safeIdx =
      typeof idx === 'number'
        ? clamp(Math.floor(idx), 0, state.voiceNotes.length - 1)
        : state.selectedNoteIdx;
    state.selectedNoteIdx = safeIdx;
    var note = state.voiceNotes[safeIdx];
    if (state.playingNoteId === note.id) {
      state.playingNoteId = null;
      state.notePlayProgress = 0;
    } else {
      state.playingNoteId = note.id;
      state.notePlayProgress = 0;
      notifyToast(state, helpers, '▶ ' + note.title, COLORS.AMBER);
    }
    var anim = getAnim(state);
    syncAnimTransitions(state, anim);
    triggerBounce(anim.notePillScale, 4.2);
    playEarconSafe(helpers, 'click');
    return note;
  }

  function triggerPrimaryAction(state, helpers) {
    ensureState(state);
    if (state.pttPhase === 'LISTENING') {
      return finishPttRelease(state, helpers);
    }
    if (state.voiceFocusLayer === 'MODE') {
      return toggleSubMode(state, helpers);
    }
    if (state.voiceSubMode === 'VOICE_NOTE') {
      return toggleNotePreview(state, state.selectedNoteIdx, helpers);
    }
    return triggerPresetPrompt(state, state.activePromptIdx, helpers);
  }

  function handlePointerTap(x, y, state, helpers) {
    ensureState(state);
    var anim = getAnim(state);

    // 1. Top Mode Switcher bubbles (y = 28..58; leaves y = 0..27 clear for top status bar)
    if (y >= 28 && y <= 58) {
      if (x >= 236 && x <= 340) {
        if (state.voiceSubMode !== 'GEMINI') {
          toggleSubMode(state, helpers);
        } else {
          triggerBounce(anim.geminiScale, 4.4);
          playEarconSafe(helpers, 'click');
        }
        return true;
      }
      if (x >= 352 && x <= 456) {
        if (state.voiceSubMode !== 'VOICE_NOTE') {
          toggleSubMode(state, helpers);
        } else {
          triggerBounce(anim.memoScale, 4.4);
          playEarconSafe(helpers, 'click');
        }
        return true;
      }
    }

    // 2. While LISTENING: tap right waveform/action area to finish & send/save; poke organism to bounce
    if (state.pttPhase === 'LISTENING') {
      if (x >= 220 && y >= 60) {
        finishPttRelease(state, helpers);
        return true;
      }
      if (Math.hypot(x - ORGANISM_CX, y - ORGANISM_CY) <= 68) {
        triggerBounce(anim.orgPop, 4.0);
        return true;
      }
      return false;
    }

    // 3. IDLE / RESPONSE interactions
    if (state.pttPhase === 'IDLE' || state.pttPhase === 'RESPONSE') {
      if (state.voiceSubMode === 'GEMINI') {
        // 5 Circular Prompt Bubbles at y=198, x=[248, 304, 360, 416, 472]
        for (var p = 0; p < PROMPT_BUBBLE_XS.length; p++) {
          if (Math.hypot(x - PROMPT_BUBBLE_XS[p], y - PROMPT_BUBBLE_Y) <= 24) {
            triggerPresetPrompt(state, p, helpers);
            return true;
          }
        }
        // Tapping selected prompt label at y=166 re-triggers it
        if (x >= 224 && x <= 522 && y >= 152 && y <= 178) {
          triggerPresetPrompt(state, state.activePromptIdx, helpers);
          return true;
        }
        // Tapping organism starts PTT listening
        if (Math.hypot(x - ORGANISM_CX, y - ORGANISM_CY) <= 66) {
          startPtt(state, helpers);
          return true;
        }
      } else {
        // VOICE_NOTE mode: vibrant Coral REC bubble at (490, 200)
        if (Math.hypot(x - REC_BUBBLE_X, y - REC_BUBBLE_Y) <= 27) {
          startPtt(state, helpers);
          return true;
        }
        // Minimalist memo capsules (up to 3 visible at y=66, 103, 140)
        var notes = state.voiceNotes;
        if (x >= 222 && x <= 522 && y >= 64 && y <= 180 && notes.length > 0) {
          var maxVis = 3;
          var startIdx = clamp(state.selectedNoteIdx - 1, 0, Math.max(0, notes.length - maxVis));
          var rel = Math.floor((y - 66) / 37);
          var hitIdx = startIdx + rel;
          if (rel >= 0 && rel < maxVis && hitIdx >= 0 && hitIdx < notes.length) {
            toggleNotePreview(state, hitIdx, helpers);
            return true;
          }
        }
        // Tapping bottom-left memo detail bar toggles selected note preview
        if (x >= 222 && x <= 456 && y >= 182 && y <= 222 && notes.length > 0) {
          toggleNotePreview(state, state.selectedNoteIdx, helpers);
          return true;
        }
        // Tapping organism starts memo recording
        if (Math.hypot(x - ORGANISM_CX, y - ORGANISM_CY) <= 66) {
          startPtt(state, helpers);
          return true;
        }
      }
    }

    return false;
  }

  // --------------------------------------------------------------------------
  // Canvas Drawing Helpers (True-Black AMOLED, Solid Bright Colors, Zero Grey Boxes)
  // --------------------------------------------------------------------------
  function roundRectPath(ctx, x, y, w, h, r) {
    var rad = Math.min(r || 0, Math.abs(w) * 0.5, Math.abs(h) * 0.5);
    ctx.beginPath();
    if (typeof ctx.roundRect === 'function') {
      ctx.roundRect(x, y, w, h, rad);
      return;
    }
    ctx.moveTo(x + rad, y);
    ctx.lineTo(x + w - rad, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + rad);
    ctx.lineTo(x + w, y + h - rad);
    ctx.quadraticCurveTo(x + w, y + h, x + w - rad, y + h);
    ctx.lineTo(x + rad, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - rad);
    ctx.lineTo(x, y + rad);
    ctx.quadraticCurveTo(x, y, x + rad, y);
    ctx.closePath();
  }

  function fillRoundRect(ctx, x, y, w, h, r, fill, stroke, lineWidth) {
    roundRectPath(ctx, x, y, w, h, r);
    if (fill) {
      ctx.fillStyle = fill;
      ctx.fill();
    }
    if (stroke) {
      ctx.strokeStyle = stroke;
      ctx.lineWidth = lineWidth || 1;
      ctx.stroke();
    }
  }

  function truncateText(ctx, text, maxWidth) {
    var str = String(text || '');
    if (maxWidth <= 0) return '';
    if (ctx.measureText(str).width <= maxWidth) return str;
    var ell = '…';
    var lo = 0;
    var hi = str.length;
    while (lo < hi) {
      var mid = Math.ceil((lo + hi) / 2);
      if (ctx.measureText(str.slice(0, mid) + ell).width <= maxWidth) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return str.slice(0, lo) + ell;
  }

  function wrapText(ctx, text, maxWidth, maxLines) {
    var words = String(text || '').split(/\s+/).filter(Boolean);
    if (!words.length) return [];
    var lines = [];
    var current = words[0];

    for (var i = 1; i < words.length; i++) {
      var next = current + ' ' + words[i];
      if (ctx.measureText(next).width <= maxWidth) {
        current = next;
      } else {
        lines.push(current);
        current = words[i];
        if (maxLines && lines.length >= maxLines - 1) {
          var rest = [current].concat(words.slice(i + 1)).join(' ');
          lines.push(truncateText(ctx, rest, maxWidth));
          return lines;
        }
      }
    }
    lines.push(truncateText(ctx, current, maxWidth));
    return maxLines ? lines.slice(0, maxLines) : lines;
  }

  function cleanBadgeForDisplay(badge) {
    var s = String(badge || '').trim();
    if (!s) return '✦ Gemini Ready';
    var m = s.match(/^★\s*(Bookmark\s+\d{1,2}:\d{2}(?::\d{2})?)\s*\+/i);
    if (m) return '✓ ' + m[1];
    return s;
  }

  function badgeColorForText(badge, state) {
    var b = String(badge || '').toLowerCase();
    if (b.indexOf('bookmark') !== -1 || b.indexOf('✓') !== -1 || b.indexOf('★') !== -1) {
      return COLORS.TEAL;
    }
    if (b.indexOf('carl') !== -1 || b.indexOf('playing') !== -1 || b.indexOf('resumed') !== -1) {
      return COLORS.GOLD;
    }
    if (b.indexOf('bt') !== -1 || b.indexOf('bluetooth') !== -1) {
      return COLORS.BT_CYAN;
    }
    if (b.indexOf('sleep') !== -1) {
      return COLORS.AMBER;
    }
    if (b.indexOf('paused') !== -1) {
      return COLORS.CORAL;
    }
    var preset = PROMPT_PRESETS[state.activePromptIdx];
    return preset ? preset.accent : COLORS.TEAL;
  }

  function drawTopStatusBarFallback(ctx, state) {
    ctx.save();
    ctx.fillStyle = COLORS.VOID;
    ctx.fillRect(0, 0, WIDTH, 28);
    ctx.textBaseline = 'middle';

    // Left: minimal fbox dot + bright source capsule
    ctx.fillStyle = COLORS.CORAL;
    ctx.beginPath();
    ctx.arc(16, 14, 3.5, 0, Math.PI * 2);
    ctx.fill();

    ctx.font = 'bold 10.5px ' + FONT_SANS;
    ctx.fillStyle = COLORS.WHITE;
    ctx.textAlign = 'left';
    ctx.fillText('fbox', 24, 14.5);

    var src = state.activeSource || 'ABS';
    var srcColor = src === 'MICROSD' ? COLORS.GOLD : src === 'SPOTIFY' ? COLORS.TEAL : COLORS.AMBER;
    var srcLabel = src === 'MICROSD' ? 'SD' : src === 'SPOTIFY' ? 'SPT' : 'ABS';

    ctx.font = 'bold 9px ' + FONT_SANS;
    var srcW = Math.ceil(ctx.measureText(srcLabel).width) + 14;
    fillRoundRect(ctx, 58, 6, srcW, 16, 8, srcColor);
    ctx.fillStyle = COLORS.VOID;
    ctx.textAlign = 'center';
    ctx.fillText(srcLabel, 58 + srcW * 0.5, 14.5);

    // Right: BT / Wired pill + battery %
    var batVal = Math.round(clamp(typeof state.batteryPct === 'number' ? state.batteryPct : 86, 0, 100));
    ctx.textAlign = 'right';
    ctx.font = 'bold 10px ' + FONT_MONO;
    ctx.fillStyle = batVal <= 20 ? COLORS.CORAL : COLORS.TEAL;
    ctx.fillText(batVal + '%', WIDTH - 14, 14.5);

    var outLabel = state.btTxOn ? 'BT TX' : '3.5mm';
    var outColor = state.btTxOn ? COLORS.BT_CYAN : COLORS.TEAL;
    ctx.font = 'bold 9px ' + FONT_SANS;
    var outW = Math.ceil(ctx.measureText(outLabel).width) + 14;
    var outX = WIDTH - 54 - outW;
    fillRoundRect(ctx, outX, 6, outW, 16, 8, hexToRgba(outColor, 0.2));
    ctx.fillStyle = outColor;
    ctx.textAlign = 'center';
    ctx.fillText(outLabel, outX + outW * 0.5, 14.5);
    ctx.restore();
  }

  function drawToastFallback(ctx, state) {
    if (!state || !state.toast || !(state.toast.until > Date.now())) return;
    var toast = state.toast;
    var remaining = toast.until - Date.now();
    var alpha = remaining < 250 ? clamp(remaining / 250, 0, 1) : 1;
    var accent = toast.color && toast.color.charAt(0) === '#' ? toast.color : COLORS.GOLD;
    var text = String(toast.text || '');

    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.font = 'bold 10.5px ' + FONT_SANS;
    var tw = Math.ceil(ctx.measureText(text).width);
    var pillW = clamp(tw + 28, 90, 420);
    var pillH = 22;
    var x = Math.round((WIDTH - pillW) * 0.5);
    var y = 186;

    fillRoundRect(ctx, x, y, pillW, pillH, 11, accent);
    ctx.fillStyle = COLORS.VOID;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(truncateText(ctx, text, pillW - 18), x + pillW * 0.5, y + pillH * 0.5 + 0.5);
    ctx.restore();
  }

  function drawTopModeSwitcher(ctx, state, anim) {
    ctx.save();
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';

    var isGemini = state.voiceSubMode === 'GEMINI';

    // Quick 0.3s lava-lamp liquid bridge whenever voiceSubMode flips
    if (anim.modeMorph < 1) {
      var p = easeInOutCubic(anim.modeMorph);
      var fromX = anim.modeFrom === 'GEMINI' ? GEMINI_CX : MEMO_CX;
      var toX = anim.modeTo === 'GEMINI' ? GEMINI_CX : MEMO_CX;
      var fromCol = anim.modeFrom === 'GEMINI' ? COLORS.CORAL : COLORS.AMBER;
      var toCol = anim.modeTo === 'GEMINI' ? COLORS.CORAL : COLORS.AMBER;
      var dropX = lerp(fromX, toX, p);
      var dropR = 5.5 + 7.5 * Math.sin(p * Math.PI);
      var midCol = lerpHex(fromCol, toCol, p);

      drawLavaBridge(ctx, fromX, MODE_Y, 11 * (1 - 0.3 * p), dropX, MODE_Y, dropR, fromCol, 120, midCol);
      drawLavaBridge(ctx, dropX, MODE_Y, dropR, toX, MODE_Y, 11 * (0.7 + 0.3 * p), midCol, 120, toCol);

      ctx.fillStyle = midCol;
      ctx.beginPath();
      ctx.arc(dropX, MODE_Y, dropR, 0, Math.PI * 2);
      ctx.fill();
    }

    // Bubble 1: Gemini (cx=288, y=42) in Coral #E0634E
    var gScale = clamp(anim.geminiScale.val, 0.78, 1.32);
    var gW = 84 * gScale;
    var gH = 24 * gScale;
    fillRoundRect(
      ctx,
      GEMINI_CX - gW * 0.5,
      MODE_Y - gH * 0.5,
      gW,
      gH,
      gH * 0.5,
      isGemini ? COLORS.CORAL : hexToRgba(COLORS.CORAL, 0.18)
    );
    if (state.voiceFocusLayer === 'MODE' && isGemini) {
      ctx.strokeStyle = COLORS.WHITE;
      ctx.lineWidth = 2;
      roundRectPath(ctx, GEMINI_CX - gW * 0.5 - 2.5, MODE_Y - gH * 0.5 - 2.5, gW + 5, gH + 5, (gH + 5) * 0.5);
      ctx.stroke();
    }
    ctx.font = 'bold 11px ' + FONT_SANS;
    ctx.fillStyle = isGemini ? COLORS.VOID : COLORS.CORAL;
    ctx.fillText('Gemini', GEMINI_CX, MODE_Y + 0.5);

    // Bubble 2: Memo (cx=404, y=42) in Amber #E3A84B
    var mScale = clamp(anim.memoScale.val, 0.78, 1.32);
    var mW = 78 * mScale;
    var mH = 24 * mScale;
    fillRoundRect(
      ctx,
      MEMO_CX - mW * 0.5,
      MODE_Y - mH * 0.5,
      mW,
      mH,
      mH * 0.5,
      !isGemini ? COLORS.AMBER : hexToRgba(COLORS.AMBER, 0.18)
    );
    if (state.voiceFocusLayer === 'MODE' && !isGemini) {
      ctx.strokeStyle = COLORS.WHITE;
      ctx.lineWidth = 2;
      roundRectPath(ctx, MEMO_CX - mW * 0.5 - 2.5, MODE_Y - mH * 0.5 - 2.5, mW + 5, mH + 5, (mH + 5) * 0.5);
      ctx.stroke();
    }
    ctx.font = 'bold 11px ' + FONT_SANS;
    ctx.fillStyle = !isGemini ? COLORS.VOID : COLORS.AMBER;
    ctx.fillText('Memo', MEMO_CX, MODE_Y + 0.5);

    ctx.restore();
  }

  function drawLavaOrganism(ctx, state, anim) {
    ctx.save();
    var popScale = clamp(anim.orgPop.val, 0.72, 1.48);
    var pts = [];
    for (var i = 0; i < 5; i++) {
      var bx = anim.blobs[i].x.val;
      var by = anim.blobs[i].y.val;
      var br = Math.max(4, anim.blobs[i].r.val * (0.75 + 0.25 * popScale));
      pts.push({
        x: ORGANISM_CX + (bx - ORGANISM_CX) * popScale,
        y: ORGANISM_CY + (by - ORGANISM_CY) * popScale,
        r: br,
        color: BLOB_PALETTE[i]
      });
    }

    // Smooth bezier metaball bridges between nearby blobs
    for (var a = 0; a < 5; a++) {
      for (var b = a + 1; b < 5; b++) {
        var maxSpan = (pts[a].r + pts[b].r) * 2.25;
        drawLavaBridge(
          ctx,
          pts[a].x,
          pts[a].y,
          pts[a].r,
          pts[b].x,
          pts[b].y,
          pts[b].r,
          pts[a].color,
          maxSpan,
          pts[b].color
        );
      }
    }

    // 5 bright solid circles on pure #000000
    for (var j = 4; j >= 0; j--) {
      ctx.fillStyle = pts[j].color;
      ctx.beginPath();
      ctx.arc(pts[j].x, pts[j].y, pts[j].r, 0, Math.PI * 2);
      ctx.fill();
    }

    // THINKING floating pill
    if (state.pttPhase === 'THINKING') {
      var dotCount = (Math.floor(anim.timeSec * 3.5) % 3) + 1;
      var dots = dotCount === 1 ? '.' : dotCount === 2 ? '..' : '...';
      var pillW = 94;
      var pillH = 22;
      var px = ORGANISM_CX - pillW * 0.5;
      var py = 190;
      fillRoundRect(ctx, px, py, pillW, pillH, 11, COLORS.GOLD);
      ctx.font = 'bold 11px ' + FONT_SANS;
      ctx.fillStyle = COLORS.VOID;
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      ctx.fillText('Thinking' + dots, px + 16, py + pillH * 0.5 + 0.5);
    }

    ctx.restore();
  }

  function drawListeningRight(ctx, state, anim) {
    ctx.save();
    var isMemo = state.voiceSubMode === 'VOICE_NOTE';

    // Big bold caption over pure #000000
    ctx.textBaseline = 'middle';
    if (isMemo) {
      ctx.textAlign = 'left';
      ctx.font = 'bold 19px ' + FONT_MONO;
      ctx.fillStyle = COLORS.CORAL;
      ctx.fillText('● ' + formatRecTimer(state.pttHoldMs), 228, 76);

      ctx.textAlign = 'right';
      ctx.font = 'bold 11px ' + FONT_SANS;
      ctx.fillStyle = COLORS.AMBER;
      ctx.fillText(nextVoiceNoteId(state.voiceNotes), 514, 76);
    } else {
      ctx.textAlign = 'left';
      ctx.font = 'bold 18px ' + FONT_SANS;
      ctx.fillStyle = COLORS.WHITE;
      ctx.fillText('Listening...', 228, 76);
    }

    // 16 thick solid-color pill bars (Coral / Gold / Teal alternating) in y=96..176
    var barColors = [COLORS.CORAL, COLORS.GOLD, COLORS.TEAL];
    var specX = 226;
    var specW = 288;
    var slotW = specW / 16; // 18px
    var barW = 11;
    var midY = 136; // center of y=96..176
    var maxBarH = 76;

    for (var i = 0; i < 16; i++) {
      var energy = clamp(anim.barSprings[i].val, 0.06, 1.05);
      var barH = clamp(10 + energy * (maxBarH - 10), 10, maxBarH);
      var bx = specX + i * slotW + (slotW - barW) * 0.5;
      var by = midY - barH * 0.5;
      fillRoundRect(ctx, bx, by, barW, barH, barW * 0.5, barColors[i % 3]);
    }

    // Clean stop/send pill in bottom right
    var actionCol = isMemo ? COLORS.CORAL : COLORS.TEAL;
    var actionLabel = isMemo ? '● Tap to Save' : '▲ Tap to Send';
    fillRoundRect(ctx, 396, 189, 118, 24, 12, actionCol);
    ctx.textAlign = 'center';
    ctx.font = 'bold 10.5px ' + FONT_SANS;
    ctx.fillStyle = COLORS.VOID;
    ctx.fillText(actionLabel, 455, 201.5);

    ctx.restore();
  }

  function drawThinkingRight(ctx, state, anim) {
    ctx.save();
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';

    var fallbackPreset = PROMPT_PRESETS[state.activePromptIdx] || PROMPT_PRESETS[0];
    var spokenText = state.lastTranscript || fallbackPreset.prompt;
    var quote = '“' + spokenText + '”';

    ctx.font = 'bold 14.5px ' + FONT_SANS;
    ctx.fillStyle = COLORS.WHITE;
    var lines = wrapText(ctx, quote, 286, 3);
    for (var i = 0; i < lines.length; i++) {
      ctx.fillText(lines[i], 228, 96 + i * 20);
    }

    // Animated bouncing Coral / Gold / Teal metaball loader dots
    var dotColors = [COLORS.CORAL, COLORS.GOLD, COLORS.TEAL];
    var baseY = 178;
    var baseX = 242;
    for (var d = 0; d < 3; d++) {
      var bounceY = baseY - Math.abs(Math.sin(anim.timeSec * 5.2 + d * 0.9)) * 10;
      ctx.fillStyle = dotColors[d];
      ctx.beginPath();
      ctx.arc(baseX + d * 24, bounceY, 6.5, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
  }

  function drawGeminiRight(ctx, state, anim) {
    ctx.save();
    ctx.textBaseline = 'middle';

    var hasResponse = Boolean(state.lastAiResponse);
    var preset = PROMPT_PRESETS[state.activePromptIdx] || PROMPT_PRESETS[0];
    var badgeText = hasResponse
      ? cleanBadgeForDisplay(state.lastAiActionBadge)
      : '✦ Gemini Ready';
    var badgeCol = badgeColorForText(badgeText, state);

    // 1. Bright solid-color action badge pill with #000000 bold text
    ctx.font = 'bold 10.5px ' + FONT_SANS;
    var bScale = clamp(anim.badgeScale.val, 0.85, 1.18);
    var rawW = clamp(Math.ceil(ctx.measureText(badgeText).width) + 22, 84, 286);
    var bW = rawW * bScale;
    var bH = 22 * bScale;
    var bx = 228 + (rawW - bW) * 0.5;
    var by = 66 + (22 - bH) * 0.5;
    fillRoundRect(ctx, bx, by, bW, bH, bH * 0.5, badgeCol);

    ctx.textAlign = 'left';
    ctx.fillStyle = COLORS.VOID;
    ctx.fillText(truncateText(ctx, badgeText, rawW - 18), 239, 77.5);

    // 2. Crisp #FFFFFF wrapped 2-3 line Gemini answer directly on #000000
    var bodyText = hasResponse
      ? state.lastAiResponse
      : 'Tap a numbered bubble below or hold B8 to ask Gemini.';
    ctx.font = '500 12px ' + FONT_SANS;
    ctx.fillStyle = COLORS.WHITE;
    var lines = wrapText(ctx, bodyText, 290, 3);
    for (var i = 0; i < lines.length; i++) {
      ctx.fillText(lines[i], 228, 105 + i * 16.5);
    }

    // 3. Above bottom row (y=166): Clean bold label of currently selected preset prompt
    ctx.fillStyle = preset.accent;
    ctx.beginPath();
    ctx.arc(233, 166, 3.5, 0, Math.PI * 2);
    ctx.fill();

    ctx.font = 'bold 11.5px ' + FONT_SANS;
    ctx.fillStyle = preset.accent;
    ctx.fillText(truncateText(ctx, preset.prompt, 276), 243, 166.5);

    // 4. Bottom Right Row (y=198): 5 Circular Prompt Bubbles (1..5 at x=[248, 304, 360, 416, 472])
    if (anim.promptMorph < 1) {
      var m = easeOutBack(anim.promptMorph);
      var fromIdx = anim.promptFromIdx;
      var toIdx = anim.promptToIdx;
      var fx = PROMPT_BUBBLE_XS[fromIdx] || PROMPT_BUBBLE_XS[0];
      var tx = PROMPT_BUBBLE_XS[toIdx] || PROMPT_BUBBLE_XS[0];
      var fCol = (PROMPT_PRESETS[fromIdx] || preset).accent;
      var tCol = (PROMPT_PRESETS[toIdx] || preset).accent;
      var travelX = lerp(fx, tx, clamp(m, 0, 1.04));
      var travelR = 7 + 6.5 * Math.sin(clamp(anim.promptMorph, 0, 1) * Math.PI);
      var midCol = lerpHex(fCol, tCol, clamp(anim.promptMorph, 0, 1));
      var span = Math.abs(tx - fx) + 48;

      drawLavaBridge(ctx, fx, PROMPT_BUBBLE_Y, 13, travelX, PROMPT_BUBBLE_Y, travelR, fCol, span, midCol);
      drawLavaBridge(ctx, travelX, PROMPT_BUBBLE_Y, travelR, tx, PROMPT_BUBBLE_Y, 15, midCol, span, tCol);

      ctx.fillStyle = midCol;
      ctx.beginPath();
      ctx.arc(travelX, PROMPT_BUBBLE_Y, travelR, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.textAlign = 'center';
    for (var p = 0; p < PROMPT_PRESETS.length; p++) {
      var item = PROMPT_PRESETS[p];
      var cx = PROMPT_BUBBLE_XS[p];
      var active = p === state.activePromptIdx;
      var pScale = clamp(anim.promptScales[p] ? anim.promptScales[p].val : 1, 0.78, 1.35);
      var r = (active ? 17 : 13.5) * pScale;

      if (active) {
        ctx.fillStyle = item.accent;
        ctx.beginPath();
        ctx.arc(cx, PROMPT_BUBBLE_Y, r, 0, Math.PI * 2);
        ctx.fill();

        ctx.font = 'bold 13px ' + FONT_SANS;
        ctx.fillStyle = COLORS.VOID;
        ctx.fillText(String(p + 1), cx, PROMPT_BUBBLE_Y + 0.5);
      } else {
        ctx.fillStyle = hexToRgba(item.accent, 0.2);
        ctx.beginPath();
        ctx.arc(cx, PROMPT_BUBBLE_Y, r, 0, Math.PI * 2);
        ctx.fill();

        ctx.strokeStyle = hexToRgba(item.accent, 0.75);
        ctx.lineWidth = 1.5;
        ctx.stroke();

        ctx.font = 'bold 11.5px ' + FONT_SANS;
        ctx.fillStyle = COLORS.WHITE;
        ctx.fillText(String(p + 1), cx, PROMPT_BUBBLE_Y + 0.5);
      }
    }

    ctx.restore();
  }

  function drawMemoRight(ctx, state, anim) {
    ctx.save();
    ctx.textBaseline = 'middle';

    var notes = state.voiceNotes;
    var dotPalette = [COLORS.TEAL, COLORS.GOLD, COLORS.CORAL_GLOW];

    if (!notes.length) {
      ctx.textAlign = 'left';
      ctx.font = '600 13px ' + FONT_SANS;
      ctx.fillStyle = COLORS.WHITE;
      ctx.fillText('No voice memos yet', 228, 108);
      ctx.font = '500 11px ' + FONT_SANS;
      ctx.fillStyle = COLORS.TEXT_SECONDARY;
      ctx.fillText('Tap REC or hold B8 to record', 228, 130);
    } else {
      var maxVis = 3;
      var startIdx = clamp(state.selectedNoteIdx - 1, 0, Math.max(0, notes.length - maxVis));
      var endIdx = Math.min(notes.length, startIdx + maxVis);

      for (var i = startIdx; i < endIdx; i++) {
        var note = notes[i];
        var slot = i - startIdx;
        var ry = 66 + slot * 37;
        var selected = i === state.selectedNoteIdx;
        var isPlaying = state.playingNoteId === note.id;
        var durStr = formatMmSs(Math.round(note.durationSec));

        if (selected) {
          var nScale = clamp(anim.notePillScale.val, 0.9, 1.1);
          var pillW = 294 * nScale;
          var pillH = 31 * nScale;
          var px = 224 + (294 - pillW) * 0.5;
          var py = ry + (31 - pillH) * 0.5;
          var cy = py + pillH * 0.5;

          fillRoundRect(ctx, px, py, pillW, pillH, pillH * 0.5, COLORS.AMBER);

          // Optional live playback fill sweep inside the active Amber capsule
          if (isPlaying) {
            ctx.save();
            roundRectPath(ctx, px, py, pillW, pillH, pillH * 0.5);
            ctx.clip();
            ctx.fillStyle = hexToRgba(COLORS.CORAL, 0.35);
            ctx.fillRect(px, py, pillW * clamp(state.notePlayProgress, 0.03, 1), pillH);
            ctx.restore();
          }

          // Circular play/stop indicator dot on left
          var dotCx = px + 17;
          ctx.fillStyle = isPlaying ? COLORS.CORAL : COLORS.VOID;
          ctx.beginPath();
          ctx.arc(dotCx, cy, 7.5, 0, Math.PI * 2);
          ctx.fill();

          if (isPlaying) {
            // Crisp stop square
            ctx.fillStyle = COLORS.VOID;
            ctx.fillRect(dotCx - 2.6, cy - 2.6, 5.2, 5.2);
          } else {
            // Crisp play triangle
            ctx.fillStyle = COLORS.AMBER;
            ctx.beginPath();
            ctx.moveTo(dotCx - 2.2, cy - 3.4);
            ctx.lineTo(dotCx + 3.6, cy);
            ctx.lineTo(dotCx - 2.2, cy + 3.4);
            ctx.closePath();
            ctx.fill();
          }

          ctx.textAlign = 'left';
          ctx.font = 'bold 11.5px ' + FONT_SANS;
          ctx.fillStyle = COLORS.VOID;
          ctx.fillText(truncateText(ctx, note.title, 200), px + 31, cy + 0.5);

          ctx.textAlign = 'right';
          ctx.font = 'bold 10.5px ' + FONT_MONO;
          ctx.fillStyle = COLORS.VOID;
          ctx.fillText(durStr, px + pillW - 14, cy + 0.5);
        } else {
          var rowCy = ry + 15.5;
          var dotColor = dotPalette[i % dotPalette.length];

          ctx.fillStyle = isPlaying ? COLORS.CORAL : dotColor;
          ctx.beginPath();
          ctx.arc(241, rowCy, 4.5, 0, Math.PI * 2);
          ctx.fill();

          ctx.textAlign = 'left';
          ctx.font = '600 11.5px ' + FONT_SANS;
          ctx.fillStyle = COLORS.WHITE;
          ctx.fillText(truncateText(ctx, note.title, 200), 255, rowCy + 0.5);

          ctx.textAlign = 'right';
          ctx.font = '600 10px ' + FONT_MONO;
          ctx.fillStyle = COLORS.TEXT_SECONDARY;
          ctx.fillText(durStr, 504, rowCy + 0.5);
        }
      }

      // Selected memo metadata / live playback status on bottom-left of right pane
      var selNote = notes[state.selectedNoteIdx];
      if (selNote) {
        var selPlaying = state.playingNoteId === selNote.id;
        ctx.textAlign = 'left';
        if (selPlaying) {
          ctx.font = 'bold 10.5px ' + FONT_SANS;
          ctx.fillStyle = COLORS.CORAL_GLOW;
          ctx.fillText('▶ Playing memo', 228, 193);
          fillRoundRect(ctx, 228, 206, 224, 5, 2.5, hexToRgba(COLORS.CORAL, 0.25));
          fillRoundRect(
            ctx,
            228,
            206,
            Math.max(10, 224 * clamp(state.notePlayProgress, 0.03, 1)),
            5,
            2.5,
            COLORS.CORAL
          );
        } else {
          ctx.font = '600 10.5px ' + FONT_SANS;
          ctx.fillStyle = COLORS.AMBER;
          ctx.fillText(truncateText(ctx, selNote.linkedTo || selNote.date || 'Voice Memo', 224), 228, 194);
          ctx.font = '500 10px ' + FONT_SANS;
          ctx.fillStyle = COLORS.TEXT_SECONDARY;
          ctx.fillText(truncateText(ctx, (selNote.date || 'Saved') + ' · Tap pill to play', 224), 228, 210);
        }
      }
    }

    // Vibrant Coral #E0634E circular REC bubble
    var recScale = clamp(anim.recBubbleScale.val, 0.8, 1.3);
    var recR = REC_BUBBLE_R * recScale;
    ctx.fillStyle = COLORS.CORAL;
    ctx.beginPath();
    ctx.arc(REC_BUBBLE_X, REC_BUBBLE_Y, recR, 0, Math.PI * 2);
    ctx.fill();

    ctx.textAlign = 'center';
    ctx.font = 'bold 11px ' + FONT_SANS;
    ctx.fillStyle = COLORS.VOID;
    ctx.fillText('REC', REC_BUBBLE_X, REC_BUBBLE_Y + 0.5);

    ctx.restore();
  }

  function renderVoiceAI(ctx, state, helpers) {
    if (!ctx) return;
    ensureState(state);

    var anim = getAnim(state);
    syncAnimTransitions(state, anim);

    // If caller invokes renderVoiceAI standalone without calling tickVoiceAI, seed positions gracefully
    if (!anim.hasTicked && typeof state.phase === 'number' && state.phase > 0) {
      anim.timeSec = state.phase / 3.0;
      var seededTargets = computeOrganismTargets(state, anim.timeSec);
      for (var bi = 0; bi < 5; bi++) {
        anim.blobs[bi].x.val = seededTargets[bi].x;
        anim.blobs[bi].y.val = seededTargets[bi].y;
        anim.blobs[bi].r.val = seededTargets[bi].r;
      }
    }

    // 1. Pure #000000 True-Black AMOLED background
    ctx.save();
    ctx.fillStyle = COLORS.VOID;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);
    ctx.restore();

    // 2. Top Status Bar (delegated when FBoxHomePlayer is loaded)
    var homePlayer = root && root.FBoxHomePlayer;
    if (homePlayer && typeof homePlayer.drawTopStatusBar === 'function') {
      homePlayer.drawTopStatusBar(ctx, state, helpers);
    } else {
      drawTopStatusBarFallback(ctx, state);
    }

    // 3. Top Mode Switcher (y=42) with 0.3s lava-lamp liquid bridge
    drawTopModeSwitcher(ctx, state, anim);

    // 4. Left/Center Living 5-Blob Lava-Lamp Voice Organism (cx=118, cy=132)
    drawLavaOrganism(ctx, state, anim);

    // 5. Right Area (x=220..520)
    if (state.pttPhase === 'LISTENING') {
      drawListeningRight(ctx, state, anim);
    } else if (state.pttPhase === 'THINKING') {
      drawThinkingRight(ctx, state, anim);
    } else if (state.voiceSubMode === 'VOICE_NOTE') {
      drawMemoRight(ctx, state, anim);
    } else {
      drawGeminiRight(ctx, state, anim);
    }

    // 6. Toast overlay (delegated when FBoxHomePlayer is loaded; NO grey bottom key-hint bar)
    if (homePlayer && typeof homePlayer.drawToast === 'function') {
      homePlayer.drawToast(ctx, state);
    } else {
      drawToastFallback(ctx, state);
    }
  }

  var api = {
    WIDTH: WIDTH,
    HEIGHT: HEIGHT,
    COLORS: COLORS,
    PROMPT_PRESETS: PROMPT_PRESETS,
    DEFAULT_VOICE_NOTES: DEFAULT_VOICE_NOTES,
    ensureState: ensureState,
    renderVoiceAI: renderVoiceAI,
    toggleSubMode: toggleSubMode,
    startPtt: startPtt,
    tickVoiceAI: tickVoiceAI,
    finishPttRelease: finishPttRelease,
    cancelPtt: cancelPtt,
    triggerPresetPrompt: triggerPresetPrompt,
    handleCustomPrompt: handleCustomPrompt,
    cycleSelection: cycleSelection,
    toggleNotePreview: toggleNotePreview,
    triggerPrimaryAction: triggerPrimaryAction,
    handlePointerTap: handlePointerTap,
    formatMmSs: formatMmSs
  };

  if (root) {
    root.FBoxVoiceAI = api;
    root.FBoxModules = root.FBoxModules || {};
    root.FBoxModules.voiceAI = api;
  }
})(typeof window !== 'undefined' ? window : typeof globalThis !== 'undefined' ? globalThis : this);

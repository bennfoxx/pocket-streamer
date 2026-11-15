/* ============================================================================
 * fbox OS — Library Browser & KY-023 Analog Stick Physics Module
 * Target: 1.91" RM67162 True-Black AMOLED (536 x 240 px)
 * Self-contained browser <script> module (no ES import/export; file:// safe)
 * Minimalist Pure-Black AMOLED + Circular Category Widgets + Lava-Lamp Morphs
 * + Underdamped Spring Solid Capsule Rows + Right-Edge Lava Velocity Droplet
 * ========================================================================== */
(function (root) {
  'use strict';

  var DISPLAY = {
    width: 536,
    height: 240,
    visibleRows: 4,
    rowHeight: 33,
    rowGap: 4,
    listX: 24,
    listRight: 494,
    listY: 82,
    listBottom: 226,
    tabCy: 50,
    tabCx: [96, 178, 260, 342, 424],
    tabR: 14,
    tabActiveR: 21,
    hudX: 508,
    hudRight: 522,
    hudY: 84,
    hudBottom: 220,
    deadzone: 0.14
  };

  var PALETTE = {
    voidBg: '#000000',
    cardSurface: '#000000',
    focusedSurface: '#000000',
    cardBorder: '#1E293B',
    focusedBorder: '#334155',
    textPrimary: '#F8FAFC',
    textSecondary: '#94A3B8',
    textDim: '#64748B',
    darkInk: '#000000',
    tabAccents: ['#E3A84B', '#EBD15E', '#45B09C', '#38BDF8', '#E0634E'],
    absAmber: '#E3A84B',
    chaptersGold: '#EBD15E',
    spotifyTeal: '#45B09C',
    sdCyan: '#38BDF8',
    marksCoral: '#E0634E'
  };

  var TABS = [
    { idx: 0, id: 'ABS_BOOKS', label: '1. ABS Books', shortLabel: 'Books', caption: 'Books', accent: PALETTE.absAmber },
    { idx: 1, id: 'ABS_CHAPTERS', label: '2. Chapters', shortLabel: 'Ch', caption: 'Ch', accent: PALETTE.chaptersGold },
    { idx: 2, id: 'SPOTIFY', label: '3. Spotify', shortLabel: 'Music', caption: 'Music', accent: PALETTE.spotifyTeal },
    { idx: 3, id: 'MICROSD', label: '4. MicroSD', shortLabel: 'Files', caption: 'Files', accent: PALETTE.sdCyan },
    { idx: 4, id: 'MARKS_NOTES', label: '5. ★ Marks & Notes', shortLabel: '★', caption: 'Marks', accent: PALETTE.marksCoral }
  ];

  // Retained on public API for external contract compatibility (not rendered on AMOLED void)
  var KEY_HINTS = [
    { key: 'STICK', label: 'Vel Scroll', color: PALETTE.marksCoral },
    { key: 'B1', label: 'Tab', color: PALETTE.chaptersGold },
    { key: 'B2/B3', label: '▲/▼', color: PALETTE.textSecondary },
    { key: 'B7', label: 'Play', color: PALETTE.chaptersGold },
    { key: 'B5', label: 'Back', color: PALETTE.absAmber }
  ];

  // --------------------------------------------------------------------------
  // Default Fallback Catalogs (used when window.FBoxHomePlayer is absent)
  // --------------------------------------------------------------------------
  var DEFAULT_ABS_BOOKS = [
    {
      id: 'abs-hail-mary',
      title: 'Project Hail Mary',
      author: 'Andy Weir',
      progressPct: 68,
      chapters: [
        { num: 1, title: 'Waking Up in Tau Ceti', durationSec: 1842 },
        { num: 2, title: 'Two Plus Two Equals...', durationSec: 2115 },
        { num: 3, title: 'The Petrova Line', durationSec: 1960 },
        { num: 4, title: 'Meeting Rocky at Eridani', durationSec: 2480 },
        { num: 5, title: 'Xenonite Hull Resonance', durationSec: 2305 },
        { num: 6, title: 'Astrophage Centrifuge', durationSec: 2640 }
      ]
    },
    {
      id: 'abs-dune',
      title: 'Dune',
      author: 'Frank Herbert',
      progressPct: 42,
      chapters: [
        { num: 1, title: 'Gom Jabbar Test', durationSec: 1730 },
        { num: 2, title: 'Arrakeen Arrival', durationSec: 2290 },
        { num: 3, title: 'The Crysknife & Shadout Mapes', durationSec: 1980 },
        { num: 4, title: 'Deep Desert Harvester', durationSec: 2540 },
        { num: 5, title: 'Stillsuit Water Discipline', durationSec: 2110 }
      ]
    },
    {
      id: 'abs-ddia',
      title: 'Designing Data-Intensive Apps',
      author: 'Martin Kleppmann',
      progressPct: 24,
      chapters: [
        { num: 1, title: 'Reliable, Scalable, Maintainable', durationSec: 2340 },
        { num: 2, title: 'Data Models & Query Languages', durationSec: 2680 },
        { num: 3, title: 'Storage & Retrieval Engines', durationSec: 2910 },
        { num: 4, title: 'Encoding & Schema Evolution', durationSec: 2150 }
      ]
    },
    {
      id: 'abs-leviathan',
      title: 'Leviathan Wakes',
      author: 'James S.A. Corey',
      progressPct: 85,
      chapters: [
        { num: 1, title: 'Julie Mao & The Scopuli', durationSec: 1620 },
        { num: 2, title: 'Ceres Station Dock', durationSec: 1945 },
        { num: 3, title: 'Rocinante Escape Burn', durationSec: 2080 },
        { num: 4, title: 'Eros Station Telemetry', durationSec: 2410 },
        { num: 5, title: 'Tycho Spin-Up', durationSec: 1875 }
      ]
    },
    {
      id: 'abs-pragmatic',
      title: 'The Pragmatic Programmer',
      author: 'Thomas & Hunt',
      progressPct: 12,
      chapters: [
        { num: 1, title: 'A Pragmatic Philosophy', durationSec: 1580 },
        { num: 2, title: 'Orthogonality & Tracer Bullets', durationSec: 1920 },
        { num: 3, title: 'The Basic Tools', durationSec: 1760 }
      ]
    }
  ];

  var DEFAULT_SPOTIFY_TRACKS = [
    { id: 'spt-1', title: 'Resonance (Lo-Fi Edit)', artist: 'HOME', playlist: 'Deep Study Focus', durationSec: 236 },
    { id: 'spt-2', title: 'Nuvole Bianche', artist: 'Ludovico Einaudi', playlist: 'Deep Study Focus', durationSec: 357 },
    { id: 'spt-3', title: 'Nightcall', artist: 'Kavinsky', playlist: 'Late Night Synthwave', durationSec: 258 },
    { id: 'spt-4', title: 'Holocene', artist: 'Bon Iver', playlist: 'Chill Indie Morning', durationSec: 336 },
    { id: 'spt-5', title: 'Midnight Rain', artist: 'Kupla', playlist: 'Deep Study Focus', durationSec: 194 },
    { id: 'spt-6', title: 'A Real Hero', artist: 'College & Electric Youth', playlist: 'Late Night Synthwave', durationSec: 267 },
    { id: 'spt-7', title: 'Coffee & Static', artist: 'Men I Trust', playlist: 'Chill Indie Morning', durationSec: 218 }
  ];

  var DEFAULT_SD_FILES = [
    { id: 'sd-1', title: 'CS229_Backprop_Lec04.mp3', folder: '/lectures', format: 'MP3', bitrate: '320k', durationSec: 2900, bookmarkSec: 1458 },
    { id: 'sd-2', title: 'Embedded_Linux_PipeWire.flac', folder: '/lectures', format: 'FLAC', bitrate: '1411k', durationSec: 1905, bookmarkSec: 664 },
    { id: 'sd-3', title: 'Dune_Ch04_Arrakis.m4b', folder: '/audiobooks', format: 'M4B', bitrate: '128k', durationSec: 3850, bookmarkSec: 2492 },
    { id: 'sd-4', title: 'ESP32_I2S_DMA_Notes.wav', folder: '/notes', format: 'WAV', bitrate: '1536k', durationSec: 198, bookmarkSec: 45 },
    { id: 'sd-5', title: 'Ambient_Tape_01.flac', folder: '/music', format: 'FLAC', bitrate: '960k', durationSec: 342, bookmarkSec: 0 },
    { id: 'sd-6', title: 'Systems_Rust_Async_Ep12.opus', folder: '/podcasts', format: 'OPUS', bitrate: '160k', durationSec: 2418, bookmarkSec: 710 }
  ];

  var FONT_SANS = '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif';
  var FONT_MONO = 'ui-monospace, SFMono-Regular, Menlo, monospace';

  // --------------------------------------------------------------------------
  // Generic & Spring Math Helpers
  // --------------------------------------------------------------------------
  function clamp(val, min, max) {
    if (val < min) return min;
    if (val > max) return max;
    return val;
  }

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }

  function smoothstep(t) {
    var x = clamp(t, 0, 1);
    return x * x * (3 - 2 * x);
  }

  function easeInOutCubic(t) {
    var x = clamp(t, 0, 1);
    return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) * 0.5;
  }

  function stepSpring(val, vel, target, stiffness, damping, dt) {
    var remain = clamp(dt, 0, 0.08);
    while (remain > 0) {
      var step = Math.min(remain, 0.008);
      var accel = (target - val) * stiffness;
      vel = (vel + accel * step) * Math.exp(-damping * step);
      val += vel * step;
      remain -= step;
    }
    if (Math.abs(target - val) < 0.01 && Math.abs(vel) < 0.05) {
      val = target;
      vel = 0;
    }
    return { val: val, vel: vel };
  }

  function getHomePlayer() {
    return root && root.FBoxHomePlayer ? root.FBoxHomePlayer : null;
  }

  function formatTime(sec) {
    var hp = getHomePlayer();
    if (hp && typeof hp.formatTime === 'function') {
      return hp.formatTime(sec);
    }
    if (hp && typeof hp.fmtTime === 'function') {
      return hp.fmtTime(sec);
    }
    var s = Math.max(0, Math.floor(Number.isFinite(sec) ? sec : (Number(sec) || 0)));
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var rem = s % 60;
    var mm = String(m).padStart(2, '0');
    var ss = String(rem).padStart(2, '0');
    return h > 0 ? (h + ':' + mm + ':' + ss) : (mm + ':' + ss);
  }

  function parseHexRgb(hex) {
    var h = String(hex || '#FFFFFF').replace('#', '');
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    return {
      r: parseInt(h.slice(0, 2), 16) || 0,
      g: parseInt(h.slice(2, 4), 16) || 0,
      b: parseInt(h.slice(4, 6), 16) || 0
    };
  }

  function hexToRgba(hex, alpha) {
    var rgb = parseHexRgb(hex);
    return 'rgba(' + rgb.r + ',' + rgb.g + ',' + rgb.b + ',' + alpha + ')';
  }

  function lerpColor(hexA, hexB, t) {
    var k = clamp(t, 0, 1);
    var a = parseHexRgb(hexA);
    var b = parseHexRgb(hexB);
    var r = Math.round(lerp(a.r, b.r, k));
    var g = Math.round(lerp(a.g, b.g, k));
    var bl = Math.round(lerp(a.b, b.b, k));
    return 'rgb(' + r + ',' + g + ',' + bl + ')';
  }

  function getCatalog() {
    var hp = getHomePlayer();
    var absBooks = (hp && Array.isArray(hp.ABS_BOOKS) && hp.ABS_BOOKS.length)
      ? hp.ABS_BOOKS
      : DEFAULT_ABS_BOOKS;
    var spotifyTracks = (hp && Array.isArray(hp.SPOTIFY_TRACKS) && hp.SPOTIFY_TRACKS.length)
      ? hp.SPOTIFY_TRACKS
      : DEFAULT_SPOTIFY_TRACKS;
    var sdFiles = (hp && Array.isArray(hp.SD_FILES) && hp.SD_FILES.length)
      ? hp.SD_FILES
      : DEFAULT_SD_FILES;

    return {
      ABS_BOOKS: absBooks,
      SPOTIFY_TRACKS: spotifyTracks,
      SD_FILES: sdFiles
    };
  }

  function slotY(slotIdx) {
    return DISPLAY.listY + slotIdx * (DISPLAY.rowHeight + DISPLAY.rowGap);
  }

  function ensureState(state) {
    if (!state || typeof state !== 'object') {
      state = {};
    }
    if (typeof state.libTabIdx !== 'number' || !Number.isFinite(state.libTabIdx)) state.libTabIdx = 0;
    state.libTabIdx = ((Math.round(state.libTabIdx) % 5) + 5) % 5;

    if (typeof state.libCursor !== 'number' || !Number.isFinite(state.libCursor)) state.libCursor = 0;
    if (typeof state.libScrollOffset !== 'number' || !Number.isFinite(state.libScrollOffset)) state.libScrollOffset = 0;

    if (!state.stick || typeof state.stick !== 'object') {
      state.stick = { x: 0, y: 0, adcX: 2048, adcY: 2048, pressed: false, scrubDeltaSec: 0, scrollVel: 0 };
    } else {
      if (typeof state.stick.x !== 'number') state.stick.x = 0;
      if (typeof state.stick.y !== 'number') state.stick.y = 0;
      if (typeof state.stick.scrubDeltaSec !== 'number') state.stick.scrubDeltaSec = 0;
      if (typeof state.stick.scrollVel !== 'number') state.stick.scrollVel = 0;
    }

    // Lava-lamp & spring animation state initialization
    if (typeof state._tabObservedIdx !== 'number' || !Number.isFinite(state._tabObservedIdx)) {
      state._tabObservedIdx = state.libTabIdx;
    }
    if (typeof state._prevTabIdx !== 'number' || !Number.isFinite(state._prevTabIdx)) {
      state._prevTabIdx = state.libTabIdx;
    }
    if (typeof state._tabLavaAnim !== 'number' || !Number.isFinite(state._tabLavaAnim)) {
      state._tabLavaAnim = 1;
    }
    if (!Array.isArray(state._tabSprings) || state._tabSprings.length !== TABS.length) {
      state._tabSprings = [];
      for (var i = 0; i < TABS.length; i++) {
        state._tabSprings.push({
          r: i === state.libTabIdx ? DISPLAY.tabActiveR : DISPLAY.tabR,
          v: 0
        });
      }
    }

    var initSlot = clamp(Math.round(state.libCursor - state.libScrollOffset), 0, DISPLAY.visibleRows - 1);
    if (typeof state._pillSpringY !== 'number' || !Number.isFinite(state._pillSpringY)) {
      state._pillSpringY = slotY(initSlot);
    }
    if (typeof state._pillSpringVel !== 'number' || !Number.isFinite(state._pillSpringVel)) {
      state._pillSpringVel = 0;
    }
    if (typeof state._pillSquish !== 'number' || !Number.isFinite(state._pillSquish)) {
      state._pillSquish = 0;
    }
    if (typeof state._pillSquishVel !== 'number' || !Number.isFinite(state._pillSquishVel)) {
      state._pillSquishVel = 0;
    }
    if (typeof state._lastFocusCursor !== 'number' || !Number.isFinite(state._lastFocusCursor)) {
      state._lastFocusCursor = state.libCursor;
    }
    if (typeof state._hudStretch !== 'number' || !Number.isFinite(state._hudStretch)) {
      state._hudStretch = 0;
    }
    if (typeof state._hudColorMix !== 'number' || !Number.isFinite(state._hudColorMix)) {
      state._hudColorMix = 0;
    }
    if (typeof state._hudThumbRatio !== 'number' || !Number.isFinite(state._hudThumbRatio)) {
      state._hudThumbRatio = 0;
    }
    return state;
  }

  function detectExternalTabChange(state) {
    if (state.libTabIdx !== state._tabObservedIdx) {
      state._prevTabIdx = state._tabObservedIdx;
      state._tabObservedIdx = state.libTabIdx;
      state._tabLavaAnim = 0;
      state._pillSquishVel = (Number(state._pillSquishVel) || 0) + 1.3;
    }
  }

  function stepVisualSprings(state, dtSec) {
    var dt = clamp(Number.isFinite(dtSec) ? dtSec : 0.016, 0.001, 0.08);
    detectExternalTabChange(state);

    // 1. Lava bridge morph timeline (0 -> 1 in ~0.30s)
    if (state._tabLavaAnim < 1) {
      var nextLava = state._tabLavaAnim + dt / 0.30;
      state._tabLavaAnim = nextLava >= 0.999 ? 1 : nextLava;
    }

    // 2. Category circle underdamped radius springs (14px <-> 21px)
    for (var i = 0; i < TABS.length; i++) {
      var sp = state._tabSprings[i];
      var targetR = i === state.libTabIdx ? DISPLAY.tabActiveR : DISPLAY.tabR;
      var next = stepSpring(sp.r, sp.v, targetR, 380, 14, dt);
      sp.r = next.val;
      sp.v = next.vel;
    }

    // 3. Active capsule pill vertical spring & elastic squish
    var items = getItemsForTab(state, state.libTabIdx);
    var visibleCount = Math.min(DISPLAY.visibleRows, Math.max(1, items.length - state.libScrollOffset));
    var focusSlot = clamp(state.libCursor - state.libScrollOffset, 0, Math.max(0, visibleCount - 1));
    var targetY = slotY(focusSlot);

    if (state._lastFocusCursor !== state.libCursor) {
      var moveDir = state.libCursor > state._lastFocusCursor ? 1 : -1;
      state._lastFocusCursor = state.libCursor;
      state._pillSquishVel += 1.45;
      state._pillSpringVel += moveDir * 55;
    }

    var pillNext = stepSpring(state._pillSpringY, state._pillSpringVel, targetY, 460, 18.5, dt);
    state._pillSpringY = pillNext.val;
    state._pillSpringVel = pillNext.vel;

    // Velocity-coupled squish so rapid moves subtly elongate/bounce the pill
    var velStretch = clamp(Math.abs(state._pillSpringVel) / 1400, 0, 0.14);
    var squishNext = stepSpring(state._pillSquish, state._pillSquishVel, velStretch, 320, 11, dt);
    state._pillSquish = clamp(squishNext.val, -0.22, 0.26);
    state._pillSquishVel = squishNext.vel;

    // 4. Right-edge lava-droplet velocity indicator smoothing
    var axes = readStickAxes(state.stick);
    var stickY = axes.y;
    var vel = Number(state.stick.scrollVel) || 0;
    var isTilted = Math.abs(stickY) >= DISPLAY.deadzone || vel >= 1;
    var velNorm = isTilted
      ? clamp(((vel >= 1 ? vel : (1 + ((Math.abs(stickY) - DISPLAY.deadzone) / (1 - DISPLAY.deadzone)) * 5)) - 1) / 5, 0, 1)
      : 0;
    var targetStretch = isTilted ? (0.18 + 0.82 * velNorm) : 0;
    var targetColorMix = isTilted ? (0.28 + 0.72 * velNorm) : 0;
    var hudSmooth = 1 - Math.exp(-16 * dt);
    state._hudStretch = lerp(state._hudStretch, targetStretch, hudSmooth);
    state._hudColorMix = lerp(state._hudColorMix, targetColorMix, hudSmooth);

    var targetRatio = items.length > 1 ? clamp(state.libCursor / (items.length - 1), 0, 1) : 0;
    if (isTilted) {
      targetRatio = clamp(targetRatio + stickY * 0.04, 0, 1);
    }
    state._hudThumbRatio = lerp(state._hudThumbRatio, targetRatio, 1 - Math.exp(-18 * dt));
  }

  function normalizeSourceTag(src) {
    var s = String(src || '').toUpperCase();
    if (s.indexOf('ABS') >= 0 || s.indexOf('BOOK') >= 0 || s.indexOf('CHAPTER') >= 0) return 'ABS';
    if (s.indexOf('SPOT') >= 0 || s === 'SPT') return 'SPOTIFY';
    if (s.indexOf('SD') >= 0) return 'SD';
    return s || 'ABS';
  }

  function resolveSourceKey(canonical) {
    var hp = getHomePlayer();
    var target = normalizeSourceTag(canonical);
    var dict = (hp && (hp.SOURCES || hp.SOURCE_IDS || hp.SOURCE_META)) || null;
    if (dict && typeof dict === 'object') {
      var keys = Object.keys(dict);
      for (var i = 0; i < keys.length; i++) {
        if (normalizeSourceTag(keys[i]) === target) return keys[i];
      }
    }
    if (target === 'SD') return 'MICROSD';
    if (target === 'SPOTIFY') return 'SPOTIFY';
    return 'ABS';
  }

  function isSourceAbs(state) {
    return normalizeSourceTag(state && state.activeSource) === 'ABS';
  }

  function isSourceSpotify(state) {
    return normalizeSourceTag(state && state.activeSource) === 'SPOTIFY';
  }

  function isSourceSd(state) {
    return normalizeSourceTag(state && state.activeSource) === 'SD';
  }

  function resolveBookProgressPct(book) {
    if (!book) return 0;
    if (typeof book.progressPct === 'number' && Number.isFinite(book.progressPct)) {
      return Math.round(clamp(book.progressPct, 0, 100));
    }
    if (typeof book.pct === 'number' && Number.isFinite(book.pct)) {
      return Math.round(clamp(book.pct <= 1 && book.pct > 0 ? book.pct * 100 : book.pct, 0, 100));
    }
    if (typeof book.progress === 'number' && Number.isFinite(book.progress)) {
      return Math.round(clamp(book.progress <= 1 ? book.progress * 100 : book.progress, 0, 100));
    }
    return 0;
  }

  function triggerToast(helpers, state, text, color) {
    if (helpers && typeof helpers.triggerToast === 'function') {
      helpers.triggerToast(text, color);
      return;
    }
    if (helpers && typeof helpers.toast === 'function') {
      helpers.toast(text, color);
      return;
    }
    if (helpers && typeof helpers.showToast === 'function') {
      helpers.showToast(text, color);
      return;
    }
    var hp = getHomePlayer();
    if (hp && typeof hp.toast === 'function') {
      hp.toast(state, text, color);
      return;
    }
    if (hp && typeof hp.showToast === 'function') {
      hp.showToast(state, text, color);
      return;
    }
    if (state && typeof state === 'object') {
      state.toast = { text: text, color: color || PALETTE.absAmber, until: Date.now() + 1800 };
    }
  }

  function triggerEarcon(helpers, type) {
    if (helpers && typeof helpers.earcon === 'function') {
      helpers.earcon(type);
      return;
    }
    if (helpers && typeof helpers.playEarcon === 'function') {
      helpers.playEarcon(type);
      return;
    }
    var hp = getHomePlayer();
    if (hp && typeof hp.playEarcon === 'function') {
      hp.playEarcon(type);
    } else if (hp && typeof hp.earcon === 'function') {
      hp.earcon(type);
    }
  }

  // --------------------------------------------------------------------------
  // 1. Data Projection: getItemsForTab(state, tabIdx)
  // --------------------------------------------------------------------------
  function getItemsForTab(state, tabIdx) {
    var st = state || {};
    var tab = typeof tabIdx === 'number' && Number.isFinite(tabIdx)
      ? (((Math.round(tabIdx) % 5) + 5) % 5)
      : (((Math.round(Number(st.libTabIdx) || 0) % 5) + 5) % 5);

    var cat = getCatalog();

    if (tab === 0) {
      return cat.ABS_BOOKS.map(function (book, index) {
        var chapters = Array.isArray(book.chapters) ? book.chapters : [];
        var pct = resolveBookProgressPct(book);
        return {
          id: book.id != null ? book.id : ('abs-book-' + index),
          title: book.title || ('Audiobook ' + (index + 1)),
          subtitle: (book.author || 'Unknown Author') + ' · ' + chapters.length + ' ch',
          badge: pct + '%',
          progress: pct / 100,
          isActive: isSourceAbs(st) && Number(st.absBookIdx || 0) === index,
          accent: PALETTE.absAmber,
          type: 'ABS_BOOK',
          icon: 'ABS',
          index: index,
          raw: book
        };
      });
    }

    if (tab === 1) {
      var books = cat.ABS_BOOKS;
      if (!books.length) return [];
      var bookIdx = clamp(Math.round(Number(st.absBookIdx) || 0), 0, books.length - 1);
      var activeBook = books[bookIdx] || {};
      var chList = Array.isArray(activeBook.chapters) ? activeBook.chapters : [];
      return chList.map(function (ch, index) {
        var num = ch.num != null ? ch.num : (index + 1);
        var chTitle = ch.title || ('Chapter ' + num);
        var dur = Number(ch.durationSec != null ? ch.durationSec : ch.duration) || 0;
        var active = isSourceAbs(st) && Number(st.absChapterIdx || 0) === index;
        var prog = undefined;
        if (active && dur > 0 && typeof st.positionSec === 'number') {
          prog = clamp(st.positionSec / dur, 0, 1);
        }
        return {
          id: ch.id != null ? ch.id : ((activeBook.id || ('book-' + bookIdx)) + '-ch-' + index),
          title: 'Ch. ' + num + ' — ' + chTitle,
          subtitle: activeBook.title || 'Audiobookshelf',
          badge: formatTime(dur),
          progress: prog,
          isActive: active,
          accent: PALETTE.chaptersGold,
          type: 'ABS_CHAPTER',
          icon: 'CH',
          bookIndex: bookIdx,
          index: index,
          raw: ch
        };
      });
    }

    if (tab === 2) {
      return cat.SPOTIFY_TRACKS.map(function (tr, index) {
        var dur = Number(tr.durationSec != null ? tr.durationSec : tr.duration) || 0;
        return {
          id: tr.id != null ? tr.id : ('spt-' + index),
          title: tr.title || ('Track ' + (index + 1)),
          subtitle: (tr.artist || 'Unknown Artist') + ' · ' + (tr.playlist || tr.album || 'Spotify'),
          badge: formatTime(dur),
          isActive: isSourceSpotify(st) && Number(st.spotifyTrackIdx || 0) === index,
          accent: PALETTE.spotifyTeal,
          type: 'SPOTIFY_TRACK',
          icon: 'SPT',
          index: index,
          raw: tr
        };
      });
    }

    if (tab === 3) {
      return cat.SD_FILES.map(function (f, index) {
        var dur = Number(f.durationSec != null ? f.durationSec : f.duration) || 0;
        var folder = f.folder || '/media';
        var fmt = f.format || 'MP3';
        var bitrate = f.bitrate || '320k';
        return {
          id: f.id != null ? f.id : ('sd-' + index),
          title: f.title || f.name || f.shortTitle || ('File ' + (index + 1)),
          subtitle: folder + ' · ' + fmt + ' ' + bitrate,
          badge: formatTime(dur),
          isActive: isSourceSd(st) && Number(st.sdFileIdx || 0) === index,
          accent: PALETTE.sdCyan,
          type: 'SD_FILE',
          icon: 'SD',
          index: index,
          raw: f
        };
      });
    }

    // Tab 4: 5. ★ Marks & Notes (bookmarks + voiceNotes)
    var items = [];
    var bookmarks = Array.isArray(st.bookmarks) ? st.bookmarks : [];
    var voiceNotes = Array.isArray(st.voiceNotes) ? st.voiceNotes : [];

    for (var bi = 0; bi < bookmarks.length; bi++) {
      var rawBm = bookmarks[bi];
      var bm = (typeof rawBm === 'number') ? { positionSec: rawBm } : (rawBm || {});
      var posSec = Number(
        bm.positionSec != null ? bm.positionSec :
        (bm.posSec != null ? bm.posSec :
        (bm.timestampSec != null ? bm.timestampSec :
        (bm.timeSec != null ? bm.timeSec : (bm.sec || 0))))
      ) || 0;
      var srcTag = normalizeSourceTag(bm.source || bm.activeSource || bm.sourceType || st.activeSource || 'ABS');
      var srcShort = srcTag === 'SPOTIFY' ? 'SPT' : (srcTag === 'MICROSD' || srcTag === 'SD' ? 'SD' : srcTag);
      var title = bm.title || bm.label || bm.note || bm.trackTitle || bm.bookTitle || ('Bookmark @ ' + formatTime(posSec));
      var ctxLabel = bm.subtitle || bm.context || bm.chapterTitle || bm.bookTitle || bm.artist || bm.fileTitle || '';
      var createdStr = (typeof bm.createdAt === 'string' && bm.createdAt) ? (' · ' + bm.createdAt) : '';
      var sub = '★ ' + srcShort + (ctxLabel && ctxLabel !== title ? (' · ' + ctxLabel) : (createdStr || ' · Saved Mark'));
      var bmId = bm.id != null ? bm.id : ('bm-' + bi);

      items.push({
        id: bmId,
        title: title,
        subtitle: sub,
        badge: formatTime(posSec),
        isActive: Boolean(st.activeBookmarkId && st.activeBookmarkId === bmId),
        accent: PALETTE.marksCoral,
        type: 'BOOKMARK',
        icon: '★',
        index: items.length,
        raw: bm
      });
    }

    for (var vi = 0; vi < voiceNotes.length; vi++) {
      var vn = voiceNotes[vi] || {};
      var durSec = Number(
        vn.durationSec != null ? vn.durationSec :
        (vn.duration != null ? vn.duration : (vn.lengthSec || 0))
      ) || 0;
      var vnSource = vn.sourceTag || vn.source || 'INMP441';
      var vnTitle = vn.title || vn.label || vn.transcript || vn.summary || vn.text || ('Voice Note #' + (vi + 1));
      var vnDetail = vn.linkedTo || vn.linkedLabel || vn.date ||
        (typeof vn.createdAt === 'string' ? vn.createdAt : '') ||
        (vn.transcript && vn.title ? ('"' + vn.transcript + '"') : '48kHz WAV');
      var vnId = vn.id != null ? vn.id : ('vn-' + vi);
      var isVnActive = Boolean(
        (st.playingNoteId && st.playingNoteId === vnId) ||
        (st.voiceNotePlayingId && st.voiceNotePlayingId === vnId) ||
        vn.playing
      );

      items.push({
        id: vnId,
        title: vnTitle,
        subtitle: vn.linkedTo ? ('WAV · ' + vnDetail + (vn.date ? ' · ' + vn.date : '')) : ('WAV · ' + vnSource + ' · ' + vnDetail),
        badge: formatTime(durSec),
        isActive: isVnActive,
        accent: PALETTE.marksCoral,
        type: 'VOICE_NOTE',
        icon: 'WAV',
        voiceNoteIndex: vi,
        index: items.length,
        raw: vn
      });
    }

    return items;
  }

  // --------------------------------------------------------------------------
  // 2. Cursor & Tab Navigation
  // --------------------------------------------------------------------------
  function syncWindow(state, itemsLength) {
    if (itemsLength <= 0) {
      state.libCursor = 0;
      state.libScrollOffset = 0;
      return;
    }
    var cursor = clamp(Math.round(Number(state.libCursor) || 0), 0, itemsLength - 1);
    var maxOffset = Math.max(0, itemsLength - DISPLAY.visibleRows);
    var offset = clamp(Math.round(Number(state.libScrollOffset) || 0), 0, maxOffset);

    if (cursor < offset) {
      offset = cursor;
    } else if (cursor >= offset + DISPLAY.visibleRows) {
      offset = cursor - DISPLAY.visibleRows + 1;
    }
    offset = clamp(offset, 0, maxOffset);

    state.libCursor = cursor;
    state.libScrollOffset = offset;
  }

  function moveCursor(state, delta) {
    ensureState(state);
    var items = getItemsForTab(state, state.libTabIdx);
    if (!items.length) {
      state.libCursor = 0;
      state.libScrollOffset = 0;
      return 0;
    }
    var prevCursor = state.libCursor;
    var step = Number(delta) || 0;
    state.libCursor = clamp(Math.round(state.libCursor + step), 0, items.length - 1);
    syncWindow(state, items.length);

    if (state.libCursor !== prevCursor) {
      state._pillSquishVel = (Number(state._pillSquishVel) || 0) + 1.25;
      if (state.libCursor > prevCursor) {
        state._pillSpringVel = (Number(state._pillSpringVel) || 0) + 45;
      } else {
        state._pillSpringVel = (Number(state._pillSpringVel) || 0) - 45;
      }
    }
    return state.libCursor;
  }

  function switchTab(state, deltaOrIdx, explicit) {
    ensureState(state);
    var prevTab = state.libTabIdx;
    var nextTab;
    if (explicit) {
      nextTab = clamp(Math.round(Number(deltaOrIdx) || 0), 0, TABS.length - 1);
    } else {
      var delta = Number(deltaOrIdx) || 0;
      nextTab = (((state.libTabIdx + Math.round(delta)) % TABS.length) + TABS.length) % TABS.length;
    }

    state.libTabIdx = nextTab;
    state._scrollAccum = 0;

    if (nextTab !== prevTab) {
      state._prevTabIdx = prevTab;
      state._tabObservedIdx = nextTab;
      state._tabLavaAnim = 0;
      state._pillSquishVel = (Number(state._pillSquishVel) || 0) + 1.5;
    }

    var items = getItemsForTab(state, nextTab);
    if (!items.length) {
      state.libCursor = 0;
      state.libScrollOffset = 0;
      state._lastFocusCursor = 0;
      return nextTab;
    }

    var activeIdx = -1;
    for (var i = 0; i < items.length; i++) {
      if (items[i].isActive) {
        activeIdx = i;
        break;
      }
    }
    state.libCursor = activeIdx >= 0 ? activeIdx : 0;
    state.libScrollOffset = 0;
    syncWindow(state, items.length);
    state._lastFocusCursor = state.libCursor;
    return nextTab;
  }

  // --------------------------------------------------------------------------
  // 3. KY-023 Analog Stick Physics across Screens
  // --------------------------------------------------------------------------
  function readStickAxes(stick) {
    var st = stick || {};
    var rawX = Number(st.x);
    var rawY = Number(st.y);
    if (!Number.isFinite(rawX) && typeof st.adcX === 'number') {
      rawX = (st.adcX - 2048) / 2048;
    }
    if (!Number.isFinite(rawY) && typeof st.adcY === 'number') {
      rawY = (st.adcY - 2048) / 2048;
    }
    return {
      x: clamp(Number.isFinite(rawX) ? rawX : 0, -1, 1),
      y: clamp(Number.isFinite(rawY) ? rawY : 0, -1, 1)
    };
  }

  function getVoicePromptCount(state) {
    var vai = root && root.FBoxVoiceAI ? root.FBoxVoiceAI : null;
    if (vai && Array.isArray(vai.PROMPT_PRESETS) && vai.PROMPT_PRESETS.length) return vai.PROMPT_PRESETS.length;
    if (vai && Array.isArray(vai.PROMPTS) && vai.PROMPTS.length) return vai.PROMPTS.length;
    if (vai && Array.isArray(vai.PRESETS) && vai.PRESETS.length) return vai.PRESETS.length;
    if (vai && Array.isArray(vai.QUICK_PROMPTS) && vai.QUICK_PROMPTS.length) return vai.QUICK_PROMPTS.length;
    if (state && Array.isArray(state.voicePrompts) && state.voicePrompts.length) return state.voicePrompts.length;
    return 5;
  }

  function updateStickPhysics(state, dtSec, helpers) {
    if (!state || typeof state !== 'object') return;
    ensureState(state);

    var dt = clamp(Number.isFinite(dtSec) ? dtSec : 0.016, 0, 5.0);
    var dz = DISPLAY.deadzone;
    var axes = readStickAxes(state.stick);
    var rawX = axes.x;
    var rawY = axes.y;
    var absX = Math.abs(rawX);
    var absY = Math.abs(rawY);
    var screen = String(state.screen || 'NOW_PLAYING').toUpperCase();

    if (screen !== 'LIBRARY_BROWSER' && screen !== 'LIBRARY_BROWSE') {
      state.stick.scrollVel = 0;
      state._scrollAccum = 0;
      state._libScrollActive = false;
      state._libTabStickLatched = false;
    }
    if (screen !== 'SYSTEM_OUTPUT' && screen !== 'SYSTEM' && screen !== 'OUTPUT' && screen !== 'STATUS') {
      state._sysStickLatched = false;
    }

    // ---- NOW_PLAYING: X scrubs (±1x..±16x) + live preview + release commit; Y controls volume ----
    if (screen === 'NOW_PLAYING') {
      var dur = Math.max(0, Number(state.durationSec) || 0);
      var basePos = Math.max(0, Number(state.positionSec) || 0);

      if (absX >= dz) {
        var normX = (absX - dz) / (1 - dz);
        var speedMul = 1 + Math.pow(normX, 1.35) * 15; // 1x .. 16x
        var scrubRate = (rawX > 0 ? 1 : -1) * speedMul;
        var nextDelta = (Number(state.stick.scrubDeltaSec) || 0) + scrubRate * dt;

        if (dur > 0) {
          nextDelta = clamp(nextDelta, -basePos, Math.max(0, dur - basePos));
        } else {
          nextDelta = Math.max(-basePos, nextDelta);
        }

        state.stick.scrubDeltaSec = nextDelta;
        state.stick.scrubSpeed = scrubRate;
        var previewPos = basePos + nextDelta;
        state.stick.previewPositionSec = dur > 0 ? clamp(previewPos, 0, dur) : Math.max(0, previewPos);
        if (helpers && typeof helpers.onScrubPreview === 'function') {
          helpers.onScrubPreview(state.stick.previewPositionSec, nextDelta, scrubRate);
        }
      } else if ((Number(state.stick.scrubDeltaSec) || 0) !== 0) {
        var deltaToCommit = Number(state.stick.scrubDeltaSec) || 0;
        var committed = basePos + deltaToCommit;
        state.positionSec = dur > 0 ? clamp(committed, 0, dur) : Math.max(0, committed);
        state.stick.scrubDeltaSec = 0;
        state.stick.scrubSpeed = 0;
        state.stick.previewPositionSec = state.positionSec;

        var signLabel = deltaToCommit >= 0 ? '+' : '−';
        triggerToast(
          helpers,
          state,
          'Seek ' + formatTime(state.positionSec) + ' (' + signLabel + Math.abs(Math.round(deltaToCommit)) + 's)',
          PALETTE.sdCyan
        );
        triggerEarcon(helpers, 'tick');
      }

      if (absY >= dz) {
        var normY = (absY - dz) / (1 - dz);
        // Up (y < 0) raises volume, Down (y > 0) lowers volume
        var volDir = rawY < 0 ? 1 : -1;
        var volRate = 18 + normY * 52; // 18..70 %/sec
        var currentVol = Number(state.volume);
        if (!Number.isFinite(currentVol)) currentVol = 68;
        var exactVol = (typeof state._volExact === 'number' && Math.round(state._volExact) === Math.round(currentVol))
          ? state._volExact
          : currentVol;
        exactVol = clamp(exactVol + volDir * volRate * dt, 0, 100);
        state._volExact = exactVol;
        var roundedVol = Math.round(exactVol);
        if (roundedVol !== state.volume) {
          state.volume = roundedVol;
          state.volHudUntil = Date.now() + 1400;
        }
      }
      return;
    }

    // ---- LIBRARY_BROWSER: Y drives variable 1x..6x row velocity; X tap switches tabs ----
    if (screen === 'LIBRARY_BROWSER' || screen === 'LIBRARY_BROWSE') {
      if (absY >= dz) {
        var normScrollY = clamp((absY - dz) / (1 - dz), 0, 1);
        var vel = 1 + normScrollY * 5; // 1x .. 6x rows/sec
        var dir = rawY > 0 ? 1 : -1;
        state.stick.scrollVel = vel;

        var prevDir = state._libScrollDir || 0;
        if (!state._libScrollActive || (prevDir !== 0 && prevDir !== dir)) {
          var prevCursor = state.libCursor;
          moveCursor(state, dir);
          if (state.libCursor !== prevCursor) triggerEarcon(helpers, 'tick');
          state._libScrollActive = true;
          state._libScrollDir = dir;
          state._scrollAccum = 0;
        } else {
          state._scrollAccum = (Number(state._scrollAccum) || 0) + dir * vel * dt;
          var steps = Math.trunc(state._scrollAccum);
          if (steps !== 0) {
            state._scrollAccum -= steps;
            var before = state.libCursor;
            moveCursor(state, steps);
            if (state.libCursor !== before) triggerEarcon(helpers, 'tick');
          }
        }
      } else {
        state.stick.scrollVel = 0;
        state._scrollAccum = 0;
        state._libScrollActive = false;
        state._libScrollDir = 0;
      }

      if (absX >= 0.25 && absX >= absY) {
        if (!state._libTabStickLatched) {
          switchTab(state, rawX > 0 ? 1 : -1, false);
          state._libTabStickLatched = true;
          triggerEarcon(helpers, 'tick');
        }
      } else if (absX < dz) {
        state._libTabStickLatched = false;
      }

      state._physicsSteppedInLoop = true;
      stepVisualSprings(state, dt);
      return;
    }

    // ---- HOME_LAUNCHER / HOME: X or Y steps launcherIdx (0..3) ----
    if (screen === 'HOME_LAUNCHER' || screen === 'HOME') {
      state._launcherStickCooldown = Math.max(0, (Number(state._launcherStickCooldown) || 0) - dt);
      var maxHome = Math.max(absX, absY);
      if (maxHome >= dz) {
        if (state._launcherStickCooldown <= 0) {
          var homeDir = absX >= absY ? (rawX > 0 ? 1 : -1) : (rawY > 0 ? 1 : -1);
          var curLauncher = Number.isFinite(state.launcherIdx) ? Math.round(state.launcherIdx) : 0;
          var nextLauncher = clamp(curLauncher + homeDir, 0, 3);
          if (nextLauncher !== curLauncher) {
            state.launcherIdx = nextLauncher;
            triggerEarcon(helpers, 'tick');
          }
          state._launcherStickCooldown = 0.24;
        }
      } else {
        state._launcherStickCooldown = 0;
      }
      return;
    }

    // ---- VOICE_AI / AI_VOICE: X or Y steps activePromptIdx or selectedNoteIdx ----
    if (screen === 'VOICE_AI' || screen === 'AI_VOICE' || screen === 'VOICE') {
      state._voiceStickCooldown = Math.max(0, (Number(state._voiceStickCooldown) || 0) - dt);
      var maxVoice = Math.max(absX, absY);
      if (maxVoice >= dz) {
        if (state._voiceStickCooldown <= 0) {
          var vDir = absY >= absX ? (rawY > 0 ? 1 : -1) : (rawX > 0 ? 1 : -1);
          var notes = Array.isArray(state.voiceNotes) ? state.voiceNotes : [];
          var inNotesView = (state.voiceSubMode === 'VOICE_NOTE' || state.voiceTab === 'NOTES') && notes.length > 0;
          if (inNotesView) {
            var curSel = typeof state.selectedNoteIdx === 'number' && Number.isFinite(state.selectedNoteIdx)
              ? Math.round(state.selectedNoteIdx)
              : 0;
            var nextSelNote = clamp(curSel + vDir, 0, notes.length - 1);
            if (nextSelNote !== state.selectedNoteIdx) {
              state.selectedNoteIdx = nextSelNote;
              triggerEarcon(helpers, 'tick');
            }
            if (typeof state.voiceNoteCursor === 'number') {
              var nextNote = clamp(Math.round(state.voiceNoteCursor) + vDir, 0, notes.length - 1);
              if (nextNote !== state.voiceNoteCursor) {
                state.voiceNoteCursor = nextNote;
                triggerEarcon(helpers, 'tick');
              }
            }
          } else {
            var promptCount = getVoicePromptCount(state);
            var curPrompt = Number.isFinite(state.activePromptIdx) ? Math.round(state.activePromptIdx) : 0;
            var nextPrompt = clamp(curPrompt + vDir, 0, Math.max(0, promptCount - 1));
            if (nextPrompt !== curPrompt) {
              state.activePromptIdx = nextPrompt;
              triggerEarcon(helpers, 'tick');
            }
          }
          state._voiceStickCooldown = 0.22;
        }
      } else {
        state._voiceStickCooldown = 0;
      }
      return;
    }

    // ---- SYSTEM_OUTPUT: X horizontal tap toggles btTxOn (3.5mm <-> BT TX) ----
    if (screen === 'SYSTEM_OUTPUT' || screen === 'SYSTEM' || screen === 'OUTPUT' || screen === 'STATUS') {
      if (absX >= 0.25 && absX >= absY) {
        if (!state._sysStickLatched) {
          state.btTxOn = !state.btTxOn;
          state._sysStickLatched = true;
          triggerToast(
            helpers,
            state,
            state.btTxOn ? 'BT TX Active · KCX_BT_EMITTER' : 'Wired Audio · 3.5mm PCM5102',
            state.btTxOn ? PALETTE.sdCyan : PALETTE.spotifyTeal
          );
          triggerEarcon(helpers, 'confirm');
        }
      } else if (absX < dz) {
        state._sysStickLatched = false;
      }
    }
  }

  // --------------------------------------------------------------------------
  // 4. Row Activation: activateSelectedRow(state, helpers)
  // --------------------------------------------------------------------------
  function findIndexById(list, id) {
    if (!id || !Array.isArray(list)) return -1;
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].id === id) return i;
    }
    return -1;
  }

  function activateSelectedRow(state, helpers) {
    ensureState(state);
    var items = getItemsForTab(state, state.libTabIdx);
    if (!items.length) {
      triggerToast(helpers, state, 'Nothing to play in this tab', PALETTE.marksCoral);
      triggerEarcon(helpers, 'denied');
      return null;
    }

    syncWindow(state, items.length);
    var item = items[state.libCursor];
    if (!item) return null;

    var cat = getCatalog();

    if (item.type === 'ABS_BOOK') {
      var book = item.raw || cat.ABS_BOOKS[item.index] || {};
      var chapters = Array.isArray(book.chapters) ? book.chapters : [];
      var sameBook = Number(state.absBookIdx) === item.index;
      state.activeSource = resolveSourceKey('ABS');
      state.absBookIdx = item.index;
      var chIdx = book.currentChapterIdx != null
        ? clamp(book.currentChapterIdx, 0, Math.max(0, chapters.length - 1))
        : (sameBook ? clamp(Number(state.absChapterIdx) || 0, 0, Math.max(0, chapters.length - 1)) : 0);
      state.absChapterIdx = chIdx;
      var ch = chapters[chIdx] || {};
      var chDur = Number(ch.durationSec != null ? ch.durationSec : ch.duration) || Number(book.durationSec) || 0;
      state.durationSec = chDur;
      state.positionSec = book.currentPosSec != null ? clamp(book.currentPosSec, 0, chDur || book.currentPosSec) : 0;
      state.playing = true;
      state.screen = 'NOW_PLAYING';
      triggerToast(helpers, state, 'ABS: ' + item.title, PALETTE.absAmber);
      triggerEarcon(helpers, 'confirm');
      return item;
    }

    if (item.type === 'ABS_CHAPTER') {
      var rawCh = item.raw || {};
      var dur = Number(rawCh.durationSec != null ? rawCh.durationSec : rawCh.duration) || 0;
      state.activeSource = resolveSourceKey('ABS');
      if (typeof item.bookIndex === 'number') state.absBookIdx = item.bookIndex;
      state.absChapterIdx = item.index;
      state.durationSec = dur;
      state.positionSec = 0;
      state.playing = true;
      state.screen = 'NOW_PLAYING';
      triggerToast(helpers, state, item.title, PALETTE.chaptersGold);
      triggerEarcon(helpers, 'confirm');
      return item;
    }

    if (item.type === 'SPOTIFY_TRACK') {
      var tr = item.raw || {};
      var trDur = Number(tr.durationSec != null ? tr.durationSec : tr.duration) || 0;
      state.activeSource = resolveSourceKey('SPOTIFY');
      state.spotifyTrackIdx = item.index;
      state.durationSec = trDur;
      state.positionSec = 0;
      state.playing = true;
      state.screen = 'NOW_PLAYING';
      triggerToast(helpers, state, 'Spotify: ' + item.title, PALETTE.spotifyTeal);
      triggerEarcon(helpers, 'confirm');
      return item;
    }

    if (item.type === 'SD_FILE') {
      var f = item.raw || {};
      var fDur = Number(f.durationSec != null ? f.durationSec : f.duration) || 0;
      var resumeSec = Number(f.bookmarkSec != null ? f.bookmarkSec : f.bookmark) || 0;
      state.activeSource = resolveSourceKey('SD');
      state.sdFileIdx = item.index;
      state.durationSec = fDur;
      state.positionSec = fDur > 0 ? clamp(resumeSec, 0, fDur) : Math.max(0, resumeSec);
      state.playing = true;
      state.screen = 'NOW_PLAYING';
      triggerToast(helpers, state, 'MicroSD: ' + item.title, PALETTE.sdCyan);
      triggerEarcon(helpers, 'confirm');
      return item;
    }

    if (item.type === 'BOOKMARK') {
      var bm = item.raw || {};
      var src = normalizeSourceTag(bm.source || bm.activeSource || bm.sourceType || state.activeSource || 'ABS');
      var targetPos = Number(
        bm.positionSec != null ? bm.positionSec :
        (bm.posSec != null ? bm.posSec :
        (bm.timestampSec != null ? bm.timestampSec :
        (bm.timeSec != null ? bm.timeSec : (bm.sec || 0))))
      ) || 0;

      if (src === 'SPOTIFY') {
        var sIdx = bm.spotifyTrackIdx != null ? bm.spotifyTrackIdx :
          (bm.trackIdx != null ? bm.trackIdx :
          (bm.itemIdx != null ? bm.itemIdx : findIndexById(cat.SPOTIFY_TRACKS, bm.trackId)));
        if (sIdx < 0) sIdx = clamp(Number(state.spotifyTrackIdx) || 0, 0, Math.max(0, cat.SPOTIFY_TRACKS.length - 1));
        var sTrack = cat.SPOTIFY_TRACKS[sIdx] || {};
        state.activeSource = resolveSourceKey('SPOTIFY');
        state.spotifyTrackIdx = sIdx;
        state.durationSec = Number(sTrack.durationSec != null ? sTrack.durationSec : sTrack.duration) || Math.max(targetPos, 180);
      } else if (src === 'SD' || src === 'MICROSD') {
        var fIdx = bm.sdFileIdx != null ? bm.sdFileIdx :
          (bm.fileIdx != null ? bm.fileIdx :
          (bm.itemIdx != null ? bm.itemIdx : findIndexById(cat.SD_FILES, bm.fileId)));
        if (fIdx < 0) fIdx = clamp(Number(state.sdFileIdx) || 0, 0, Math.max(0, cat.SD_FILES.length - 1));
        var sFile = cat.SD_FILES[fIdx] || {};
        state.activeSource = resolveSourceKey('SD');
        state.sdFileIdx = fIdx;
        state.durationSec = Number(sFile.durationSec != null ? sFile.durationSec : sFile.duration) || Math.max(targetPos, 180);
      } else {
        var bIdx = bm.absBookIdx != null ? bm.absBookIdx :
          (bm.bookIdx != null ? bm.bookIdx :
          (bm.itemIdx != null ? bm.itemIdx : findIndexById(cat.ABS_BOOKS, bm.bookId)));
        if (bIdx < 0) bIdx = clamp(Number(state.absBookIdx) || 0, 0, Math.max(0, cat.ABS_BOOKS.length - 1));
        var bObj = cat.ABS_BOOKS[bIdx] || {};
        var bChs = Array.isArray(bObj.chapters) ? bObj.chapters : [];
        var cIdx = bm.absChapterIdx != null ? bm.absChapterIdx :
          (bm.chapterIdx != null ? bm.chapterIdx :
          (bm.chapterNum != null ? Number(bm.chapterNum) - 1 : 0));
        cIdx = clamp(cIdx, 0, Math.max(0, bChs.length - 1));
        var bCh = bChs[cIdx] || {};
        state.activeSource = resolveSourceKey('ABS');
        state.absBookIdx = bIdx;
        state.absChapterIdx = cIdx;
        state.durationSec = Number(bCh.durationSec != null ? bCh.durationSec : bCh.duration) || Number(bm.durationSec) || Math.max(targetPos, 180);
      }

      state.positionSec = state.durationSec > 0 ? clamp(targetPos, 0, state.durationSec) : Math.max(0, targetPos);
      state.activeBookmarkId = item.id;
      state.playing = true;
      state.screen = 'NOW_PLAYING';
      triggerToast(helpers, state, '★ Jump to ' + formatTime(state.positionSec) + ' · ' + item.title, PALETTE.marksCoral);
      triggerEarcon(helpers, 'bookmark');
      return item;
    }

    if (item.type === 'VOICE_NOTE') {
      var vn = item.raw || {};
      var vnDur = Number(vn.durationSec != null ? vn.durationSec : vn.duration) || 8;
      var vai = root && root.FBoxVoiceAI ? root.FBoxVoiceAI : null;

      if (helpers && typeof helpers.playVoiceNote === 'function') {
        helpers.playVoiceNote(vn, item);
      } else if (vai && typeof vai.toggleNotePreview === 'function') {
        var vnIdx = typeof item.voiceNoteIndex === 'number' ? item.voiceNoteIndex : 0;
        vai.toggleNotePreview(state, vnIdx, helpers);
        state.voiceNotePlayingId = state.playingNoteId || null;
        state.voiceNotePreviewUntil = state.playingNoteId ? (Date.now() + Math.max(2, vnDur) * 1000) : 0;
        return item;
      } else if (vai && typeof vai.playVoiceNote === 'function') {
        vai.playVoiceNote(state, vn, helpers);
      }

      if (state.voiceNotePlayingId === item.id && Date.now() < (state.voiceNotePreviewUntil || 0)) {
        state.voiceNotePlayingId = null;
        state.playingNoteId = null;
        state.voiceNotePreviewUntil = 0;
        triggerToast(helpers, state, 'Stopped WAV preview', PALETTE.textSecondary);
        triggerEarcon(helpers, 'tick');
      } else {
        state.voiceNotePlayingId = item.id;
        state.playingNoteId = item.id;
        state.voiceNotePreviewUntil = Date.now() + Math.max(2, vnDur) * 1000;
        triggerToast(helpers, state, '▶ WAV Preview: ' + item.title + ' (' + formatTime(vnDur) + ')', PALETTE.marksCoral);
        triggerEarcon(helpers, 'ptt_send');
      }
      return item;
    }

    return item;
  }

  // --------------------------------------------------------------------------
  // 5. Canvas Drawing Primitives & Category Icons
  // --------------------------------------------------------------------------
  function drawRoundRectPath(ctx, x, y, w, h, r) {
    var rad = Math.max(0, Math.min(r || 0, Math.min(w, h) * 0.5));
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

  function truncateFit(ctx, text, maxWidth) {
    var str = String(text || '');
    if (maxWidth <= 8) return '';
    if (ctx.measureText(str).width <= maxWidth) return str;
    var lo = 0;
    var hi = str.length;
    while (lo < hi) {
      var mid = (lo + hi + 1) >> 1;
      if (ctx.measureText(str.slice(0, mid) + '…').width <= maxWidth) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo > 0 ? (str.slice(0, lo) + '…') : '…';
  }

  function recordLibHitbox(helpers, box) {
    if (!helpers) return;
    if (typeof helpers.registerHitbox === 'function') {
      helpers.registerHitbox(box);
    } else if (Array.isArray(helpers.hitboxes)) {
      helpers.hitboxes.push(box);
    }
  }

  function drawFallbackTopStatusBar(ctx, state, helpers) {
    ctx.save();
    ctx.fillStyle = PALETTE.voidBg;
    ctx.fillRect(0, 0, DISPLAY.width, 28);

    // Minimal brand dot + fbox label (pure black void, zero table chrome)
    ctx.fillStyle = PALETTE.marksCoral;
    ctx.beginPath();
    ctx.arc(16, 14, 3.2, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = PALETTE.textPrimary;
    ctx.font = 'bold 11px ' + FONT_SANS;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText('fbox', 24, 14.5);
    recordLibHitbox(helpers, { id: 'top_home', x: 8, y: 2, w: 50, h: 24, action: 'goHome' });

    var src = normalizeSourceTag(state.activeSource || 'ABS');
    var srcAccent = src === 'SPOTIFY' ? PALETTE.spotifyTeal : (src === 'SD' ? PALETTE.sdCyan : PALETTE.absAmber);
    ctx.fillStyle = srcAccent;
    ctx.font = 'bold 9.5px ' + FONT_MONO;
    ctx.fillText(src, 64, 14.5);

    var btOn = Boolean(state.btTxOn);
    var outLabel = btOn ? 'BT TX' : '3.5mm';
    var outColor = btOn ? PALETTE.sdCyan : PALETTE.spotifyTeal;
    ctx.fillStyle = outColor;
    ctx.textAlign = 'right';
    ctx.fillText(outLabel, DISPLAY.width - 110, 14.5);
    recordLibHitbox(helpers, { id: 'top_output', x: DISPLAY.width - 160, y: 2, w: 56, h: 24, action: 'toggleOutput' });

    var vol = Number.isFinite(state.volume) ? Math.round(state.volume) : 74;
    var bat = Number.isFinite(state.batteryPct) ? Math.round(state.batteryPct) : 86;
    ctx.fillStyle = PALETTE.textSecondary;
    ctx.font = '600 9.5px ' + FONT_MONO;
    ctx.fillText(vol + '% · ' + bat + '%', DISPLAY.width - 14, 14.5);
    recordLibHitbox(helpers, { id: 'top_telemetry', x: DISPLAY.width - 104, y: 2, w: 94, h: 24, action: 'openSystem' });
    ctx.restore();
  }

  function drawCategoryIcon(ctx, tabIdx, cx, cy, scale, color) {
    var s = scale || 1;
    ctx.save();
    ctx.fillStyle = color;
    ctx.strokeStyle = color;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.lineWidth = Math.max(1.3, 1.75 * s);

    if (tabIdx === 0) {
      // Open Book
      ctx.beginPath();
      ctx.moveTo(cx, cy - 4.2 * s);
      ctx.quadraticCurveTo(cx - 3.8 * s, cy - 6.0 * s, cx - 7.5 * s, cy - 4.2 * s);
      ctx.lineTo(cx - 7.5 * s, cy + 4.8 * s);
      ctx.quadraticCurveTo(cx - 3.8 * s, cy + 3.2 * s, cx, cy + 5.0 * s);
      ctx.quadraticCurveTo(cx + 3.8 * s, cy + 3.2 * s, cx + 7.5 * s, cy + 4.8 * s);
      ctx.lineTo(cx + 7.5 * s, cy - 4.2 * s);
      ctx.quadraticCurveTo(cx + 3.8 * s, cy - 6.0 * s, cx, cy - 4.2 * s);
      ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(cx, cy - 4.0 * s);
      ctx.lineTo(cx, cy + 4.8 * s);
      ctx.stroke();
    } else if (tabIdx === 1) {
      // Chapters: 3 crisp staggered bullet lines
      var ys = [-3.6, 0, 3.6];
      var ws = [6.4, 4.6, 5.8];
      for (var i = 0; i < 3; i++) {
        var yy = cy + ys[i] * s;
        ctx.beginPath();
        ctx.arc(cx - 5.2 * s, yy, 1.15 * s, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.moveTo(cx - 2.2 * s, yy);
        ctx.lineTo(cx + ws[i] * s, yy);
        ctx.stroke();
      }
    } else if (tabIdx === 2) {
      // Music: Beamed eighth notes
      ctx.beginPath();
      ctx.arc(cx - 3.6 * s, cy + 3.8 * s, 2.2 * s, 0, Math.PI * 2);
      ctx.arc(cx + 3.6 * s, cy + 2.4 * s, 2.2 * s, 0, Math.PI * 2);
      ctx.fill();

      ctx.beginPath();
      ctx.moveTo(cx - 1.7 * s, cy + 3.5 * s);
      ctx.lineTo(cx - 1.7 * s, cy - 4.8 * s);
      ctx.lineTo(cx + 5.5 * s, cy - 6.2 * s);
      ctx.lineTo(cx + 5.5 * s, cy + 2.0 * s);
      ctx.stroke();
    } else if (tabIdx === 3) {
      // Files: Notched MicroSD card silhouette
      ctx.beginPath();
      ctx.moveTo(cx - 4.8 * s, cy - 6.0 * s);
      ctx.lineTo(cx + 2.2 * s, cy - 6.0 * s);
      ctx.lineTo(cx + 5.2 * s, cy - 2.8 * s);
      ctx.lineTo(cx + 5.2 * s, cy + 6.0 * s);
      ctx.lineTo(cx - 4.8 * s, cy + 6.0 * s);
      ctx.closePath();
      ctx.stroke();

      ctx.lineWidth = Math.max(1.1, 1.4 * s);
      for (var p = 0; p < 3; p++) {
        var px = cx - 2.5 * s + p * 2.2 * s;
        ctx.beginPath();
        ctx.moveTo(px, cy - 3.5 * s);
        ctx.lineTo(px, cy - 0.8 * s);
        ctx.stroke();
      }
    } else {
      // ★ Marks & Notes: 5-point solid star
      var outerR = 7.0 * s;
      var innerR = 3.1 * s;
      ctx.beginPath();
      for (var k = 0; k < 10; k++) {
        var ang = (k * Math.PI) / 5 - Math.PI / 2;
        var rad = k % 2 === 0 ? outerR : innerR;
        var sx = cx + Math.cos(ang) * rad;
        var sy = cy + Math.sin(ang) * rad;
        if (k === 0) ctx.moveTo(sx, sy);
        else ctx.lineTo(sx, sy);
      }
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();
  }

  // --------------------------------------------------------------------------
  // 6. Lava-Lamp Metaball Liquid Bridge (built-in bezier + droplet engine)
  // --------------------------------------------------------------------------
  function drawMetaballPair(ctx, x1, y1, r1, x2, y2, r2, maxDist, fillStyle) {
    var dx = x2 - x1;
    var dy = y2 - y1;
    var dist = Math.hypot(dx, dy);
    if (dist <= Math.abs(r1 - r2) + 0.5 || dist >= maxDist) return false;

    var minD = Math.max(1, (r1 + r2) * 0.35);
    var stretch = clamp((dist - minD) / Math.max(1, maxDist - minD), 0, 1);
    var theta = Math.atan2(dy, dx);
    var spread1 = lerp(0.98, 0.28, stretch);
    var spread2 = lerp(0.98, 0.28, stretch);

    var p1TopX = x1 + r1 * Math.cos(theta - spread1);
    var p1TopY = y1 + r1 * Math.sin(theta - spread1);
    var p2TopX = x2 + r2 * Math.cos(theta + Math.PI + spread2);
    var p2TopY = y2 + r2 * Math.sin(theta + Math.PI + spread2);

    var p2BotX = x2 + r2 * Math.cos(theta + Math.PI - spread2);
    var p2BotY = y2 + r2 * Math.sin(theta + Math.PI - spread2);
    var p1BotX = x1 + r1 * Math.cos(theta + spread1);
    var p1BotY = y1 + r1 * Math.sin(theta + spread1);

    var midX = (x1 + x2) * 0.5;
    var midY = (y1 + y2) * 0.5;
    var pinchPull = lerp(0.14, 0.74, stretch);

    var ctrlTopX = lerp((p1TopX + p2TopX) * 0.5, midX, pinchPull);
    var ctrlTopY = lerp((p1TopY + p2TopY) * 0.5, midY, pinchPull);
    var ctrlBotX = lerp((p1BotX + p2BotX) * 0.5, midX, pinchPull);
    var ctrlBotY = lerp((p1BotY + p2BotY) * 0.5, midY, pinchPull);

    ctx.fillStyle = fillStyle;
    ctx.beginPath();
    ctx.moveTo(p1TopX, p1TopY);
    ctx.quadraticCurveTo(ctrlTopX, ctrlTopY, p2TopX, p2TopY);
    ctx.arc(x2, y2, r2, theta + Math.PI + spread2, theta + Math.PI - spread2, false);
    ctx.quadraticCurveTo(ctrlBotX, ctrlBotY, p1BotX, p1BotY);
    ctx.arc(x1, y1, r1, theta + spread1, theta - spread1, false);
    ctx.closePath();
    ctx.fill();
    return true;
  }

  function drawBuiltInLavaBridge(ctx, x1, y1, r1, x2, y2, r2, t, color1, color2) {
    var progress = clamp(t, 0, 1);
    if (progress <= 0 || progress >= 1) return;

    var dist = Math.abs(x2 - x1);
    if (dist < 1) return;

    var travel = easeInOutCubic(progress);
    var arcLift = Math.sin(progress * Math.PI) * Math.min(6, dist * 0.025);
    var blobX = lerp(x1, x2, travel);
    var blobY = lerp(y1, y2, travel) - arcLift;
    var blobR = lerp(r1 * 0.78, r2 * 0.86, travel) * (0.78 + 0.28 * Math.sin(progress * Math.PI));

    var grad = ctx.createLinearGradient(x1, y1, x2, y2);
    grad.addColorStop(0, color1);
    grad.addColorStop(0.5, lerpColor(color1, color2, 0.5));
    grad.addColorStop(1, color2);

    ctx.save();
    ctx.shadowBlur = 12;
    ctx.shadowColor = hexToRgba(lerpColor(color1, color2, travel), 0.45);

    var maxNeck = Math.max(96, (r1 + r2) * 3.1);
    drawMetaballPair(ctx, x1, y1, r1 * 0.94, blobX, blobY, blobR, maxNeck, grad);
    drawMetaballPair(ctx, blobX, blobY, blobR, x2, y2, r2 * 0.94, maxNeck, grad);

    // Core traveling molten drop
    ctx.fillStyle = lerpColor(color1, color2, travel);
    ctx.beginPath();
    ctx.arc(blobX, blobY, blobR, 0, Math.PI * 2);
    ctx.fill();

    // Two trailing micro-droplets bubbling along the lava stream
    var dropFade = Math.sin(progress * Math.PI);
    for (var d = 1; d <= 2; d++) {
      var dtLag = clamp(travel - d * 0.14, 0, 1);
      var dropX = lerp(x1, x2, dtLag);
      var dropY = lerp(y1, y2, dtLag) + Math.sin(progress * Math.PI * 2 + d * 1.9) * 3.2;
      var dropR = (4.2 - d * 1.1) * dropFade;
      if (dropR > 0.7) {
        ctx.fillStyle = lerpColor(color1, color2, dtLag);
        ctx.beginPath();
        ctx.arc(dropX, dropY, dropR, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.restore();
  }

  function renderCategoryBridge(ctx, state) {
    var anim = Number(state._tabLavaAnim);
    var prevIdx = clamp(Math.round(Number(state._prevTabIdx) || 0), 0, TABS.length - 1);
    var curIdx = clamp(Math.round(Number(state.libTabIdx) || 0), 0, TABS.length - 1);
    if (!(anim >= 0 && anim < 1) || prevIdx === curIdx) return;

    var x1 = DISPLAY.tabCx[prevIdx];
    var x2 = DISPLAY.tabCx[curIdx];
    var cy = DISPLAY.tabCy;
    var r1 = state._tabSprings[prevIdx].r;
    var r2 = state._tabSprings[curIdx].r;
    var c1 = TABS[prevIdx].accent;
    var c2 = TABS[curIdx].accent;

    var hp = getHomePlayer();
    if (hp && typeof hp.drawLavaBridge === 'function') {
      try {
        var handled = hp.drawLavaBridge.length <= 2
          ? hp.drawLavaBridge(ctx, { x1: x1, y1: cy, r1: r1, x2: x2, y2: cy, r2: r2, t: anim, color1: c1, color2: c2 })
          : hp.drawLavaBridge(ctx, x1, cy, r1, x2, cy, r2, anim, c1, c2);
        if (handled !== false) return;
      } catch (_err) {
        // Fallback to built-in metaball bridge below
      }
    }

    drawBuiltInLavaBridge(ctx, x1, cy, r1, x2, cy, r2, anim, c1, c2);
  }

  // --------------------------------------------------------------------------
  // 7. Top Circular Category Bar (y=50)
  // --------------------------------------------------------------------------
  function drawCategoryCircles(ctx, state, helpers) {
    renderCategoryBridge(ctx, state);

    var activeIdx = state.libTabIdx;
    var cy = DISPLAY.tabCy;

    for (var i = 0; i < TABS.length; i++) {
      var tab = TABS[i];
      var cx = DISPLAY.tabCx[i];
      var isActive = i === activeIdx;
      var rad = clamp(state._tabSprings[i] ? state._tabSprings[i].r : (isActive ? DISPLAY.tabActiveR : DISPLAY.tabR), 10, 26);

      ctx.save();
      if (isActive) {
        ctx.shadowBlur = 14;
        ctx.shadowColor = hexToRgba(tab.accent, 0.45);
      }

      ctx.fillStyle = tab.accent;
      ctx.beginPath();
      ctx.arc(cx, cy, rad, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();

      // Draw crisp #000000 icon + caption on expanded circle, or centered icon on compact circle
      var expandBlend = clamp((rad - DISPLAY.tabR) / (DISPLAY.tabActiveR - DISPLAY.tabR), 0, 1);
      var iconOffsetY = lerp(0, -5.5, expandBlend);
      var iconScale = lerp(0.95, 0.9, expandBlend);
      drawCategoryIcon(ctx, i, cx, cy + iconOffsetY, iconScale, PALETTE.darkInk);

      if (expandBlend > 0.22) {
        ctx.save();
        ctx.globalAlpha = clamp((expandBlend - 0.22) / 0.55, 0, 1);
        ctx.fillStyle = PALETTE.darkInk;
        ctx.font = 'bold 8.5px ' + FONT_SANS;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(tab.caption || tab.shortLabel, cx, cy + 9.5);
        ctx.restore();
      }

      // Generous circular hitbox for touch/mouse tap
      var hitR = 25;
      recordLibHitbox(helpers, {
        id: 'lib_tab_' + i,
        x: cx - hitR,
        y: cy - hitR,
        w: hitR * 2,
        h: hitR * 2,
        action: 'switchLibTab',
        tabIdx: i
      });
    }
  }

  // --------------------------------------------------------------------------
  // 8. Minimalist Pure-Black 4-Row Viewport + Bouncy Solid Capsule Pill
  // --------------------------------------------------------------------------
  function drawEqualizer(ctx, x, y, color, animate) {
    var phase = Date.now() * 0.009;
    var barW = 2.2;
    var gap = 1.6;
    var maxH = 11;
    ctx.fillStyle = color;
    for (var i = 0; i < 4; i++) {
      var h = animate ? Math.round(3 + (Math.sin(phase + i * 1.45) * 0.5 + 0.5) * (maxH - 3)) : 3;
      ctx.fillRect(x + i * (barW + gap), y + (maxH - h), barW, h);
    }
  }

  function isVoiceNotePreviewing(item, state) {
    return item.type === 'VOICE_NOTE' && (
      (state.playingNoteId && state.playingNoteId === item.id) ||
      (state.voiceNotePlayingId === item.id && Date.now() < (state.voiceNotePreviewUntil || 0))
    );
  }

  function drawRowContent(ctx, item, ry, isInsideCapsule, tabIdx, tabAccent, state) {
    var x = DISPLAY.listX;
    var h = DISPLAY.rowHeight;
    var cy = ry + h * 0.5;
    var badgeCx = x + 18; // x = 42
    var textX = x + 36;   // x = 60

    var isPreviewing = isVoiceNotePreviewing(item, state);
    var showEq = Boolean(item.isActive || isPreviewing);
    var eqAnimate = item.type === 'VOICE_NOTE' ? isPreviewing : Boolean(state.playing);

    // 1. Left Icon Badge
    if (isInsideCapsule) {
      // #000000 solid circular icon badge inside vibrant capsule
      ctx.fillStyle = PALETTE.darkInk;
      ctx.beginPath();
      ctx.arc(badgeCx, cy, 10.5, 0, Math.PI * 2);
      ctx.fill();
      drawCategoryIcon(ctx, tabIdx, badgeCx, cy, 0.72, tabAccent);
    } else {
      // Unselected: small solid colored dot (r = 4) directly on #000000 void
      if (item.isActive) {
        ctx.strokeStyle = hexToRgba(tabAccent, 0.55);
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.arc(badgeCx, cy, 6.8, 0, Math.PI * 2);
        ctx.stroke();
      }
      ctx.fillStyle = tabAccent;
      ctx.beginPath();
      ctx.arc(badgeCx, cy, 4, 0, Math.PI * 2);
      ctx.fill();
    }

    // 2. Right-aligned Mono Duration / Progress Badge
    var badgeText = String(item.badge || '');
    ctx.font = 'bold 10px ' + FONT_MONO;
    var badgeTextW = Math.ceil(ctx.measureText(badgeText).width);
    var eqWidth = showEq ? 20 : 0;
    var rightLimitX;

    if (isInsideCapsule) {
      var pillPadX = 8;
      var pillW = Math.max(40, badgeTextW + pillPadX * 2);
      var pillH = 20;
      var pillX = DISPLAY.listRight - 8 - pillW;
      var pillY = cy - pillH * 0.5;

      drawRoundRectPath(ctx, pillX, pillY, pillW, pillH, pillH * 0.5);
      ctx.fillStyle = PALETTE.darkInk;
      ctx.fill();

      ctx.fillStyle = tabAccent;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(badgeText, pillX + pillW * 0.5, cy + 0.5);

      if (showEq) {
        drawEqualizer(ctx, pillX - 20, cy - 5.5, PALETTE.darkInk, eqAnimate);
      }
      rightLimitX = pillX - eqWidth - 8;
    } else {
      var rightEdge = DISPLAY.listRight - 14;
      ctx.fillStyle = item.isActive ? tabAccent : PALETTE.textSecondary;
      ctx.textAlign = 'right';
      ctx.textBaseline = 'middle';
      ctx.fillText(badgeText, rightEdge, cy + 0.5);

      if (showEq) {
        drawEqualizer(ctx, rightEdge - badgeTextW - 22, cy - 5.5, tabAccent, eqAnimate);
      }
      rightLimitX = rightEdge - badgeTextW - eqWidth - 10;
    }

    // 3. Title & Secondary Line
    var maxTextW = Math.max(40, rightLimitX - textX);
    ctx.textAlign = 'left';
    ctx.textBaseline = 'alphabetic';

    if (isInsideCapsule) {
      ctx.fillStyle = PALETTE.darkInk;
      ctx.font = 'bold 13px ' + FONT_SANS;
      ctx.fillText(truncateFit(ctx, item.title, maxTextW), textX, ry + 14.5);

      ctx.fillStyle = PALETTE.darkInk;
      ctx.font = '600 10px ' + FONT_SANS;
      ctx.fillText(truncateFit(ctx, item.subtitle, maxTextW), textX, ry + 26.5);
    } else {
      ctx.fillStyle = PALETTE.textPrimary;
      ctx.font = '600 13px ' + FONT_SANS;
      ctx.fillText(truncateFit(ctx, item.title, maxTextW), textX, ry + 14.5);

      ctx.fillStyle = PALETTE.textSecondary;
      ctx.font = '500 10px ' + FONT_SANS;
      ctx.fillText(truncateFit(ctx, item.subtitle, maxTextW), textX, ry + 26.5);
    }
  }

  function drawRowList(ctx, state, items, tabIdx, tabAccent, helpers) {
    if (items.length === 0) {
      var centerX = (DISPLAY.listX + DISPLAY.listRight) * 0.5;
      var centerY = (DISPLAY.listY + DISPLAY.listBottom) * 0.5;

      // Floating accent orb directly on #000000 AMOLED void (zero grey box)
      ctx.save();
      ctx.shadowBlur = 16;
      ctx.shadowColor = hexToRgba(tabAccent, 0.45);
      ctx.fillStyle = tabAccent;
      ctx.beginPath();
      ctx.arc(centerX, centerY - 24, 16, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();

      drawCategoryIcon(ctx, tabIdx, centerX, centerY - 24, 1.0, PALETTE.darkInk);

      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = PALETTE.textPrimary;
      ctx.font = 'bold 13px ' + FONT_SANS;
      ctx.fillText(
        tabIdx === 4 ? 'No Saved Marks or WAV Notes Yet' : 'No Items Available',
        centerX,
        centerY + 8
      );
      ctx.fillStyle = PALETTE.textSecondary;
      ctx.font = '500 10.5px ' + FONT_SANS;
      ctx.fillText(
        tabIdx === 4 ? 'Press B4 (MARK) during playback or hold B8 (REC)' : 'Insert MicroSD or sync server library',
        centerX,
        centerY + 26
      );
      return;
    }

    var visibleCount = Math.min(DISPLAY.visibleRows, items.length - state.libScrollOffset);
    var rowW = DISPLAY.listRight - DISPLAY.listX;
    var rowH = DISPLAY.rowHeight;

    // 1. Draw unselected row layer directly on pure #000000 black
    for (var i = 0; i < visibleCount; i++) {
      var absIdx = state.libScrollOffset + i;
      var ry = slotY(i);
      drawRowContent(ctx, items[absIdx], ry, false, tabIdx, tabAccent, state);
      recordLibHitbox(helpers, {
        id: 'lib_row_' + i,
        x: DISPLAY.listX,
        y: ry,
        w: rowW,
        h: rowH,
        action: 'activateLibRow',
        rowIdx: absIdx
      });
    }

    // 2. Compute bouncy solid capsule geometry from _pillSpringY + _pillSquish
    var squish = clamp(Number(state._pillSquish) || 0, -0.22, 0.26);
    var scaleY = 1 + squish;
    var scaleX = 1 - squish * 0.06;
    var pw = rowW * scaleX;
    var ph = rowH * scaleY;
    var pillCy = state._pillSpringY + rowH * 0.5;
    var px = DISPLAY.listX + (rowW - pw) * 0.5;
    var py = pillCy - ph * 0.5;

    // 3. Draw 100% solid vibrant capsule pill with soft AMOLED glow
    ctx.save();
    ctx.shadowBlur = 14;
    ctx.shadowColor = hexToRgba(tabAccent, 0.42);
    drawRoundRectPath(ctx, px, py, pw, ph, ph * 0.5);
    ctx.fillStyle = tabAccent;
    ctx.fill();
    ctx.restore();

    // 4. Clip to the bouncy capsule pill and paint high-contrast #000000 active row contents
    ctx.save();
    drawRoundRectPath(ctx, px, py, pw, ph, ph * 0.5);
    ctx.clip();
    for (var j = 0; j < visibleCount; j++) {
      var absIdx2 = state.libScrollOffset + j;
      var ry2 = slotY(j);
      if (ry2 + rowH >= py - 2 && ry2 <= py + ph + 2) {
        drawRowContent(ctx, items[absIdx2], ry2, true, tabIdx, tabAccent, state);
      }
    }
    ctx.restore();
  }

  // --------------------------------------------------------------------------
  // 9. Right-Edge Lava-Droplet Velocity Indicator (x=508..522, y=84..220)
  // --------------------------------------------------------------------------
  function drawLavaVelocityIndicator(ctx, state, tabAccent) {
    var trackTop = DISPLAY.hudY;     // 84
    var trackBottom = DISPLAY.hudBottom; // 220
    var trackH = trackBottom - trackTop; // 136
    var cx = (DISPLAY.hudX + DISPLAY.hudRight) * 0.5; // 515

    // Minimalist pill rail (no grey HUD box or border)
    var railW = 6;
    drawRoundRectPath(ctx, cx - railW * 0.5, trackTop, railW, trackH, railW * 0.5);
    ctx.fillStyle = 'rgba(255, 255, 255, 0.08)';
    ctx.fill();

    ctx.fillStyle = hexToRgba(tabAccent, 0.14);
    drawRoundRectPath(ctx, cx - railW * 0.5, trackTop, railW, trackH, railW * 0.5);
    ctx.fill();

    var stretch = clamp(Number(state._hudStretch) || 0, 0, 1);
    var colorMix = clamp(Number(state._hudColorMix) || 0, 0, 1);
    var ratio = clamp(Number(state._hudThumbRatio) || 0, 0, 1);

    // Droplet stretches vertically: height = 18..48px proportional to velocity (1x..6x)
    var dropH = 18 + stretch * 30;
    var dropW = 10 + stretch * 2.5; // fits cleanly inside x=508..522 (14px)
    var dropY = trackTop + (trackH - dropH) * ratio;

    // Brighten through Gold (#EBD15E) -> Coral (#E0634E) as velocity rises
    var velColor = colorMix < 0.45
      ? lerpColor(tabAccent, PALETTE.chaptersGold, colorMix / 0.45)
      : lerpColor(PALETTE.chaptersGold, PALETTE.marksCoral, (colorMix - 0.45) / 0.55);

    var axes = readStickAxes(state.stick);
    var dir = axes.y;
    var bulge = clamp(dir * stretch * 3.0, -3.0, 3.0);

    ctx.save();
    ctx.shadowBlur = 7 + colorMix * 13;
    ctx.shadowColor = velColor;
    ctx.fillStyle = velColor;

    // Organic lava-droplet capsule (bulges slightly toward tilt direction)
    var rx = dropW * 0.5;
    var topR = clamp(rx - bulge * 0.35, 3.0, 6.8);
    var botR = clamp(rx + bulge * 0.35, 3.0, 6.8);
    var topCy = dropY + topR;
    var botCy = dropY + dropH - botR;

    ctx.beginPath();
    ctx.arc(cx, topCy, topR, Math.PI, 0, false);
    ctx.quadraticCurveTo(cx + rx + stretch * 0.8, (topCy + botCy) * 0.5, cx + botR, botCy);
    ctx.arc(cx, botCy, botR, 0, Math.PI, false);
    ctx.quadraticCurveTo(cx - rx - stretch * 0.8, (topCy + botCy) * 0.5, cx - topR, topCy);
    ctx.closePath();
    ctx.fill();

    // Subtle specular core sheen inside the lava bead
    ctx.shadowBlur = 0;
    ctx.fillStyle = 'rgba(255, 255, 255, ' + (0.22 + colorMix * 0.26).toFixed(2) + ')';
    drawRoundRectPath(ctx, cx - 1.5, dropY + 5, 3, Math.max(5, dropH * 0.28), 1.5);
    ctx.fill();
    ctx.restore();
  }

  // --------------------------------------------------------------------------
  // 10. Main Renderer: renderLibraryBrowser(ctx, state, helpers)
  // --------------------------------------------------------------------------
  function renderLibraryBrowser(ctx, state, helpers) {
    if (!ctx) return;
    ensureState(state);

    if (helpers && Array.isArray(helpers.hitboxes)) {
      helpers.hitboxes.length = 0;
    }

    // Advance springs smoothly even if caller didn't invoke updateStickPhysics this frame
    var nowMs = (typeof performance !== 'undefined' && typeof performance.now === 'function')
      ? performance.now()
      : Date.now();
    if (state._physicsSteppedInLoop) {
      state._physicsSteppedInLoop = false;
      state._lastRenderMs = nowMs;
    } else {
      var dtSec = typeof state._lastRenderMs === 'number'
        ? clamp((nowMs - state._lastRenderMs) / 1000, 0.001, 0.05)
        : 0.016;
      state._lastRenderMs = nowMs;
      stepVisualSprings(state, dtSec);
    }

    var hp = getHomePlayer();
    var tabIdx = state.libTabIdx;
    var tab = TABS[tabIdx] || TABS[0];

    // Pure #000000 True-Black AMOLED void
    ctx.fillStyle = PALETTE.voidBg;
    ctx.fillRect(0, 0, DISPLAY.width, DISPLAY.height);

    // 1. Top Status Bar (delegated to FBoxHomePlayer when present; no bottom strip)
    if (hp && typeof hp.drawTopStatusBar === 'function') {
      hp.drawTopStatusBar(ctx, state, helpers);
    } else {
      drawFallbackTopStatusBar(ctx, state, helpers);
    }

    // 2. Top Circular Category Bubbles (cy=50) + Lava-Lamp Metaball Bridge
    drawCategoryCircles(ctx, state, helpers);

    // 3. Minimalist 4-Row Viewport (x=24..494, y=82..226) + Bouncy Solid Capsule Pill
    var items = getItemsForTab(state, tabIdx);
    syncWindow(state, items.length);
    drawRowList(ctx, state, items, tabIdx, tab.accent, helpers);

    // 4. Right-Edge Minimalist Lava-Droplet Velocity Indicator (x=508..522, y=84..220)
    drawLavaVelocityIndicator(ctx, state, tab.accent);

    // 5. Toast overlay (delegates to FBoxHomePlayer.drawToast when available)
    if (hp && typeof hp.drawToast === 'function') {
      hp.drawToast(ctx, state);
    } else if (state.toast && Date.now() < (state.toast.until || 0)) {
      ctx.save();
      ctx.font = 'bold 10.5px ' + FONT_SANS;
      var tw = Math.min(460, Math.ceil(ctx.measureText(state.toast.text).width + 26));
      var tx = Math.round((DISPLAY.width - tw) * 0.5);
      var ty = 206;
      var toastColor = state.toast.color || tab.accent;
      ctx.shadowBlur = 12;
      ctx.shadowColor = hexToRgba(toastColor, 0.4);
      drawRoundRectPath(ctx, tx, ty, tw, 22, 11);
      ctx.fillStyle = toastColor;
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.fillStyle = PALETTE.darkInk;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(truncateFit(ctx, state.toast.text, tw - 16), DISPLAY.width * 0.5, ty + 11.5);
      ctx.restore();
    }
  }

  // --------------------------------------------------------------------------
  // Export to BOTH window.FBoxLibraryBrowser and FBoxModules.libraryBrowser
  // --------------------------------------------------------------------------
  var api = {
    DISPLAY: DISPLAY,
    PALETTE: PALETTE,
    TABS: TABS,
    KEY_HINTS: KEY_HINTS,
    DEFAULT_ABS_BOOKS: DEFAULT_ABS_BOOKS,
    DEFAULT_SPOTIFY_TRACKS: DEFAULT_SPOTIFY_TRACKS,
    DEFAULT_SD_FILES: DEFAULT_SD_FILES,
    formatTime: formatTime,
    getCatalog: getCatalog,
    ensureState: ensureState,
    getItemsForTab: getItemsForTab,
    renderLibraryBrowser: renderLibraryBrowser,
    moveCursor: moveCursor,
    switchTab: switchTab,
    updateStickPhysics: updateStickPhysics,
    activateSelectedRow: activateSelectedRow
  };

  root.FBoxLibraryBrowser = api;
  root.FBoxModules = root.FBoxModules || {};
  root.FBoxModules.libraryBrowser = api;
})(typeof window !== 'undefined' ? window : globalThis);

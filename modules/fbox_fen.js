/* ============================================================================
 * fbox OS — Fen Digital Companion Sprite Module
 * Target: 1.91" RM67162 True-Black AMOLED (536 x 240 px)
 * Self-contained classic <script> IIFE (file:// safe, no ES import/export)
 * Attaches API to window.FBoxFen
 * ========================================================================== */
(function (root) {
  'use strict';

  var PALETTE = Object.freeze({
    coat: '#E0634E',
    coatBright: '#FB7185',
    white: '#FFFFFF',
    voidInk: '#000000',
    teal: '#45B09C',
    gold: '#EBD15E',
    amber: '#E3A84B',
    dimArch: '#2A3342'
  });

  var MOODS = Object.freeze([
    'RESTING',
    'LISTENING',
    'BROWSING',
    'AI_LISTENING',
    'AI_THINKING',
    'FIELD_REC',
    'SLEEPING'
  ]);

  function clamp(v, lo, hi) {
    return v < lo ? lo : v > hi ? hi : v;
  }

  function normalizeMood(mood) {
    var m = String(mood || 'RESTING').toUpperCase();
    for (var i = 0; i < MOODS.length; i++) {
      if (MOODS[i] === m) return m;
    }
    return 'RESTING';
  }

  /**
   * Draw Fen geometric vector companion.
   * @param {CanvasRenderingContext2D} ctx
   * @param {number} x - center X
   * @param {number} y - center Y
   * @param {number} [scale=1]
   * @param {Object} [opts] - { mood, phase, playing, den, accent }
   */
  function drawFen(ctx, x, y, scale, opts) {
    if (!ctx) return;
    var o = opts || {};
    var sc = typeof scale === 'number' && Number.isFinite(scale) && scale > 0 ? scale : 1;
    var mood = normalizeMood(o.mood);
    var phase = typeof o.phase === 'number' && Number.isFinite(o.phase) ? o.phase : 0;
    var playing = Boolean(o.playing);

    ctx.save();
    ctx.translate(x, y);
    ctx.scale(sc, sc);

    // Subtle cozy den arch for RESTING on Home
    if (mood === 'RESTING' || o.den) {
      ctx.strokeStyle = o.accent || PALETTE.dimArch;
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      ctx.arc(0, 6, 22, Math.PI * 1.05, Math.PI * -0.05, false);
      ctx.stroke();
    }

    // Aura ring for AI listening / thinking / field recording
    if (mood === 'AI_LISTENING' || mood === 'AI_THINKING' || mood === 'FIELD_REC') {
      var pulse = 0.5 + 0.5 * Math.sin(phase * (mood === 'AI_LISTENING' ? 4.5 : 2.6));
      ctx.save();
      ctx.strokeStyle = PALETTE.coat;
      ctx.globalAlpha = 0.25 + pulse * 0.45;
      ctx.lineWidth = 1.8;
      ctx.beginPath();
      ctx.arc(0, 0, 20 + pulse * 4, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }

    // Sleeping curled ball (Pocket Lock)
    if (mood === 'SLEEPING') {
      var breathe = 1 + Math.sin(phase * 1.4) * 0.03;
      ctx.scale(breathe, 1 / breathe);

      // Curled coral body
      ctx.fillStyle = PALETTE.coat;
      ctx.beginPath();
      ctx.ellipse(0, 3, 15, 11, 0, 0, Math.PI * 2);
      ctx.fill();

      // Tucked tail with white tip
      ctx.beginPath();
      ctx.arc(9, 4, 6.5, -Math.PI * 0.4, Math.PI * 0.85, false);
      ctx.fill();
      ctx.fillStyle = PALETTE.white;
      ctx.beginPath();
      ctx.arc(13, 2, 3.6, 0, Math.PI * 2);
      ctx.fill();

      // Folded ear
      ctx.fillStyle = PALETTE.coat;
      ctx.beginPath();
      ctx.moveTo(-10, -4);
      ctx.lineTo(-14, -12);
      ctx.lineTo(-4, -8);
      ctx.closePath();
      ctx.fill();

      // Closed sleeping eye arc
      ctx.strokeStyle = PALETTE.voidInk;
      ctx.lineWidth = 1.6;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.arc(-5, 1, 3, 0.2, Math.PI - 0.2, false);
      ctx.stroke();

      // Tiny floating z
      ctx.fillStyle = PALETTE.amber;
      ctx.font = 'bold 8px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('z', 14, -10 - Math.sin(phase * 1.4) * 2);

      ctx.restore();
      return;
    }

    // Subtle motion bob/tilt for active moods
    var bobY = 0;
    var headTilt = 0;
    if (mood === 'LISTENING' && playing) {
      bobY = Math.sin(phase * 3.8) * 1.8;
      headTilt = Math.sin(phase * 1.9) * 0.06;
    } else if (mood === 'AI_THINKING') {
      headTilt = 0.14 + Math.sin(phase * 1.5) * 0.04;
    } else if (mood === 'BROWSING') {
      bobY = Math.sin(phase * 2.0) * 0.8;
    } else if (mood === 'RESTING') {
      bobY = Math.sin(phase * 1.3) * 0.6;
    }

    ctx.translate(0, bobY);
    ctx.rotate(headTilt);

    // Tail sweeping out to the right
    ctx.save();
    ctx.fillStyle = PALETTE.coat;
    ctx.beginPath();
    ctx.moveTo(7, 8);
    ctx.quadraticCurveTo(18, 10, 17, 1);
    ctx.quadraticCurveTo(14, -2, 8, 5);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = PALETTE.white;
    ctx.beginPath();
    ctx.arc(16.2, 2.2, 2.8, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    // Compact geometric torso
    ctx.fillStyle = PALETTE.coat;
    ctx.beginPath();
    ctx.ellipse(0, 8, 8.5, 6.5, 0, 0, Math.PI * 2);
    ctx.fill();

    // White chest tuft
    ctx.fillStyle = PALETTE.white;
    ctx.beginPath();
    ctx.ellipse(0, 7.5, 4, 3.8, 0, 0, Math.PI * 2);
    ctx.fill();

    // Large Fennec Ears (perked taller when AI_LISTENING / AI_THINKING / BROWSING)
    var earLift = (mood === 'AI_LISTENING' || mood === 'AI_THINKING' || mood === 'BROWSING') ? 3.2 : 0;

    // Left ear
    ctx.fillStyle = PALETTE.coat;
    ctx.beginPath();
    ctx.moveTo(-9, -3);
    ctx.lineTo(-15, -18 - earLift);
    ctx.lineTo(-2, -9);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = PALETTE.white;
    ctx.beginPath();
    ctx.moveTo(-8.5, -5);
    ctx.lineTo(-12.8, -14.5 - earLift * 0.8);
    ctx.lineTo(-4.2, -8.5);
    ctx.closePath();
    ctx.fill();

    // Right ear
    ctx.fillStyle = PALETTE.coat;
    ctx.beginPath();
    ctx.moveTo(9, -3);
    ctx.lineTo(15, -18 - earLift);
    ctx.lineTo(2, -9);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = PALETTE.white;
    ctx.beginPath();
    ctx.moveTo(8.5, -5);
    ctx.lineTo(12.8, -14.5 - earLift * 0.8);
    ctx.lineTo(4.2, -8.5);
    ctx.closePath();
    ctx.fill();

    // Head (rounded diamond/oval)
    ctx.fillStyle = PALETTE.coat;
    ctx.beginPath();
    ctx.ellipse(0, -3.5, 11, 8.5, 0, 0, Math.PI * 2);
    ctx.fill();

    // White cheeks
    ctx.fillStyle = PALETTE.white;
    ctx.beginPath();
    ctx.ellipse(-5.8, -1.2, 4.4, 3.0, -0.15, 0, Math.PI * 2);
    ctx.ellipse(5.8, -1.2, 4.4, 3.0, 0.15, 0, Math.PI * 2);
    ctx.fill();

    // Eyes (#000000 pupils)
    if (mood === 'RESTING') {
      // Cozy half-lidded/relaxed eyes
      ctx.strokeStyle = PALETTE.voidInk;
      ctx.lineWidth = 1.6;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.arc(-4.2, -4.0, 2.0, 0.15, Math.PI - 0.15, false);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(4.2, -4.0, 2.0, 0.15, Math.PI - 0.15, false);
      ctx.stroke();
    } else {
      var lookX = mood === 'BROWSING' ? -0.9 : 0;
      ctx.fillStyle = PALETTE.voidInk;
      ctx.beginPath();
      ctx.arc(-4.2 + lookX, -4.2, 1.9, 0, Math.PI * 2);
      ctx.arc(4.2 + lookX, -4.2, 1.9, 0, Math.PI * 2);
      ctx.fill();

      // Tiny white eye glint
      ctx.fillStyle = PALETTE.white;
      ctx.beginPath();
      ctx.arc(-4.7 + lookX, -4.8, 0.65, 0, Math.PI * 2);
      ctx.arc(3.7 + lookX, -4.8, 0.65, 0, Math.PI * 2);
      ctx.fill();
    }

    // Tiny nose
    ctx.fillStyle = PALETTE.voidInk;
    ctx.beginPath();
    ctx.arc(0, -1.4, 1.35, 0, Math.PI * 2);
    ctx.fill();

    // Tiny headphones when LISTENING or playing media
    if (mood === 'LISTENING' || (playing && mood !== 'AI_LISTENING' && mood !== 'FIELD_REC')) {
      ctx.strokeStyle = PALETTE.teal;
      ctx.lineWidth = 2.0;
      ctx.beginPath();
      ctx.arc(0, -4.5, 11.8, Math.PI * 1.08, Math.PI * -0.08, false);
      ctx.stroke();

      ctx.fillStyle = PALETTE.gold;
      ctx.beginPath();
      ctx.roundRect ? ctx.roundRect(-13.5, -6.5, 3.8, 6.5, 1.8) : ctx.rect(-13.5, -6.5, 3.8, 6.5);
      ctx.fill();
      ctx.beginPath();
      ctx.roundRect ? ctx.roundRect(9.7, -6.5, 3.8, 6.5, 1.8) : ctx.rect(9.7, -6.5, 3.8, 6.5);
      ctx.fill();
    }

    // Tiny mic capsule when FIELD_REC
    if (mood === 'FIELD_REC') {
      ctx.strokeStyle = PALETTE.white;
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      ctx.moveTo(-9, 6);
      ctx.lineTo(-13, -1);
      ctx.stroke();

      ctx.fillStyle = PALETTE.gold;
      ctx.beginPath();
      ctx.ellipse(-13.5, -2.5, 2.6, 3.6, -0.3, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = PALETTE.coat;
      ctx.beginPath();
      ctx.arc(-13.5, -2.5, 1.1, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
  }

  var api = {
    PALETTE: PALETTE,
    MOODS: MOODS,
    drawFen: drawFen
  };

  root.FBoxFen = api;
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
})(typeof window !== 'undefined' ? window : globalThis);

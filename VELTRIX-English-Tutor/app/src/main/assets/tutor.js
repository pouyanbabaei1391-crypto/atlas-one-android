/* VELTRIX AI · native private model, structured 3-stage English curriculum, no fabricated model responses. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const native = window.AndroidBridge || null;
  const catalog = window.VELTRIX_CURRICULUM;
  const DAY = 86400000;
  const STORE_KEY = 'veltrix_sprint_v3';
  const TYPES = ['word', 'grammar', 'collocation'];
  const getStore = (key, fallback) => { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch (_) { return fallback; } };
  const putStore = (key, value) => { try { localStorage.setItem(key, JSON.stringify(value)); } catch (_) {} };
  const oldProfile = getStore('veltrix_sprint_v2', null);
  const initial = {
    started: Date.now(), introduced: { word: [], grammar: [], collocation: [] },
    turn: 0, reviewTurn: 0, streak: 0, lastDate: '', total: 0
  };
  const profile = getStore(STORE_KEY, null) || {
    ...initial,
    started: oldProfile?.started || Date.now(),
    introduced: Object.fromEntries(TYPES.map(k => [k, Array.isArray(oldProfile?.introduced?.[k]) ? oldProfile.introduced[k] : []]))
  };
  if (!profile.started) profile.started = Date.now();
  if (!Number.isInteger(profile.turn) || profile.turn < 0) profile.turn = 0;
  for (const k of TYPES) if (!Array.isArray(profile.introduced?.[k])) {
    profile.introduced ||= {}; profile.introduced[k] = [];
  }
  const pools = {word: catalog.words, grammar: catalog.grammar, collocation: catalog.collocations};
  // Advanced structures are taught first, while every listed grammar topic remains in the 30-day syllabus.
  const grammarOrder = [
    ...catalog.grammar.filter(g => g.group === 'Writing and C1-C2'),
    ...catalog.grammar.filter(g => g.group === 'Complex Grammar'),
    ...catalog.grammar.filter(g => !['Writing and C1-C2', 'Complex Grammar'].includes(g.group))
  ];
  const state = {
    ready: false, installing: false, generating: false, speaking: true,
    stream: '', thinkingNode: null, activeFocus: null, robot: 'idle'
  };
  function safe(value, max = 8500) { return String(value ?? '').slice(0, max); }
  function toast(message) {
    const t = document.createElement('div'); t.className = 'toast'; t.textContent = safe(message, 300);
    $('toasts').append(t); setTimeout(() => t.remove(), 5000);
  }
  function robot(mode) {
    state.robot = mode; $('demo-companion').dataset.expression = mode;
    const words = { idle:'READY TO LEARN', thinking:'THINKING', listening:'LISTENING', speaking:'SPEAKING', happy:'WELL DONE', error:'CHECK MODEL' };
    $('robot-state').textContent = words[mode] || words.idle;
  }
  function day() { return Math.min(30, Math.max(1, Math.floor((Date.now() - profile.started) / DAY) + 1)); }
  function introducedCount() { return TYPES.reduce((n, kind) => n + profile.introduced[kind].length, 0); }
  function updatePace() {
    const d = day(); $('day-progress').textContent = `DAY ${d} / 30`;
    $('pace-summary').textContent = `${introducedCount()} ITEMS INTRODUCED`;
    // Exposure pacing is not a mastery measurement; show helpful progress instead of punitive alarms.
    const expected = Math.floor((catalog.words.length + catalog.grammar.length + catalog.collocations.length) * Math.max(0, d - 1) / 30);
    const deficit = Math.max(0, expected - introducedCount());
    const alert = $('pace-alert');
    if (d > 1 && deficit > 0 && getStore('veltrix_pace_dismissed_' + d, false) !== true) {
      $('pace-alert-text').textContent = `Your 30-day exposure target is ${deficit} items behind. A short session now helps you catch up. Mastery takes more than exposure.`;
      alert.hidden = false;
    } else alert.hidden = true;
  }
  $('pace-dismiss').addEventListener('click', () => {
    putStore('veltrix_pace_dismissed_' + day(), true); $('pace-alert').hidden = true;
  });
  // This is a deterministic, persisted cycle, not a model-chosen/randomized topic.
  // Word batches never repeat until 3,000 items have been introduced; likewise for collocations.
  function pickFocus() {
    const kind = TYPES[profile.turn % 3];
    const seen = new Set(profile.introduced[kind]);
    const ordered = kind === 'grammar' ? grammarOrder : pools[kind];
    const count = kind === 'grammar' ? 1 : 10;
    let items = ordered.filter(item => !seen.has(item.id)).slice(0, count);
    let review = false;
    if (!items.length) {
      review = true;
      const offset = (Math.floor(profile.reviewTurn / 3) * count) % Math.max(1, ordered.length);
      items = ordered.slice(offset, offset + count);
      if (items.length < count) items = items.concat(ordered.slice(0, count - items.length));
    }
    if (!items.length) return null;
    return {kind, items, review, turn: profile.turn};
  }
  function focusLabel(focus) {
    return focus.items.map((it, i) => `${i + 1}. ${it.term || it.title}`).join('\n');
  }
  function appendBubble(kind, value) {
    $('empty-state')?.remove();
    const msg = document.createElement('article'); msg.className = 'message ' + kind;
    const label = document.createElement('div'); label.className = 'label'; label.textContent = kind === 'user' ? 'YOU' : 'VELTRIX AI';
    const bubble = document.createElement('div'); bubble.className = 'bubble'; bubble.textContent = safe(value);
    msg.append(label, bubble); $('conversation').append(msg); scrollBottom(); return {msg, bubble};
  }
  function scrollBottom() { const log = $('conversation'); requestAnimationFrame(() => { log.scrollTop = log.scrollHeight; }); }
  function parseOutput(raw) {
    const text = String(raw ?? '').replace(/\r/g, '').replace(/\*\*/g, '').replace(/^```[^\n]*\n?|```$/gm, '').trim();
    const answer = text.match(/(?:^|\n)\s*(?:#{1,3}\s*)?ANSWER\s*:\s*([\s\S]*?)(?=\n\s*(?:#{1,3}\s*)?PRACTICE\s*:|$)/i);
    const practice = text.match(/(?:^|\n)\s*(?:#{1,3}\s*)?PRACTICE\s*:\s*([\s\S]*)$/i);
    return {answer: answer?.[1]?.trim() || '', practice: practice?.[1]?.trim() || '', ok: Boolean(answer?.[1]?.trim() && practice?.[1]?.trim())};
  }
  function practiceLines(text) { return text.split('\n').map(s => s.trim()).filter(Boolean); }
  function validateLesson(parsed, focus) {
    if (!parsed.ok) return {ok:false, reason:'The model omitted ANSWER or PRACTICE.'};
    const lines = practiceLines(parsed.practice);
    if (lines.length > 15) return {ok:false, reason:'Practice exceeded the 15-line limit.'};
    if (!lines.length || !/^\s*(?:exercise|challenge|your turn)\s*:/i.test(lines[lines.length - 1])) {
      return {ok:false, reason:'The practice exercise must be the last line.'};
    }
    if (focus.kind !== 'grammar') {
      if (lines.length < 11 || lines.length > 15) return {ok:false, reason:'Expected ten entries followed by an exercise.'};
      for (let i = 0; i < focus.items.length; i++) {
        const entry = lines.find(line => new RegExp(`^${i + 1}[.)]\\s`).test(line));
        const term = (focus.items[i].term || '').toLocaleLowerCase('en');
        if (!entry || !entry.toLocaleLowerCase('en').includes(term)) {
          return {ok:false, reason:`The model omitted curriculum item ${i + 1}: ${term}.`};
        }
        if (!entry.includes('—') && !entry.includes('–') && !entry.includes(' - ')) return {ok:false, reason:'Every entry needs a brief English definition.'};
        if (!/\b(?:ex\.?|example)\s*:/i.test(entry)) return {ok:false, reason:'Every entry needs a short example sentence.'};
      }
    } else {
      const target = (focus.items[0].title || '').toLocaleLowerCase('en');
      if (!parsed.practice.toLocaleLowerCase('en').includes(target)) return {ok:false, reason:'The assigned grammar topic was omitted.'};
      if (!/\b(?:ex\.?|example)\s*:/i.test(parsed.practice)) return {ok:false, reason:'The grammar point needs an example.'};
    }
    return {ok:true};
  }
  function renderLesson(raw, node, focus) {
    const parsed = parseOutput(raw);
    const validity = validateLesson(parsed, focus);
    node.msg.querySelector('.bubble')?.remove();
    // Even when the model's formatting is incomplete, preserve the promised TWO cards.
    // Never mark an incomplete set as introduced. A simple, explicitly identified retry exercise remains available.
    const fallbackExercise = focus.kind === 'grammar'
      ? `Exercise: Write a sentence using \"${focus.items[0].title}\".`
      : `Exercise: Write one English sentence using \"${focus.items[0].term}\".`;
    let answer = parsed.answer;
    let practice = parsed.practice;
    if (!validity.ok) {
      answer ||= 'The response was incomplete. Please send your sentence again.';
      const partial = practiceLines(practice).filter(line => !/^\s*(?:exercise|challenge|your turn)\s*:/i.test(line)).slice(0, 14);
      practice = [...partial, fallbackExercise].join('\n');
      toast(validity.reason + ' Lesson not counted; resend your sentence to retry this topic.');
    }
    const grid = document.createElement('div'); grid.className = 'lesson-pair';
    if (!validity.ok) grid.dataset.incomplete = 'true';
    for (const [kind, value] of [['answer', answer], ['practice', practice]]) {
      const card = document.createElement('section'); card.className = 'lesson-card ' + kind;
      const title = document.createElement('div'); title.className = 'kicker';
      title.textContent = kind === 'answer' ? '01  /  ANSWER' : '02  /  PRACTICE';
      const content = document.createElement('p'); content.textContent = safe(value);
      if (kind === 'practice') {content.classList.add('practice-lines'); content.setAttribute('aria-label', 'English lesson with an exercise');}
      card.append(title, content); grid.append(card);
    }
    node.msg.append(grid); scrollBottom(); return {ok:validity.ok, parsed};
  }
  function markIntroduced(focus) {
    if (!focus || profile.turn !== focus.turn) return;
    const seen = new Set(profile.introduced[focus.kind]);
    for (const item of focus.items) seen.add(item.id);
    profile.introduced[focus.kind] = Array.from(seen);
    profile.turn++;
    if (focus.review) profile.reviewTurn++;
    profile.total = introducedCount();
    putStore(STORE_KEY, profile); updatePace();
  }
  function submit(input) {
    const message = String(input || '').trim();
    if (!message || state.generating) return;
    if (!state.ready) {toast('Install or import MODEL before speaking.'); return;}
    const focus = pickFocus(); if (!focus) {toast('The curriculum could not be loaded.'); return;}
    state.activeFocus = focus; state.generating = true; state.stream = '';
    appendBubble('user', message); $('message-input').value = ''; $('message-input').style.height = 'auto';
    state.thinkingNode = appendBubble('assistant', 'Thinking…'); $('send-button').disabled = true; robot('thinking');
    try { native.ask(message, focus.kind, focusLabel(focus), 'C1'); }
    catch (_) { state.generating = false; $('send-button').disabled = false; toast('The private Android model is unavailable.'); }
  }
  function setup({installed = false, ready = false, installing = false}) {
    state.ready = !!ready; state.installing = !!installing;
    $('model-setup').classList.toggle('is-ready', ready);
    $('model-status').textContent = ready ? 'MODEL READY' : installed ? 'MODEL LOADING' : 'MODEL OFFLINE';
    $('model-status').classList.toggle('ready', ready); $('setup-buttons').hidden = installing;
    if (!ready) {
      $('setup-title').textContent = installed ? 'Loading existing MODEL…' : 'Private model setup';
      $('setup-description').textContent = installed ? 'The installed MODEL is being reused.' : 'Install the private MODEL once, or import an existing compatible GGUF.';
    }
  }
  window.Veltrix = {onNative(payload) {
    let event = payload; try {if (typeof event === 'string') event = JSON.parse(event);} catch (_) {return;}
    switch (event.type) {
      case 'status': setup(event); break;
      case 'model_progress':
        state.installing = true; $('model-progress').hidden = false; $('setup-buttons').hidden = true;
        $('setup-title').textContent = event.message || 'Preparing MODEL…';
        $('model-progress-fill').style.width = (event.percent >= 0 ? event.percent : 3) + '%'; break;
      case 'model_ready': setup({installed:true, ready:true}); robot('happy'); toast('MODEL ready. Start your English practice!'); break;
      case 'generation_start': robot('thinking'); break;
      case 'generation_chunk': state.stream = safe(event.text); if (state.thinkingNode) state.thinkingNode.bubble.textContent = state.stream; scrollBottom(); break;
      case 'generation_done': {
        state.generating = false; $('send-button').disabled = false; state.stream = event.text || state.stream;
        const result = state.thinkingNode && state.activeFocus && renderLesson(state.stream, state.thinkingNode, state.activeFocus);
        if (result?.ok) {
          markIntroduced(state.activeFocus);
          if (state.speaking && native) native.speak((result.parsed.answer + '. ' + result.parsed.practice).slice(0, 1100));
        }
        state.activeFocus = null; robot('happy'); break;
      }
      case 'generation_cancelled': state.generating = false; $('send-button').disabled = false; state.activeFocus = null; robot('idle'); break;
      case 'transcription': $('message-input').value = event.text || ''; submit(event.text); break;
      case 'speech_partial': $('message-input').value = event.text || ''; break;
      case 'robot': robot(event.state || 'idle'); break;
      case 'error': {
        toast(event.message || 'Something went wrong.'); state.generating = false; $('send-button').disabled = false;
        if (state.installing) {state.installing = false; $('setup-buttons').hidden = false;}
        robot('error'); break;
      }
    }
  }};
  $('composer').addEventListener('submit', e => {e.preventDefault(); submit($('message-input').value);});
  $('message-input').addEventListener('input', e => {e.target.style.height = 'auto'; e.target.style.height = Math.min(e.target.scrollHeight, 116) + 'px';});
  $('message-input').addEventListener('keydown', e => {if (e.key === 'Enter' && !e.shiftKey) {e.preventDefault(); submit(e.target.value);}});
  $('mic-button').addEventListener('click', () => {
    if (!native) {toast('The microphone works in the Android app.'); return;}
    if (state.generating) {toast('Tap STOP before starting a new turn.'); return;}
    native.beginVoice();
  });
  $('stop-button').addEventListener('click', () => {native?.stopAll(); state.generating = false; state.activeFocus = null; $('send-button').disabled = false; robot('idle');});
  $('tts-toggle').addEventListener('click', () => {
    state.speaking = !state.speaking; $('tts-toggle').textContent = state.speaking ? 'VOICE ON' : 'VOICE OFF';
    native?.setSpeaking(state.speaking); if (!state.speaking) native?.stopVoice();
  });
  $('install-model').addEventListener('click', () => native ? native.installModel() : toast('Private MODEL installation requires the Android APK.'));
  $('import-model').addEventListener('click', () => native ? native.importModel() : toast('Import requires the Android APK.'));
  updatePace(); setup({});
  if (native) setTimeout(() => native.getStatus(), 200);
  else {$('setup-title').textContent = 'Android APK required'; $('setup-description').textContent = 'Browser preview only. Install the Android app for private offline inference.';}
})();

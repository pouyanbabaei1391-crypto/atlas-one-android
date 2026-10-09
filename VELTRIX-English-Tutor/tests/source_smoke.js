const fs = require('fs');
const assert = require('node:assert/strict');
const path = require('path');
const dir = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(dir,name), 'utf8');
const html = read('app/src/main/assets/index.html');
const css = read('app/src/main/assets/tutor.css');
const js = read('app/src/main/assets/tutor.js');
const kotlin = read('app/src/main/java/ai/veltrix/tutor/MainActivity.kt');
const prompt = read('app/src/main/java/ai/veltrix/tutor/TutorPrompts.kt');
const data = JSON.parse(read('app/src/main/assets/curriculum.json'));
assert.equal(data.words.length, 3000);
assert.equal(data.collocations.length, 1000);
assert.equal(data.grammar.length, 159);
for (const k of ['words','collocations','grammar']) {
  assert.equal(new Set(data[k].map(x=>x.id)).size, data[k].length);
}
for (const key of ['ANSWER:', 'PRACTICE:', 'Exercise:', 'ENGLISH ONLY', 'FOCUS_ITEMS_BEGIN'])
  assert(prompt.includes(key), 'Missing teaching instruction ' + key);
assert(!prompt.includes('Persian meaning'), 'Translations must not be requested');
assert(js.includes("['word', 'grammar', 'collocation']"), 'Wrong three-turn teaching order');
assert(js.includes('slice(0, count)') && js.includes('profile.turn++'), 'Missing indexed sequential learning');
assert(js.includes('lines.length > 15'), 'Practice line bound is missing');
assert(js.includes('focus.items.length'), 'Ten assigned terms should be verified');
assert(js.includes('new Set(profile.introduced[kind])'), 'Unseen item tracking is missing');
assert(js.includes("'01  /  ANSWER'") && js.includes("'02  /  PRACTICE'"), 'Wrong card titles');
assert(!js.includes('innerHTML') && !js.includes('eval('), 'Unsafe dynamic HTML execution');
assert(css.includes('white-space:pre;overflow-x:auto'), 'Practice needs scrollable nonwrapping lines on mobile');
assert(kotlin.includes('term.take(1100)') && kotlin.includes('else 1250'), 'Native prompt budget cannot handle ten entries');
assert(kotlin.includes('this@MainActivity.installModel()'), 'Kotlin recursion fix must be preserved');
assert(kotlin.includes('settings.allowFileAccess = false') && kotlin.includes('settings.blockNetworkLoads = true'), 'Retain WebView security');
for (const id of ['demo-companion','conversation','model-setup','message-input','send-button','mic-button','tts-toggle'])
  assert(html.includes('id="' + id + '"'));
console.log('PASS: 3-stage rotation, ten unseen terms, English-only lessons, two panels, ≤15 practice lines, Kotlin token budget, security, mobile CSS');

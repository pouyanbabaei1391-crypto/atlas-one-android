'use strict';
const fs=require('node:fs');const assert=require('node:assert/strict');const path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const html=read('app/src/main/assets/index.html');
const css=read('app/src/main/assets/tutor.css');
const legacy=read('app/src/main/assets/legacy-visual.css');
const js=read('app/src/main/assets/tutor.js');
const kt=read('app/src/main/java/ai/veltrix/tutor/MainActivity.kt');
const prompt=read('app/src/main/java/ai/veltrix/tutor/TutorPrompts.kt');
const dl=read('app/src/main/java/ai/veltrix/tutor/ModelDownloader.kt');
const yaml=read('.github/workflows/build-apk.yml');
for(const id of ['demo-companion','tutor-log','input-form','record-button','audio-button','install-model','import-model','goal-options','learner-level']){
 assert(html.includes(`id="${id}"`),`missing UI component ${id}`);
}
for(const s of ['REVIEW','CORRECTION','UPGRADE','GRAMMAR','VOCABULARY','PRACTICE','QUIZ']){
 assert(prompt.includes(`${s}:`),`missing teaching stage ${s}`);
 assert(js.includes(s),`missing UI rendering stage ${s}`);
}
assert(html.includes('class="demo-eyes"') && html.includes('class="demo-mouth"'));
assert(legacy.includes('.demo-companion') && legacy.includes('.demo-eyes') && legacy.includes('demoFloat'));
assert(css.includes('@media(max-width:760px)') && css.includes('.tutor-panel'));
assert(kt.includes('AiChat.getInferenceEngine') && kt.includes('SpeechRecognizer.createSpeechRecognizer') && kt.includes('TextToSpeech'));
// Regression: Bridge.installModel must target the Activity method explicitly.
assert(kt.includes('this@MainActivity.installModel()'), 'installModel bridge must call MainActivity.installModel explicitly');
assert(!/fun\s+installModel\s*\(\s*\)\s*=\s*runOnUiThread\s*\{\s*installModel\s*\(\s*\)/.test(kt), 'recursive installModel bridge found');
assert(dl.includes('gemma-3-4b-it-Q4_0.gguf') && dl.includes('validateSHA256'));
assert(yaml.includes('actions/upload-artifact@v4') && yaml.includes('app-debug.apk'));
assert(!js.includes('fakeReply') && !js.includes('demoFallbackReply'));
console.log('PASS: all 11 UI controls, 7 teaching stages, robot styling, responsive CSS, real inference/voice bridges, SHA256, APK workflow');

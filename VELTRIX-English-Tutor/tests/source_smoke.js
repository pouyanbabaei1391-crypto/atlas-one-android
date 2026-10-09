const fs=require('fs');const assert=require('node:assert/strict');const path=require('path');
const base=path.resolve(__dirname,'..');const read=p=>fs.readFileSync(path.join(base,p),'utf8');
const html=read('app/src/main/assets/index.html'),css=read('app/src/main/assets/tutor.css'),js=read('app/src/main/assets/tutor.js');
const main=read('app/src/main/java/ai/veltrix/tutor/MainActivity.kt'),dl=read('app/src/main/java/ai/veltrix/tutor/ModelDownloader.kt');
const prompt=read('app/src/main/java/ai/veltrix/tutor/TutorPrompts.kt');
const data=JSON.parse(read('app/src/main/assets/curriculum.json'));
assert.equal(data.words.length,3000);assert.equal(data.collocations.length,1000);assert.equal(data.grammar.length,159);
for(const key of ['words','collocations','grammar']){
 assert.equal(new Set(data[key].map(x=>x.id)).size,data[key].length);
 assert.equal(new Set(data[key].map(x=>x.term||x.title)).size,data[key].length);
}
for(const id of ['demo-companion','conversation','message-input','mic-button','send-button','tts-toggle','stop-button','model-setup','pace-alert','install-model','import-model'])assert(html.includes('id="'+id+'"'),'missing '+id);
for(const h of ['UPGRADE:','FOCUS:'])assert(prompt.includes(h));
for(const h of ['REVIEW:','CORRECTION:','GRAMMAR:','VOCABULARY:','PRACTICE:','QUIZ:'])assert(!prompt.includes(h),'old verbose prompt remains');
assert(main.includes('this@MainActivity.installModel()'));
assert(main.includes('settings.allowFileAccess = false')&&main.includes('settings.blockNetworkLoads = true'));
assert(main.includes('blankBlockedResource()')&&main.includes('WebView.setWebContentsDebuggingEnabled(false)'));
assert(dl.includes('Qwen3-1.7B-GGUF')&&dl.includes('validateSHA256'));
assert(dl.includes('veltrix-fast-qwen3-1_7b-q4km.gguf'));
assert(js.includes('pickFocus')&&js.includes('markIntroduced')&&js.includes('renderLesson'));
assert(!js.includes('innerHTML')&&!js.includes('eval(')&&!js.includes('fakeReply'));
assert(css.includes('@media(max-width:700px)'));
const wf=read('deploy/veltrix-english-tutor.yml');assert(wf.includes('VELTRIX-English-Tutor.apk'));
console.log('PASS: corpus 3000/1000/159, 2-section tutor, hardened local bridge, model digest, 30-day scheduler, mobile layout, APK workflow');

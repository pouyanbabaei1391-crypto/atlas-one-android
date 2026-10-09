/* VELTRIX · privacy-first English micro-lessons. No fake model text, no network SDKs. */
(() => {'use strict';
const $ = id => document.getElementById(id);
const native = window.AndroidBridge || null;
const catalog = window.VELTRIX_CURRICULUM;
const getStore = (k, fallback) => { try {return JSON.parse(localStorage.getItem(k)) ?? fallback;}catch(_){return fallback;} };
const putStore = (k,v) => {try{localStorage.setItem(k,JSON.stringify(v));}catch(_){}};
const now = () => Date.now();
const DAY = 86400000;
const profile = getStore('veltrix_sprint_v2',{started:now(),introduced:{word:[],collocation:[],grammar:[]},streak:0,lastDate:'',total:0});
if(!profile.started)profile.started=now();
for(const k of ['word','collocation','grammar'])if(!Array.isArray(profile.introduced[k]))profile.introduced[k]=[];
const pools={word:catalog.words,collocation:catalog.collocations,grammar:catalog.grammar};
const state={ready:false,installing:false,generating:false,speaking:true,stream:'',thinkingNode:null,activeFocus:null,robot:'idle'};
function textSafe(value){return String(value||'').slice(0,3000)}
function toast(message){const t=document.createElement('div');t.className='toast';t.textContent=textSafe(message);$('toasts').append(t);setTimeout(()=>t.remove(),4500);}
function robot(mode){state.robot=mode;$('demo-companion').dataset.expression=mode;const words={idle:'READY TO LEARN',thinking:'THINKING',listening:'LISTENING',speaking:'SPEAKING',happy:'WELL DONE',error:'CHECK MODEL'};$('robot-state').textContent=words[mode]||words.idle;}
function day(){return Math.min(30,Math.max(1,Math.floor((now()-profile.started)/DAY)+1));}
function updatePace(){const d=day();$('day-progress').textContent=`DAY ${d} / 30`;const learned=Object.values(profile.introduced).reduce((a,b)=>a+b.length,0);$('pace-summary').textContent=`${learned} TOPICS INTRODUCED`;
 const behind=['word','collocation','grammar'].map(kind=>{const expected=Math.floor(pools[kind].length*Math.max(0,d-1)/30);return Math.max(0,expected-profile.introduced[kind].length)});
 const deficit=behind.reduce((a,b)=>a+b,0),notice=$('pace-alert');
 if(d>1&&deficit>0&&getStore('veltrix_pace_dismissed_'+d,false)!==true){notice.hidden=false;$('pace-alert-text').textContent=`Your 30-day exposure plan is ${deficit} items behind its stretch schedule. Short daily practice helps; you can adjust the goal.`;}else notice.hidden=true;
}
$('pace-dismiss').addEventListener('click',()=>{putStore('veltrix_pace_dismissed_'+day(),true);$('pace-alert').hidden=true;});
function pickFocus(){const d=day();const types=['word','collocation','grammar'];let best=types[0],score=-Infinity;
 for(const type of types){const remaining=pools[type].length-profile.introduced[type].length;if(remaining<=0)continue;
 const ideal=Math.ceil(pools[type].length*d/30);const gap=Math.max(0,ideal-profile.introduced[type].length);
 const weighted=(gap/Math.max(1,pools[type].length/30))+(type==='grammar'?.09:0);
 if(weighted>score){score=weighted;best=type;}}
 const seen=new Set(profile.introduced[best]);const item=pools[best].find(x=>!seen.has(x.id));return item?{kind:best,item}:null;
}
function appendBubble(kind,value){const empty=$('empty-state');if(empty)empty.remove();const msg=document.createElement('article');msg.className='message '+kind;const label=document.createElement('div');label.className='label';label.textContent=kind==='user'?'YOU':'VELTRIX AI';const bubble=document.createElement('div');bubble.className='bubble';bubble.textContent=textSafe(value);msg.append(label,bubble);$('conversation').append(msg);scrollBottom();return{msg,bubble};}
function scrollBottom(){const log=$('conversation');requestAnimationFrame(()=>log.scrollTop=log.scrollHeight)}
function parseOutput(text){let all=String(text||'').replace(/\r/g,'').replace(/\*\*/g,'');const u=all.match(/(?:^|\n)\s*(?:#{1,3}\s*)?UPGRADE\s*:\s*([\s\S]*?)(?=\n\s*(?:#{1,3}\s*)?FOCUS\s*:|$)/i);const f=all.match(/(?:^|\n)\s*(?:#{1,3}\s*)?FOCUS\s*:\s*([\s\S]*)$/i);return {upgrade:u?.[1]?.trim()||'',focus:f?.[1]?.trim()||'',ok:!!(u?.[1]?.trim()&&f?.[1]?.trim())};}
function renderLesson(raw,node){const parsed=parseOutput(raw);node.msg.querySelector('.bubble')?.remove();if(!parsed.ok){const warning=document.createElement('div');warning.className='bubble lesson-raw';warning.textContent=textSafe(raw);node.msg.append(warning);toast('The model omitted a lesson section. Please ask it to use UPGRADE and FOCUS.');return false;}
 const grid=document.createElement('div');grid.className='lesson-pair';for(const [kind,value] of [['upgrade',parsed.upgrade],['focus',parsed.focus]]){const card=document.createElement('section');card.className='lesson-card '+kind;const kicker=document.createElement('div');kicker.className='kicker';kicker.textContent=kind==='upgrade'?'01  /  SENTENCE UPGRADE':'02  /  MICRO LESSON';const p=document.createElement('p');p.textContent=textSafe(value);card.append(kicker,p);grid.append(card);}node.msg.append(grid);scrollBottom();return true;
}
function markIntroduced(focus){if(!focus)return;const {kind,item}=focus;const list=profile.introduced[kind];if(!list.includes(item.id)){list.push(item.id);profile.total++;}putStore('veltrix_sprint_v2',profile);updatePace();}
function submit(input){const message=String(input||'').trim();if(!message||state.generating)return;if(!state.ready){toast('Install or import your MODEL before speaking.');return;}
 const focus=pickFocus();if(!focus){toast('All scheduled items introduced. Keep reviewing for retention.');return;}
 state.activeFocus=focus;state.generating=true;state.stream='';appendBubble('user',message);$('message-input').value='';$('message-input').style.height='auto';state.thinkingNode=appendBubble('assistant','Thinking…');$('send-button').disabled=true;robot('thinking');
 try{native.ask(message,focus.kind,focus.item.term||focus.item.title,'A1');}catch(_){state.generating=false;$('send-button').disabled=false;toast('Android model bridge is not available.');}
}
function setup({installed=false,ready=false,installing=false}){state.ready=!!ready;state.installing=!!installing;$('model-setup').classList.toggle('is-ready',ready);$('model-status').textContent=ready?'MODEL READY':installed?'MODEL LOADING':'MODEL OFFLINE';$('model-status').classList.toggle('ready',ready);$('setup-buttons').hidden=installing; if(!ready){$('setup-title').textContent=installed?'Loading existing model…':'Private model setup';$('setup-description').textContent=installed?'The already-installed model is being reused.':'Install the fast model once (~1.28 GB), or import the exact matching GGUF from this device.';}}
window.Veltrix={onNative(payload){let e=payload;try{if(typeof e==='string')e=JSON.parse(e);}catch(_){return;}switch(e.type){
 case 'status':setup(e);break;
 case 'model_progress':state.installing=true;$('model-progress').hidden=false;$('setup-buttons').hidden=true;$('setup-title').textContent=e.message||'Preparing…';$('model-progress-fill').style.width=(e.percent>=0?e.percent:3)+'%';break;
 case 'model_ready':setup({installed:true,ready:true});robot('happy');toast('MODEL ready. Speak a sentence!');break;
 case 'generation_start':robot('thinking');break;
 case 'generation_chunk':state.stream=textSafe(e.text);if(state.thinkingNode)state.thinkingNode.bubble.textContent=state.stream;scrollBottom();break;
 case 'generation_done':{state.generating=false;$('send-button').disabled=false;state.stream=e.text||state.stream;const ok=state.thinkingNode&&renderLesson(state.stream,state.thinkingNode);if(ok){const parsed=parseOutput(state.stream);const term=String(state.activeFocus?.item?.term||state.activeFocus?.item?.title||'').toLowerCase();if(term && parsed.focus.toLowerCase().includes(term))markIntroduced(state.activeFocus);else toast('Lesson did not cover the assigned topic; it was not counted.');}robot('happy');if(ok&&state.speaking&&native){const p=parseOutput(state.stream);native.speak((p.upgrade+'. '+p.focus).slice(0,900));}state.activeFocus=null;break;}
 case 'generation_cancelled':state.generating=false;$('send-button').disabled=false;robot('idle');break;
 case 'transcription':$('message-input').value=e.text||'';submit(e.text);break;
 case 'speech_partial':$('message-input').value=e.text||'';break;
 case 'robot':robot(e.state||'idle');break;
 case 'error':{toast(e.message||'Something went wrong.');state.generating=false;$('send-button').disabled=false;if(state.installing){state.installing=false;$('setup-buttons').hidden=false;}robot('error');break;}
 }}};
$('composer').addEventListener('submit',e=>{e.preventDefault();submit($('message-input').value);});
$('message-input').addEventListener('input',e=>{e.target.style.height='auto';e.target.style.height=Math.min(e.target.scrollHeight,116)+'px';});
$('message-input').addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();submit(e.target.value);}});
$('mic-button').addEventListener('click',()=>{if(!native){toast('Microphone is available in the Android app.');return;}if(state.generating){toast('Tap STOP before starting a new turn.');return;}native.beginVoice();});
$('stop-button').addEventListener('click',()=>{native?.stopAll();state.generating=false;$('send-button').disabled=false;robot('idle');});
$('tts-toggle').addEventListener('click',()=>{state.speaking=!state.speaking;$('tts-toggle').textContent=state.speaking?'VOICE ON':'VOICE OFF';native?.setSpeaking(state.speaking);if(!state.speaking)native?.stopVoice();});
$('install-model').addEventListener('click',()=>native?native.installModel():toast('Only Android APK can install a private model.'));
$('import-model').addEventListener('click',()=>native?native.importModel():toast('Import is only available inside Android APK.'));
updatePace();setup({});if(native)setTimeout(()=>native.getStatus(),200);else{$('setup-title').textContent='Android APK required';$('setup-description').textContent='Browser preview only. The native Android application runs the private model.';}
})();

/* VELTRIX AI English Tutor — real Android native inference; never fakes model answers. */
(() => {
'use strict';
const $ = s => document.querySelector(s);
const android = window.AndroidBridge || null;
const sections = ['REVIEW','CORRECTION','UPGRADE','GRAMMAR','VOCABULARY','PRACTICE','QUIZ'];
const store = (key, fallback) => { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; } };
const save = (key, value) => { try { localStorage.setItem(key, JSON.stringify(value)); } catch { } };
const dayStamp = () => new Date().toISOString().slice(0,10);
const state = {
    modelReady:false, installing:false, generating:false, listening:false, speaking:true,
    goal: store('veltrix_goal','Everyday conversation'),
    level: store('veltrix_level','A1'),
    xp: store('veltrix_xp',0),
    lastStudy: store('veltrix_lastStudy',''),
    streak: store('veltrix_streak',0),
    turnCount:store('veltrix_turnCount',0),
    replyText:'',streamEl:null,bubbleEl:null, currentPrompt:'',lastQuiz:'', stage:'idle'
};

function toast(text){
    const root=$('#toasts'),n=document.createElement('div');n.className='vl-toast';n.textContent=text;root.append(n);
    setTimeout(()=>n.remove(),6500);
}
function setRobot(mode,label){
    state.stage=mode;
    const robot=$('#demo-companion'),eq=$('#demo-equalizer');
    if(robot)robot.dataset.expression=({thinking:'thinking',speaking:'speaking',listening:'listening',happy:'happy',error:'sleepy'}[mode]||'idle');
    if(eq)eq.classList.toggle('is-talking',mode==='speaking');
    $('#demo-state-label').textContent=label||({thinking:'THINKING · CREATING YOUR LESSON',speaking:'SPEAKING · PRACTICE ALOUD',listening:'LISTENING · SPEAK ENGLISH',happy:'WELL DONE · READY FOR YOUR ANSWER',idle:'READY FOR YOUR VOICE',error:'MODEL NEEDS ATTENTION'}[mode]||'READY');
    $('#demo-scene-status').textContent=mode.toUpperCase();
}
function pushMessage(role,message){
    const log=$('#tutor-log');
    if(log.querySelector('.intro-empty'))log.replaceChildren();
    const node=document.createElement('div');node.className=role==='user'?'user-bubble':'ai-bubble';
    const label=document.createElement('small');label.textContent=role==='user'?'YOU / SPEAKING':'VELTRIX AI / TUTOR';
    const content=document.createElement('div');content.textContent=message;
    if(role!=='user')content.className='ai-stream';
    node.append(label,content);log.append(node);log.scrollTop=log.scrollHeight;
    return {node,content};
}
function parseSections(text){
    const src=String(text||'').replace(/\r\n/g,'\n');
    const lines=src.split('\n');const found=[];let current=null;
    const pattern=/^\s*(?:#{1,4}\s*)?(?:\*\*)?\s*(REVIEW|CORRECTION|UPGRADE|GRAMMAR|VOCABULARY|PRACTICE|QUIZ)\s*:?(?:\*\*)?\s*(.*)$/i;
    for(const line of lines){
        const match=line.match(pattern);
        if(match){
            current={title:match[1].toUpperCase(),text:match[2].trim()};found.push(current);
        }else if(current){current.text+=(current.text?'\n':'')+line;}
    }
    return found.map(x=>({...x,text:x.text.trim()}));
}
function card(section){
    const root=document.createElement('article');root.className='lesson-card';root.dataset.section=section.title;
    const header=document.createElement('header');const idx=sections.indexOf(section.title);
    header.textContent=`${String(idx+1).padStart(2,'0')} · ${section.title}`;
    const text=document.createElement('div');text.className='lesson-text';text.textContent=section.text;
    root.append(header,text);
    if(section.title==='QUIZ'){
        state.lastQuiz=section.text;
        const action=document.createElement('button');action.type='button';action.className='quiz-action';action.textContent='↗ Answer the quiz';
        action.addEventListener('click',()=>{$('#user-message').focus();$('#user-message').placeholder='Your answer to the last quiz…';});
        root.append(action);
    }
    return root;
}
function renderTeachingResponse(reply){
    const node=state.bubbleEl?.node;if(!node)return;
    const old=node.querySelector('.ai-stream');if(old)old.remove();
    const parsed=parseSections(reply);
    if(parsed.length<3){
        const fallback=document.createElement('div');fallback.className='ai-stream';fallback.textContent=reply;
        node.append(fallback);
        toast('The local model returned an unstructured lesson. You can ask it to include all seven learning stages.');
    }else parsed.forEach(x=>node.append(card(x)));
    $('#tutor-log').scrollTop=$('#tutor-log').scrollHeight;
}
function setupStatus(label,ready){
    const el=$('#model-presence');el.classList.toggle('offline',!ready);
    el.replaceChildren();const icon=document.createElement('span');icon.textContent=ready?'✓':'○';
    const b=document.createElement('b');b.textContent=label;el.append(icon,b);
    $('#global-dot').classList.toggle('ready',ready);$('#global-status').textContent=ready?'MODEL ONLINE':'MODEL SETUP';
}
function showSetup(installed,ready,installing){
    state.modelReady=!!ready;state.installing=!!installing;
    const pane=$('#model-setup'),title=$('#setup-title'),desc=$('#setup-description'),buttons=$('.setup-buttons');
    if(ready){
        pane.classList.add('installed');title.textContent='MODEL ready · Everything runs on this device';
        desc.textContent='Ask a sentence or start talking. No AI subscription or external inference server.';
        buttons.hidden=true;$('#setup-progress').hidden=true;setupStatus('MODEL ONLINE',true);
    }else{
        pane.classList.remove('installed');buttons.hidden=!!installing;setupStatus(installed?'MODEL LOADING':'MODEL NOT INSTALLED',false);
        title.textContent=installed?'Loading MODEL into device memory…':'Install your private MODEL';
        desc.textContent=installed?'Please wait. Large models may take time to initialize.':'Install once inside the app: about 2.4 GB plus ~3 GB free storage.';
    }
}
function refreshProgress(){
    $('#xp-text').textContent=`${state.xp} XP`;
    $('#lesson-stats').textContent=`${state.turnCount} LESSONS · ${state.streak} DAY STREAK`;
    $('#xp-bar').style.width=`${state.xp%100}%`;
}
function awardLearningXP(){
    const today=dayStamp();
    if(state.lastStudy!==today){
        if(state.lastStudy){
            const yesterday=new Date(Date.now()-86_400_000).toISOString().slice(0,10);
            state.streak=state.lastStudy===yesterday?state.streak+1:1;
        }else state.streak=1;
        state.lastStudy=today;
    }
    state.xp+=25;state.turnCount++;
    save('veltrix_xp',state.xp);save('veltrix_streak',state.streak);
    save('veltrix_lastStudy',state.lastStudy);save('veltrix_turnCount',state.turnCount);
    refreshProgress();
}
function voiceSummary(reply){
    const p=parseSections(reply);const part=name=>p.find(s=>s.title===name)?.text||'';
    return (`Correction. ${part('CORRECTION')} Advanced version. ${part('UPGRADE')} Your quiz. ${part('QUIZ')}`).slice(0,1500);
}
function sendPrompt(text){
    const message=String(text||'').trim();if(!message)return;
    if(!state.modelReady){toast('Install and load MODEL first. The app cannot invent AI answers.');return;}
    if(state.generating){toast('Please wait for the previous lesson or tap Stop.');return;}
    state.currentPrompt=message;state.generating=true;state.replyText='';state.streamEl=null;state.bubbleEl=null;
    pushMessage('user',message);$('#user-message').value='';$('#user-message').style.height='auto';
    $('#send-button').disabled=true;
    setRobot('thinking');
    try{android.ask(message,state.level,state.goal);}catch(err){state.generating=false;toast('Android inference bridge unavailable.');}
}
window.Veltrix={onNative(message){
    const e=typeof message==='string'?JSON.parse(message):message;
    switch(e.type){
        case 'status': showSetup(e.installed,e.ready,e.installing);break;
        case 'model_progress':{
            state.installing=true;
            $('#setup-title').textContent=e.message||'Preparing model…';
            const p=$('#setup-progress');p.hidden=false;
            const v=Number(e.percent)||0;$('#setup-progress-bar').style.width=`${Math.max(1,v)}%`;
            if(e.downloadedGb!==undefined)$('#setup-description').textContent=`${e.downloadedGb} GB received · Do not close the app during model installation.`;
            $('.setup-buttons').hidden=true;break;
        }
        case 'model_ready':showSetup(true,true,false);setRobot('happy');toast('Model installed. Speak your first sentence!');break;
        case 'generation_start':{
            if(!state.bubbleEl){state.bubbleEl=pushMessage('assistant','Thinking…');state.streamEl=state.bubbleEl.content;}
            setRobot('thinking');break;
        }
        case 'generation_chunk':{
            if(!state.bubbleEl){state.bubbleEl=pushMessage('assistant','');state.streamEl=state.bubbleEl.content;}
            state.replyText=e.text||'';state.streamEl.textContent=state.replyText;
            $('#tutor-log').scrollTop=$('#tutor-log').scrollHeight;break;
        }
        case 'generation_done':{
            state.generating=false;$('#send-button').disabled=false;
            state.replyText=e.text||state.replyText;
            renderTeachingResponse(state.replyText);
            awardLearningXP();setRobot('happy');
            if(state.speaking&&android)android.speak(voiceSummary(state.replyText));
            break;
        }
        case 'generation_cancelled':state.generating=false;$('#send-button').disabled=false;setRobot('idle');break;
        case 'transcription':{
            state.listening=false;$('#record-button').classList.remove('recording');
            $('#user-message').value=e.text||'';
            sendPrompt(e.text||'');break;
        }
        case 'speech_partial':$('#user-message').value=e.text||'';break;
        case 'mic_level':break;
        case 'robot':setRobot(e.state||'idle');if(e.state==='listening'){$('#record-button').classList.add('recording');state.listening=true;}break;
        case 'lesson_reset':toast(e.message||'Lesson reset.');break;
        case 'error':{
            toast(e.message||'Unexpected error.');if(state.generating){state.generating=false;$('#send-button').disabled=false;}
            if(state.installing){state.installing=false;$('.setup-buttons').hidden=false;}
            if(state.listening){state.listening=false;$('#record-button').classList.remove('recording');}
            setRobot('error');break;
        }
    }
}};

$('#input-form').addEventListener('submit',ev=>{ev.preventDefault();sendPrompt($('#user-message').value);});
$('#user-message').addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();sendPrompt(e.target.value);}});
$('#user-message').addEventListener('input',e=>{e.target.style.height='auto';e.target.style.height=Math.min(e.target.scrollHeight,120)+'px';});
$('#learner-level').value=state.level;
$('#learner-level').addEventListener('change',e=>{state.level=e.target.value;save('veltrix_level',state.level);toast(`Exercises adapted to ${state.level}. This is a self-selected practice level, not a certified score.`);});
$('#goal-options').addEventListener('click',e=>{
    const btn=e.target.closest('[data-goal]');if(!btn)return;
    state.goal=btn.dataset.goal;save('veltrix_goal',state.goal);
    $('#goal-options').querySelectorAll('button').forEach(b=>b.classList.toggle('active',b===btn));
});
$('#goal-options').querySelectorAll('button').forEach(b=>b.classList.toggle('active',b.dataset.goal===state.goal));
$('#suggestions').addEventListener('click',e=>{const b=e.target.closest('[data-example]');if(!b)return;$('#user-message').value=b.dataset.example;$('#user-message').focus();});
$('#install-model').addEventListener('click',()=>{if(!android){toast('Model installer only works inside the Android APK.');return;}android.installModel();});
$('#import-model').addEventListener('click',()=>{if(!android){toast('Import is available inside the Android app.');return;}android.importModel();});
$('#record-button').addEventListener('click',()=>{if(!android){toast('Android microphone is available inside the APK.');return;}if(state.generating){toast('Stop the AI reply before speaking again.');return;}android.beginVoice();});
$('#audio-button').addEventListener('click',()=>{
    state.speaking=!state.speaking;
    $('#audio-button span').textContent=state.speaking?'Voice on':'Voice off';
    if(android){android.setSpeaking(state.speaking);if(!state.speaking)android.stopVoice();}
});
$('#stop-button').addEventListener('click',()=>{
    if(android)android.stopAll();else toast('No Android model is running in the browser preview.');
    state.generating=false;state.listening=false;$('#send-button').disabled=false;$('#record-button').classList.remove('recording');setRobot('idle');
});
$('#clear-button').addEventListener('click',()=>{
    if(state.generating){toast('Tap Stop before starting a new lesson.');return;}
    $('#tutor-log').replaceChildren();
    const intro=document.createElement('div');intro.className='intro-empty';
    const title=document.createElement('strong');title.textContent='New practice session.';
    const para=document.createElement('p');para.textContent='Start again. The local model is reloaded to clear its active conversation.';
    intro.append(title,para);$('#tutor-log').append(intro);
    if(android)android.resetLesson();
    state.lastQuiz='';state.bubbleEl=null;state.replyText='';setRobot('idle');
});
refreshProgress();showSetup(false,false,false);
if(android){setTimeout(()=>android.getStatus(),300);}else{
    $('#setup-title').textContent='Android APK required for local intelligence';
    $('#setup-description').textContent='This browser preview shows the exact interface. Real STT, inference and installation run in the APK.';
    setupStatus('APP PREVIEW',false);
}
})();

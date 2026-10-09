"""Headless interface test with a deterministic fake bridge (never claims the actual GGUF ran)."""
from pathlib import Path
from playwright.sync_api import sync_playwright
import json

root = Path(__file__).resolve().parents[1]
assets = root / 'app/src/main/assets'
markup = (assets / 'index.html').read_text()
markup = markup.replace('<link rel="stylesheet" href="legacy-visual.css"/>', '<style>' + (assets / 'legacy-visual.css').read_text() + '</style>')
markup = markup.replace('<link rel="stylesheet" href="tutor.css"/>', '<style>' + (assets / 'tutor.css').read_text() + '</style>')
markup = markup.replace('<script src="curriculum.js"></script>', '<script>' + (assets / 'curriculum.js').read_text() + '</script>')
markup = markup.replace('<script src="tutor.js"></script>', '<script>' + (assets / 'tutor.js').read_text() + '</script>')
bridge_js = r'''
window.__calls = [];
window.AndroidBridge = {
  getStatus(){ setTimeout(() => window.Veltrix.onNative({type:'status', installed:true, ready:true}),15); },
  ask(message,kind,terms,level){
    window.__calls.push({message,kind,terms,level});
    if (window.__failNext) {
      window.__failNext=false;
      setTimeout(()=>window.Veltrix.onNative({type:'generation_done',text:'ANSWER:\nImproved sentence.\nPRACTICE:\nIncomplete practice.'}),25);
      return;
    }
    const list=terms.split('\n').map(v=>v.replace(/^\d+\.\s*/,''));
    let lines=[];
    if(kind==='grammar') {
      lines=[list[0] + ': use this structure accurately in formal English.', 'Use it to connect an idea clearly.', 'Ex: The report provided further context.', 'Ex: The decision was carefully explained.'];
    } else {
      lines=list.map((term,i)=> `${i+1}. ${term} — a short English meaning. Ex: We discussed ${term} during the meeting.`);
    }
    const reply='ANSWER:\nYour sentence, improved.\nPRACTICE:\n'+lines.join('\n')+'\nExercise: Write one original sentence.';
    setTimeout(()=>window.Veltrix.onNative({type:'generation_done',text:reply}),25);
  },
  speak(){},stopAll(){},setSpeaking(){},stopVoice(){},beginVoice(){},installModel(){},importModel(){}
};
'''
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])
    context = browser.new_context(viewport={'width':390,'height':844},device_scale_factor=1)
    context.add_init_script(bridge_js)
    page = context.new_page()
    errors = []
    page.on('pageerror', lambda err: errors.append(str(err)))
    page.goto('about:blank')
    page.evaluate(bridge_js)
    page.evaluate("""Object.defineProperty(window,'localStorage',{configurable:true,value:{_data:{},getItem(k){return this._data[k]??null},setItem(k,v){this._data[k]=v}}});""")
    page.set_content(markup)
    page.wait_for_function("document.getElementById('model-status').textContent === 'MODEL READY'")
    expected = ['word','grammar','collocation','word']
    names=[]
    for i,kind in enumerate(expected):
        if i == 3:
            # Check the stored stage survives reloading the HTML, then reject an incomplete response.
            page.set_content(markup)
            page.wait_for_function("document.getElementById('model-status').textContent === 'MODEL READY'")
            page.evaluate('window.__failNext=true')
            page.locator('#message-input').fill('I make a research yesterday.')
            page.locator('#send-button').click()
            page.wait_for_function('window.__calls.length === 4')
            page.wait_for_function('document.querySelector(".lesson-pair[data-incomplete=true]") !== null')
            rejected=page.evaluate('window.__calls[3]')
            assert rejected['kind']=='word'
            assert len(page.locator('.lesson-pair').all()) == 1
            assert page.locator('.lesson-pair[data-incomplete=true] .practice-lines').text_content().splitlines()[-1].startswith('Exercise:')

        page.locator('#message-input').fill('I make a research yesterday.')
        page.locator('#send-button').click()
        page.wait_for_function('window.__calls.length === ' + str(i+1 if i < 3 else 5))
        page.wait_for_function('document.querySelectorAll(".lesson-pair").length === ' + str(i+1 if i < 3 else 2))
        call=page.evaluate('window.__calls[window.__calls.length-1]')
        assert call['kind']==kind,(kind,call)
        names.append(call['terms'])
        lesson=page.locator('.lesson-pair').last
        assert lesson.locator('.kicker').all_text_contents()==['01  /  ANSWER','02  /  PRACTICE']
        lines=lesson.locator('.practice-lines').text_content().splitlines()
        assert len(lines)<=15,lines
        assert lines[-1].startswith('Exercise:'),lines
        if kind!='grammar':assert len(lines)==11,lines
    assert names[0].splitlines()[0]!=names[3].splitlines()[0], 'Vocabulary must advance to the next 10 items'
    assert rejected['terms']==names[3], 'Incomplete reply must retry the identical next batch'
    assert page.locator('.lesson-pair').count()==2
    assert not errors,errors
    assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth'), 'Viewport overflows on mobile'
    page.screenshot(path=str(root / 'previews/english-three-stage-mobile.png'))
    print('PASS: 4 conversational turns, word→grammar→collocation→next 10 words, English-only Answer/Practice, ≤15 logical lines, mobile layout')
    context.close();browser.close()

"""Developer-only Chromium smoke. Requires Python playwright and installed browser."""
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT = Path(__file__).resolve().parents[1] / 'app/src/main/assets'
html = (ROOT / 'index.html').read_text()
for cssname in ('legacy-visual.css','tutor.css'):
    css = (ROOT / cssname).read_text().replace("@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Manrope:wght@400;500;600;700;800&display=swap');",'')
    html = html.replace(f'<link rel="stylesheet" href="{cssname}" />', f'<style>{css}</style>')
html = html.replace('<script src="tutor.js"></script>', '<script>'+ (ROOT/'tutor.js').read_text() + '</script>')
with sync_playwright() as p:
    b=p.chromium.launch(headless=True, executable_path='/usr/bin/chromium', args=['--no-sandbox','--disable-gpu','--disable-dev-shm-usage'])
    page=b.new_page(viewport={'width':390,'height':844})
    errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.set_content(html,wait_until='domcontentloaded')
    assert page.locator('#demo-companion').count()==1
    assert page.locator('#model-setup').is_visible()
    page.evaluate("""() => window.Veltrix.onNative({type:'status',installed:true,ready:true,engine:true,installing:false})""")
    assert 'MODEL ONLINE' in page.locator('#model-presence').inner_text()
    response='''REVIEW:\nThe student describes the past.\nCORRECTION:\nI went to school yesterday.\nUPGRADE:\nYesterday, I attended school as usual.\nGRAMMAR:\nUse simple past for completed actions. Example: I went.\nVOCABULARY:\n1. attend: شرکت کردن; attend class. Example: I attend class.\n2. yesterday: دیروز. Example: Yesterday I studied.\n3. frequently: اغلب. Example: I frequently practice.\nPRACTICE:\nSay one sentence about yesterday.\nQUIZ:\nWhich is correct: I go yesterday or I went yesterday?'''
    page.evaluate("""(text) => {window.Veltrix.onNative({type:'generation_start',original:'I go to school yesterday'});window.Veltrix.onNative({type:'generation_chunk',text});window.Veltrix.onNative({type:'generation_done',text});}""",response)
    assert page.locator('.lesson-card').count()==7, f"expected 7 lesson cards, got {page.locator('.lesson-card').count()}"
    assert page.locator('.quiz-action').is_visible()
    assert '25 XP' in page.locator('#xp-text').inner_text()
    dims=page.evaluate('({width:document.documentElement.scrollWidth,viewport:window.innerWidth})')
    assert dims['width'] <= dims['viewport']+1, dims
    assert not errors, errors
    print('PASS: mobile robot, in-app model state, 7 adaptive teaching cards, quiz button, XP, responsive overflow, JS errors')
    b.close()

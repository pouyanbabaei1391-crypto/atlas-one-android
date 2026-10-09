"""Independent static checks. Android speech and inference require testing on a real ARM64 device."""
from pathlib import Path
from html.parser import HTMLParser
root=Path(__file__).resolve().parents[1]
html=(root/'app/src/main/assets/index.html').read_text()
css=(root/'app/src/main/assets/tutor.css').read_text()
class Parser(HTMLParser):
    def __init__(self):super().__init__();self.ids=set()
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if 'id' in a:self.ids.add(a['id'])
p=Parser();p.feed(html)
for name in ['demo-companion','conversation','mic-button','message-input','model-setup','pace-alert']:
    assert name in p.ids,name
assert 'max-width:700px' in css
assert '<script src="curriculum.js"></script>' in html
print('PASS: minimal mobile layout DOM, robot and tutor controls present')

"""Create a private visual-review contact sheet from unchanged trace images."""
import argparse
import sqlite3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

p=argparse.ArgumentParser()
p.add_argument('campaign')
p.add_argument('session')
p.add_argument('steps', nargs='+', type=int)
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
runs=root/'artifacts/artemis-campaigns'/a.campaign
if runs.resolve().parent != (root/'artifacts/artemis-campaigns').resolve():
    p.error('Invalid campaign')
db=sqlite3.connect(f'file:{(runs/"traces/data_engine.db").as_posix()}?mode=ro',uri=True)
frames=[]
for step in a.steps:
    row=db.execute('select post_image_name,pre_image_name from steps where session_id=? and step_number=?',(a.session,step)).fetchone()
    if not row or not (row[0] or row[1]):
        p.error(f'Missing step image: {step}')
    frames.append((step,row[0] or row[1]))
w,h=360,800
cols=min(3,len(frames))
sheet=Image.new('RGB',(cols*w,((len(frames)+cols-1)//cols)*(h+30)),'white')
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',16)
for i,(step,name) in enumerate(frames):
    source=Image.open(runs/'traces/images'/f'{name}.jpg').convert('RGB')
    source.thumbnail((w,h))
    x,y=(i%cols)*w,(i//cols)*(h+30)
    draw.text((x+5,y+3),f'Step {step}  {name[:12]}',fill='black',font=font)
    sheet.paste(source,(x,y+30))
target=runs/f'review-{a.session}.jpg'
sheet.save(target,quality=92)
print(target)

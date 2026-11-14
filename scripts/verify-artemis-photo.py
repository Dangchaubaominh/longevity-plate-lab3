"""Verify the real downloaded test photo against the authorized input fixture."""
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

p=argparse.ArgumentParser()
p.add_argument('campaign')
p.add_argument('run', type=int, choices=[1,2,3])
p.add_argument('--date', default='2026-11-14')
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
base=root/'artifacts/artemis-campaigns'/a.campaign
if base.resolve().parent != (root/'artifacts/artemis-campaigns').resolve():
    p.error('Invalid campaign')
records=json.loads((base/f'meals-{a.date}.json').read_text(encoding='utf8'))
label=f'ARTEMIS_AR13_R{a.run}_{a.campaign}_PHOTO'
matches=[r for r in records['tests'] if r['data'].get('description')==label]
if len(matches)!=1:
    p.error(f'Expected one exact meal, got {len(matches)}')
meal=matches[0]
asset=meal.get('photoAsset') or {}
download=meal.get('downloadProof') or {}
if meal['data'].get('type')!='lunch' or asset.get('status')!='ready' or download.get('status')!=200:
    p.error('Meal type, ready asset or private download proof missing')
input_path=base/'input-fixture.jpg'
output_path=base/f'photo-{meal["id"]}.jpg'
original=Image.open(input_path).convert('RGB')
output=Image.open(output_path).convert('RGB')
same_aspect=abs(original.width/original.height-output.width/output.height)<0.01
aligned=output.resize(original.size,Image.Resampling.LANCZOS)
diff=ImageStat.Stat(ImageChops.difference(original,aligned))
rmse=math.sqrt(sum(v*v for v in diff.rms)/3)
def dhash(image):
    pixels=list(image.convert('L').resize((9,8),Image.Resampling.LANCZOS).getdata())
    return [pixels[y*9+x]>pixels[y*9+x+1] for y in range(8) for x in range(8)]
hamming=sum(x!=y for x,y in zip(dhash(original),dhash(output)))
# JPEG re-encoding is expected (app quality82), so compare decoded content.
identity=same_aspect and rmse<=15 and hamming<=8
proof={'case':f'AR13-R{a.run}','label':label,'mealId':meal['id'],'mealVersion':meal['version'],
       'assetId':asset['id'],'assetStatus':asset['status'],'downloadStatus':download['status'],
       'inputSha256':hashlib.sha256(input_path.read_bytes()).hexdigest(),
       'downloadSha256':hashlib.sha256(output_path.read_bytes()).hexdigest(),
       'inputSize':list(original.size),'downloadSize':list(output.size),'rgbRmse':round(rmse,4),
       'dhashDistance':hamming,'thresholds':{'rmseMax':15,'dhashMax':8},'identityMatch':identity,
       'boundary':'Backend/image oracle only; native picker and UI flow need separate trace review.'}
(base/f'AR13-R{a.run}-photo-proof.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf8')
print(json.dumps(proof))
raise SystemExit(0 if identity else 1)

from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib,copy,math
import argparse
parser=argparse.ArgumentParser(description="Rebake eight committed saber poses from the existing painted atlas; offline only.")
parser.add_argument('--output-dir',type=Path,required=True,help='New evidence folder for review PNG and receipt')
args=parser.parse_args()
root=Path(__file__).resolve().parents[2];work=args.output_dir.resolve();work.mkdir(parents=True,exist_ok=False)
assets=root/'assets/sprites/enemies/guard_rendered_r1';meta_path=assets/'guard_rig.json'
raw=meta_path.read_bytes();data=json.loads(raw)
source_metadata_sha=data.get('part2_provenance',{}).get('source_metadata_sha256',hashlib.sha256(raw).hexdigest())
data['clips']=[entry for entry in data['clips'] if entry['id']!='committed_sweep']
clip=next(c for c in data['clips'] if c['id']=='attack_sweep');source_frame=clip['frames'][2]
x,y,w,h=source_frame['rect'];atlas=Image.open(assets/clip['atlas']).convert('RGBA');source=atlas.crop((x,y,x+w,y+h));src=np.asarray(source,dtype=np.float32)/255
src[...,:3]*=src[...,3:4]
wrist_x,wrist_y=source_frame['sword_hand']
def smooth(a,b,v):
 t=np.clip((v-a)/(b-a),0,1);return t*t*(3-2*t)
def deform(px,py,angle,lean):
 # Legs and boot pixels retain the original common root. Upper body turns
 # over the pelvis; the committed arm/weapon follows through independently.
 body=smooth(266,177,py)*(1-smooth(208,225,px))
 dx=(px-168);dy=(py-238)
 bx=(dx*np.cos(lean)-dy*np.sin(lean)-dx)*body
 by=(dx*np.sin(lean)+dy*np.cos(lean)-dy)*body
 arm=smooth(190,225,px)*smooth(155,188,py)
 ax=(px-wrist_x);ay=(py-wrist_y)
 rx=(ax*np.cos(angle)-ay*np.sin(angle)-ax)*arm
 ry=(ax*np.sin(angle)+ay*np.cos(angle)-ay)*arm
 return px+bx+rx,py+by+ry
def sample(sx,sy):
 sx=np.clip(sx,0,w-1);sy=np.clip(sy,0,h-1);x0=sx.astype(int);y0=sy.astype(int);x1=np.minimum(x0+1,w-1);y1=np.minimum(y0+1,h-1);fx=(sx-x0)[...,None];fy=(sy-y0)[...,None]
 pix=(src[y0,x0]*(1-fx)+src[y0,x1]*fx)*(1-fy)+(src[y1,x0]*(1-fx)+src[y1,x1]*fx)*fy
 np.divide(pix[...,:3],pix[...,3:4],out=pix[...,:3],where=pix[...,3:4]>1e-7);pix[pix[...,3]<1e-7,:3]=0
 rgba=np.uint8(np.clip(pix,0,1)*255+.5);rgba[rgba[...,3]<=4]=0
 return Image.fromarray(rgba)
yy,xx=np.mgrid[0:h,0:w].astype(np.float32)
frames=[];outdir=assets/'committed_sweep_source';outdir.mkdir(exist_ok=True)
angles=[-24,-20,-14,-8,-2,3,2,0];leans=[-.06,-.025,.015,.05,.08,.07,.04,0]
for i,(deg,lean) in enumerate(zip(angles,leans)):
 angle=math.radians(deg);sx=xx.copy();sy=yy.copy()
 for _ in range(5):
  ox,oy=deform(sx,sy,angle,lean);sx+=xx-ox;sy+=yy-oy
 image=sample(sx,sy);image.save(outdir/f'active_{i:02d}.png')
 item=copy.deepcopy(source_frame)
 for key in ['foot_front','foot_back','front_boot_contact','back_boot_contact','saber_hand','sword_hand','saber_base','saber_tip']:
  px,py=item[key];qx,qy=deform(float(px),float(py),angle,lean);item[key]=[float(qx),float(qy)]
 item.update({'clip':'committed_sweep','normalized_time':i/7,'index':i,'file':f'committed_sweep_source/active_{i:02d}.png','rect':[i%4*w,i//4*h,w,h],'duration':.18/8,'angle_degrees':deg,'body_lean_radians':lean})
 tip=(np.array(item['saber_tip'])-np.array(data['root_pivot']))*.3
 assert tip[0]>50 and -29<=tip[1]<=-3,(i,tip.tolist())
 assert item['front_boot_contact']==source_frame['front_boot_contact'] and item['back_boot_contact']==source_frame['back_boot_contact']
 frames.append((image,item))
sheet=Image.new('RGBA',(w*4,h*2))
for image,item in frames:sheet.alpha_composite(image,(item['rect'][0],item['rect'][1]))
sheet.save(assets/'committed_sweep_atlas.png')
data['clips'].append({'id':'committed_sweep','count':8,'seconds':.18,'loop':False,'frames':[item for image,item in frames],'atlas':'committed_sweep_atlas.png','atlas_size':[w*4,h*2],'columns':4})
data['status']='runtime_part2_painted_source_followthrough';data['part2_provenance']={'method':'bounded offline articulation/deformation of the existing painted attack_sweep frame2; no image model or new painted views','source_atlas':clip['atlas'],'source_atlas_sha256':hashlib.sha256((assets/clip['atlas']).read_bytes()).hexdigest(),'source_frame':2,'source_metadata_sha256':source_metadata_sha,'root_unchanged':True,'gameplay_window_seconds':.18}
meta_path.write_bytes(json.dumps(data,ensure_ascii=False,indent=2).encode('utf-8'))
review=Image.new('RGB',(w*4,h*2),(48,52,57));draw=ImageDraw.Draw(review)
for image,item in frames:
 at=(item['rect'][0],item['rect'][1]);review.paste(image,at,image);draw.line((at[0],at[1]+292,at[0]+w,at[1]+292),fill=(170,105,70));draw.text((at[0]+6,at[1]+5),f'active {item["index"]} {item["angle_degrees"]}deg',fill='white')
review.save(work/'guard-active-candidate.png')
(work/'GUARD_BAKE.json').write_text(json.dumps({'source':data['part2_provenance'],'frames':[{'index':f['index'],'tip':f['saber_tip'],'hand':f['sword_hand']} for image,f in frames]},indent=2),encoding='utf-8')
print(json.dumps({'atlas':str(assets/'committed_sweep_atlas.png'),'frames':8,'root':data['root_pivot'],'source_provenance':data['part2_provenance']}))

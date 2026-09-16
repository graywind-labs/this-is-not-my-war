from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from lxml import etree as E
import hashlib, json, copy, posixpath
b=Path('D:/这不是我的战争/artifacts/t1704_ppt')
src=b/'output/这不是我的战争_项目介绍_v5_ready.pptx'
sha=hashlib.sha256(src.read_bytes()).hexdigest()
assert sha=='1baea7c2d3c050da40a9eb3e06f43b2590a246ad8c423adf0148b9c55e34b3c9', 'User source changed; inspect latest first'
(b/'build/user_v5_before_ghi.pptx').write_bytes(src.read_bytes())
ns={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main','r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
rn='http://schemas.openxmlformats.org/package/2006/relationships'
with ZipFile(src) as z: original={n:z.read(n) for n in z.namelist()}
out=dict(original)
with ZipFile(b/'build/ghi_additions.pptx') as add:
 for j,(n,indices) in enumerate([(13,[23,24,25]),(15,[7,8,9]),(16,[7,8,9])],1):
  name=f'ppt/slides/slide{n}.xml'; rel=f'ppt/slides/_rels/slide{n}.xml.rels'
  root=E.fromstring(out[name]); tree=root.find('p:cSld/p:spTree',ns); old=list(tree)
  assert any(('G/' if n==13 else 'H/' if n==15 else 'I/') in ''.join(x.itertext()).replace(' ','') for x in old if old.index(x) in indices)
  preserve=[E.tostring(x,method='c14n') for i,x in enumerate(old) if i not in indices]
  for i in reversed(indices): tree.remove(old[i])
  assert preserve==[E.tostring(x,method='c14n') for x in tree]
  rs=E.fromstring(out[rel]); ar=E.fromstring(add.read(f'ppt/slides/_rels/slide{j}.xml.rels'))
  targets={x.get('Id'):x.get('Target') for x in ar}
  ap=E.fromstring(add.read(f'ppt/slides/slide{j}.xml'))
  maxid=max(int(x.get('id')) for x in root.findall('.//p:cNvPr',ns))
  for k,pic in enumerate(ap.findall('.//p:pic',ns)):
   pic=copy.deepcopy(pic); pic.find('p:nvPicPr/p:cNvPr',ns).set('id',str(maxid+k+1))
   blip=pic.find('.//a:blip',ns); rid=f'rIdT1704GHI{k}'; target=targets[blip.get('{'+ns['r']+'}embed')]
   apath=posixpath.normpath(posixpath.join('ppt/slides',target)).lstrip('/')
   media=f'ppt/media/t1704_ghi_{n}_{k}.png';out[media]=add.read(apath)
   blip.set('{'+ns['r']+'}embed',rid)
   E.SubElement(rs,'{'+rn+'}Relationship',Id=rid,Type=ns['r']+'/image',Target='../media/'+media.split('/')[-1])
   tree.insert(indices[0]+k,pic)
  out[name]=E.tostring(root,xml_declaration=True,encoding='UTF-8',standalone=True)
  out[rel]=E.tostring(rs,xml_declaration=True,encoding='UTF-8',standalone=True)
changed=[n for n in original if original[n]!=out[n]]
assert len(changed)==6
with ZipFile(b/'build/v6_ghi_candidate.pptx','w',ZIP_DEFLATED) as z:
 for n,v in out.items(): z.writestr(n,v)
(b/'build/v6_ghi_preservation.json').write_text(json.dumps({'source_sha256':sha,'changed_parts':changed,'all_other_parts_byte_identical':True,'nonplaceholder_objects_preserved':True},indent=2),encoding='utf8')
print('Preserved all user edits; replaced only G/H/I placeholders')

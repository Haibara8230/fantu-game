"""Create new editable vector parts in candidate outputs; no raster generation."""
from __future__ import annotations
import json
import xml.etree.ElementTree as ET
from handoff_support import PACK, configure_writes, project_path
from bulk_art import read, rel, sha, save, QUEUE

def svg(body, width=64, height=64):
 return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">\n{body}\n</svg>\n'

def badge(body):
 return '<g id="badge"><circle cx="32" cy="32" r="27" fill="#13292c" stroke="#d9b86c" stroke-width="3"/><circle cx="32" cy="32" r="22.5" fill="none" stroke="#d9b86c" stroke-opacity=".3" stroke-width="1.4"/></g>\n'+body

def outline(body, colour='#d9b86c', width=2.4):
 return f'<g fill="none" stroke="{colour}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round">{body}</g>'

def write_svg(path, data):
 path=project_path(path);path.parent.mkdir(parents=True,exist_ok=True)
 if path.exists() and path.read_text(encoding='utf-8')!=data:raise RuntimeError('Refusing to replace vector '+str(path))
 path.write_text(data,encoding='utf-8',newline='\n');ET.parse(path)
 return {'path':rel(path),'sha256':sha(path)}

def main():
 configure_writes();queue=read(QUEUE)
 states={
 'unknown':outline('<circle cx="32" cy="32" r="9" stroke-dasharray="2 5"/>', '#89988d'),
 'heard':outline('<path d="M22 36 Q17 25 25 20 Q34 14 40 22 Q45 29 36 34 Q31 37 32 42"/><circle cx="32" cy="48" r="1" fill="#d9b86c"/>'),
 'discovered':outline('<path d="M16 32 Q32 14 48 32 Q32 50 16 32 Z"/><circle cx="32" cy="32" r="5" fill="#8cbaa7"/>'),
 'visited':outline('<path d="M20 44 V26 L32 19 L44 26 V44 M17 44 H47 M28 44 V34 Q32 28 36 34 V44"/>'),
 'complete':outline('<circle cx="32" cy="32" r="15"/><path d="M22 32 L29 39 L43 24"/>','#a5c7a0',3),
 }
 city=badge('<g id="city-silhouette" fill="#e9dcb8" stroke="#26392f" stroke-width="1.3" stroke-linejoin="round"><path d="M17 28 H47 V46 H17 Z"/><path d="M14 28 L32 17 L50 28 Z" fill="#9cafa2"/><path d="M21 26 V18 H27 V23 M37 23 V18 H43 V26" fill="#d9b86c"/><path d="M27 46 V36 A5 5 0 0 1 37 36 V46" fill="#13292c"/></g>')
 port=badge('<g id="port-silhouette" stroke="#26392f" stroke-width="1.3" stroke-linejoin="round"><path d="M14 36 H49 L43 44 H21 Z" fill="#b98a55"/><path d="M29 35 V17 L43 31 H29" fill="#e9dcb8"/><path d="M16 33 V20 H22 V33" fill="#9cafa2"/><path d="M13 47 Q19 44 25 47 T37 47 T50 47 M16 52 Q22 49 28 52 T40 52" fill="none" stroke="#8fd3f0" stroke-width="2" stroke-linecap="round"/></g>')
 diary=svg('<rect x="1.5" y="1.5" width="61" height="61" rx="3" fill="#303c32" stroke="#a99a70"/><g id="diary-pages" stroke="#293d35" stroke-width="1.1" stroke-linejoin="round"><path d="M17 12 L45 10 L49 49 L21 53 Z" fill="#e5d6b1"/><path d="M15 10 L43 8 L46 47 L18 50 Z" fill="#6f7e64"/><path d="M18 10 L21 49" fill="none" stroke="#bcb08c"/><path d="M15 17 L20 17 M16 25 L21 25 M17 33 L22 33 M18 41 L23 41" stroke="#e5d6b1"/></g><g id="array-clue" fill="none" stroke="#e5d6b1" stroke-width="1.4" stroke-linecap="round"><path d="M27 29 V23 H38 V29 M30 29 V26 Q32.5 22 35 26 V29 M26 34 Q30 32 34 34 T41 34"/><path d="M38 18 A10 10 0 1 0 42 31"/></g><path id="closing-cord" d="M22 39 L47 36 L49 42" fill="none" stroke="#a99a70" stroke-width="2"/>')
 tag=(project_path('assets/art/ui/tag.svg')).read_text(encoding='utf-8')
 products={
  'wen_zhaoheng_diary.svg':(diary,{}),
  'exploration_states.svg':(svg(badge(states['discovered'])),{'exploration_'+name+'.svg':svg(badge(body)) for name,body in states.items()}),
  'city_port_markers.svg':(svg(city),{'city_marker.svg':svg(city),'sea_port_marker.svg':svg(port)}),
  'retreat_return_summary.svg':(tag,{'retreat_message_blank.svg':tag,'retreat_changed_friend_blank.svg':tag,'retreat_promise_blank.svg':tag}),
 }
 for job in queue['jobs']:
  if job['label'] not in products or job['status']!='vector_pending':continue
  data,parts=products[job['label']];target=project_path(job['output'])
  main_part=write_svg(target,data)
  records=[write_svg(target.parent/'parts'/name,value) for name,value in parts.items()]
  job.update(status='delivered_vector',newly_generated=False,newly_created_vector=True,sha256=main_part['sha256'],native_dimensions=job['spec']['dimensions'],parts=records,
   delivery_kind='editable_svg_parts',review='XML parsed; visual preview pending',
   integration_notes='Blank UI parts: names, dates, messages and status labels remain runtime text. Native editable vector, not an imagegen bitmap.')
  if job['label']=='retreat_return_summary.svg':
   job['delivery_kind']='reuse_blank_tag_with_independent_parts';job['newly_created_vector']=False
   job['integration_notes']='Existing blank tag reused unchanged for independent message parts. Not claimed as newly drawn art.'
  target.with_suffix('.parts.json').write_text(json.dumps({'main':main_part,'parts':records,'technical_source':job['source'],'technical_source_sha256':sha(project_path(job['source']))},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 save(queue);print(json.dumps({'vectors_finished':4,'counts':queue['counts']},ensure_ascii=False))

if __name__=='__main__':main()

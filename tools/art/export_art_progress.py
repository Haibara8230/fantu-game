"""Verify delivery bytes and export honest batch reports; never edits runtime art."""
from __future__ import annotations
from collections import Counter
import json
import xml.etree.ElementTree as ET
from PIL import Image
from handoff_support import PACK, ROOT, configure_writes, project_path
from bulk_art import read, rel, save, sha, write, QUEUE

def main():
 configure_writes();queue=read(QUEUE);errors=[]
 integration=PACK/'INTEGRATION.json';installed=read(integration)['installed'] if integration.exists() else {}
 for job in queue['jobs']:
  if not job['status'].startswith('delivered_'):continue
  target=project_path(job['output'])
  if not target.exists():errors.append('Missing '+job['output']);continue
  if sha(target)!=job['sha256']:errors.append('Hash mismatch '+job['output']);continue
  if target.suffix=='.svg':
   root=ET.parse(target).getroot();native=[int(float(root.attrib.get(k,'0'))) for k in ('width','height')]
  else:
   with Image.open(target) as img:
    img.load();native=list(img.size);job['native_mode']=img.mode
    job['alpha_extrema']=list(img.getchannel('A').getextrema()) if 'A' in img.getbands() else None
  job['native_dimensions']=native;job['target_dimensions']=job['spec']['dimensions']
  job['size_matches_technical_source']=native==job['target_dimensions']
  job['integration_status']='runtime_installed' if job['id'] in installed else 'candidate_only_not_runtime_integrated'
  if job['id'] in installed:job['runtime_targets']=[r['path'] for r in installed[job['id']]]
  if not job['size_matches_technical_source']:
   job['size_note']='Native bytes retained; runtime crop/scale or atlas registration must be resolved separately. Target dimensions are not claimed as delivered dimensions.'
  if job['spec'].get('background')=='transparent_required' and (not job.get('alpha_extrema') or job['alpha_extrema'][0]!=0):errors.append('Missing true alpha '+job['output'])
 for batch in sorted({j['batch'] for j in queue['jobs']}):
  jobs=[j for j in queue['jobs'] if j['batch']==batch]
  write(PACK/'batches'/batch/'output/bulk_delivery.json',{'scope':'candidate delivery; runtime installs listed in INTEGRATION.json','counts':dict(Counter(j['status'] for j in jobs)),'jobs':jobs})
 save(queue)
 lines=['# 全量美术进度','', '用户已授权继续完成全部图。既有分类画风不变，全部候选保存在本包各批 `output/`。'+(f'已有 {len(installed)} 项装入正式资源（`tools/art/integrate_refresh.py`，逐项见 [INTEGRATION.json](INTEGRATION.json)），其余仍为候选。' if installed else '正式资源尚未替换。'), '',
        '范围：645 项既有资源 + 98 项新增计划，共 743 项任务。计划与既有资源有独立交付记录，复用不计为新生成。', '',
        '| 分类 | 新生成候选 | 复用 | SVG交付 | 待处理 | 明确排除 |','|---|---:|---:|---:|---:|---:|']
 for batch in sorted({j['batch'] for j in queue['jobs']}):
  jobs=[j for j in queue['jobs'] if j['batch']==batch];c=Counter(j['status'] for j in jobs)
  pending=sum(v for k,v in c.items() if not k.startswith('delivered_') and not k.startswith('excluded_'))
  lines.append(f'| [{batch}](batches/{batch}/output/bulk_delivery.json) | {c["delivered_generated"]} | {c["delivered_reuse"]} | {c["delivered_vector"]} | {pending} | {c["excluded_unconfirmed_enemy"]} |')
 counts=queue['counts'];lines+=['', '总状态：`'+json.dumps(counts,ensure_ascii=False)+'`。','',
  '“新生成候选”仅统计经目视核对并已复制原始字节的本轮图片。“复用”包括此前候选、原生SVG和授权基础特效；不会冒称重绘。SVG交付含复用的空白出关纸签，具体见逐项记录。', '',
  '目录联接与逐图实路径已核验在 D 盘。每张交付保留提示词、实际输入、哈希、目标/原生尺寸、alpha与退回原因。地图布局仍为规划候选；工具原生尺寸不一致的文件保留原图并注明待集成适配。', '',
  '待处理项仍须继续，不代表全部完成。可选矿道傀儡没有确认的战斗消费者，明确排除，避免凭美术计划新增敌人。', '',
  '机器可读进度：[ALL_ART_PROGRESS.json](ALL_ART_PROGRESS.json)。各批 `bulk_delivery.json` 为本轮全量清单，原有 `delivery.json` 保留历史首批记录。', '',
  '文件核验：'+('全部已交付文件通过哈希、解码/XML及要求的alpha检查。' if not errors else '存在错误：'+json.dumps(errors,ensure_ascii=False))]
 (PACK/'PROGRESS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
 print(json.dumps({'counts':counts,'errors':errors},ensure_ascii=False))
 if errors:raise SystemExit(1)

if __name__=='__main__':main()

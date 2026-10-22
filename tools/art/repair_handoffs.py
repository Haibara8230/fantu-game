"""Refresh packaged handoffs without generating images or touching runtime assets.

Run from the project root: python -B tools/art/repair_handoffs.py
All manifest/CSV paths are relative to the project root; Markdown links are
relative to their document. Historical scratch paths are explicitly labelled.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json

from handoff_support import PACK, ROOT, actor_sources, configure_writes, markdown_paths, normalize, project_path
from prepare_handoffs import PLANNED
from production_specs import decorate_briefs, manifest as production_manifest, full_scope

DISK_RULE = ('10. 全部项目输出、缓存、备份和日志只写当前 D 盘项目根目录，临时文件放 `.tmp/`。'
             'Python 使用 `-B`，TEMP／TMP 指向项目 `.tmp/`。不得写 C 盘。'
             '用户已授权将内置生图目录通过NTFS联接重定向到项目 `.tmp/imagegen_storage/generated_images/`；'
             '每次生图前用 `tools/art/redirect_imagegen.ps1 -VerifyOnly` 核验真实目标和写入探针。'
             '联接失效、目标不在D盘或工具另写未核验目录时停止，不用事后搬迁代替，不擅自切换API／CLI。'
             '此联接仅迁移图片负载目录，未迁移Codex应用设置与日志。')
SYNC = {
    '01_human_actions': '宗门男女动态图集的 `source_role: look` 来自 battle_stage.gd 的宗门／性别选图；保持3列2行、idle／prepare／attack／cast／hit／guard和朝右。晏无咎等剧情角色不自动新增敌人动作。',
    '02_key_portraits': '温照衡是拍卖老修士的定稿身份；初期头像、元婴后期状态与旧画像保持同一人。陆承舟接家业、柳寒舟北岳旧案在筑基篇先做；叶知微与闻人照的中期经历在五城阶段。晏无咎先交身份候选，服饰标识未定；不因数十年过去就统一换老脸。',
    '03_portrait_pool': '按大纲7.4，先从现有246张池中选两位完整交往样本；本批仍是原八个子批，不额外扩池，不用图像自动新增人物规则或替代关键人物专属脸。',
    '04_beast_actions': '妖蟒保留药路与灵泉的地方成因，不统一加照川城符号。矿道傀儡等新增敌人必须等实际战斗内容、身份和帧数确定，未确定时列待办，不为计划文件强行新增战斗。',
    '05_locations': '五城各有客栈；布局需为静房入口留出位置。天南大比五城轮办，场地由第06／07／09批协作，避免将青云小宗扩大成全国大会固定主场。',
    '06_scenes': 'P0优先青石镇静房与白鹭渡天河渡口月圆映城；五城静房随城市交付。筑基篇先北岳旧档库、五处探索、试剑崖、历练帖与天南大比；五城阶段补五宗论道；古境房间和封存空间未定时保留待办。',
    '07_battle_backgrounds': '炼气潜龙会、筑基天南大比、金丹以上五宗论道分别与各自会场保持空间关系；天南大比五城轮办优先复用场地结构与城市陈设，不烘焙角色、胜者、年号或排名。',
    '08_maps': '以新大纲3.1的未知／已听闻／已发现／已到访／已探索完毕五种状态留出UI空间。筑基五处探索与试剑崖、历练帖入口只按实际内容接入，先交规划。',
    '09_events': '按开局、炼气、筑基、五城、金丹、元婴飞升六段交付。补陆家丧事、北岳证人、五宗论道、叶知微禁方与闻人照失联；温照衡口述／遗物两版接续。照川城真相与三条通路分阶段表现，不用早期插画提前泄密。',
    '10_item_skill_icons': '作品机制以新大纲6.3为准：《照水分光诀》为水金神通连击与善水印转化；听潮剑为水脉附近开局吸灵气；《藏息录》为遁速、撤离和野外避险。候选城徽的三拱门／双水纹／缺口圆环仍非已批准设计。',
    '11_ui_rites': 'P0打坐服务客栈静房的首次闭关与领悟；后续复用到各闭关处。五种舆图状态、出关消息、突破基本条件／可选筹划、六格神通栏由现有UI承载，数字、文字和格数不烘焙进图。',
    '12_vfx': '筑基篇先审查藏息的遁速／撤离表现；五城阶段补照水的水金连击、印转化及听潮剑水脉吸灵气。延用原画法与CC0复用规则，不沿用蓄势／反击机制，不以特效新增规则。',
}

SCOPE = {
    '01_human_actions': [
        '先检查主角六姿态候选；逐格验头发、剑尖、鞋底和帧区域，保持现有身份与布局。',
        '开局为16岁无名散修，服装／道具不提前宣告拜入青云；需要适配时说明内容差异，既有主角画法与身份参考不变。',
        '宗门男女修士、散修、对手和赤霄执法按实际消费者审查再处理；停用图集单列，不为覆盖清单重复重绘。',
        '同辈与晏无咎只有确定实际斗法用途后才新增全身动作，不自动把剧情人物做成敌人。'],
    '02_key_portraits': [
        '先复核陆承舟、叶知微、闻人照、柳寒舟健康与温照衡（auction_elder）候选；阿芷和沈墨沿用既有身份参考。',
        '柳寒舟受伤与健康是同一人，受伤图保留；温照衡旧画像由同一身份推导，不另造脸。',
        '筑基篇先陆承舟接掌家业、柳寒舟北岳旧案及晏无咎身份；五城阶段再补叶知微、闻人照中期状态。',
        '人物事件按日历和其自身修为，不统一按玩家升级换老脸，不预设全员死亡、黑化或固定结局。',
        '顾长庚、许清和属于拜师后的青云人物；两张 assets/local/portraits 根目录定制头像仍归本批。'],
    '03_portrait_pool': [
        '本目录为总说明，实际仍分八个互不重叠子批，保持246张原图身份、性别、年龄与职业。',
        '每张独立生成和验收，既定构图与底色不变，不用多人联系表代替独立交付。',
        '炼气篇先从既有池中选两位有完整来往的普通修士样本；候选使用不改变全池任务范围，不自行追加新角色或扩池。',
        '原命名与路径稳定；关键人物成长和晏无咎身份由第02批处理，不借普通池代替。'],
    '04_beast_actions': [
        '岩甲蜥单姿态样张继续作画法参考，不能覆盖四姿态图集；帧顺序和区域按 inputs.json 的实际定义。',
        '蛇、鸟、熊和蜥蜴保留各自解剖、重心和身份；药路妖蟒与地方灵泉有关，不添加无依据的旧城符号。',
        '古境、矿道新增敌人先确定战斗用途、身份与帧数；矿道傀儡计划不代表大纲已要求新增此敌人。'],
    '05_locations': [
        '青云小宗与云溪全城先复核已有候选；日常山门、城区、旧坊市是不同用途。',
        '筑基篇交南明与北岳旧档库所在城区；五城阶段补沧澜、望海及北岳其余部分，不一次性定稿全部城市。',
        '城池内容体现供给、行业与生活；五城各有客栈，城市与同名宗门分别处理。',
        '白鹭渡为内河枢纽，天河渡口是其主线场景；望海另承担外海港口。首版不增加中州、北荒或天衍空地点。',
        '按输入保留不同横图的尺寸和用途；城市相邻关系未定时先规划，不擅自定稿路线。'],
    '06_scenes': [
        '青石客栈公共厅先复用 town_inn.png 与既有样张；P0补静房、赴云溪入口、集会、拍卖楼、陆府与白鹭渡天河渡口月圆城影。',
        '五城静房随城市上线，共用基础并变陈设；宗门静室、租洞府、自有洞府与灵眼保持用途差异。',
        '日常青云山门候选与原魔潮状态分别交付；拜师介绍移到入宗后，不直接覆盖现有消费者。',
        '筑基五处探索先审查已有洞府、灵泉、熔窟图，再补缺图；北岳旧档库、试剑崖、历练帖和天南大比属于P1。',
        '五宗论道与五城中期内景属于P2；古境、船上、岛屿、水下、照川城按后续阶段和已定空间关系制作。',
        '药路、矿区与故地再访优先交陈设或状态变化；场景无文字、按钮和默认角色，不给每个分支画整幅全景。'],
    '07_battle_backgrounds': [
        '先审查现有场地身份与尺寸；开局潜龙会镜头对应第09批已有候选，不烘焙角色或胜利结果。',
        'P1交筑基天南大比，P2补金丹以上五宗论道；与第06批会场保持空间关系，五城轮办优先用陈设变化。',
        '双方约四分之一、四分之三横向位置继续留站位与技能空间；场地内不烘焙法术或地面角色投影。',
        '矿洞、古境、海岛与水下场地随实际战斗内容补齐；没有战斗消费者的场景不自动新增竞技版本。'],
    '08_maps': [
        '整体规划服务首版天南五城五宗、青云起步区、野外、内河至望海近海；城市邻接与路程未定时不强行定稿。',
        '当前正式底图遵循实际消费者坐标，新布局另交候选；不先改数据把空节点冒充可玩地点。',
        '白鹭渡及其天河渡口保持内河身份，望海承担海港；中州、北荒、远海与天衍上宗不画首版假开放节点。',
        '地名、路线、迷雾和未知／已听闻／已发现／已到访／已探索完毕五种状态由独立UI表达。',
        '近海、沉霞内部、照川城封存空间地图按对应阶段交；房间和阵枢结构先由内容确定。'],
    '09_events': [
        '现有32幅含天赋与旧剧情图先按用途审查；外门小比不继续承担公共潜龙会，固定天河窗口不继续承担新结局。',
        'P0交集会、首次拍卖残镜异象、潜龙会与陆府夜宴；参赛／观战、拍下／未拍下、拜师／不拜师均可成立。',
        'P1交同辈日常、天南大比重逢、陆家接续、北岳证人与守川司交涉；P2交禁方、海图失联、五宗论道及古境实证。',
        '温照衡口述与遗物日记各有接续版本；失联不等于死亡。剧情图出场身份先读取第02批候选，未定人物先待办。',
        '照川城按线索揭示阶段呈现，候选城徽与第10批保持一致，不在早期图提前泄露真相或画时间旅行。',
        '三条通路表现不同空间结果；公开真相与阵枢处理独立，不用一张金色云桥代表全部结局。'],
    '10_item_skill_icons': [
        '现有SVG修改和9个候选先审查，不重复覆盖；保留现有生成器与分层组合，新增题材不等于新增可玩物品。',
        '背板、主体、品级框继续分开，带框样张不重复套框；铜片、残镜、档案与阵图共用候选城徽母题。',
        'P1重点藏息与听潮剑线索，P2完整追求照水分光诀、听潮剑修复、海图与温照衡遗物；开局演示可复用已有候选。',
        '照水为水金连击与善水印，听潮为水脉吸灵气，藏息为遁速与撤离；不按旧机制或仅换颜色交付。',
        '筑基丹之外不追加必需突破丹；仅本批提出 make_item_icons.py 与 make_story_icons.py 的补丁，交本批 output/。'],
    '11_ui_rites': [
        '浅纸卷轴与深色兼容版继续按现有文字主题使用，保留对比度规则；33个UI矢量先审查复用。',
        'P0打坐服务静房首次闭关与领悟，后续各闭关处复用；丹炉、灵田与人物引用原有各自参考。',
        '筹划的基本条件、可选提升、风险和结果分开；出关消息与故人变化优先复用卷轴，数字和文字由程序绘制。',
        '五种地图状态、灵气／印／连击与六格神通栏沿用原UI体系；部件不写死格数、年号或规则。',
        'assets/icon.svg 仍归本批；仅本批提出 make_ui_art.py 补丁，交本批 output/。'],
    '12_vfx': [
        '37张CC0基础特效先审查用途、配色、许可证与消费者，能沿用的形状继续复用。',
        'tribulation.png 保留多帧结构与透明度；飞升通路内容变化不自动改变雷劫规则。',
        '筑基篇先审查藏息的撤离表现，五城阶段补照水水金连击／印转化与听潮水脉吸灵气；帧数、时长随实际消费者确认。',
        '新表现引用第10批器物和功法设计，不把藏息画成永久隐身，不新增蓄势／反击或免风险规则。'],
}

OUTLINE_SECTIONS = {
    '01_human_actions': ['2', '4', '7'], '02_key_portraits': ['4', '7', '8.1', '11'],
    '03_portrait_pool': ['7.4'], '04_beast_actions': ['3.4', '9.1', '10'],
    '05_locations': ['3', '12', '16'], '06_scenes': ['3', '4', '5.2', '8', '9', '10', '13'],
    '07_battle_backgrounds': ['4.5', '9', '11'], '08_maps': ['3', '8', '9.1', '18'],
    '09_events': ['4', '7', '8', '9', '10', '11'], '10_item_skill_icons': ['6.2', '6.3', '8'],
    '11_ui_rites': ['2', '3.1', '5.2', '6.1', '6.2'], '12_vfx': ['2', '6.3', '8.3'],
}


def planned_briefs(batch):
    return decorate_briefs([{'priority': priority, 'filename': filename, 'brief': brief,
             'status': 'needs_content_confirmation' if filename == 'mine_guardian_puppet_atlas.png' else 'planned_or_existing_candidate',
             'output_path': f'art_sources/refresh_20261019/batches/{batch}/output/{filename}',
             'content_outline': 'docs/GAME_OUTLINE.md', 'outline_sections': OUTLINE_SECTIONS[batch],
             'content_plan': 'art_sources/refresh_20261019/CONTENT_PLAN.md',
             'style_reference': f'art_sources/refresh_20261019/batches/{batch}/references.json'}
            for priority, filename, brief in PLANNED[batch]], batch)


def update_content():
    """Update instructions only; preserve style sections, references and images."""
    configure_writes()
    common_path = PACK / 'COMMON_RULES.md'
    common = common_path.read_text(encoding='utf-8')
    write_text(common_path, '\n'.join(DISK_RULE if line.startswith('10. ') else line for line in common.splitlines()) + '\n')
    all_briefs = {}
    for batch, scope in SCOPE.items():
        folder = PACK / 'batches' / batch
        task = folder / 'TASK.md'
        value = task.read_text(encoding='utf-8')
        value = value.replace('本文件是交接说明；当前对话已按用户要求停止生成，后续由用户在新对话授权执行。',
                              '本文件是分类交接说明；当前首批与暂缓项以 PRODUCTION_MANIFEST.json 为准，所有素材只交候选，不自动替换正式资源。')
        before, rest = value.split('## 制作范围与顺序\n', 1)
        _, after = rest.split('## 输入与输出', 1)
        before = before.replace('[美术影响评审](../../../../docs/ART_IMPACT_WORLD_REWRITE_20261019.md)',
                                '[美术影响评审](../../../../docs/ART_IMPACT_WORLD_REWRITE_20261019.md)\n'
                                '[新大纲制作范围](../../CONTENT_PLAN.md)') if '[新大纲制作范围]' not in before else before
        value = before + '## 制作范围与顺序\n\n' + '\n'.join(f'{i}. {line}' for i, line in enumerate(scope, 1)) + '\n\n## 输入与输出' + after
        if '## 新大纲同步' in value:
            value = value.split('## 新大纲同步', 1)[0].rstrip() + '\n\n'
        value += '## 新大纲同步\n\n' + SYNC[batch] + '\n'
        write_text(task, value)
        all_briefs[batch] = planned_briefs(batch)
        write_json(folder / 'new_asset_briefs.json', all_briefs[batch])
        write_text(folder / 'START_PROMPT.txt',
                   f'从当前项目根目录执行，以下路径均相对于项目根目录。\n请按 art_sources/refresh_20261019/batches/{batch}/TASK.md 执行本批。'
                   '内容以 docs/GAME_OUTLINE.md 和 art_sources/refresh_20261019/CONTENT_PLAN.md 为准，按可玩片段及本批优先级处理。'
                   '各类图风格、既定画法和验收要求保持不变：严格沿用 STYLE_GUIDE.md、本批“本批画法”、references.json及已确认样张；C版只适用于人物。'
                   '先读通用规则、inputs.json与new_asset_briefs.json，查看实际原图和已有候选；仅在本批output/交付，不改正式资源、玩法、存档或别批文件。'
                   '规格继承technical_spec的旧图，引用按PRODUCTION_MANIFEST.json核验路径、哈希与角色；仅先处理P0首批，P1—P3暂缓。'
                   '遵守不写C盘与后台验证要求；先核验生图目录联接确实写D盘，核验失败时停止，不切换API／CLI。\n')
    for folder in sorted((PACK / 'batches/03_portrait_pool').iterdir()):
        if not folder.is_dir() or not (folder / 'inputs.json').exists():
            continue
        task = folder / 'TASK.md'
        value = task.read_text(encoding='utf-8')
        if '## 新大纲内容范围' in value:
            value = value.split('## 新大纲内容范围', 1)[0].rstrip() + '\n'
        value += ('\n## 新大纲内容范围\n\n按 [新大纲制作范围](../../../CONTENT_PLAN.md) 与上级任务执行。'
                  '原有C版、构图、底色、年龄性别职业与逐张验收要求不变；炼气篇两位普通修士样本从既有池中选择，不自行扩池或生成关键人物替代脸。\n')
        write_text(task, value)
        count = len(read_json(folder / 'inputs.json'))
        write_text(folder / 'START_PROMPT.txt',
                   f'从当前项目根目录执行，以下路径均相对于项目根目录。\n请按 {task.relative_to(ROOT).as_posix()} 执行本子批{count}张头像。'
                   '先读上级TASK.md、COMMON_RULES.md、CONTENT_PLAN.md与上级references.json；只处理本子批inputs.json。'
                   '新大纲只更新人物用途，原人物C版、参考样张、构图、底色和验收要求保持不变。'
                   '头像规格继承每张inputs.json旧图；引用按PRODUCTION_MANIFEST.json核验。本轮头像批暂缓。'
                   '只交本子批output/，不扩池、不替换正式资源；遵守不写C盘，生图前核验目录联接。\n')
    index = read_json(PACK / 'batch_index.json')
    index.update(content_plan='art_sources/refresh_20261019/CONTENT_PLAN.md', style_policy='inherit_existing_batch_references')
    write_json(PACK / 'batch_index.json', index)
    write_json(PACK / 'PRODUCTION_MANIFEST.json', production_manifest(all_briefs))
    readme_path = PACK / 'README.md'
    readme = readme_path.read_text(encoding='utf-8')
    readme = readme.replace('**状态：按用户要求停止图片生成。用户将自行开启多个对话，分别执行下列批次。**',
                            '**状态：已核验D盘生图目录并完成开局首批场景候选；其他批次按计划分阶段处理，P1—P3暂缓。**')
    readme = readme.replace('本次只修文档与清单；内置生图缓存不能确认不写C盘，故未启动图片生成。',
                            '目录核验、首批生图交付及后期暂缓的当前状态见上方“当前生图执行状态”；历史归档与本轮output分别记录。')
    write_text(readme_path, readme)
    print('CONTENT_UPDATED: 12 batches and 8 portrait subbatches; existing drawing styles preserved')


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write_text(path, value):
    if full_scope():
        substitutions = {
            '仅先处理P0首批，P1—P3暂缓。': '用户已追加授权做完全部图，按P0—P3及依赖继续；逐图状态见ALL_ART_PROGRESS.json。',
            '本轮头像批暂缓。': '本轮头像全池纳入逐张制作与验收，保持原有246张范围。',
            '当前首批与暂缓项以 PRODUCTION_MANIFEST.json 为准': '当前全量范围以 production_scope.json 与 ALL_ART_PROGRESS.json 为准',
            '**状态：已核验D盘生图目录并完成开局首批场景候选；其他批次按计划分阶段处理，P1—P3暂缓。**': '**状态：用户已授权继续做完全部图，按既定分类画风生产候选；实时完成数见 [全量进度](PROGRESS.md)。**',
            '目录核验、首批生图交付及后期暂缓的当前状态': '目录核验和全量生图交付的当前状态',
        }
        for old, new in substitutions.items():
            value = value.replace(old, new)
    path = project_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = path.read_bytes() if path.exists() else b''
    previous = raw.decode('utf-8-sig').replace('\r\n', '\n') if raw else None
    if previous != value or b'\r\n' in raw:
        path.write_text(value, encoding='utf-8', newline='\n')


def write_json(path, value):
    write_text(path, json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def repair():
    configure_writes()
    layouts = actor_sources(read_json(ROOT / 'data/art.json'))
    for path in sorted(PACK.rglob('*')):
        if 'output' in path.relative_to(PACK).parts:
            continue  # Delivered images, prompts and provenance are immutable inputs.
        if path.suffix == '.json':
            value = normalize(read_json(path))
            if path.name == 'inputs.json':
                for item in value:
                    item.pop('absolute_path', None)
                    item['actor_layouts'] = layouts.get(item['path'], [])
            if path.name == 'references.json' or path == PACK / 'approved_samples/index.json':
                for sample in value:
                    sample['new'] = sample['packaged_new']
                    history = sample.get('historical_paths', {})
                    for key in ('old', 'referenceOutput', 'comparison', 'promptPath'):
                        if key in sample and not (ROOT / sample[key]).is_file():
                            history[key] = sample.pop(key)
                    if history:
                        sample['historical_paths'] = history
                        sample['historical_note'] = '历史临时材料，不是当前生图输入；使用 packaged_new 与 ref。'
            if path.name == 'new_asset_briefs.json':
                value = planned_briefs(path.parent.name)
            if path.name == 'reference_sources.json':
                for record in value:
                    record.setdefault('collection_status', record['status'])
                    image = project_path(record['file'])
                    valid = image.is_file() and hashlib.sha256(image.read_bytes()).hexdigest().lower() == record['sha256'].lower()
                    record['status'] = 'verified_local' if valid else 'missing_local'
            if path.name == 'batch_index.json':
                value['path_base'] = 'project_root'
                value['content_outline'] = 'docs/GAME_OUTLINE.md'
            write_json(path, value)
        elif path.suffix == '.csv':
            rows = list(csv.reader(io.StringIO(path.read_text(encoding='utf-8-sig'))))
            buffer = io.StringIO(newline='')
            csv.writer(buffer).writerows([[normalize(cell) for cell in row] for row in rows])
            write_text(path, buffer.getvalue().replace('\r\n', '\n'))
        elif path.suffix in ('.md', '.txt'):
            value = path.read_text(encoding='utf-8-sig')
            if path.suffix == '.md':
                value = markdown_paths(value, path)
            value = normalize(value).replace('WORLD_STORY_REWRITE_20261019.md', 'GAME_OUTLINE.md')
            if path.name == 'START_PROMPT.txt' and not value.startswith('从当前项目根目录'):
                value = '从当前项目根目录执行，以下路径均相对于项目根目录。\n' + value
            if path.name == 'TASK.md':
                value = value.replace('P0开局／基础，P1首段修行，P2中期扩展，P3旧城与结局',
                                      'P0开局／基础，P1炼气至筑基，P2金丹扩展，P3旧城与结局')
                batch = path.parent.name
                if batch in SYNC and '## 新大纲同步' not in value:
                    value = value.rstrip() + '\n\n## 新大纲同步\n\n' + SYNC[batch] + '\n'
            if path.name == 'COMMON_RULES.md':
                value = '\n'.join(DISK_RULE if line.startswith('10. ') else line for line in value.splitlines()) + '\n'
                if '路径约定：' not in value:
                    value += ('\n路径约定：JSON、CSV、启动词中的路径均相对于当前项目根目录；Markdown链接相对于所在文档。'
                              '原作参考缺失时按 [参考恢复说明](REFERENCE_SETUP.md) 处理；历史临时字段不算可用输入。\n')
            if path == PACK / 'README.md':
                value = value.replace('- 真实《觅长生》截图仍在 .tmp/mcs_style_reference_20261019/，原始来源记录在本包 `reference_sources.json`，不复制到正式游戏资源。',
                                      '- 原作参考存入项目忽略目录 `PNG/mcs_style_reference_20261019/originals/`；来源与SHA-256见 `reference_sources.json`，恢复和验证见 [参考恢复说明](REFERENCE_SETUP.md)。')
                value = value.replace('- 原版资源备份位于 .tmp/art_refresh_20261019/baseline/。正式目录的SVG修改已保留，后续批次先审查现状，不盲目回滚或重复生成。',
                                      '- 历史原版备份路径为 `.tmp/art_refresh_20261019/baseline/`，不随Git携带，也不假定当前机器已有。正式SVG修改已保留，集成前另在项目 `.tmp/` 做当前快照，不盲目回滚。')
                if '## 本次交接修正' not in value:
                    value += ('\n## 本次交接修正\n\n内容以 `docs/GAME_OUTLINE.md` 为准；新增需求见各批说明和 `new_asset_briefs.json`，'
                              '不计入645项现有资源。清单路径相对于项目根目录，链接相对于文档。'
                              '使用 `python -B tools/art/repair_handoffs.py` 更新现有包，不依赖旧机器的生成缓存。'
                              '本次只修文档与清单；内置生图缓存不能确认不写C盘，故未启动图片生成。\n')
            write_text(path, value)
    update_content()
    print('HANDOFF_REPAIRED: project-relative paths, current outline, dynamic actor layouts; runtime assets untouched')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--content-only', action='store_true', help='Update content instructions and briefs without rewriting references or inputs')
    args = parser.parse_args()
    update_content() if args.content_only else repair()

"""Classify existing art and completed candidates for user-run parallel chats.

This script only reads, copies and documents existing files. It never calls an
image model, regenerates SVGs, replaces runtime art, or changes gameplay data.
"""
from __future__ import annotations

from collections import Counter
import csv
import hashlib
import json
from pathlib import Path
import shutil
import sys

from PIL import Image
from handoff_support import actor_sources as collect_actor_sources, configure_writes, markdown_paths, normalize, project_path, relative_path

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / 'art_sources/refresh_20261019'
WORK = ROOT / '.tmp/art_refresh_20261019'
BATCHES = PACK / 'batches'


def jsave(path, value):
    path = project_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(normalize(value), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def text(path, value):
    path = project_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    value = markdown_paths(value, path) if path.suffix == '.md' else value
    path.write_text(normalize(value).strip() + '\n', encoding='utf-8')


def link(label, path):
    return f'[{label}]({relative_path(path)})'


DEFS = {
 '01_human_actions': ('主角与人形战斗动作', [1, 2],
    '人物沿用已确认 C 版，保持身份、朝向与六姿态；图集按实际帧区域取样，不用六张相同站姿冒充动作。',
    ['先检查现有主角六姿态候选，逐格检查头发、剑尖、鞋底是否越界。', '重绘其余宗门男女修士、散修、对手和赤霄执法动作。', '同辈只有在确定会进入斗法时才新增全身动作，不擅自把所有剧情人物做成敌人。']),
 '02_key_portraits': ('关键 NPC 与同辈头像', [2],
    '人物沿用 C 版。每人保留原身份、发型、衣色、年龄、道具和辨识轮廓；新增同辈使用现有候选作为暂定身份锚点。',
    ['先复核陆承舟、叶知微、闻人照、柳寒舟健康状态和拍卖老修士候选。', '阿芷已有重绘候选；沈墨有此前确认样张；其余关键人物逐一处理。', '柳寒舟受伤与健康是同一人，受伤图仍需保留；成长、衰老和结局状态按实际剧情分批做，不一律悲剧化。', '两张 assets/local/portraits 根目录定制头像归本批，不归普通头像池。']),
 '03_portrait_pool': ('普通修士头像池', [2],
    '人物沿用 C 版，保留文件名所表达的性别、年龄和职业，简练线条、自然差异，不把所有人画成同一张脸。',
    ['本目录只作总说明，实际任务分成下属八个互不重叠的子批。', '每张头像独立生成并验收，统一构图和底色；不要用一张多人联系表代替独立交付。', '原路径和命名保持稳定；同职业通过道具、发束、衣形区分，避免贵族、药师和散修全部同装。']),
 '04_beast_actions': ('妖兽战斗图集', [3],
    '沿用 03_beast 的妖兽画法：大体块、轮廓清楚、鳞甲成组，少碎纹；保留各兽解剖特征。',
    ['岩甲蜥已有单姿态样张，只是风格锚点，不能直接覆盖四姿态图集。', '每个图集逐格制作待机、攻击、受击、守势，具体顺序与 inputs.json 的 actor_layouts 一致。', '蛇、鸟、熊和蜥蜴保留不同重心、轮廓与肢体结构，避免简单换色。']),
 '05_locations': ('城镇、宗门与地点全景', [4],
    '按官方宗门／城镇参考与地点样张画法：屋顶、墙面、群树和远山归并色块，建筑按功能组织；不套人物 C 版提示词。',
    ['青云小宗全景已有候选，仍需检查规模与可点击建筑分布。', '云溪城已有新增城市候选；旧云溪坊市不能未经内容迁移就直接视为全城。', '南明扩城，并新增沧澜医药城、北岳古物阵法城、望海海贸城。沧澜阁不等于沧澜城，玄岳宗不等于北岳城。', '现有两种地点横图有不同尺寸和用途，按清单逐个处理，不能强行全部改成16:9。']),
 '06_scenes': ('室内与二级探索场景', [7],
    '室内沿用 07_interior：木构家具用暖色大块、清楚轮廓、有序陈设、少木纹；室外支路沿用地点环境画法。',
    ['青石客栈已有确认样张，后续需适配开局和同辈日常。', '正常青云山门已有候选；正式 sect_gate.png 当前用于魔潮状态，不能用日常图直接覆盖。', '补云溪城门、陆府室内／庭院、其他城市代表内景；按章节再做古境房间、矿道分岔、船上、岛屿与水下遗迹。', '野外发现用少量具体线索和状态变化，不为每个隐藏标志单独画一整幅全景。']),
 '07_battle_backgrounds': ('斗法背景', [6],
    '沿用 06_battle 与官方斗法截图：前中后景分层、植物群组、宽阔清楚地面；角色站位和动作不能被背景吞没。',
    ['竹林背景已有样张；其余地点背景按原场地身份重绘。', '双方约四分之一、四分之三横向位置留出人物和技能空间，不在背景烘焙角色、法术或地面投影。', '按实际清单保留不同比例；水下、矿洞、古境等新战斗场地随对应内容补齐。']),
 '08_maps': ('区域与探索舆图', [5],
    '沿用 05_map 与原作地图参考：概括小山形、树群、淡色地块、清楚河流；不同于地点全景，不画电影式巨峰。',
    ['当前两张地图的正式版本保留现有节点坐标与区际出口，读取 data/world.json。', '新五城关系另做规划候选：青云起步区、五城五宗、河运至海域；不把尚未实现的节点伪装成可玩地点。', '白鹭渡保持内河身份；海港属于望海。两张现有区域图是否合并须由内容接入决定。', '地名、路线、探索状态、迷雾和标记由独立图层／界面表达，不烘焙进底图。']),
 '09_events': ('剧情、天赋与结局插画', [13],
    '沿用官方演出参考及 13_event 的图形化语言：云形与山形分层、象征性焦点、大色块和留白；旧飞升题材本身不能照搬。',
    ['现有32幅事件包括天赋图，按清单保留事件身份，不统一画成同一张仙山。', '补集会、拍卖残镜异象、潜龙会、陆府夜宴；潜龙会公共赛场已有背景候选。', '镜中旧城需与第10批候选城徽一致；城徽目前是暂拟设计，不能宣称已最终批准。', '飞升需要不同通路与结局状态；先共享基础构图再制作变化，不再用一张金色云桥宫阙代表全部结局。', '剧情人物出场时先读取第02批身份图，不为同一人重画一张无关的脸。']),
 '10_item_skill_icons': ('物品、功法、法宝与线索图标', [8, 9],
    '沿用物品／技能参考和08、09样张：主体剪影优先、少量材质明暗、小尺寸可读；现有 SVG 保留可编辑性与分层组合。',
    ['正式图标矢量已有一批在本轮修改，先审查现状、逐项状态及生成器，不重复覆盖；另有9个新大纲矢量候选。远程后续新增图标保留原样，另列待处理。', '背板、主体、品级框分开；完整带框样张不能再叠一套框。', '残镜、铜片、档案和阵纹先沿用候选母题：三拱城门、两道水纹、缺口圆环，待内容确认后统一修订。', '代表传承须可辨识，听潮剑保留残损／修复两形态。新增图标不等于已经新增可玩物品。', '仅本批负责 tools/art/make_item_icons.py 和 tools/art/make_story_icons.py 的后续修改；其他批只读。']),
 '11_ui_rites': ('界面、标记与修行生活插画', [10, 11, 12],
    '沿用各自系统参考：卷轴青绿卷边和纸色阅读区，丹炉简洁器型、灵田植物成簇；UI装饰不是人物 C 版。',
    ['浅纸色卷轴已有样张；深色兼容版也已生成。现有文字为浅色，不能未经主题适配就套浅纸底。', '33个正式UI矢量已修改，先审查现状；丹炉、灵田沿用各自样张，保留真实透明通道。', '补主角打坐与突破筹划需要的空白部件，文字、材料槽和风险结果由程序绘制。', '应用图标 assets/icon.svg 归本批；仅本批负责 tools/art/make_ui_art.py 的后续修改。']),
 '12_vfx': ('技能与劫雷特效', [6],
    '使用清楚大形和克制光效，服务技能辨识与场地阅读；不把静态背景画法强加给瞬时特效。',
    ['37张现有特效来自CC0素材，先审查用途和配色，保留许可证；能沿用的基础形状不必强制重画。', 'tribulation.png 为多帧劫雷特效图集，保留其帧结构与透明度。', '新增代表功法特效需和第10批图标及实际机制一致，不能仅因名字自行添加新战斗规则。']),
}


def category(rel, actor_sources):
    if rel == 'assets/icon.svg':
        return '11_ui_rites'
    if rel.startswith('assets/local/portraits/pool/'):
        return '03_portrait_pool'
    if rel.startswith(('assets/art/portraits/', 'assets/local/portraits/')):
        return '02_key_portraits'
    if rel == 'assets/art/actors/hero_meditate.png':
        return '11_ui_rites'
    if rel.startswith('assets/art/actors/') or 'cultivator_atlas_' in rel or rel.endswith('rival_atlas_v2.png'):
        return '01_human_actions'
    if rel.endswith('beasts_atlas_v1.png'):
        return '04_beast_actions'
    if rel.endswith('/battle/chixiao_zhifa.png'):
        return '01_human_actions'
    if rel.startswith('assets/art/vfx/') or rel.endswith('/battle/tribulation.png'):
        return '12_vfx'
    if rel in actor_sources:
        return '04_beast_actions'
    if rel.startswith('assets/art/battle/') or rel.endswith('bamboo_arena_v1.png'):
        return '07_battle_backgrounds'
    if rel.startswith('assets/art/locations/'):
        return '05_locations'
    if rel.startswith('assets/art/scenes/'):
        return '06_scenes'
    if rel.startswith('assets/art/map/'):
        return '08_maps'
    if rel.startswith('assets/art/events/'):
        return '09_events'
    if rel.startswith(('assets/art/icons/', 'assets/art/story/icons/')):
        return '10_item_skill_icons'
    if rel.startswith('assets/art/ui/'):
        return '11_ui_rites'
    raise ValueError('Unassigned resource: ' + rel)


CANDIDATES = {
 'sect_small': ('05_locations', '青云小宗全景', 'candidate'),
 'lu_chengzhou': ('02_key_portraits', '陆承舟初期头像', 'candidate'),
 'ye_zhiwei': ('02_key_portraits', '叶知微初期头像', 'candidate'),
 'wenren_zhao': ('02_key_portraits', '闻人照初期头像', 'candidate'),
 'liu_hanzhou_healthy': ('02_key_portraits', '柳寒舟健康状态', 'candidate'),
 'azhi': ('02_key_portraits', '阿芷简化重绘', 'candidate'),
 'auction_elder': ('02_key_portraits', '拍卖老修士暂拟形象', 'candidate'),
 'hero_atlas': ('01_human_actions', '主角六姿态初版', 'superseded'),
 'hero_atlas_alpha': ('01_human_actions', '主角六姿态修正版，优先检查此版', 'candidate'),
 'yunxi_city': ('05_locations', '云溪城市全景规划', 'candidate'),
 'sect_gate_normal': ('06_scenes', '日常山门，不能直接覆盖魔潮状态', 'candidate'),
 'qianlong_arena': ('09_events', '公共潜龙会背景', 'candidate'),
 'scroll_panel_dark': ('11_ui_rites', '与浅色文字兼容的深色卷轴', 'candidate'),
}

# Planned filenames are delivery names inside each batch output/, not promises
# that matching events, places or items already exist in the playable game.
PLANNED = {
 '01_human_actions': [],
 '02_key_portraits': [
  ('P0', 'lu_chengzhou.png', '陆承舟初期身份；已有候选，先复核，不另造一张脸'),
  ('P0', 'ye_zhiwei.png', '叶知微初期医修身份；已有候选'),
  ('P0', 'wenren_zhao.png', '闻人照初期阵法／远行身份；已有候选'),
  ('P0', 'liu_hanzhou_healthy.png', '柳寒舟健康状态；已有候选，与原 wounded 身份一致'),
  ('P0', 'auction_elder.png', '温照衡初期拍卖老修士身份；已有候选，按元婴后期设定复核，不公开真相式装饰'),
  ('P1', 'yan_wujiu.png', '守川司主事晏无咎，元婴；第7.3节角色，姓名暂拟。先交身份候选，克制威仪，不提前把立场画成纯粹邪恶'),
  ('P1', 'lu_chengzhou_heir.png', '筑基篇：兄长离世后接掌家业，服饰与气质体现责任，保留同一张脸；不预设黑化或必须继任结局'),
  ('P1', 'liu_hanzhou_case.png', '筑基篇北岳证人与旧案状态，沿用健康候选及剑穗身份；先复用，确需经历变化才补图，不机械变老'),
  ('P2', 'ye_zhiwei_physician.png', '叶知微行医重逢状态，禁药分支待剧情定案后另补'),
  ('P2', 'wenren_zhao_navigator.png', '闻人照可靠领航者状态，身份可辨，不默认失联即死亡'),
 ],
 '03_portrait_pool': [],
 '04_beast_actions': [
  ('P2', 'mine_guardian_puppet_atlas.png', '矿道守卫傀儡；先确定实际战斗用途和帧数，再制作动作候选'),
 ],
 '05_locations': [
  ('P0', 'qingyun_small_sect.png', '青云小宗全景；已有候选，复核建筑规模和标签空间'),
  ('P0', 'yunxi_city.png', '云溪全城总览；已有候选，与旧坊市内部街区区分'),
  ('P1', 'nanming_city.png', '南明全城：器街、商会、地火产业及旧坊市，不是赤霄宗改名'),
  ('P2', 'canglan_city.png', '沧澜医药城：丹会、药市、水榭；独立于沧澜阁'),
  ('P1', 'beiyue_city.png', '筑基篇先做北岳旧档库所在城区，五城阶段再补全古物街与阵师会馆；独立于玄岳宗'),
  ('P2', 'wanghai_city.png', '望海海贸城：海港、船坞、海图铺；区分内河白鹭渡'),
 ],
 '06_scenes': [
  ('P0', 'qingshi_inn_quiet_room.png', '青石镇客栈静房：散修首次闭关、领悟与突破教学；简朴蒲团、床榻与案几，和客栈公共厅区分，空背景'),
  ('P0', 'city_inn_quiet_room.png', '五城客栈静房共用基础及城市陈设变体；服务散修闭关与领悟，不画成已有私家洞府'),
  ('P0', 'sect_gate_normal.png', '日常青云山门；已有候选，正式旧图当前为魔潮状态'),
  ('P0', 'yunxi_city_gate.png', '结伴赴云溪的入城背景，门楼人间尺度，无烘焙文字'),
  ('P0', 'yunxi_assembly_street.png', '仙师集会街道：摊位、买卖与请教空间，空背景版'),
  ('P0', 'yunxi_auction_hall.png', '日常拍卖楼内景：台面、席位和普通拍品陈设'),
  ('P0', 'lu_family_courtyard.png', '陆府庭院，世家生活与商路气息，避免皇宫规模'),
  ('P0', 'lu_family_dining_hall.png', '夜宴室内空背景，便于人物和对话层复用'),
  ('P1', 'rogue_rented_abode.png', '散修租住洞府，简洁住处、修炼与生活陈设'),
  ('P1', 'nanming_artisan_street.png', '南明器街与炼器作坊，与现有万宝楼、牙行分工'),
  ('P2', 'canglan_medical_hall.png', '沧澜城丹会／医馆代表内景'),
  ('P1', 'beiyue_old_archive.png', '筑基篇北岳旧档库：缺页卷宗、古物与守川司交涉空间；线索与第10批一致'),
  ('P0', 'tianhe_ferry_reflection.png', '白鹭渡内的天河渡口，开局夜宴后首条线索；复用日常内河岸线，补月圆照川城倒影状态，不另造港口，不提前泄露封印真相'),
  ('P1', 'qingyun_sword_trial_cliff.png', '筑基宗门试炼青云试剑崖：山崖、分层攀登与剑痕；层数文字和交互由UI绘制'),
  ('P1', 'rogue_trial_notice_hall.png', '各城悬赏会与散修历练帖领取处；告示正文与排名留给UI，不烘焙文字'),
  ('P1', 'tiannan_tournament_venue.png', '筑基天南大比会场：斗法台、论道席与易宝会的空间关系；五城轮办用陈设变化，区别炼气潜龙会'),
  ('P2', 'five_sect_forum_venue.png', '金丹以上五宗论道：论道席、交易展示和支持后辈的空间；优先复用公共会场，背景无年号、排名或奖励文字'),
  ('P1', 'ancient_abode_inner_chamber.png', '筑基古修洞府深处：前厅通向受损阵法内室，留出合作与避阵的可读路线'),
  ('P1', 'luoxia_deep_spirit_spring.png', '筑基落霞深谷灵泉：灵眼、异常水流与药路妖蟒线索；不自动加照川城阴谋符号'),
  ('P1', 'duanjian_gorge_outskirts.png', '筑基断剑峡外围：安全商道、御剑近路与商队痕迹，内层另留后续内容'),
  ('P2', 'wanghai_chart_shop.png', '望海海图铺，闻人照远行相关'),
  ('P2', 'chenxia_branching_path.png', '沉霞古境可分岔的内部路径，区别现有入口'),
  ('P2', 'chenxia_array_chamber.png', '沉霞阵室，体现可研究／合作处理的空间'),
  ('P2', 'chenxia_record_room.png', '古境旧城记录所在房间，线索标记与第10批一致'),
  ('P2', 'sea_ship_deck.png', '海船甲板，区分内河小舟'),
  ('P2', 'island_landing.png', '近海岛屿登陆点，清楚可行路线'),
  ('P2', 'underwater_ruin_gate.png', '海底遗址入口，与闻人照海图视觉相连'),
  ('P3', 'sealed_old_city_gate.png', '元婴进入照川城封存空间的城门；城徽沿用候选母题，空间结构随大纲18节定案，不画时间旅行'),
  ('P3', 'sealed_old_city_street.png', '旧城生活遗迹，避免只有宏大宫殿'),
  ('P3', 'old_city_array_core.png', '旧城阵枢，可共享基础场景并留分支状态层'),
 ],
 '07_battle_backgrounds': [
  ('P1', 'tiannan_tournament_arena.png', '筑基天南大比斗法镜头，与第06批会场保持空间关系；五城轮办可换边缘陈设，站位清楚'),
  ('P0', 'public_tournament_stage.png', '开局云溪潜龙会斗法镜头，与第09批全景保持空间关系；参赛与观战共用，不烘焙胜者或角色'),
  ('P2', 'five_sect_forum_arena.png', '五宗论道的高阶斗法镜头；沿用第06批会场布局和既有斗法背景要求，优先复用相容场地'),
  ('P2', 'chenxia_array_arena.png', '古境阵室斗法场，双方站位明确'),
  ('P2', 'sea_island_arena.png', '海岛斗法场，海面与岛屿分层'),
  ('P2', 'underwater_ruin_arena.png', '水下遗迹斗法场，同色系分层但不吞没角色'),
 ],
 '08_maps': [
  ('P0', 'tiannan_five_city_plan.png', '五城五宗及河运／海域整体规划候选；不直接覆盖当前可玩地图'),
  ('P2', 'near_sea_map.png', '近海群岛、航线空间和沉船遗址布局；标签与路线独立'),
  ('P2', 'chenxia_interior_map.png', '古境内部支路／阵室关系；先确定真实房间再画'),
  ('P3', 'zhaochuan_sealed_space_map.png', '照川城封存空间规划；城门、生活遗迹与阵枢的关系待大纲18节定案，先候选，不提前烘焙路线或结局状态'),
 ],
 '09_events': [
  ('P1', 'tiannan_tournament_reunion.png', '筑基天南大比同辈重逢；同一角色沿用第02批身份和成长状态，区别炼气潜龙会'),
  ('P1', 'beiyue_shouchuan_encounter.png', '北岳旧档库守川司回收古物与缺页卷宗的首次正面交涉；晏无咎身份先由第02批确认'),
  ('P1', 'lu_family_succession.png', '约30年陆家丧事与接掌家业的经历；复用陆府空间和同一张脸，后续离家／担责／疏远不固定成单一结局'),
  ('P1', 'beiyue_witness.png', '柳寒舟北岳证人与矛盾卷宗的会面；沿用剑穗身份与旧档空间，证人造型待实际人物内容确认'),
  ('P0', 'yunxi_assembly.png', '仙师集会事件：交易与结识的繁华，人物身份沿用头像候选'),
  ('P0', 'auction_mirror_anomaly.png', '残镜短暂映出地图没有的城，铜片反应；不提前泄露完整真相'),
  ('P0', 'qianlong_arena.png', '公共潜龙会场景；已有空背景候选，区别宗门外门比试'),
  ('P0', 'lu_family_night_banquet.png', '陆府夜宴与同辈相识，人物脸型引用第02批，不擅改身份'),
  ('P1', 'friends_breakthrough_meal.png', '突破后吃饭等轻松同辈日常，可复用陆府／客栈空间'),
  ('P1', 'auction_elder_old_painting.png', '拍卖老修士的旧画像线索，必须是同一身份的历史版本'),
  ('P2', 'ye_zhiwei_master_crisis.png', '叶知微师父寿元将尽、替代救法与禁方抉择；先复用医馆与人物，师父造型随内容确认，不预设必然黑化或死亡'),
  ('P2', 'five_sect_forum.png', '金丹以上五宗论道：斗法、观战论道、交易展示或支持后辈四类参与；与第06批会场一致，不固定夺冠'),
  ('P2', 'chenxia_old_city_record.png', '古境记录证明旧城真实存在的发现演出'),
  ('P2', 'chenxia_shouchuan_evidence.png', '沉霞古境合作探索及与守川司争夺照川城实证；同辈可缺席，交涉或争夺按实际剧情，不强制全员同框'),
  ('P2', 'sea_chart_departure.png', '闻人照筹船与出海，呼应海图、海船和同一人物'),
  ('P2', 'wenren_missing_trace.png', '闻人照出海失联后的船队消息／遗留线索；复用海图与海船，不以遗体或葬礼断言人物已死'),
  ('P2', 'wen_zhaoheng_testimony.png', '约200年前温照衡建立信任后口述封存往事的版本；沿用元婴后期身份，后期真相与初期素材分开'),
  ('P2', 'wen_zhaoheng_legacy.png', '错过温照衡生前口述后的遗物、日记与阵图接续版本；使用同一器物母题，不让错过人物卡死主线'),
  ('P3', 'old_city_revelation.png', '旧城封印与遗民历史揭示，不画成任意时间旅行'),
  ('P3', 'ending_reopen_passage.png', '修复重开：照川城部分恢复、通路重开与后续治理；公开真相另作独立状态'),
  ('P3', 'ending_replace_array.png', '替换旧阵：疏散可救者、部分遗迹永久封闭并另修通路；与重开结局有可见差异'),
  ('P3', 'ending_personal_passage.png', '自寻通路：个人飞升、移交证据与方案、后续责任按交托情况延续；不预设毁城或隐瞒真相'),
 ],
 '10_item_skill_icons': [
  ('P0', 'old_city_seal.svg', '已生成候选：三拱城门、双水纹与缺口圆环，非已批准设定'),
  ('P0', 'mirror_back_fragment.svg', '已生成候选：廉价铜片，有可识别的部分阵纹'),
  ('P0', 'remnant_mirror.svg', '已生成候选：拍卖残镜，与铜片、城徽同一视觉母题'),
  ('P1', 'old_city_record.svg', '已生成候选：旧城档案，重复同一城徽而非无关符号'),
  ('P2', 'zhaoshui_fenguang.svg', '已有候选：《照水分光诀》水剑辨识形，水金连击与善水印转化；开局可作演示／残篇，完整追求属五城阶段'),
  ('P1', 'cangxi_lu.svg', '已生成候选：《藏息录》，隐息主题，区别水剑传承'),
  ('P1', 'tingchao_broken.svg', '已生成候选：听潮剑残损形态，和修复版保持同一器型'),
  ('P1', 'tingchao_repaired.svg', '已生成候选：听潮剑修复形态，不自动设为本命法宝'),
  ('P2', 'wenren_sea_chart.svg', '已生成候选：闻人照海图，连接远行线索'),
  ('P2', 'wen_zhaoheng_diary.svg', '温照衡遗物日记与阵图线索；沿用档案和候选城徽部件，不将未揭示的完整真相写进小图文字'),
 ],
 '11_ui_rites': [
  ('P0', 'scroll_panel_dark.png', '深色兼容卷轴已有候选，适配现有浅色文字'),
  ('P0', 'hero_meditate.png', '开局静房首次闭关与领悟的打坐插画；沿用第01批主角身份与既定画法，真实透明背景，不提前宣告宗门归属'),
  ('P1', 'breakthrough_ritual_vignette.png', '突破筹划功能插画，条件、资源和结果由UI独立绘制'),
  ('P1', 'exploration_states.svg', '未知／已听闻／已发现／已到访／已探索完毕五种状态，交独立可组合矢量而非写死在地图'),
  ('P1', 'city_port_markers.svg', '城市与海港地图标记，区分旧坊市及内河渡口'),
  ('P1', 'retreat_return_summary.svg', '出关消息、故人变故与约定提醒的可组合空白部件；沿用现有UI画法，日期、人名与结果由程序绘制，先复用现有卷轴'),
 ],
 '12_vfx': [
  ('P2', 'zhaoshui_water_metal_chain.png', '按新大纲6.3的水金神通连击和善水印转化制作表现候选，不沿用旧版蓄势／反击机制；不改规则'),
  ('P1', 'cangxi_concealment.png', '筑基篇藏息传承的轻雾／撤离表现，沿用原特效要求；不画成永久隐身，不改变实际风险规则'),
  ('P2', 'tingchao_water_qi.png', '听潮剑修复后在水脉附近开局多吸灵气的表现候选，保留同一剑型；帧数、时长与实际消费者确认后再做'),
 ],
}


def main():
    configure_writes()
    catalog_path = PACK / 'inventory.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    art = json.loads((ROOT / 'data/art.json').read_text(encoding='utf-8'))
    # Snapshot the one project icon outside the initial two art roots.
    if not any(a['path'] == 'assets/icon.svg' for a in catalog['assets']):
        path = ROOT / 'assets/icon.svg'
        backup = WORK / 'baseline/assets/icon.svg'
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, backup)
        catalog['assets'].append({'path': 'assets/icon.svg', 'category': 'app_icon', 'status': 'pending',
                                  'baseline': {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'bytes': path.stat().st_size}})
    # Include assets added by other development commits after the initial art
    # inventory. Preserve them unchanged and give them their own pending entry.
    known = {entry['path'] for entry in catalog['assets']}
    for path in sorted((ROOT / 'assets').rglob('*')):
        if path.suffix.lower() not in ('.svg', '.png', '.jpg', '.jpeg', '.webp'):
            continue
        rel = path.relative_to(ROOT).as_posix()
        if rel in known:
            continue
        backup = WORK / 'baseline' / rel
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, backup)
        info = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'bytes': path.stat().st_size}
        if path.suffix.lower() != '.svg':
            with Image.open(path) as image:
                info.update(size=list(image.size), mode=image.mode)
        catalog['assets'].append({'path': rel, 'category': 'upstream_addition', 'status': 'pending', 'baseline': info})
    # Freeze accurate status: vectors were written, but the game has not had its
    # import/art/UI checks for this batch. No runtime PNG has been deployed.
    for entry in catalog['assets']:
        if entry['status'] == 'integrated':
            entry['status'] = 'modified_pending_game_qa'
    catalog.update(generation_status='stopped_by_user', runtime_png_replaced=0,
                   note='User will dispatch separate chats. Handoffs produce candidates only; integration is separate.')
    jsave(catalog_path, catalog)
    actor_sources = collect_actor_sources(art)
    entries = {key: [] for key in DEFS}
    for entry in catalog['assets']:
        record = dict(entry)
        record['actor_layouts'] = actor_sources.get(entry['path'], [])
        entries[category(entry['path'], actor_sources)].append(record)
    assert sum(map(len, entries.values())) == len(catalog['assets'])
    all_paths = [e['path'] for group in entries.values() for e in group]
    assert len(all_paths) == len(set(all_paths))

    samples_path = ROOT / '.tmp/style_samples_20261019/samples.json'
    if not samples_path.exists():
        samples_path = PACK / 'approved_samples/index.json'
    samples = normalize(json.loads(samples_path.read_text(encoding='utf-8')))
    sample_map = {}
    for sample in samples:
        dest = PACK / 'approved_samples' / Path(sample['new']).name
        dest.parent.mkdir(parents=True, exist_ok=True)
        source = project_path(sample.get('packaged_new', sample['new']))
        if source != dest:
            shutil.copy2(source, dest)
        sample_map[int(sample['id'][:2])] = {**sample, 'packaged_new': dest.as_posix()}
        for suffix in ('.svg',):
            svg = source.with_suffix(suffix)
            if svg.exists() and svg != dest.with_suffix(suffix):
                shutil.copy2(svg, dest.with_suffix(suffix))
    jsave(PACK / 'approved_samples/index.json', list(sample_map.values()))

    jobs = json.loads((PACK / 'generated_jobs.json').read_text(encoding='utf-8-sig'))
    assert len(jobs) == len(CANDIDATES)
    completed = []
    for job in jobs:
        batch, title, status = CANDIDATES[job['id']]
        source = WORK / (job['id'] + '.png')
        dest = BATCHES / batch / 'candidates' / source.name
        dest.parent.mkdir(parents=True, exist_ok=True)
        if source.exists():
            shutil.copy2(source, dest)
        elif not dest.exists():
            raise FileNotFoundError('Missing packaged candidate: ' + str(dest))
        with Image.open(dest) as im:
            info = {'size': list(im.size), 'mode': im.mode}
            if im.mode == 'RGBA':
                info.update(alpha_extrema=list(im.getchannel('A').getextrema()), corner_alpha=im.getpixel((0, 0))[3])
        prompt_path = BATCHES / batch / 'prompts' / (job['id'] + '.txt')
        text(prompt_path, job['prompt'])
        completed.append({'id': job['id'], 'title': title, 'batch': batch, 'status': status,
                          'path': dest.as_posix(), 'prompt': prompt_path.as_posix(), 'refs': job.get('refs', []),
                          'sha256': hashlib.sha256(dest.read_bytes()).hexdigest(), **info})
    jsave(PACK / 'completed_candidates.json', completed)
    references_path = ROOT / '.tmp/mcs_style_reference_20261019/sources.json'
    if references_path.exists():
        jsave(PACK / 'reference_sources.json', json.loads(references_path.read_text(encoding='utf-8')))

    common = '''
# 多对话共用规则

1. 只执行用户交给你的批次；先读本包 STYLE_GUIDE.md、新大纲和美术影响评审。
2. 各类资源遵循各自参考。人物使用 C 版；地图、场景、妖兽、图标、UI分别遵循对应样张。不能统一套人物提示词。
3. 先查看 inputs.json 中的实际原图、对应真实参考和已生成候选；不要凭文件名猜形象。已生成≠用户已批准最终设计。
4. 本轮交付统一写本批的 output/，保留独立原图、完整提示词、参考角色与身份说明，以及 delivery.json。只生成自己的资源，不改别批文件。
5. 并行期间不替换 assets/ 的正式资源，不改 data/、scripts/、共享 inventory.json 或别人任务说明。原始路径只是将来集成目标。
6. 如需修改生成器，在本批 output/ 中交付补丁或脚本副本。只有第10批提出物品图标生成器修改，第11批提出UI生成器修改；最后统一集成。
7. 保留原始尺寸、长宽比、透明度、朝向、图集行列、帧顺序和自定义 frame_regions。需要变更时在 delivery.json 明确提出，不擅自改游戏规则或存档 ID。
8. 背景默认无文字、无按钮、无角色；标签和交互位置由界面承担。剧情插画如需人物，必须沿用第02批身份参考。
9. PNG 的真实 alpha 需检查，不能只凭预览底色判断。图集每一格都要有完整头发、道具和脚部，不跨格、不裁剑尖、不缺姿态。
10. 全部项目输出、缓存、备份和日志存 D:/fqh/flash，临时文件在 .tmp/，不手动写 C 盘。内置 imagegen 的自动缓存路径不由提示词可靠控制：不承诺指定路径，已产出项目图片及时迁入 D 盘；不要为控制路径擅自切换 API／CLI。
11. 位图用 imagegen；原生 SVG 应直接编辑或修改对应生成器，不用批量滤镜冒充重绘，不把矢量统一栅格化。
12. 原作截图仅作绘画语言参考，不复制原作人物、地理、UI文字或水印到交付图，不放入正式 assets/。
13. 自动 Godot 检查只能 --headless，不开可见游戏／编辑器。图像生成对话通常只交候选和检查记录，正式导入与全量验证统一处理。
14. 不提交 Git、不推送、不启动定时任务、不创建其他对话；用户自行安排各批。

交付清单建议字段：source_path、output_path、status、dimensions、alpha、actor_layout、prompt_path、reference_paths、checks、integration_notes。
'''
    text(PACK / 'COMMON_RULES.md', common)

    summary = []
    for key, (title, sample_ids, style, tasks) in DEFS.items():
        folder = BATCHES / key
        folder.mkdir(parents=True, exist_ok=True)
        (folder / 'output').mkdir(exist_ok=True)
        text(folder / 'output/.gitkeep', '')
        group = entries[key]
        jsave(folder / 'inputs.json', group)
        with (folder / 'inputs.csv').open('w', encoding='utf-8-sig', newline='') as file:
            writer = csv.writer(file)
            writer.writerow(['path', 'status', 'width', 'height', 'mode', 'baseline_sha256'])
            for e in group:
                info = e.get('current', e.get('baseline', {}))
                size = info.get('size', ['', ''])
                writer.writerow([e['path'], e['status'], *size, info.get('mode', ''), e.get('baseline', {}).get('sha256', '')])
        refs = [sample_map[i] for i in sample_ids]
        jsave(folder / 'references.json', refs)
        planned = [{'priority': priority, 'filename': filename, 'brief': brief,
                    'status': 'planned_or_existing_candidate',
                    'output_path': (folder / 'output' / filename).as_posix()}
                   for priority, filename, brief in PLANNED[key]]
        jsave(folder / 'new_asset_briefs.json', planned)
        candidates = [e for e in completed if e['batch'] == key]
        lines = [f'# {key} · {title}', '', f'现有资源：{len(group)} 项。已归档本轮生成位图：{len(candidates)} 张。', '', '本文件是交接说明；当前对话已按用户要求停止生成，后续由用户在新对话授权执行。', '', '## 先读', '', link('通用规则', PACK / 'COMMON_RULES.md'), link('分类风格规范', PACK / 'STYLE_GUIDE.md'), link('新大纲', ROOT / 'docs/GAME_OUTLINE.md'), link('美术影响评审', ROOT / 'docs/ART_IMPACT_WORLD_REWRITE_20261019.md'), '', '## 本批画法', '', style, '', '## 制作范围与顺序', '']
        lines += [f'{i+1}. {t}' for i, t in enumerate(tasks)]
        lines += ['', '## 输入与输出', '', '- `inputs.json` 是本批完整原图清单，含尺寸、哈希和角色帧定义；`inputs.csv` 便于浏览。', '- `references.json` 指向本批已确定样张及对应真实参考。注意参考内容不一定与交付题材相同。', '- `new_asset_briefs.json` 是新大纲所需图片的逐项说明，不代表已经生成或接入。P0开局／基础，P1首段修行，P2中期扩展，P3旧城与结局；后期布局未定时先留待办。', '- `candidates/` 为已生成待验收图片，`prompts/` 为当时完整提示词；先复用或修订，不盲目从头生成。', '- 新产物只写本目录 `output/`，交付 `delivery.json` 和逐张提示词；未生成项目保留待办，不冒称已完成。', '']
        if candidates:
            lines += ['## 已有位图候选', '', '| 文件 | 内容 | 状态 |', '|---|---|---|']
            lines += [f"| {link(Path(c['path']).name, Path(c['path']))} | {c['title']} | {c['status']} |" for c in candidates]
        if key == '03_portrait_pool':
            lines += ['', '## 子批', '', '248张本地头像中，2张定制头像已划给第02批；本批实际246张，按年龄和性别划成8个子批，每个不超过32张。']
        text(folder / 'TASK.md', '\n'.join(lines))
        prompt = f'请按 D:/fqh/flash/art_sources/refresh_20261019/batches/{key}/TASK.md 执行“{title}”这一批美术工作。先读通用规则和本批 inputs.json、references.json、new_asset_briefs.json，查看原图及已有候选。各类画法以对应参考为准。只在本批 output/ 生成和整理交付，暂不替换正式 assets/，不修改游戏规则、共享配置或其他批次文件。'
        text(folder / 'START_PROMPT.txt', prompt)
        summary.append({'id': key, 'title': title, 'count': len(group), 'candidate_pngs': len(candidates), 'task': (folder / 'TASK.md').as_posix()})

    subbatches = []
    pool = entries['03_portrait_pool']
    for demographic in sorted({Path(e['path']).parent.name for e in pool}):
        group = sorted((e for e in pool if Path(e['path']).parent.name == demographic), key=lambda e: e['path'])
        for start in range(0, len(group), 32):
            part = group[start:start+32]
            suffix = f'_{start//32+1:02d}' if len(group) > 32 else ''
            name = demographic + suffix
            folder = BATCHES / '03_portrait_pool' / name
            (folder / 'output').mkdir(parents=True, exist_ok=True)
            text(folder / 'output/.gitkeep', '')
            jsave(folder / 'inputs.json', part)
            text(folder / 'TASK.md', f'# 普通头像子批：{name}\n\n本批{len(part)}张，只处理本目录 inputs.json。\n\n先读上级 TASK.md 和总包 COMMON_RULES.md。使用已确认人物 C 版；保持年龄、性别、职业和原文件身份，查看原图后逐张生成。只写本目录 output/，交付 delivery.json 与完整提示词，不替换正式资源，不写其他子批。')
            text(folder / 'START_PROMPT.txt', f'请按 {folder.as_posix()}/TASK.md 执行这一批 {len(part)} 张普通头像，只处理本批 inputs.json，只在本批 output/ 交付，遵守上级风格规范和通用规则。')
            subbatches.append({'id': name, 'count': len(part), 'task': (folder / 'TASK.md').as_posix()})
    jsave(BATCHES / '03_portrait_pool/subbatches.json', subbatches)
    jsave(PACK / 'batch_index.json', {'batches': summary, 'portrait_subbatches': subbatches})
    icon_candidates = BATCHES / '10_item_skill_icons/candidates/icons'
    icon_candidates.mkdir(parents=True, exist_ok=True)
    for path in (ROOT / 'assets/art/story/icons').glob('*.svg'):
        shutil.copy2(path, icon_candidates / path.name)
    review = BATCHES / '10_item_skill_icons/review'
    review.mkdir(exist_ok=True)
    if (WORK / 'vector_overview.png').exists():
        shutil.copy2(WORK / 'vector_overview.png', review / 'vector_overview.png')
    baseline_count = sum('baseline' in e for e in catalog['assets'])
    changed = sum(e['status'] == 'modified_pending_game_qa' for e in catalog['assets'])
    rows = ['# 美术分批交接总入口', '', '**状态：按用户要求停止图片生成。用户将自行开启多个对话，分别执行下列批次。**', '', f'本包覆盖{baseline_count}项原有美术，加9个新大纲SVG，共{len(catalog["assets"])}项正式目录资源。另归档本轮13张生成位图（12项独立资源，主角图集含初版及修正版），以及此前13类样张。', '', f'当前正式PNG替换数：0。已有{changed}个正式SVG及两个原生生成器被修改，另有9个新增SVG；205个SVG已通过Godot无窗口渲染检查，尚未完成游戏导入／美术／UI回归。没有修改玩法数据、存档或运行脚本。', '', '## 开新对话的用法', '', '每批目录都有 `START_PROMPT.txt`，复制其内容到新对话即可。普通头像使用8个子批中的启动词，不把父目录与子批同时分给不同对话。', '', '所有生成对话先交付本批 `output/`，正式替换最后统一集成。这样多对话不会同时改同一张正式资源或共享配置。', '', link('通用规则', PACK / 'COMMON_RULES.md') + ' · ' + link('分类风格规范', PACK / 'STYLE_GUIDE.md') + ' · ' + link('本轮13张候选索引', PACK / 'completed_candidates.json'), '', '## 12类任务', '', '| 批次 | 工作范围 | 原有／已新增目录资源 | 本轮位图候选 |', '|---|---|---:|---:|']
    rows += [f"| {link(b['id'], Path(b['task']))} | {b['title']} | {b['count']} | {b['candidate_pngs']} |" for b in summary]
    rows += ['', '## 普通头像的8个子批', '', '| 子批 | 张数 |', '|---|---:|']
    rows += [f"| {link(b['id'], Path(b['task']))} | {b['count']} |" for b in subbatches]
    rows += ['', '## 已有图片与状态', '', '- 本轮位图按批次归档在 `batches/*/candidates/`，完整提示词在相邻 `prompts/`。它们是已生成候选，不等于用户已批准新人物、城徽或构图。', '- 主角图集 `hero_atlas.png` 为初版，`hero_atlas_alpha.png` 为修正版。两者均有真实alpha，透明检查应读取像素，不应只看预览底色。', '- 前轮样张在 `approved_samples/`，包括2个SVG源文件。地点、地图、飞升样张只作为画法锚点，其旧构图不能覆盖新大纲要求。', '- 真实《觅长生》截图仍在 D:/fqh/flash/.tmp/mcs_style_reference_20261019/，原始来源记录在本包 `reference_sources.json`，不复制到正式游戏资源。', '- 原版资源备份位于 D:/fqh/flash/.tmp/art_refresh_20261019/baseline/。正式目录的SVG修改已保留，后续批次先审查现状，不盲目回滚或重复生成。', '', '## 建议分工', '', '可同时开展人物动作、关键头像、普通头像子批、环境、图标或界面。涉及同辈出场的剧情插画先使用第02批候选身份；地图和地点共享新大纲空间关系，但各自只交候选。特效先做审查，旧城与海域大场景在玩法和布局确定后再定稿。', '', '本次整理不会继续生成图片、替换PNG、自动创建对话或提交Git。']
    readme = '\n'.join(rows).replace('尚未完成游戏导入／美术／UI回归。', '整理阶段未进行游戏回归；后续提交前检查见本目录 VALIDATION.md。')
    readme = readme.replace('本次整理不会继续生成图片、替换PNG、自动创建对话或提交Git。', '生成批次不会自动替换PNG或创建其他对话；Git提交推送由用户另行授权。')
    text(PACK / 'README.md', readme)
    jsave(WORK / 'handoff_validation.json', {'baseline_assets': baseline_count, 'runtime_entries': len(all_paths), 'unique_entries': len(set(all_paths)), 'batch_counts': {k: len(v) for k, v in entries.items()}, 'pool_subbatches': len(subbatches), 'pool_subbatch_total': sum(s['count'] for s in subbatches), 'candidate_pngs': len(completed), 'candidate_unique_assets': len(completed)-1, 'modified_svg': changed, 'missing_inputs': [p for p in all_paths if not (ROOT / p).exists()]})
    from repair_handoffs import repair
    repair()
    print('HANDOFF_READY', {'baseline': baseline_count, 'runtime_entries': len(all_paths), 'candidate_pngs': len(completed), 'batches': len(summary), 'portrait_subbatches': len(subbatches), 'modified_svg': changed})


if __name__ == '__main__':
    if not sys.dont_write_bytecode:
        raise SystemExit('Run with python -B to avoid bytecode cache writes.')
    main()

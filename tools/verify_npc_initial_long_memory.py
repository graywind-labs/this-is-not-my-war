from __future__ import annotations

import json
from pathlib import Path
import re
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
PROFILE_PATH = REPO_ROOT / "data" / "npc_profiles.json"
BUILDING_PATH = REPO_ROOT / "data" / "building_defs.json"
MEMORY_PATH = REPO_ROOT / "data" / "npc_initial_long_memory.json"
PROMPT_PATHS = (
    REPO_ROOT / "data" / "prompts" / "dialogue_system_prompt.txt",
    REPO_ROOT / "data" / "prompts" / "daily_plan_system_prompt.txt",
    REPO_ROOT / "data" / "prompts" / "plan_revision_judgement_system_prompt.txt",
    REPO_ROOT / "data" / "prompts" / "plan_revision_system_prompt.txt",
    REPO_ROOT / "data" / "prompts" / "battle_judgement_system_prompt.txt",
    REPO_ROOT / "data" / "prompts" / "daily_reflection_system_prompt.txt",
)

EXPECTED_DIARY_PERIODS = ("往昔·来站前", "往昔·初到驿站", "往昔·近日")
DIARY_RECORD_FIELDS = {
    "day",
    "time",
    "entry",
    "source",
    "model_provider",
    "model_name",
    "model_fallback_used",
    "debug_reason",
}
NON_BUILDING_SUBJECTS = {"plaza", "notice_board"}
PRIMARY_BUILDING_MIN_RELATIONS = {
    "stableman_01": {"stable": 4},
    "cook_01": {"dining_hall": 4, "tavern": 2},
    "gardener_01": {"garden": 3},
    "blacksmith_01": {"blacksmith": 3},
    "veteran_deputy_01": {"main_hall": 2, "front_gate": 2, "training_ground": 3},
    "priest_01": {"chapel": 3, "tavern": 2},
    "doctor_01": {"clinic": 4},
    "engineer_01": {"workshop": 3, "wall": 2},
}
OPEN_GUARD_MARKERS = (
    "尚待观察",
    "仍待观察",
    "仍需观察",
    "要看之后",
    "取决于之后",
    "尚未判断",
    "目前还看不出来",
    "以后只根据",
    "以后看实际",
    "之后会根据",
    "还没有依据",
    "还需要通过",
    "尚无足够",
    "没有事实可以判断",
    "是否愿意",
    "是否会",
    "能否信任",
    "具体做法",
    "以后",
    "未来",
)
GUARD_DUTY_MARKERS = ("防务", "警戒", "人员安排", "危急")
EXPECTED_GUARD_RELATION_VALUES = {
    "role": "station_defense_alert_and_emergency_staff_coordination",
    "arrival_at_station": "arrived_three_years_before_game_start",
    "past_before_station": "unknown_not_disclosed",
    "pre_game_relationship": "consistently_dedicated_and_harmonious",
}
PREJUDGED_GUARD_PHRASES = (
    "守备官曾经",
    "守备官已经",
    "守备官答应",
    "守备官背叛",
    "我信任守备官",
    "我效忠守备官",
    "我憎恨守备官",
)
CJK_PATTERN = re.compile(r"[\u3400-\u9fff]")
OUT_OF_WORLD_LABEL_PHRASES = ("玩家", "程序", "结算", "开局")
BUILDING_MANUAL_MARKERS = (
    "初始",
    "升级后",
    "槽位",
    "系统",
    "结算",
    "等级",
    "数值",
    "解锁",
    "百分之",
)
WAREHOUSE_UNIMPLEMENTED_MARKERS = (
    "少丢",
    "物资流失",
    "丢物资",
    "丢货",
    "掠夺",
    "损失比例",
)
OPAQUE_STYLE_MARKERS = (
    "仿佛",
    "宛如",
    "如同",
    "好像",
    "像个",
    "像一",
    "季节没有耳朵",
    "国王的餐桌",
    "有主见的蚯蚓",
    "问题先把嘴占上",
    "根系般",
    "愿意合作的木料",
)
LEGACY_COPY_FRAGMENTS = (
    "缰绳是两头都能感觉到的绳子",
    "白鼻说什么也不肯踏上那座桥",
    "草料架却摆得像国王的餐桌",
    "饿汉争论的真理通常藏在第二碗汤里",
    "九粒装死",
    "土硬得像格伦的问候",
    "铁匠铺的炉口歪",
    "人不是棋子",
    "前者要少掺水",
    "药瓶若睡不好会摔碎",
    "窗却朝错了风",
    "好运不能代替结构",
)
LEGACY_STORY_SUBJECTS = {
    "stableman_01": {"old_ordelan", "white_nose_mare"},
    "cook_01": {"aunt_marta", "ferry_inn"},
    "gardener_01": {"speckled_bean_seeds"},
    "blacksmith_01": {"patched_plowshare"},
    "veteran_deputy_01": {"north_ridge_retreat"},
    "priest_01": {"riverbend_wine_cask"},
    "doctor_01": {"blue_thread_kit"},
    "engineer_01": {"three_notch_wedge"},
}
RECENT_WAR_MARKERS = (
    "敌袭",
    "敌人",
    "敌军",
    "战事",
    "战斗",
    "开战",
    "打仗",
    "备战",
    "防线",
    "警铃",
    "军令",
    "战报",
    "征召",
    "入伍",
    "围困",
    "守城",
)
RECENT_DAILY_MARKERS = {
    "stableman_01": ("马厩", "栗风", "灰鬃", "草料", "刷毛", "喂马"),
    "cook_01": ("食堂", "锅", "餐食", "面包", "汤", "灶台"),
    "gardener_01": ("菜园", "种", "浇水", "除草", "收成", "堆肥"),
    "blacksmith_01": ("铁匠铺", "修", "铰链", "马蹄", "锅", "工具"),
    "veteran_deputy_01": ("巡查", "门闩", "值班", "记录", "清单", "交接"),
    "priest_01": ("小教堂", "祈祷", "弥撒", "酒", "来访", "长椅"),
    "doctor_01": ("诊所", "病人", "药", "绷带", "伤口", "看诊"),
    "engineer_01": ("工械坊", "修", "工具", "木料", "车", "尺寸"),
}
GUARD_PRENOTICE_PHRASES = (
    "敌情",
    "军令",
    "战报",
    "敌袭",
    "即将进攻",
    "要求备战",
    "通知备战",
    "已经传达",
)
ARRIVAL_ORDER = (
    "veteran_deputy_01",
    "stableman_01",
    "cook_01",
    "gardener_01",
    "blacksmith_01",
    "engineer_01",
    "priest_01",
    "doctor_01",
)
PRE_STATION_TIME_MARKERS = {
    "veteran_deputy_01": "三年前初秋",
    "stableman_01": "三年前入冬前",
    "cook_01": "两年前春汛后",
    "gardener_01": "两年前夏末",
    "blacksmith_01": "两年前初冬",
    "engineer_01": "去年开春",
    "priest_01": "去年初夏",
    "doctor_01": "去年秋雨前",
}
RECENT_ENTRY_SNAPSHOTS = {
    "stableman_01": "这几天栗风左后蹄有些发热，灰鬃又总想抢它的草。我把草槽隔开，给栗风减了负重，每晚再检查一次。布鲁诺嫌我为两匹马多领了一桶热水，念叨完还是把水烧了。我明天得先把用过的桶刷干净。",
    "cook_01": "今天收灶后，我重新核对了粮食、柴火和每个人的饭量。伊沃送来的菜比上周多一筐，马塞尔又问能不能留些粮酿酒。我让他先吃完晚饭，再讨论酒窖。今晚的汤够所有人添一次；想添第二次的，明天来帮我刷锅。",
    "gardener_01": "北畦刚补种了一行萝卜，去年留下的豆种也分到了三块地里。两行嫩苗被乌鸦啄光，我重新撒种，又罩上细网。布鲁诺问下一批菜什么时候能进锅，我告诉他至少要等它们长出来。他嫌时间太久，我只能把预计收成的日子再说一遍。",
    "blacksmith_01": "这阵子铁匠铺接到的都是锅、门栓和农具。布鲁诺送来的锅底裂了三道缝，还说再撑一个月没问题。我把锅补好，让他下次见到第一道裂缝就送来。他答应得很快，至于会不会照做，我等那口锅再回来时就知道了。",
    "veteran_deputy_01": "这几天没有大事。我每天查看城门和后门，午后在训练场练一轮剑盾，再帮托马把总往外跑的灰鬃牵回马厩。布鲁诺要求用餐时间不得排岗。我重新核对了轮值，这项调整不影响巡查，也能让值班的人按时吃饭。",
    "priest_01": "这阵子我照常主持弥撒，也接待来谈心的人。多数人说到一半会问酒是否免费，听到答案后，通常就愿意直接谈正事。空闲时我给酒窖换了两只塞子，又请格伦在弥撒期间停一停锤子。他答应停半个时辰，我接受了。",
    "doctor_01": "这周来诊所的多是日常小伤：托马擦破手背，格伦被火星烫出水泡，欧文又因为熬夜头痛。三个人都先说“不碍事”，最后也都坐下来让我处理。我补齐了登记册，把两张病床重新晒过。没有大病号的时候，诊所也很少真正空着。",
    "engineer_01": "这几天我处理了三件小事：加固食堂那条总晃的长凳，给马厩门换铰链，再清理围墙排水槽。布鲁诺坚持长凳没坏，只是客人坐得不对。我请他坐到松动的那一头，长凳立刻向左一歪。他看完就让我继续修。",
}


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _assert_chinese_label(value: Any, context: str) -> str:
    text = str(value).strip()
    assert text, f"{context} must not be empty"
    assert CJK_PATTERN.search(text), f"{context} must contain Chinese display text: {text!r}"
    assert "玩家" not in text, f"{context} must use 守备官 instead of 玩家"
    return text


def _assert_direct_style(value: Any, context: str) -> str:
    text = str(value).strip()
    assert text, f"{context} must not be empty"
    for marker in OPAQUE_STYLE_MARKERS + LEGACY_COPY_FRAGMENTS:
        assert marker not in text, (
            f"{context} keeps an opaque or legacy T0059 expression: {marker!r}"
        )
    return text


def _verify_diary(npc_id: str, diary_value: Any) -> set[str]:
    assert isinstance(diary_value, list), f"{npc_id}.diary must be an array"
    assert len(diary_value) >= 3, f"{npc_id} needs at least three initial diary slices"
    periods: list[str] = []
    entries: set[str] = set()
    for index, raw_entry in enumerate(diary_value):
        assert isinstance(raw_entry, dict), f"{npc_id}.diary[{index}] must be an object"
        assert set(raw_entry) == DIARY_RECORD_FIELDS, (
            f"{npc_id}.diary[{index}] must exactly match the runtime diary record shape"
        )
        assert int(raw_entry["day"]) == 0, f"{npc_id}.diary[{index}] must be pre-game day 0"
        period = str(raw_entry["time"]).strip()
        entry = str(raw_entry["entry"]).strip()
        source = str(raw_entry["source"]).strip()
        assert period, f"{npc_id}.diary[{index}].time must label its life slice"
        assert 70 <= len(entry) <= 130, (
            f"{npc_id}.diary[{index}] should stay short but substantial, got {len(entry)} chars"
        )
        assert "我" in entry, f"{npc_id}.diary[{index}] must be first person"
        assert "玩家" not in entry, f"{npc_id}.diary[{index}] must not use 玩家"
        _assert_direct_style(entry, f"{npc_id}.diary[{index}].entry")
        assert source == "initial_long_memory", (
            f"{npc_id}.diary[{index}] must declare initial_long_memory provenance"
        )
        assert raw_entry["model_provider"] == ""
        assert raw_entry["model_name"] == ""
        assert raw_entry["model_fallback_used"] is False
        assert raw_entry["debug_reason"] == "seeded_before_game"
        assert entry not in entries, f"{npc_id} has a duplicated diary entry"
        periods.append(period)
        entries.add(entry)
        if period == "往昔·来站前":
            assert PRE_STATION_TIME_MARKERS[npc_id] in entry, (
                f"{npc_id} pre-station diary must say when the NPC reached the station"
            )
            assert any(marker in entry for marker in ("辞", "关了门", "缩小", "不想", "缩编", "合并", "扩建", "离开")), (
                f"{npc_id} pre-station diary must explain why the old life led to the station"
            )
            assert any(marker in entry for marker in ("驿站", "这里", "来了", "赶来", "差事")), (
                f"{npc_id} pre-station diary must end at the station rather than at an unrelated past event"
            )
        elif period == "往昔·初到驿站":
            current_index = ARRIVAL_ORDER.index(npc_id)
            earlier_names = {
                {
                    "veteran_deputy_01": "艾达",
                    "stableman_01": "托马",
                    "cook_01": "布鲁诺",
                    "gardener_01": "伊沃",
                    "blacksmith_01": "格伦",
                    "engineer_01": "欧文",
                    "priest_01": "马塞尔",
                    "doctor_01": "莉娜",
                }[earlier_id]
                for earlier_id in ARRIVAL_ORDER[:current_index]
            }
            later_names = {
                {
                    "veteran_deputy_01": "艾达",
                    "stableman_01": "托马",
                    "cook_01": "布鲁诺",
                    "gardener_01": "伊沃",
                    "blacksmith_01": "格伦",
                    "engineer_01": "欧文",
                    "priest_01": "马塞尔",
                    "doctor_01": "莉娜",
                }[later_id]
                for later_id in ARRIVAL_ORDER[current_index + 1 :]
            }
            if earlier_names:
                assert any(name in entry for name in earlier_names), (
                    f"{npc_id} arrival diary must meet someone already at the station"
                )
            assert not any(name in entry for name in later_names), (
                f"{npc_id} arrival diary mentions a resident who had not arrived yet"
            )
        if period == "往昔·近日":
            assert entry == RECENT_ENTRY_SNAPSHOTS[npc_id], (
                f"{npc_id} recent micro-story must remain unchanged in T0061"
            )
            for marker in RECENT_WAR_MARKERS:
                assert marker not in entry, (
                    f"{npc_id} recent diary incorrectly knows about future conflict: "
                    f"{marker!r}"
                )
            assert any(
                marker in entry for marker in RECENT_DAILY_MARKERS[npc_id]
            ), f"{npc_id} recent diary must describe recognizable station daily life"
    assert tuple(periods[:3]) == EXPECTED_DIARY_PERIODS, (
        f"{npc_id} first three diary slices must be {EXPECTED_DIARY_PERIODS}, got {periods[:3]}"
    )
    return entries


def _verify_knowledge_graph(
    npc_id: str,
    graph_value: Any,
    npc_ids: set[str],
    npc_labels: dict[str, str],
    building_labels: dict[str, str],
) -> set[str]:
    assert isinstance(graph_value, dict), f"{npc_id}.knowledge_graph must be an object"
    assert graph_value.get("schema_version") == "key_value_replace_v1", (
        f"{npc_id}.knowledge_graph must use key_value_replace_v1"
    )
    assert int(graph_value.get("updated_day", -1)) == 0
    assert str(graph_value.get("updated_time", "")).strip() == "开局前"
    assert "patches" not in graph_value, f"{npc_id}.knowledge_graph must not use append-only patches"
    by_subject = graph_value.get("by_subject")
    assert isinstance(by_subject, dict) and by_subject, f"{npc_id}.knowledge_graph.by_subject is empty"

    required_people = npc_ids - {npc_id}
    required_subjects = set(building_labels) | required_people | {"guard_officer"}
    missing_subjects = sorted(required_subjects - set(by_subject))
    assert not missing_subjects, f"{npc_id} knowledge graph misses subjects: {missing_subjects}"
    assert not (NON_BUILDING_SUBJECTS & set(by_subject)), (
        f"{npc_id} must not classify plaza or notice_board as buildings/seeded knowledge subjects"
    )

    personal_subjects = (
        set(by_subject)
        - set(building_labels)
        - npc_ids
        - {"guard_officer"}
    )
    assert len(personal_subjects) >= 2, (
        f"{npc_id} needs at least two story-specific people, things or past events"
    )
    stale_subjects = LEGACY_STORY_SUBJECTS[npc_id] & set(by_subject)
    assert not stale_subjects, (
        f"{npc_id} still uses T0059 personal-story subjects: {sorted(stale_subjects)}"
    )

    value_labels: set[str] = set()
    for subject, raw_relations in by_subject.items():
        assert isinstance(raw_relations, dict) and raw_relations, (
            f"{npc_id}.{subject} must have at least one relation"
        )
        expected_subject_label = building_labels.get(subject, npc_labels.get(subject))
        if subject == "guard_officer":
            expected_subject_label = "守备官"
        for relation, raw_record in raw_relations.items():
            assert relation and isinstance(raw_record, dict), (
                f"{npc_id}.{subject}.{relation} must be a record"
            )
            value = str(raw_record.get("value", "")).strip()
            assert value, f"{npc_id}.{subject}.{relation}.value is empty"
            assert "玩家" not in value, f"{npc_id}.{subject}.{relation} must use 守备官"
            confidence = float(raw_record.get("confidence", -1.0))
            assert 0.0 <= confidence <= 1.0, (
                f"{npc_id}.{subject}.{relation}.confidence is outside 0..1"
            )
            subject_label = _assert_chinese_label(
                raw_record.get("subject_label"),
                f"{npc_id}.{subject}.{relation}.subject_label",
            )
            _assert_chinese_label(
                raw_record.get("relation_label"),
                f"{npc_id}.{subject}.{relation}.relation_label",
            )
            value_label = _assert_chinese_label(
                raw_record.get("value_label"),
                f"{npc_id}.{subject}.{relation}.value_label",
            )
            _assert_direct_style(
                value_label,
                f"{npc_id}.{subject}.{relation}.value_label",
            )
            assert value_label not in value_labels, (
                f"{npc_id} reuses the same knowledge wording: {value_label!r}"
            )
            value_labels.add(value_label)
            assert not any(phrase in value_label for phrase in OUT_OF_WORLD_LABEL_PHRASES), (
                f"{npc_id}.{subject}.{relation}.value_label breaks the in-world viewpoint: "
                f"{value_label!r}"
            )
            assert int(raw_record.get("day", -1)) == 0
            assert str(raw_record.get("time", "")).strip() == "开局前"
            if expected_subject_label is not None:
                assert subject_label == expected_subject_label, (
                    f"{npc_id}.{subject} subject label must be {expected_subject_label!r}"
                )
            if subject in building_labels:
                displayed_text = "%s %s" % (
                    str(raw_record.get("relation_label", "")),
                    value_label,
                )
                for marker in BUILDING_MANUAL_MARKERS:
                    if subject in {"wall", "main_hall"} and marker in {"槽位", "等级", "解锁"}:
                        # T0108 intentionally seeds the exact defense-device
                        # progression as pre-game stable knowledge.
                        continue
                    assert marker not in displayed_text, (
                        f"{npc_id}.{subject}.{relation} reads like a game manual: "
                        f"{marker!r}"
                    )

    for building_id, minimum_relations in PRIMARY_BUILDING_MIN_RELATIONS[npc_id].items():
        relation_count = len(by_subject.get(building_id, {}))
        assert relation_count >= minimum_relations, (
            f"{npc_id}.{building_id} needs {minimum_relations} detailed relations, "
            f"got {relation_count}"
        )

    guard_text = " ".join(
        "%s %s" % (
            str(record.get("value", "")),
            str(record.get("value_label", "")),
        )
        for record in by_subject["guard_officer"].values()
        if isinstance(record, dict)
    )
    guard_relations = by_subject["guard_officer"]
    assert set(guard_relations) == set(EXPECTED_GUARD_RELATION_VALUES), (
        f"{npc_id} guard-officer seed must contain role, arrival, unknown past and "
        f"pre-game relationship, got {sorted(guard_relations)}"
    )
    for relation, expected_value in EXPECTED_GUARD_RELATION_VALUES.items():
        assert guard_relations[relation]["value"] == expected_value, (
            f"{npc_id}.guard_officer.{relation} must use {expected_value!r}"
        )
    assert "防务" in guard_text and any(
        marker in guard_text for marker in GUARD_DUTY_MARKERS[1:]
    ), (
        f"{npc_id} guard-officer knowledge must preserve the post's basic duties"
    )
    assert "三年前" in str(guard_relations["arrival_at_station"]["value_label"]), (
        f"{npc_id} guard-officer arrival must state the shared three-year anchor"
    )
    unknown_past_text = str(guard_relations["past_before_station"]["value_label"])
    assert any(marker in unknown_past_text for marker in ("不知道", "不在我所知范围内")), (
        f"{npc_id} guard-officer past must be explicitly unknown"
    )
    assert any(marker in unknown_past_text for marker in ("不该", "不能", "不会", "不应")), (
        f"{npc_id} guard-officer past must forbid inference or invention"
    )
    relationship_text = str(guard_relations["pre_game_relationship"]["value_label"])
    assert any(marker in relationship_text for marker in ("尽责", "敬业", "忠于职守", "尽职", "认真履职")), (
        f"{npc_id} guard-officer pre-game relationship must preserve dedication"
    )
    assert any(marker in relationship_text for marker in ("和睦", "和气", "和谐")), (
        f"{npc_id} guard-officer pre-game relationship must preserve harmony"
    )
    non_relationship_guard_text = " ".join(
        "%s %s" % (
            str(record.get("value", "")),
            str(record.get("value_label", "")),
        )
        for relation, record in guard_relations.items()
        if relation != "pre_game_relationship" and isinstance(record, dict)
    )
    for marker in OPEN_GUARD_MARKERS:
        assert marker not in non_relationship_guard_text, (
            f"{npc_id} guard-officer factual seed adds an unnecessary assessment: "
            f"{marker!r}"
        )
    assert any(marker in relationship_text for marker in ("战时", "征召", "危险命令")), (
        f"{npc_id} pre-game relationship must distinguish ordinary harmony from wartime trust"
    )
    assert any(marker in relationship_text for marker in ("检验", "考验")), (
        f"{npc_id} pre-game relationship must state that wartime conduct is untested"
    )
    assert any(marker in relationship_text for marker in ("实际", "真实", "结果", "兑现")), (
        f"{npc_id} pre-game relationship must defer later trust to observed facts"
    )
    for phrase in PREJUDGED_GUARD_PHRASES:
        assert phrase not in guard_text, (
            f"{npc_id} guard-officer knowledge prejudges an interaction: {phrase!r}"
        )
    for phrase in GUARD_PRENOTICE_PHRASES:
        assert phrase not in guard_text, (
            f"{npc_id} guard-officer knowledge assumes a notice not yet delivered: "
            f"{phrase!r}"
        )

    warehouse_relations = by_subject["warehouse"]
    assert len(warehouse_relations) == 1
    warehouse_record = next(iter(warehouse_relations.values()))
    assert warehouse_record["value"] == "level_based_bulk_storage_and_post_breach_attack_target", (
        f"{npc_id} warehouse technical value must match the implemented runtime rules"
    )
    warehouse_text = str(warehouse_record["value_label"])
    assert all(
        marker in warehouse_text
        for marker in ("粮食", "餐食", "酒", "木材", "石料", "铁", "上限", "扩建")
    ), f"{npc_id} warehouse knowledge must explain level-based bulk-resource caps"
    assert any(marker in warehouse_text for marker in ("城门", "正门"))
    assert "主厅" in warehouse_text
    for marker in WAREHOUSE_UNIMPLEMENTED_MARKERS:
        assert marker not in warehouse_text, (
            f"{npc_id} warehouse knowledge claims an unimplemented rule: {marker!r}"
        )

    wall_text = " ".join(
        str(record.get("value_label", ""))
        for record in by_subject["wall"].values()
        if isinstance(record, dict)
    )
    main_hall_text = " ".join(
        str(record.get("value_label", ""))
        for record in by_subject["main_hall"].values()
        if isinstance(record, dict)
    )
    assert all(marker in wall_text for marker in ("弩床", "箭塔", "1、2、2、3、3、4")), (
        f"{npc_id} wall knowledge must preserve the current six-level universal-slot curve"
    )
    assert all(
        marker in main_hall_text
        for marker in ("弩床", "箭塔", "1、1、2、2、3、4")
    ), f"{npc_id} main-hall knowledge must preserve the delayed six-level slot curve"
    assert "射程" in main_hall_text and any(
        marker in main_hall_text for marker in ("两倍", "翻倍", "加倍")
    ), f"{npc_id} main-hall knowledge must preserve the 2x device range"
    assert not any(
        stale_phrase in f"{wall_text} {main_hall_text}"
        for stale_phrase in (
            "只能安在各自合适的墙位",
            "只会让墙体更耐打",
            "不会凭空多出安装器械的地方",
        )
    ), f"{npc_id} retained stale wall-only device knowledge"

    if npc_id == "doctor_01":
        recovery_text = str(by_subject["clinic"]["recovery_rule"]["value_label"])
        for required_fragment in ("倒下", "两", "自行行动"):
            assert required_fragment in recovery_text, (
                "doctor_01 clinic recovery must distinguish local unconscious aid "
                "from conscious clinic treatment"
            )
        study_text = str(by_subject["clinic"]["study_rule"]["value_label"])
        assert all(fragment in study_text for fragment in ("没有病人", "研读", "医术")), (
            "doctor_01 clinic knowledge must explain idle medical study"
        )
    if npc_id == "stableman_01":
        assignment_text = str(by_subject["stable"]["assignment_rule"]["value_label"])
        assert all(fragment in assignment_text for fragment in ("入伍", "主武器", "战斗")), (
            "stableman_01 stable knowledge must explain horse assignment eligibility"
        )
    if npc_id == "cook_01":
        meal_text = str(by_subject["dining_hall"]["meal_value_rule"]["value_label"])
        assert all(fragment in meal_text for fragment in ("餐食", "粮食", "更饱")), (
            "cook_01 dining knowledge must explain why prepared meals matter"
        )
    if npc_id == "veteran_deputy_01":
        instructor_text = str(
            by_subject["training_ground"]["instructor_growth_rule"]["value_label"]
        )
        assert all(
            fragment in instructor_text
            for fragment in ("没有受训者", "独自操练", "教练本事")
        ), "Ada must know both solo instructor practice and coached growth"
    if npc_id == "engineer_01":
        wall_upgrade_text = str(by_subject["wall"]["upgrade_rule"]["value_label"])
        assert all(
            fragment in wall_upgrade_text
            for fragment in ("1、2、2、3、3、4", "1、1、2、2、3、4", "最多", "某些")
        ), (
            "engineer_01 must know both host slot curves and that some levels do not unlock slots"
        )
    if npc_id == "blacksmith_01":
        wall_text = str(by_subject["wall"]["operational_role"]["value_label"])
        assert all(
            fragment in wall_text
            for fragment in ("弩床", "箭塔", "1、2、2、3、3、4", "至多")
        ), (
            "blacksmith_01 wall knowledge must preserve the six-level slot progression"
        )
        training_text = str(
            by_subject["training_ground"]["operational_role"]["value_label"]
        )
        assert all(
            required_fragment in training_text
            for required_fragment in ("主武器", "坐骑", "或", "教官")
        ), (
            "blacksmith_01 training knowledge must allow either a weapon or a mount"
        )
    return value_labels


def main() -> None:
    profiles = _load_json(PROFILE_PATH)
    buildings = _load_json(BUILDING_PATH)
    initial_memory = _load_json(MEMORY_PATH)

    assert isinstance(profiles, list) and len(profiles) == 8
    assert isinstance(buildings, list) and len(buildings) == 15
    assert isinstance(initial_memory, dict)

    profile_by_id = {str(profile["id"]): profile for profile in profiles}
    npc_ids = set(profile_by_id)
    npc_labels = {
        npc_id: str(profile["name"])
        for npc_id, profile in profile_by_id.items()
    }
    building_labels = {
        str(building["id"]): str(building["name"])
        for building in buildings
    }
    assert set(initial_memory) == npc_ids, (
        "Initial-memory NPC ids must exactly match npc_profiles.json"
    )

    all_diary_entries: set[str] = set()
    all_knowledge_labels: set[str] = set()
    for npc_id, profile in profile_by_id.items():
        background_story = str(profile.get("background_story", "")).strip()
        assert profile.get("religion") == "天主教", (
            f"{npc_id}.religion must use the concise shared value 天主教"
        )
        assert 20 <= len(background_story) <= 120, (
            f"{npc_id}.background_story must stay concise and fundamental"
        )
        assert "玩家" not in background_story
        _assert_direct_style(background_story, f"{npc_id}.background_story")
        for list_field in ("personality", "desires", "fears", "boundaries"):
            values = profile.get(list_field)
            assert isinstance(values, list) and values, f"{npc_id}.{list_field} is empty"
            for index, text in enumerate(values):
                _assert_direct_style(text, f"{npc_id}.{list_field}[{index}]")
        speech_style = _assert_direct_style(
            profile.get("speech_style", ""),
            f"{npc_id}.speech_style",
        )
        assert "作比" not in speech_style and "比喻" not in speech_style, (
            f"{npc_id}.speech_style must not prescribe repetitive occupational metaphors"
        )
        assert "signature_lines" not in profile, (
            f"{npc_id} must not retain fixed representative expressions"
        )
        assert profile.get("diary", []) == [], (
            f"{npc_id} base profile must not duplicate the separate initial diary"
        )
        assert profile.get("knowledge_graph", {}) == {}, (
            f"{npc_id} base profile must not duplicate the separate initial graph"
        )

        memory = initial_memory[npc_id]
        assert isinstance(memory, dict), f"{npc_id} initial memory must be an object"
        assert set(memory) == {"diary", "knowledge_graph"}, (
            f"{npc_id} initial memory must contain only diary and knowledge_graph"
        )
        diary_entries = _verify_diary(npc_id, memory["diary"])
        assert all_diary_entries.isdisjoint(diary_entries), (
            f"{npc_id} reuses another NPC's diary prose"
        )
        all_diary_entries.update(diary_entries)
        knowledge_labels = _verify_knowledge_graph(
            npc_id,
            memory["knowledge_graph"],
            npc_ids,
            npc_labels,
            building_labels,
        )
        overlap = all_knowledge_labels & knowledge_labels
        assert not overlap, (
            f"{npc_id} reuses another NPC's knowledge wording: {sorted(overlap)!r}"
        )
        all_knowledge_labels.update(knowledge_labels)
        by_subject = memory["knowledge_graph"]["by_subject"]
        personal_subjects = (
            set(by_subject)
            - set(building_labels)
            - npc_ids
            - {"guard_officer"}
        )
        for subject in personal_subjects:
            relations = by_subject[subject]
            first_record = next(iter(relations.values()))
            personal_label = str(first_record["subject_label"]).strip()
            assert personal_label not in background_story, (
                f"{npc_id}.background_story duplicates personal memory label "
                f"{personal_label!r}"
            )

    for prompt_path in PROMPT_PATHS:
        prompt_text = prompt_path.read_text(encoding="utf-8")
        assert "宗教信仰" in prompt_text, (
            f"{prompt_path.name} must preserve the shared religion field as character context"
        )
        assert all(marker in prompt_text for marker in ("三年前", "来站前", "相处和睦")), (
            f"{prompt_path.name} must preserve the shared guard-officer history boundary"
        )
        assert "初始" in prompt_text and "长期记忆" in prompt_text, (
            f"{prompt_path.name} must explain how seeded long memory differs from current facts"
        )
        assert "往昔·近日" in prompt_text and "传达敌情" in prompt_text, (
            f"{prompt_path.name} must preserve the pre-notice recent-memory timeline"
        )
        assert "第 N 天 + 时间" in prompt_text, (
            f"{prompt_path.name} must explain the diary timeline prefix"
        )
        assert "signature_lines" not in prompt_text, (
            f"{prompt_path.name} must not expose fixed representative expressions"
        )

    print(
        "verify_npc_initial_long_memory: ok "
        f"npcs={len(npc_ids)} buildings={len(building_labels)} "
        f"diary_entries={len(all_diary_entries)}"
    )


if __name__ == "__main__":
    main()

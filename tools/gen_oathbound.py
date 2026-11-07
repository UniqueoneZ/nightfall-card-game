#!/usr/bin/env python3
"""守誓者职业卡表（一次性生成脚本，数据以 data/cards.json 为准）。"""
import json, collections

D = lambda v: {"k": "damage", "v": v}
B = lambda v: {"k": "block", "v": v}
SB = lambda v: {"k": "self_block", "v": v}
ST = lambda s, v: {"k": "self_status", "status": s, "v": v}
TG = lambda s, v: {"k": "status", "status": s, "v": v}
DBB = lambda mult, add, hits=1: {"k": "damage_by_block", "mult": mult, "add": add, "hits": hits}
DR = lambda v: {"k": "draw", "v": v}
HL = lambda v: {"k": "heal", "v": v}

CARDS = [
 # (id, 名称, 费, 类型, 目标, 稀有度, 描述, 效果)
 ("g_strike","誓约斩",1,"attack","enemy","starter","造成 6 点伤害。",[D(6)]),
 ("g_guard","守势",1,"skill","none","starter","获得 5 点格挡。",[B(5)]),
 ("g_bash","盾击",1,"attack","enemy","starter","造成等同于当前格挡的伤害。",[DBB(1,0)]),
 ("g_iron","铁誓",2,"skill","none","starter","获得 10 点格挡，+2 反击。",[B(10),ST("thorns",2)]),
 ("g_riposte","反击姿态",1,"power","none","starter","+3 反击。",[ST("thorns",3)]),
 ("g_bulwark","铁壁",2,"skill","none","starter","获得 14 点格挡。",[B(14)]),
 # ---- 普通 18 ----
 ("g_hold","坚守",1,"skill","none","common","获得 8 点格挡。",[B(8)]),
 ("g_shieldwall","盾墙",2,"skill","none","common","获得 12 点格挡。",[B(12)]),
 ("g_heavy","重斩",2,"attack","enemy","common","造成 10 点伤害。",[D(10)]),
 ("g_sunder","破防",1,"skill","enemy","common","施加 2 层易伤。",[TG("vulnerable",2)]),
 ("g_warcry","战吼",1,"power","none","common","+2 力量。",[ST("strength",2)]),
 ("g_slam","盾牌猛击",2,"attack","enemy","common","造成等同于格挡的伤害，额外 +4。",[DBB(1,4)]),
 ("g_counter","格挡反击",1,"skill","none","common","获得 6 点格挡，+2 反击。",[B(6),ST("thorns",2)]),
 ("g_whet","磨砺",0,"skill","none","common","抽 1 张牌，+1 力量。",[DR(1),ST("strength",1)]),
 ("g_resolve","坚毅",1,"skill","none","common","获得 5 点格挡，抽 1 张牌。",[B(5),DR(1)]),
 ("g_charge","冲撞",1,"attack","enemy","common","造成 7 点伤害。",[D(7)]),
 ("g_armor","铁甲",1,"power","none","common","+2 壁垒（回合开始保留一半格挡）。",[ST("retain",2)]),
 ("g_brace","蓄势",0,"skill","none","common","获得 4 点格挡。",[B(4)]),
 ("g_cleave","削甲",1,"attack","enemy","common","造成 5 点伤害，施加 1 层易伤。",[D(5),TG("vulnerable",1)]),
 ("g_storm","反击风暴",2,"attack","enemy","common","造成 6 点伤害，+4 反击。",[D(6),ST("thorns",4)]),
 ("g_holdup","坚守阵地",2,"skill","none","common","获得 10 点格挡，抽 1 张牌。",[B(10),DR(1)]),
 ("g_oathbond","誓约",1,"power","none","common","+1 力量，+2 反击。",[ST("strength",1),ST("thorns",2)]),
 ("g_press","盾压",1,"attack","enemy","common","造成 6 点伤害，施加 1 层虚弱。",[D(6),TG("weak",1)]),
 ("g_copper","铜墙",2,"skill","none","common","获得 10 点格挡，回复 2 点生命。",[B(10),HL(2)]),
 # ---- 稀有 18 ----
 ("g_bulwarkcounter","铁壁反击",2,"skill","none","uncommon","获得 10 点格挡，+3 反击。",[B(10),ST("thorns",3)]),
 ("g_greatslam","盾击猛击",2,"attack","enemy","uncommon","造成等同于格挡的伤害，额外 +6。",[DBB(1,6)]),
 ("g_unbroken","不破",2,"power","none","uncommon","+1 壁垒。",[ST("retain",1)]),
 ("g_thornmail","荆棘之甲",2,"power","none","uncommon","+4 反击。",[ST("thorns",4)]),
 ("g_watch","守望",1,"skill","none","uncommon","获得 8 点格挡。",[B(8)]),
 ("g_armorbreak","破甲重击",2,"attack","enemy","uncommon","造成 8 点伤害，施加 2 层易伤。",[D(8),TG("vulnerable",2)]),
 ("g_ironwill","钢铁意志",1,"skill","none","uncommon","获得 6 点格挡，回复 3 点生命。",[B(6),HL(3)]),
 ("g_chain","反击链",1,"attack","enemy","uncommon","造成 4 点伤害，+2 反击。",[D(4),ST("thorns",2)]),
 ("g_crush","沉重打击",2,"attack","enemy","uncommon","造成 16 点伤害。",[D(16)]),
 ("g_fortress","堡垒",2,"skill","none","uncommon","获得 15 点格挡。",[B(15)]),
 ("g_shieldriposte","盾反",1,"skill","none","uncommon","获得 4 点格挡，+2 反击，抽 1 张牌。",[B(4),ST("thorns",2),DR(1)]),
 ("g_spirit","战意",1,"power","none","uncommon","+2 力量。",[ST("strength",2)]),
 ("g_immovable","坚不可摧",2,"skill","none","uncommon","获得 12 点格挡，+2 壁垒。",[B(12),ST("retain",2)]),
 ("g_aegis","圣盾",2,"skill","none","uncommon","获得 12 点格挡，+2 反击。",[B(12),ST("thorns",2)]),
 ("g_countermeasure","反制",1,"skill","enemy","uncommon","施加 1 层虚弱与 1 层易伤。",[TG("weak",1),TG("vulnerable",1)]),
 ("g_doubleslam","双盾击",2,"attack","enemy","uncommon","造成 8 点伤害，两次。",[D(8),D(8)]),
 ("g_ironblood","铁血",1,"power","none","uncommon","+3 力量。",[ST("strength",3)]),
 ("g_deathvow","誓死",2,"attack","enemy","uncommon","造成 12 点伤害，回复 4 点生命。",[D(12),HL(4)]),
 # ---- 史诗 9 ----
 ("g_mountain","不动如山",3,"skill","none","epic","获得 20 点格挡，+2 壁垒。",[B(20),ST("retain",2)]),
 ("g_thorncrown","荆棘王冠",2,"power","none","epic","+6 反击。",[ST("thorns",6)]),
 ("g_siege","破城",3,"attack","enemy","epic","造成 22 点伤害。",[D(22)]),
 ("g_ram","盾墙冲锋",2,"attack","enemy","epic","造成等同于格挡的伤害，两次。",[DBB(1,0,2)]),
 ("g_steel","钢铁壁垒",3,"skill","none","epic","获得 25 点格挡。",[B(25)]),
 ("g_ripostemaster","反击大师",2,"power","none","epic","+4 反击，+2 力量。",[ST("thorns",4),ST("strength",2)]),
 ("g_oathshield","誓约之盾",2,"skill","none","epic","获得 15 点格挡，回复 5 点生命。",[B(15),HL(5)]),
 ("g_giantslam","巨盾猛击",3,"attack","enemy","epic","造成等同于格挡的伤害，额外 +10。",[DBB(1,10)]),
 ("g_bloodwar","血战",2,"attack","enemy","epic","造成 10 点伤害，回复 5 点生命。",[D(10),HL(5)]),
 # ---- 传说 3 ----
 ("g_eternal","永誓",3,"power","none","legendary","+8 反击，+2 壁垒。",[ST("thorns",8),ST("retain",2)]),
 ("g_judgment","天罚",3,"attack","enemy","legendary","造成 32 点伤害。",[D(32)]),
 ("g_city","不动之城",3,"skill","none","legendary","获得 30 点格挡，+5 反击。",[B(30),ST("thorns",5)]),
]

p = "data/cards.json"
d = json.load(open(p), object_pairs_hook=collections.OrderedDict)
have = {c["id"] for c in d["cards"]}
added = 0
for cid, name, cost, typ, tgt, rar, desc, eff in CARDS:
    if cid in have:
        continue
    d["cards"].append(collections.OrderedDict([
        ("id", cid), ("name", name), ("cost", cost), ("type", typ), ("target", tgt),
        ("rarity", rar), ("class", "oathbound"), ("desc", desc), ("effects", eff),
    ]))
    added += 1
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
print(f"added {added}, total {len(d['cards'])}")

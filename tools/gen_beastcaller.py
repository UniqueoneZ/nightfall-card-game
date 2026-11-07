#!/usr/bin/env python3
import json, collections
D=lambda v:{"k":"damage","v":v}
DH=lambda v,h:{"k":"damage","v":v,"hits":h}
B=lambda v:{"k":"block","v":v}
BR=lambda v:{"k":"status","status":"mark","v":v}
SM=lambda v:{"k":"self_status","status":"beast","v":v}
ST=lambda s,v:{"k":"self_status","status":s,"v":v}
HL=lambda v:{"k":"heal","v":v}
DR=lambda v:{"k":"draw","v":v}

CARDS=[
 ("b_strike","兽击",1,"attack","enemy","starter","造成 6 点伤害。",[D(6)]),
 ("b_guard","护林",1,"skill","none","starter","获得 5 点格挡。",[B(5)]),
 ("b_wolf","唤狼",1,"skill","none","starter","召唤 1 只影狼（回合末造成 4 点伤害）。",[SM(1)]),
 ("b_mark","标记",1,"skill","enemy","starter","施加 3 层标记（受击时额外受伤）。",[BR(3)]),
 ("b_shot","射击",1,"attack","enemy","starter","造成 5 点伤害，施加 1 层标记。",[D(5),BR(1)]),
 ("b_pack","兽群",2,"skill","none","starter","召唤 2 只影狼。",[SM(2)]),

 ("b_trap","陷阱",1,"skill","enemy","common","施加 4 层标记。",[BR(4)]),
 ("b_arrow","穿甲箭",2,"attack","enemy","common","造成 10 点伤害，施加 2 层标记。",[D(10),BR(2)]),
 ("b_hawk","猎鹰",1,"skill","none","common","召唤 1 只猎鹰。",[SM(1)]),
 ("b_camp","营地",1,"skill","none","common","获得 6 点格挡，抽 1 张牌。",[B(6),DR(1)]),
 ("b_swarm","蜂群",2,"attack","enemy","common","造成 4 点伤害，三次。",[DH(4,3)]),
 ("b_tame","驯服",2,"skill","none","common","召唤 2 只影狼。",[SM(2)]),
 ("b_spear","长矛",1,"attack","enemy","common","造成 7 点伤害。",[D(7)]),
 ("b_heal","草药",1,"skill","none","common","回复 5 点生命，获得 3 点格挡。",[HL(5),B(3)]),
 ("b_snare","束缚",1,"skill","enemy","common","施加 2 层标记与 1 层虚弱。",[BR(2),{"k":"status","status":"weak","v":1}]),
 ("b_bear","巨熊",2,"skill","none","common","召唤 1 只巨熊。",[SM(1),B(6)]),
 ("b_volley","齐射",2,"attack","enemy","common","造成 8 点伤害，施加 2 层标记。",[D(8),BR(2)]),
 ("b_call","号角",1,"skill","none","common","召唤 1 只影狼，抽 1 张牌。",[SM(1),DR(1)]),

 ("b_packhunt","群猎",2,"attack","enemy","uncommon","造成 6 点伤害，两次，施加 2 层标记。",[DH(6,2),BR(2)]),
 ("b_alpha","首领",2,"skill","none","uncommon","召唤 2 只影狼，+1 力量。",[SM(2),ST("strength",1)]),
 ("b_skewer","穿刺",3,"attack","enemy","uncommon","造成 22 点伤害。",[D(22)]),
 ("b_beastcall","万兽奔腾",3,"skill","none","uncommon","召唤 3 只影狼。",[SM(3)]),
 ("b_hunter","猎人",2,"skill","none","uncommon","获得 12 点格挡，召唤 1 只影狼。",[B(12),SM(1)]),
 ("b_markbeast","血标",1,"attack","enemy","uncommon","造成 6 点伤害，施加 3 层标记。",[D(6),BR(3)]),
 ("b_ambush2","伏击",2,"attack","enemy","uncommon","造成 9 点伤害，若目标有标记则 +9。",[D(9),BR(2)]),
 ("b_nest","兽巢",2,"skill","none","uncommon","召唤 2 只影狼，回复 4 点生命。",[SM(2),HL(4)]),

 ("b_apex","顶点猎手",3,"attack","enemy","epic","造成 18 点伤害，施加 5 层标记。",[D(18),BR(5)]),
 ("b_stampede","兽潮",3,"skill","none","epic","召唤 4 只影狼。",[SM(4)]),
 ("b_bond","兽群羁绊",2,"power","none","epic","+2 力量，召唤 1 只影狼。",[ST("strength",2),SM(1)]),

 ("b_wild","荒野之主",3,"skill","none","legendary","召唤 5 只影狼，+2 力量。",[SM(5),ST("strength",2)]),
]

p="data/cards.json"
d=json.load(open(p), object_pairs_hook=collections.OrderedDict)
have={c["id"] for c in d["cards"]}
n=0
for cid,name,cost,typ,tgt,rar,desc,eff in CARDS:
    if cid in have: continue
    d["cards"].append(collections.OrderedDict([
        ("id",cid),("name",name),("cost",cost),("type",typ),("target",tgt),
        ("rarity",rar),("class","beastcaller"),("desc",desc),("effects",eff)]))
    n+=1
json.dump(d, open(p,"w"), ensure_ascii=False, indent=2)
print("added",n,"total",len(d["cards"]))

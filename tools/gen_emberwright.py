#!/usr/bin/env python3
"""烬术士职业卡表（30 张）。"""
import json, collections

D=lambda v:{"k":"damage","v":v}
DH=lambda v,h:{"k":"damage","v":v,"hits":h}
B=lambda v:{"k":"block","v":v}
BURN=lambda v:{"k":"status","status":"burn","v":v}
SD=lambda v:{"k":"self_damage","v":v}
ST=lambda s,v:{"k":"self_status","status":s,"v":v}
HL=lambda v:{"k":"heal","v":v}
DR=lambda v:{"k":"draw","v":v}
TH=lambda v:{"k":"self_status","status":"thorns","v":v}

CARDS=[
 ("e_ember","火种",1,"attack","enemy","starter","造成 6 点伤害，施加 1 层灼烧。",[D(6),BURN(1)]),
 ("e_cinder","灰烬",1,"skill","none","starter","获得 6 点格挡，抽 1 张牌。",[B(6),DR(1)]),
 ("e_kindling","引燃",1,"skill","enemy","starter","施加 3 层灼烧。",[BURN(3)]),
 ("e_sacrifice","献祭",0,"skill","none","starter","失去 3 点生命，+2 力量。",[SD(3),ST("strength",2)]),
 ("e_guard","余烬",1,"skill","none","starter","获得 5 点格挡。",[B(5)]),
 ("e_flare","爆燃",2,"attack","enemy","starter","造成 10 点伤害。",[D(10)]),

 ("e_scorch","灼烧",1,"attack","enemy","common","造成 5 点伤害，施加 2 层灼烧。",[D(5),BURN(2)]),
 ("e_fireball","火球",2,"attack","enemy","common","造成 12 点伤害。",[D(12)]),
 ("e_inferno","烈焰风暴",2,"attack","enemy","common","造成 8 点伤害，两次。",[DH(8,2)]),
 ("e_bloodrite","血祭",1,"skill","none","common","失去 4 点生命，获得 10 点格挡。",[SD(4),B(10)]),
 ("e_warmth","余温",1,"skill","none","common","回复 4 点生命，获得 3 点格挡。",[HL(4),B(3)]),
 ("e_blaze","炽焰",2,"attack","enemy","common","造成 9 点伤害，施加 3 层灼烧。",[D(9),BURN(3)]),
 ("e_ashwall","灰烬护盾",2,"skill","none","common","获得 10 点格挡。",[B(10)]),
 ("e_ignite","引火",0,"skill","enemy","common","施加 2 层灼烧。",[BURN(2)]),
 ("e_furnace","熔炉",1,"power","none","common","+2 力量。",[ST("strength",2)]),
 ("e_sparks","火星四溅",1,"attack","enemy","common","造成 4 点伤害，施加 2 层灼烧。",[D(4),BURN(2)]),
 ("e_combust","自燃",2,"attack","enemy","common","造成 14 点伤害，失去 5 点生命。",[D(14),SD(5)]),
 ("e_rekindle","复燃",2,"skill","none","common","回复 8 点生命。",[HL(8)]),
 ("e_ashveil","灰幕",1,"skill","none","common","获得 4 点格挡，抽 1 张牌。",[B(4),DR(1)]),
 ("e_soot","煤烟",1,"skill","enemy","common","施加 1 层虚弱与 1 层灼烧。",[{"k":"status","status":"weak","v":1},BURN(1)]),

 ("e_pyro","炎爆",3,"attack","enemy","uncommon","造成 22 点伤害。",[D(22)]),
 ("e_firewall","火墙",2,"skill","none","uncommon","获得 12 点格挡，+2 反击。",[B(12),TH(2)]),
 ("e_phoenix","凤凰",2,"skill","none","uncommon","回复 10 点生命，+2 力量。",[HL(10),ST("strength",2)]),
 ("e_emberheart","烬心",1,"power","none","uncommon","+3 力量。",[ST("strength",3)]),
 ("e_conflagration","焚城",2,"attack","enemy","uncommon","造成 6 点伤害，三次。",[DH(6,3)]),
 ("e_bloodflame","血焰",1,"attack","enemy","uncommon","造成 8 点伤害，失去 3 点生命。",[D(8),SD(3)]),
 ("e_ashfall","落灰",1,"skill","enemy","uncommon","施加 4 层灼烧。",[BURN(4)]),
 ("e_immolate","献身",3,"attack","enemy","uncommon","造成 18 点伤害，失去 8 点生命。",[D(18),SD(8)]),

 ("e_meteor","陨星",3,"attack","enemy","epic","造成 26 点伤害，施加 4 层灼烧。",[D(26),BURN(4)]),
 ("e_pyre","焚身",2,"power","none","epic","+4 力量，失去 6 点生命。",[ST("strength",4),SD(6)]),
 ("e_eternalflame","不灭之火",3,"skill","none","epic","获得 15 点格挡，+4 反击。",[B(15),TH(4)]),

 ("e_sun","烈日",3,"attack","enemy","legendary","造成 30 点伤害，施加 6 层灼烧。",[D(30),BURN(6)]),
]

p="data/cards.json"
d=json.load(open(p), object_pairs_hook=collections.OrderedDict)
have={c["id"] for c in d["cards"]}
n=0
for cid,name,cost,typ,tgt,rar,desc,eff in CARDS:
    if cid in have: continue
    d["cards"].append(collections.OrderedDict([
        ("id",cid),("name",name),("cost",cost),("type",typ),("target",tgt),
        ("rarity",rar),("class","emberwright"),("desc",desc),("effects",eff)]))
    n+=1
json.dump(d, open(p,"w"), ensure_ascii=False, indent=2)
print("added",n,"total",len(d["cards"]))

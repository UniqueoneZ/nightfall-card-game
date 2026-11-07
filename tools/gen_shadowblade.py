#!/usr/bin/env python3
import json, collections
D=lambda v:{"k":"damage","v":v}
DH=lambda v,h:{"k":"damage","v":v,"hits":h}
B=lambda v:{"k":"block","v":v}
PZ=lambda v:{"k":"status","status":"poison","v":v}
WK=lambda v:{"k":"status","status":"weak","v":v}
VU=lambda v:{"k":"status","status":"vulnerable","v":v}
CM=lambda v,per=2:{"k":"damage_combo","v":v,"per":per}
DR=lambda v:{"k":"draw","v":v}
ST=lambda s,v:{"k":"self_status","status":s,"v":v}
HL=lambda v:{"k":"heal","v":v}

CARDS=[
 ("s_dagger","匕首",1,"attack","enemy","starter","造成 6 点伤害。",[D(6)]),
 ("s_dodge","闪避",1,"skill","none","starter","获得 5 点格挡。",[B(5)]),
 ("s_venom","淬毒",1,"skill","enemy","starter","施加 3 层中毒。",[PZ(3)]),
 ("s_combo","连击",1,"attack","enemy","starter","造成 4 点伤害，本回合每出过一张攻击牌再 +2。",[CM(4,2)]),
 ("s_shadowstep","暗影步",1,"skill","none","starter","获得 4 点格挡，抽 1 张牌。",[B(4),DR(1)]),
 ("s_thrust","刺击",1,"attack","enemy","starter","造成 7 点伤害。",[D(7)]),

 ("s_double","双刃",1,"attack","enemy","common","造成 3 点伤害，两次。",[DH(3,2)]),
 ("s_poisonblade","毒刃",1,"attack","enemy","common","造成 5 点伤害，施加 2 层中毒。",[D(5),PZ(2)]),
 ("s_quick","快斩",0,"attack","enemy","common","造成 4 点伤害。",[D(4)]),
 ("s_backstab","背刺",1,"attack","enemy","common","造成 5 点伤害，若目标有易伤则 +5。",[D(5),VU(1)]),
 ("s_smoke","烟雾",1,"skill","none","common","获得 6 点格挡，施加 1 层虚弱。",[B(6),WK(1)]),
 ("s_poisoncloud","毒雾",2,"skill","enemy","common","施加 4 层中毒。",[PZ(4)]),
 ("s_slash","割喉",1,"attack","enemy","common","造成 6 点伤害，本回合每出过一张攻击牌再 +2。",[CM(6,2)]),
 ("s_light","轻步",0,"skill","none","common","抽 1 张牌。",[DR(1)]),
 ("s_venomdart","毒镖",1,"attack","enemy","common","造成 4 点伤害，施加 2 层中毒。",[D(4),PZ(2)]),
 ("s_chain","连环斩",2,"attack","enemy","common","造成 5 点伤害，两次，本回合每出过一张攻击牌再 +2。",[CM(5,2),CM(5,2)]),
 ("s_shadow","隐匿",2,"skill","none","common","获得 10 点格挡。",[B(10)]),
 ("s_bite","蛇咬",1,"attack","enemy","common","造成 5 点伤害，施加 3 层中毒。",[D(5),PZ(3)]),
 ("s_focus","专注",1,"skill","none","common","抽 2 张牌。",[DR(2)]),
 ("s_mark","标记",0,"skill","enemy","common","施加 2 层易伤。",[VU(2)]),

 ("s_thousand","千刃",2,"attack","enemy","uncommon","造成 4 点伤害，三次。",[DH(4,3)]),
 ("s_deadlypoison","剧毒",2,"skill","enemy","uncommon","施加 6 层中毒。",[PZ(6)]),
 ("s_clone","影分身",2,"skill","none","uncommon","获得 12 点格挡，抽 1 张牌。",[B(12),DR(1)]),
 ("s_ambush","偷袭",2,"attack","enemy","uncommon","造成 8 点伤害，本回合每出过一张攻击牌再 +3。",[CM(8,3)]),
 ("s_toxicburst","毒爆",2,"attack","enemy","uncommon","造成 8 点伤害，施加 3 层中毒。",[D(8),PZ(3)]),
 ("s_gale","疾风连斩",1,"attack","enemy","uncommon","造成 3 点伤害，三次。",[DH(3,3)]),
 ("s_assassinate","暗杀",3,"attack","enemy","uncommon","造成 20 点伤害。",[D(20)]),
 ("s_snakebite","毒牙",1,"attack","enemy","uncommon","造成 6 点伤害，本回合每出过一张攻击牌再 +2，施加 1 层中毒。",[CM(6,2),PZ(1)]),

 ("s_myriad","万刃归一",3,"attack","enemy","epic","造成 6 点伤害，四次。",[DH(6,4)]),
 ("s_lethal","致命毒",2,"skill","enemy","epic","施加 8 层中毒。",[PZ(8)]),
 ("s_dance","影之舞",2,"skill","none","epic","获得 15 点格挡，抽 2 张牌。",[B(15),DR(2)]),

 ("s_death","影杀",3,"attack","enemy","legendary","造成 10 点伤害，本回合每出过一张攻击牌再 +4。",[CM(10,4)]),
]

p="data/cards.json"
d=json.load(open(p), object_pairs_hook=collections.OrderedDict)
have={c["id"] for c in d["cards"]}
n=0
for cid,name,cost,typ,tgt,rar,desc,eff in CARDS:
    if cid in have: continue
    d["cards"].append(collections.OrderedDict([
        ("id",cid),("name",name),("cost",cost),("type",typ),("target",tgt),
        ("rarity",rar),("class","shadowblade"),("desc",desc),("effects",eff)]))
    n+=1
json.dump(d, open(p,"w"), ensure_ascii=False, indent=2)
print("added",n,"total",len(d["cards"]))

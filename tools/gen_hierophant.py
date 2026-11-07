#!/usr/bin/env python3
import json, collections
D=lambda v:{"k":"damage","v":v}
DH=lambda v,h:{"k":"damage","v":v,"hits":h}
B=lambda v:{"k":"block","v":v}
HL=lambda v:{"k":"heal","v":v}
SEAL=lambda v:{"k":"self_status","status":"seal","v":v}
OVF=lambda v:{"k":"self_status","status":"overflow","v":v}
ST=lambda s,v:{"k":"self_status","status":s,"v":v}
TG=lambda s,v:{"k":"status","status":s,"v":v}
DR=lambda v:{"k":"draw","v":v}

CARDS=[
 ("h_light","圣光",1,"attack","enemy","starter","造成 6 点伤害。",[D(6)]),
 ("h_prayer","祷言",1,"skill","none","starter","获得 5 点格挡。",[B(5)]),
 ("h_seal","圣印",1,"power","none","starter","+1 圣印（回合结束造成 4 点伤害）。",[SEAL(1)]),
 ("h_mend","治疗",1,"skill","none","starter","回复 6 点生命。",[HL(6)]),
 ("h_shelter","庇护",1,"skill","none","starter","获得 4 点格挡，回复 2 点生命。",[B(4),HL(2)]),
 ("h_smite","圣锤",1,"attack","enemy","starter","造成 5 点伤害，获得 3 点格挡。",[D(5),B(3)]),

 ("h_overflow","溢流",1,"power","none","common","获得溢流：过量治疗转化为格挡。",[OVF(1)]),
 ("h_bless","祝福",1,"skill","none","common","获得 8 点格挡。",[B(8)]),
 ("h_holybolt","圣光弹",2,"attack","enemy","common","造成 10 点伤害。",[D(10)]),
 ("h_purify","净化",1,"skill","none","common","回复 5 点生命，获得 4 点格挡。",[HL(5),B(4)]),
 ("h_chant","咏唱",1,"power","none","common","+2 圣印。",[SEAL(2)]),
 ("h_guardian","守护",2,"skill","none","common","获得 12 点格挡。",[B(12)]),
 ("h_penance","忏悔",1,"attack","enemy","common","造成 5 点伤害，施加 1 层易伤。",[D(5),TG("vulnerable",1)]),
 ("h_grace","恩典",2,"skill","none","common","回复 10 点生命。",[HL(10)]),
 ("h_radiance","辉光",2,"attack","enemy","common","造成 8 点伤害，+1 圣印。",[D(8),SEAL(1)]),
 ("h_shield_faith","信仰之盾",1,"skill","none","common","获得 6 点格挡，抽 1 张牌。",[B(6),DR(1)]),
 ("h_judge","裁决",2,"attack","enemy","common","造成 12 点伤害，但失去 4 点生命。",[D(12),{"k":"self_damage","v":4}]),
 ("h_sanctuary","圣所",2,"skill","none","common","获得 10 点格挡，回复 3 点生命。",[B(10),HL(3)]),

 ("h_dawn","黎明",2,"skill","none","uncommon","回复 12 点生命，+1 圣印。",[HL(12),SEAL(1)]),
 ("h_judgement","审判",3,"attack","enemy","uncommon","造成 20 点伤害。",[D(20)]),
 ("h_halo","光环",2,"power","none","uncommon","+3 圣印。",[SEAL(3)]),
 ("h_renew","复苏",2,"skill","none","uncommon","回复 15 点生命，抽 1 张牌。",[HL(15),DR(1)]),
 ("h_bastion","壁垒",2,"skill","none","uncommon","获得 14 点格挡，+1 溢流。",[B(14),OVF(1)]),
 ("h_lance","圣枪",2,"attack","enemy","uncommon","造成 8 点伤害，两次。",[DH(8,2)]),
 ("h_seraph","炽天使",3,"skill","none","uncommon","回复 18 点生命，+2 圣印。",[HL(18),SEAL(2)]),
 ("h_verdict","终审",2,"attack","enemy","uncommon","造成 10 点伤害，+2 圣印。",[D(10),SEAL(2)]),

 ("h_miracle","神迹",3,"skill","none","epic","回复 25 点生命，+2 溢流。",[HL(25),OVF(2)]),
 ("h_pillar","光柱",3,"attack","enemy","epic","造成 24 点伤害，+2 圣印。",[D(24),SEAL(2)]),
 ("h_covenant","圣约",2,"power","none","epic","+4 圣印。",[SEAL(4)]),

 ("h_apotheosis","升华",3,"skill","none","legendary","回复 30 点生命，+4 圣印，抽 2 张牌。",[HL(30),SEAL(4),DR(2)]),
]

p="data/cards.json"
d=json.load(open(p), object_pairs_hook=collections.OrderedDict)
have={c["id"] for c in d["cards"]}
n=0
for cid,name,cost,typ,tgt,rar,desc,eff in CARDS:
    if cid in have: continue
    d["cards"].append(collections.OrderedDict([
        ("id",cid),("name",name),("cost",cost),("type",typ),("target",tgt),
        ("rarity",rar),("class","hierophant"),("desc",desc),("effects",eff)]))
    n+=1
json.dump(d, open(p,"w"), ensure_ascii=False, indent=2)
print("added",n,"total",len(d["cards"]))

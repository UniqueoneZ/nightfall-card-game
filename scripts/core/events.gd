class_name Events
extends RefCounted
## 随机事件表：每条事件 2–3 个选项，选项用效果字典描述。

const LIST := [
	{"title": "破旧的旅行箱", "text": "箱扣已经锈死，里面传出金属碰撞的声音。",
	 "choices": [
		{"label": "撬开（+40 金币）", "fx": {"gold": 40}},
		{"label": "小心检查（+20 生命）", "fx": {"heal": 20}},
	 ]},
	{"title": "无名祭坛", "text": "石面上刻着看不懂的字，凹槽里还残留着暗红。",
	 "choices": [
		{"label": "献上鲜血（-10 生命，得一张稀有卡）", "fx": {"damage": 10, "card": "rare"}},
		{"label": "转身离开", "fx": {}},
	 ]},
	{"title": "枯骨", "text": "一具枯骨靠在墙边，手里还攥着什么东西。",
	 "choices": [
		{"label": "取走遗物（+25 金币）", "fx": {"gold": 25}},
		{"label": "就地掩埋（+15 生命）", "fx": {"heal": 15}},
	 ]},
	{"title": "商队残骸", "text": "货车翻倒在路边，货物散了一地，还有半瓶酒。",
	 "choices": [
		{"label": "搜刮货物（+50 金币，-10 生命）", "fx": {"gold": 50, "damage": 10}},
		{"label": "只拿走药瓶（+30 生命）", "fx": {"heal": 30}},
	 ]},
	{"title": "古井", "text": "井水深不见底，倒映出的却不是你的脸。",
	 "choices": [
		{"label": "饮下井水（+15 生命）", "fx": {"heal": 15}},
		{"label": "打捞井底（+35 金币）", "fx": {"gold": 35}},
	 ]},
	{"title": "断剑", "text": "一把断剑插在石缝里，剑身还在微微发烫。",
	 "choices": [
		{"label": "用它磨砺卡牌（升级一张卡）", "fx": {"upgrade": true}},
		{"label": "熔掉换钱（+30 金币）", "fx": {"gold": 30}},
	 ]},
	{"title": "游荡的幽魂", "text": "它没有脸，却一直在向你伸手。",
	 "choices": [
		{"label": "给它一枚金币（-8 生命，+40 金币）", "fx": {"damage": 8, "gold": 40}},
		{"label": "驱散它（+10 生命）", "fx": {"heal": 10}},
	 ]},
	{"title": "篝火余烬", "text": "有人在这里休息过，火还没完全熄灭。",
	 "choices": [
		{"label": "烤火（+18 生命）", "fx": {"heal": 18}},
	 ]},
	{"title": "赌徒的骰子", "text": "桌上摆着三颗骰子，旁边压着一张字条：「愿赌服输」。",
	 "choices": [
		{"label": "押上 20 金币（50% 得 60）", "fx": {"gamble": 20}},
		{"label": "不赌", "fx": {}},
	 ]},
	{"title": "倒塌的钟楼", "text": "铜钟摔成了两半，钟腹里似乎卡着什么。",
	 "choices": [
		{"label": "撬开钟腹（+30 金币）", "fx": {"gold": 30}},
		{"label": "搬开碎石（-12 生命，+50 金币）", "fx": {"damage": 12, "gold": 50}},
	 ]},
	{"title": "蛇窟", "text": "洞口的石头上刻着：「进者自担」。",
	 "choices": [
		{"label": "摸进去（-15 生命，得一张稀有卡）", "fx": {"damage": 15, "card": "rare"}},
		{"label": "绕路（+20 生命）", "fx": {"heal": 20}},
	 ]},
	{"title": "废弃营地", "text": "营火早就冷了，帐篷里还留着一张毯子。",
	 "choices": [
		{"label": "睡一觉（+25 生命）", "fx": {"heal": 25}},
		{"label": "翻找行囊（+45 金币）", "fx": {"gold": 45}},
	 ]},
	{"title": "血池", "text": "池水是暗红色的，倒影里你看见自己举起了一把断剑。",
	 "choices": [
		{"label": "浸入断剑（-20 生命，升级一张卡）", "fx": {"damage": 20, "upgrade": true}},
		{"label": "退开", "fx": {}},
	 ]},
	{"title": "流浪商人", "text": "他戴着兜帽，摊位上只有一张卡。",
	 "choices": [
		{"label": "买下（-60 金币，得一张稀有卡）", "fx": {"gold": -60, "card": "rare"}},
		{"label": "谢绝", "fx": {}},
	 ]},
	{"title": "倒吊的钟", "text": "钟舌上缠着布条，写着你的名字。",
	 "choices": [
		{"label": "扯下布条（+30 金币，-8 生命）", "fx": {"gold": 30, "damage": 8}},
		{"label": "敲响它（+15 生命）", "fx": {"heal": 15}},
	 ]},
	{"title": "旧书", "text": "书页已经脆了，但还能看清几行字。",
	 "choices": [
		{"label": "研读（得一张稀有卡）", "fx": {"card": "rare"}},
		{"label": "当柴烧（+12 生命）", "fx": {"heal": 12}},
	 ]},
]

static func pick(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return LIST[rng.randi_range(0, LIST.size() - 1)]

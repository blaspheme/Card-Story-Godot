class_name GameEnums

#region Test类枚举
enum ReqOp {
	MoreOrEqual = 0,
	Equal = 1,
	LessOrEqual = 2,
	More = 3,
	NotEqual = 4,
	Less = 5,
	Mod = 6,
	RandomChallenge = 10,
	RandomClash = 20,
}

enum ReqLoc {
	Scope = 0,
	MatchedCards = 1 << 5,
	Slots = 1 << 2,
	Table = 1 << 4,
	Heap = 1 << 3,
	Free = 1 << 7,
	Anywhere = 1 << 6,
}
#endregion

#region Modifier 枚举
enum CardOp {
	FragmentAdditive = 0,
	FragmentSet = 5,
	Transform = 10,
	Decay = 100,
	SetMemory = 140,
	MoveToHeap = 170,
	MoveFromHeap = 171,
	Slot = 160,
	Spread = 150,
}

enum ActOp {
	Adjust = 0,
	Grab = 20,
	Expulse = 30,
	SetMemory = 40,
	RunTriggers = 50,
}

enum PathOp {
	BranchOut = 0,
	InjectNextAct = 10,
	InjectAltAct = 11,
	ForceAct = 20,
	SetCallback = 40,
	Callback = 41,
	GameOver = 80,
}

enum DeckOp {
	Draw = 0,
	DrawNext = 10,
	DrawPrevious = 20,
	Add = 50,
	AddFront = 51,
	ForwardShift = 100
}

enum TableOp {
	SpawnAct = 0,
	SpawnToken = 10
}
#endregion

#region Act 状态枚举
enum ActStatus {
	IDLE = 0,
	READY = 1,
	RUNNING = 2,
	FINISHED = 3,
}
#endregion

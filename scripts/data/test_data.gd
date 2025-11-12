class_name TestData
extends Resource

#region 属性定义
@export var card_test : bool
@export var can_fail : bool
@export var loc1 : GameEnums.ReqLoc = GameEnums.ReqLoc.Scope
@export var fragment1 : FragmentData
@export var op : GameEnums.ReqOp
@export var constant : int
@export var loc2 : GameEnums.ReqLoc = GameEnums.ReqLoc.Scope
@export var fragment2 : FragmentData
#endregion

#region 公开方法
func attempt(context: Context) -> bool:
	var right: int
	var fragment1r = context.resolve_fragment(fragment1) if context != null else null
	var fragment2r = context.resolve_fragment(fragment2) if context != null else null

	if fragment2r == null:
		right = int(constant)
	else:
		right = int(constant) * get_count(context, loc2, fragment2r)

	if card_test:
		var scope = context.resolve_scope(loc1)
		var cards = context.matches if loc1 == GameEnums.ReqLoc.MatchedCards else scope.cards

		var passed: bool = false
		if fragment1r == null:
			if right > 0:
				right = min(right, context.matches.size())
				passed = true
				# 截断 matches 到前 right 项
				var new_matches: Array = []
				for i in range(min(right, context.matches.size())):
					new_matches.append(context.matches[i])
				context.matches = new_matches
		else:
			var new_matches: Array = []

			# Aspect 分支
			if fragment1r is AspectData:
				var aspect = fragment1r
				for card_viz in cards:
					var left = 0
					if card_viz.frag_tree and card_viz.frag_tree.has_method("count"):
						left = card_viz.frag_tree.count(aspect)
					var result = compare(op, constant, left, right)
					if result and (loc1 != GameEnums.ReqLoc.Free or card_viz.free):
						new_matches.append(card_viz)
						passed = true
			# Card 分支
			elif fragment1r is CardData:
				var card = fragment1r
				for card_viz in cards:
					var result = (card_viz.card == card)
					if result and (loc1 != GameEnums.ReqLoc.Free or card_viz.free):
						new_matches.append(card_viz)
				var left = new_matches.size()
				passed = compare(op, constant, left, right)

			# 替换 context.matches
			context.matches.clear()
			for item in new_matches:
				context.matches.append(item)

		return passed
	else:
		var left = get_count(context, loc1, fragment1r)
		return compare(op, constant, left, right)
#endregion

#region 静态方法

static func compare(req_op: GameEnums.ReqOp, constant: int, left: int, right: int) -> bool:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	match req_op:
		GameEnums.ReqOp.Equal:
			return left == right
		GameEnums.ReqOp.NotEqual:
			return left != right
		GameEnums.ReqOp.Less:
			return left < right
		GameEnums.ReqOp.LessOrEqual:
			return left <= right
		GameEnums.ReqOp.More:
			return left > right
		GameEnums.ReqOp.MoreOrEqual:
			return left >= right
		GameEnums.ReqOp.Mod:
			if right == 0:
				return false
			return left % right == 0
		GameEnums.ReqOp.RandomChallenge:
			return constant * left > rng.randi_range(0, 99)
		GameEnums.ReqOp.RandomClash:
			var div = float(left + right)
			if div > 0.0:
				var chance = float(left) / div
				return chance > rng.randf()
			else:
				return false
		_:
			return false

static func get_count(context: Context, loc: GameEnums.ReqLoc, fragment: FragmentData) -> int:
	var total: int = 0

	if loc == GameEnums.ReqLoc.MatchedCards:
		var cards: Array[CardViz] = context.matches
		if fragment == null:
			total = cards.size()
		elif fragment is AspectData:
			for card in cards:
				var ha = null
				ha = card.frag_tree.find_fragment_by_aspect(fragment)
				if ha != null:
					total += int(ha.count)
		elif fragment is CardData:
			for card in cards:
				if card.card_data == fragment:
					total += 1
	else:
		var scope = context.resolve_scope(loc)
		if fragment != null:
			total = int(scope.count_fragment(fragment, loc == GameEnums.ReqLoc.Free))
		else:
			# TODO: 
			total = 0

	return total
#endregion

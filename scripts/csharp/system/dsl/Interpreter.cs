using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using Godot;

namespace CardStory.scripts.csharp.system.dsl
{
	public record DslContext(string TokenId, string ActId, string Stage);

	public enum FlowControl
	{
		None,
		Return,
		Break,
		Continue
	}

	public class Interpreter
	{
		// 这里将来会注入游戏系统的引用，例如 State, Executor, Resolver
		// 目前先定义一个抽象层或者直接在 Runtime 中处理这些依赖

		public (object? Result, FlowControl Flow) ExecuteBlock(IEnumerable<AstStatement> block, DslContext context)
		{
			foreach (var stmt in block)
			{
				var (res, flow) = ExecuteStatement(stmt, context);
				if (flow != FlowControl.None)
				{
					return (res, flow);
				}
			}
			return (null, FlowControl.None);
		}

		public (object? Result, FlowControl Flow) ExecuteStatement(AstStatement stmt, DslContext context)
		{
			switch (stmt)
			{
				case AstIf ifStat:
					if (AsBool(EvaluateExpression(ifStat.Condition, context)))
					{
						return ExecuteBlock(ifStat.ThenBlock, context);
					}
					else if (ifStat.ElseBlock != null)
					{
						return ExecuteBlock(ifStat.ElseBlock, context);
					}
					break;

				case AstWhile whileStat:
					while (AsBool(EvaluateExpression(whileStat.Condition, context)))
					{
						var (res, flow) = ExecuteBlock(whileStat.Body, context);
						if (flow == FlowControl.Break) break;
						if (flow == FlowControl.Return) return (res, FlowControl.Return);
						// Continue 就继续循环
					}
					break;

				case AstEffect effectStat:
					ExecuteEffectChain(effectStat.Chain, context);
					break;

				case AstReturn returnStat:
					return (returnStat.Value != null ? EvaluateExpression(returnStat.Value, context) : null, FlowControl.Return);

				case AstBreak:
					return (null, FlowControl.Break);

				case AstContinue:
					return (null, FlowControl.Continue);
			}

			return (null, FlowControl.None);
		}

		public object? EvaluateExpression(AstExpression exp, DslContext context)
		{
			switch (exp)
			{
				case AstLiteral literal:
					return literal.Value;

				case AstBinaryOp binOp:
					var left = EvaluateExpression(binOp.Left, context);
					var right = EvaluateExpression(binOp.Right, context);
					return EvaluateBinaryOp(binOp.Op, left, right);

				case AstUnaryOp unOp:
					var r = EvaluateExpression(unOp.Right, context);
					if (unOp.Op == "NOT") return !AsBool(r);
					break;

				case AstCall call:
					return CallFunction(call.Func, call.Args, context);

				case AstTable table:
					// 返回一个键值对字典
					return table.Fields.ToDictionary(kvp => kvp.Key, kvp => EvaluateExpression(kvp.Value, context));
			}
			return null;
		}

		private object? EvaluateBinaryOp(string op, object? left, object? right)
		{
			switch (op)
			{
				case "AND": return AsBool(left) && AsBool(right);
				case "OR": return AsBool(left) || AsBool(right);
				case "==": return Equals(left, right);
				case "~=": return !Equals(left, right);
				case ">": return AsDouble(left) > AsDouble(right);
				case "<": return AsDouble(left) < AsDouble(right);
				case ">=": return AsDouble(left) >= AsDouble(right);
				case "<=": return AsDouble(left) <= AsDouble(right);
				case "=": return Equals(left, right); // DSL 中 = 有时也用作相等
				default: return null;
			}
		}

		private void ExecuteEffectChain(IEnumerable<AstCall> chain, DslContext context)
		{
			foreach (var call in chain)
			{
				CallFunction(call.Func, call.Args, context);
			}
		}

		private object? CallFunction(string name, IEnumerable<AstExpression> args, DslContext context)
		{
			var evalArgs = args.Select(a => EvaluateExpression(a, context)).ToList();

			// TODO: 集成真正的游戏逻辑
			GD.Print($"DSL: Calling {name} with {evalArgs.Count} args");
			
			// 这里根据 dsl_interpreter.lua 中的函数列表进行映射
			switch (name)
			{
				case "has_card": return false; // 占位
				case "slot_is_empty": return true; // 占位
				case "random": return GD.Randf() * 100 <= AsDouble(evalArgs.FirstOrDefault());
				// ... 其他函数
			}

			return null;
		}

		private bool AsBool(object? val)
		{
			if (val is bool b) return b;
			if (val == null) return false;
			return true;
		}

		private double AsDouble(object? val)
		{
			if (val is double d) return d;
			if (val is float f) return f;
			if (val is int i) return i;
			if (val is decimal dec) return (double)dec;
			return 0;
		}
	}
}

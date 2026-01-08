#nullable enable
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using Pidgin;
using static Pidgin.Parser;

namespace CardStory.scripts.csharp.system.dsl
{
	#region AST Nodes

	public abstract record AstNode;

	public record AstScript(ImmutableDictionary<string, ImmutableList<AstStatement>> Blocks) : AstNode;

	public abstract record AstStatement : AstNode;

	public record AstIf(AstExpression Condition, ImmutableList<AstStatement> ThenBlock, ImmutableList<AstStatement>? ElseBlock) : AstStatement;

	public record AstWhile(AstExpression Condition, ImmutableList<AstStatement> Body) : AstStatement;

	public record AstEffect(ImmutableList<AstCall> Chain) : AstStatement;

	public record AstReturn(AstExpression? Value) : AstStatement;

	public record AstBreak() : AstStatement;

	public record AstContinue() : AstStatement;

	public abstract record AstExpression : AstNode;

	public record AstBinaryOp(string Op, AstExpression Left, AstExpression Right) : AstExpression;

	public record AstUnaryOp(string Op, AstExpression Right) : AstExpression;

	public record AstLiteral(object? Value) : AstExpression;

	public record AstTable(ImmutableDictionary<string, AstExpression> Fields) : AstExpression;

	public record AstCall(string Func, ImmutableList<AstExpression> Args) : AstExpression;

	#endregion

	public static class DslParser
	{
		private static Parser<char, T> Token<T>(Parser<char, T> p) => p.Before(SkipWhitespaces);
		private static Parser<char, string> Keyword(string s) => Token(String(s));
		private static Parser<char, char> Symbol(char c) => Token(Char(c));

		private static readonly Parser<char, string> Identifier = Token(
			Map((first, rest) => first + rest,
				LetterOrDigit.Or(Char('_')),
				LetterOrDigit.Or(Char('_')).ManyString()
			)
		);

		private static readonly Parser<char, string> StringLiteral = Token(
			Char('\"')
				.Then(AnyCharExcept('\"').ManyString())
				.Before(Char('\"'))
		);

		private static readonly Parser<char, double> NumberLiteral = Token(
			Real.Select(d => d)
		);

		private static readonly Parser<char, AstExpression> Expression = Rec(() => OrExp);

		private static readonly Parser<char, AstCall> FunctionCall =
			Identifier.Before(Symbol('('))
				.Then(Expression.Separated(Symbol(',')), (name, args) => new AstCall(name, args.ToImmutableList()))
				.Before(Symbol(')'));

		private static readonly Parser<char, AstExpression> Value =
			OneOf(
				FunctionCall.Cast<AstExpression>(),
				StringLiteral.Select(s => new AstLiteral(s)).Cast<AstExpression>(),
				NumberLiteral.Select(n => new AstLiteral(n)).Cast<AstExpression>(),
				Keyword("true").Select(_ => new AstLiteral(true)).Cast<AstExpression>(),
				Keyword("false").Select(_ => new AstLiteral(false)).Cast<AstExpression>(),
				Rec(() => Table).Cast<AstExpression>()
			);

		private static readonly Parser<char, AstExpression> Table =
			Symbol('{')
				.Then(
					Identifier.Before(Symbol(':'))
						.Then(Value, (k, v) => new KeyValuePair<string, AstExpression>(k, v))
						.Separated(Symbol(','))
				)
				.Before(Symbol('}'))
				.Select(pairs => new AstTable(pairs.ToImmutableDictionary()) as AstExpression);

		private static readonly Parser<char, AstExpression> Term =
			OneOf(
				Keyword("NOT").Then(Value).Select(e => new AstUnaryOp("NOT", e)).Cast<AstExpression>(),
				Symbol('(').Then(Expression).Before(Symbol(')')),
				Value
			);

		private static readonly Parser<char, AstExpression> CompExp =
			Binary(
				OneOf(
					Try(Keyword(">=")), Try(Keyword("<=")), Try(Keyword("==")), 
					Try(Keyword("~=")), Symbol('>').Select(c => c.ToString()), 
					Symbol('<').Select(c => c.ToString()), Symbol('=').Select(c => c.ToString())
				),
				Term,
				Term
			);

		private static readonly Parser<char, AstExpression> AndExp =
			Binary(Keyword("AND"), CompExp, CompExp);

		private static readonly Parser<char, AstExpression> OrExp =
			Binary(Keyword("OR"), AndExp, AndExp);

		private static Parser<char, AstExpression> Binary(Parser<char, string> op, Parser<char, AstExpression> leftParser, Parser<char, AstExpression> rightParser) =>
			leftParser.Then(
				op.Then(rightParser, (o, r) => (o, r)).Many(),
				(l, rest) => rest.Aggregate(l, (acc, next) => new AstBinaryOp(next.o, acc, next.r))
			);

		private static readonly Parser<char, ImmutableList<AstStatement>> Statements = Rec(() => Statement).Many().Select(s => s.ToImmutableList());

		private static readonly Parser<char, AstStatement> IfStat =
			Keyword("IF").Then(Expression).Before(Keyword("THEN"))
				.Then(Statements, (cond, then) => (cond, then))
				.Then(Keyword("ELSE").Then(Statements).Optional(), (pair, @else) => new AstIf(pair.cond, pair.then, @else.GetValueOrDefault()) as AstStatement)
				.Before(Keyword("END"));

		private static readonly Parser<char, AstStatement> WhileStat =
			Keyword("WHILE").Then(Expression).Before(Keyword("THEN"))
				.Then(Statements, (cond, body) => new AstWhile(cond, body) as AstStatement)
				.Before(Keyword("END"));

		private static readonly Parser<char, AstStatement> EffectStat =
			Keyword("EFFECT").Then(FunctionCall.SeparatedAtLeastOnce(Keyword("->")))
				.Select(calls => new AstEffect(calls.ToImmutableList()) as AstStatement);

		private static readonly Parser<char, AstStatement> ReturnStat =
			Keyword("RETURN").Then(Expression.Optional())
				.Select(val => new AstReturn(val.GetValueOrDefault()) as AstStatement);

		private static readonly Parser<char, AstStatement> BreakStat =
			Keyword("BREAK").Select(_ => new AstBreak() as AstStatement);

		private static readonly Parser<char, AstStatement> ContinueStat =
			Keyword("CONTINUE").Select(_ => new AstContinue() as AstStatement);

		private static readonly Parser<char, AstStatement> Statement =
			OneOf(Try(IfStat), Try(WhileStat), Try(EffectStat), Try(ReturnStat), Try(BreakStat), Try(ContinueStat));

		private static readonly Parser<char, KeyValuePair<string, ImmutableList<AstStatement>>> Block =
			Identifier.Before(Symbol('{'))
				.Then(Statements, (name, stmts) => new KeyValuePair<string, ImmutableList<AstStatement>>(name, stmts))
				.Before(Symbol('}'));

		public static readonly Parser<char, AstScript> Script =
			SkipWhitespaces.Then(Symbol('{'))
				.Then(Block.Many())
				.Before(Symbol('}'))
				.Select(blocks => new AstScript(blocks.ToImmutableDictionary()));

		public static AstScript Parse(string input)
		{
			return Script.ParseOrThrow(input);
		}
	}
}

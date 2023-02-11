import Foundation

public protocol Parser {
	/// Parses a filter from the grammar.
	/// This expects the entire input string to be parsed, and will fail if no
	/// EOF is encountered at the end.
	func parseFilter() throws -> FilterExpression
	
	/// Parses a path from the grammar.
	/// This expects the entire input string to be parsed, and will fail if no
	/// EOF is encountered at the end.
	func parsePath() throws -> PathExpression
}

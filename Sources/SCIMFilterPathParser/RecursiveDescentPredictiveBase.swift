import Foundation

// TODO: Detect and error upon ATTRNAME.subAttr[valFilter]

// Uses SCIM_RFC_7644_LeftRecursionEliminatedV2.abnf

/// Base implementation of a predictive recursive-descent parser. Contains
/// shared methods to predictively parse various simple and common grammar
/// symbols.
///
/// See RecursiveDescentPredictiveParser and RecursiveDescentBacktracingParser
/// for full parser implementations that use this as a base for shared
/// functionality.
public class RecursiveDescentPredictiveBase {
	
	let lexer: Lexer
	var currentTokenIndex: String.Index
	var currentToken: Token
	
	init(filter: String) throws {
		lexer = Lexer(inputString: filter)
		
		currentTokenIndex = lexer.index
		currentToken = try lexer.next()
	}
}

// Error handling
extension RecursiveDescentPredictiveBase {
	struct ParserError: Error {
		let message: String
	}
}

// Internal helper methods
extension RecursiveDescentPredictiveBase {
	func consumeCurrentToken() throws {
		currentTokenIndex = lexer.index
		currentToken = try lexer.next()
	}
	
	func expect(token: Token) throws {
		guard currentToken == token else {
			throw ParserError(message: "Expected a \(token) at \(currentTokenIndex), but instead found a \(currentToken)")
		}
		try consumeCurrentToken()
	}
	
	func attempt(token: Token) throws -> Bool {
		if currentToken == token {
			try consumeCurrentToken()
			return true
		} else {
			return false
		}
	}
	
	/// Parses an `"and" / "or"` as a helper method. This is not a symbol in the
	/// grammar.
	///
	/// Type: Predictive
	func parseLogicalOperator() throws -> LogicalOperator {
		switch currentToken {
		case .keywordIdentifier(.and):
			try consumeCurrentToken()
			return .and
		case .keywordIdentifier(.or):
			try consumeCurrentToken()
			return .or
		default:
			throw ParserError(message: "Expected a logical operator at \(currentTokenIndex), but found a \(currentToken) instead.")
		}
	}
}

// Internal node parsers
extension RecursiveDescentPredictiveBase {
	
	/// Parses a comparative value from the grammar.
	///
	/// Symbol: `compValue`
	/// Type: Predictive
	func parseComparativeValue() throws -> ComparativeValue {
		switch currentToken {
		case let .keywordIdentifier(keyword):
			switch keyword {
			case .false:
				try consumeCurrentToken()
				return .false
			case .null:
				try consumeCurrentToken()
				return .null
			case .true:
				try consumeCurrentToken()
				return .true
			default:
				throw ParserError(message: "Expected a comparative value (number, string, or constant value) at \(currentTokenIndex), but instead found a \(currentToken)")
			}
		case let .numberLiteral(numLiteral):
			try consumeCurrentToken()
			return .number(numLiteral)
		case let .stringLiteral(stringLiteral):
			try consumeCurrentToken()
			return .string("", stringLiteral) // TODO
		default:
			throw ParserError(message: "Expected a comparative value (number, string, or constant value) at \(currentTokenIndex), but instead found a \(currentToken)")
		}
	}
	
	/// Parses a comparative operator from the grammar.
	///
	/// Symbol: `compareOp`
	/// Type: Predictive
	func parseComparativeOperator() throws -> ComparativeOperator {
		switch currentToken {
		case let .keywordIdentifier(keyword):
			guard let compOp = ComparativeOperator(rawValue: keyword.rawValue) else {
				throw ParserError(message: "Expected a comparative operator at \(currentTokenIndex), but instead found a \(currentToken)")
			}
			try consumeCurrentToken()
			return compOp
		default:
			throw ParserError(message: "Expected a comparative operator at \(currentTokenIndex), but instead found a \(currentToken)")
		}
	}
	
	/// Parses an attribute path from the grammar.
	///
	/// Symbol: `attrPath`
	/// Type: Predictive
	func parseAttributePath() throws -> AttributePath {
		switch currentToken {
		case let .urnIdentifier(urnString):
			// Path: namestring ":" ATTRNAME *1subAttr
			try consumeCurrentToken() // Consume the urn namestring
			try expect(token: .colon)
			let attrName = try parseAttributeIdentifier()
			
			if try attempt(token: .dot) {
				let subAttrName = try parseAttributeIdentifier()
				return AttributePath(schemaUrn: urnString, attributeName: attrName, subAttributeName: subAttrName)
			} else {
				return AttributePath(schemaUrn: urnString, attributeName: attrName, subAttributeName: nil)
			}
		case let .attributeIdentifier(attrName):
			// Path: ATTRNAME *1subAttr
			try consumeCurrentToken() // Consume the attrName
			
			if try attempt(token: .dot) {
				let subAttrName = try parseAttributeIdentifier()
				return AttributePath(schemaUrn: nil, attributeName: attrName, subAttributeName: subAttrName)
			} else {
				return AttributePath(schemaUrn: nil, attributeName: attrName, subAttributeName: nil)
			}
		default:
			throw ParserError(message: "Expected a URN or an attribute identifier at \(currentTokenIndex), but instead found a \(currentToken)")
		}
	}
	
	/// Parses an attribute identifier from the grammar.
	///
	/// Symbol: `ATTRNAME`, `subAttr`
	/// Type: Predictive
	func parseAttributeIdentifier() throws -> String {
		guard case let .attributeIdentifier(attrName) = currentToken else {
			throw ParserError(message: "Expected an attribute identifier at \(currentTokenIndex), but instead found a \(currentToken)")
		}
		try consumeCurrentToken()
		return attrName
	}
}

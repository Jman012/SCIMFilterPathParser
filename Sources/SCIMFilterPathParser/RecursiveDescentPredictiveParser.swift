import Foundation

// TODO: Detect and error upon ATTRNAME.subAttr[valFilter]

// Uses SCIM_RFC_7644_LeftRecursionEliminatedV2.abnf
public class RecursiveDescentPredictiveParser {
	
	let lexer: Lexer
	var currentTokenIndex: String.Index
	var currentToken: Token
	private(set) var attemptParseTokenStack: [(String.Index, Token)] = []
	
	public init(filter: String) throws {
		lexer = Lexer(inputString: filter)
		
		currentTokenIndex = lexer.index
		currentToken = try lexer.next()
	}
	
	/// Parses a filter from the grammar.
	/// This expects the entire input string to be parsed, and will fail if no
	/// EOF is encountered at the end.
	///
	/// Symbol: `FILTER`
	/// Type: Predictive
	public func parseFilter() throws -> FilterExpression {
		let filter = try parseFilterInternal()
		try expect(token: .eof)
		return filter
	}
	
	/// Parses a path from the grammar.
	/// This expects the entire input string to be parsed, and will fail if no
	/// EOF is encountered at the end.
	///
	/// Symbol: `PATH`
	/// Type: Predictive
	public func parsePath() throws -> PathExpression {
		/*
		 Reducing PATH down to tokenizable terminal symbols:
		 
		 PATH
		 = attrPath
		 / valuePath [subAttr]
		 / attrExp
		 = attrPath
		 / attrPath "[" valFilter "]" [subAttr]
		 / attrPath SP "pr"
		 / attrPath SP compareOp SP compValue
		 = attrPath [
			"[" valFilter "]" [subAttr]
			/ SP "pr"
			/ SP compareOp SP compValue
		 ]
		 
		 This should help explain what the paths are in the code below.
		 
		 All paths begin with an attrPath, optionally followed with other
		 possibilities to make a valuePath or attribute expression.
		 */
		
		let attrPath = try parseAttributePath()
		
		switch currentToken {
		case .openBracket:
			// Path: valuePath [subAttr]
			let valuePath = try parseValuePath(withPreParsedAttrPath: attrPath)
			var subAttr: String? = nil
			if try attempt(token: .dot) {
				subAttr = try parseAttributeIdentifier()
			}
			try expect(token: .eof)
			return .valuePathExpression(valuePath, subAttr)
		case .space:
			// Path: attrExp
			let attrExp = try parseAttributeExpression(withPreParsedAttrPath: attrPath)
			try expect(token: .eof)
			return .attributeExpression(attrExp)
		case .eof:
			// Path: attrPath
			return .attributePath(attrPath)
		default:
			throw ParserError(message: "Expected a value path, attribute expression, or end of input after the attribute path at \(currentTokenIndex), but found a \(currentToken) instead")
		}
	}
}

// Error handling
extension RecursiveDescentPredictiveParser {
	struct ParserError: Error {
		let message: String
	}
}

// Internal helper methods
extension RecursiveDescentPredictiveParser {
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
extension RecursiveDescentPredictiveParser {
	
	/// Parses a filter from the grammar.
	/// This does not expect an EOF at the end, so that it can be used for
	/// recursive parsing from `parseFilterValue`.
	///
	/// Symbol: `FILTER`
	/// Type: Predictive
	func parseFilterInternal() throws -> FilterExpression {
		let filterOption = try parseFilterValue()
		var continued: [FilterListExpressionContinued] = []
		while currentToken == .space {
			try self.expect(token: .space)
			let logicalOperator = try self.parseLogicalOperator()
			try self.expect(token: .space)
			let filterOption = try self.parseFilterValue()
			let next: FilterListExpressionContinued = .init(logicalOperator: logicalOperator, filter: filterOption)
			
			continued.append(next)
		}
		
		let filterList = FilterListExpression(start: filterOption, continued: continued)
		return filterList.toFilterExpression()
	}
	
	/// Parses a filter value from the grammar.
	///
	/// Symbol: `filterValue`
	/// Type: Predictive
	func parseFilterValue() throws -> FilterValueExpression {
		/*
		 Reducing filterValue down to tokenizable terminal symbols:
		 
		 filterValue
		 = attrExp
		 / valuePath
		 / ["not" [SP]] "(" FILTER ")"
		 = attrPath SP "pr"
		 / attrPath SP compareOp SP compValue
		 / attrPath "[" valFilter "]"
		 / ["not" [SP]] "(" FILTER ")"
		 = [namestring ":"] ATTRNAME *1subAttr SP "pr"
		 / [namestring ":"] ATTRNAME *1subAttr SP compareOp SP compValue
		 / [namestring ":"] ATTRNAME *1subAttr "[" valFilter "]"
		 / ["not" [SP]] "(" FILTER ")"
		 = [namestring ":"] ATTRNAME *1subAttr (SP "pr" / SP compareOp SP compValue / "[" valFilter "]")
		 / ["not" [SP]] "(" FILTER ")"
		 
		 This should help explain what the paths are in the code below.
		 */
		
		switch currentToken {
		case .urnIdentifier, .attributeIdentifier:
			// Path: attrExp or valuePath
			// Both symbols start with an attrPath, and branch from there.
			let attrPath = try parseAttributePath()
			switch currentToken {
			case .space:
				// Path: attrExp
				let attrExp = try parseAttributeExpression(withPreParsedAttrPath: attrPath)
				return .attributeExpression(attrExp)
			case .openBracket:
				// Path: valuePath
				let valuePath = try parseValuePath(withPreParsedAttrPath: attrPath)
				return .valuePathExpression(valuePath)
			default:
				throw ParserError(message: "Expected an space or opening bracket while parsing an attribute expression or value path at \(currentTokenIndex), but encountered a \(currentToken) token instead")
			}
		case .keywordIdentifier(.not), .openParen:
			// Path: nested grouped filter
			var isNegated = false
			if try attempt(token: .keywordIdentifier(.not)) {
				isNegated = true
				_ = try attempt(token: .space)
			}
			
			try expect(token: .openParen)
			let filter = try parseFilterInternal()
			try expect(token: .closeParen)
			
			if isNegated {
				return .negatedGroupedFilter(filter)
			} else {
				return .groupedFilter(filter)
			}
		default:
			throw ParserError(message: "Expected an attribute expression, value path, or a nested grouped filter at \(currentTokenIndex), but encountered a \(currentToken) token instead")
		}
	}
	
	/// Parses a value path from the grammar.
	/// Allows for a pre-parsed attribute path beginning symbol to be used.
	///
	/// Symbol: `valuePath`
	/// Type: Predictive
	func parseValuePath(withPreParsedAttrPath preParsedAttrPath: AttributePath? = nil) throws -> ValuePathExpression {
		
		// Either use a pre-parsed attrPath, or parse it ourselves
		let attrPath: AttributePath
		if let preParsedAttrPath = preParsedAttrPath {
			attrPath = preParsedAttrPath
		} else {
			attrPath = try parseAttributePath()
		}
		
		try expect(token: .openBracket)
		let valFilter = try parseValueFilter()
		try expect(token: .closeBracket)
		
		return ValuePathExpression(attributePath: attrPath, valueFilterExpression: valFilter)
	}
	
	/// Parses a value filter from the grammar.
	///
	/// Symbol: `valFilter`
	/// Type: Predictive
	func parseValueFilter() throws -> ValueFilterListExpression {
		let valFilterOption = try parseValueFilterListValue()
		var continued: [ValueFilterListExpressionContinued] = []
		while currentToken == .space {
			try self.expect(token: .space)
			let logicalOperator = try self.parseLogicalOperator()
			try self.expect(token: .space)
			let valFilterOption = try self.parseValueFilterListValue()
			let next: ValueFilterListExpressionContinued = .init(logicalOperator: logicalOperator, filter: valFilterOption)
			
			continued.append(next)
		}
		
		return .init(start: valFilterOption, continued: continued)
	}
	
	/// Parses a value filter expression from the grammar.
	///
	/// Symbol: `valFilterValue`
	/// Type: Predictive
	func parseValueFilterListValue() throws -> ValueFilterValueExpression {
		/*
		 Reducing valFilterValue down to tokenizable terminal symbols:
		 
		 valFilterValue
		 = attrExp
		 / ["not" [SP]] "(" valFilter ")"
		 = attrPath SP "pr"
		 / attrPath SP compareOp SP compValue
		 / ["not" [SP]] "(" valFilter ")"
		 = [namestring ":"] ATTRNAME *1subAttr SP "pr"
		 / [namestring ":"] ATTRNAME *1subAttr SP compareOp SP compValue
		 / ["not" [SP]] "(" valFilter ")"
		 = [namestring ":"] ATTRNAME *1subAttr SP ("pr" / compareOp SP compValue)
		 / ["not" [SP]] "(" valFilter ")"
		 
		 This should help explain what the paths are in the code below.
		 */
		
		switch currentToken {
		case .urnIdentifier, .attributeIdentifier:
			// Path: attrExp
			let attrExp = try parseAttributeExpression()
			return .attributeExpression(attrExp)
		case .keywordIdentifier(.not), .openParen:
			// Path: nested grouped valFilter
			var isNegated = false
			if try attempt(token: .keywordIdentifier(.not)) {
				isNegated = true
				_ = try attempt(token: .space)
			}

			try expect(token: .openParen)
			let valFilter = try parseValueFilter()
			try expect(token: .closeParen)

			if isNegated {
				return .negatedGroupedValueFilter(valFilter)
			} else {
				return .groupedValueFilter(valFilter)
			}
		default:
			throw ParserError(message: "Expected either an attribute expression or a nested grouped value filter at \(currentTokenIndex), but encountered a \(currentToken) token instead")
		}
	}
	
	/// Parses an attribute expression from the grammar.
	/// Allows for a pre-parsed attribute path beginning symbol to be used.
	///
	/// Symbol: `attrExp`
	/// Type: Predictive
	func parseAttributeExpression(withPreParsedAttrPath preParsedAttrPath: AttributePath? = nil) throws -> AttributeExpression {
		
		// Either use a pre-parsed attrPath, or parse it ourselves
		let attrPath: AttributePath
		if let preParsedAttrPath = preParsedAttrPath {
			attrPath = preParsedAttrPath
		} else {
			attrPath = try parseAttributePath()
		}
		
		_ = try expect(token: .space)
		
		if try attempt(token: .keywordIdentifier(.pr)) {
			return AttributeExpression.present(.init(attributePath: attrPath))
		}
		
		let comparativeOperator: ComparativeOperator
		switch currentToken {
		case let .keywordIdentifier(keyword):
			guard let compOp = ComparativeOperator(rawValue: keyword.rawValue) else {
				throw ParserError(message: "Expected a comparative operator at \(currentTokenIndex), but instead found a \(currentToken)")
			}
			try consumeCurrentToken()
			comparativeOperator = compOp
		default:
			throw ParserError(message: "Expected a comparative operator at \(currentTokenIndex), but instead found a \(currentToken)")
		}
		
		try expect(token: .space)
		let compValue = try parseComparativeValue()
		
		return AttributeExpression.comparison(.init(
			attributePath: attrPath,
			comparativeOperator: comparativeOperator,
			comparativeValue: compValue))
	}
	
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

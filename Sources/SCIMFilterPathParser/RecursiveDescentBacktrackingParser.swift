import Foundation

// TODO: Detect and error upon ATTRNAME.subAttr[valFilter]

public class RecursiveDescentBacktrackingParser {
	
	let lexer: Lexer
	var currentTokenIndex: String.Index
	var currentToken: Token
	private(set) var attemptParseTokenStack: [(String.Index, Token)] = []
	
	public init(filter: String) throws {
		lexer = Lexer(inputString: filter)
		
		currentTokenIndex = lexer.index
		currentToken = try lexer.next()
	}
	
	public func parseFilter() throws -> FilterExpression {
		let filter = try parseFilterInternal()
		try expect(token: .eof)
		return filter
	}
	
	public func parsePath() throws -> PathExpression {
		if let valuePath = attemptParse({ try parseValuePath() }) {
			// Try valuePath first, since it's the longest and most complex
			var subAttr: String? = nil
			if try attempt(token: .dot) {
				subAttr = try parseAttributeIdentifier()
			}
			try expect(token: .eof)
			return .valuePathExpression(valuePath, subAttr)
		} else if let attrExp = attemptParse({ try parseAttributeExpression() }) {
			// Try attrExp next, before attrPath, as it is a superset of attrPath
			try expect(token: .eof)
			return .attributeExpression(attrExp)
		} else if let attrPath = attemptParse({ try parseAttributePath() }) {
			try expect(token: .eof)
			return .attributePath(attrPath)
		} else {
			throw ParserError(message: "Could not parse the path (no viable option was found)")
		}
	}
}

// Error handling
extension RecursiveDescentBacktrackingParser {
	struct ParserError: Error {
		let message: String
	}
}

// Internal helper methods
extension RecursiveDescentBacktrackingParser {
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
	
	func attemptParse<T>(_ closure: () throws -> T) -> T? {
		lexer.pushSnapshot()
		attemptParseTokenStack.append((currentTokenIndex, currentToken))
		
		do {
			let parseResult = try closure()
			
			lexer.discardSnapshot()
			_ = attemptParseTokenStack.popLast()
			
			return parseResult
		} catch {
			lexer.popSnapshot()
			if let currentTokenSnapshot = attemptParseTokenStack.popLast() {
				currentTokenIndex = currentTokenSnapshot.0
				currentToken = currentTokenSnapshot.1
			}
			
			return nil
		}
	}
}

// Internal node parsers
extension RecursiveDescentBacktrackingParser {
	func parseFilterInternal() throws -> FilterExpression {
		let parseNext: () throws -> FilterListExpressionContinued = {
			try self.expect(token: .space)
			let logicalOperator = try self.parseLogicalOperator()
			try self.expect(token: .space)
			let filterOption = try self.parseFilterOption()
			return .init(logicalOperator: logicalOperator, filter: filterOption)
		}
		
		let filterOption = try parseFilterOption()
		var continued: [FilterListExpressionContinued] = []
		while let next = attemptParse({ try parseNext() }) {
			continued.append(next)
		}
		
		let filterList = FilterListExpression(start: filterOption, continued: continued)
		return filterList.toFilterExpression()
	}
	
	func parseFilterOption() throws -> FilterValueExpression {
		if let attrExp = attemptParse({ try parseAttributeExpression() }) {
			// Try attrExp
			return .attributeExpression(attrExp)
		} else if let valuePath = attemptParse({ try parseValuePath() }) {
			// Try valuePath
			return .valuePathExpression(valuePath)
		} else {
			// Try ["not" [SP]] "(" valFilter ")"
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
		}
	}
	
	func parseValuePath() throws -> ValuePathExpression {
		let attrPath = try parseAttributePath()
		try expect(token: .openBracket)
		let valFilter = try parseValueFilter()
		try expect(token: .closeBracket)
		
		return ValuePathExpression(attributePath: attrPath, valueFilterExpression: valFilter)
	}
	
	func parseValueFilter() throws -> ValueFilterListExpression {
		let parseNext: () throws -> ValueFilterListExpressionContinued = {
			try self.expect(token: .space)
			let logicalOperator = try self.parseLogicalOperator()
			try self.expect(token: .space)
			let valFilterOption = try self.parseValueFilterListOption()
			return .init(logicalOperator: logicalOperator, filter: valFilterOption)
		}
		
		let valFilterOption = try parseValueFilterListOption()
		var continued: [ValueFilterListExpressionContinued] = []
		while let next = attemptParse({ try parseNext() }) {
			continued.append(next)
		}
		
		return .init(start: valFilterOption, continued: continued)
	}
	
	func parseValueFilterListOption() throws -> ValueFilterValueExpression {
		if let attrExp = attemptParse({ try parseAttributeExpression() }) {
			// Try attrExp
			return .attributeExpression(attrExp)
		} else {
			// Try ["not" [SP]] "(" valFilter ")"
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
		}
	}
	
	func parseAttributeExpression() throws -> AttributeExpression {
		let attrPath = try parseAttributePath()
		
		_ = try expect(token: .space)
		
		if try attempt(token: .keywordIdentifier(.pr)) {
			return AttributeExpression.present(.init(attributePath: attrPath))
		} else if let compOp = attemptParse({ try parseComparativeOperator() }) {
			try expect(token: .space)
			let compValue = try parseComparativeValue()
			return AttributeExpression.comparison(.init(
				attributePath: attrPath,
				comparativeOperator: compOp,
				comparativeValue: compValue))
		} else {
			throw ParserError(message: "Expected an attribute operator at \(currentTokenIndex), but instead found a \(currentToken)")
		}
	}
	
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
	
	func parseAttributePath() throws -> AttributePath {
		switch currentToken {
		case let .urnIdentifier(urnString):
			try consumeCurrentToken() // Consume the urn
			try expect(token: .colon)
			let attrName = try parseAttributeIdentifier()
			
			if try attempt(token: .dot) {
				let subAttrName = try parseAttributeIdentifier()
				return AttributePath(schemaUrn: urnString, attributeName: attrName, subAttributeName: subAttrName)
			} else {
				return AttributePath(schemaUrn: urnString, attributeName: attrName, subAttributeName: nil)
			}
		case let .attributeIdentifier(attrName):
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
	
	func parseAttributeIdentifier() throws -> String {
		guard case let .attributeIdentifier(attrName) = currentToken else {
			throw ParserError(message: "Expected an attribute identifier at \(currentTokenIndex), but instead found a \(currentToken)")
		}
		try consumeCurrentToken()
		return attrName
	}
	
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

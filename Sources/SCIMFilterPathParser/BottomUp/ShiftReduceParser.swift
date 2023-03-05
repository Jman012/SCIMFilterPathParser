import Foundation

public class ShiftReduceParser: Parser {
	
	enum TokenOrExpr: Hashable {
		case token(Token)
		case symbol(Symbol)
	}
	
	let lexer: Lexer
	var stack: [TokenOrExpr] = []
	
	init(filter: String) {
		lexer = Lexer(inputString: filter)
	}
	
	/// Parses a filter from the grammar.
	/// This expects the entire input string to be parsed, and will fail if no
	/// EOF is encountered at the end.
	public func parseFilter() throws -> FilterExpression {
		throw ParserError(message: "")
	}
	
	/// Parses a path from the grammar.
	/// This expects the entire input string to be parsed, and will fail if no
	/// EOF is encountered at the end.
	public func parsePath() throws -> PathExpression {
		throw ParserError(message: "")
	}
}

// Error handling
extension ShiftReduceParser {
	struct ParserError: Error {
		let message: String
	}
}

// Internal methods
extension ShiftReduceParser {
	func shift() throws {
		let token = try lexer.next()
		stack.append(.token(token))
	}
	
	func reduceShared() -> Bool {
		if stack.count >= 5 {
			let suffix = stack.suffix(5)
			switch (suffix[0], suffix[1], suffix[2], suffix[3], suffix[4]) {
			case (.symbol(.valueFilterAnyExpression(var valFilterAny)), .token(.space), .token(.keywordIdentifier(.or)), .token(.space), .symbol(.valueFilterAllExpression(let valFilterAll))):
				// valFilterAny   = valFilterAny / valFilterAll SP "or" SP valFilterAll
				stack.removeLast(5)
				valFilterAny.anyExprs.append(valFilterAll)
				stack.append(.symbol(.valueFilterAnyExpression(valFilterAny)))
				return true
			case (.symbol(.valueFilterAllExpression(var valFilterAll)), .token(.space), .token(.keywordIdentifier(.and)), .token(.space), .symbol(.valueFilterValueExpression(let valFilterValue))):
				// valFilterAll   = valFilterValue / valFilterAll SP "and" SP valFilterValue
				stack.removeLast(5)
				valFilterAll.allExprs.append(valFilterValue)
				stack.append(.symbol(.valueFilterAllExpression(valFilterAll)))
				return true
			case (.token(.keywordIdentifier(.not)), .token(.space), .token(.openParen), .symbol(.valueFilterExpression(let valFilter)), .token(.closeParen)):
				// valFilterValue = ["not" [SP]] "(" valFilter ")"
				stack.removeLast(5)
				stack.append(.symbol(.valueFilterValueExpression(.negatedGroupedValueFilter(valFilter))))
				return true
			case (.symbol(.attributePath(let attrPath)), .token(.space), .symbol(.comparativeOperator(let compareOp)), .token(.space), .symbol(.comparativeValue(let compValue))):
				// attrExp   = attrPath SP compareOp SP compValue
				stack.removeLast(5)
				stack.append(.symbol(.attributeExpression(.comparison(.init(attributePath: attrPath, comparativeOperator: compareOp, comparativeValue: compValue)))))
				return true
			default:
				break
			}
		}
		
		if stack.count >= 4 {
			let suffix = stack.suffix(4)
			switch (suffix[0], suffix[1], suffix[2], suffix[3]) {
			case (.symbol(.attributePath(let attrPath)), .token(.openBracket), .symbol(.valueFilterExpression(let valFilter)), .token(.closeBracket)):
				// valuePath = attrPath "[" valFilter "]"
				stack.removeLast(4)
				stack.append(.symbol(.valuePathExpression(.init(attributePath: attrPath, valueFilterExpression: valFilter))))
				return true
			default:
				break
			}
		}
		
		if stack.count >= 3 {
			let suffix = stack.suffix(3)
			switch (suffix[0], suffix[1], suffix[2]) {
			case (.symbol(.attributePath(let attrPath)), .token(.space), .token(.keywordIdentifier(.pr))):
				// attrExp   = attrPath SP "pr"
				stack.removeLast(3)
				stack.append(.symbol(.attributeExpression(.present(.init(attributePath: attrPath)))))
				return true
			case (.token(.urnIdentifier(let urnNamestring)), .token(.colon), .token(.attributeIdentifier(let attrName))):
				// attrPath = namestring ":" ATTRNAME
				stack.removeLast(3)
				stack.append(.symbol(.attributePath(.init(schemaUrn: urnNamestring, attributeName: attrName, subAttributeName: nil))))
			case (.symbol(.attributePath(let attrPath)), .token(.dot), .token(.attributeIdentifier(let subAttr))) where attrPath.subAttributeName == nil:
				// attrPath = ATTRNAME "." subAttr
				// or
				// attrPath = attrPath "." subAttr
				stack.removeLast(3)
				stack.append(.symbol(.attributePath(.init(schemaUrn: attrPath.schemaUrn, attributeName: attrPath.attributeName, subAttributeName: subAttr))))
			default:
				break
			}
		}
		
		if stack.count >= 1 {
			switch stack.last! {
			case .symbol(.valueFilterAnyExpression(let valFilterAny)):
				// valFilter      = valFilterAny
				stack.removeLast(1)
				stack.append(.symbol(.valueFilterExpression(.init(anyExpr: valFilterAny))))
				return true
			case .symbol(.attributeExpression(let attrExpr)):
				// valFilterValue = attrExp
				// filterValue = attrExp
				// PATH = attrExp
				// But, this can also be a filterValue or PATH. How to know which?
				return true
			case .token(.keywordIdentifier(.false)):
				// compValue = false
				stack.removeLast(1)
				stack.append(.symbol(.comparativeValue(.false)))
				return true
			case .token(.keywordIdentifier(.null)):
				// compValue = null
				stack.removeLast(1)
				stack.append(.symbol(.comparativeValue(.null)))
				return true
			case .token(.keywordIdentifier(.true)):
				// compValue = true
				stack.removeLast(1)
				stack.append(.symbol(.comparativeValue(.true)))
				return true
			case .token(.numberLiteral(let num)):
				// compValue = number
				stack.removeLast(1)
				stack.append(.symbol(.comparativeValue(.number(num))))
				return true
			case .token(.stringLiteral(let str)):
				// compValue = string
				stack.removeLast(1)
				stack.append(.symbol(.comparativeValue(.string("", str))))
				return true
			case .token(.keywordIdentifier(.eq)):
				// compareOp = "eq"
				stack.removeLast(1)
				stack.append(.symbol(.comparativeOperator(.eq)))
				return true
			case .token(.keywordIdentifier(.ne)):
				// compareOp = "ne"
				stack.removeLast(1)
				stack.append(.symbol(.comparativeOperator(.ne)))
				return true
			case .token(.keywordIdentifier(.co)):
				// compareOp = "co"
				stack.removeLast(1)
				stack.append(.symbol(.comparativeOperator(.co)))
				return true
			case .token(.keywordIdentifier(.sw)):
				// compareOp = "sw"
				stack.removeLast(1)
				stack.append(.symbol(.comparativeOperator(.sw)))
				return true
			case .token(.keywordIdentifier(.ew)):
				// compareOp = "ew"
				stack.removeLast(1)
				stack.append(.symbol(.comparativeOperator(.ew)))
				return true
			case .token(.keywordIdentifier(.gt)):
				// compareOp = "gt"
				stack.removeLast(1)
				stack.append(.symbol(.comparativeOperator(.gt)))
				return true
			case .token(.keywordIdentifier(.lt)):
				// compareOp = "lt"
				stack.removeLast(1)
				stack.append(.symbol(.comparativeOperator(.lt)))
				return true
			case .token(.keywordIdentifier(.ge)):
				// compareOp = "ge"
				stack.removeLast(1)
				stack.append(.symbol(.comparativeOperator(.ge)))
				return true
			case .token(.keywordIdentifier(.le)):
				// compareOp = "le"
				stack.removeLast(1)
				stack.append(.symbol(.comparativeOperator(.le)))
				return true
			default:
				break
			}
		}
		
		return false
	}
	
	func reduceFilter() -> Bool {
		if stack.count >= 5 {
			let suffix = stack.suffix(5)
			switch (suffix[0], suffix[1], suffix[2], suffix[3], suffix[4]) {
			case (.symbol(.filterAnyExpression(var any)), .token(.space), .token(.keywordIdentifier(.or)), .token(.space), .symbol(.filterAllExpression(let all))):
				stack.removeLast(5)
				any.anyExprs.append(all)
				stack.append(.symbol(.filterAnyExpression(any)))
				return true
			default:
				break
			}
		}
		
//		if stack.count >= 3 {
//			switch stack.suffix(3) {
//
//			}
//		}
		
		if stack.count >= 1 {
			switch stack.last! {
			case let .symbol(.filterAnyExpression(filterAnyExpr)):
				stack.removeLast(1)
				stack.append(.symbol(.filterExpression(.init(anyExpr: filterAnyExpr))))
				return true
			case .token(.keywordIdentifier(.eq)):
				stack.removeLast(1)
				stack.append(.symbol(.comparativeOperator(.eq)))
				return true
			default:
				break
			}
		}
		
		return false
	}
	
	func reducePath() -> Bool {
		return false
	}
}

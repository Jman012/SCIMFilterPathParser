import Foundation

public enum Keyword: String, Hashable {
	case eq = "eq"
	case ne = "ne"
	case co = "co"
	case sw = "sw"
	case ew = "ew"
	case pr = "pr"
	case gt = "gt"
	case ge = "ge"
	case lt = "lt"
	case le = "le"
	case and = "and"
	case or = "or"
	case not = "not"
	case `true` = "true"
	case `false` = "false"
	case null = "null"
}

public enum Token: Hashable {
	case eof
	case space
	case openParen
	case closeParen
	case openBracket
	case closeBracket
	case dot
	case colon
	case keywordIdentifier(Keyword)
	case urnIdentifier(String)
	case attributeIdentifier(String)
	case stringLiteral(String)
	case numberLiteral(String)
}

import Foundation

public class Lexer {
	
	private let inputString: String
	private(set) var index: String.Index
	private let endIndex: String.Index
	private var indexSnapshots: [String.Index] = []
	
	public init(inputString: String) {
		self.inputString = inputString
		self.index = inputString.startIndex
		self.endIndex = inputString.endIndex
	}
	
	public func next() throws -> Token {
		while true {
			switch current {
			case "\0":
				return .eof
			case " ":
				advance()
				return .space
			case "(":
				advance()
				return .openParen
			case ")":
				advance()
				return .closeParen
			case "[":
				advance()
				return .openBracket
			case "]":
				advance()
				return .closeBracket
			case ".":
				advance()
				return .dot
			case ":":
				advance()
				return .colon
			default:
				let char = current
				if char.isAbnfDigit || char == "-" {
					return try nextNumber()
				} else if char == "\"" {
					return try nextString()
				} else if char.isAbnfAlpha {
					// An identifier, keyword, or URN all begin with only ABNF
					// ALPHA characters
					return try nextIdentifier()
				} else {
					throw LexerError(reason: .unexpectedCharacter, message: "Unexpected character '\(char)'", atIndex: index)
				}
			}
		}
	}
}

// Error handling
extension Lexer {
	public struct LexerError: Error, Hashable {
		let reason: LexerErrorReason
		let message: String
		let atIndex: String.Index
	}
	
	public enum LexerErrorReason: Hashable {
		case invalidNumberLiteral
		case invalidStringLiteral
		case unexpectedCharacter
		case invalidAttemptedUrnIdentifier
		case invalidAttributeIdentifier
	}
}

// Backtracking support
extension Lexer {
	public func pushSnapshot() {
		indexSnapshots.append(index)
	}
	
	public func discardSnapshot() {
		_ = indexSnapshots.popLast()
	}
	
	public func popSnapshot() {
		if let poppedIndex = indexSnapshots.popLast() {
			index = poppedIndex
		}
	}
}

// Internal state management/helper methods
extension Lexer {
	private var current: Character {
		if index == inputString.endIndex {
			return "\0"
		}
		
		return inputString[index]
	}
	
	private var peekNext: Character {
		let nextIndex = inputString.index(after: index)
		if nextIndex >= endIndex {
			return "\0"
		}
		
		return inputString[nextIndex]
	}
	
	private var peekPrevious: Character {
		let previousIndex = inputString.index(before: index)
		if previousIndex <= inputString.startIndex {
			return "\0"
		}
		
		return inputString[previousIndex]
	}
	
	private func advance() {
		index = inputString.index(after: index)
	}
	
	private func withdraw(_ n: Int = 1) {
		for _ in 0..<n {
			index = inputString.index(before: index)
		}
	}
	
	private func peek(_ n: Int) -> Character {
		let peekIndex = inputString.index(index, offsetBy: n)
		if peekIndex < inputString.startIndex || peekIndex >= endIndex {
			return "\0"
		}
		
		return inputString[peekIndex]
	}
}

// Internal tokenizer methods
extension Lexer {
	// Tokenizes an RFC 7159 JSON Number value.
	// See /Docs/AppliedGrammars/JSON_RFC7159.abnf section 6
	func nextNumber() throws -> Token {
		// Capture the beginning and ending indices to form the literal
		let start = index
		
		// `[ minus ]`
		// Optional beginning minus/negation/hyphen
		if current == "-" {
			advance() // "-"
		}
		
		// `int`
		// Either 0, or a series of digits not beginning with 0.
		if current == "0" {
			advance() // "0"
		} else if current.isAbnfDigit {
			// Non-zero is implied in the if-else chain
			// Consume consecutive digits
			while current.isAbnfDigit {
				advance()
			}
		} else {
			throw LexerError(reason: .invalidNumberLiteral, message: "Expected digit", atIndex: index)
		}
		
		// `[ frac ]`
		// Optional fractional
		if current == "." && peekNext.isAbnfDigit {
			advance() // "."
			// Consume consecutive digits
			while current.isAbnfDigit {
				advance()
			}
		}
		
		// `[ exp ]`
		// Optional exponential
		if current.lowercased() == "e" && (peekNext == "-" || peekNext == "+") && peek(2).isAbnfDigit {
			// Case 1: e-1234 or e+1234
			advance() // "e"
			advance() // "-" / "+"
			// Consume consecutive digits
			while current.isAbnfDigit {
				advance()
			}
		} else if current.lowercased() == "e" && peekNext.isAbnfDigit {
			// Case 2: e1234 or e1234
			advance() // "e"
			// Consume consecutive digits
			while current.isAbnfDigit {
				advance()
			}
		}
		
		let end = index
		let literal: Substring = inputString[start..<end]
		return .numberLiteral(String(literal))
	}
	
	// Tokenizes an RFC 7150 JSON String value.
	// See /Docs/AppliedGrammars/JSON_RFC7159.abnf section 7
	func nextString() throws -> Token {
		// Capture the beginning and ending indices to form the literal
		let start = index
		
		guard current == "\"" else {
			throw LexerError(reason: .invalidStringLiteral, message: "Expected beginning double quote", atIndex: index)
		}
		advance() // '"'
		
		while current != "\"" {
			if current == "\\" {
				// Escape sequence
				switch peekNext {
				case "\"", "\\", "/", "b", "f", "n", "r", "t":
					// Simple, pre-defined escape sequence
					advance() // "\"
					advance() // The escaped single character
				case "u":
					// Unicode scalar escape sequence
					guard peek(2).isAbnfHexDig && peek(3).isAbnfHexDig && peek(4).isAbnfHexDig && peek(5).isAbnfHexDig else {
						throw LexerError(reason: .invalidStringLiteral, message: "Invalid unicode escape sequence", atIndex: index)
					}
					
					for _ in 0..<6 {
						advance() // \uxxxx, six total digits
					}
				default:
					throw LexerError(reason: .invalidStringLiteral, message: "Invalid escape sequence", atIndex: index)
				}
			} else if index == endIndex {
				throw LexerError(reason: .invalidStringLiteral, message: "Unexpected end of input", atIndex: index)
			} else {
				// Simple valid character
				advance()
			}
		}
		
		guard current == "\"" else {
			throw LexerError(reason: .invalidStringLiteral, message: "Expected ending double quote", atIndex: index)
		}
		advance() // '"'
		
		let end = index
		let literal: Substring = inputString[start..<end]
		return .stringLiteral(String(literal))
	}
	
	/*
	 Tokenizes the next keyword, URN, or attribute identifier.
	 
	 Note that URNs allow parentheses and the SCIM parser does not require
	 a space before a "not" and an opening parenthesis. This makes lexical analysis
	 difficult. This function could greedily capture "not(userName" as a single
	 token if not handled carefully with the URN rules. While the SCIM ABNF does
	 not contain a space between "not" and "(", the examples do.
	 */
	func nextIdentifier() throws -> Token {
		/*
		 In the SCIM RFC, there are a set of keywords. All of which are letters.
		 There are also attribute identifiers, that must begin with a letter,
		 but can contain or end with letters, digits, underscores, and/or hyphens.
		 
		 In the JSON RFC, there are only three keywords, all of which contain
		 only letters.
		 
		 A URN can contain many more characters and symbols. Usually, including
		 a URN in a full programming language grammar would be difficult, as the
		 symbols have a lot of overlap with a language's grammar, and knowing when
		 to continue tokenizing a URN vs. stop and produce other tokens is difficult.
		 
		 In the grammar for this project, we run into this issue only with the
		 parenthetical characters "(" and ")" and the dot ("."). To faciliate this,
		 we will consume parentheticals if the current identifier being consumed
		 thus far is a valid URN, and the parenthetical exists within the NSS
		 section of the URN. Thus, the input `not(` will be tokenized into "not"
		 and "(", while the input `urn:x:not(` will be tokenized into a single
		 URN identifier.
		 
		 Conversely, the inputs `a:b:c()` will fail to tokenize into anything,
		 as it is not a valid URN, and contains invalid characters for a SCIM
		 attribute name (and is not a registered keyword). Same for `urn:()`
		 because parentheticals are not allow in the NID of a URN.
		 */
		
		// Capture the beginning and ending indices to form the literal
		let start = index
		
		// Consume all characters that are either part of:
		// - The SCIM's ATTRNAME node
		// - The JSON's value literal nodes
		// - The URN's namestring node
		while current.isMemberOf(CharacterSet.scimAttrNameJsonValuesUrnNamestring) {
			if current == "(" || current == ")" || current == "." {
				// Handle URN's parentheticals carefully
				let end = index
				let literal: Substring = inputString[start..<end]
				if isAttemptedUrnString(literal) {
					// If it looks like a URN, continue consuming the parenthetical
					// since it can be part of a URN. If the URN is invalid, it
					// will be handled below.
					advance()
				} else {
					// Otherwise, it's likely that this is a keyword followed by
					// a parenthesis, such as `not(` or a mistaken `and(`.
					break
				}
			} else {
				// Consume the next character as normal
				advance()
			}
		}
		
		let end = index
		let literal: Substring = inputString[start..<end]
		let literalString = String(literal)
		
		if literal == "" {
			throw LexerError(reason: .invalidAttributeIdentifier, message: "Nothing found", atIndex: start)
		}
		
		// Determine which type of token to return
		if let keyword = Keyword(rawValue: literalString) {
			return .keywordIdentifier(keyword)
		}
		
		if isValidSyntacticScimAttrName(literal) {
			return .attributeIdentifier(literalString)
		}
		
		if isAttemptedUrnString(literal) {
			// Here, we have to perform some special handling as well.
			// In SCIM, you can explicitly refer to a schema's attribute by
			// preceding the attribute name with the URN and a colon (":").
			// While the full combination is a correct URN, it's more likely
			// that this should be interpreted as a URN, a colon, and then
			// an attribute path name. Attempt to do so here.
			
			if let lastColonIndex = literal.lastIndex(of: ":") {
				let attemptedUrn = literal[...lastColonIndex]
				var attemptedAttributeName = literal[literal.index(after: lastColonIndex)...]
				
				// If of the form "urn:abc:def:emails.type", the attemptedAttributeName
				// will be "emails.type" which won't pass the valid syntactic
				// attrName test below. Split it to only contain, e.g., "emails"
				if let dotIndex = attemptedAttributeName.firstIndex(of: ".") {
					attemptedAttributeName = attemptedAttributeName[..<dotIndex]
				}
				
				if isAttemptedUrnString(attemptedUrn) && isValidSyntacticUrn(attemptedUrn) && isValidSyntacticScimAttrName(attemptedAttributeName) {
					let end = lastColonIndex
					let literal: Substring = inputString[start..<end]
					let literalString = String(literal)
					
					// Backtrack the index to not consume the colon and
					// the attribute name.
					index = end
					
					return .urnIdentifier(literalString)
				}
			}
			
			if isValidSyntacticUrn(literal) {
				return .urnIdentifier(literalString)
			} else {
				throw LexerError(reason: .invalidAttemptedUrnIdentifier, message: "An attempted URN is malformed or contains invalid characters", atIndex: start)
			}
		}
		
		throw LexerError(reason: .invalidAttributeIdentifier, message: "An identifier contains invalid characters", atIndex: start)
	}
	
	func isValidSyntacticScimAttrName<T>(_ literal: T) -> Bool where T: StringProtocol {
		if let first = literal.first, first.isMemberOf(.abnfAlphas)
			&& CharacterSet.scimAttrName.isSuperset(of: CharacterSet(literal.unicodeScalars)) {
			return true
		} else {
			return false
		}
	}
}

// URN helper methods
extension Lexer {
	// The desired regex is the following, but NSRegularExpression does not
	// support the DEFINE feature.
	// #"(?(DEFINE)(?<pchar>(?:[a-z0-9\-\._~!$&'()*+,;=:@]|%[0-9a-f]{2})))^(?i:urn:(?!urn:)(?<nid>[a-z0-9][a-z0-9-]{0,30}[a-z0-9]):(?<nss>(?:\g<pchar>)(?:\g<pchar>|[\/])*)(?:\?\+(?<rcomponent>(?:\g<pchar>)(?:\g<pchar>|[\/?])*))?(?:\?=(?<qcomponent>(?:\g<pchar>)(?:\g<pchar>|[\/?])*))?(?:#(?<fcomponent>(?:\g<pchar>)(?:\g<pchar>|[\/?])*))?)$"#
	static let urnRegex = try! NSRegularExpression(pattern: #"^(?i:urn:(?!urn:)(?<nid>[a-z0-9][a-z0-9-]{0,30}[a-z0-9]):(?<nss>(?:(?:[a-z0-9\-\._~!$&'()*+,;=:@]|%[0-9a-f]{2}))(?:(?:[a-z0-9\-\._~!$&'()*+,;=:@]|%[0-9a-f]{2})|[\/])*)(?:\?\+(?<rcomponent>(?:(?:[a-z0-9\-\._~!$&'()*+,;=:@]|%[0-9a-f]{2}))(?:(?:[a-z0-9\-\._~!$&'()*+,;=:@]|%[0-9a-f]{2})|[\/?])*))?(?:\?=(?<qcomponent>(?:(?:[a-z0-9\-\._~!$&'()*+,;=:@]|%[0-9a-f]{2}))(?:(?:[a-z0-9\-\._~!$&'()*+,;=:@]|%[0-9a-f]{2})|[\/?])*))?(?:#(?<fcomponent>(?:(?:[a-z0-9\-\._~!$&'()*+,;=:@]|%[0-9a-f]{2}))(?:(?:[a-z0-9\-\._~!$&'()*+,;=:@]|%[0-9a-f]{2})|[\/?])*))?)$"#)
	
	func isAttemptedUrnString<T>(_ urn: T) -> Bool where T: StringProtocol {
		// A URN begins with "urn:", case-insensitive.
		// The prefix "urn" with the added colon is enough to identify an
		// attempted URN, because the colon is only allow in URNs, not in SCIM
		// attribute names nor JSON values.
		return urn.lowercased().hasPrefix("urn:")
	}
	
	func isValidSyntacticUrn<T>(_ urn: T) -> Bool where T: StringProtocol {
		Lexer.urnRegex.numberOfMatches(in: String(urn), range: NSRange(0..<urn.count)) > 0
	}
}

import XCTest
@testable import SCIMFilterPathParser

final class LexerTests: XCTestCase {
	func testMain() throws {
		
		let input = " ()[]. 0 1 -1 0.1 1.0 1.01 1.10 10e2 10.3e-4 10.3e+4"
		let lexer = Lexer(inputString: input)
		
		var tokens: [Token] = []
		while tokens.last != .eof {
			tokens.append(try lexer.next())
		}
		
		XCTAssertEqual(tokens, [
			.space,
			.openParen,
			.closeParen,
			.openBracket,
			.closeBracket,
			.dot,
			.space,
			.numberLiteral("0"),
			.space,
			.numberLiteral("1"),
			.space,
			.numberLiteral("-1"),
			.space,
			.numberLiteral("0.1"),
			.space,
			.numberLiteral("1.0"),
			.space,
			.numberLiteral("1.01"),
			.space,
			.numberLiteral("1.10"),
			.space,
			.numberLiteral("10e2"),
			.space,
			.numberLiteral("10.3e-4"),
			.space,
			.numberLiteral("10.3e+4"),
			.eof,
		])
	}
	
	func testStrings() throws {
		var input = #" "test" "test\u0061\n" "\"" "🇺🇸" "#
		let lexer = Lexer(inputString: input)
		
		var tokens: [Token] = []
		while tokens.last != .eof {
			tokens.append(try lexer.next())
		}
		
		XCTAssertEqual(tokens, [
			.space,
			.stringLiteral(#""test""#),
			.space,
			.stringLiteral(#""test\u0061\n""#),
			.space,
			.stringLiteral(#""\"""#),
			.space,
			.stringLiteral(#""🇺🇸""#),
			.space,
			.eof,
		])
		
		input = #"""#
		XCTAssertThrowsError(try Lexer(inputString: input).next()) { error in
			XCTAssertEqual(error as? Lexer.LexerError, Lexer.LexerError(reason: .invalidStringLiteral, message: "Unexpected end of input", atIndex: input.endIndex))
		}
		input = #""a"#
		XCTAssertThrowsError(try Lexer(inputString: input).next()) { error in
			XCTAssertEqual(error as? Lexer.LexerError, Lexer.LexerError(reason: .invalidStringLiteral, message: "Unexpected end of input", atIndex: input.endIndex))
		}
		input = #""\""#
		XCTAssertThrowsError(try Lexer(inputString: input).next()) { error in
			XCTAssertEqual(error as? Lexer.LexerError, Lexer.LexerError(reason: .invalidStringLiteral, message: "Unexpected end of input", atIndex: input.endIndex))
		}
		input = #""\a""#
		XCTAssertThrowsError(try Lexer(inputString: input).next()) { error in
			XCTAssertEqual(error as? Lexer.LexerError, Lexer.LexerError(reason: .invalidStringLiteral, message: "Invalid escape sequence", atIndex: input.index(input.startIndex, offsetBy: 1)))
		}
		input = #""\u""#
		XCTAssertThrowsError(try Lexer(inputString: input).next()) { error in
			XCTAssertEqual(error as? Lexer.LexerError, Lexer.LexerError(reason: .invalidStringLiteral, message: "Invalid unicode escape sequence", atIndex: input.index(input.startIndex, offsetBy: 1)))
		}
		input = #""\u1""#
		XCTAssertThrowsError(try Lexer(inputString: input).next()) { error in
			XCTAssertEqual(error as? Lexer.LexerError, Lexer.LexerError(reason: .invalidStringLiteral, message: "Invalid unicode escape sequence", atIndex: input.index(input.startIndex, offsetBy: 1)))
		}
		input = #""\u12""#
		XCTAssertThrowsError(try Lexer(inputString: input).next()) { error in
			XCTAssertEqual(error as? Lexer.LexerError, Lexer.LexerError(reason: .invalidStringLiteral, message: "Invalid unicode escape sequence", atIndex: input.index(input.startIndex, offsetBy: 1)))
		}
		input = #""\u123""#
		XCTAssertThrowsError(try Lexer(inputString: input).next()) { error in
			XCTAssertEqual(error as? Lexer.LexerError, Lexer.LexerError(reason: .invalidStringLiteral, message: "Invalid unicode escape sequence", atIndex: input.index(input.startIndex, offsetBy: 1)))
		}
	}
	
	func testIsAttemptedUrnString() throws {
		let attempted: [String] = [
			"urn:",
			"urN:",
			"uRn:",
			"Urn:",
			"uRN:",
			"UrN:",
			"URn:",
			"URN:",
			"urn:test",
			"urn:test:fullurn",
			"urn:with a space or few",
			"urn:trailing space ",
			"urn::::::",
		]
		
		let notAttempted: [String] = [
			" urn:",
			"urn",
			"urn_",
			"urn;"
		]
		
		for attemptedUrn in attempted {
			XCTAssertTrue(Lexer(inputString: "").isAttemptedUrnString(attemptedUrn))
		}
		
		for notAttemptedUrn in notAttempted {
			XCTAssertFalse(Lexer(inputString: "").isAttemptedUrnString(notAttemptedUrn))
		}
	}
	
	func testIsValidSyntacticUrn() throws {
		let valid: [String] = [
			"urn:isbn:1234",
			"URN:test:test",
			"urn:ab:ab",
			"urn:012:345",
			"urn:a-c:abc",
			"urn:0-2:012",
			#"urn:test:a0-._~%ab!$&'()*+,;=:@"#,
			"urn:test:a?+abc/?",
			"urn:test:a?=abc/?",
			"urn:test:a?+abc/??=abc/?",
			"urn:test:a#abc/?",
		]
		
		let invalid: [String] = [
			"",
			"urn:",
			"urn::",
			"urn:abc",
			"urn:abc:",
			" urn:test:test",
			"urn:test:test ",
			"urn:te st:te st",
			"urn:test-:test",
			"urn:-test:test",
			"urn:a:b",
			"urn:test:%",
			"urn:test:%a",
			"urn:test:%gg",
		]
		
		for validUrn in valid {
			XCTAssertTrue(Lexer(inputString: "").isValidSyntacticUrn(validUrn), validUrn)
		}
		
		for invalidUrn in invalid {
			XCTAssertFalse(Lexer(inputString: "").isValidSyntacticUrn(invalidUrn), invalidUrn)
		}
	}
	
	func testNextIdentifier() throws {
		let tests: [(String, Token)] = [
			("not", .keywordIdentifier(.not)),
			("true", .keywordIdentifier(.true)),
			("eq", .keywordIdentifier(.eq)),
			("somethingelse", .attributeIdentifier("somethingelse")),
			("nota", .attributeIdentifier("nota")),
			("anot", .attributeIdentifier("anot")),
			("test-test-", .attributeIdentifier("test-test-")),
			("test_test_", .attributeIdentifier("test_test_")),
			("t_---_-_t", .attributeIdentifier("t_---_-_t")),
			("urn:test:test", .urnIdentifier("urn:test:test")),
			("urn:test1:test2:test3", .urnIdentifier("urn:test1:test2")), // Separated into URN and ATTRNAME
			("urn:test1:test2:test3.test4", .urnIdentifier("urn:test1:test2")), // Separated into URN and ATTRNAME and subAttr
			("urn:test:test()", .urnIdentifier("urn:test:test()")),
		]
		
		for (input, expected) in tests {
			XCTAssertNoThrow(XCTAssertEqual(expected, try Lexer(inputString: input).nextIdentifier()))
		}
		
		let invalidTests: [String] = [
			"-test",
			":test",
			"urn:",
			"urn:a:b",
			"test:",
			"test%",
			"urn:(",
		]
		
		for invalidTest in invalidTests {
			XCTAssertThrowsError(try Lexer(inputString: invalidTest).nextIdentifier(), invalidTest)
		}
		
		let seriesTests: [(String, [Token])] = [
			("not(", [.keywordIdentifier(.not), .openParen, .eof]),
			("not)", [.keywordIdentifier(.not), .closeParen, .eof]),
			("test(", [.attributeIdentifier("test"), .openParen, .eof]),
			("test)", [.attributeIdentifier("test"), .closeParen, .eof]),
			("name.familyName", [.attributeIdentifier("name"), .dot, .attributeIdentifier("familyName"), .eof]),
			("urn:abc:def:ghi", [.urnIdentifier("urn:abc:def"), .colon, .attributeIdentifier("ghi"), .eof]),
			("urn:abc:def:ghi?=jkl:userName", [.urnIdentifier("urn:abc:def:ghi?=jkl"), .colon, .attributeIdentifier("userName"), .eof]),
		]
		
		for (input, expectedTokens) in seriesTests {
			let lexer = Lexer(inputString: input)
			var tokens: [Token] = []

			var token: Token = .space
			repeat {
				token = try! lexer.next()
				tokens.append(token)
			} while token != .eof
			
			XCTAssertEqual(expectedTokens, tokens, input)
		}
	}
	
	func testLexer() throws {
		let input = #"urn:ietf:params:scim:schemas:core:2.0:User:userName sw "J" and title pr and name.familyName co "O'Malley" and emails[type eq "work" or value co "@example.com"] or (id ne "1234")"#
		let expectedTokens: [Token] = [
			.urnIdentifier("urn:ietf:params:scim:schemas:core:2.0:User"),
			.colon,
			.attributeIdentifier("userName"),
			.space,
			.keywordIdentifier(.sw),
			.space,
			.stringLiteral(#""J""#),
			.space,
			.keywordIdentifier(.and),
			.space,
			.attributeIdentifier("title"),
			.space,
			.keywordIdentifier(.pr),
			.space,
			.keywordIdentifier(.and),
			.space,
			.attributeIdentifier("name"),
			.dot,
			.attributeIdentifier("familyName"),
			.space,
			.keywordIdentifier(.co),
			.space,
			.stringLiteral(#""O'Malley""#),
			.space,
			.keywordIdentifier(.and),
			.space,
			.attributeIdentifier("emails"),
			.openBracket,
			.attributeIdentifier("type"),
			.space,
			.keywordIdentifier(.eq),
			.space,
			.stringLiteral(#""work""#),
			.space,
			.keywordIdentifier(.or),
			.space,
			.attributeIdentifier("value"),
			.space,
			.keywordIdentifier(.co),
			.space,
			.stringLiteral(#""@example.com""#),
			.closeBracket,
			.space,
			.keywordIdentifier(.or),
			.space,
			.openParen,
			.attributeIdentifier("id"),
			.space,
			.keywordIdentifier(.ne),
			.space,
			.stringLiteral(#""1234""#),
			.closeParen,
			.eof,
		]
		
		let lexer = Lexer(inputString: input)
		var tokens: [Token] = []

		var token: Token = .space
		repeat {
			token = try! lexer.next()
			tokens.append(token)
		} while token != .eof
		
		XCTAssertEqual(expectedTokens, tokens)
	}
	
	func testSnapshots() throws {
		let inputString = "0 1 2 3 4 5 6"
		let lexer = Lexer(inputString: inputString)
		
		lexer.popSnapshot() // Ensure doesn't crash
		
		XCTAssertEqual(Token.numberLiteral("0"), try lexer.next())
		XCTAssertEqual(Token.space, try lexer.next())
		
		// Push, consume, and pop to get back to where we pushed
		lexer.pushSnapshot()
		XCTAssertEqual(Token.numberLiteral("1"), try lexer.next())
		XCTAssertEqual(Token.space, try lexer.next())
		lexer.popSnapshot()
		
		// Ensure we're back where we were
		XCTAssertEqual(Token.numberLiteral("1"), try lexer.next())
		XCTAssertEqual(Token.space, try lexer.next())
		
		// Ensure discard doesn't let a pop do anything
		lexer.pushSnapshot()
		XCTAssertEqual(Token.numberLiteral("2"), try lexer.next())
		XCTAssertEqual(Token.space, try lexer.next())
		lexer.discardSnapshot()
		lexer.popSnapshot()
		
		XCTAssertEqual(Token.numberLiteral("3"), try lexer.next())
		XCTAssertEqual(Token.space, try lexer.next())
		
		// Stacked pushes
		lexer.pushSnapshot()
		XCTAssertEqual(Token.numberLiteral("4"), try lexer.next())
		XCTAssertEqual(Token.space, try lexer.next())
		lexer.pushSnapshot()
		XCTAssertEqual(Token.numberLiteral("5"), try lexer.next())
		XCTAssertEqual(Token.space, try lexer.next())
		lexer.popSnapshot()
		XCTAssertEqual(Token.numberLiteral("5"), try lexer.next())
		XCTAssertEqual(Token.space, try lexer.next())
		lexer.popSnapshot()
		XCTAssertEqual(Token.numberLiteral("4"), try lexer.next())
		XCTAssertEqual(Token.space, try lexer.next())
		
	}
}

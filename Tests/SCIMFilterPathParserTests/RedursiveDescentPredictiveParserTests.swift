import XCTest
@testable import SCIMFilterPathParser

final class RecursiveDescentPredictiveParserTests: XCTestCase {
	func testInit() throws {
		XCTAssertNoThrow(try RecursiveDescentPredictiveParser(filter: ""))
		XCTAssertNoThrow(try RecursiveDescentPredictiveParser(filter: " "))
		XCTAssertNoThrow(try RecursiveDescentPredictiveParser(filter: "0"))
		XCTAssertNoThrow(try RecursiveDescentPredictiveParser(filter: ")"))
		
		XCTAssertThrowsError(try RecursiveDescentPredictiveParser(filter: "+"))
		XCTAssertThrowsError(try RecursiveDescentPredictiveParser(filter: "_"))
		XCTAssertThrowsError(try RecursiveDescentPredictiveParser(filter: "{"))
		XCTAssertThrowsError(try RecursiveDescentPredictiveParser(filter: "urn:a:b:c"))
	}
	
	func testConsumeCurrentToken() throws {
		let parser = try RecursiveDescentPredictiveParser(filter: "0 1")
		XCTAssertEqual(Token.numberLiteral("0"), parser.currentToken)
		XCTAssertNoThrow(try parser.consumeCurrentToken())
		XCTAssertEqual(Token.space, parser.currentToken)
		XCTAssertNoThrow(try parser.consumeCurrentToken())
		XCTAssertEqual(Token.numberLiteral("1"), parser.currentToken)
		XCTAssertNoThrow(try parser.consumeCurrentToken())
		XCTAssertEqual(Token.eof, parser.currentToken)
		XCTAssertNoThrow(try parser.consumeCurrentToken())
		XCTAssertNoThrow(try parser.consumeCurrentToken())
		XCTAssertNoThrow(try parser.consumeCurrentToken())
		
		XCTAssertNoThrow(try parser.expect(token: .eof))
	}
	
	func testExpect() throws {
		let parser = try RecursiveDescentPredictiveParser(filter: "0 1")
		XCTAssertNoThrow(try parser.expect(token: .numberLiteral("0")))
		XCTAssertNoThrow(try parser.expect(token: .space))
		XCTAssertNoThrow(try parser.expect(token: .numberLiteral("1")))
		XCTAssertNoThrow(try parser.expect(token: .eof))
		
		let parser2 = try RecursiveDescentPredictiveParser(filter: "0 1")
		let indexOld = parser2.currentTokenIndex
		XCTAssertThrowsError(try parser2.expect(token: .openParen))
		let indexNew = parser2.currentTokenIndex
		XCTAssertEqual(indexOld, indexNew)
		XCTAssertNoThrow(try parser2.expect(token: .numberLiteral("0")))
		XCTAssertNoThrow(try parser2.expect(token: .space))
		XCTAssertNoThrow(try parser2.expect(token: .numberLiteral("1")))
		XCTAssertNoThrow(try parser2.expect(token: .eof))
	}
	
	func testAttempt() throws {
		let parser = try RecursiveDescentPredictiveParser(filter: "0 1 2")
		
		XCTAssertFalse(try parser.attempt(token: .openParen))
		XCTAssertTrue(try parser.attempt(token: .numberLiteral("0")))
		
		XCTAssertFalse(try parser.attempt(token: .openParen))
		XCTAssertTrue(try parser.attempt(token: .space))
	}
	
	func testParseLogicalOperator() throws {
		let parser = try RecursiveDescentPredictiveParser(filter: "or and")
		
		var logicalOp = try parser.parseLogicalOperator()
		XCTAssertEqual(logicalOp, .or)
		XCTAssertNoThrow(try parser.expect(token: .space))
		logicalOp = try parser.parseLogicalOperator()
		XCTAssertEqual(logicalOp, .and)
		XCTAssertNoThrow(try parser.expect(token: .eof))
		
		for (expectedExpr, scimFilterString) in testCases_LogicalOperator {
			let parser = try RecursiveDescentPredictiveParser(filter: scimFilterString)
			let logicalOp = try parser.parseLogicalOperator()
			XCTAssertEqual(logicalOp, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParseAttributeIdentifier() throws {
		let parser = try RecursiveDescentPredictiveParser(filter: "0 abc")
		XCTAssertNoThrow(try parser.expect(token: .numberLiteral("0")))
		XCTAssertNoThrow(try parser.expect(token: .space))
		let attrIdentifier = try parser.parseAttributeIdentifier()
		XCTAssertEqual("abc", attrIdentifier)
		XCTAssertNoThrow(try parser.expect(token: .eof))
	}
	
	func testParseAttributePath() throws {
		var parser = try RecursiveDescentPredictiveParser(filter: "userName")
		var attrPath = try parser.parseAttributePath()
		XCTAssertEqual(attrPath, .init(schemaUrn: nil, attributeName: "userName", subAttributeName: nil))
		XCTAssertEqual(parser.currentToken, .eof)
		
		parser = try RecursiveDescentPredictiveParser(filter: "emails.type")
		attrPath = try parser.parseAttributePath()
		XCTAssertEqual(attrPath, .init(schemaUrn: nil, attributeName: "emails", subAttributeName: "type"))
		XCTAssertEqual(parser.currentToken, .eof)
		
		parser = try RecursiveDescentPredictiveParser(filter: "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:employeeNumber")
		attrPath = try parser.parseAttributePath()
		XCTAssertEqual(attrPath, .init(schemaUrn: "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User", attributeName: "employeeNumber", subAttributeName: nil))
		XCTAssertEqual(parser.currentToken, .eof)
		
		parser = try RecursiveDescentPredictiveParser(filter: "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:manager.value")
		attrPath = try parser.parseAttributePath()
		XCTAssertEqual(attrPath, .init(schemaUrn: "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User", attributeName: "manager", subAttributeName: "value"))
		XCTAssertEqual(parser.currentToken, .eof)
		
		for (expectedExpr, scimFilterString) in testCases_AttributePath {
			let parser = try RecursiveDescentPredictiveParser(filter: scimFilterString)
			let attrPath = try parser.parseAttributePath()
			XCTAssertEqual(attrPath, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParseComparativeOperator() throws {
		let parser = try RecursiveDescentPredictiveParser(filter: "eq ne gt co pr")
		
		XCTAssertEqual(try parser.parseComparativeOperator(), .eq)
		XCTAssertNoThrow(try parser.expect(token: .space))
		XCTAssertEqual(try parser.parseComparativeOperator(), .ne)
		XCTAssertTrue(try parser.attempt(token: .space))
		XCTAssertEqual(try parser.parseComparativeOperator(), .gt)
		XCTAssertTrue(try parser.attempt(token: .space))
		XCTAssertEqual(try parser.parseComparativeOperator(), .co)
		XCTAssertTrue(try parser.attempt(token: .space))
		XCTAssertThrowsError(try parser.parseComparativeOperator())
		
		for (expectedExpr, scimFilterString) in testCases_ComparativeOperator {
			let parser = try RecursiveDescentPredictiveParser(filter: scimFilterString)
			let compOp = try parser.parseComparativeOperator()
			XCTAssertEqual(compOp, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParseComparativeValue() throws {
		let parser = try RecursiveDescentPredictiveParser(filter: #"false null true 0 1 -0.1e2 "test\"test" false"#)
		
		XCTAssertEqual(try parser.parseComparativeValue(), .false)
		XCTAssertNoThrow(try parser.expect(token: .space))
		XCTAssertEqual(try parser.parseComparativeValue(), .null)
		XCTAssertNoThrow(try parser.expect(token: .space))
		XCTAssertEqual(try parser.parseComparativeValue(), .true)
		XCTAssertNoThrow(try parser.expect(token: .space))
		XCTAssertEqual(try parser.parseComparativeValue(), .number("0"))
		XCTAssertNoThrow(try parser.expect(token: .space))
		XCTAssertEqual(try parser.parseComparativeValue(), .number("1"))
		XCTAssertNoThrow(try parser.expect(token: .space))
		XCTAssertEqual(try parser.parseComparativeValue(), .number("-0.1e2"))
		XCTAssertNoThrow(try parser.expect(token: .space))
		XCTAssertEqual(try parser.parseComparativeValue(), .string("", #""test\"test""#))
		XCTAssertNoThrow(try parser.expect(token: .space))
		XCTAssertEqual(try parser.parseComparativeValue(), .false)
		
		for (expectedExpr, scimFilterString) in testCases_ComparativeValue {
			let parser = try RecursiveDescentPredictiveParser(filter: scimFilterString)
			let compValue = try parser.parseComparativeValue()
			XCTAssertEqual(compValue, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParseAttributeExpression() throws {
		for (expectedExpr, scimFilterString) in testCases_AttributeExpression {
			let parser = try RecursiveDescentPredictiveParser(filter: scimFilterString)
			let attrExp = try parser.parseAttributeExpression()
			XCTAssertEqual(attrExp, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParseValueFilterList() throws {
		for (expectedExpr, scimFilterString) in testCases_ValueFilterListExpression {
			let parser = try RecursiveDescentPredictiveParser(filter: scimFilterString)
			let valFilter = try parser.parseValueFilter()
			XCTAssertEqual(valFilter, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParseValuePath() throws {
		for (expectedExpr, scimFilterString) in testCases_ValuePathExpression {
			let parser = try RecursiveDescentPredictiveParser(filter: scimFilterString)
			let valFilter = try parser.parseValuePath()
			XCTAssertEqual(valFilter, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParseFilterList() throws {
		for (expectedExpr, scimFilterString) in testCases_FilterExpression {
			let parser = try RecursiveDescentPredictiveParser(filter: scimFilterString)
			let valFilter = try parser.parseFilterInternal()
			XCTAssertEqual(valFilter, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
		
		for (expectedExpr, scimFilterString) in testCases_FilterExpression {
			let parser = try RecursiveDescentPredictiveParser(filter: scimFilterString)
			let valFilter = try parser.parseFilter()
			XCTAssertEqual(valFilter, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParsePath() throws {
		let parser = try RecursiveDescentPredictiveParser(filter: "emails.")
		XCTAssertThrowsError(try parser.parsePath())
		
		for (expectedExpr, scimFilterString) in testCases_PathExpression {
			let parser = try RecursiveDescentPredictiveParser(filter: scimFilterString)
			let valFilter = try parser.parsePath()
			XCTAssertEqual(valFilter, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParseRfcExamples() throws {
		let filters: [String] = [
			#"userName eq "bjensen""#,
			#"name.familyName co "O'Malley""#,
			#"userName sw "J""#,
			#"urn:ietf:params:scim:schemas:core:2.0:User:userName sw "J""#,
			#"title pr"#,
			#"meta.lastModified gt "2011-05-13T04:42:34Z""#,
			#"meta.lastModified ge "2011-05-13T04:42:34Z""#,
			#"meta.lastModified lt "2011-05-13T04:42:34Z""#,
			#"meta.lastModified le "2011-05-13T04:42:34Z""#,
			#"title pr and userType eq "Employee""#,
			#"title pr or userType eq "Intern""#,
			#"schemas eq "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User""#,
			#"userType eq "Employee" and (emails co "example.com" or emails.value co "example.org")"#,
			#"userType ne "Employee" and not (emails co "example.com" or emails.value co "example.org")"#,
			#"userType eq "Employee" and (emails.type eq "work")"#,
			#"userType eq "Employee" and emails[type eq "work" and value co "@example.com"]"#,
			#"emails[type eq "work" and value co "@example.com"] or ims[type eq "xmpp" and value co "@foo.com"]"#,
		]
		
		for filter in filters {
			let parser = try RecursiveDescentPredictiveParser(filter: filter)
			let filterExpression = try parser.parseFilter()
			XCTAssertEqual(filter, filterExpression.scimFilterString)
		}
	}
}

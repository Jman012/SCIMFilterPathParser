import XCTest
@testable import SCIMFilterPathParser

final class RecursiveDescentBacktrackingParserTests: XCTestCase {	
	func testParseAttributeExpression() throws {		
		for (expectedExpr, scimFilterString) in testCases_AttributeExpression {
			let parser = try RecursiveDescentBacktrackingParser(filter: scimFilterString)
			let attrExp = try parser.parseAttributeExpression()
			XCTAssertEqual(attrExp, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParseValueFilterList() throws {
		for (expectedExpr, scimFilterString) in testCases_ValueFilterListExpression {
			let parser = try RecursiveDescentBacktrackingParser(filter: scimFilterString)
			let valFilter = try parser.parseValueFilter()
			XCTAssertEqual(valFilter, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParseValuePath() throws {
		for (expectedExpr, scimFilterString) in testCases_ValuePathExpression {
			let parser = try RecursiveDescentBacktrackingParser(filter: scimFilterString)
			let valFilter = try parser.parseValuePath()
			XCTAssertEqual(valFilter, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParseFilterList() throws {
		for (expectedExpr, scimFilterString) in testCases_FilterExpression {
			let parser = try RecursiveDescentBacktrackingParser(filter: scimFilterString)
			let valFilter = try parser.parseFilterInternal()
			XCTAssertEqual(valFilter, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
		
		for (expectedExpr, scimFilterString) in testCases_FilterExpression {
			let parser = try RecursiveDescentBacktrackingParser(filter: scimFilterString)
			let valFilter = try parser.parseFilter()
			XCTAssertEqual(valFilter, expectedExpr, scimFilterString)
			XCTAssertNoThrow(try parser.expect(token: .eof))
		}
	}
	
	func testParsePath() throws {
		let parser = try RecursiveDescentBacktrackingParser(filter: "emails.")
		XCTAssertThrowsError(try parser.parsePath()) { error in
			XCTAssertTrue((error as? RecursiveDescentBacktrackingParser.ParserError)?.message.contains("Could not parse the path (no viable option was found)") ?? false)
		}
		
		for (expectedExpr, scimFilterString) in testCases_PathExpression {
			let parser = try RecursiveDescentBacktrackingParser(filter: scimFilterString)
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
			let parser = try RecursiveDescentBacktrackingParser(filter: filter)
			let filterExpression = try parser.parseFilter()
			XCTAssertEqual(filter, filterExpression.scimFilterString)
		}
	}
}

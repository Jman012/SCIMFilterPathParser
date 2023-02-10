import XCTest
@testable import SCIMFilterPathParser

final class ExpressionTests: XCTestCase {

	func testLogicalOperatorCustomScimFilterStringConvertible() {
		for (expr, expected) in testCases_LogicalOperator {
			XCTAssertEqual(expected, expr.scimFilterString)
		}
	}
	
	func testAttributePathCustomScimFilterStringConvertible() {
		for (expr, expected) in testCases_AttributePath {
			XCTAssertEqual(expected, expr.scimFilterString)
		}
	}
	
	func testComparativeOperatorCustomScimFilterStringConvertible() {
		for (expr, expected) in testCases_ComparativeOperator {
			XCTAssertEqual(expected, expr.scimFilterString)
		}
	}
	
	func testComparativeValueCustomScimFilterStringConvertible() {
		for (expr, expected) in testCases_ComparativeValue {
			XCTAssertEqual(expected, expr.scimFilterString)
		}
	}
	
	func testAttributePresentExpressionCustomScimFilterStringConvertible() {
		for (expr, expected) in testCases_AttributePresentExpression {
			XCTAssertEqual(expected, expr.scimFilterString)
		}
	}
	
	func testAttributeComparisonExpressionCustomScimFilterStringConvertible() {
		for (expr, expected) in testCases_AttributeComparisonExpression {
			XCTAssertEqual(expected, expr.scimFilterString)
		}
	}
	
	func testAttributeExpressionCustomScimFilterStringConvertible() {
		for (expr, expected) in testCases_AttributeExpression {
			XCTAssertEqual(expected, expr.scimFilterString)
		}
	}
	
	func testValueFilterListExpressionCustomScimFilterStringConvertible() {
		for (expr, expected) in testCases_ValueFilterListExpression {
			XCTAssertEqual(expected, expr.scimFilterString)
		}
	}
	
	func testValuePathExpressionCustomScimFilterStringConvertible() {
		for (expr, expected) in testCases_ValuePathExpression {
			XCTAssertEqual(expected, expr.scimFilterString)
		}
	}
	
	func testFilterExpressionCustomScimFilterStringConvertible() {
		for (expr, expected) in testCases_FilterExpression {
			XCTAssertEqual(expected, expr.scimFilterString)
		}
	}
	
	func testPathExpressionCustomScimFilterStringConvertible() {
		for (expr, expected) in testCases_PathExpression {
			XCTAssertEqual(expected, expr.scimFilterString)
		}
	}
}

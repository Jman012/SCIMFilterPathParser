import Foundation

// Used in SCIM_RFC7644_LeftRecursionEliminatedV2.abnf for top-down parsing.
// Converts to FilterExpression.
internal struct FilterListExpression: Hashable {
	let start: FilterValueExpression
	let continued: [FilterListExpressionContinued]
	
	func toFilterExpression() -> FilterExpression {
		var filter = FilterExpression(anyExpr: FilterAnyExpression(anyExprs: [FilterAllExpression(allExprs: [self.start])]))
		var currentFilterAnyExprIndex = filter.anyExpr.anyExprs.startIndex
		
		for next in self.continued {
			if next.logicalOperator == .and {
				filter.anyExpr.anyExprs[currentFilterAnyExprIndex].allExprs.append(next.filter)
			} else {
				filter.anyExpr.anyExprs.append(FilterAllExpression(allExprs: [next.filter]))
				currentFilterAnyExprIndex = filter.anyExpr.anyExprs.index(after: currentFilterAnyExprIndex)
			}
		}
		
		return filter
	}
}

internal struct FilterListExpressionContinued: Hashable {
	let logicalOperator: LogicalOperator
	let filter: FilterValueExpression
}

// Used in SCIM_RFC7644_LeftRecursionEliminatedV2.abnf for top-down parsing.
// Converts to FilterExpression.
internal struct ValueFilterListExpression: Hashable {
	let start: ValueFilterValueExpression
	let continued: [ValueFilterListExpressionContinued]
	
	func toValueFilterExpression() -> ValueFilterExpression {
		var filter = ValueFilterExpression(anyExpr: ValueFilterAnyExpression(anyExprs: [ValueFilterAllExpression(allExprs: [self.start])]))
		var currentValueFilterAnyExprIndex = filter.anyExpr.anyExprs.startIndex
		
		for next in self.continued {
			if next.logicalOperator == .and {
				filter.anyExpr.anyExprs[currentValueFilterAnyExprIndex].allExprs.append(next.filter)
			} else {
				filter.anyExpr.anyExprs.append(ValueFilterAllExpression(allExprs: [next.filter]))
				currentValueFilterAnyExprIndex = filter.anyExpr.anyExprs.index(after: currentValueFilterAnyExprIndex)
			}
		}
		
		return filter
	}
}

internal struct ValueFilterListExpressionContinued: Hashable {
	let logicalOperator: LogicalOperator
	let filter: ValueFilterValueExpression
}

// Used in SCIM_RFC7644_StructuredPrecedence.abnf for bottom-up parsing.
internal struct FilterAnyListExpression: Hashable {
	
}

// Used in SCIM_RFC7644_StructuredPrecedence.abnf for bottom-up parsing.
internal struct FilterAllListExpression: Hashable {
	
}

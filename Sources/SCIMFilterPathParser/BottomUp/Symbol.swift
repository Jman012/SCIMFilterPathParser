import Foundation

enum Symbol: Hashable {
	case pathExpression(PathExpression)
	case filterExpression(FilterExpression)
	case filterAnyExpression(FilterAnyExpression)
	case filterAllExpression(FilterAllExpression)
	case filterValueExpression(FilterValueExpression)
	case valuePathExpression(ValuePathExpression)
	case valueFilterExpression(ValueFilterExpression)
	case valueFilterAnyExpression(ValueFilterAnyExpression)
	case valueFilterAllExpression(ValueFilterAllExpression)
	case valueFilterValueExpression(ValueFilterValueExpression)
	case attributeExpression(AttributeExpression)
	case attributePresentExpression(AttributePresentExpression)
	case attributeComparisonExpression(AttributeComparisonExpression)
	case comparativeValue(ComparativeValue)
	case comparativeOperator(ComparativeOperator)
	case attributePath(AttributePath)
}

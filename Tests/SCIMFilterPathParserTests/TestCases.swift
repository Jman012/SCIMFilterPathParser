import XCTest
@testable import SCIMFilterPathParser

let testCases_LogicalOperator: [(LogicalOperator, String)] = [
	(LogicalOperator.and, "and"),
	(LogicalOperator.or, "or"),
]

let testCases_AttributePath: [(AttributePath, String)] = [
	(.init(attributeName: "id"),
	 "id"),
	(.init(attributeName: "name", subAttributeName: "givenName"),
	 "name.givenName"),
	(.init(schemaUrn: "urn:ietf:params:scim:schemas:core:2.0:User", attributeName: "userName"),
	 "urn:ietf:params:scim:schemas:core:2.0:User:userName"),
	(.init(schemaUrn: "urn:ietf:params:scim:schemas:core:2.0:User", attributeName: "name", subAttributeName: "givenName"),
	 "urn:ietf:params:scim:schemas:core:2.0:User:name.givenName"),
]

let testCases_ComparativeOperator: [(ComparativeOperator, String)] = [
	(ComparativeOperator.eq, "eq"),
	(ComparativeOperator.ne, "ne"),
	(ComparativeOperator.co, "co"),
]

let testCases_ComparativeValue: [(ComparativeValue, String)] = [
	(ComparativeValue.false, "false"),
	(ComparativeValue.null, "null"),
	(ComparativeValue.true, "true"),
	(ComparativeValue.number("0.1"), "0.1"),
	(ComparativeValue.string("", "\"Hello!\""), "\"Hello!\""),
]

let testCases_AttributePresentExpression: [(AttributePresentExpression, String)] = [
	(.init(attributePath: .init(attributeName: "userName")),
	 "userName pr"),
]

let testCases_AttributeComparisonExpression: [(AttributeComparisonExpression, String)] = [
	(.init(
		attributePath: .init(attributeName: "userName"),
		comparativeOperator: .eq,
		comparativeValue: .string("", "\"testUser\"")),
	 #"userName eq "testUser""#),
]

let testCases_AttributeExpression: [(AttributeExpression, String)] = [
	(.present(AttributePresentExpression(attributePath: .init(attributeName: "userName"))),
	 "userName pr"),
	(.comparison(AttributeComparisonExpression(
		attributePath: .init(attributeName: "userName"),
		comparativeOperator: .eq,
		comparativeValue: .string("", "\"testUser\""))),
	 #"userName eq "testUser""#),
	(.present(.init(attributePath: .init(schemaUrn: "urn:test:test", attributeName: "userName"))),
	 "urn:test:test:userName pr"),
	(.present(.init(attributePath: .init(attributeName: "emails", subAttributeName: "type"))),
	 "emails.type pr"),
	(.comparison(.init(
		attributePath: .init(attributeName: "num"),
		comparativeOperator: .eq,
		comparativeValue: .number("3"))),
	 "num eq 3"),
	(.comparison(.init(
		attributePath: .init(attributeName: "externalId"),
		comparativeOperator: .ne,
		comparativeValue: .null)),
	 "externalId ne null"),
]

let testCases_ValueFilterListExpression: [(ValueFilterListExpression, String)] = [
	(.init(
		start: .attributeExpression(.present(.init(attributePath: .init(attributeName: "userName")))),
		continued: []),
	 "userName pr"),
	(.init(
		start: .groupedValueFilter(.init(
			start: .attributeExpression(.present(.init(attributePath: .init(attributeName: "userName")))),
			continued: [])),
		continued: []),
	 "(userName pr)"),
	(.init(
		start: .negatedGroupedValueFilter(.init(
			start: .attributeExpression(.present(.init(attributePath: .init(attributeName: "userName")))),
			continued: [])),
		continued: []),
	 "not (userName pr)"),
	(.init(
		start: .attributeExpression(.present(.init(attributePath: .init(attributeName: "userName")))),
		continued: [
			.init(
				logicalOperator: .and,
				filter: .attributeExpression(.present(.init(attributePath: .init(attributeName: "externalId"))))),
		]),
	 "userName pr and externalId pr"),
	(.init(
		start: .attributeExpression(.present(.init(attributePath: .init(attributeName: "userName")))),
		continued: [
			.init(
				logicalOperator: .or,
				filter: .attributeExpression(.comparison(.init(
					attributePath: .init(attributeName: "userName"),
					comparativeOperator: .eq,
					comparativeValue: .null))))
		]),
	 "userName pr or userName eq null"),
	(.init(
		start: .groupedValueFilter(.init(
			start: .attributeExpression(.present(.init(attributePath: .init(attributeName: "userName")))),
			continued: [
				.init(
					logicalOperator: .and,
					filter: .attributeExpression(.present(.init(attributePath: .init(attributeName: "emails"))))),
				.init(
					logicalOperator: .and,
					filter: .attributeExpression(.present(.init(attributePath: .init(attributeName: "externalId")))))
			])),
		continued: [
			.init(
				logicalOperator: .or,
				filter: .negatedGroupedValueFilter(.init(
					start: .attributeExpression(.comparison(.init(
						attributePath: .init(attributeName: "externalId"),
						comparativeOperator: .ne,
						comparativeValue: .string("", #""test""#)))),
					continued: [
					
					]))),
			.init(
				logicalOperator: .or,
				filter: .attributeExpression(.comparison(.init(
					attributePath: .init(attributeName: "userName"),
					comparativeOperator: .eq,
					comparativeValue: .string("", #""test@example.com""#))))),
		]), #"(userName pr and emails pr and externalId pr) or not (externalId ne "test") or userName eq "test@example.com""#),
]

let testCases_ValuePathExpression: [(ValuePathExpression, String)] = [
	(.init(
		attributePath: .init(schemaUrn: "urn:ietf:params:scim:schemas:core:2.0:User", attributeName: "emails"),
		valueFilterExpression: .init(
			start: .attributeExpression(.comparison(.init(
				attributePath: .init(attributeName: "type"),
				comparativeOperator: .eq,
				comparativeValue: .string("", #""work""#)))),
			continued: [])),
	 #"urn:ietf:params:scim:schemas:core:2.0:User:emails[type eq "work"]"#),
	// This is valid according to the loose grammar, but should never be able to be parsed or interpreted
	(.init(
		attributePath: .init(schemaUrn: "urn:ietf:params:scim:schemas:core:2.0:User", attributeName: "emails", subAttributeName: "subComplexAttr"),
		valueFilterExpression: .init(
			start: .attributeExpression(.comparison(.init(
				attributePath: .init(schemaUrn: "urn:test:test", attributeName: "type", subAttributeName: "nonExistent"),
				comparativeOperator: .eq,
				comparativeValue: .string("", #""work""#)))),
			continued: [])),
	 #"urn:ietf:params:scim:schemas:core:2.0:User:emails.subComplexAttr[urn:test:test:type.nonExistent eq "work"]"#),
]

let testCases_FilterExpression: [(FilterExpression, String)] = [
	(.init(anyExpr: .init(anyExprs: [
		.init(allExprs: [
			.attributeExpression(.present(.init(attributePath: .init(attributeName: "userName")))),
		])
	])),
	 "userName pr"),
	(.init(anyExpr: .init(anyExprs: [
		.init(allExprs: [
			.groupedFilter(.init(anyExpr: .init(anyExprs: [
				.init(allExprs: [
					.attributeExpression(.present(.init(attributePath: .init(attributeName: "userName"))))
				])
			])))
		])
	])),
	 "(userName pr)"),
	(.init(anyExpr: .init(anyExprs: [
		.init(allExprs: [
			.negatedGroupedFilter(.init(anyExpr: .init(anyExprs: [
				.init(allExprs: [
					.attributeExpression(.present(.init(attributePath: .init(attributeName: "userName"))))
				])
			])))
		])
	])),
	 "not (userName pr)"),
	(.init(anyExpr: .init(anyExprs: [
		.init(allExprs: [
			.valuePathExpression(.init(
				attributePath: .init(attributeName: "emails"),
				valueFilterExpression: .init(
					start: .attributeExpression(.comparison(.init(
						attributePath: .init(attributeName: "type"),
						comparativeOperator: .eq,
						comparativeValue: .string("", #""work""#)))),
					continued: [
						.init(logicalOperator: .and, filter: .attributeExpression(.comparison(.init(
							attributePath: .init(attributeName: "value"),
							comparativeOperator: .eq,
							comparativeValue: .string("", #""test@example.com""#))))),
					])))
		])
	])),
	 #"emails[type eq "work" and value eq "test@example.com"]"#),
	(.init(anyExpr: .init(anyExprs: [
		.init(allExprs: [
			.attributeExpression(.present(.init(attributePath: .init(attributeName: "userName")))),
			.attributeExpression(.present(.init(attributePath: .init(attributeName: "externalId")))),
		])
	])),
	 "userName pr and externalId pr"),
	(.init(anyExpr: .init(anyExprs: [
		.init(allExprs: [
			.attributeExpression(.present(.init(attributePath: .init(attributeName: "userName")))),
		]),
		.init(allExprs: [
			.attributeExpression(.comparison(.init(
				attributePath: .init(attributeName: "userName"),
				comparativeOperator: .eq,
				comparativeValue: .null)))
		])
	])),
	 "userName pr or userName eq null"),
	(.init(anyExpr: .init(anyExprs: [
		.init(allExprs: [
			.groupedFilter(.init(anyExpr: .init(anyExprs: [
				.init(allExprs: [
					.attributeExpression(.present(.init(attributePath: .init(attributeName: "userName")))),
					.attributeExpression(.present(.init(attributePath: .init(attributeName: "emails")))),
					.attributeExpression(.present(.init(attributePath: .init(attributeName: "externalId")))),
				])
			])))
		]),
		.init(allExprs: [
			.negatedGroupedFilter(.init(anyExpr: .init(anyExprs: [
				.init(allExprs: [
					.attributeExpression(.comparison(.init(
						attributePath: .init(attributeName: "externalId"),
						comparativeOperator: .ne,
						comparativeValue: .string("", #""test""#)))),
				])
			])))
		]),
		.init(allExprs: [
			.attributeExpression(.comparison(.init(
				attributePath: .init(attributeName: "userName"),
				comparativeOperator: .eq,
				comparativeValue: .string("", #""test@example.com""#)))),
		]),
	])),
	 #"(userName pr and emails pr and externalId pr) or not (externalId ne "test") or userName eq "test@example.com""#),
	(.init(anyExpr: .init(anyExprs: [
		.init(allExprs: [
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "a"), comparativeOperator: .eq, comparativeValue: .number("1")))),
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "b"), comparativeOperator: .eq, comparativeValue: .number("2")))),
		]),
		.init(allExprs: [
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "c"), comparativeOperator: .eq, comparativeValue: .number("3")))),
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "d"), comparativeOperator: .eq, comparativeValue: .number("4")))),
		]),
		.init(allExprs: [
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "e"), comparativeOperator: .eq, comparativeValue: .number("5")))),
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "f"), comparativeOperator: .eq, comparativeValue: .number("6")))),
		]),
	])),
	 "a eq 1 and b eq 2 or c eq 3 and d eq 4 or e eq 5 and f eq 6"),
	(.init(anyExpr: .init(anyExprs: [
		.init(allExprs: [
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "a"), comparativeOperator: .eq, comparativeValue: .number("1")))),
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "b"), comparativeOperator: .eq, comparativeValue: .number("2")))),
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "c"), comparativeOperator: .eq, comparativeValue: .number("3")))),
		]),
		.init(allExprs: [
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "d"), comparativeOperator: .eq, comparativeValue: .number("4")))),
		]),
		.init(allExprs: [
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "e"), comparativeOperator: .eq, comparativeValue: .number("5")))),
		]),
		.init(allExprs: [
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "f"), comparativeOperator: .eq, comparativeValue: .number("6")))),
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "g"), comparativeOperator: .eq, comparativeValue: .number("7")))),
		]),
	])),
	 "a eq 1 and b eq 2 and c eq 3 or d eq 4 or e eq 5 or f eq 6 and g eq 7"),
	(.init(anyExpr: .init(anyExprs: [
		.init(allExprs: [
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "a"), comparativeOperator: .eq, comparativeValue: .number("1")))),
		]),
		.init(allExprs: [
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "b"), comparativeOperator: .eq, comparativeValue: .number("2")))),
		]),
		.init(allExprs: [
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "c"), comparativeOperator: .eq, comparativeValue: .number("3")))),
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "d"), comparativeOperator: .eq, comparativeValue: .number("4")))),
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "e"), comparativeOperator: .eq, comparativeValue: .number("5")))),
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "f"), comparativeOperator: .eq, comparativeValue: .number("6")))),
		]),
		.init(allExprs: [
			.attributeExpression(.comparison(.init(attributePath: .init(attributeName: "g"), comparativeOperator: .eq, comparativeValue: .number("7")))),
		]),
	])),
	 "a eq 1 or b eq 2 or c eq 3 and d eq 4 and e eq 5 and f eq 6 or g eq 7"),
]

let testCases_PathExpression: [(PathExpression, String)] = [
	(PathExpression.attributePath(.init(attributeName: "userName")),
	 "userName"),
	(PathExpression.valuePathExpression(.init(
		attributePath: .init(attributeName: "emails"),
		valueFilterExpression: .init(
			start: .attributeExpression(.comparison(.init(
				attributePath: .init(attributeName: "type"),
				comparativeOperator: .eq,
				comparativeValue: .string("", #""work""#)))),
			continued: [])), nil),
	 #"emails[type eq "work"]"#),
	(PathExpression.valuePathExpression(.init(
		attributePath: .init(attributeName: "emails"),
		valueFilterExpression: .init(
			start: .attributeExpression(.comparison(.init(
				attributePath: .init(attributeName: "type"),
				comparativeOperator: .eq,
				comparativeValue: .string("", #""work""#)))),
			continued: [])), "value"),
	 #"emails[type eq "work"].value"#),
	(PathExpression.attributeExpression(.comparison( .init(
		attributePath: .init(attributeName: "schemas"),
		comparativeOperator: .eq,
		comparativeValue: .string("", #""urn:test:test""#)))),
	 #"schemas eq "urn:test:test""#),
]

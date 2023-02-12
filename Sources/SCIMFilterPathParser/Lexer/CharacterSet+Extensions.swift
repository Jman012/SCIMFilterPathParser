import Foundation

extension CharacterSet {
	static var abnfAlphas = CharacterSet(charactersIn: Unicode.Scalar(0x41)...Unicode.Scalar(0x5A)) // A-Z
		.union(CharacterSet(charactersIn: Unicode.Scalar(0x61)...Unicode.Scalar(0x7A))) // a-z
	
	static var abnfDigits = CharacterSet(charactersIn: Unicode.Scalar(0x30)...Unicode.Scalar(0x39)) // 0-9
	
	static var abnfHexDigits = abnfDigits // 0-9
		.union(CharacterSet(charactersIn: Unicode.Scalar(0x41)...Unicode.Scalar(0x46))) // A-F
		.union(CharacterSet(charactersIn: Unicode.Scalar(0x61)...Unicode.Scalar(0x66))) // a-f
	
	// See /Docs/AppliedGrammars/URI_RFC3986.abnf
	static var uriSubDelims = CharacterSet([
		"!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
	])
	
	// See /Docs/AppliedGrammars/URI_RFC3986.abnf
	static var uriUnreserveds = abnfAlphas
		.union(abnfDigits)
		.union(CharacterSet([
			"-", ".", "_", "~"
		]))

	// See /Docs/AppliedGrammars/URI_RFC3986.abnf
	static var uriPctEncodeds = abnfHexDigits
		.union(CharacterSet([
			"%"
		]))
	
	// See /Docs/AppliedGrammars/URI_RFC3986.abnf
	static var uriPchars = uriUnreserveds
		.union(uriPctEncodeds)
		.union(uriSubDelims)
		.union(CharacterSet([
			":", "@"
		]))
	
	// See /Docs/AppliedGrammars/URI_RFC3986.abnf
	static var uriFragments = uriUnreserveds
		.union(uriPchars)
		.union(CharacterSet([
			"/", "?"
		]))
	
	// See /Docs/AppliedGrammars/URN_RFC8141.abnf
	static var urnFComponents = uriFragments
	
	// See /Docs/AppliedGrammars/URN_RFC8141.abnf
	static var urnQComponents = uriPchars
		.union(CharacterSet([
			"/", "?"
		]))
	
	// See /Docs/AppliedGrammars/URN_RFC8141.abnf
	static var urnRComponents = uriPchars
		.union(CharacterSet([
			"/", "?"
		]))
	
	// See /Docs/AppliedGrammars/URN_RFC8141.abnf
	static var urnRQComponents = urnRComponents
		.union(urnQComponents)
		.union(CharacterSet([
			"?", "+"
		]))
	
	// See /Docs/AppliedGrammars/URN_RFC8141.abnf
	static var urnNSS = uriPchars
		.union(CharacterSet([
			"/"
		]))
	
	// See /Docs/AppliedGrammars/URN_RFC8141.abnf
	static var urnLdh = abnfAlphas
		.union(abnfDigits)
		.union(CharacterSet([
			"-"
		]))
	
	// See /Docs/AppliedGrammars/URN_RFC8141.abnf
	static var urnNID = abnfAlphas
		.union(abnfDigits)
		.union(urnLdh)
	
	// See /Docs/AppliedGrammars/URN_RFC8141.abnf
	static var urnAssignedName = urnNID
		.union(urnNSS)
		.union(CharacterSet([
			":"
		]))
	
	// See /Docs/AppliedGrammars/URN_RFC8141.abnf
	static var urnNamestring = urnAssignedName
		.union(urnRQComponents)
		.union(urnFComponents)
		.union(CharacterSet([
			"#"
		]))
	
	// See /Docs/AppliedGrammars/JSON_RFC7159.abnf
	static var jsonValues = CharacterSet(charactersIn: "false")
		.union(CharacterSet(charactersIn: "null"))
		.union(CharacterSet(charactersIn: "true"))
	
	// See /Docs/AppliedGrammars/SCIM_RFC7644.abnf
	static var scimAttrName = abnfAlphas
		.union(abnfDigits)
		.union(CharacterSet([
			"-", "_"
		]))
	
	static var scimAttrNameJsonValuesUrnNamestring = scimAttrName
		.union(jsonValues)
		.union(urnNamestring)
}

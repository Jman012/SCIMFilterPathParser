import Foundation

extension Character {
	var isAbnfAlpha: Bool {
		return isMemberOf(CharacterSet.abnfAlphas)
	}
	
	var isAbnfDigit: Bool {
		return isMemberOf(CharacterSet.abnfDigits)
	}
	
	var isAbnfHexDig: Bool {
		return isMemberOf(CharacterSet.abnfHexDigits)
	}
	
	func isMemberOf(_ charSet: CharacterSet) -> Bool {
		return charSet.isSuperset(of: CharacterSet(self.unicodeScalars))
	}
}

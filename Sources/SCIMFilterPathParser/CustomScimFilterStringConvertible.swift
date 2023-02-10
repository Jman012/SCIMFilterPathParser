import Foundation

public protocol CustomScimFilterStringConvertible {
	var scimFilterString: String { get }
}

extension Array: CustomScimFilterStringConvertible where Element: CustomScimFilterStringConvertible {
	public var scimFilterString: String {
		return self.map({ $0.scimFilterString }).joined(separator: " ")
	}
}

import Foundation

public class RecursiveAscentParser {
	
	let lexer: Lexer
	
	init(filter: String) {
		lexer = Lexer(inputString: filter)
	}
}

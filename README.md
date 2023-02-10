# SCIM Filter & Path Parser

This is an exercise in building a parser for the SCIM protocol filters and paths
grammar in the Swift programming language.

The 

**Disclaimer**: This code has unit tests but should not be considered 
production-ready without further analysis and testing. 

## References

The grammar is sourced primarily from

- SCIM Protocol Specification [RFC 7644](https://www.rfc-editor.org/rfc/rfc7644) 
  - Filtering [Section 3.4.2.2](https://www.rfc-editor.org/rfc/rfc7644#section-3.4.2.2)
  - Modifying with PATCH [Section 3.5.2](https://www.rfc-editor.org/rfc/rfc7644#section-3.5.2)

With additional grammar specificatons and information from

- JSON Data Interchange Format [RFC 7159](https://www.rfc-editor.org/rfc/rfc7159)
  - Referred to in the SCIM filter/path grammar for value literals.
  - Values [Section 3](https://www.rfc-editor.org/rfc/rfc7159#section-3)
  - Numbers [Section 6](https://www.rfc-editor.org/rfc/rfc7159#section-6)
  - Strings [Section 7](https://www.rfc-editor.org/rfc/rfc7159#section-7)
- URI Generic Syntax [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986)
  - Referred to in the official SCIM filter/path grammar for URN identifier prefixes.
  - Not used in revised grammar in this project.
  - Collected ABNF for URI [Appendix A](https://www.rfc-editor.org/rfc/rfc3986#appendix-A)
- URN Syntax [RFC 2141](https://www.rfc-editor.org/rfc/rfc2141)
  - Originally referred to from RFC 3986, but obsoleted by the preferred RFC 8141 below.
- URNs [RFC 8141](https://www.rfc-editor.org/rfc/rfc8141.html)
  - Latest and more correct syntax for URNs, obsoleting RFC 2141 above.
  - Used in revised grammar in this project.
  - URN Syntax [Section 2](https://www.rfc-editor.org/rfc/rfc8141.html#section-2)
- SCIM Core Schema [RFC 7643](https://www.rfc-editor.org/rfc/rfc7643)
  - Additional context for the reasoning behind the specified SCIM filter/path grammar.

## Grammar

### Original Grammar

The following is the original collected 
[ABNF](https://en.wikipedia.org/wiki/Augmented_Backus%E2%80%93Naur_form) grammar
for RFC 7644.

```abnf
; https://www.rfc-editor.org/rfc/rfc7644#section-3.4.2.2

FILTER    = attrExp / logExp / valuePath / *1"not" "(" FILTER ")"

valuePath = attrPath "[" valFilter "]"
			; FILTER uses sub-attributes of a parent attrPath

valFilter = attrExp / logExp / *1"not" "(" valFilter ")"

attrExp   = (attrPath SP "pr") /
			(attrPath SP compareOp SP compValue)

logExp    = FILTER SP ("and" / "or") SP FILTER

compValue = false / null / true / number / string
			; rules from JSON (RFC 7159)

compareOp = "eq" / "ne" / "co" /
				"sw" / "ew" /
				"gt" / "lt" /
				"ge" / "le"

attrPath  = [URI ":"] ATTRNAME *1subAttr
			; SCIM attribute name
			; URI is SCIM "schema" URI

ATTRNAME  = ALPHA *(nameChar)

nameChar  = "-" / "_" / DIGIT / ALPHA

subAttr   = "." ATTRNAME
			; a sub-attribute of a complex attribute


; https://www.rfc-editor.org/rfc/rfc7644#section-3.5.2

PATH      = attrPath / valuePath [subAttr]
```

The following sections describe considered errata and further revisions to the
grammar for use in this project. The aim is to have a more specific and correct
grammar with which to implement.

### Core Revisions

#### Errata

The following Errata exist on RFC 7644, and they are taken into account in the
revised SCIM filter/path grammar used in this project.

- [Errata 7319](https://www.rfc-editor.org/errata/eid7319)
  - Reported by the author of this project.
  - Adds an optional `SP` (space) between `"not"` and `"("` in the `FILTER` and
    `valFilter` nonterminal symbols.
  - This was included in the revised grammar, in order to comply with the specified
    examples in Section 3.4.2.2, as well as to comply with how most other parsers
    for this grammar are designed to work.
- [Errata 4690](https://www.rfc-editor.org/errata/eid4690)
  - Reported by one of the authors of RFC 7644.
  - Separates the `logExp` nonterminal symbol into a new `valLogExp` for use in 
    `valFilter`, in order to prevent accidental illegal recursion.
  - This is because SCIM restricts complex attributes to only contain non-complex
    sub-attributes in schemas, and thus making it invalid to require 
    nested/recurred filters.
  - This was included in the revised grammar, in order to more accurately model 
    filter expressions and disallow invalid filters.
- [Errata 7122](https://www.rfc-editor.org/errata/eid7122)
  - Adds the `attrExp` nonterminal symbol as an option for the `PATH`.
  - This is in order to allow for the logic in 
    [RFC 7644 Section 3.5.2.2](https://www.rfc-editor.org/rfc/rfc7644#section-3.5.2.2)
    to be made possible.
  - This was included in the revised grammar.
- [Errata 4670](https://www.rfc-editor.org/errata/eid4670)
  - Clarifies the order of precedence in operators for for SCIM filters and paths.
  - This is not explicitly taken into account in the revised grammar, but is
    considered in the implementation of the expression representation and parser
    logic.

#### Further Revisions

- Extension of Errata 4690
  - The original Errata 4690 introduces `valLogExp = attrExp SP ("and" / "or") SP attrExp`
  - However, this would restrict the level of recursion for value filters.
  - For example, this filter would be illegal according to Errata 4690:
    - `emails[type eq "work" or (type eq "home" and value ew "@example.com")]`
  - The revised version is `valLogExp = valFilter SP ("and" / "or") SP valFilter`
    to allow for recursion.
  - This was later submitted as a correction to Errata 4690 as 
    [Errata 7322](https://www.rfc-editor.org/errata/eid7322).
- URIs and URNs
  - Disregard the reference to `URI` with RFC 3986 in the `attrPath` nonterminal symbol.
  - According to the specification, any URI *must* be a URN. So, for example, an
    HTTP URL would be technically invalid.
  - Instead, the revised grammar refers to the URN's `namestring` in RFC 8141,
    for a more specific and targeted overall grammar. This reduces the surface for
    grammatically valid but illegally constructed SCIM filters.
    
### Revised Grammar

The following grammar has revisions according to the above, and stays true to
the original intent of RFC 7644.

```abnf
; https://www.rfc-editor.org/rfc/rfc7644#section-3.4.2.2

FILTER    = attrExp / logExp / valuePath / ["not" [SP]] "(" FILTER ")"

valuePath = attrPath "[" valFilter "]"
			; FILTER uses sub-attributes of a parent attrPath

valFilter = attrExp / valLogExp / ["not" [SP]] "(" valFilter ")"

valLogExp = valFilter SP ("and" / "or") SP valFilter

attrExp   = (attrPath SP "pr") /
			(attrPath SP compareOp SP compValue)

logExp    = FILTER SP ("and" / "or") SP FILTER

compValue = false / null / true / number / string
			; rules from JSON (RFC 7159)

compareOp = "eq" / "ne" / "co" /
				"sw" / "ew" /
				"gt" / "lt" /
				"ge" / "le"

attrPath  = [namestring ":"] ATTRNAME *1subAttr
			; SCIM attribute name
			; namestring is from URN RFC 8141

ATTRNAME  = ALPHA *(nameChar)

nameChar  = "-" / "_" / DIGIT / ALPHA

subAttr   = "." ATTRNAME
			; a sub-attribute of a complex attribute


; https://www.rfc-editor.org/rfc/rfc7644#section-3.5.2

PATH      = attrPath / valuePath [subAttr] / attrExp
```

### Elimination of Left Recursion

The original and revised grammars are not LL(1). In order to build a top-down 
recursive-descent parser, the grammar must be converted to LL(1) by eliminating
left recursion in the grammar.

[Algorithmic techniques](https://en.wikipedia.org/wiki/Left_recursion#Removing_left_recursion)
to eliminate left recursion, in this instance, led to a legal but undesirable
grammar that is difficult to make sense of or to model after in code. After
analysis and trial-and-error, in addition to the use of several useful tools,
the following changes were chosen.

Original:
```abnf
FILTER    = attrExp / logExp / valuePath / ["not" [SP]] "(" FILTER ")"
logExp    = FILTER SP ("and" / "or") SP FILTER

valFilter = attrExp / valLogExp / ["not" [SP]] "(" valFilter ")"
valLogExp = valFilter SP ("and" / "or") SP valFilter
```

Revised:
```abnf
FILTER          = filterValue *(SP ("and" / "or") filterValue)
filterValue     = attrExp / valuePath / ["not" [SP]] "(" FILTER ")"

valFilter       = valFilterValue *(SP ("and" / "or") valFilterValue)
valFilterValue  = attrExp / ["not" [SP]] "(" valFilter ")"
```

The logical expression nonterminal symbols `logExp` and `valLogExp` were removed.
The "and/or" structure was moved upward into the higher-level `FILTER` and 
`valFilter` symbols as a list of values. And the types of values were moved from
`FILTER` and `valFilter` down into new `filterValue` and `valFilterValue` symbols.

This has a benefit during parsing. The original grammar enforced an ambiguous
tree structure that was enforced at the grammar level. A flat list of mixed "and"s
and "or"s could have any tree structure during parsing, and would be difficult
to untangle. However, by specifying the grammar as a list of additional `filterValues`
connected with and/or logical operators, post-processing can be done to determine
the correct hierarchical structure.

Full grammar without left recursion:
```abnf
; https://www.rfc-editor.org/rfc/rfc7644#section-3.4.2.2

FILTER          = filterValue *(SP ("and" / "or") filterValue)
filterValue     = attrExp / valuePath / ["not" [SP]] "(" FILTER ")"

valuePath       = attrPath "[" valFilter "]"
				; FILTER uses sub-attributes of a parent attrPath

valFilter       = valFilterValue *(SP ("and" / "or") valFilterValue)
valFilterValue  = attrExp / ["not" [SP]] "(" valFilter ")"

attrExp         = (attrPath SP "pr") /
				  (attrPath SP compareOp SP compValue)

compValue       = false / null / true / number / string
				  ; rules from JSON (RFC 7159)

compareOp       = "eq" / "ne" / "co" /
					"sw" / "ew" /
					"gt" / "lt" /
					"ge" / "le"

attrPath        = [namestring ":"] ATTRNAME *1subAttr
				; SCIM attribute name
				; namestring is from URN RFC 8141

ATTRNAME        = ALPHA *(nameChar)

nameChar        = "-" / "_" / DIGIT / ALPHA

subAttr         = "." ATTRNAME
				; a sub-attribute of a complex attribute


; https://www.rfc-editor.org/rfc/rfc7644#section-3.5.2

PATH            = attrPath / valuePath [subAttr] / attrExp
```

The aforementioned useful online tools:
- http://smlweb.cpsc.ucalgary.ca
- https://cyberzhg.github.io/toolbox/left_rec
- https://lab.brainonfire.net/CFG/remove-left-recursion.html

## Implementation

### Lexer

The lexer for this project was surprisingly difficult to construct. As with all
grammars, deciding where to separate the tokens from the symbols can be tricky.
This determines how the split is done between grammar parsing and more simple
character recognition. For instance, when a language contains comlex character 
combinations for operators like `<`, `<=`, `<<=`, etc. The SCIM filter/path 
grammar does not have that kind of complexity. However, the difficulty comes in
with the use of URNs, and how there is no clear separation of a URN and an
`ATTRNAME`.

SCIM structures an attribute path (`attrPath`) as an optional URN schema identifier,
followed by the name of the attribute, optionally followed by the name of a 
sub-attribute.

```abnf
attrPath        = [namestring ":"] ATTRNAME *1subAttr
```

The divider between the URN `namestring` and the `ATTRNAME`, however, is a colon
(`:`). The colon is also used as a separator *within* the URN itself.

An `attrPath` can be as simple as `emails`, or as complex as
`urn:ietf:params:scim:schemas:core:2.0:User:emails.type`. It is easy enough to
separate out the `subAttr` ("type") and the dividing dot character. But then you
are left with what looks like a vald URN. However, it's a URN 
`urn:ietf:params:scim:schemas:core:2.0:User` following by a colon and the `ATTRNAME`
or "emails". 

When a lexer is going through the input stream of characters, it would consume
all of the characters that are valid for an `ATTRNAME` and a URN `namestring`,
and thus consume through to to the end of `:emails.type`, because the colon and
dot are valid characters for a URN. Typically, one might see a dividing character
between the URN and following tokens where the character is *not* a valid URN
character.

So, this lexer has to backtrack after consuming a whole valid URN in order to
un-consume the `subAttr`, the dot, the `ATTRNAME`, and the dividing colon. This
is where the majority of the complexity comes in. It also has to check to make
sure that the remaining URN is still valid, however. A URN starts with a `urn:`
followed by the NID, another colon, and finally the NSS. The NSS is what is allowed
to contain so many special characters. The string `urn:nid:nss.subAttr` might
invalidly be split into a URN of `urn:nid`, an ATTRNAME of `nss`, and a subAttr
of `subAttr` where the URN is not legal. This has to be taken into account properly.

Note that this does blur the line with the grammar compared to the parser. It is
not completely isolated to a small subset of the terminal and nonterminal symbols
in the grammar. It has knowledge of the `attrPath` symbol in order to better
generate the correct tokens, so that the parser doesn't have to split a longer
string of characters correctly.

This lexer was chosen to include a full URN as a token in order to simplify the
role of the parser. Another option was to have the lexer produce colon tokens and
identifiers, such that the parser could assemble them into a URN later, if valid.
It may lead to other complications, though, because if dots are a token, that would
divide the URN (dots are allowed in URNs as well). Then the parser would have to
consume a mixture of identifiers, colons, *and* number literals and transform them
back into strings. This seems like a bit much for the parser.

Otherwise, the rest of the lexer is msotly straightforward. There is some support
for pushing/popping snapshots in order to be able to backtrack along with the
parser nicely.

### Parsers

#### Recursive Descent Backtracking Parser

This is the current/first parser written for this project. A recursive descent
parser was chosen due to the ease of programming and understanding it. The
backtracking aspect also lead to a clearer set of code that doesn't take too
much to understand and correlate it to the chosen grammar.

The fact this is a top-down parser, as implied by the fact that it's a recursive
descent parser, requires that the grammar not contain left recursion. The details
on eliminating the left recursion is explained further above.

With the complexity of the lexer in assembling and tokenizing the URNs for us,
the parser itself was able to stay fairly straightforward. There are a set of
helper methods to handle common/simple operations more succinctly, and then a
set of methods that correlate closely to each nonterminal symbol in the grammar.

#### Recursive Descent Lookahead Parser

There are plans to make a lookahead, as opposed to backtracking, parser as well.
It would likely be the new "base" parser, which the backtracking parser can
extend off of and redo some of the methods to be backtracking at a higher level,
while leaving the simpler parsing methods on this base class for lookahead parsing.

#### Recusive Ascent/Bottom-Up Parser

It would also be exciting to try hand-writing a bottom up parser, as practice.
This has yet to be researched.

## Comparison with Other Parsers

### [imulab/go-scim](https://github.com/imulab/go-scim)

The parser in the go-scim library has some limitations, chiefly the fact that it
seems to not be able to handle the `valuePath` symbol in the grammar, and some
examples of nested grouped filters. These either throw errors when parsing, or 
result in a panic.

It also has a less-clear division between the lexing/scanning and the parsing,
relying on what appears to be a state machine to keep track of what it's doing.

Otherwise, it mentions the shunting yard algorithm for creating expressions. I
am less familiar with this and overall the structure of this parser, so it is
difficult to classify and describe.

### [scim2/filter-parser](https://github.com/scim2/filter-parser)

This parser thankfully has some docs that describe the revised grammar it uses
more specifically than the one in the RFC, much like this project does. It is 
located at https://github.com/scim2/filter-parser/blob/master/internal/spec/grammar.pegn

Of note, it makes the "and"/"or" precedence explicit in the grammar, with this
structure:

```pegn
Filter          <- FilterOr
FilterOr       <-- FilterAnd (SP+ Or SP+ FilterAnd)*
FilterAnd      <-- FilterValue (SP+ And SP+ FilterValue)*
FilterNot      <-- Not SP* FilterParen
FilterValue     <- ValuePath / AttrExp / FilterNot / FilterParen
FilterParen     <- '(' SP* FilterOr 'SP* )'
```

The limitation here is that this grammar is unable to parse:

```scim
a or b and c or d and e
```

due to the lack of recursion back up to `Filter` or `FilterOr` from the lower 
paths. Instead, it would require the use of parentheses for nesting expressions.
This was attempted for this project, but adding `FilterOr` as an option to the 
`FilterValue` symbol lead to lead recursion again. That said, there likely is a 
good solution to make this not left-recursive, and to preserve this form of
enforcing the precedence, which is desired. 

Otherwise, it seems to use [di-wu/parser](https://github.com/di-wu/parser) as
the basis for the parsing engine. It is made by the same author. It does not
mention what type of parser this is, explicitly.

# Coverage Taxonomy — BrightScript + SceneGraph

This file is the **EBNF-derived coverage taxonomy** for the ast-grep BrightScript/SceneGraph
project. It is the human-readable companion to the machine-readable `coverage.json`; both enumerate
the *same leaves*.

## What "coverage" means here (read this first)

Coverage is **exhaustive over the dimensions of operating on / invoking a construct**, NOT over data
values. We do not test "an array holding many numbers"; we enumerate every *grammar position* an
array (or any construct) can occupy, derived from the EBNF rules where it appears.

> Example (array): `ArrayLiteral` ([], nested, multiline, trailing comma), `IndexSuffix` read
> `a[i]`, index write `a[i]=x` (`AssignTarget`), multi-subscript `a[i,j]` (after `DimStatement`),
> optional-index `a?[i]` (`OC_BRACKET`), compound-assign `a[i]+=1` (`CompoundAssignStatement`),
> inc/dec `a[i]++` (`IncDecStatement`), member-chain `a[i].f` (`MemberSuffix`), as a call argument
> (`ArgumentList`), as a return value (`ReturnStatement`), in a `for each` (`ForEachStatement`).
> That whole set is the array's *dimensionality*.

We apply this method to **every** construct in `brightscript.ebnf` and `scenegraph.ebnf`.

## Field schema (every leaf has these)

| field             | meaning                                                                                 |
|-------------------|-----------------------------------------------------------------------------------------|
| `id`              | dotted stable identifier, e.g. `array.index.multisub`                                    |
| `kind`            | the **exact EBNF rule name** the leaf exercises (becomes a tree-sitter node kind / ast-grep `kind`) |
| `layer`           | `brightscript` or `scenegraph`                                                           |
| `dimension`       | one-line statement of *which way of operating on the construct* this leaf covers          |
| `snippet`         | minimal source illustrating it                                                           |
| `device_testable` | `true` if it can run on a Roku and self-check; `false` for purely syntactic / negative cases |
| `expect`          | what should happen: `parse` (valid, parses), `value:<v>` (runtime self-check), or `error` (negative — device/grammar rejects) |
| `negative`        | present and `true` only for the NEGATIVE section (device REJECTS; grammar should emit ERROR) |

`expect: value:<v>` leaves are the on-device self-checking ones (the harness asserts the runtime
result equals `<v>`); `expect: parse` leaves are syntactic — they must parse without an ERROR node,
but a no-op at runtime. `expect: error` leaves are the negative corpus.

The `id` namespace is the organizing index. Top-level groups follow the EBNF Parts:
`lex.*` (Part 1), `decl.*` (Part 2), `stmt.*` (Part 3), `cc.*` (Part 4), `expr.*` (Part 5),
`sg.*` (SceneGraph layers 1 & 2), and `neg.*` (the negative corpus).

---

# Part 1 — Lexical grammar (tokens)

The lexer-level dimensions: each token *shape* the scanner must distinguish (maximal-munch),
plus the case-insensitivity and significant-newline quirks the EBNF implementer notes call out.

## 1.1 Identifiers & type-designator suffixes — `Identifier`, `TypeSuffix`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `lex.ident.plain` | `Identifier` | bare identifier, letters/digits/underscore | `foo_1 = 1` | true | value:1 |
| `lex.ident.leading_underscore` | `IdentStart` | identifier starting with `_` | `_x = 2` | true | value:2 |
| `lex.ident.suffix.string` | `TypeSuffix` | `$` String designator | `s$ = "a"` | true | value:a |
| `lex.ident.suffix.integer` | `TypeSuffix` | `%` Integer designator | `n% = 3` | true | value:3 |
| `lex.ident.suffix.float` | `TypeSuffix` | `!` Float designator | `f! = 1.5` | true | value:1.5 |
| `lex.ident.suffix.double` | `TypeSuffix` | `#` Double designator | `d# = 1.0` | true | value:1 |
| `lex.ident.suffix.longint` | `TypeSuffix` | `&` LongInteger designator (OS 7.0+) | `g& = 4` | true | value:4 |
| `lex.ident.case_insensitive` | `Identifier` | same var, mixed case binds (case-insensitive) | `Foo = 5 : x = fOO` | true | value:5 |
| `lex.ident.m_keyword` | `Primary` | the implicit instance AA `m` used as a primary | `m.x = 6` | true | value:6 |

## 1.2 Numeric literals — `NumericLiteral` (every lexical shape)

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `lex.num.int.dec` | `IntegerLiteral` | decimal integer | `x = 42` | true | value:42 |
| `lex.num.int.hex` | `HexLiteral` | `&h` hex integer | `x = &hFF` | true | value:255 |
| `lex.num.int.hex_upper` | `HexLiteral` | `&H` uppercase prefix | `x = &H10` | true | value:16 |
| `lex.num.longint.dec` | `LongIntegerLiteral` | decimal with `&` suffix (OS 7.0+) | `x = 5000000000&` | true | value:5000000000 |
| `lex.num.longint.hex` | `LongIntegerLiteral` | hex with `&` suffix | `x = &hFF&` | true | value:255 |
| `lex.num.float.point` | `FloatLiteral` | decimal point form | `x = 3.14` | true | parse |
| `lex.num.float.leading_dot` | `FloatLiteral` | leading-dot form `.5` | `x = .5` | true | value:0.5 |
| `lex.num.float.exp` | `FloatLiteral` | `E` exponent | `x = 1e3` | true | value:1000 |
| `lex.num.float.suffix` | `FloatLiteral` | `!` Float suffix on integer shape | `x = 5!` | true | value:5 |
| `lex.num.double.exp` | `DoubleLiteral` | `D` exponent | `x = 1d2` | true | value:100 |
| `lex.num.double.suffix` | `DoubleLiteral` | `#` Double suffix | `x = 5#` | true | value:5 |
| `lex.num.double.tendigit` | `DoubleLiteral` | 10+ digit constant inferred Double | `x = 1234567890.0` | true | parse |
| `lex.num.maximal_munch` | `NumericLiteral` | longest-match: `&hFF&` is one token not `&hFF`+`&` | `x = &hFF&` | true | value:255 |

## 1.3 String literals — `StringLiteral`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `lex.str.basic` | `StringLiteral` | basic double-quoted string | `s = "hello"` | true | value:hello |
| `lex.str.empty` | `StringLiteral` | empty string | `s = ""` | true | value: |
| `lex.str.escaped_quote` | `EscapedQuote` | embedded `""` is an escaped quote | `s = "a""b"` | true | value:a"b |
| `lex.str.no_backslash_escape` | `StringChar` | `\` is literal (no escape sequences) | `s = "a\nb"` | true | parse |

## 1.4 Boolean / invalid / line_num literals — `BooleanLiteral`, `InvalidLiteral`, `LINE_NUM_Literal`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `lex.bool.true` | `BooleanLiteral` | `true` literal | `b = true` | true | value:true |
| `lex.bool.false` | `BooleanLiteral` | `false` literal | `b = false` | true | value:false |
| `lex.bool.case_insensitive` | `BooleanLiteral` | mixed-case `True` | `b = True` | true | value:true |
| `lex.invalid` | `InvalidLiteral` | `invalid` literal | `x = invalid` | true | value:invalid |
| `lex.line_num` | `LINE_NUM_Literal` | `line_num` compiler substitution | `n = line_num` | true | parse |

## 1.5 Comments — `Comment` (an `extra` in tree-sitter)

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `lex.comment.apostrophe` | `Comment` | `'` line comment | `' a comment` | true | parse |
| `lex.comment.rem` | `Comment` | `rem` line comment | `rem a comment` | true | parse |
| `lex.comment.trailing` | `Comment` | comment after a statement on same line | `x = 1 ' note` | true | value:1 |

## 1.6 Statement terminators / significant newlines — `EOS`, `NL`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `lex.eos.newline` | `EOS` | newline terminates a statement | `x = 1\ny = 2` | true | value:2 |
| `lex.eos.colon` | `EOS` | colon separates statements on one line | `x = 1 : y = 2` | true | value:2 |
| `lex.eos.collapse` | `EOS` | runs of blank terminators collapse | `x = 1\n\n\ny = 2` | true | value:2 |
| `lex.eos.no_continuation` | `NL` | no line-continuation char (newline always terminates at depth 0) | `x = 1 +\n2` | false | error |
| `lex.eos.depth0_only` | `EOS` | newline NOT a terminator inside `( ) [ ] { }` | `x = [\n1,\n2]` | true | parse |

---

# Part 2 — Declarations

## 2.1 Library statement — `LibraryStatement`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `decl.library.basic` | `LibraryStatement` | `library "x.brs"` import | `library "v30/bslCore.brs"` | true | parse |

## 2.2 Function declaration — `FunctionDeclaration`, `EndFunction`, `ReturnType`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `decl.function.noargs` | `FunctionDeclaration` | function with no params | `function f()\nreturn 1\nend function` | true | value:1 |
| `decl.function.endfunction_fused` | `EndFunction` | fused `endfunction` terminator | `function f()\nreturn 1\nendfunction` | true | value:1 |
| `decl.function.returntype` | `ReturnType` | `as Type` return annotation | `function f() as integer\nreturn 1\nend function` | true | value:1 |
| `decl.function.nested` | `FunctionDeclaration` | function declared inside another (Statement position) | `function f()\nfunction g()\nreturn 2\nend function\nreturn g()\nend function` | true | value:2 |

## 2.3 Sub declaration — `SubDeclaration`, `EndSub`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `decl.sub.noargs` | `SubDeclaration` | sub with no params | `sub s()\nend sub` | true | parse |
| `decl.sub.endsub_fused` | `EndSub` | fused `endsub` terminator | `sub s()\nendsub` | true | parse |
| `decl.sub.returntype_void` | `ReturnType` | sub with explicit `as void` | `sub s() as void\nend sub` | true | parse |

## 2.4 Parameters — `ParameterList`, `Parameter`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `decl.param.single` | `Parameter` | one parameter, no type/default | `function f(a)\nreturn a\nend function` | true | parse |
| `decl.param.multiple` | `ParameterList` | comma-separated params | `function f(a, b)\nreturn a+b\nend function` | true | parse |
| `decl.param.typed` | `Parameter` | param with `as Type` | `function f(a as integer)\nreturn a\nend function` | true | parse |
| `decl.param.default` | `Parameter` | param with default value | `function f(a = 7)\nreturn a\nend function` | true | parse |
| `decl.param.default_and_type` | `Parameter` | default then `as Type` (order: name = default as Type) | `function f(a = 7 as integer)\nreturn a\nend function` | true | parse |

## 2.5 Type system — `Type` (each `as Type` annotation position)

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `decl.type.integer` | `Type` | `as integer` | `function f() as integer\nreturn 1\nend function` | true | value:1 |
| `decl.type.longinteger` | `Type` | `as longinteger` (OS 7.0+) | `function f() as longinteger\nreturn 1\nend function` | true | parse |
| `decl.type.float` | `Type` | `as float` | `function f() as float\nreturn 1.0\nend function` | true | parse |
| `decl.type.double` | `Type` | `as double` | `function f() as double\nreturn 1.0\nend function` | true | parse |
| `decl.type.string` | `Type` | `as string` | `function f() as string\nreturn "a"\nend function` | true | parse |
| `decl.type.boolean` | `Type` | `as boolean` | `function f() as boolean\nreturn true\nend function` | true | parse |
| `decl.type.object` | `Type` | `as object` | `function f() as object\nreturn []\nend function` | true | parse |
| `decl.type.function` | `Type` | `as function` | `function f() as function\nreturn sub()\nend sub\nend function` | true | parse |
| `decl.type.interface` | `Type` | `as interface` | `sub f(x as interface)\nend sub` | true | parse |
| `decl.type.dynamic` | `Type` | `as dynamic` (the unconstrained default) | `function f() as dynamic\nreturn 1\nend function` | true | parse |
| `decl.type.void` | `Type` | `as void` | `sub f() as void\nend sub` | true | parse |
| `decl.type.custom` | `Type` | component/interface type name via `Identifier` | `sub f(n as roSGNode)\nend sub` | true | parse |

---

# Part 3 — Statements

## 3.1 Assignment — `AssignmentStatement`, `AssignTarget`

The dimensionality of an l-value: every shape `AssignTarget` (`Identifier PostfixSuffix*`) can take.

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.assign.var` | `AssignmentStatement` | assign to a bare variable | `x = 1` | true | value:1 |
| `stmt.assign.member` | `AssignTarget` | assign to `.member` target | `m.count = 2` | true | value:2 |
| `stmt.assign.index` | `AssignTarget` | assign to `[i]` index target | `a = [0] : a[0] = 3` | true | value:3 |
| `stmt.assign.chain` | `AssignTarget` | assign to deep member/index chain | `m.list = [{}] : m.list[0].name = "z"` | true | value:z |
| `stmt.assign.no_let` | `AssignmentStatement` | NO leading `let` (device-confirmed: `let` rejected) | `x = 1` | true | value:1 |

## 3.2 Compound assignment — `CompoundAssignStatement`, `CompoundOp` (OS 7.1+)

Each compound operator × applied to a variable target (and one index-target variant).

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.compound.plus` | `CompoundOp` | `+=` | `x = 1 : x += 2` | true | value:3 |
| `stmt.compound.minus` | `CompoundOp` | `-=` | `x = 5 : x -= 2` | true | value:3 |
| `stmt.compound.star` | `CompoundOp` | `*=` | `x = 2 : x *= 3` | true | value:6 |
| `stmt.compound.slash` | `CompoundOp` | `/=` (float division) | `x = 6 : x /= 2` | true | value:3 |
| `stmt.compound.backslash` | `CompoundOp` | `\=` (integer division) | `x = 7 : x \= 2` | true | value:3 |
| `stmt.compound.shl` | `CompoundOp` | `<<=` (shift left) | `x = 1 : x <<= 3` | true | value:8 |
| `stmt.compound.shr` | `CompoundOp` | `>>=` (shift right) | `x = 8 : x >>= 2` | true | value:2 |
| `stmt.compound.on_index` | `CompoundAssignStatement` | compound op on an index target | `a = [1] : a[0] += 4` | true | value:5 |

## 3.3 Increment / decrement — `IncDecStatement` (OS 7.1+, postfix only)

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.incdec.incr_var` | `IncDecStatement` | `++` on a variable | `x = 1 : x++` | true | value:2 |
| `stmt.incdec.decr_var` | `IncDecStatement` | `--` on a variable | `x = 2 : x--` | true | value:1 |
| `stmt.incdec.on_index` | `IncDecStatement` | `++` on an index target | `a = [1] : a[0]++` | true | value:2 |
| `stmt.incdec.on_member` | `IncDecStatement` | `++` on a member target | `m.n = 1 : m.n++` | true | value:2 |

## 3.4 Print — `PrintStatement`, `PrintItemList`, `PrintSep`, `TabItem`, `PosItem`

Each print *form* and separator behavior (print's `;`/`,` are item separators, not operators).

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.print.keyword` | `PrintStatement` | `print` keyword form | `print "hi"` | true | parse |
| `stmt.print.question_alias` | `QUESTION` | `?` shorthand for print | `? "hi"` | true | parse |
| `stmt.print.empty` | `PrintStatement` | empty print (just newline) | `print` | true | parse |
| `stmt.print.sep_comma` | `PrintSep` | `,` separator (tab zone advance) | `print "a", "b"` | true | parse |
| `stmt.print.sep_semi` | `PrintSep` | `;` separator (no advance) | `print "a"; "b"` | true | parse |
| `stmt.print.trailing_sep` | `PrintItemList` | trailing separator suppresses newline | `print "a";` | true | parse |
| `stmt.print.tab` | `TabItem` | `tab(expr)` positional item | `print tab(5) "x"` | true | parse |
| `stmt.print.pos` | `PosItem` | `pos(expr)` positional item | `print pos(0)` | true | parse |

## 3.5 If — `IfStatement`, `BlockIf`, `SingleLineIf`, `ElseIfClause`, `ElseClause`, `EndIf`

Both forms (block vs single-line, the newline-driven disambiguation), each clause, fused/spaced.

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.if.block` | `BlockIf` | multi-line block if/end if | `if true\nx = 1\nend if` | true | value:1 |
| `stmt.if.block_then` | `BlockIf` | optional `then` before newline | `if true then\nx = 1\nend if` | true | value:1 |
| `stmt.if.endif_fused` | `EndIf` | fused `endif` terminator | `if true\nx = 1\nendif` | true | value:1 |
| `stmt.if.elseif` | `ElseIfClause` | `else if` clause | `if false\nx=1\nelse if true\nx=2\nend if` | true | value:2 |
| `stmt.if.elseif_fused` | `ElseIfClause` | fused `elseif` clause | `if false\nx=1\nelseif true\nx=2\nend if` | true | value:2 |
| `stmt.if.else` | `ElseClause` | `else` clause in block if | `if false\nx=1\nelse\nx=2\nend if` | true | value:2 |
| `stmt.if.singleline` | `SingleLineIf` | single-line if (statement after then, no newline) | `if true then x = 1` | true | value:1 |
| `stmt.if.singleline_no_then` | `SingleLineIf` | single-line if without `then` | `if true x = 1` | true | value:1 |
| `stmt.if.singleline_else` | `SingleLineIf` | single-line if with inline `else` | `if false then x=1 else x=2` | true | value:2 |
| `stmt.if.singleline_colon` | `InlineStatements` | multiple `:`-joined statements after then | `if true then x=1 : y=2` | true | value:2 |

## 3.6 For (numeric) — `ForStatement`, `ForTerminator`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.for.basic` | `ForStatement` | `for i = a to b` | `s=0 : for i=1 to 3\ns=s+i\nend for` | true | value:6 |
| `stmt.for.step` | `ForStatement` | `step` clause | `s=0 : for i=0 to 4 step 2\ns=s+i\nend for` | true | value:6 |
| `stmt.for.step_negative` | `ForStatement` | negative step (counts down) | `s=0 : for i=3 to 1 step -1\ns=s+i\nend for` | true | value:6 |
| `stmt.for.next` | `ForTerminator` | legacy `next` terminator | `s=0 : for i=1 to 3\ns=s+i\nnext` | true | value:6 |
| `stmt.for.next_var` | `ForTerminator` | `next` with counter variable | `s=0 : for i=1 to 3\ns=s+i\nnext i` | true | value:6 |
| `stmt.for.endfor_fused` | `ForTerminator` | fused `endfor` terminator | `s=0 : for i=1 to 3\ns=s+i\nendfor` | true | value:6 |

## 3.7 For Each — `ForEachStatement`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.foreach.array` | `ForEachStatement` | iterate an array | `s=0 : for each v in [1,2,3]\ns=s+v\nend for` | true | value:6 |
| `stmt.foreach.aa` | `ForEachStatement` | iterate AA keys | `n=0 : for each k in {a:1,b:2}\nn=n+1\nend for` | true | value:2 |
| `stmt.foreach.endfor_fused` | `ForEachStatement` | fused `endfor` terminator | `s=0 : for each v in [1,2]\ns=s+v\nendfor` | true | value:3 |

## 3.8 While — `WhileStatement`, `EndWhile`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.while.basic` | `WhileStatement` | `while`/`end while` | `i=0 : while i<3\ni=i+1\nend while` | true | value:3 |
| `stmt.while.endwhile_fused` | `EndWhile` | fused `endwhile` terminator | `i=0 : while i<3\ni=i+1\nendwhile` | true | value:3 |

## 3.9 Exit / Continue — `ExitStatement`, `ContinueStatement`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.exit.for` | `ExitStatement` | `exit for` breaks a numeric loop | `r=0 : for i=1 to 9\nif i=3 then exit for\nr=i\nend for` | true | value:2 |
| `stmt.exit.while` | `ExitStatement` | `exit while` breaks a while loop | `i=0 : while true\ni=i+1\nif i=2 then exit while\nend while` | true | value:2 |
| `stmt.exit.exitwhile_fused` | `ExitStatement` | legacy fused `exitwhile` | `i=0 : while true\ni=i+1\nif i=2 then exitwhile\nend while` | true | value:2 |
| `stmt.continue.for` | `ContinueStatement` | `continue for` skips iteration | `s=0 : for i=1 to 3\nif i=2 then continue for\ns=s+i\nend for` | true | value:4 |
| `stmt.continue.while` | `ContinueStatement` | `continue while` skips iteration | `i=0 : s=0 : while i<3\ni=i+1\nif i=2 then continue while\ns=s+i\nend while` | true | value:4 |

## 3.10 Return — `ReturnStatement`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.return.value` | `ReturnStatement` | return with an expression | `function f()\nreturn 9\nend function` | true | value:9 |
| `stmt.return.bare` | `ReturnStatement` | bare return (no expression, from a sub) | `sub s()\nreturn\nend sub` | true | parse |

## 3.11 Dim — `DimStatement`, `DimBounds`

Both bracket and paren bounds; single & multi-dimension (multi-dim enables `a[i,j]`).

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.dim.bracket` | `DimBounds` | `dim a[n]` bracket bounds | `dim a[3] : a[0]=1` | true | value:1 |
| `stmt.dim.paren` | `DimBounds` | `dim a(n)` paren bounds | `dim a(3) : a[0]=1` | true | value:1 |
| `stmt.dim.multidim` | `DimBounds` | multi-dimension bounds → enables `a[i,j]` | `dim a[2,2] : a[1,1]=5` | true | value:5 |

## 3.12 Goto & Labels — `GotoStatement`, `Label`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.label.def` | `Label` | label definition (`ident:` alone on a line) | `top:` | true | parse |
| `stmt.goto.basic` | `GotoStatement` | `goto label` jump | `i=0\ntop:\ni=i+1\nif i<3 then goto top` | true | value:3 |

## 3.13 Stop / End — `StopStatement`, `EndStatement`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.stop` | `StopStatement` | `stop` (invoke debugger) — syntactic only | `stop` | false | parse |
| `stmt.end` | `EndStatement` | bare `end` (terminate program) — disambiguate from `end if` etc. | `end` | false | parse |

## 3.14 Try / Catch / Throw — `TryStatement`, `EndTry`, `ThrowStatement`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.try.basic` | `TryStatement` | `try`/`catch e`/`end try` | `caught=false : try\nthrow "x"\ncatch e\ncaught=true\nend try` | true | value:true |
| `stmt.try.endtry_fused` | `EndTry` | fused `endtry` terminator | `try\nthrow "x"\ncatch e\nendtry` | true | parse |
| `stmt.throw.string` | `ThrowStatement` | `throw` a string message | `try\nthrow "boom"\ncatch e\nend try` | true | parse |
| `stmt.throw.aa` | `ThrowStatement` | `throw` an AA with number/message | `try\nthrow {number:1, message:"m"}\ncatch e\nend try` | true | parse |

## 3.15 Expression statement — `ExpressionStatement`, `CallExpression`

A bare statement must END in a call (member/index access alone is not a statement).

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `stmt.expr.call` | `ExpressionStatement` | function-call statement | `print("x")` | true | parse |
| `stmt.expr.method_call` | `CallExpression` | method-call statement (member then call) | `m.doIt()` | true | parse |
| `stmt.expr.optcall` | `CallExpression` | optional-call as the trailing call (`?(`) | `m.fn?()` | true | parse |

---

# Part 4 — Conditional compilation (preprocessor)

`#const`, `#if`/`#else if`/`#else`/`#end if`, `#error`. Device-confirmed: `CCExpression` is ONLY a
single boolean literal OR a single `#const` name (no `and`/`or`/`not`/parens — those are negatives).

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `cc.const.bool` | `ConstDirective` | `#const NAME = true/false` | `#const debug = true` | true | parse |
| `cc.if.literal` | `IfDirectiveBlock` | `#if <bool literal>` | `#if true\nx=1\n#end if` | true | value:1 |
| `cc.if.const` | `CCExpression` | `#if <CONST-NAME>` | `#const d = true\n#if d\nx=1\n#end if` | true | value:1 |
| `cc.if.elseif` | `IfDirectiveBlock` | `#else if` branch | `#if false\nx=1\n#else if true\nx=2\n#end if` | true | value:2 |
| `cc.if.else` | `IfDirectiveBlock` | `#else` branch (used for negation) | `#if false\nx=1\n#else\nx=2\n#end if` | true | value:2 |
| `cc.if.nested` | `IfDirectiveBlock` | nested `#if` (used for conjunction) | `#if true\n#if true\nx=1\n#end if\n#end if` | true | value:1 |
| `cc.endif.fused` | `EndIfDirective` | fused `#endif` terminator | `#if true\nx=1\n#endif` | true | value:1 |
| `cc.error` | `ErrorDirective` | `#error` directive (compile-time abort) | `#error stop here` | false | error |

---

# Part 5 — Expression grammar (precedence-layered cascade)

This is where the *precedence and associativity* dimensions live. Each layer of the cascade
(`OrExpr → AndExpr → NotExpr → ComparisonExpr → BitshiftExpr → AdditiveExpr → MultiplicativeExpr →
UnaryExpr → PowerExpr → PostfixExpr → Primary`) gets coverage of its operator(s) AND of the
precedence/associativity edges between layers — these are the leaves a parser most easily gets wrong.

## 5.0 Precedence & associativity edges (the load-bearing cases)

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.prec.unary_vs_power` | `UnaryExpr` | unary minus binds LOOSER than `^`: `-2^2` = `-(2^2)` | `x = -2^2` | true | value:-4 |
| `expr.prec.power_right_assoc` | `PowerExpr` | `^` right-assoc: `2^3^2` = `2^(3^2)` = 512 | `x = 2^3^2` | true | value:512 |
| `expr.prec.power_neg_exp` | `PowerExpr` | RHS of `^` recurses through unary: `2^-1` = 0.5 | `x = 2^-1` | true | value:0.5 |
| `expr.prec.mul_vs_add` | `AdditiveExpr` | `*` tighter than `+`: `1+2*3` = 7 | `x = 1+2*3` | true | value:7 |
| `expr.prec.add_vs_shift` | `BitshiftExpr` | `+` tighter than `<<`: `1+1<<2` = 8 | `x = 1+1<<2` | true | value:8 |
| `expr.prec.shift_vs_cmp` | `ComparisonExpr` | shift tighter than comparison: `1<<2 = 4` true | `x = (1<<2 = 4)` | true | value:true |
| `expr.prec.cmp_vs_not` | `NotExpr` | `not` looser than comparison: `not 1 = 2` = `not (1=2)` = true | `x = not 1 = 2` | true | value:true |
| `expr.prec.not_vs_and` | `AndExpr` | `not` tighter than `and`: `not false and true` = true | `x = not false and true` | true | value:true |
| `expr.prec.and_vs_or` | `OrExpr` | `and` tighter than `or`: `false or true and false` = false | `x = false or true and false` | true | value:false |
| `expr.assoc.sub_left` | `AdditiveExpr` | `-` left-assoc: `10-3-2` = 5 | `x = 10-3-2` | true | value:5 |
| `expr.assoc.div_left` | `MultiplicativeExpr` | `/` left-assoc: `100/10/2` = 5 | `x = 100/10/2` | true | value:5 |
| `expr.cmp.non_chaining` | `ComparisonExpr` | comparison is non-chaining: `1 < 2 < 3` evals L→R (`(1<2)<3` = `true<3`) | `x = (1 < 2)` | true | value:true |
| `expr.paren.override` | `ParenExpr` | parentheses override precedence: `(1+2)*3` = 9 | `x = (1+2)*3` | true | value:9 |

## 5.1 Logical (level 12-13) — `OrExpr`, `AndExpr`, short-circuit semantics

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.or.basic` | `OrExpr` | `or` operator | `x = false or true` | true | value:true |
| `expr.or.short_circuit` | `OrExpr` | `or` short-circuits (RHS not evaluated when LHS true) | `x = true or (1/0 = 0)` | true | value:true |
| `expr.and.basic` | `AndExpr` | `and` operator | `x = true and false` | true | value:false |
| `expr.and.short_circuit` | `AndExpr` | `and` short-circuits (RHS not evaluated when LHS false) | `x = false and (1/0 = 0)` | true | value:false |
| `expr.or.bitwise` | `OrExpr` | `or` as bitwise on integers: `5 or 2` = 7 | `x = 5 or 2` | true | value:7 |
| `expr.and.bitwise` | `AndExpr` | `and` as bitwise on integers: `6 and 3` = 2 | `x = 6 and 3` | true | value:2 |

## 5.2 Not (level 11) — `NotExpr`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.not.bool` | `NotExpr` | logical `not` on a boolean | `x = not false` | true | value:true |
| `expr.not.bitwise` | `NotExpr` | bitwise `not` on an integer | `x = not 0` | true | value:-1 |
| `expr.not.double` | `NotExpr` | nested/right-assoc `not not` | `x = not not true` | true | value:true |

## 5.3 Comparison (level 10) — `ComparisonExpr`, `ComparisonOp` (each operator; multi-char before single)

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.cmp.eq` | `ComparisonOp` | `=` equality | `x = (1 = 1)` | true | value:true |
| `expr.cmp.ne` | `ComparisonOp` | `<>` inequality | `x = (1 <> 2)` | true | value:true |
| `expr.cmp.lt` | `ComparisonOp` | `<` less-than | `x = (1 < 2)` | true | value:true |
| `expr.cmp.gt` | `ComparisonOp` | `>` greater-than | `x = (2 > 1)` | true | value:true |
| `expr.cmp.le` | `ComparisonOp` | `<=` (matched before `<`) | `x = (2 <= 2)` | true | value:true |
| `expr.cmp.ge` | `ComparisonOp` | `>=` (matched before `>`) | `x = (2 >= 2)` | true | value:true |
| `expr.cmp.string` | `ComparisonExpr` | string comparison | `x = ("a" < "b")` | true | value:true |

## 5.4 Bitshift (level 9) — `BitshiftExpr`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.shift.shl` | `BitshiftExpr` | `<<` shift left | `x = 1 << 3` | true | value:8 |
| `expr.shift.shr` | `BitshiftExpr` | `>>` shift right | `x = 8 >> 2` | true | value:2 |

## 5.5 Additive (level 8) — `AdditiveExpr`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.add.plus` | `AdditiveExpr` | numeric `+` | `x = 2 + 3` | true | value:5 |
| `expr.add.minus` | `AdditiveExpr` | numeric `-` | `x = 5 - 3` | true | value:2 |
| `expr.add.concat` | `AdditiveExpr` | `+` string concatenation | `x = "a" + "b"` | true | value:ab |

## 5.6 Multiplicative (level 7) — `MultiplicativeExpr`, `MultiplicativeOp`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.mul.star` | `MultiplicativeOp` | `*` multiply | `x = 4 * 3` | true | value:12 |
| `expr.mul.slash` | `MultiplicativeOp` | `/` float division | `x = 7 / 2` | true | value:3.5 |
| `expr.mul.backslash` | `MultiplicativeOp` | `\` integer division | `x = 7 \ 2` | true | value:3 |
| `expr.mul.mod` | `MultiplicativeOp` | `mod` keyword operator | `x = 7 mod 3` | true | value:1 |

## 5.7 Unary (level 6) — `UnaryExpr`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.unary.minus` | `UnaryExpr` | unary minus (negation) | `x = -5` | true | value:-5 |
| `expr.unary.plus` | `UnaryExpr` | unary plus | `x = +5` | true | value:5 |
| `expr.unary.double_neg` | `UnaryExpr` | right-assoc nested unary `--5` → `-(-5)` | `x = - -5` | true | value:5 |

## 5.8 Power (level 5) — `PowerExpr`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.power.basic` | `PowerExpr` | `^` exponentiation | `x = 2 ^ 10` | true | value:1024 |

## 5.9 Postfix (levels 1-4) — `PostfixExpr`, `PostfixSuffix` and each suffix kind

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.postfix.member` | `MemberSuffix` | `.member` access | `m.x = 1 : y = m.x` | true | value:1 |
| `expr.postfix.member_chain` | `MemberSuffix` | chained `.a.b` | `m.a = {b:2} : y = m.a.b` | true | value:2 |
| `expr.postfix.index` | `IndexSuffix` | `[i]` index read | `a=[7] : y = a[0]` | true | value:7 |
| `expr.postfix.index_multisub` | `IndexSuffix` | multi-subscript `a[i,j]` (after dim) | `dim a[2,2] : a[1,1]=8 : y=a[1,1]` | true | value:8 |
| `expr.postfix.call` | `CallSuffix` | `(args)` call suffix | `function f(n)\nreturn n\nend function` | true | value:0 |
| `expr.postfix.call_noargs` | `CallSuffix` | `()` empty arg call | `function f()\nreturn 1\nend function` | true | value:1 |
| `expr.postfix.attribute` | `AttributeSuffix` | `@attr` XML attribute access | `v = node@id` | false | parse |
| `expr.postfix.mixed_chain` | `PostfixExpr` | mixed suffix chain `a[0].f()` | `a=[{f:function()\nreturn 3\nend function}] : y=a[0].f()` | true | value:3 |

## 5.10 Optional chaining (levels 4, OS 11+) — `OptChainSuffix`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.optchain.dot` | `OC_DOT` | `?.member` optional member | `m.a = invalid : y = m.a?.b` | true | value:invalid |
| `expr.optchain.at` | `OC_AT` | `?@attr` optional XML attr | `y = node?@id` | false | parse |
| `expr.optchain.bracket` | `OC_BRACKET` | `?[i]` optional index | `a = invalid : y = a?[0]` | true | value:invalid |
| `expr.optchain.paren` | `OC_PAREN` | `?(args)` optional call | `f = invalid : y = f?()` | true | value:invalid |
| `expr.optchain.space_vs_print` | `OptChainSuffix` | `?[`/`?(` chaining requires no space (else `?` = print) | `y = m?[0]` | true | parse |

## 5.11 Primary expressions — `Primary`, `ParenExpr`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.primary.paren` | `ParenExpr` | parenthesized expression | `x = (1)` | true | value:1 |
| `expr.primary.m` | `Primary` | `m` as a primary | `m.v = 1 : x = m.v` | true | value:1 |

## 5.12 Array literal — `ArrayLiteral`, `ArrayElement`, `ElementSep` (full dimensionality)

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.array.empty` | `ArrayLiteral` | empty `[]` literal | `a = []` | true | value:0 |
| `expr.array.elements` | `ArrayElement` | `[]` with comma-separated elements | `a = [1,2,3]` | true | value:3 |
| `expr.array.nested` | `ArrayLiteral` | nested array literal | `a = [[1],[2]] : y = a[1][0]` | true | value:2 |
| `expr.array.multiline` | `ElementSep` | multiline literal (newline separates, depth>0) | `a = [\n1,\n2\n]` | true | value:2 |
| `expr.array.trailing_comma` | `ElementSep` | trailing comma tolerated | `a = [1,2,]` | true | value:2 |
| `expr.array.newline_sep` | `ElementSep` | newline-only element separator (no comma) | `a = [\n1\n2\n]` | true | value:2 |
| `expr.array.as_arg` | `ArgumentList` | array literal as a call argument | `function f(a)\nreturn a.count()\nend function : y=f([1,2])` | true | value:2 |
| `expr.array.as_return` | `ReturnStatement` | array literal as a return value | `function f()\nreturn [1,2]\nend function` | true | value:2 |
| `expr.array.in_foreach` | `ForEachStatement` | array literal iterated by `for each` | `s=0 : for each v in [4,5]\ns=s+v\nend for` | true | value:9 |

## 5.13 Associative array literal — `AssocArrayLiteral`, `AAEntry`, `AAKey`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.aa.empty` | `AssocArrayLiteral` | empty `{}` literal | `a = {}` | true | value:0 |
| `expr.aa.entries` | `AAEntry` | `{key: value}` entries | `a = {x:1, y:2}` | true | value:2 |
| `expr.aa.key_ident` | `AAKey` | identifier key | `a = {name:1} : y = a.name` | true | value:1 |
| `expr.aa.key_string` | `AAKey` | string-literal key | `a = {"my key":1} : y = a["my key"]` | true | value:1 |
| `expr.aa.key_reserved` | `AAKey` | reserved word usable as an AA key | `a = {type:1} : y = a.type` | true | value:1 |
| `expr.aa.multiline` | `ElementSep` | multiline AA (newline separates entries) | `a = {\nx:1,\ny:2\n}` | true | value:2 |
| `expr.aa.trailing_comma` | `ElementSep` | trailing comma in AA | `a = {x:1, y:2,}` | true | value:2 |
| `expr.aa.nested` | `AssocArrayLiteral` | nested AA value | `a = {p:{q:3}} : y = a.p.q` | true | value:3 |

## 5.14 Anonymous functions — `AnonymousFunction`, `AnonFunctionExpr`, `AnonSubExpr`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.anon.function` | `AnonFunctionExpr` | `function()...end function` expression value | `f = function()\nreturn 1\nend function : y = f()` | true | value:1 |
| `expr.anon.sub` | `AnonSubExpr` | `sub()...end sub` expression value | `s = sub()\nend sub` | true | parse |
| `expr.anon.as_arg` | `AnonymousFunction` | anon function passed as a call argument | `function call(fn)\nreturn fn()\nend function : y=call(function()\nreturn 2\nend function)` | true | value:2 |
| `expr.anon.in_aa` | `AnonymousFunction` | anon function as an AA value (method) | `m.go = function()\nreturn 3\nend function : y = m.go()` | true | value:3 |

## 5.15 Literals as a Primary — `Literal`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.literal.numeric` | `Literal` | numeric literal as primary | `x = 42` | true | value:42 |
| `expr.literal.string` | `Literal` | string literal as primary | `x = "s"` | true | value:s |
| `expr.literal.boolean` | `Literal` | boolean literal as primary | `x = true` | true | value:true |
| `expr.literal.invalid` | `Literal` | invalid literal as primary | `x = invalid` | true | value:invalid |

## 5.16 CreateObject & reserved built-ins — `CreateObjectCall`, `BuiltinCall`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.createobject.basic` | `CreateObjectCall` | `CreateObject("roArray", ...)` | `a = CreateObject("roArray", 4, true) : a.push(1) : y=a.count()` | true | value:1 |
| `expr.createobject.node` | `CreateObjectCall` | `CreateObject("roSGNode", ...)` | `n = CreateObject("roSGNode", "Node")` | false | parse |
| `expr.builtin.type` | `BuiltinCall` | reserved `type()` builtin call | `s = type(1)` | true | value:Integer |
| `expr.builtin.box` | `BuiltinCall` | reserved `box()` builtin call | `o = box(1)` | true | parse |
| `expr.builtin.getglobalaa` | `BuiltinCall` | reserved `getglobalaa()` builtin call | `g = getglobalaa()` | true | parse |
| `expr.builtin.eval` | `BuiltinCall` | reserved `eval()` builtin call | `r = eval("x = 1")` | false | parse |

## 5.17 Argument list positions — `ArgumentList`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `expr.args.empty` | `CallSuffix` | empty argument list | `function f()\nreturn 0\nend function : y=f()` | true | value:0 |
| `expr.args.single` | `ArgumentList` | single argument | `function f(a)\nreturn a\nend function : y=f(5)` | true | value:5 |
| `expr.args.multiple` | `ArgumentList` | multiple arguments | `function f(a,b)\nreturn a+b\nend function : y=f(2,3)` | true | value:5 |
| `expr.args.expr_arg` | `ArgumentList` | a compound expression as an argument | `function f(a)\nreturn a\nend function : y=f(1+2*3)` | true | value:7 |
| `expr.args.call_as_arg` | `ArgumentList` | a call result as an argument (nested call) | `function id(a)\nreturn a\nend function : y=id(id(4))` | true | value:4 |

---

# SceneGraph — Layer 1 (generic XML)

The XML structural dimensions: the prolog, each markup node kind, attribute quoting, references,
comments, CDATA, PIs. (Many Layer-1 leaves are syntactic — they parse but the device validates the
whole document, so per-construct device self-check is via the enclosing component loading.)

## SG 1.1 Prolog — `prolog`, `XMLDecl`, `VersionInfo`, `EncodingDecl`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `sg.prolog.xmldecl` | `XMLDecl` | `<?xml version="1.0" ?>` declaration | `<?xml version="1.0" ?>` | false | parse |
| `sg.prolog.encoding` | `EncodingDecl` | `encoding="utf-8"` in the declaration | `<?xml version="1.0" encoding="utf-8" ?>` | false | parse |
| `sg.prolog.standalone` | `SDDecl` | `standalone="yes"` declaration | `<?xml version="1.0" standalone="yes" ?>` | false | parse |
| `sg.prolog.no_xmldecl` | `prolog` | document with no XML declaration (decl is optional) | `<component name="C" />` | false | parse |

## SG 1.2 Markup node kinds — `Comment`, `CDSect`, `PI`, `Reference`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `sg.xml.comment` | `Comment` | XML comment `<!-- -->` | `<!-- a note -->` | false | parse |
| `sg.xml.cdata` | `CDSect` | CDATA section | `<![CDATA[ raw < & > ]]>` | false | parse |
| `sg.xml.pi` | `PI` | processing instruction | `<?target data?>` | false | parse |
| `sg.xml.entityref` | `EntityRef` | predefined entity reference `&amp;` | `<Label text="a &amp; b" />` | false | parse |
| `sg.xml.charref` | `CharRef` | numeric character reference | `<Label text="&#65;" />` | false | parse |

## SG 1.3 Tags & attributes — `STag`, `ETag`, `EmptyElemTag`, `Attribute`, `AttValue`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `sg.xml.element_pair` | `GenericElement` | start-tag/content/end-tag triple | `<a>text</a>` | false | parse |
| `sg.xml.empty_elem` | `EmptyElemTag` | self-closing empty element | `<a/>` | false | parse |
| `sg.xml.attr_double_quote` | `AttValue` | double-quoted attribute value | `<a x="1"/>` | false | parse |
| `sg.xml.attr_single_quote` | `AttValue` | single-quoted attribute value | `<a x='1'/>` | false | parse |
| `sg.xml.content_chardata` | `CharData` | character data as element content | `<a>hello</a>` | false | parse |

---

# SceneGraph — Layer 2 (the component constraints)

The SceneGraph dimensions: the `<component>` root + each attribute, `<interface>` with `<field>`
(every FieldType, WITH a value so the device validates the type — see DEVICE_FACTS), `<function>`,
`<script>` inline-CDATA vs external-uri, `<children>` with node elements (role, id, field init).

> **Device-testability note (from DEVICE_FACTS #3 / general rule):** a SceneGraph field's *type is
> validated only when a `value` is present* (the device attempts the string→type conversion then).
> So the device-meaningful field tests are the *valued* ones; those are marked `device_testable:true`
> with `expect: parse` (component loads without a conversion error). A field with no value parses but
> does not exercise type validation.

## SG 2.1 Component root — `Component`, `ComponentAttribute`, `ExtendsAttValue`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `sg.component.name` | `ComponentAttribute` | required `name` attribute | `<component name="MyComp" />` | true | parse |
| `sg.component.extends_builtin` | `ExtendsValue` | `extends` a built-in node class | `<component name="C" extends="Group" />` | true | parse |
| `sg.component.extends_custom` | `ExtendsValue` | `extends` a user-defined component name | `<component name="C" extends="MyBase" />` | true | parse |
| `sg.component.initialfocus` | `ComponentAttribute` | `initialFocus` attribute | `<component name="C" initialFocus="btn" />` | true | parse |
| `sg.component.version` | `ComponentAttribute` | `version` attribute | `<component name="C" version="1.0" />` | true | parse |
| `sg.component.extends_scene` | `BuiltinNodeClass` | `extends="Scene"` (root scene class) | `<component name="C" extends="Scene" />` | true | parse |
| `sg.component.extends_task` | `BuiltinNodeClass` | `extends="Task"` (Task node class) | `<component name="C" extends="Task" />` | true | parse |

## SG 2.2 Interface — `Interface`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `sg.interface.empty` | `Interface` | empty `<interface/>` | `<interface />` | true | parse |
| `sg.interface.with_children` | `Interface` | `<interface>` containing fields/functions | `<interface><field id="a" type="integer" value="1" /></interface>` | true | parse |

## SG 2.3 Field — `Field`, `FieldAttribute`, and **every FieldType with a value**

Each `FieldType` is given WITH a `value` so the device validates the string→type conversion.

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `sg.field.type.integer` | `FieldType` | `integer` field with value | `<field id="a" type="integer" value="42" />` | true | parse |
| `sg.field.type.int_alias` | `FieldType` | `int` alias spelling | `<field id="a" type="int" value="42" />` | true | parse |
| `sg.field.type.longinteger` | `FieldType` | `longinteger` field with value | `<field id="a" type="longinteger" value="5000000000" />` | true | parse |
| `sg.field.type.float` | `FieldType` | `float` field with value | `<field id="a" type="float" value="3.14" />` | true | parse |
| `sg.field.type.string` | `FieldType` | `string` field with value | `<field id="a" type="string" value="hi" />` | true | parse |
| `sg.field.type.str_alias` | `FieldType` | `str` alias spelling | `<field id="a" type="str" value="hi" />` | true | parse |
| `sg.field.type.boolean` | `FieldType` | `Boolean` field with value | `<field id="a" type="Boolean" value="true" />` | true | parse |
| `sg.field.type.bool_alias` | `FieldType` | `bool` alias spelling | `<field id="a" type="bool" value="false" />` | true | parse |
| `sg.field.type.boolean_caseinsensitive` | `FieldTypeAttValue` | type value matched case-insensitively (`boolean`) | `<field id="a" type="boolean" value="true" />` | true | parse |
| `sg.field.type.vector2d` | `FieldType` | `vector2d` field with `[x,y]` value | `<field id="a" type="vector2d" value="[1,2]" />` | true | parse |
| `sg.field.type.color` | `FieldType` | `color` field with `0xRRGGBBAA` value | `<field id="a" type="color" value="0xFF0000FF" />` | true | parse |
| `sg.field.type.time` | `FieldType` | `time` field with value | `<field id="a" type="time" value="0" />` | true | parse |
| `sg.field.type.uri` | `FieldType` | `uri` field with value | `<field id="a" type="uri" value="pkg:/x.png" />` | true | parse |
| `sg.field.type.node` | `FieldType` | `node` field (reference) | `<field id="a" type="node" />` | true | parse |
| `sg.field.type.floatarray` | `FieldType` | `floatarray` field with quoted-element value | `<field id="a" type="floatarray" value="[1.0,2.0]" />` | true | parse |
| `sg.field.type.intarray` | `FieldType` | `intarray` field with value | `<field id="a" type="intarray" value="[1,2,3]" />` | true | parse |
| `sg.field.type.boolarray` | `FieldType` | `boolarray` field with value | `<field id="a" type="boolarray" value="[true,false]" />` | true | parse |
| `sg.field.type.stringarray` | `FieldType` | `stringarray` field — elements MUST be quoted (DEVICE_FACTS #3) | `<field id="a" type="stringarray" value='["a","b"]' />` | true | parse |
| `sg.field.type.vector2darray` | `FieldType` | `vector2darray` field with value | `<field id="a" type="vector2darray" value="[[1,2],[3,4]]" />` | true | parse |
| `sg.field.type.colorarray` | `FieldType` | `colorarray` field with value | `<field id="a" type="colorarray" value="[0xFF0000FF]" />` | true | parse |
| `sg.field.type.timearray` | `FieldType` | `timearray` field with value | `<field id="a" type="timearray" value="[0,1]" />` | true | parse |
| `sg.field.type.nodearray` | `FieldType` | `nodearray` field | `<field id="a" type="nodearray" />` | true | parse |
| `sg.field.type.assocarray` | `FieldType` | `assocarray` field with value | `<field id="a" type="assocarray" value="{}" />` | true | parse |
| `sg.field.type.array` | `FieldType` | generic `array` field with value | `<field id="a" type="array" value="[1,2]" />` | true | parse |
| `sg.field.type.rect2d` | `FieldType` | `rect2D` field with `[x,y,w,h]` value | `<field id="a" type="rect2D" value="[0,0,10,10]" />` | true | parse |
| `sg.field.type.rect2darray` | `FieldType` | `rect2DArray` field with value | `<field id="a" type="rect2DArray" value="[[0,0,1,1]]" />` | true | parse |

### Field non-type attributes — `FieldAttribute`, `AliasAttValue`, `BoolAttValue`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `sg.field.attr.id` | `FieldAttribute` | required `id` attribute | `<field id="a" type="integer" value="1" />` | true | parse |
| `sg.field.attr.value` | `FieldAttribute` | optional `value` initial value | `<field id="a" type="integer" value="1" />` | true | parse |
| `sg.field.attr.alias` | `AliasAttValue` | `alias="node.field"` micro-syntax | `<field id="a" type="integer" alias="child.width" />` | true | parse |
| `sg.field.attr.onchange` | `FieldAttribute` | `onChange` names a BrightScript callback | `<field id="a" type="integer" value="1" onChange="onA" />` | true | parse |
| `sg.field.attr.alwaysnotify` | `BoolAttValue` | `alwaysNotify="true"` | `<field id="a" type="integer" value="1" alwaysNotify="true" />` | true | parse |

## SG 2.4 Function — `Function`, `FunctionAttribute`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `sg.function.name` | `Function` | `<function name="..."/>` exposes a BrightScript fn (callFunc) | `<function name="doThing" />` | true | parse |

## SG 2.5 Script — `Script`, `ScriptInline` (CDATA) vs `ScriptExternal` (uri)

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `sg.script.inline_cdata` | `ScriptCData` | inline `<script>` with BrightScript in CDATA (injection point) | `<script type="text/brightscript"><![CDATA[\nsub init()\nend sub\n]]></script>` | true | parse |
| `sg.script.inline_text` | `ScriptText` | inline `<script>` with bare (non-CDATA) BrightScript text | `<script type="text/brightscript">sub init()\nend sub</script>` | true | parse |
| `sg.script.external_uri` | `ScriptExternal` | external `<script uri="..."/>` (no body) | `<script type="text/brightscript" uri="pkg:/components/c.brs" />` | true | parse |
| `sg.script.type_fixed` | `ScriptTypeAttValue` | fixed `type="text/brightscript"` | `<script type="text/brightscript" uri="pkg:/c.brs" />` | true | parse |

## SG 2.6 Children & node elements — `Children`, `NodeElement`, `NodeAttribute`, `RoleAttValue`

| id | kind | dimension | snippet | device | expect |
|----|------|-----------|---------|--------|--------|
| `sg.children.empty` | `Children` | empty `<children/>` | `<children />` | true | parse |
| `sg.children.with_nodes` | `Children` | `<children>` containing node markup | `<children><Label /></children>` | true | parse |
| `sg.node.builtin` | `NodeName` | node element whose tag is a built-in class (`<Label>`) | `<Label text="hi" />` | true | parse |
| `sg.node.custom` | `NodeName` | node element whose tag is a user component name | `<MyWidget />` | true | parse |
| `sg.node.empty_tag` | `NodeEmptyTag` | self-closing node element | `<Rectangle />` | true | parse |
| `sg.node.nested` | `NodeContent` | nested node elements (parent/child) | `<Group><Label /></Group>` | true | parse |
| `sg.node.attr_id` | `NodeAttribute` | reserved `id` node attribute (findNode dictionary id) | `<Label id="title" />` | true | parse |
| `sg.node.attr_role` | `RoleAttValue` | `role` assigns child as the value of a parent field | `<Animation><Vector2DFieldInterpolator role="animationData" /></Animation>` | true | parse |
| `sg.node.attr_fieldinit` | `FieldInitValue` | generic field-initializer attribute | `<Label text="hello" />` | true | parse |
| `sg.node.fieldinit_color` | `FieldInitValue` | color field-init micro-syntax `0xRRGGBBAA` | `<Rectangle color="0xFF0000FF" />` | true | parse |
| `sg.node.fieldinit_vector2d` | `FieldInitValue` | vector2d field-init micro-syntax `[x,y]` | `<Group translation="[10,20]" />` | true | parse |

---

# NEGATIVE corpus (constructs the device REJECTS)

These are NOT device self-check tests; they are negative cases for the grammar (the parser should
produce ERROR nodes) and for ast-grep. All are marked `device_testable: false`, `negative: true`,
`expect: error`. Sources: `DEVICE_FACTS.md` #1, #2, #3.

| id | kind | layer | dimension | snippet | source |
|----|------|-------|-----------|---------|--------|
| `neg.cc.if_and` | `CCExpression` | brightscript | `#if` with `and` operator — compile error `&h93` | `#if true and false\nx=1\n#end if` | DEVICE_FACTS #1 |
| `neg.cc.if_or` | `CCExpression` | brightscript | `#if` with `or` operator — compile error `&h93` | `#if true or false\nx=1\n#end if` | DEVICE_FACTS #1 |
| `neg.cc.if_not` | `CCExpression` | brightscript | `#if not` operator — compile error `&h93` | `#if not true\nx=1\n#end if` | DEVICE_FACTS #1 |
| `neg.cc.if_paren` | `CCExpression` | brightscript | `#if` with parenthesized expression — compile error `&h93` | `#if (true)\nx=1\n#end if` | DEVICE_FACTS #1 |
| `neg.assign.let` | `AssignmentStatement` | brightscript | leading `let` on assignment — Syntax Error `&h02` | `let x = 5` | DEVICE_FACTS #2 |
| `neg.sg.stringarray_unquoted` | `FieldType` | scenegraph | `stringarray` value with unquoted elements `[a,b,c]` — runtime conversion error | `<field id="a" type="stringarray" value="[a, b, c]" />` | DEVICE_FACTS #3 |

---

## BrighterScript layer (`.bs`, device-validated via transpile)

This layer (taxonomy `layer:"brighterscript"`) models the full BrighterScript language surface from
[`brighterscript.ebnf`](./brighterscript.ebnf) — the `.bs` superset that transpiles to BrightScript.
Ground truth here is **BOTH** `bsc` (the authority for whether the `.bs` *syntax* is accepted) and
the **device** (the authority for whether the transpiled `.brs` *runs*).

- **device-testable leaves** are proven on hardware: their `t.spec` lives in a `.bs` module
  (`roku-test-harness/source/tests/test_bs.bs`) that the deploy build transpiles to `.brs` before
  sideload — "device-testable **via transpile**". All **24/24 PASS** in a clean run
  (`##SPEC## event=run-end pass=497 fail=0`; DEVICE_FACTS #18).
- **parse-only leaves** are bsc-syntax-only: `bsc` accepts the syntax but there is no runtime signal
  (the construct is a type/erased on transpile/multi-file/etc.), so they are tagged `.bs` corpus
  files under `roku-test-harness/corpus/parse-only/` rather than device-run.

The layer adds **37 leaves** (24 device + 13 parse-only), bringing the total `coverage.json` leaves
to **657**.

### device-testable (via transpile)

| id | kind | mode | dimension |
|----|------|------|-----------|
| `bs.namespace.func_call` | `NamespaceStatement` | device (transpile) | namespaced function declaration + dotted call |
| `bs.class.instantiate` | `ClassDeclaration` | device (transpile) | class declaration; new instance; field read |
| `bs.class.method` | `MethodDeclaration` | device (transpile) | class instance method call |
| `bs.class.field_init` | `FieldDeclaration` | device (transpile) | class field with initializer + type |
| `bs.class.extends_super` | `ClassDeclaration` | device (transpile) | subclass extends + super() constructor chain |
| `bs.class.override` | `MethodDeclaration` | device (transpile) | override of an inherited method |
| `bs.class.access.public` | `AccessModifier` | device (transpile) | public field readable outside the class |
| `bs.class.access.private` | `AccessModifier` | device (transpile) | private field read via a public method of the same class |
| `bs.class.access.protected` | `AccessModifier` | device (transpile) | protected field read by a subclass method |
| `bs.enum.member` | `EnumMemberDecl` | device (transpile) | enum member value referenced by dotted name |
| `bs.const.value` | `ConstStatement` | device (transpile) | const declaration referenced as a value |
| `bs.expr.ternary` | `TernaryExpr` | device (transpile) | ternary conditional expression cond ? a : b |
| `bs.expr.nullcoalesce` | `NullCoalesceTail` | device (transpile) | null-coalescing a ?? b (left invalid -> right) |
| `bs.expr.template` | `TemplateString` | device (transpile) | backtick template string literal |
| `bs.expr.template_interp` | `TemplateInterpolation` | device (transpile) | template string ${expr} interpolation |
| `bs.expr.new` | `NewExpression` | device (transpile) | new ClassName(args) with constructor args |
| `bs.expr.aa_computed_key` | `AAEntry` | device (transpile) | associative-array literal with a computed [const] key (bsc BS1144: key must be a compile-time constant) |
| `bs.assign.typed` | `AssignmentStatement` | device (transpile) | typed local assignment `name as Type = value` |
| `bs.foreach.typed` | `ForEachStatement` | device (transpile) | for each with a typed loop item |
| `bs.type.custom_param` | `Type` | device (transpile) | parameter typed with a custom class type |
| `bs.type.union` | `BsTypeUnion` | device (transpile) | union type annotation `string or integer` |
| `bs.type.array` | `BsTypePostfix` | device (transpile) | typed-array annotation `integer[]` |
| `bs.regex.match` | `RegexLiteral` | device (transpile) | regex literal /.../ -> roRegex; isMatch |
| `bs.annotation.on_func` | `Annotation` | device (transpile) | @annotation attached to a function declaration (stripped on transpile) |

### parse-only / bsc-syntax-only

| id | kind | mode | dimension |
|----|------|------|-----------|
| `bs.interface.decl` | `InterfaceDeclaration` | parse-only (bsc) | interface declaration (a type; no runtime) |
| `bs.interface.field` | `InterfaceField` | parse-only (bsc) | interface typed field signature |
| `bs.interface.method` | `InterfaceMethod` | parse-only (bsc) | interface method signature |
| `bs.type.inline_interface` | `InlineInterfaceType` | parse-only (bsc) | inline (anonymous) interface type annotation |
| `bs.type.function_type` | `TypedFunctionType` | parse-only (bsc) | callable/function type annotation |
| `bs.type.grouped` | `GroupedType` | parse-only (bsc) | parenthesized (grouped) type annotation |
| `bs.typecast.stmt` | `TypecastStatement` | parse-only (bsc) | scope-level typecast statement (erased on transpile) |
| `bs.alias.stmt` | `AliasStatement` | parse-only (bsc) | alias statement (single-identifier value in 0.72.2) |
| `bs.type_alias.stmt` | `TypeAliasStatement` | parse-only (bsc) | type alias statement (erased on transpile) |
| `bs.import.stmt` | `ImportStatement` | parse-only (bsc) | import statement (multi-file; resolved at compile) |
| `bs.expr.tagged_template` | `TaggedTemplate` | parse-only (bsc) | tagged template string (tag function before backtick) |
| `bs.expr.callfunc` | `CallfuncSuffix` | parse-only (bsc) | callfunc operator node@.method(args) (transpiles to .callFunc) |
| `bs.source_literal.function_name` | `BsSourceLiteral` | parse-only (bsc) | BrighterScript source literal (e.g. FUNCTION_NAME) |

---

## Summary

The same leaves are encoded machine-readably in [`coverage.json`](./coverage.json). See that file's
array for the canonical `{id, kind, layer, dimension, snippet, device_testable, expect}` records
(plus `negative: true` on the negative corpus). The harness and the future tree-sitter `test/corpus`
and ast-grep rules all consume this ledger; keep COVERAGE.md and coverage.json in lockstep, and keep
both faithful to the EBNF rule names (they become tree-sitter node kinds / ast-grep `kind`s).

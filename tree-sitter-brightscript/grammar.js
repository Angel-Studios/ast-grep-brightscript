/// <reference types="tree-sitter-cli/dsl" />
// @ts-check
//
// BrightScript grammar for tree-sitter / ast-grep.
// Translated from grammar/brightscript.ebnf (the authoritative, device-corrected
// spec). Rule names mirror the EBNF non-terminals 1:1 so they line up with the
// `kind`s in grammar/coverage.json and with ast-grep patterns.
//
// Design notes (verified empirically — see memory/roadmap 03):
//  * Lexer resolution order is context-validity -> explicit `prec` -> longest.
//  * Case-insensitive keywords via ci(); the keyword/identifier prefix problem
//    (e.g. `print` vs `printer`) is solved by making IdentStart an EXTERNAL token
//    that the scanner only emits for non-reserved whole words (see src/scanner.c).
//  * `_nl` is an external newline token emitted by the scanner ONLY when valid
//    (valid_symbols). This makes the grouping-paren rule (#14) and the
//    collection/arg-list newline-suppression fall out of the grammar shape: a
//    newline inside `( expr )` is not a valid EOS there, so it errors; inside
//    `[ ]` / `{ }` / argument lists EOS is allowed, so it is consumed.
//  * Supertypes (Literal/NumericLiteral/Primary/AnonymousFunction/OptChainSuffix)
//    are hidden: good for structure & node-types.json, but ast-grep cannot match
//    them, so coverage targets the concrete subtypes.

/** Case-insensitive keyword token (prec 2 so a keyword beats IdentStart when both are context-valid and equal length). */
function ci(word) {
  return token(prec(2, new RegExp(
    [...word].map((ch) => {
      const lo = ch.toLowerCase(), hi = ch.toUpperCase();
      return lo !== hi ? `[${lo}${hi}]` : ch.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }).join(''),
  )));
}

/**
 * A fused multi-word keyword token allowing optional spaces between words, so the
 * spaced and run-together spellings are one token (`end if` / `endif`). Single
 * tokens beat the bare `end` (EndStatement) by longest-match, removing the
 * block-terminator-vs-`end` ambiguity.
 */
function fused(...words) {
  const word = (w) => [...w].map((ch) => {
    const lo = ch.toLowerCase(), hi = ch.toUpperCase();
    return lo !== hi ? `[${lo}${hi}]` : ch.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }).join('');
  return token(prec(2, new RegExp(words.map(word).join('[ \\t]*'))));
}

// Expression precedence — tighter binds higher (tree-sitter convention).
const PREC = {
  or: 1,
  and: 2,
  not: 3,
  cmp: 4,
  shift: 5,
  add: 6,
  mul: 7,
  unary: 8,
  power: 9,
  postfix: 10,
};

/**
 * A statement/block-item sequence: optional leading terminators, then items each
 * followed by one-or-more terminators (a comment between two newlines splits the
 * EOS run, so the separator must accept repeat1). Leaves the trailing terminator
 * to the caller's structure where needed.
 */
function blockBody($) {
  return repeat(seq($._BlockItem, repeat1($.EOS)));
}

/**
 * A newline-only EOS node, for use INSIDE collection literals. There a newline is
 * a separator but a ':' is not (':' there is the AA key separator), so the
 * colon-bearing EOS must not apply. The scanner already collapses newline runs
 * into one `_nl`, so this is a single token, not a repeat.
 */
function nlEos($) {
  return alias($._nl, $.EOS);
}

/**
 * A comma/newline-separated list with optional leading, repeated, and trailing
 * separators (covers trailing commas and multiline collection literals).
 */
function sepList($, item) {
  return seq(
    repeat($.ElementSep),
    item,
    repeat(seq(repeat1($.ElementSep), item)),
    repeat($.ElementSep),
  );
}

export default grammar({
  name: 'brightscript',

  // Horizontal whitespace only; newlines are significant (handled by the scanner).
  extras: $ => [/[ \t\f]/, $.Comment],

  externals: $ => [
    $.IdentStart, // scanner emits this for a non-reserved whole word
    $._nl,        // scanner emits this for a run of line breaks, only when valid
  ],

  supertypes: $ => [
    $.Literal,
    $.NumericLiteral,
    $.Primary,
    $.AnonymousFunction,
    $.OptChainSuffix,
  ],

  conflicts: $ => [
    // An l-value (`x`, `m.x`, `a[0]`) is an AssignTarget before `=`/op but an
    // ordinary expression otherwise; keep both alive until the trailing token.
    [$.AssignTarget, $._Expression],
    [$.AssignTarget, $.Primary],
    // `( expr )` after a callee is a single-arg ArgumentList; standalone it is a
    // ParenExpr — same shape, resolved by whether a callee precedes it.
    [$.ArgumentList, $.ParenExpr],
    // `[ … ]` after an object is an IndexSuffix; standalone it is an ArrayLiteral.
    [$.IndexSuffix, $.ArrayElement],
  ],

  rules: {
    //========================================================================
    // PART 2 — program structure
    //========================================================================

    SourceFile: $ => seq(
      repeat($.EOS),
      optional(seq(
        $._TopLevelItem,
        repeat(seq(repeat1($.EOS), $._TopLevelItem)),
        repeat($.EOS),
      )),
    ),

    _TopLevelItem: $ => choice(
      $.FunctionDeclaration,
      $.SubDeclaration,
      $.LibraryStatement,
      $.ConstDirective,
      $._ConditionalCompilation,
      $.Label,
      $._Statement,
    ),

    // ---- statement terminator -------------------------------------------
    // EOS = one or more newlines and/or colons (collapsed). `_nl` is the
    // external newline token; ':' is an ordinary token also used by AAEntry /
    // InlineStatements / Label, disambiguated by parse context.
    EOS: $ => prec.right(repeat1(choice($._nl, ':'))),

    // ---- library --------------------------------------------------------
    LibraryStatement: $ => seq(ci('library'), $.StringLiteral),

    // ---- function / sub declarations ------------------------------------
    FunctionDeclaration: $ => seq(
      ci('function'),
      field('name', $.Identifier),
      '(', optional($.ParameterList), ')',
      optional($.ReturnType),
      repeat1($.EOS),
      optional(field('body', alias(blockBody($), $.Block))),
      $.EndFunction,
    ),
    SubDeclaration: $ => seq(
      ci('sub'),
      field('name', $.Identifier),
      '(', optional($.ParameterList), ')',
      optional($.ReturnType),
      repeat1($.EOS),
      optional(field('body', alias(blockBody($), $.Block))),
      $.EndSub,
    ),
    EndFunction: _ => fused('end', 'function'),
    EndSub: _ => fused('end', 'sub'),

    ReturnType: $ => seq(ci('as'), field('type', $.Type)),

    ParameterList: $ => seq($.Parameter, repeat(seq(',', $.Parameter))),
    Parameter: $ => seq(
      field('name', $.Identifier),
      optional(seq('=', field('default', $._Expression))),
      optional(seq(ci('as'), field('type', $.Type))),
    ),

    // The PARSER accepts any name after `as` so that device-invalid annotations
    // (`as interface`, `as roSGNode`) still parse clean and are flagged by a lint
    // rule, not an ERROR node (roadmap; DEVICE_FACTS #6/#7). The intrinsic type
    // names are non-reserved, so they arrive as an Identifier via the scanner;
    // the two reserved ones (`function`, `invalid`) need explicit alternatives.
    Type: $ => choice($.Identifier, ci('function'), ci('invalid')),

    //========================================================================
    // PART 3 — statements
    //========================================================================

    _BlockItem: $ => choice(
      $.Label,
      $._Statement,
      $._ConditionalCompilation,
    ),

    _Statement: $ => choice(
      $.AssignmentStatement,
      $.CompoundAssignStatement,
      $.IncDecStatement,
      $.PrintStatement,
      $.IfStatement,
      $.ForStatement,
      $.ForEachStatement,
      $.WhileStatement,
      $.ExitStatement,
      $.ContinueStatement,
      $.ReturnStatement,
      $.DimStatement,
      $.GotoStatement,
      $.StopStatement,
      $.EndStatement,
      $.TryStatement,
      $.ThrowStatement,
      $.ExpressionStatement,
    ),

    // ---- assignment -----------------------------------------------------
    AssignmentStatement: $ => seq(field('target', $.AssignTarget), '=', field('value', $._Expression)),
    // An l-value: a variable or a member/index/attribute chain (never ending in a
    // call). A bare Identifier or a PostfixExpr (which is left-recursive over the
    // member/index suffixes); disambiguated from a CallExpression statement by the
    // trailing '='/op via GLR.
    AssignTarget: $ => choice($.Identifier, $.PostfixExpr),

    CompoundAssignStatement: $ => seq(field('target', $.AssignTarget), field('op', $.CompoundOp), field('value', $._Expression)),
    CompoundOp: _ => choice('+=', '-=', '*=', '/=', '\\=', '<<=', '>>='),

    IncDecStatement: $ => seq(field('target', $.AssignTarget), field('op', choice('++', '--'))),

    // ---- print ----------------------------------------------------------
    PrintStatement: $ => seq(choice(ci('print'), $.QUESTION), optional($.PrintItemList)),
    QUESTION: _ => '?',
    // Expression items need a ';'/',' separator, but a positional tab()/pos()
    // item may be directly followed by one item (e.g. `print tab(5) "x"`).
    PrintItemList: $ => seq($._PrintItem, repeat(seq($.PrintSep, $._PrintItem)), optional($.PrintSep)),
    _PrintItem: $ => choice(
      seq(choice($.TabItem, $.PosItem), optional($._Expression)),
      $._Expression,
    ),
    PrintSep: _ => choice(';', ','),
    TabItem: $ => seq(ci('tab'), '(', $._Expression, ')'),
    PosItem: $ => seq(ci('pos'), '(', $._Expression, ')'),

    // ---- if -------------------------------------------------------------
    IfStatement: $ => choice($.BlockIf, $.SingleLineIf),
    BlockIf: $ => seq(
      ci('if'), field('condition', $._Expression), optional(ci('then')),
      repeat1($.EOS),
      optional(field('consequence', alias(blockBody($), $.Block))),
      repeat($.ElseIfClause),
      optional($.ElseClause),
      $.EndIf,
    ),
    ElseIfClause: $ => seq(
      fused('else', 'if'),
      field('condition', $._Expression), optional(ci('then')),
      repeat1($.EOS),
      optional(field('consequence', alias(blockBody($), $.Block))),
    ),
    ElseClause: $ => seq(
      ci('else'),
      repeat1($.EOS),
      optional(field('consequence', alias(blockBody($), $.Block))),
    ),
    EndIf: _ => fused('end', 'if'),

    SingleLineIf: $ => prec.right(seq(
      ci('if'), field('condition', $._Expression), optional(ci('then')),
      field('consequence', $.InlineStatements),
      optional(seq(ci('else'), field('alternative', $.InlineStatements))),
    )),
    InlineStatements: $ => prec.right(seq($._Statement, repeat(seq(':', $._Statement)))),

    // ---- for ------------------------------------------------------------
    ForStatement: $ => seq(
      ci('for'), field('counter', $.Identifier), '=', field('start', $._Expression),
      ci('to'), field('end', $._Expression),
      optional(seq(ci('step'), field('step', $._Expression))),
      repeat1($.EOS),
      optional(field('body', alias(blockBody($), $.Block))),
      $.ForTerminator,
    ),
    ForTerminator: $ => choice(fused('end', 'for'), seq(ci('next'), optional($.Identifier))),

    ForEachStatement: $ => seq(
      ci('for'), ci('each'), field('item', $.Identifier), ci('in'), field('collection', $._Expression),
      repeat1($.EOS),
      optional(field('body', alias(blockBody($), $.Block))),
      fused('end', 'for'),
    ),

    // ---- while ----------------------------------------------------------
    WhileStatement: $ => seq(
      ci('while'), field('condition', $._Expression),
      repeat1($.EOS),
      optional(field('body', alias(blockBody($), $.Block))),
      $.EndWhile,
    ),
    EndWhile: _ => fused('end', 'while'),

    // ---- exit / continue ------------------------------------------------
    ExitStatement: _ => choice(fused('exit', 'for'), fused('exit', 'while')),
    ContinueStatement: _ => choice(fused('continue', 'for'), fused('continue', 'while')),

    // ---- return / dim / goto / stop / end -------------------------------
    ReturnStatement: $ => prec.right(seq(ci('return'), optional($._Expression))),
    DimStatement: $ => seq(ci('dim'), field('name', $.Identifier), $.DimBounds),
    DimBounds: $ => seq('[', $._Expression, repeat(seq(',', $._Expression)), ']'),
    GotoStatement: $ => seq(ci('goto'), $.Identifier),
    Label: $ => seq($.Identifier, ':'),
    StopStatement: _ => ci('stop'),
    EndStatement: _ => ci('end'),

    // ---- try / throw ----------------------------------------------------
    TryStatement: $ => seq(
      ci('try'),
      repeat1($.EOS),
      optional(field('body', alias(blockBody($), $.Block))),
      ci('catch'), field('exception', $.Identifier),
      repeat1($.EOS),
      optional(field('handler', alias(blockBody($), $.Block))),
      $.EndTry,
    ),
    EndTry: _ => fused('end', 'try'),
    ThrowStatement: $ => seq(ci('throw'), $._Expression),

    // ---- expression statement (must end in a call) ----------------------
    ExpressionStatement: $ => choice($.CallExpression, $.BuiltinCall, $.CreateObjectCall),

    //========================================================================
    // PART 4 — conditional compilation
    //========================================================================

    _ConditionalCompilation: $ => choice($.IfDirectiveBlock, $.ErrorDirective),

    ConstDirective: $ => seq(token(/#[ \t]*[cC][oO][nN][sS][tT]/), field('name', $.Identifier), '=', field('value', $.CCExpression)),

    IfDirectiveBlock: $ => seq(
      token(/#[ \t]*[iI][fF]/), field('condition', $.CCExpression),
      repeat1($.EOS),
      optional(alias(blockBody($), $.Block)),
      repeat(seq(
        token(/#[ \t]*[eE][lL][sS][eE][ \t]*[iI][fF]/), field('condition', $.CCExpression),
        repeat1($.EOS),
        optional(alias(blockBody($), $.Block)),
      )),
      optional(seq(
        token(/#[ \t]*[eE][lL][sS][eE]/),
        repeat1($.EOS),
        optional(alias(blockBody($), $.Block)),
      )),
      $.EndIfDirective,
    ),
    EndIfDirective: _ => token(/#[ \t]*[eE][nN][dD][ \t]*[iI][fF]/),

    ErrorDirective: _ => token(seq('#', /[ \t]*/, /[eE][rR][rR][oO][rR]/, /[^\r\n]*/)),

    // Single boolean literal or #const name only (DEVICE_FACTS #1).
    CCExpression: $ => choice($.BooleanLiteral, $.Identifier),

    //========================================================================
    // PART 5 — expressions (flat precedence cascade)
    //========================================================================

    _Expression: $ => choice(
      $.OrExpr,
      $.AndExpr,
      $.NotExpr,
      $.ComparisonExpr,
      $.BitshiftExpr,
      $.AdditiveExpr,
      $.MultiplicativeExpr,
      $.UnaryExpr,
      $.PowerExpr,
      $.CallExpression,
      $.PostfixExpr,
      $.Primary,
    ),

    OrExpr: $ => prec.left(PREC.or, seq(field('left', $._Expression), ci('or'), field('right', $._Expression))),
    AndExpr: $ => prec.left(PREC.and, seq(field('left', $._Expression), ci('and'), field('right', $._Expression))),
    NotExpr: $ => prec.right(PREC.not, seq(ci('not'), field('operand', $._Expression))),
    ComparisonExpr: $ => prec.left(PREC.cmp, seq(field('left', $._Expression), field('op', $.ComparisonOp), field('right', $._Expression))),
    ComparisonOp: _ => choice('<=', '>=', '<>', '<', '>', '='),
    BitshiftExpr: $ => prec.left(PREC.shift, seq(field('left', $._Expression), field('op', choice('<<', '>>')), field('right', $._Expression))),
    AdditiveExpr: $ => prec.left(PREC.add, seq(field('left', $._Expression), field('op', choice('+', '-')), field('right', $._Expression))),
    MultiplicativeExpr: $ => prec.left(PREC.mul, seq(field('left', $._Expression), field('op', $.MultiplicativeOp), field('right', $._Expression))),
    MultiplicativeOp: _ => choice('*', '/', '\\', ci('mod')),
    UnaryExpr: $ => prec.right(PREC.unary, seq(field('op', choice('+', '-')), field('operand', $._Expression))),
    PowerExpr: $ => prec.right(PREC.power, seq(field('base', $._Expression), '^', field('exp', $._Expression))),

    // Postfix layer, left-recursive: one suffix per application, so a chain like
    // `a.b()[0].c` nests correctly. A chain ending in a call '(...)' is a
    // CallExpression (matchable in any position, incl. the standard library);
    // a chain ending in member/index/attr/optional-chain is a PostfixExpr.
    CallExpression: $ => prec.left(PREC.postfix, seq(field('callee', $._Expression), $.CallSuffix)),
    PostfixExpr: $ => prec.left(PREC.postfix, seq(
      field('object', $._Expression),
      choice($.IndexSuffix, $.MemberSuffix, $.AttributeSuffix, $.OptChainSuffix),
    )),

    CallSuffix: $ => seq('(', optional($.ArgumentList), ')'),
    IndexSuffix: $ => seq('[', $._Expression, repeat(seq(',', $._Expression)), ']'),
    MemberSuffix: $ => seq('.', field('name', $._NameOrKeyword)),
    AttributeSuffix: $ => seq('@', field('name', $._NameOrKeyword)),

    OptChainSuffix: $ => choice($.OC_DOT, $.OC_AT, $.OC_BRACKET, $.OC_PAREN),
    OC_DOT: $ => seq('?.', field('name', $._NameOrKeyword)),
    OC_AT: $ => seq('?@', field('name', $._NameOrKeyword)),
    OC_BRACKET: $ => seq('?[', $._Expression, repeat(seq(',', $._Expression)), ']'),
    OC_PAREN: $ => seq('?(', optional($.ArgumentList), ')'),

    ArgumentList: $ => seq($._Expression, repeat(seq(',', $._Expression))),

    //---- primary ----------------------------------------------------------
    Primary: $ => choice(
      $.Literal,
      $.Identifier,
      $.ParenExpr,
      $.ArrayLiteral,
      $.AssocArrayLiteral,
      $.AnonymousFunction,
      $.CreateObjectCall,
      $.BuiltinCall,
    ),
    ParenExpr: $ => seq('(', $._Expression, ')'),

    // A name position that also accepts reserved words used as names
    // (AA keys, member/attribute access). `m` is just an Identifier.
    _NameOrKeyword: $ => choice($.Identifier, alias($._reserved_word, $.Identifier)),
    _reserved_word: _ => choice(
      ci('and'), ci('box'), ci('createobject'), ci('dim'), ci('each'), ci('else'),
      ci('elseif'), ci('end'), ci('endfunction'), ci('endif'), ci('endsub'),
      ci('endwhile'), ci('eval'), ci('exit'), ci('exitwhile'), ci('false'),
      ci('for'), ci('function'), ci('getglobalaa'), ci('getlastruncompileerror'),
      ci('getlastrunruntimeerror'), ci('goto'), ci('if'), ci('invalid'), ci('let'),
      ci('line_num'), ci('mod'), ci('next'), ci('not'), ci('objfun'), ci('or'),
      ci('pos'), ci('print'), ci('return'), ci('run'), ci('step'), ci('stop'),
      ci('sub'), ci('tab'), ci('then'), ci('to'), ci('type'), ci('while'),
    ),

    //---- array / assoc-array literals ------------------------------------
    ArrayLiteral: $ => seq('[', optional(sepList($, $.ArrayElement)), ']'),
    ArrayElement: $ => $._Expression,
    ElementSep: $ => choice(',', nlEos($)),

    AssocArrayLiteral: $ => seq('{', optional(sepList($, $.AAEntry)), '}'),
    AAEntry: $ => seq(field('key', $.AAKey), ':', field('value', $._Expression)),
    AAKey: $ => choice($._NameOrKeyword, $.StringLiteral),

    //---- anonymous function values --------------------------------------
    AnonymousFunction: $ => choice($.AnonFunctionExpr, $.AnonSubExpr),
    AnonFunctionExpr: $ => seq(
      ci('function'), '(', optional($.ParameterList), ')', optional($.ReturnType),
      repeat1($.EOS),
      optional(field('body', alias(blockBody($), $.Block))),
      $.EndFunction,
    ),
    AnonSubExpr: $ => seq(
      ci('sub'), '(', optional($.ParameterList), ')', optional($.ReturnType),
      repeat1($.EOS),
      optional(field('body', alias(blockBody($), $.Block))),
      $.EndSub,
    ),

    //---- createobject + reserved builtins -------------------------------
    CreateObjectCall: $ => seq(ci('createobject'), '(', optional($.ArgumentList), ')'),
    BuiltinCall: $ => seq(
      field('callee', alias($._ReservedBuiltinName, $.Identifier)),
      '(', optional($.ArgumentList), ')',
    ),
    _ReservedBuiltinName: _ => choice(
      ci('getglobalaa'), ci('getlastruncompileerror'), ci('getlastrunruntimeerror'),
      ci('eval'), ci('objfun'), ci('run'), ci('type'), ci('box'),
    ),

    //========================================================================
    // PART 1 — literals & lexical
    //========================================================================

    Literal: $ => choice($.NumericLiteral, $.StringLiteral, $.BooleanLiteral, $.InvalidLiteral, $.LINE_NUM_Literal),
    NumericLiteral: $ => choice($.DoubleLiteral, $.FloatLiteral, $.LongIntegerLiteral, $.HexLiteral, $.IntegerLiteral),

    // LongInteger is highest: a trailing `&` is definitive (it must beat the
    // 10+-digit Double form for `5000000000&`, since prec wins over longest-match).
    LongIntegerLiteral: _ => token(prec(6, /([0-9]+|&[hH][0-9a-fA-F]+)&/)),
    DoubleLiteral: _ => token(prec(5, /([0-9]+[dD][+-]?[0-9]+)|([0-9]*\.[0-9]+#)|([0-9]+#)|([0-9]{10,}(\.[0-9]*)?)|(\.[0-9]{10,})/)),
    FloatLiteral: _ => token(prec(4, /([0-9]+\.[0-9]*([eE][+-]?[0-9]+)?)|(\.[0-9]+([eE][+-]?[0-9]+)?)|([0-9]+[eE][+-]?[0-9]+)|([0-9]+!)/)),
    HexLiteral: _ => token(prec(2, /&[hH][0-9a-fA-F]+/)),
    IntegerLiteral: _ => token(prec(1, /[0-9]+/)),

    StringLiteral: $ => seq('"', repeat(choice($.EscapedQuote, $.StringChar)), '"'),
    // prec must beat the `rem`/`'` Comment extra (prec 3): otherwise a string
    // whose content starts like a comment (e.g. "rem line comment") is eaten as a
    // Comment node instead of StringChar.
    StringChar: _ => token.immediate(prec(4, /[^"\r\n]+/)),
    EscapedQuote: _ => token.immediate(prec(4, '""')),

    BooleanLiteral: _ => choice(ci('true'), ci('false')),
    InvalidLiteral: _ => ci('invalid'),
    LINE_NUM_Literal: _ => ci('line_num'),

    Identifier: $ => seq($.IdentStart, optional($.TypeSuffix)),
    TypeSuffix: _ => token.immediate(/[$%!#&]/),

    Comment: _ => token(prec(3, choice(
      seq("'", /[^\r\n]*/),
      seq(/[rR][eE][mM]/, /[ \t][^\r\n]*/),
    ))),
  },
});

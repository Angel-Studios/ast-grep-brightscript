/// <reference types="tree-sitter-cli/dsl" />
// @ts-check
//
// BrighterScript (.bs) grammar — a SUPERSET of BrightScript.
//
// Authored as a tree-sitter grammar that INHERITS the BrightScript grammar and
// OVERRIDES only the "seam" rules it extends, then adds the BrighterScript
// productions. This mirrors grammar/brighterscript.ebnf's import+shadow over
// brightscript.ebnf (and how tree-sitter-typescript extends tree-sitter-
// javascript). New rule names mirror the EBNF non-terminals 1:1 so they line up
// with the layer="brighterscript" `kind`s in grammar/coverage.json and the
// EBNF<->node-types parity check (grammar/check_parity.py).
//
// Inherits the BrightScript scanner externals (IdentStart, _nl) verbatim:
// src/scanner.c is a renamed copy with the SAME reserved-word set, so the new
// BrighterScript keywords (namespace, class, ...) are CONTEXTUAL — the scanner
// emits IdentStart for them and the ci() keyword token (prec 2) wins only where
// the grammar makes the keyword valid.
//
// Expression-level type-cast `expr as T` (TypeCastExpression) is the outermost
// (loosest-binding) expression wrapper, chainable left-assoc. _Expression is split
// into two tiers mirroring bsc: _Expression == bsc expression(true) == an optional
// outermost cast over _ExpressionNoCast == bsc anonymousFunction() == the binary/
// postfix cascade + ternary/??. Postfix/call OBJECTS are _ExpressionNoCast, so a
// cast is never a `.`/`[]`/`(` object without parens (member/index/call bind inside
// anonymousFunction, before the cast) — that keeps `resp as a.b.c` / `x as T[]`
// attaching to the TYPE. The `as` token is shared with the typed positions
// (param/return/field/typed-assign/typed-for-each); the only genuine clash — a
// parameter DEFAULT followed by `as` — falls out of the cast's loosest precedence
// (bsc parses defaults with expression(findTypeCast=false), Parser.ts:1042), so the
// trailing `as Type` reads as the parameter's declared type, not a cast.

import base from '../tree-sitter-brightscript/grammar.js';

/** Case-insensitive keyword token (prec 2 so a keyword beats IdentStart). */
function ci(word) {
  return token(prec(2, new RegExp(
    [...word].map((ch) => {
      const lo = ch.toLowerCase(), hi = ch.toUpperCase();
      return lo !== hi ? `[${lo}${hi}]` : ch.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }).join(''),
  )));
}
/** Fused multi-word keyword token allowing optional spaces (`end class`/`endclass`). */
function fused(...words) {
  const word = (w) => [...w].map((ch) => {
    const lo = ch.toLowerCase(), hi = ch.toUpperCase();
    return lo !== hi ? `[${lo}${hi}]` : ch.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }).join('');
  return token(prec(2, new RegExp(words.map(word).join('[ \\t]*'))));
}

/** Statement/member block body (mirrors the base grammar's blockBody). */
function blockBody($) {
  return repeat(seq($._BlockItem, repeat1($.EOS)));
}
/** A member list: items each followed by 1+ statement terminators. */
function members($, item) {
  return repeat1(seq(item, repeat1($.EOS)));
}
/** Leading `(Annotation EOS)+` prefix used before annotatable declarations. */
function annotationPrefix($) {
  return repeat1(seq($.Annotation, repeat1($.EOS)));
}

export default grammar(base, {
  name: 'brighterscript',

  // Inherit the base externals (IdentStart, _nl) and append TemplateChars — a
  // run of literal `...` template text read by the scanner (src/scanner.c), so
  // the `'` comment opener is never skipped as an extra after a `${...}`
  // interpolation (R5). Order MUST match the scanner enum {IDENT_START, NL,
  // TEMPLATE_CHARS}. The brighterscript scanner is a distinct copy, so this added
  // external is brighterscript-only (the base grammar is unchanged).
  externals: ($, previous) => [...previous, $.TemplateChars],

  // The base now declares NO conflicts (the _Callable narrowing removed them), so
  // these are the only brighterscript-specific ones. The l-value conflicts
  // (AssignTarget vs the expression tiers) are likewise no longer needed.
  conflicts: $ => [
    // `?` is both the ternary operator and the `print` shorthand: in a then-less
    // single-line `if` body, `if x ? a : b` is ambiguous (ternary condition vs
    // `if x` + `? a` print). Keep both alive; context (a later `end if` / use in
    // expression position) decides.
    [$.TernaryExpr, $._PrintItem],
    // `as function` / `as sub`: the intrinsic type `function` and the typed-
    // function-type `function(params) as Ret` share the keyword prefix. The next
    // token (`(` -> TypedFunctionType, else IntrinsicType) decides; keep both alive.
    // Newly reachable via TypeCastExpression (`x as function(...)`).
    [$.IntrinsicType, $.TypedFunctionType],
  ],

  rules: {
    //========================================================================
    // top level — add the BrighterScript declarations
    //========================================================================
    _TopLevelItem: ($, previous) => choice(
      previous,
      $.AnnotatedItem,
      $.NamespaceStatement,
      $.ClassDeclaration,
      $.InterfaceDeclaration,
      $.EnumDeclaration,
      $.ConstStatement,
      $.ImportStatement,
      $.TypecastStatement,
      $.AliasStatement,
      $.TypeAliasStatement,
    ),

    //========================================================================
    // annotations
    //========================================================================
    AnnotatedItem: $ => seq(annotationPrefix($), $._AnnotatableDeclaration),
    Annotation: $ => seq('@', field('name', $._NameOrKeyword), optional(seq('(', optional(alias($._AnnotationArgs, $.ArgumentList)), ')'))),
    // Annotation arg list tolerant of newlines around/between args (R8): an
    // annotation `(...)` may span lines (`@params(`⏎`1,`⏎`2`⏎`)`). Aliased to
    // ArgumentList at the use site so the node kind matches the single-line
    // `@x(a, b)` form and no new kind is introduced (keeps L5 parity). `_nl` is
    // the external newline token — valid here because this rule explicitly admits
    // it, so the scanner emits and we consume it instead of erroring.
    _AnnotationArgs: $ => seq(
      optional($._nl),
      $._Expression,
      repeat(seq(optional($._nl), ',', optional($._nl), $._Expression)),
      optional($._nl),
    ),
    _AnnotatableDeclaration: $ => choice(
      $.NamespaceStatement, $.ClassDeclaration, $.InterfaceDeclaration,
      $.EnumDeclaration, $.ConstStatement, $.FunctionDeclaration, $.SubDeclaration,
    ),

    //========================================================================
    // dotted / qualified name (declaration, extends, new, custom type)
    //========================================================================
    // A segment AFTER a `.` may be a reserved word (`namespace mc.private`,
    // `new mc.Sub()`, type `mc.private.Bar`) — same AllowedProperties rule as
    // member access. The first segment stays a plain Identifier. R2c.
    QualifiedName: $ => prec.left(seq($.Identifier, repeat(seq('.', $._NameOrKeyword)))),

    //========================================================================
    // namespace
    //========================================================================
    NamespaceStatement: $ => seq(
      ci('namespace'), field('name', $.QualifiedName), repeat1($.EOS),
      optional(field('body', $.NamespaceBody)),
      fused('end', 'namespace'),
    ),
    NamespaceBody: $ => members($, $._NamespaceMember),
    _NamespaceMember: $ => choice(
      $.AnnotatedItem, $.NamespaceStatement, $.ClassDeclaration, $.InterfaceDeclaration,
      $.EnumDeclaration, $.ConstStatement, $.FunctionDeclaration, $.SubDeclaration,
    ),

    //========================================================================
    // class
    //========================================================================
    ClassDeclaration: $ => seq(
      // A class name may be a reserved word (`class Type`) — bsc allows it. R2d.
      ci('class'), field('name', $._NameOrKeyword),
      optional(seq(ci('extends'), field('parent', $.QualifiedName))),
      repeat1($.EOS),
      optional(field('body', $.ClassBody)),
      fused('end', 'class'),
    ),
    ClassBody: $ => members($, $._ClassMember),
    _ClassMember: $ => choice($.AnnotatedClassMember, $.FieldDeclaration, $.MethodDeclaration),
    AnnotatedClassMember: $ => seq(annotationPrefix($), choice($.FieldDeclaration, $.MethodDeclaration)),
    FieldDeclaration: $ => seq(
      optional(field('access', $.AccessModifier)),
      optional(ci('optional')),
      // A field name may be a reserved word (`public type as string`) per
      // BrighterScript AllowedProperties. R2a. The MethodDeclaration shares the
      // `function`/`sub` prefix, so [FieldDeclaration, MethodDeclaration] is a
      // declared conflict resolved by lookahead (a name+`(` is a method).
      field('name', $._NameOrKeyword),
      optional(seq(ci('as'), field('type', $.Type))),
      optional(seq('=', field('value', $._Expression))),
    ),
    MethodDeclaration: $ => seq(
      optional(field('access', $.AccessModifier)),
      optional(ci('override')),
      choice($._MethodFunction, $._MethodSub),
    ),
    // Methods inline the function/sub shape (rather than reusing the inherited
    // FunctionDeclaration/SubDeclaration) so the method NAME can also be `new` —
    // the constructor — which is otherwise a reserved keyword (for `new Foo()`).
    _MethodFunction: $ => seq(
      ci('function'), field('name', $._MethodName),
      '(', optional($.ParameterList), ')', optional($.ReturnType),
      repeat1($.EOS),
      optional(field('body', alias(blockBody($), $.Block))),
      $.EndFunction,
    ),
    _MethodSub: $ => seq(
      ci('sub'), field('name', $._MethodName),
      '(', optional($.ParameterList), ')', optional($.ReturnType),
      repeat1($.EOS),
      optional(field('body', alias(blockBody($), $.Block))),
      $.EndSub,
    ),
    // A class method name may be (almost) any keyword — `function run()`,
    // `function stop()`, the `new` constructor — per BrighterScript Allowed
    // properties. _NameOrKeyword (Identifier | the brighterscript _reserved_word,
    // which includes `new`/`class`/… and the inherited base keywords) covers it. R2a.
    _MethodName: $ => $._NameOrKeyword,
    AccessModifier: _ => choice(ci('public'), ci('protected'), ci('private')),

    //========================================================================
    // interface
    //========================================================================
    InterfaceDeclaration: $ => seq(
      ci('interface'), field('name', $._NameOrKeyword),
      optional(seq(ci('extends'), field('parent', $.QualifiedName))),
      repeat1($.EOS),
      optional(field('body', $.InterfaceBody)),
      fused('end', 'interface'),
    ),
    InterfaceBody: $ => members($, $._InterfaceMember),
    _InterfaceMember: $ => choice($.AnnotatedInterfaceMember, $.InterfaceField, $.InterfaceMethod),
    AnnotatedInterfaceMember: $ => seq(annotationPrefix($), choice($.InterfaceField, $.InterfaceMethod)),
    InterfaceField: $ => seq(optional(ci('optional')), field('name', $.Identifier), ci('as'), field('type', $.Type)),
    InterfaceMethod: $ => seq(
      optional(ci('optional')),
      choice(ci('function'), ci('sub')),
      field('name', $.Identifier), '(', optional($.ParameterList), ')', optional($.ReturnType),
    ),

    //========================================================================
    // enum
    //========================================================================
    EnumDeclaration: $ => seq(
      // An enum name may be a reserved word (`enum Type`) — bsc allows it. R2d.
      ci('enum'), field('name', $._NameOrKeyword), repeat1($.EOS),
      optional(field('body', $.EnumBody)),
      fused('end', 'enum'),
    ),
    EnumBody: $ => members($, $._EnumMember),
    _EnumMember: $ => choice($.AnnotatedEnumMember, $.EnumMemberDecl),
    AnnotatedEnumMember: $ => seq(annotationPrefix($), $.EnumMemberDecl),
    EnumMemberDecl: $ => seq(field('name', $._NameOrKeyword), optional(seq('=', field('value', $._Expression)))),

    //========================================================================
    // const / import / typecast / alias / type-alias
    //========================================================================
    ConstStatement: $ => seq(ci('const'), field('name', $._NameOrKeyword), '=', field('value', $._Expression)),
    ImportStatement: $ => seq(ci('import'), $.StringLiteral),
    TypecastStatement: $ => seq(ci('typecast'), field('target', $.Identifier), ci('as'), field('type', $.Type)),
    AliasStatement: $ => seq(ci('alias'), field('name', $.Identifier), '=', field('value', $.Identifier)),
    TypeAliasStatement: $ => seq(ci('type'), field('name', $.Identifier), '=', field('value', $.Type)),

    //========================================================================
    // expression extensions
    //========================================================================
    // Two tiers (mirroring bsc): _Expression == bsc expression(true) == a no-cast
    // expression optionally wrapped by an outermost type-cast; _ExpressionNoCast ==
    // bsc anonymousFunction() == the binary/postfix cascade + ternary/??. Routing
    // the cascade ONLY through _ExpressionNoCast (not _Expression directly) keeps a
    // single derivation path, so there is NO _Expression/_ExpressionNoCast
    // reduce-reduce ambiguity.
    _Expression: $ => choice($._ExpressionNoCast, $.TypeCastExpression),
    // Mirrors the inherited brightscript _Expression cascade (OrExpr..Primary) — a
    // NEW rule can't take `previous`, so the alternatives are listed — plus the
    // BrighterScript ternary/?? additions. Keep in sync with the base _Expression.
    _ExpressionNoCast: $ => choice(
      $.OrExpr, $.AndExpr, $.NotExpr, $.ComparisonExpr, $.BitshiftExpr,
      $.AdditiveExpr, $.MultiplicativeExpr, $.UnaryExpr, $.PowerExpr,
      // The callable tier reached only through the inherited _Callable (Primary +
      // postfix cascade), so a postfix/call object is never a binary/unary
      // expression without parens — see base _Callable (R6).
      $._Callable,
      $.TernaryExpr, $.NullCoalesceExpr,
    ),
    // Ternary / null-coalescing bind looser than every binary operator (prec 0).
    TernaryExpr: $ => prec.right(0, seq(
      field('condition', $._Expression), $.QUESTION,
      field('consequence', $._Expression), ':', field('alternative', $._Expression),
    )),
    NullCoalesceExpr: $ => prec.left(0, seq(field('left', $._Expression), '??', field('right', $._Expression))),
    // Type-cast `expr as Type`, chainable (`x as dynamic as string`). Binds LOOSEST
    // (prec -1, below ternary/??) so it wraps the whole expression, as bsc applies it
    // last; left-assoc via the _Expression operand for the cast chain. That loosest
    // precedence also settles the one genuine clash — a parameter DEFAULT followed by
    // `as`: bsc parses defaults with expression(findTypeCast=false) (Parser.ts:1042),
    // so the `as Type` is the parameter's declared type; the cast's -1 lets the
    // default reduce and Parameter take its own `as`, so the param-type reading wins.
    // A cast is NOT a postfix/call object (see PostfixExpr/CallExpression below), so
    // `resp as a.b.c` / `x as integer[]` attach the dotted name / `[]` to the TYPE,
    // not as member/index on the cast — exactly as bsc, where member/index/call live
    // inside anonymousFunction(). brighterscript.ebnf TypeCastExpression / impl note 9.
    TypeCastExpression: $ => prec.left(-1, seq(
      field('expression', $._Expression), ci('as'), field('type', $.Type),
    )),

    // primary additions (Primary is an inherited supertype; these become subtypes)
    Primary: ($, previous) => choice(
      previous,
      $.NewExpression, $.TemplateString, $.TaggedTemplate, $.RegexLiteral, $.BsSourceLiteral,
    ),
    NewExpression: $ => prec.right(seq(ci('new'), field('class', $.QualifiedName), '(', optional($.ArgumentList), ')')),

    // Postfix / call OBJECT is the no-cast expression: a type-cast is the OUTERMOST
    // wrapper and can never be the object of `.`/`[]`/`(`/`@.` without parens (bsc
    // parses member/index/call inside anonymousFunction(), before the cast loop).
    // Fully redefined (not `previous`) to swap the object AND fold in the callfunc
    // suffix `obj@.method(args)` in one rule.
    PostfixExpr: $ => prec.left(10, seq(
      field('object', $._Callable),
      choice($.IndexSuffix, $.MemberSuffix, $.AttributeSuffix, $.OptChainSuffix, $.CallfuncSuffix),
    )),
    CallExpression: $ => prec.left(10, seq(field('callee', $._Callable), $.CallSuffix)),
    CallfuncSuffix: $ => seq('@.', field('name', $._NameOrKeyword), '(', optional($.ArgumentList), ')'),

    // BrighterScript (unlike plain BrightScript) allows newlines INSIDE call
    // argument parens — `foo(`⏎`1,`⏎`2`⏎`)`, and notably a multi-line array arg
    // whose closing `]` is followed by a newline before the `)` (R9). bsc accepts
    // this in `.bs` but REJECTS the identical text in `.brs`, so the override is
    // brighterscript-only (base ArgumentList stays strict, matching .brs + the
    // device-validated newline-suppression design). `.bs` is transpiled to one
    // line before the device sees it, so there is no runtime impact. Newlines are
    // admitted around args and commas (the `_nl` external token becomes valid here
    // and the scanner emits it instead of erroring).
    ArgumentList: $ => seq(
      optional($._nl),
      $._Expression,
      repeat(seq(optional($._nl), ',', optional($._nl), $._Expression)),
      optional($._nl),
    ),

    // A bare callfunc call `obj@.method(args)` is a valid expression statement
    // (it ends in a call, like CallExpression). The base ExpressionStatement only
    // covers chains ending in a plain `(...)`; add the callfunc terminus (no-cast
    // object, like PostfixExpr).
    ExpressionStatement: ($, previous) => choice(
      previous,
      prec.left(10, seq($._Callable, $.CallfuncSuffix)),
    ),

    // BrighterScript's AllowedProperties: nearly every keyword (incl. the new
    // declaration keywords and source literals) may be used as a member/AA-key
    // name. Extend the inherited reserved-word-as-name set so `m.new()`,
    // `node.class`, etc. parse (brighterscript.ebnf implementer note 6).
    _reserved_word: ($, previous) => choice(
      previous,
      ci('new'), ci('class'), ci('namespace'), ci('interface'), ci('enum'),
      ci('const'), ci('import'), ci('typecast'), ci('alias'), ci('public'),
      ci('protected'), ci('private'), ci('override'), ci('optional'),
      ci('source_file_path'), ci('source_line_num'), ci('function_name'),
      ci('source_function_name'), ci('source_namespace_name'),
      ci('source_namespace_root_name'), ci('source_location'),
      ci('pkg_path'), ci('pkg_location'),
    ),

    // computed associative-array key `[ <const expr> ]: value`
    AAEntry: ($, previous) => choice(
      previous,
      seq('[', field('key', $._Expression), ']', ':', field('value', $._Expression)),
    ),

    //========================================================================
    // typed forms (override the inherited rules)
    //========================================================================
    // typed local assignment: `name as Type = value`
    AssignmentStatement: ($, previous) => choice(
      previous,
      seq(field('target', $.AssignTarget), ci('as'), field('type', $.Type), '=', field('value', $._Expression)),
    ),
    // for-each with a typed loop item
    ForEachStatement: $ => seq(
      ci('for'), ci('each'), field('item', $.Identifier),
      optional(seq(ci('as'), field('type', $.Type))),
      ci('in'), field('collection', $._Expression),
      repeat1($.EOS),
      optional(field('body', alias(blockBody($), $.Block))),
      fused('end', 'for'),
    ),

    //========================================================================
    // type grammar (override Type to the BrighterScript type language)
    //========================================================================
    Type: $ => $.BsTypeUnion,
    BsTypeUnion: $ => prec.left(seq($.BsTypePostfix, repeat(seq(choice(ci('or'), ci('and')), $.BsTypePostfix)))),
    BsTypePostfix: $ => prec.left(seq($._BsTypeAtom, repeat(seq('[', ']')))),
    _BsTypeAtom: $ => choice($.IntrinsicType, $.QualifiedName, $.TypedFunctionType, $.InlineInterfaceType, $.GroupedType),
    IntrinsicType: _ => choice(
      ci('boolean'), ci('integer'), ci('longinteger'), ci('float'), ci('double'),
      ci('string'), ci('object'), ci('function'), ci('dynamic'), ci('void'), ci('invalid'),
    ),
    // prec.right so the optional ReturnType is GREEDY: `x as function() as string`
    // attaches `as string` as this function-type's return, not as a chained cast on
    // the whole function-type (matches bsc's typedFunctionType()/typeToken()).
    TypedFunctionType: $ => prec.right(seq(choice(ci('function'), ci('sub')), '(', optional($.ParameterList), ')', optional($.ReturnType))),
    InlineInterfaceType: $ => seq('{', optional(seq($.InlineInterfaceField, repeat(seq(choice(',', $.EOS), $.InlineInterfaceField)))), '}'),
    InlineInterfaceField: $ => seq(optional(ci('optional')), field('name', $.Identifier), ci('as'), field('type', $.Type)),
    GroupedType: $ => seq('(', $.Type, ')'),

    //========================================================================
    // template strings / regex / source literals
    //========================================================================
    // TemplateChars is an EXTERNAL token (scanner-lexed) — see the externals
    // declaration above and src/scanner.c. A `${...}` interpolation; the `${`
    // opener is token.immediate; `}` closes it.
    TemplateString: $ => seq('`', repeat(choice($.TemplateInterpolation, $.TemplateChars)), '`'),
    TemplateInterpolation: $ => seq(token.immediate('${'), $._Expression, '}'),
    TaggedTemplate: $ => prec.right(11, seq(field('tag', $.Identifier), $.TemplateString)),

    // Regex literal /pattern/flags. A single token; disambiguated from division by
    // tree-sitter context-validity (a RegexLiteral is a Primary, valid only at an
    // operand position; `/` division is valid only after an operand).
    RegexLiteral: _ => token(prec(1, seq('/', repeat1(choice(/[^/\\\r\n]/, /\\./)), '/', /[a-zA-Z]*/))),

    // BrighterScript source-position literals (LINE_NUM is in the base grammar).
    BsSourceLiteral: _ => choice(
      ci('source_file_path'), ci('source_line_num'), ci('function_name'),
      ci('source_function_name'), ci('source_namespace_name'),
      ci('source_namespace_root_name'), ci('source_location'),
      ci('pkg_path'), ci('pkg_location'),
    ),
    // The `??` and `@.` operators are inlined as string literals in
    // NullCoalesceExpr / CallfuncSuffix (anonymous tokens); the EBNF spells them
    // OP_NULLCOALESCE / OP_CALLFUNC (UPPER_SNAKE token rules, parity-excluded).
  },
});

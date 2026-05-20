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
// Deferred to a later phase (modeled in the EBNF, not yet in this grammar):
// expression-level type-cast `expr as T` (TypeCastExpression).

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

  conflicts: ($, previous) => [
    ...previous,
    // `?` is both the ternary operator and the `print` shorthand: in a then-less
    // single-line `if` body, `if x ? a : b` is ambiguous (ternary condition vs
    // `if x` + `? a` print). Keep both alive; context (a later `end if` / use in
    // expression position) decides.
    [$.TernaryExpr, $._PrintItem],
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
    Annotation: $ => seq('@', field('name', $._NameOrKeyword), optional(seq('(', optional($.ArgumentList), ')'))),
    _AnnotatableDeclaration: $ => choice(
      $.NamespaceStatement, $.ClassDeclaration, $.InterfaceDeclaration,
      $.EnumDeclaration, $.ConstStatement, $.FunctionDeclaration, $.SubDeclaration,
    ),

    //========================================================================
    // dotted / qualified name (declaration, extends, new, custom type)
    //========================================================================
    QualifiedName: $ => prec.left(seq($.Identifier, repeat(seq('.', $.Identifier)))),

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
      ci('class'), field('name', $.Identifier),
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
      field('name', $.Identifier),
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
    _MethodName: $ => choice($.Identifier, alias(ci('new'), $.Identifier)),
    AccessModifier: _ => choice(ci('public'), ci('protected'), ci('private')),

    //========================================================================
    // interface
    //========================================================================
    InterfaceDeclaration: $ => seq(
      ci('interface'), field('name', $.Identifier),
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
      ci('enum'), field('name', $.Identifier), repeat1($.EOS),
      optional(field('body', $.EnumBody)),
      fused('end', 'enum'),
    ),
    EnumBody: $ => members($, $._EnumMember),
    _EnumMember: $ => choice($.AnnotatedEnumMember, $.EnumMemberDecl),
    AnnotatedEnumMember: $ => seq(annotationPrefix($), $.EnumMemberDecl),
    EnumMemberDecl: $ => seq(field('name', $.Identifier), optional(seq('=', field('value', $._Expression)))),

    //========================================================================
    // const / import / typecast / alias / type-alias
    //========================================================================
    ConstStatement: $ => seq(ci('const'), field('name', $.Identifier), '=', field('value', $._Expression)),
    ImportStatement: $ => seq(ci('import'), $.StringLiteral),
    TypecastStatement: $ => seq(ci('typecast'), field('target', $.Identifier), ci('as'), field('type', $.Type)),
    AliasStatement: $ => seq(ci('alias'), field('name', $.Identifier), '=', field('value', $.Identifier)),
    TypeAliasStatement: $ => seq(ci('type'), field('name', $.Identifier), '=', field('value', $.Type)),

    //========================================================================
    // expression extensions
    //========================================================================
    _Expression: ($, previous) => choice(previous, $.TernaryExpr, $.NullCoalesceExpr),
    // Ternary / null-coalescing bind looser than every binary operator (prec 0).
    TernaryExpr: $ => prec.right(0, seq(
      field('condition', $._Expression), $.QUESTION,
      field('consequence', $._Expression), ':', field('alternative', $._Expression),
    )),
    NullCoalesceExpr: $ => prec.left(0, seq(field('left', $._Expression), '??', field('right', $._Expression))),

    // primary additions (Primary is an inherited supertype; these become subtypes)
    Primary: ($, previous) => choice(
      previous,
      $.NewExpression, $.TemplateString, $.TaggedTemplate, $.RegexLiteral, $.BsSourceLiteral,
    ),
    NewExpression: $ => prec.right(seq(ci('new'), field('class', $.QualifiedName), '(', optional($.ArgumentList), ')')),

    // postfix addition: callfunc operator `obj@.method(args)`
    PostfixExpr: ($, previous) => choice(
      previous,
      prec.left(10, seq(field('object', $._Expression), $.CallfuncSuffix)),
    ),
    CallfuncSuffix: $ => seq('@.', field('name', $._NameOrKeyword), '(', optional($.ArgumentList), ')'),

    // A bare callfunc call `obj@.method(args)` is a valid expression statement
    // (it ends in a call, like CallExpression). The base ExpressionStatement only
    // covers chains ending in a plain `(...)`; add the callfunc terminus.
    ExpressionStatement: ($, previous) => choice(
      previous,
      prec.left(10, seq($._Expression, $.CallfuncSuffix)),
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
    TypedFunctionType: $ => seq(choice(ci('function'), ci('sub')), '(', optional($.ParameterList), ')', optional($.ReturnType)),
    InlineInterfaceType: $ => seq('{', optional(seq($.InlineInterfaceField, repeat(seq(choice(',', $.EOS), $.InlineInterfaceField)))), '}'),
    InlineInterfaceField: $ => seq(optional(ci('optional')), field('name', $.Identifier), ci('as'), field('type', $.Type)),
    GroupedType: $ => seq('(', $.Type, ')'),

    //========================================================================
    // template strings / regex / source literals
    //========================================================================
    TemplateString: $ => seq('`', repeat(choice($.TemplateInterpolation, $.TemplateChars)), '`'),
    // A run of template text: anything but ` $ \  ; an escape \X; or a $ not opening ${.
    TemplateChars: _ => token.immediate(prec(1, /([^`$\\]|\\[\s\S]|\$[^{])+/)),
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

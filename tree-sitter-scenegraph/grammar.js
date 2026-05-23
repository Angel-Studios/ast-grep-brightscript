/// <reference types="tree-sitter-cli/dsl" />
// @ts-check
//
// Roku SceneGraph XML grammar for tree-sitter / ast-grep.
// Translated from grammar/scenegraph.ebnf (the authoritative, device-corrected
// spec) + the vendored RokuSceneGraph.xsd enums. Rule names mirror the EBNF
// non-terminals 1:1 so they line up with the `kind`s in grammar/coverage.json
// (layer == "scenegraph") and with ast-grep patterns.
//
// DESIGN NOTES (verified empirically — see roadmap 03 + the task brief):
//  * XML element/attribute NAMES are case-SENSITIVE; SceneGraph framework names
//    (component/interface/field/function/script/children) have a single canonical
//    lowercase spelling and are matched literally. Keyword extraction (`word`)
//    makes `componentLibrary` lex as one Name, not `component` + `Library`.
//  * The <field type=...> VALUE is case-INSENSITIVE and `extends`/node-tag values
//    can be ARBITRARY user component names. Enumerations (FieldType /
//    BuiltinNodeClass / ExtendsValue / NodeName) are therefore SEMANTIC, not
//    structural: those rules capture the VALUE position as a generic token, NOT
//    restricted to the enum literals (scenegraph.ebnf implementer note 2).
//  * ast-grep 0.42.3 does NOT expand hidden supertypes, so EVERY coverage `kind`
//    is a CONCRETE visible node. Hidden helper rules (leading `_`) are only used
//    for plumbing that is not a coverage kind.
//  * The grammar is a lenient well-formed-XML document: the root accepts the
//    SceneGraph <component> AND bare fragments (a lone CDATA section, PI, comment,
//    a generic <a/> element, an XML decl with no root) because the parse-only
//    corpus contains exactly such fragments.
//  * BrightScript language injection: a <script> body appears as ScriptCData
//    (CDATA), ScriptText (bare char-data) or ScriptExternal (uri, no body). The
//    injectable BrightScript text is exposed as a clean named node so ast-grep
//    injection can target it — see ScriptCData/ScriptText below. We do NOT parse
//    BrightScript here.
//
// Distinguishing GenericElement (Layer-1 generic XML) from NodeElement (a
// SceneGraph node in markup): both are structurally "any Name tag", so they are
// disambiguated by CONTEXT — an element inside <children> / inside a node is a
// NodeElement; an element in generic document content is a GenericElement.

/** Case-insensitive token from a literal word (used for the case-insensitive
 *  field-type / bool attribute VALUES only, never for element/attr names). */
function ci(word) {
  return new RegExp(
    [...word].map((ch) => {
      const lo = ch.toLowerCase(), hi = ch.toUpperCase();
      return lo !== hi ? `[${lo}${hi}]` : ch.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }).join(''),
  );
}

export default grammar({
  name: 'scenegraph',

  // Whitespace is insignificant in XML structural positions. Comments and PIs are
  // NOT in `extras` because they are addressable coverage kinds that must appear
  // as real nodes in content/misc positions.
  extras: $ => [/\s+/],

  // Keyword extraction: framework element/attribute name keywords are matched
  // through the Name token, so e.g. <componentLibrary> is one Name not a keyword.
  word: $ => $.Name,

  // Genuine, must-be-deferred ambiguity: a <script>'s leading attributes are
  // consumed before its `type` value (and before its body / closing form) is
  // seen, so the parser cannot yet tell whether it is a plain BrightScript
  // inline, a BrighterScript inline, or an external (empty) script. The GLR
  // parser keeps all three alive until the type literal (ScriptAttributeBs) or
  // the closing token ('>' vs '/>') disambiguates. The body kind
  // (BrightScriptBody vs BrighterScriptBody) then follows from the chosen rule.
  conflicts: $ => [
    [$._ScriptInline, $._ScriptInlineBs, $.ScriptExternal],
    [$._ScriptInlineBs, $.ScriptExternal],
  ],

  rules: {
    // ----------------------------------------------------------------------
    // Document root (lenient: SceneGraph component OR generic XML fragment)
    // ----------------------------------------------------------------------
    // The first rule is the start symbol. A real SceneGraph file is
    //   prolog Component Misc*
    // but the parse-only corpus also contains bare fragments, so the root is a
    // prolog followed by any number of top-level items.
    SGDocument: $ => seq(
      optional(field('prolog', $.prolog)),
      repeat($._TopItem),
    ),

    // A top-level item: the SceneGraph component, a generic element, or stray
    // markup that may legally float at the document level / in fragments.
    _TopItem: $ => choice(
      $.Component,
      $.GenericElement,
      $.Comment,
      $.PI,
      $.CDSect,
      $.Reference,
      $.CharData,
    ),

    // ----------------------------------------------------------------------
    // Prolog: XML declaration + misc
    // ----------------------------------------------------------------------
    // Non-nullable (tree-sitter forbids an empty non-start rule): a prolog node
    // exists only when there is an XML declaration; leading/trailing comments and
    // PIs are ordinary top-level items (this keeps the document grammar
    // unambiguous). A document with no decl (e.g. just `<component/>`) has no
    // prolog node — fine: `sg.prolog.no_xmldecl` is a non-device leaf (kind
    // unchecked) and the `prolog` kind still exists in node-types.json.
    prolog: $ => seq($.XMLDecl),

    XMLDecl: $ => seq(
      '<?xml',
      $.VersionInfo,
      optional($.EncodingDecl),
      optional($.SDDecl),
      '?>',
    ),

    VersionInfo: $ => seq('version', $.Eq, $.AttValue),

    EncodingDecl: $ => seq('encoding', $.Eq, $.AttValue),

    SDDecl: $ => seq('standalone', $.Eq, $.AttValue),

    // ----------------------------------------------------------------------
    // Lexical: names, equals, quoted values
    // ----------------------------------------------------------------------
    // W3C XML Name. ':' is permitted (note 5) but carries no namespace meaning.
    Name: _ => /[A-Za-z_:][A-Za-z0-9_:.\-]*/,

    Eq: _ => '=',

    // AttValue: the quoted string content (may contain references). Named so it
    // is matchable as the coverage `AttValue` kind. The literal text run is
    // exposed as a visible `AttText` node (both quote styles alias to it) so an
    // ast-grep $meta-variable written in attribute-value position binds, e.g.
    // <field id="$ID"/> -> AttValue(AttText "$ID") -> metavar ID.
    AttValue: $ => choice(
      seq('"', repeat(choice(alias($._att_dq_chunk, $.AttText), $.Reference)), '"'),
      seq("'", repeat(choice(alias($._att_sq_chunk, $.AttText), $.Reference)), "'"),
    ),
    _att_dq_chunk: _ => token.immediate(prec(1, /[^<&"]+/)),
    _att_sq_chunk: _ => token.immediate(prec(1, /[^<&']+/)),

    // ----------------------------------------------------------------------
    // References, character data
    // ----------------------------------------------------------------------
    Reference: $ => choice($.EntityRef, $.CharRef),

    EntityRef: _ => token(seq('&', /[A-Za-z_:][A-Za-z0-9_:.\-]*/, ';')),

    CharRef: _ => token(choice(
      seq('&#', /[0-9]+/, ';'),
      seq('&#x', /[0-9a-fA-F]+/, ';'),
    )),

    // Character data between markup: a run of chars containing no markup
    // delimiter and not the CDATA-close. Must contain at least one non-whitespace
    // character so that whitespace-only runs are swallowed by `extras` instead of
    // forming spurious CharData nodes.
    CharData: _ => token(prec(-1, /[^<&\s]([^<&]*[^<&\s])?/)),

    // ----------------------------------------------------------------------
    // Comments, CDATA sections, processing instructions
    // ----------------------------------------------------------------------
    Comment: _ => token(seq('<!--', /([^-]|-[^-])*/, '-->')),

    // Generic CDATA section (NOT a script body). Coverage kind `CDSect`.
    CDSect: _ => token(seq('<![CDATA[', /([^\]]|\][^\]]|\]\][^>])*/, ']]>')),

    // Processing instruction. The '<?' start is a SEPARATE literal from XMLDecl's
    // '<?xml' literal, so the lexer's longest-match rule makes '<?xml' win for a
    // declaration and '<?' win for any other target (the regex engine has no
    // lookahead, so this literal-length tiebreak is how PITarget excludes "xml").
    PI: $ => seq('<?', $._pi_rest),
    _pi_rest: _ => token.immediate(seq(
      /[A-Za-z_:][A-Za-z0-9_:.\-]*/,
      optional(seq(/\s/, /([^?]|\?[^>])*/)),
      '?>',
    )),

    // ----------------------------------------------------------------------
    // Generic XML element (Layer 1)
    // ----------------------------------------------------------------------
    GenericElement: $ => choice(
      $.EmptyElemTag,
      seq($._GenericSTag, repeat($._GenericContent), $._GenericETag),
    ),

    EmptyElemTag: $ => seq('<', field('name', $.Name), repeat($.Attribute), '/>'),

    _GenericSTag: $ => seq('<', field('name', $.Name), repeat($.Attribute), '>'),
    _GenericETag: $ => seq('</', $.Name, '>'),

    _GenericContent: $ => choice(
      $.GenericElement,
      $.Reference,
      $.CDSect,
      $.PI,
      $.Comment,
      $.CharData,
    ),

    // A generic attribute: Name = AttValue.
    Attribute: $ => seq(field('name', $.Name), $.Eq, field('value', $.AttValue)),

    // ======================================================================
    // LAYER 2 — SceneGraph
    // ======================================================================

    // ----------------------------------------------------------------------
    // <component> root
    // ----------------------------------------------------------------------
    // The <component> root. Normally paired (<component>...</component>) but the
    // self-closing form <component .../> is also valid (and appears in the
    // parse-only corpus, e.g. sg.prolog.no_xmldecl `<component name="C" />`).
    Component: $ => choice(
      seq(
        '<', 'component', repeat($.ComponentAttribute), '>',
        repeat($._ComponentContent),
        '</', 'component', '>',
      ),
      seq('<', 'component', repeat($.ComponentAttribute), '/>'),
    ),

    // The child kinds may appear in ANY order / interleaved (real files put
    // <script> before <interface>, non-XSD order — sg.component.child_order).
    _ComponentContent: $ => choice(
      $.Interface,
      $.Script,
      $.Children,
      $.Customization,
      $.Comment,
      $.PI,
    ),

    // <customization> — the Instant-Resume element (suspendhandler / resumehandler)
    // that is NOT in the XSD (sg.component.customization). Parsed as a SceneGraph
    // child element; its attributes are generic name="value" pairs.
    Customization: $ => choice(
      seq(
        '<', 'customization', repeat($.CustomizationAttribute), '>',
        repeat(choice($.Comment, $.PI)),
        '</', 'customization', '>',
      ),
      seq('<', 'customization', repeat($.CustomizationAttribute), '/>'),
    ),

    // <customization> attributes: the Instant-Resume suspend/resume handlers (each
    // names a BrightScript callback), plus a generic name="value" fallthrough.
    CustomizationAttribute: $ => choice(
      seq(field('name', 'suspendhandler'), $.Eq, field('value', $.AttValue)),
      seq(field('name', 'resumehandler'), $.Eq, field('value', $.AttValue)),
      seq(field('name', $.Name), $.Eq, field('value', $.AttValue)),
    ),

    // Component attributes. `name` required; `extends` value is captured via
    // ExtendsValue; others are plain AttValues. A generic/namespaced attribute
    // (e.g. xmlns:xsi, xsi:noNamespaceSchemaLocation — sg.component.attr_namespaced)
    // falls through to the last alternative. Each alternative is a
    // ComponentAttribute node (the coverage kind).
    ComponentAttribute: $ => choice(
      seq(field('name', 'name'), $.Eq, field('value', $.AttValue)),
      seq(field('name', 'extends'), $.Eq, field('value', $.ExtendsAttValue)),
      seq(field('name', 'initialFocus'), $.Eq, field('value', $.AttValue)),
      seq(field('name', 'version'), $.Eq, field('value', $.AttValue)),
      seq(field('name', $.Name), $.Eq, field('value', $.AttValue)),
    ),

    // `extends` value: a built-in node class OR a user component name. Both are
    // captured as a generic ExtendsValue (semantic, not enum-restricted). The
    // BuiltinNodeClass node is produced when the value matches a known class so
    // that coverage `BuiltinNodeClass` is matchable; otherwise a bare value.
    ExtendsAttValue: $ => choice(
      seq('"', $.ExtendsValue, '"'),
      seq("'", $.ExtendsValue, "'"),
    ),
    // The user-component-name branch is exposed as AttText (the shared free-text
    // attribute node) so an ast-grep $meta-variable binds, e.g. extends="$BASE".
    ExtendsValue: $ => choice($.BuiltinNodeClass, alias($._ext_name, $.AttText)),
    _ext_name: _ => token.immediate(/[^"'<&]+/),

    // Built-in SceneGraph node classes (XSD `extends` enumeration). SEMANTIC:
    // captured so `kind: BuiltinNodeClass` matches the well-known classes; an
    // arbitrary user component name falls through to _ext_name above.
    BuiltinNodeClass: _ => token.immediate(prec(1, choice(
      'AnimationBase', 'Animation', 'ArrayGrid', 'Audio', 'BusySpinner',
      'ButtonGroup', 'Button', 'ChannelStore', 'CheckList',
      'ColorFieldInterpolator', 'ComponentLibrary', 'ContentNode', 'Dialog',
      'FloatFieldInterpolator', 'Font', 'GridPanel', 'Group', 'KeyboardDialog',
      'Keyboard', 'LabelList', 'Label', 'LayoutGroup', 'ListPanel', 'MarkupGrid',
      'MarkupList', 'MaskGroup', 'MiniKeyboard', 'Node', 'OverhangPanelSetScene',
      'Overhang', 'PanelSet', 'Panel', 'ParallelAnimation',
      'ParentalControlPinPad', 'PinDialog', 'PinPad', 'PosterGrid', 'Poster',
      'ProgressDialog', 'RadioButtonList', 'Rectangle', 'RowList', 'Scene',
      'ScrollableText', 'ScrollingLabel', 'SequentialAnimation', 'SimpleLabel',
      'SoundEffect', 'TargetGroup', 'TargetList', 'TargetSet', 'Task',
      'TextEditBox', 'TimeGrid', 'Timer', 'Vector2DFieldInterpolator', 'Video',
      'ZoomRowList',
    ))),

    // ----------------------------------------------------------------------
    // <interface>, <field>, <function>
    // ----------------------------------------------------------------------
    Interface: $ => choice(
      seq(
        '<', 'interface', '>',
        repeat(choice($.Field, $.Function, $.Comment, $.PI)),
        '</', 'interface', '>',
      ),
      seq('<', 'interface', '/>'),
    ),

    // <field> — always an empty element.
    Field: $ => seq('<', 'field', repeat($.FieldAttribute), '/>'),

    FieldAttribute: $ => choice(
      seq(field('name', 'id'), $.Eq, field('value', $.AttValue)),
      seq(field('name', 'type'), $.Eq, field('value', $.FieldTypeAttValue)),
      seq(field('name', 'value'), $.Eq, field('value', $.AttValue)),
      seq(field('name', 'alias'), $.Eq, field('value', $.AliasAttValue)),
      seq(field('name', 'onChange'), $.Eq, field('value', $.AttValue)),
      seq(field('name', 'alwaysNotify'), $.Eq, field('value', $.BoolAttValue)),
    ),

    // type="..." VALUE — case-insensitive, captured via FieldType. The whole
    // quoted thing is FieldTypeAttValue (a coverage kind).
    FieldTypeAttValue: $ => choice(
      seq('"', $.FieldType, '"'),
      seq("'", $.FieldType, "'"),
    ),

    // FieldType: SEMANTIC. Captures the type token in any case; NOT restricted to
    // the enum (note 2 — case-insensitive; unknown spellings are caught by lint).
    // Also accepts an ast-grep $meta-variable (a leading run of '$') so a pattern
    // like type="$T" binds — real field types never start with '$'.
    FieldType: _ => token.immediate(/\$+[A-Za-z_][A-Za-z0-9_]*|[A-Za-z][A-Za-z0-9]*/),

    // alias="node.field" micro-syntax. The body is exposed as AttText so an
    // ast-grep $meta-variable binds, e.g. alias="$A".
    AliasAttValue: $ => choice(
      seq('"', alias($._alias_body, $.AttText), '"'),
      seq("'", alias($._alias_body, $.AttText), "'"),
    ),
    _alias_body: _ => token.immediate(/[^"'<&]+/),

    // alwaysNotify="true|false" — matched case-insensitively (note 1). Also
    // accepts an ast-grep $meta-variable (leading '$' run) so alwaysNotify="$B"
    // binds — a real bool value is only true/false, never $-prefixed.
    BoolAttValue: $ => choice(
      seq('"', $.BoolText, '"'),
      seq("'", $.BoolText, "'"),
    ),
    BoolText: _ => token.immediate(choice(ci('true'), ci('false'), /\$+[A-Za-z_][A-Za-z0-9_]*/)),

    // <function name="..."/> — always an empty element.
    Function: $ => seq('<', 'function', repeat($.FunctionAttribute), '/>'),
    FunctionAttribute: $ => seq(field('name', 'name'), $.Eq, field('value', $.AttValue)),

    // ----------------------------------------------------------------------
    // <script> (BrightScript / BrighterScript embedding point)
    // ----------------------------------------------------------------------
    // A <script> embeds either plain BrightScript (type="text/brightscript",
    // body injected as `brightscript`) OR BrighterScript (type=
    // "text/brighterscript", body injected as `brighterscript`). The two are
    // distinguished by the `type` attribute LITERAL, and each inline form emits
    // a DISTINCT injectable body node (BrightScriptBody vs BrighterScriptBody)
    // so the two `languageInjections` entries in sgconfig.yml stay unambiguous.
    // The dialect is committed by the `type` attribute via a GLR conflict (the
    // parser keeps both inline branches alive until it lexes the type literal),
    // which is what lets a later-positioned body inherit the right body kind
    // even though XML attributes are order-independent.
    Script: $ => choice(
      $._ScriptInline,
      $._ScriptInlineBs,
      $.ScriptExternal,
    ),

    // Plain BrightScript inline script (default / text/brightscript).
    _ScriptInline: $ => seq(
      '<', 'script', repeat($.ScriptAttribute), '>',
      repeat(choice($.ScriptCData, $.ScriptText, $.Comment, $.PI)),
      '</', 'script', '>',
    ),

    // BrighterScript inline script (type="text/brighterscript"). Requires the
    // BrighterScript type attribute and exposes a BrighterScript body node.
    _ScriptInlineBs: $ => seq(
      '<', 'script',
      repeat($.ScriptAttribute), $.ScriptAttributeBs, repeat($.ScriptAttribute),
      '>',
      repeat(choice($.ScriptCDataBs, $.ScriptTextBs, $.Comment, $.PI)),
      '</', 'script', '>',
    ),

    // External script: empty <script .../> (no body). Coverage kind. No body to
    // inject, so the dialect need not be distinguished here — it accepts either a
    // BrightScript (ScriptAttribute) or a BrighterScript (ScriptAttributeBs) type
    // attribute via a single repeat (no body, so no body-kind ambiguity).
    ScriptExternal: $ => seq(
      '<', 'script', repeat(choice($.ScriptAttribute, $.ScriptAttributeBs)), '/>',
    ),

    ScriptAttribute: $ => choice(
      seq(field('name', 'type'), $.Eq, field('value', $.ScriptTypeAttValue)),
      seq(field('name', 'uri'), $.Eq, field('value', $.AttValue)),
    ),

    // The BrighterScript-selecting attribute: type="text/brighterscript". A
    // separate node from ScriptAttribute so the inline form that contains it is
    // unambiguously the BrighterScript dialect (and so its body is injected as
    // `brighterscript`).
    ScriptAttributeBs: $ => seq(
      field('name', 'type'), $.Eq, field('value', $.ScriptTypeBsAttValue),
    ),

    // type="text/brightscript" (the BrighterScript literal is handled solely by
    // ScriptTypeBsAttValue so the two type values are unambiguous).
    ScriptTypeAttValue: $ => choice(
      seq('"', alias('text/brightscript', $.ScriptType), '"'),
      seq("'", alias('text/brightscript', $.ScriptType), "'"),
    ),

    // type="text/brighterscript".
    ScriptTypeBsAttValue: $ => choice(
      seq('"', alias('text/brighterscript', $.ScriptType), '"'),
      seq("'", alias('text/brighterscript', $.ScriptType), "'"),
    ),

    // CDATA-wrapped BrightScript. The INJECTABLE BrightScript body is the
    // `content` field — a single named token holding the raw bytes between the
    // CDATA delimiters (ast-grep injects the brightscript grammar there).
    ScriptCData: $ => seq(
      '<![CDATA[',
      optional(field('content', alias($._cdata_body, $.BrightScriptBody))),
      ']]>',
    ),
    _cdata_body: _ => token(/([^\]]|\][^\]]|\]\][^>])+/),

    // Bare (non-CDATA) inline BrightScript. The INJECTABLE body is the `content`
    // field, the raw character-data text of the <script> element.
    ScriptText: $ => field('content', alias($._script_text_body, $.BrightScriptBody)),
    _script_text_body: _ => token(prec(-1, /[^<]+/)),

    // CDATA-wrapped BrighterScript. Mirrors ScriptCData but exposes the body as
    // a BrighterScriptBody node so ast-grep injects the `brighterscript` grammar
    // there (sgconfig.yml languageInjections kind: BrighterScriptBody).
    ScriptCDataBs: $ => seq(
      '<![CDATA[',
      optional(field('content', alias($._cdata_body, $.BrighterScriptBody))),
      ']]>',
    ),

    // Bare (non-CDATA) inline BrighterScript. Mirrors ScriptText with a
    // BrighterScriptBody injectable body node.
    ScriptTextBs: $ => field('content', alias($._script_text_body, $.BrighterScriptBody)),

    // ----------------------------------------------------------------------
    // <children> and node elements
    // ----------------------------------------------------------------------
    Children: $ => choice(
      seq(
        '<', 'children', '>',
        repeat(choice($.NodeElement, $.Comment, $.PI)),
        '</', 'children', '>',
      ),
      seq('<', 'children', '/>'),
    ),

    NodeElement: $ => choice(
      seq($.NodeStartTag, optional($.NodeContent), $.NodeEndTag),
      $.NodeEmptyTag,
    ),

    NodeStartTag: $ => seq('<', field('name', $.NodeName), repeat($.NodeAttribute), '>'),
    NodeEndTag: $ => seq('</', $.NodeName, '>'),
    NodeEmptyTag: $ => seq('<', field('name', $.NodeName), repeat($.NodeAttribute), '/>'),

    // The tag name: a built-in node class OR an arbitrary user component Name.
    // SEMANTIC: captured as a name; not restricted to BuiltinNodeClass. Wraps the
    // shared `Name` token (which is the `word` token, so it cannot be a duplicate
    // standalone terminal here).
    NodeName: $ => $.Name,

    // Node content: nested node elements interleaved with misc.
    NodeContent: $ => repeat1(choice($.NodeElement, $.Comment, $.PI)),

    // A node attribute = a field initializer (plus reserved id / role).
    NodeAttribute: $ => choice(
      seq(field('name', 'id'), $.Eq, field('value', $.AttValue)),
      seq(field('name', 'role'), $.Eq, field('value', $.RoleAttValue)),
      seq(field('name', $.Name), $.Eq, field('value', $.FieldInitValue)),
    ),

    // role="parentFieldName". The body is exposed as AttText so an ast-grep
    // $meta-variable binds, e.g. role="$R".
    RoleAttValue: $ => choice(
      seq('"', alias($._role_body, $.AttText), '"'),
      seq("'", alias($._role_body, $.AttText), "'"),
    ),
    _role_body: _ => token.immediate(/[^"'<&]+/),

    // A generic field-initializer value — structurally a quoted string.
    FieldInitValue: $ => $.AttValue,
  },
});

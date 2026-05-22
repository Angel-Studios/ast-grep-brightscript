// External scanner for the BrighterScript tree-sitter grammar.
//
// IDENTICAL in behavior to the BrightScript scanner (tree-sitter-brightscript/
// src/scanner.c) -- only the exported `tree_sitter_<name>_external_scanner_*`
// symbol prefix differs (brighterscript vs brightscript), because the grammar
// inherits the SAME two externals in the SAME order:
//   0: IdentStart  -- a whole identifier word that is NOT a reserved keyword.
//   1: _nl         -- a run of line breaks (a statement terminator).
//
// The BrighterScript-only keywords (namespace, class, interface, enum, const,
// import, typecast, alias, type, public, protected, private, optional, override,
// new) are deliberately NOT added to RESERVED: that makes them CONTEXTUAL
// keywords (the `ci()` token, prec 2, wins where the grammar makes the keyword
// valid; elsewhere the scanner emits IdentStart and they are ordinary names) --
// matching how BrighterScript itself treats them. So the reserved set is
// unchanged from the base scanner.

#include "tree_sitter/parser.h"
#include <string.h>
#include <ctype.h>

enum TokenType {
  IDENT_START,
  NL,
  TEMPLATE_CHARS,
};

// Hard reserved words. The BrightScript base set, PLUS the BrighterScript
// DECLARATION keywords that must be recognized at positions where an identifier
// is also valid (top-level/member start). Without reserving them the scanner
// emits IdentStart and they wrongly lex as identifiers (the external IdentStart
// token wins over the internal ci() keyword token). They therefore become HARD
// keywords in `.bs` (not usable as plain identifiers) -- which matches how
// BrighterScript treats them in these positions.
//   `new` IS reserved (so `new Foo()` is recognized in expression position); the
//   grammar re-admits `new` specifically as the constructor METHOD name.
// Still CONTEXTUAL (intentionally NOT reserved): as, in, extends, the intrinsic
// type names, or/and (already reserved), and the source-literal names -- each is
// only a keyword where the grammar makes IdentStart invalid.
static const char *const RESERVED[] = {
  "and", "box", "catch", "continue", "createobject", "dim", "each", "else",
  "elseif", "end", "endfor", "endfunction", "endif", "endsub", "endtry",
  "endwhile", "eval", "exit", "exitfor", "exitwhile", "false", "for", "function",
  "getglobalaa", "getlastruncompileerror", "getlastrunruntimeerror", "goto",
  "if", "invalid", "let", "library", "line_num", "mod", "next", "not", "objfun",
  "or", "pos", "print", "rem", "return", "run", "step", "stop", "sub", "tab",
  "then", "throw", "to", "true", "try", "type", "while",
  // --- BrighterScript declaration keywords ---
  "namespace", "class", "interface", "enum", "const", "import", "typecast",
  "alias", "new", "public", "protected", "private", "override", "optional",
  // --- BrighterScript source-position literals (recognized at expression
  //     position as BsSourceLiteral; LINE_NUM is handled by the base grammar) ---
  "source_file_path", "source_line_num", "function_name", "source_function_name",
  "source_namespace_name", "source_namespace_root_name", "source_location",
  "pkg_path", "pkg_location",
};
static const unsigned RESERVED_COUNT = sizeof(RESERVED) / sizeof(RESERVED[0]);

static bool is_reserved(const char *word, unsigned len) {
  for (unsigned i = 0; i < RESERVED_COUNT; i++) {
    const char *kw = RESERVED[i];
    if (strlen(kw) != len) continue;
    bool eq = true;
    for (unsigned j = 0; j < len; j++) {
      if (kw[j] != tolower((unsigned char)word[j])) { eq = false; break; }
    }
    if (eq) return true;
  }
  return false;
}

static inline bool is_ident_start(int32_t c) {
  return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_';
}
static inline bool is_ident_cont(int32_t c) {
  return is_ident_start(c) || (c >= '0' && c <= '9');
}
static inline bool is_hspace(int32_t c) {
  return c == ' ' || c == '\t' || c == '\f';
}
static inline bool is_newline(int32_t c) {
  return c == '\n' || c == '\r';
}

void *tree_sitter_brighterscript_external_scanner_create(void) { return NULL; }
void tree_sitter_brighterscript_external_scanner_destroy(void *p) { (void)p; }
unsigned tree_sitter_brighterscript_external_scanner_serialize(void *p, char *b) { (void)p; (void)b; return 0; }
void tree_sitter_brighterscript_external_scanner_deserialize(void *p, const char *b, unsigned n) { (void)p; (void)b; (void)n; }

bool tree_sitter_brighterscript_external_scanner_scan(void *payload, TSLexer *lexer,
                                                      const bool *valid_symbols) {
  (void)payload;

  // ---- TemplateChars : a run of literal text inside a `...` template string.
  // Lexed by the scanner (not an internal token) so that after a `${...}`
  // interpolation the `'` comment opener (and any other extra) is NEVER skipped:
  // the external scanner is consulted BEFORE extras-skipping, so it reads the
  // template text deterministically. The internal lexer could not, because the
  // interpolation's closing `}` shares its follow lex-state with the AA-literal
  // `}` (which legitimately skips extras for `{a:1} + b`), so a `'` right after
  // `}` was eaten as a Comment to EOL (R5). Checked FIRST, before the horizontal-
  // whitespace skip below, since leading spaces are template content. Stops
  // (without consuming) at a closing backtick, an interpolation opener `${`, or
  // EOF; consumes `\<char>` escapes; a lone `$` (not `${`) is content.
  if (valid_symbols[TEMPLATE_CHARS]) {
    bool has_content = false;
    for (;;) {
      lexer->mark_end(lexer);
      int32_t c = lexer->lookahead;
      if (c == '`' || c == 0) break;
      if (c == '\\') {
        lexer->advance(lexer, false);                       // backslash
        if (lexer->lookahead != 0) lexer->advance(lexer, false); // escaped char
        has_content = true;
        continue;
      }
      if (c == '$') {
        lexer->advance(lexer, false);                       // consume '$'
        if (lexer->lookahead == '{') break;                 // '${' opens interpolation
        has_content = true;                                 // lone '$' is content
        continue;
      }
      lexer->advance(lexer, false);
      has_content = true;
    }
    if (has_content) {
      lexer->result_symbol = TEMPLATE_CHARS;
      return true;
    }
    return false;
  }

  while (is_hspace(lexer->lookahead)) {
    lexer->advance(lexer, true);
  }

  // ---- _nl : a run of line breaks (collapsing blank lines / interspersed ws).
  if (valid_symbols[NL] && is_newline(lexer->lookahead)) {
    while (is_newline(lexer->lookahead) || is_hspace(lexer->lookahead)) {
      lexer->advance(lexer, false);
    }
    lexer->mark_end(lexer);
    lexer->result_symbol = NL;
    return true;
  }

  // ---- IdentStart : a whole non-reserved word. Also lexes ast-grep meta-
  // variables ($X, $$$ARGS) so structural patterns parse: a word may begin with
  // a run of '$' (the meta-variable sigil). Real BrighterScript never starts a
  // word with '$' (it is only a trailing type-designator, lexed by TypeSuffix),
  // so a leading '$' here can only be a meta-variable, never real code.
  if (valid_symbols[IDENT_START] &&
      (is_ident_start(lexer->lookahead) || lexer->lookahead == '$')) {
    char word[64];
    unsigned len = 0;
    bool meta = lexer->lookahead == '$';
    while (lexer->lookahead == '$') {
      if (len < sizeof(word) - 1) {
        word[len] = '$';
      }
      len++;
      lexer->advance(lexer, false);
    }
    // A lone '$' with no identifier following is a type-designator, not a meta-
    // variable: decline so the TypeSuffix lexer handles it.
    if (meta && len == 1 && !is_ident_cont(lexer->lookahead)) {
      return false;
    }
    while (is_ident_cont(lexer->lookahead)) {
      if (len < sizeof(word) - 1) {
        word[len] = (char)lexer->lookahead;
      }
      len++;
      lexer->advance(lexer, false);
    }
    bool reserved = !meta && len < sizeof(word) && is_reserved(word, len);
    if (!reserved) {
      lexer->mark_end(lexer);
      lexer->result_symbol = IDENT_START;
      return true;
    }
    return false;
  }

  return false;
}

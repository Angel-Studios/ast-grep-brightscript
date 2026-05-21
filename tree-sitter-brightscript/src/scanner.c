// External scanner for the BrightScript tree-sitter grammar.
//
// It produces exactly two tokens (order MUST match `externals` in grammar.js):
//   0: IdentStart  — a whole identifier word that is NOT a reserved keyword.
//   1: _nl         — a run of line breaks (a statement terminator).
//
// Why a scanner:
//  * Keyword/identifier disambiguation. BrightScript is case-insensitive, so
//    keywords are case-insensitive regex tokens. tree-sitter resolves two
//    context-valid tokens by precedence (not longest-match), so a keyword that
//    is a prefix of an identifier (`print` in `printer`, `invalid` in
//    `invalidate`) would wrongly win. The scanner reads the WHOLE word and only
//    emits IdentStart when the lower-cased word is not a hard reserved keyword;
//    otherwise it declines and the normal lexer matches the keyword token.
//    Contextual keywords (`mod`, `as`, `in`, the `as`-type names) are NOT in the
//    reserved set: they become IdentStart where an identifier is valid and the
//    keyword token elsewhere (the grammar makes IdentStart invalid in those
//    spots), driven by `valid_symbols`.
//  * Significant newlines. `_nl` is emitted only when `valid_symbols[_nl]` is
//    set, i.e. only where the grammar allows a statement terminator. Inside a
//    grouping `( expr )` a newline is not a valid terminator, so it is not
//    emitted and the stray newline errors (DEVICE_FACTS #14). Inside `[ ]`/`{ }`
//    and argument lists the grammar allows EOS, so it is emitted and consumed.

#include "tree_sitter/parser.h"
#include <string.h>
#include <ctype.h>

enum TokenType {
  IDENT_START,
  NL,
};

// Hard reserved words: the scanner declines IdentStart for these so the
// case-insensitive keyword token matches instead.
// Contextual keywords (as, in, integer, longinteger, float, double, string,
// boolean, object, dynamic, void, interface) are intentionally absent: they
// resolve via valid_symbols (IdentStart is invalid where they act as keywords).
// `mod` MUST be here though: it is a binary operator keyword that follows an
// operand, and in an if-condition IdentStart is also valid right after the first
// operand (a then-less single-line body could begin there), so without reserving
// `mod` the scanner would emit it as an identifier instead of the operator.
static const char *const RESERVED[] = {
  "and", "box", "catch", "continue", "createobject", "dim", "each", "else",
  "elseif", "end", "endfor", "endfunction", "endif", "endsub", "endtry",
  "endwhile", "eval", "exit", "exitfor", "exitwhile", "false", "for", "function",
  "getglobalaa", "getlastruncompileerror", "getlastrunruntimeerror", "goto",
  "if", "invalid", "let", "library", "line_num", "mod", "next", "not", "objfun",
  "or", "pos", "print", "rem", "return", "run", "step", "stop", "sub", "tab",
  "then", "throw", "to", "true", "try", "type", "while",
};
static const unsigned RESERVED_COUNT = sizeof(RESERVED) / sizeof(RESERVED[0]);

static bool is_reserved(const char *word, unsigned len) {
  // Linear scan with length+case-insensitive compare (list is small).
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

void *tree_sitter_brightscript_external_scanner_create(void) { return NULL; }
void tree_sitter_brightscript_external_scanner_destroy(void *p) { (void)p; }
unsigned tree_sitter_brightscript_external_scanner_serialize(void *p, char *b) { (void)p; (void)b; return 0; }
void tree_sitter_brightscript_external_scanner_deserialize(void *p, const char *b, unsigned n) { (void)p; (void)b; (void)n; }

bool tree_sitter_brightscript_external_scanner_scan(void *payload, TSLexer *lexer,
                                                    const bool *valid_symbols) {
  (void)payload;

  // Skip leading horizontal whitespace (it is `extras` either way).
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
  // a run of '$' (the meta-variable sigil). Real BrightScript never starts a word
  // with '$' (it is only a trailing type-designator, lexed by TypeSuffix), so a
  // leading '$' here can only be a meta-variable, never real code.
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
    // variable: decline so the TypeSuffix lexer handles it (span is dropped).
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
    // A word longer than the buffer cannot be a (short) reserved keyword; a meta-
    // variable word (leading '$') is never a reserved keyword.
    bool reserved = !meta && len < sizeof(word) && is_reserved(word, len);
    if (!reserved) {
      lexer->mark_end(lexer);
      lexer->result_symbol = IDENT_START;
      return true;
    }
    // Reserved: decline so the normal lexer matches the keyword token. We have
    // advanced over the word, but without mark_end the consumed span is dropped.
    return false;
  }

  return false;
}

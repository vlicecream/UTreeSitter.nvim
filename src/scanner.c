#include "tree_sitter/alloc.h"
#include "tree_sitter/parser.h"

#include <assert.h>
#include <string.h>
#include <wctype.h>

/**
 * Reuse the upstream C++ raw-string external scanner for this Unreal parser.
 * 这里复用上游 C++ 的 raw string external scanner，只把导出符号改成 unreal_cpp。
 */

enum TokenType {
  RAW_STRING_DELIMITER,
  RAW_STRING_CONTENT,
};

#define MAX_DELIMITER_LENGTH 16

typedef struct {
  uint8_t delimiter_length;
  wchar_t delimiter[MAX_DELIMITER_LENGTH];
} Scanner;

/**
 * Advance the lexer without skipping text.
 * 推进 lexer，但不跳过文本。
 */
static inline void advance(TSLexer *lexer) {
  lexer->advance(lexer, false);
}

/**
 * Reset the tracked raw-string delimiter state.
 * 重置当前记录的 raw string 分隔符状态。
 */
static inline void reset(Scanner *scanner) {
  scanner->delimiter_length = 0;
  memset(scanner->delimiter, 0, sizeof scanner->delimiter);
}

/**
 * Scan the custom raw-string delimiter section between `R"` and `(`.
 * 扫描 `R"` 和 `(` 之间的自定义 raw-string 分隔符。
 */
static bool scan_raw_string_delimiter(Scanner *scanner, TSLexer *lexer) {
  if (scanner->delimiter_length > 0) {
    for (int i = 0; i < scanner->delimiter_length; ++i) {
      if (lexer->lookahead != scanner->delimiter[i]) {
        return false;
      }
      advance(lexer);
    }
    reset(scanner);
    return true;
  }

  for (;;) {
    if (scanner->delimiter_length >= MAX_DELIMITER_LENGTH ||
        lexer->eof(lexer) ||
        lexer->lookahead == '\\' ||
        iswspace(lexer->lookahead)) {
      return false;
    }

    if (lexer->lookahead == '(') {
      return scanner->delimiter_length > 0;
    }

    scanner->delimiter[scanner->delimiter_length++] = lexer->lookahead;
    advance(lexer);
  }
}

/**
 * Scan raw-string body content until the terminating `)` plus delimiter is reached.
 * 扫描 raw-string 正文，直到遇到 `)` 加分隔符的结束位置。
 */
static bool scan_raw_string_content(Scanner *scanner, TSLexer *lexer) {
  for (int delimiter_index = -1;;) {
    if (lexer->eof(lexer)) {
      lexer->mark_end(lexer);
      return true;
    }

    if (delimiter_index >= 0) {
      if (delimiter_index == scanner->delimiter_length) {
        if (lexer->lookahead == '"') {
          return true;
        }
        delimiter_index = -1;
      } else {
        if (lexer->lookahead == scanner->delimiter[delimiter_index]) {
          delimiter_index += 1;
        } else {
          delimiter_index = -1;
        }
      }
    }

    if (delimiter_index == -1 && lexer->lookahead == ')') {
      lexer->mark_end(lexer);
      delimiter_index = 0;
    }

    advance(lexer);
  }
}

/**
 * Create the external scanner payload.
 * 创建 external scanner 的状态对象。
 */
void *tree_sitter_unreal_cpp_external_scanner_create(void) {
  Scanner *scanner = ts_calloc(1, sizeof(Scanner));
  memset(scanner, 0, sizeof(Scanner));
  return scanner;
}

/**
 * Dispatch external scanning based on the valid symbol set.
 * 根据当前可接受 token 集合分派 external scanner 的扫描逻辑。
 */
bool tree_sitter_unreal_cpp_external_scanner_scan(void *payload, TSLexer *lexer, const bool *valid_symbols) {
  Scanner *scanner = (Scanner *)payload;

  if (valid_symbols[RAW_STRING_DELIMITER] && valid_symbols[RAW_STRING_CONTENT]) {
    return false;
  }

  if (valid_symbols[RAW_STRING_DELIMITER]) {
    lexer->result_symbol = RAW_STRING_DELIMITER;
    return scan_raw_string_delimiter(scanner, lexer);
  }

  if (valid_symbols[RAW_STRING_CONTENT]) {
    lexer->result_symbol = RAW_STRING_CONTENT;
    return scan_raw_string_content(scanner, lexer);
  }

  return false;
}

/**
 * Serialize the scanner state so incremental parsing can restore it.
 * 序列化 scanner 状态，供增量解析恢复使用。
 */
unsigned tree_sitter_unreal_cpp_external_scanner_serialize(void *payload, char *buffer) {
  static_assert(MAX_DELIMITER_LENGTH * sizeof(wchar_t) < TREE_SITTER_SERIALIZATION_BUFFER_SIZE,
                "Serialized delimiter is too long!");

  Scanner *scanner = (Scanner *)payload;
  size_t size = scanner->delimiter_length * sizeof(wchar_t);
  memcpy(buffer, scanner->delimiter, size);
  return (unsigned)size;
}

/**
 * Restore the scanner state from the serialized buffer.
 * 从序列化缓冲区恢复 scanner 状态。
 */
void tree_sitter_unreal_cpp_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
  assert(length % sizeof(wchar_t) == 0 && "Can't decode serialized delimiter!");

  Scanner *scanner = (Scanner *)payload;
  scanner->delimiter_length = length / sizeof(wchar_t);
  if (length > 0) {
    memcpy(&scanner->delimiter[0], buffer, length);
  }
}

/**
 * Free the external scanner payload.
 * 释放 external scanner 的状态对象。
 */
void tree_sitter_unreal_cpp_external_scanner_destroy(void *payload) {
  Scanner *scanner = (Scanner *)payload;
  ts_free(scanner);
}

; inherits: cpp

; Doxygen-style comments should inject as doxygen.
; Doxygen 风格注释应注入为 doxygen。
((comment) @injection.content
  (#lua-match? @injection.content "/[*/][!*/]<?[^a-zA-Z]")
  (#set! injection.language "doxygen"))

; Raw string literals preserve their embedded language markers.
; 原始字符串保持其内嵌语言标记。
(raw_string_literal
  delimiter: (raw_string_delimiter) @injection.language
  (raw_string_content) @injection.content)


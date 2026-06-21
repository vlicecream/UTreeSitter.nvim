; Conservative Verse highlights.
; These rules intentionally stay broad so the query remains useful across
; parser revisions and partial grammars.

[
  (line_comment)
  (block_comment)
] @comment

[
  (string)
  (interpreted_string)
] @string

[
  (escape_sequence)
] @string.escape

[
  (integer)
  (float)
] @number

[
  "true"
  "false"
] @boolean

[
  "module"
  "using"
  "class"
  "struct"
  "interface"
  "enum"
  "var"
  "const"
  "let"
  "if"
  "then"
  "else"
  "for"
  "in"
  "do"
  "loop"
  "break"
  "return"
  "defer"
  "spawn"
  "sync"
  "race"
  "branch"
  "suspends"
  "override"
  "public"
  "private"
  "protected"
  "internal"
  "where"
] @keyword

[
  ":="
  "="
  "->"
  "."
  ":"
  ","
  ";"
  "?"
  "!"
  "+"
  "-"
  "*"
  "/"
  "<"
  ">"
  "<="
  ">="
  "and"
  "or"
  "not"
] @operator

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

[
  "."
  ","
  ":"
  ";"
] @punctuation.delimiter

[
  (identifier)
  (name)
] @variable

[
  (type_identifier)
  (scoped_type_identifier)
] @type

[
  (builtin_type)
] @type.builtin

[
  (function_declaration
    name: (_) @function)
  (method_declaration
    name: (_) @function.method)
  (call_expression
    function: (_) @function)
]

[
  (parameter
    name: (_) @parameter)
] 

[
  (field_declaration
    name: (_) @property)
  (field_expression
    field: (_) @property)
] 

[
  (class_declaration
    name: (_) @type)
  (enum_declaration
    name: (_) @type)
  (module_declaration
    name: (_) @module)
] 

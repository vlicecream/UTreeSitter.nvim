;; inherits: cpp
;; extends

; 默认配色策略 / Default color strategy:
; - 普通 C++ 尽量沿用继承自 cpp query 的默认语义分组
;   Keep plain C++ on the inherited cpp query semantics.
; - Unreal 宏和预处理风格 token 优先映射到 directive / macro 类 capture
;   Map Unreal macros and preprocessor-like tokens to directive / macro captures.
; - 类型名和 specifier key 优先映射到 type 类 capture
;   Map type names and specifier keys to type-like captures.
; - 函数、方法、字段尽量保持 function / property 层次
;   Keep functions, methods, and fields on function / property style captures.
; - 字符串、数字、布尔值继续使用各自原生 capture
;   Keep strings, numbers, and booleans on their native captures.

; ========================
; C++ 预处理 / C++ Preprocessor
; ========================

(preproc_include) @keyword.directive
(preproc_def) @keyword.directive
(preproc_function_def) @keyword.directive
(preproc_call) @keyword.directive
(preproc_if) @keyword.directive
(preproc_ifdef) @keyword.directive
(preproc_elifdef) @keyword.directive
(preproc_else) @keyword.directive
(preproc_elif) @keyword.directive

(preproc_include
  path: (string_literal) @string.special)

(preproc_include
  path: (system_lib_string) @string.special)

; Raw string literals keep normal string coloring.
; 原始字符串保持普通字符串颜色。
(raw_string_literal) @string

; ========================
; C++ 核心类型 / C++ Core Types / Names
; ========================

(primitive_type) @type.builtin
(auto) @type.builtin
(type_identifier) @type

; Unreal/C++ projects often use namespaces as type-like prefixes.
; UE/C++ 项目里 namespace 经常作为类型前缀出现。
((namespace_identifier) @type
 (#match? @type "^[A-Z]"))

; ========================
; Unreal 反射宏 / Unreal Reflection Macros
; ========================

(unreal_class_macro) @keyword.directive.unreal_cpp
(unreal_struct_macro) @keyword.directive.unreal_cpp
(unreal_enum_macro) @keyword.directive.unreal_cpp

(unreal_property_macro) @keyword.directive.unreal_cpp
(unreal_function_macro) @function.macro.unreal_cpp

(unreal_umeta_macro) @keyword.directive.unreal_cpp

(unreal_generated_body_macro) @keyword.directive.unreal_cpp
(unreal_declare_class_macro) @keyword.directive.unreal_cpp
(unreal_define_default_object_initializer_macro) @keyword.directive.unreal_cpp

(unreal_deprecated_macro) @keyword.directive.unreal_cpp

; ========================
; UE Specifier 参数 / UE Specifiers (Blueprintable, EditAnywhere...)
; ========================

(unreal_specifier
  key: (identifier) @type.unreal_cpp)

(unreal_specifier
  key: (unreal_specifier_keyword) @type.unreal_cpp)

(unreal_specifier
  flag: (identifier) @type.unreal_cpp)

(unreal_specifier
  flag: (unreal_specifier_keyword) @type.unreal_cpp)

(unreal_specifier
  value: (unreal_specifier_value
    (string_literal) @string.unreal_cpp))

(unreal_specifier
  value: (unreal_specifier_value
    (number_literal) @number.unreal_cpp))

(unreal_specifier
  value: (unreal_specifier_value
    [
      (true)
      (false)
    ] @constant.builtin.unreal_cpp))

(unreal_specifier
  value: (unreal_specifier_value
    (identifier) @constant.unreal_cpp))

(unreal_specifier
  value: (unreal_specifier_value
    (qualified_unreal_identifier) @type.unreal_cpp))

(unreal_specifier
  value: (unreal_specifier_value
    (qualified_unreal_type_identifier) @type.unreal_cpp))

(unreal_specifier
  value: (unreal_specifier_value
    (template_type) @type.unreal_cpp))

; meta=(Key=Value) 元数据参数 / metadata specifier items
(unreal_meta_specifier_item
  key: (identifier) @type.unreal_cpp)

(unreal_meta_specifier_item
  key: (unreal_specifier_keyword) @type.unreal_cpp)

(unreal_meta_specifier_item
  flag: (identifier) @type.unreal_cpp)

(unreal_meta_specifier_item
  flag: (unreal_specifier_keyword) @type.unreal_cpp)

(unreal_meta_specifier_item
  value: (unreal_specifier_value
    (string_literal) @string.unreal_cpp))

(unreal_meta_specifier_item
  value: (unreal_specifier_value
    (number_literal) @number.unreal_cpp))

(unreal_meta_specifier_item
  value: (unreal_specifier_value
    [
      (true)
      (false)
    ] @constant.builtin.unreal_cpp))

(unreal_meta_specifier_item
  value: (unreal_specifier_value
    (identifier) @constant.unreal_cpp))

(unreal_meta_specifier_item
  value: (unreal_specifier_value
    (qualified_unreal_identifier) @type.unreal_cpp))

(unreal_meta_specifier_item
  value: (unreal_specifier_value
    (qualified_unreal_type_identifier) @type.unreal_cpp))

(unreal_meta_specifier_item
  value: (unreal_specifier_value
    (template_type) @type.unreal_cpp))

; ========================
; UE API 宏 / UE API Macro (XXX_API)
; ========================

(unreal_module_api_specifier) @keyword.directive.unreal_cpp

; FORCEINLINE 内联提示 / FORCEINLINE hint
(unreal_force_inline_specifier) @keyword.function.unreal_cpp

; ========================
; UE 声明宏 / UE Declaration Macros
; ========================

(unreal_declaration_macro
  name: (unreal_declaration_macro_name) @function.macro.delegate.unreal_cpp
  (#match? @function.macro.delegate.unreal_cpp "^DECLARE_.*DELEGATE"))

(unreal_declaration_macro
  name: (unreal_declaration_macro_name) @function.macro.delegate.unreal_cpp
  (#match? @function.macro.delegate.unreal_cpp "^DECLARE_EVENT$"))

(unreal_declaration_macro
  name: (unreal_declaration_macro_name) @macro.unreal_cpp)

; ========================
; 反射类型名 / Reflected Type Names
; ========================

(unreal_reflected_class_declaration
  name: (type_identifier) @type.unreal_cpp)

(unreal_reflected_struct_declaration
  name: (type_identifier) @type.unreal_cpp)

(unreal_reflected_enum_declaration
  name: (type_identifier) @type.enum.unreal_cpp)

(unreal_reflected_class_declaration
  name: (qualified_identifier) @type.unreal_cpp)

(unreal_reflected_struct_declaration
  name: (qualified_identifier) @type.unreal_cpp)

(unreal_reflected_enum_declaration
  name: (qualified_identifier) @type.enum.unreal_cpp)

; ========================
; Enums / Enumerators
; ========================

(enum_specifier
  name: (type_identifier) @type.enum.unreal_cpp)

(enum_specifier
  name: (qualified_identifier) @type.enum.unreal_cpp)

(enumerator
  name: (identifier) @constant.enum.unreal_cpp)

; ========================
; UE Pragma 指令 / UE Pragmas
; ========================

(unreal_pragma_macro) @keyword.directive.unreal_cpp

; ========================
; 函数与方法 / Functions and Methods
; ========================

(function_definition
  declarator: (function_declarator
    declarator: (identifier) @function.unreal_cpp))

(function_definition
  declarator: (function_declarator
    declarator: (field_identifier) @function.method.unreal_cpp))

(function_definition
  declarator: (function_declarator
    declarator: (qualified_identifier
      name: (identifier) @function.unreal_cpp)))

(function_definition
  declarator: (function_declarator
    declarator: (qualified_identifier
      name: (field_identifier) @function.method.unreal_cpp)))

(call_expression
  function: (identifier) @function.unreal_cpp)

(call_expression
  function: (qualified_identifier
    name: (identifier) @function.unreal_cpp))

(call_expression
  function: (qualified_identifier
    scope: (namespace_identifier) @type.unreal_cpp
    name: (identifier) @function.unreal_cpp))

(function_declarator
  declarator: (identifier) @function.unreal_cpp)

(function_declarator
  declarator: (qualified_identifier
    name: (identifier) @function.unreal_cpp))

(function_declarator
  declarator: (field_identifier) @function.method.unreal_cpp)

(template_function
  name: (identifier) @function.unreal_cpp)

(template_method
  name: (field_identifier) @function.method.unreal_cpp)

(unreal_function_declaration
  declarator: (function_declarator
    declarator: (field_identifier) @function.method.unreal_cpp))

(field_declaration
  declarator: (field_identifier) @property.unreal_cpp)

(field_declaration
  declarator: (function_declarator
    declarator: (field_identifier) @function.method.unreal_cpp))

; Member access needs two layers:
; - plain member access is a property
; - member access used as a call target is a method
; 成员访问分两层：
; - 普通成员访问是 property
; - 作为调用目标的成员访问是 method
(field_expression
  field: (field_identifier) @property.unreal_cpp)

(assignment_expression
  left: (identifier) @property.unreal_cpp)

[
 "class"
 "struct"
 "enum"
 "public"
 "private"
 "protected"
 "virtual"
 "override"
 "final"
 "const"
 "static"
] @keyword.unreal_cpp

(comment) @comment.unreal_cpp

; ========================
; 常量 / Constants
; ========================

(qualified_unreal_identifier) @type.unreal_cpp
(qualified_unreal_type_identifier) @type.unreal_cpp
(template_type) @type.unreal_cpp

(unreal_macro_fallback_value) @constant.unreal_cpp
(unreal_declaration_macro_name) @macro.unreal_cpp
(unreal_specifier_keyword) @constant.builtin.unreal_cpp

; ========================
; Unreal 常见对象与助手 / Unreal Common Objects and Helpers
; ========================

(call_expression
  function: (identifier) @function
  (#match? @function "^CreateWidget$|^NewObject$|^CreateDefaultSubobject$|^DuplicateObject$|^LoadObject$|^StaticLoadObject$|^LoadClass$|^StaticLoadClass$|^Cast$|^CastChecked$|^CastField$|^FindObject$|^GetDefault$|^GetMutableDefault$|^IsValid$|^IsValidLowLevel$|^UE_LOG$|^UE_CLOG$|^UE_LOGFMT$"))

(call_expression
  function: (qualified_identifier
    name: (identifier) @function
    (#match? @function "^CreateWidget$|^NewObject$|^CreateDefaultSubobject$|^DuplicateObject$|^LoadObject$|^StaticLoadObject$|^LoadClass$|^StaticLoadClass$|^Cast$|^CastChecked$|^CastField$|^FindObject$|^GetDefault$|^GetMutableDefault$|^IsValid$|^IsValidLowLevel$|^UE_LOG$|^UE_CLOG$|^UE_LOGFMT$")))

(call_expression
  function: (qualified_identifier
    scope: (namespace_identifier) @type
    name: (identifier) @function
    (#match? @function "^CreateWidget$|^NewObject$|^CreateDefaultSubobject$|^DuplicateObject$|^LoadObject$|^StaticLoadObject$|^LoadClass$|^StaticLoadClass$|^Cast$|^CastChecked$|^CastField$|^FindObject$|^GetDefault$|^GetMutableDefault$|^IsValid$|^IsValidLowLevel$|^UE_LOG$|^UE_CLOG$|^UE_LOGFMT$")))

(template_function
  name: (identifier) @function
  (#match? @function "^CreateWidget$|^NewObject$|^CreateDefaultSubobject$|^DuplicateObject$|^LoadObject$|^StaticLoadObject$|^LoadClass$|^StaticLoadClass$|^Cast$|^CastChecked$|^CastField$|^FindObject$|^GetDefault$|^GetMutableDefault$|^IsValid$|^IsValidLowLevel$"))

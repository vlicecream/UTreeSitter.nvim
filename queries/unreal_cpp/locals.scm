; inherits: cpp

; Unreal reflection macros create local scopes and definitions around reflected types.
; Unreal 反射宏会给被反射类型周围形成可解析的局部作用域和定义。
(unreal_reflected_class_declaration
  name: (type_identifier) @local.definition.type
  body: (_) @local.scope)

(unreal_reflected_struct_declaration
  name: (type_identifier) @local.definition.type
  body: (_) @local.scope)

(unreal_reflected_enum_declaration
  name: (type_identifier) @local.definition.type
  body: (_) @local.scope)

; Function-style Unreal declarations should still expose their declarator names as locals.
; 函数式 Unreal 声明也应暴露 declarator 名称，便于引用解析。
(unreal_function_declaration
  declarator: (function_declarator
    declarator: (field_identifier) @local.definition.method))

; Unreal function declarations often appear next to reflected members, so keep the whole node in scope.
; Unreal 函数声明通常和反射成员放在一起，整体节点也作为一个局部范围。
(unreal_function_declaration) @local.scope

; Common class / struct member declarations.
; 常见类 / 结构体成员声明。
(field_declaration
  declarator: (field_identifier) @local.definition.field)

(field_declaration
  declarator: (function_declarator
    declarator: (field_identifier) @local.definition.method))

; Parameters in Unreal-style declarations.
; Unreal 风格声明中的参数。
(parameter_declaration
  declarator: (identifier) @local.definition.parameter)

(parameter_declaration
  declarator: (field_identifier) @local.definition.parameter)

; Template declarations inside Unreal headers should still behave like C++ templates.
; Unreal 头文件里的模板声明仍然按 C++ 模板处理。
(template_declaration) @local.scope

; Control-flow scopes stay local like stock C++.
; 控制流作用域保持和原生 C++ 一致。
(try_statement) @local.scope
(catch_clause) @local.scope
(requires_expression) @local.scope
(lambda_expression) @local.scope


; inherits: cpp

; Classes / structs / enums.
; 类 / 结构体 / 枚举。
(unreal_reflected_class_declaration) @class.outer
(unreal_reflected_struct_declaration) @class.outer
(unreal_reflected_enum_declaration) @class.outer

((unreal_reflected_class_declaration
   body: (_) @class.inner))
((unreal_reflected_struct_declaration
   body: (_) @class.inner))
((unreal_reflected_enum_declaration
   body: (_) @class.inner))

; Normal C++ class and struct specifiers.
; 普通 C++ class / struct。
(class_specifier) @class.outer
(struct_specifier) @class.outer

((class_specifier
   body: (_) @class.inner))
((struct_specifier
   body: (_) @class.inner))

; Functions and methods.
; 函数和方法。
(function_definition) @function.outer
(function_declarator) @function.inner
(template_method) @function.inner
(template_function) @function.inner
(unreal_function_declaration) @function.outer

; Parameters.
; 参数。
(parameter_declaration) @parameter.outer
(parameter_declaration
  declarator: (_) @parameter.inner)

; Field declarations.
; 字段声明。
(field_declaration) @property.outer
(field_declaration
  declarator: (_) @property.inner)


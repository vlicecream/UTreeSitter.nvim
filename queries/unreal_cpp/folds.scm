; inherits: cpp

; Fold Unreal reflected type blocks and their class/struct bodies.
; 折叠 Unreal 反射类型块及其类 / 结构体主体。
[
  (unreal_reflected_class_declaration)
  (unreal_reflected_struct_declaration)
  (unreal_reflected_enum_declaration)
  (unreal_function_declaration)
] @fold

; Keep normal class / namespace / template folding from the inherited query.
; 保留继承来的普通类 / 命名空间 / 模板折叠。


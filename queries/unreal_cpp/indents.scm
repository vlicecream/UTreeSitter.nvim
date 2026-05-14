; inherits: cpp

; Keep Unreal reflected declarations aligned like normal C++ blocks.
; 让 Unreal 反射声明保持和普通 C++ 块一样的缩进。
(unreal_reflected_class_declaration) @indent.begin
(unreal_reflected_struct_declaration) @indent.begin
(unreal_reflected_enum_declaration) @indent.begin

; UPROPERTY / UFUNCTION are line-prefix macros, not indentation blocks.
; Pressing <CR> after `UPROPERTY()` should keep the next line aligned with the
; macro line; only pressing <CR> inside the parentheses should indent via the
; normal `(` rule.
; UPROPERTY / UFUNCTION 是行前缀宏，不应在宏后回车时额外进一层。

; Field initializer lists and control flow should behave like stock C++.
; 字段初始化列表和控制流保持和原生 C++ 一致。
(field_initializer_list) @indent.begin
(condition_clause) @indent.begin
(access_specifier) @indent.branch

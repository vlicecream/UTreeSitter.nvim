; inherits: cpp

; Keep Unreal reflected declarations aligned like normal C++ blocks.
; 让 Unreal 反射声明保持和普通 C++ 块一样的缩进。
(unreal_reflected_class_declaration) @indent.begin
(unreal_reflected_struct_declaration) @indent.begin
(unreal_reflected_enum_declaration) @indent.begin

; UPROPERTY / UFUNCTION blocks often sit inside class bodies.
; UPROPERTY / UFUNCTION 常出现在类体内，保持正常缩进即可。
(unreal_property_macro) @indent.begin
(unreal_function_macro) @indent.begin

; Field initializer lists and control flow should behave like stock C++.
; 字段初始化列表和控制流保持和原生 C++ 一致。
(field_initializer_list) @indent.begin
(condition_clause) @indent.begin
(access_specifier) @indent.branch


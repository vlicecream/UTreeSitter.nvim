/**
 * Unreal-aware C++ grammar built on top of tree-sitter-cpp.
 * 基于 tree-sitter-cpp 扩展的 Unreal C++ 语法，用来识别反射宏和常见 UE 声明结构。
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

const cpp = require("tree-sitter-cpp/grammar");

/**
 * Unreal-specific precedence hints.
 * Unreal 宏会和标准 C++ 声明打架，这里只保留少量必要优先级提示。
 */
const UNREAL_PREC = {
  REFLECTED_DECLARATION: 100,
  MACRO_STATEMENT: 50,
  SPECIFIER_ASSIGNMENT: 20,
  SPECIFIER_VALUE: 10,
};

/**
 * Common Unreal reflection specifiers.
 * 这些关键字覆盖常见 UE4/UE5 反射说明符，重点保证结构化解析而不是穷举所有语义。
 */
const UNREAL_SPECIFIER_KEYWORDS = [
  "Abstract",
  "Blueprintable",
  "BlueprintAuthorityOnly",
  "BlueprintCallable",
  "BlueprintImplementableEvent",
  "BlueprintNativeEvent",
  "BlueprintPure",
  "BlueprintReadOnly",
  "BlueprintReadWrite",
  "BlueprintType",
  "Category",
  "Client",
  "Config",
  "DefaultToInstanced",
  "Deprecated",
  "DisplayName",
  "EditAnywhere",
  "EditDefaultsOnly",
  "EditFixedSize",
  "EditInline",
  "EditInstanceOnly",
  "Exec",
  "GlobalConfig",
  "Instanced",
  "MinimalAPI",
  "NetMulticast",
  "NotBlueprintable",
  "Replicated",
  "ReplicatedUsing",
  "Reliable",
  "SaveGame",
  "Server",
  "ToolTip",
  "Transient",
  "Unreliable",
  "VisibleAnywhere",
  "VisibleDefaultsOnly",
  "VisibleInstanceOnly",
  "WithValidation",
];

/**
 * Delegate-style declaration macros that are worth naming explicitly.
 * 这些宏在 Unreal 头文件里很常见，但内部参数非常自由，因此整体按声明宏处理最稳。
 */
const UNREAL_NAMED_DECLARATION_MACROS = [
  "DECLARE_DELEGATE",
  "DECLARE_DELEGATE_OneParam",
  "DECLARE_DELEGATE_TwoParams",
  "DECLARE_DELEGATE_ThreeParams",
  "DECLARE_DELEGATE_FourParams",
  "DECLARE_DELEGATE_FiveParams",
  "DECLARE_DELEGATE_SixParams",
  "DECLARE_DELEGATE_SevenParams",
  "DECLARE_DELEGATE_EightParams",
  "DECLARE_DELEGATE_NineParams",
  "DECLARE_DELEGATE_RetVal",
  "DECLARE_DELEGATE_RetVal_OneParam",
  "DECLARE_DELEGATE_RetVal_TwoParams",
  "DECLARE_DELEGATE_RetVal_ThreeParams",
  "DECLARE_DELEGATE_RetVal_FourParams",
  "DECLARE_DELEGATE_RetVal_FiveParams",
  "DECLARE_DELEGATE_RetVal_SixParams",
  "DECLARE_DELEGATE_RetVal_SevenParams",
  "DECLARE_DELEGATE_RetVal_EightParams",
  "DECLARE_DELEGATE_RetVal_NineParams",
  "DECLARE_DYNAMIC_DELEGATE",
  "DECLARE_DYNAMIC_DELEGATE_OneParam",
  "DECLARE_DYNAMIC_DELEGATE_RetVal",
  "DECLARE_DYNAMIC_MULTICAST_DELEGATE",
  "DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam",
  "DECLARE_DYNAMIC_MULTICAST_SPARSE_DELEGATE",
  "DECLARE_DYNAMIC_MULTICAST_SPARSE_DELEGATE_OneParam",
  "DECLARE_DYNAMIC_MULTICAST_SPARSE_DELEGATE_TwoParams",
  "DECLARE_DYNAMIC_MULTICAST_SPARSE_DELEGATE_ThreeParams",
  "DECLARE_DYNAMIC_MULTICAST_SPARSE_DELEGATE_FourParams",
  "DECLARE_DYNAMIC_MULTICAST_SPARSE_DELEGATE_FiveParams",
  "DECLARE_EVENT",
  "DECLARE_MULTICAST_DELEGATE",
  "DECLARE_MULTICAST_DELEGATE_OneParam",
  "DECLARE_MULTICAST_DELEGATE_TwoParams",
  "DECLARE_TS_MULTICAST_DELEGATE",
  "ENUM_CLASS_FLAGS",
  "IMPLEMENT_GAME_MODULE",
  "IMPLEMENT_MODULE",
  "IMPLEMENT_PRIMARY_GAME_MODULE",
];

module.exports = grammar(cpp, {
  /**
   * Use a dedicated grammar name so Neovim can register it independently.
   * 使用独立 grammar 名称，方便在 Neovim 中单独注册 unreal_cpp 解析器。
   */
  name: "unreal_cpp",

  /**
   * Keep the upstream externals and do not invent new scanners.
   * 保持上游 external scanner 接口不变，避免额外 scanner 维护成本。
   */
  externals: ($, original) => original,

  /**
   * Unreal adds declaration prefixes that collide with normal C++ declarations.
   * Unreal 的宏前缀会和普通 C++ 声明产生歧义，因此这里只补少量确实需要的冲突。
   */
  conflicts: ($, original) => original.concat([
    [$.unreal_module_api_specifier, $.expression],
    [$.declaration, $._declaration_modifiers],
    [$.unreal_reflected_class_declaration],
    [$.unreal_reflected_struct_declaration],
    [$.unreal_reflected_enum_declaration],
    [$.unreal_specifier_value, $.expression],
  ]),

  rules: {
    // -----------------------------------------------------------------------
    // Top-level and block-level integration.
    // 顶层与块级集成点，负责把 Unreal 声明接进原始 C++ 入口。
    // -----------------------------------------------------------------------

    _top_level_item: ($, original) => choice(
      prec(UNREAL_PREC.MACRO_STATEMENT, $.unreal_declaration_macro),
      $.unreal_pragma_macro,
      original,
    ),

    _block_item: ($, original) => choice(
      prec(UNREAL_PREC.MACRO_STATEMENT, $.unreal_declaration_macro),
      $.unreal_pragma_macro,
      original,
    ),

    /**
     * Accept standalone `PRAGMA_*` tokens inside Unreal headers.
     * 允许把 `PRAGMA_*` 这种独立宏当成语句节点，以免打断类体或头文件解析。
     */
    unreal_pragma_macro: _ => token(prec(1, /PRAGMA_[A-Z0-9_]+/)),

    /**
     * Support `#pragma` lines directly because Unreal headers use them heavily.
     * 支持直接解析 `#pragma` 行，Unreal 头文件里经常会和自定义宏混用。
     */
    preproc_directive: ($, original) => choice(
      seq(
        "#",
        alias($._unreal_pragma_keyword, $.identifier),
        optional(alias($._unreal_pragma_argument, $.preproc_arg)),
        "\n",
      ),
      original,
    ),

    _unreal_pragma_keyword: _ => "pragma",
    _unreal_pragma_argument: _ => token.immediate(prec(-1, /.*/)),

    // -----------------------------------------------------------------------
    // Declaration-level integration.
    // 声明级别集成，负责让反射类、属性、函数和过时宏挂进 C++ 主干。
    // -----------------------------------------------------------------------

    declaration: ($, original) => choice(
      prec(UNREAL_PREC.REFLECTED_DECLARATION, $.unreal_reflected_class_declaration),
      prec(UNREAL_PREC.REFLECTED_DECLARATION, $.unreal_reflected_struct_declaration),
      prec(UNREAL_PREC.REFLECTED_DECLARATION, $.unreal_reflected_enum_declaration),
      seq($.unreal_deprecated_macro, original),
      original,
    ),

    /**
     * Allow UPROPERTY before standard field declarations.
     * 允许 UPROPERTY 作为字段声明前缀，同时保留标准 C++ 字段解析。
     */
    field_declaration: ($, original) => choice(
      seq(
        $.unreal_deprecated_macro,
        $.unreal_property_macro,
        original,
      ),
      seq(
        $.unreal_property_macro,
        original,
      ),
      seq(
        $.unreal_deprecated_macro,
        original,
      ),
      original,
    ),

    /**
     * Allow UFUNCTION before out-of-line definitions for coverage.
     * 允许 UFUNCTION 出现在函数定义前，用于兼容少量头文件中的定义写法。
     */
    function_definition: ($, original) => choice(
      seq($.unreal_deprecated_macro, $.unreal_function_macro, original),
      seq($.unreal_function_macro, original),
      seq($.unreal_deprecated_macro, original),
      original,
    ),

    /**
     * Inject Unreal-aware members inside class/struct bodies.
     * 把 Unreal 类体成员接入 field_declaration_list，避免 GENERATED_BODY 等宏被当成错误。
     */
    _field_declaration_list_item: ($, original) => choice(
      $.unreal_generated_body_macro,
      $.unreal_declare_class_macro,
      $.unreal_define_default_object_initializer_macro,
      $.unreal_declaration_macro,
      $.unreal_reflected_class_declaration,
      $.unreal_reflected_struct_declaration,
      $.unreal_reflected_enum_declaration,
      $.unreal_function_declaration,
      $.unreal_pragma_macro,
      original,
    ),

    /**
     * Unreal method declarations often use UFUNCTION plus normal method syntax.
     * Unreal 方法常带 UFUNCTION 前缀，但主体仍然是标准 C++ 方法声明。
     */
    unreal_function_declaration: $ => seq(
      optional($.unreal_deprecated_macro),
      $.unreal_function_macro,
      $._declaration_specifiers,
      field("declarator", $._field_declarator),
      optional($.attribute_specifier),
      ";",
    ),

    /**
     * Keep declaration modifiers aligned with upstream C++ and let deprecated macros stay as outer
     * declaration/function prefixes, otherwise the generator sees two competing parse paths.
     * 声明修饰符尽量贴近上游 C++，过时宏只保留在声明/函数外层前缀，否则生成器会看到两条竞争路径。
     */
    _declaration_modifiers: ($, original) => original,

    storage_class_specifier: ($, original) => choice(
      original,
      $.unreal_module_api_specifier,
      $.unreal_force_inline_specifier,
    ),

    /**
     * Constructor specifiers should flow through the upstream C++ path.
     * 构造函数修饰符保持走上游 C++ 路径，避免与 storage/declaration modifiers 重复收同一宏。
     */
    _constructor_specifiers: ($, original) => original,

    /**
     * Unreal enum entries frequently use trailing UMETA annotations.
     * Unreal 枚举项常带 UMETA 尾注，因此在 enumerator 后补一个可选宏。
     */
    enumerator: ($, original) => seq(
      original,
      optional($.unreal_umeta_macro),
    ),

    /**
     * Unreal classes and structs often place `XXX_API` between keyword and name.
     * Unreal 类和结构体常在 `class/struct` 与类型名之间插入 `XXX_API` 宏。
     */
    _class_declaration_item: $ => prec.right(seq(
      choice(
        seq(
          optional($.unreal_module_api_specifier),
          field("name", $._class_name),
        ),
        seq(
          optional($.unreal_module_api_specifier),
          optional(field("name", $._class_name)),
          optional($.virtual_specifier),
          optional($.base_class_clause),
          field("body", $.field_declaration_list),
        ),
      ),
      optional($.attribute_specifier),
    )),

    /**
     * Unreal enums can also use `XXX_API` before the enum name.
     * Unreal 枚举也可能在名称前带模块 API 宏，这里直接并入 enum_specifier。
     */
    enum_specifier: $ => prec.right(seq(
      "enum",
      optional(choice("class", "struct")),
      optional($.unreal_module_api_specifier),
      choice(
        seq(
          field("name", $._class_name),
          optional($._enum_base_clause),
          optional(field("body", $.enumerator_list)),
        ),
        field("body", $.enumerator_list),
      ),
      optional($.attribute_specifier),
    )),

    // -----------------------------------------------------------------------
    // Unreal reflected declarations.
    // 反射声明本体，保证 UCLASS/USTRUCT/UENUM 节点清晰独立。
    // -----------------------------------------------------------------------

    unreal_reflected_class_declaration: $ => prec(UNREAL_PREC.REFLECTED_DECLARATION, seq(
      $.unreal_class_macro,
      repeat($.comment),
      "class",
      optional($.unreal_module_api_specifier),
      field("name", $._class_name),
      optional($.base_class_clause),
      field("body", $.field_declaration_list),
      optional(";"),
    )),

    unreal_reflected_struct_declaration: $ => prec(UNREAL_PREC.REFLECTED_DECLARATION, seq(
      $.unreal_struct_macro,
      repeat($.comment),
      "struct",
      optional($.unreal_module_api_specifier),
      field("name", $._class_name),
      optional($.base_class_clause),
      field("body", $.field_declaration_list),
      optional(";"),
    )),

    unreal_reflected_enum_declaration: $ => prec(UNREAL_PREC.REFLECTED_DECLARATION, seq(
      $.unreal_enum_macro,
      repeat($.comment),
      "enum",
      optional(choice("class", "struct")),
      optional($.unreal_module_api_specifier),
      field("name", $._class_name),
      optional($._enum_base_clause),
      field("body", $.enumerator_list),
      optional(";"),
    )),

    // -----------------------------------------------------------------------
    // Unreal reflection macros.
    // 反射宏定义块，统一 `unreal_*` 命名，方便 query 与后续扩展。
    // -----------------------------------------------------------------------

    unreal_class_macro: $ => seq("UCLASS", $.unreal_argument_list),
    unreal_struct_macro: $ => seq("USTRUCT", $.unreal_argument_list),
    unreal_enum_macro: $ => seq("UENUM", $.unreal_argument_list),
    unreal_property_macro: $ => seq("UPROPERTY", $.unreal_argument_list),
    unreal_function_macro: $ => seq("UFUNCTION", $.unreal_argument_list),
    unreal_umeta_macro: $ => seq("UMETA", $.unreal_argument_list),

    /**
     * Generated body macros are explicit nodes because they are key editor anchors.
     * GENERATED_BODY 系列必须单独成节点，因为它们对 textobject/highlight 都很关键。
     */
    unreal_generated_body_macro: $ => seq(
      choice("GENERATED_BODY", "GENERATED_UCLASS_BODY", "GENERATED_USTRUCT_BODY"),
      "(",
      ")",
    ),

    unreal_declare_class_macro: $ => seq(
      "DECLARE_CLASS",
      $.unreal_argument_list,
    ),

    unreal_define_default_object_initializer_macro: $ => seq(
      "DEFINE_DEFAULT_OBJECT_INITIALIZER_CONSTRUCTOR_CALL",
      $.unreal_argument_list,
    ),

    /**
     * Deprecated macros are modeled structurally because they alter declaration shape.
     * UE_DEPRECATED 系列宏会改变声明前缀，因此需要结构化建模，而不是普通 fallback token。
     */
    unreal_deprecated_macro: $ => seq(
      choice("UE_DEPRECATED", "UE_DEPRECATED_FORGAME"),
      $.unreal_argument_list,
    ),

    unreal_module_api_specifier: _ => token(prec(1, /[A-Z0-9_]+_API/)),
    unreal_force_inline_specifier: _ => token(prec(1, /FORCEINLINE(_[A-Z0-9_]+)?/)),

    // -----------------------------------------------------------------------
    // Unreal specifier parsing.
    // Unreal 宏参数解析，重点保证结构清晰：flag、key=value、meta=(...)。
    // -----------------------------------------------------------------------

    /**
     * The argument list is reused by most Unreal reflection macros.
     * 绝大多数 Unreal 反射宏都复用这一层参数列表包装。
     */
    unreal_argument_list: $ => seq(
      "(",
      optional($.unreal_specifier_list),
      ")",
    ),

    /**
     * A comma-separated specifier list with optional trailing comma.
     * Unreal specifier 列表允许尾逗号，因此这里统一处理。
     */
    unreal_specifier_list: $ => commaSep1($.unreal_specifier),

    /**
     * A specifier is either a flag, a key-value pair, or a nested meta block.
     * 单个 Unreal specifier 可能是纯标记、键值对，或者 `meta=(...)` 这种嵌套块。
     */
    unreal_specifier: $ => choice(
      $.unreal_meta_specifier,
      prec.right(UNREAL_PREC.SPECIFIER_ASSIGNMENT, seq(
        field("key", choice($.unreal_specifier_keyword, $.identifier)),
        "=",
        field("value", $.unreal_specifier_value),
      )),
      field("flag", choice($.unreal_specifier_keyword, $.identifier)),
    ),

    /**
     * `meta=(...)` deserves its own node because it is heavily queried later.
     * `meta=(...)` 单独成节点，后面写 highlights 和 textobjects 会更稳。
     */
    unreal_meta_specifier: $ => seq(
      "meta",
      "=",
      "(",
      optional($.unreal_meta_specifier_list),
      ")",
    ),

    unreal_meta_specifier_list: $ => commaSep1($.unreal_meta_specifier_item),

    unreal_meta_specifier_item: $ => choice(
      prec.right(UNREAL_PREC.SPECIFIER_ASSIGNMENT, seq(
        field("key", choice($.identifier, $.unreal_specifier_keyword)),
        "=",
        field("value", $.unreal_specifier_value),
      )),
      field("flag", choice($.identifier, $.unreal_specifier_keyword)),
    ),

    /**
     * The value rule stays structured for common cases and falls back only for rare nested macros.
     * 这个值规则对常见情况保持结构化，只在少数嵌套宏场景下才退回宽松兜底。
     */
    unreal_specifier_value: $ => choice(
      $.string_literal,
      $.number_literal,
      $.true,
      $.false,
      alias($.qualified_identifier, $.qualified_unreal_identifier),
      alias($.qualified_type_identifier, $.qualified_unreal_type_identifier),
      $.template_type,
      $.identifier,
      seq("(", optional($.unreal_specifier_list), ")"),
      $.unreal_macro_fallback_value,
    ),

    unreal_specifier_keyword: _ => choice(...UNREAL_SPECIFIER_KEYWORDS),

    /**
     * This fallback intentionally swallows uncommon nested macro fragments like TEXT(...) or custom engine helpers.
     * 这个 fallback 有意吞掉少见嵌套宏片段，例如 TEXT(...) 或自定义引擎辅助宏。
     */
    unreal_macro_fallback_value: $ => seq(
      field("name", $.identifier),
      field("arguments", $.argument_list),
    ),

    // -----------------------------------------------------------------------
    // Unreal delegate and declaration macros.
    // Unreal 声明宏块，主要覆盖委托和模块实现宏。
    // -----------------------------------------------------------------------

    /**
     * Use one explicit node for delegate-like declaration macros.
     * 把委托和实现类宏统一为一个声明节点，减少规则爆炸并保持语法树可预测。
     */
    unreal_declaration_macro: $ => prec.left(UNREAL_PREC.MACRO_STATEMENT, seq(
      field("api", optional($.unreal_module_api_specifier)),
      field("name", $.unreal_declaration_macro_name),
      field("arguments", $.unreal_flexible_argument_list),
      optional(";"),
    )),

    unreal_declaration_macro_name: _ => token(prec(10, choice(
      ...UNREAL_NAMED_DECLARATION_MACROS,
      /DECLARE_[A-Z0-9_]+/,
      "DEPRECATED_CHARACTER_MOVEMENT_RPC",
    ))),

    /**
     * Declaration macro arguments are intentionally loose because they mix types, names, and custom tokens.
     * 声明宏参数故意保持宽松，因为它们会混合类型、名字和各种自定义 token。
     */
    unreal_flexible_argument_list: $ => seq(
      "(",
      optional($._unreal_flexible_argument_content),
      ")",
    ),

    _unreal_flexible_argument_content: $ => repeat1(choice(
      token(prec(10, /[^(),]+/)),
      ",",
      seq("(", optional($._unreal_flexible_argument_content), ")"),
    )),

    // -----------------------------------------------------------------------
    // Unreal-friendly primitive aliases.
    // Unreal 常用基础类型别名，帮助头文件更稳定地落入 type_specifier。
    // -----------------------------------------------------------------------

    primitive_type: ($, original) => choice(
      original,
      "int8",
      "uint8",
      "int16",
      "uint16",
      "int32",
      "uint32",
      "int64",
      "uint64",
      "FName",
      "FString",
      "FText",
    ),
  },
});

/**
 * Standard comma-separated helper with optional trailing comma.
 * 标准逗号分隔辅助函数，允许可选尾逗号。
 */
function commaSep1(rule) {
  return seq(rule, repeat(seq(",", rule)), optional(","));
}


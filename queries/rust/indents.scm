[
  (mod_item)
  (struct_item)
  (enum_item)
  (impl_item)
  (for_expression)
  (struct_expression)
  (match_expression)
  (tuple_expression)
  (match_arm)
  (match_block)
  (if_let_expression)
  (call_expression)
  (assignment_expression)
  (arguments)
  (block)
  (where_clause)
  (use_list)
  (macro_definition)
  (macro_rule)
  (token_tree)
] @indent

[
  "where"
  ")"
  "]"
  "}"
  ; use dedent for all "{" as it seems that there are no nested initializers
  ; in Rust that use it, but "(" and "[" are used for nested arrays/tuples
  "{"
] @dedent

[
  (line_comment)
  (raw_string_literal)
] @ignore

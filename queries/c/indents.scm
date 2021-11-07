[
  (init_declarator)
  (compound_statement)
  (preproc_arg)
  (field_declaration_list)
  (case_statement)
  (conditional_expression)
  (enumerator_list)
  (struct_specifier)
  (compound_literal_expression)
  ; dev
  (parameter_list)
  (if_statement)
  (while_statement)
  (for_statement)
] @indent


[
  "#define"
  "#ifdef"
  "#if"
  "#endif"
  "}"
  ")"
  "]"
] @branch

[
  (comment)
  (preproc_function_def)
] @ignore

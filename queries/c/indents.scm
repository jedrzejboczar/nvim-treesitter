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
  (statement_identifier) ; goto labels
  "else"
] @branch

; dedent only braces in functions, if statements, structs, etc.,
; but in things like nested array initializers
(compound_statement "{" @branch)
(field_declaration_list "{" @branch)

[
  (comment)
  (preproc_function_def)
  (string_literal)
] @ignore

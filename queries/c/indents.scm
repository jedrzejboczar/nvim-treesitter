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
  (parameter_list)
  (if_statement)
  (while_statement)
  (for_statement)
] @indent


[
  "}"
  ")"
  "]"
  "else"
] @dedent

[
  "#define"
  "#ifdef"
  "#if"
  "#else"
  "#endif"
  (statement_identifier) ; goto labels
] @zero

; dedent only braces in functions, if statements, structs, etc.,
; but in things like nested array initializers
; (compound_statement "{" @dedent)
(field_declaration_list "{" @dedent)

[
  (comment)
  (preproc_function_def)
  (string_literal)
] @ignore

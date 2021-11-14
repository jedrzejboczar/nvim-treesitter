[
  (block_statement)
  (case_statement)
  (token_string)
] @indent

[
  "(" ")"
  "{" "}"
  "[" "]"
] @dedent

[
  (line_comment)
  (block_comment)
  (nesting_block_comment)
] @ignore

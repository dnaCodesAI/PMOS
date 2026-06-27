#!/bin/bash
# Blocks saving a file that looks like a final PRD if it has no
# Compliance section. Claude Code sends the proposed write as JSON
# on stdin.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)

if [[ "$FILE_PATH" == *"PRD"*"FINAL"* || "$FILE_PATH" == *"prd"*"final"* ]]; then
  if ! echo "$INPUT" | grep -q "## Compliance"; then
    echo "BLOCKED: $FILE_PATH has no '## Compliance' section. ABC Bank" >&2
    echo "PRDs cannot be saved as final without one. Add the section," >&2
    echo "then try again." >&2
    exit 2
  fi
fi

exit 0

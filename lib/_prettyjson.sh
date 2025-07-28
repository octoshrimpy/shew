#! /usr/bin/env bash

# _prettyjson: Format JSON with jq or a fallback if jq is missing.
# use: echo '{"x":1}' | _prettyjson
_prettyjson() {
  local json_input

  # Read from argument(s) or stdin
  if [ $# -gt 0 ]; then
    json_input="$*"
  else
    json_input=$(cat)
  fi

  # Try using jq if available
  if command -v jq >/dev/null 2>&1; then
    echo "$json_input" | jq .
    return
  fi

  # Fallback: minimal formatter using grep + awk
  echo "$json_input" |
    grep -Eo '"[^"]*" *(: *([0-9]*|"[^"]*")[^{}\["]*|,)?|[^"\]\[\}\{]*|\{|\},?|\[|\],?|[0-9 ]*,?' |
    awk '{if ($0 ~ /^[}\]]/ ) offset-=4; printf "%*c%s\n", offset, " ", $0; if ($0 ~ /^[{\[]/) offset+=4}'
}

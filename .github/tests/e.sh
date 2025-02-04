#!/bin/bash

# shellcheck disable=all
jq -c --argjson rules '{"rules":{"a":1,"b":-1}}' '
reduce .things[] as $thing (
  {"things": [], "counts": {}}; 
  .counts[$thing.type] = (.counts[$thing.type] // 0) |
  .things += [
    $thing + {
      "keep": (
        ($rules.rules[$thing.type] == -1) or 
        (.counts[$thing.type] < $rules.rules[$thing.type])
      )
    }
  ] |
  .counts[$thing.type] += if ($rules.rules[$thing.type] == -1) then 0 else (.things[-1].keep | if . then 1 else 0 end) end
)
| .things
' .github/tests/e.json

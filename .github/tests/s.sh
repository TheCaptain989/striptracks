#!/bin/bash

# shellcheck disable=all
json='{"tracks":[{"properties":{"language":"eng"}},{"properties":{"language":"eng"}},{"properties":{"language":"fre"}}]}'

echo "$json" | jq -c --argjson rules_raw '{"languages":{"eng":1,"fre":-1,"mis":-1,"zxx":-1}}' '
# Parse input JSON and rules, then apply logic
reduce .tracks[] as $track (
  {"tracks": [], "counts": {}}; 
  .counts[$track.properties.language] = (.counts[$track.properties.language] // 0) |
  .tracks += [
    $track + {
      "keep": (
        ($rules_raw.languages[$track.properties.language] == -1) or 
        (.counts[$track.properties.language] < $rules_raw.languages[$track.properties.language])
      )
    }
  ] |
  .counts[$track.properties.language] +=
  if ($rules_raw.languages[$track.properties.language] == -1 or (.tracks[-1].keep | not)) then
    0
  else
    1
  end
)
| .tracks

'
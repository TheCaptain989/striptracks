#!/bin/bash

# shellcheck disable=all
json='{"attachments":[],"chapters":[],"container":{"properties":{"container_type":25,"is_providing_timestamps":true},"recognized":true,"supported":true,"type":"QuickTime/MP4"},"errors":[],"file_name":"ElephantsDream.mp4","global_tags":[],"identification_format_version":12,"track_tags":[],"tracks":[{"codec":"MPEG-4p10/AVC/H.264","id":0,"properties":{"language":"swe","number":1,"packetizer":"mpeg4_p10_video","pixel_dimensions":"1280x720"},"type":"video","striptracks_debug_log":"Debug|Parsing track ID:0 Type:video Name:null Lang:und Codec:MPEG-4p10/AVC/H.264 Default:null Forced:null","striptracks_keep":false},{"codec":"AAC","id":1,"properties":{"audio_bits_per_sample":16,"audio_channels":2,"audio_sampling_frequency":44100,"number":2,"language":"und"},"type":"audio","striptracks_debug_log":"Debug|Parsing track ID:1 Type:audio Name:null Lang:und Codec:AAC Default:null Forced:null","striptracks_log":"1: und (AAC)","striptracks_keep":false},{"codec":"TheCaptain989-forced","id":4,"properties":{"audio_bits_per_sample":16,"audio_channels":2,"audio_sampling_frequency":44100,"track_name":"Should include","language":"ger","number":5,"forced_track":true},"type":"audio","striptracks_debug_log":"Debug|Parsing track ID:4 Type:audio Name:Should include Lang:ger Codec:TheCaptain989-forced Default:null Forced:true","striptracks_log":"Info|Keeping forced audio track 4: ger (TheCaptain989-forced) \"Should include\"","striptracks_keep":true,"striptracks_rule":"forced","striptracks_limit":-1},{"codec":"TheCaptain989-default","id":5,"properties":{"audio_bits_per_sample":16,"audio_channels":2,"audio_sampling_frequency":44100,"track_name":"Should include","language":"ger","number":6,"default_track":true},"type":"audio","striptracks_debug_log":"Debug|Parsing track ID:5 Type:audio Name:Should include Lang:ger Codec:TheCaptain989-default Default:true Forced:null","striptracks_log":"Info|Keeping default audio track 5: ger (TheCaptain989-default) \"Should include\"","striptracks_keep":true,"striptracks_rule":"default","striptracks_limit":-1},{"codec":"TheCaptain989","id":2,"properties":{"audio_bits_per_sample":16,"audio_channels":2,"audio_sampling_frequency":44100,"track_name":"Should include","language":"eng","number":3},"type":"audio","striptracks_debug_log":"Debug|Parsing track ID:2 Type:audio Name:Should include Lang:eng Codec:TheCaptain989 Default:null Forced:null","striptracks_log":"Info|Keeping audio track 2: eng (TheCaptain989) \"Should include\"","striptracks_keep":true,"striptracks_limit":1},{"codec":"TheCaptain989-2","id":3,"properties":{"audio_bits_per_sample":16,"audio_channels":2,"audio_sampling_frequency":44100,"language":"eng","track_name":"Should exclude","number":4},"type":"audio","striptracks_debug_log":"Debug|Parsing track ID:3 Type:audio Name:Should exclude Lang:eng Codec:TheCaptain989-2 Default:null Forced:null","striptracks_log":"Info|Keeping audio track 3: eng (TheCaptain989-2) \"Should exclude\"","striptracks_keep":true,"striptracks_limit":1}],"warnings":[]}'

json='{ "attachments": [], "chapters": [], "container": { "properties": { "container_type": 25, "is_providing_timestamps": true }, "recognized": true, "supported": true, "type": "QuickTime/MP4" }, "errors": [], "file_name": "ElephantsDream.mp4", "global_tags": [], "identification_format_version": 12, "track_tags": [], "tracks": [ { "codec": "MPEG-4p10/AVC/H.264", "id": 0, "properties": { "language": "", "number": 1, "packetizer": "mpeg4_p10_video", "pixel_dimensions": "1280x720" }, "type": "video" }, { "codec": "AAC", "id": 1, "properties": { "audio_bits_per_sample": 16, "audio_channels": 2, "audio_sampling_frequency": 44100, "number": 2 }, "type": "audio" }, { "codec": "TheCaptain989-forced", "id": 4, "properties": { "audio_bits_per_sample": 16, "audio_channels": 2, "audio_sampling_frequency": 44100, "track_name": "Should include", "language": "ger", "number": 5, "forced_track": true }, "type": "audio" }, { "codec": "TheCaptain989-default", "id": 5, "properties": { "audio_bits_per_sample": 16, "audio_channels": 2, "audio_sampling_frequency": 44100, "track_name": "Should include", "language": "ger", "number": 6, "default_track": true }, "type": "audio" }, { "codec": "TheCaptain989", "id": 2, "properties": { "audio_bits_per_sample": 16, "audio_channels": 2, "audio_sampling_frequency": 44100, "track_name": "Should include", "language": "eng", "number": 3 }, "type": "audio" }, { "codec": "TheCaptain989-2", "id": 3, "properties": { "audio_bits_per_sample": 16, "audio_channels": 2, "audio_sampling_frequency": 44100, "language": "eng", "track_name": "Should exclude", "number": 4 }, "type": "audio" } ], "warnings": [] }'

echo "$json" | jq -c --argjson currentRules '{"languages":{"eng":1,"fre":-1,"mis":-1,"zxx":-1},"forced_languages":{"any":-1},"default_languages":{"ger":-1}}' '
# Parse input JSON and rules, then apply logic
reduce .tracks[] as $track (
  {"processed_tracks": [], "counts": {}, "forced_counts": {}, "default_counts": {}} ;
  (if ($track.properties.language == "" or $track.properties.language == null) then "und" else $track.properties.language end) as $track_lang |
  .counts[$track_lang] = (.counts[$track_lang] // 0) | .counts as $counts |
  if $track.properties.forced_track then .forced_counts[$track_lang] = (.forced_counts[$track_lang] // 0) else . end | .forced_counts as $forced_counts |
  if $track.properties.default_track then .default_counts[$track_lang] = (.default_counts[$track_lang] // 0) else . end | .default_counts as $default_counts |
  .processed_tracks += [
    $track |
    .striptracks_debug_log = "Debug|Parsing track ID:\(.id) Type:\(.type) Name:\(.properties.track_name) Lang:\($track_lang) Codec:\(.codec) Default:\(.properties.default_track) Forced:\(.properties.forced_track)" |
    if .type == "video" then
      .striptracks_keep = true
    elif .type == "audio" or .type == "subtitles" then
      .striptracks_log = "\(.id): \($track_lang) (\(.codec))\(if .properties.track_name then " \"" + .properties.track_name + "\"" else "" end)" |
      # Same logic for both audio and subtitles
      # (if .type == "audio" then $AudioRules else $SubsRules end) as $currentRules |
      if ($currentRules.languages["any"] == -1 or ($counts | add) < $currentRules.languages["any"] or
          $currentRules.languages[$track_lang] == -1 or $counts[$track_lang] < $currentRules.languages[$track_lang]) then
        .striptracks_keep = true |
        .striptracks_rule = "normal"
      elif (.properties.forced_track and
            ($currentRules.forced_languages["any"] == -1 or ($forced_counts | add) < $currentRules.forced_languages["any"] or
              $currentRules.forced_languages[$track_lang] == -1 or $forced_counts[$track_lang] < $currentRules.forced_languages[$track_lang])) then
        .striptracks_keep = true |
        .striptracks_rule = "forced"
      elif (.properties.default_track and
            ($currentRules.default_languages["any"] == -1 or ($default_counts | add) < $currentRules.default_languages["any"] or
              $currentRules.default_languages[$track_lang] == -1 or $default_counts[$track_lang] < $currentRules.default_languages[$track_lang])) then
        .striptracks_keep = true |
        .striptracks_rule = "default"
      else . end |
      if .striptracks_keep then
        .striptracks_log = "Info|Keeping \(if .striptracks_rule then .striptracks_rule + " " else "" end)\(.type) track " + .striptracks_log
      else
        .striptracks_keep = false
      end
    else . end
  ] | 
  .counts[$track_lang] +=
    if ($track.type == "audio" or $track.type == "subtitles") and .processed_tracks[-1].striptracks_keep then
      1
    else
      0
    end | 
  .forced_counts[$track_lang] +=
    if (($track.type == "audio" or $track.type == "subtitles") and $track.properties.forced_track and
      .processed_tracks[-1].striptracks_keep)
    then 
      1
    else
      0
    end |
  .default_counts[$track_lang] +=
    if (($track.type == "audio" or $track.type == "subtitles") and $track.properties.default_track and
      .processed_tracks[-1].striptracks_keep)
    then
      1
    else
      0
    end
)
# | del(.counts, .forced_counts, .default_counts)
# | .processed_tracks
'

echo $json | jq -c '.tracks | map(.properties.language)'
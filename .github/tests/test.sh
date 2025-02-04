#!/bin/bash

striptracks_pid=$$

function log {(
  while read -r
  do
    # shellcheck disable=2046
    echo $(date +"%Y-%m-%d %H:%M:%S.%1N")"|[$striptracks_pid]$REPLY"
  done
)}

striptracks_json='{
  "attachments": [],
  "chapters": [],
  "container": {
    "properties": {
      "container_type": 25,
      "is_providing_timestamps": true
    },
    "recognized": true,
    "supported": true,
    "type": "QuickTime/MP4"
  },
  "errors": [],
  "file_name": "ElephantsDream.mp4",
  "global_tags": [],
  "identification_format_version": 12,
  "track_tags": [],
  "tracks": [
    {
      "codec": "MPEG-4p10/AVC/H.264",
      "id": 0,
      "properties": {
        "language": "",
        "number": 1,
        "packetizer": "mpeg4_p10_video",
        "pixel_dimensions": "1280x720"
      },
      "type": "video"
    },
    {
      "codec": "AAC",
      "id": 1,
      "properties": {
        "audio_bits_per_sample": 16,
        "audio_channels": 2,
        "audio_sampling_frequency": 44100,
        "number": 2
      },
      "type": "audio"
    },
    {
      "codec": "TheCaptain989-forced",
      "id": 4,
      "properties": {
        "audio_bits_per_sample": 16,
        "audio_channels": 2,
        "audio_sampling_frequency": 44100,
        "track_name": "Should include",
        "language": "ger",
        "number": 5,
        "forced_track": true
      },
      "type": "audio"
    },
    {
      "codec": "TheCaptain989-default",
      "id": 5,
      "properties": {
        "audio_bits_per_sample": 16,
        "audio_channels": 2,
        "audio_sampling_frequency": 44100,
        "track_name": "Should include",
        "language": "ger",
        "number": 6,
        "default_track": true
      },
      "type": "audio"
    },
    {
      "codec": "TheCaptain989-subs",
      "id": 27,
      "properties": {
        "track_name": "Subs forced",
        "language": "fre",
        "number": 3,
        "forced_track": true
      },
      "type": "subtitles"
    },
    {
      "codec": "TheCaptain989",
      "id": 2,
      "properties": {
        "audio_bits_per_sample": 16,
        "audio_channels": 2,
        "audio_sampling_frequency": 44100,
        "track_name": "Should include",
        "language": "eng",
        "number": 3
      },
      "type": "audio"
    },
    {
      "codec": "TheCaptain989-2",
      "id": 3,
      "properties": {
        "audio_bits_per_sample": 16,
        "audio_channels": 2,
        "audio_sampling_frequency": 44100,
        "language": "eng",
        "track_name": "Should exclude",
        "number": 4
      },
      "type": "audio"
    }
  ],
  "warnings": []
}'

striptracks_audiokeep=":eng+1:fre:ger+d:any+f"
striptracks_subskeep=":any+f"

echo "Keeping Audio $striptracks_audiokeep     Subtitles $striptracks_subskeep"

echo "$striptracks_json" | jq -c --arg AudioKeep "$striptracks_audiokeep" \
--arg SubsKeep "$striptracks_subskeep" '
# Parse input string into language rules
def parse_language_codes(codes):
  # Supports f, d, and number modifiers
  # -1 default value in language key means to keep unlimited tracks
  # NOTE: Logic can result in duplicate keys, but jq just uses the last defined key
  codes | split(":")[1:] | map(split("+") | {lang: .[0], mods: .[1]}) |
  {languages: map(
      # Select tracks with no modifiers or only numeric modifiers
      (select(.mods == null) | {(.lang): -1}),
      (select(.mods | test("^[0-9]+$")?) | {(.lang): .mods | tonumber})
    ) | add,
    forced_languages: map(
      # Select tracks with f modifier
      select(.mods | contains("f")?) | {(.lang): ((.mods | scan("[0-9]+") | tonumber) // -1)}
    ) | add,
    default_languages: map(
      # Select tracks with d modifier
      select(.mods | contains("d")?) | {(.lang): ((.mods | scan("[0-9]+") | tonumber) // -1)}
    ) | add
  };

# Language rules for audio and subtitles, adding required audio tracks
(parse_language_codes($AudioKeep) | .languages += {"mis":-1,"zxx":-1}) as $AudioRules |
parse_language_codes($SubsKeep) as $SubsRules |

# Log chapter information
if (.chapters[0].num_entries) then
  .striptracks_log = "Info|Chapters: \(.chapters[].num_entries)"
else . end |
 
# Process tracks
reduce .tracks[] as $track (
  {"tracks": [], "counters": {"audio": {"normal": {}, "forced": {}, "default": {}}, "subtitles": {"normal": {}, "forced": {}, "default": {}}}};
  (if ($track.properties.language == "" or $track.properties.language == null) then "und" else $track.properties.language end) as $track_lang |
  .counters[$track.type].normal[$track_lang] = (.counters[$track.type].normal[$track_lang] // 0) |
  if $track.properties.forced_track then .counters[$track.type].forced[$track_lang] = (.counters[$track.type].forced[$track_lang] // 0) else . end |
  if $track.properties.default_track then .counters[$track.type].default[$track_lang] = (.counters[$track.type].default[$track_lang] // 0) else . end |
  .counters[$track.type] as $track_counters |
  .tracks += [
    $track |
    .striptracks_debug_log = "Debug|Parsing track ID:\(.id) Type:\(.type) Name:\(.properties.track_name) Lang:\($track_lang) Codec:\(.codec) Default:\(.properties.default_track) Forced:\(.properties.forced_track)" |
    if .type == "video" then
      .striptracks_keep = true
    elif .type == "audio" or .type == "subtitles" then
      .striptracks_log = "\(.id): \($track_lang) (\(.codec))\(if .properties.track_name then " \"" + .properties.track_name + "\"" else "" end)" |
      # Same logic for both audio and subtitles
      (if .type == "audio" then $AudioRules else $SubsRules end) as $currentRules |
      if ($currentRules.languages["any"] == -1 or ($track_counters.normal | add) < $currentRules.languages["any"] or
          $currentRules.languages[$track_lang] == -1 or $track_counters.normal[$track_lang] < $currentRules.languages[$track_lang]) then
        .striptracks_keep = true
        # | .striptracks_rule = "normal"
      elif (.properties.forced_track and
            ($currentRules.forced_languages["any"] == -1 or ($track_counters.forced | add) < $currentRules.forced_languages["any"] or
              $currentRules.forced_languages[$track_lang] == -1 or $track_counters.forced[$track_lang] < $currentRules.forced_languages[$track_lang])) then
        .striptracks_keep = true |
        .striptracks_rule = "forced"
      elif (.properties.default_track and
            ($currentRules.default_languages["any"] == -1 or ($track_counters.default | add) < $currentRules.default_languages["any"] or
              $currentRules.default_languages[$track_lang] == -1 or $track_counters.default[$track_lang] < $currentRules.default_languages[$track_lang])) then
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
  .counters[$track.type].normal[$track_lang] +=
    if .tracks[-1].striptracks_keep then
      1
    else 0 end | 
  .counters[$track.type].forced[$track_lang] +=
    if ($track.properties.forced_track and .tracks[-1].striptracks_keep) then
      1
    else 0 end |
  .counters[$track.type].default[$track_lang] +=
    if ($track.properties.default_track and .tracks[-1].striptracks_keep) then
      1
    else 0 end
) |

# Ensure at least one audio track is kept
if ((.tracks | map(select(.type == "audio")) | length == 1) and (.tracks | map(select(.type == "audio" and .striptracks_keep)) | length == 0)) then
  # If there is only one audio track and none are kept, keep the only audio track
  .tracks |= map(if .type == "audio" then
      .striptracks_log = "Warn|No audio tracks matched! Keeping only audio track " + .striptracks_log |
      .striptracks_keep = true
    else . end)
elif (.tracks | map(select(.type == "audio" and .striptracks_keep)) | length == 0) then
  # If no audio tracks are kept, first try to keep the default audio track
  .tracks |= map(if .type == "audio" and .properties.default_track then
      .striptracks_log = "Warn|No audio tracks matched! Keeping default audio track " + .striptracks_log |
      .striptracks_keep = true
    else . end) |
  # If still no audio tracks are kept, keep the first audio track
  if (.tracks | map(select(.type == "audio" and .striptracks_keep)) | length == 0) then
    (first(.tracks[] | select(.type == "audio"))) |= . +
    {striptracks_log: ("Warn|No audio tracks matched! Keeping first audio track " + .striptracks_log),
     striptracks_keep: true}
  else . end
else . end |

# Output simplified dataset
{ striptracks_log, tracks: [ .tracks[] | { id, type, forced: .properties.forced_track, default: .properties.default_track, striptracks_debug_log, striptracks_log, striptracks_keep } ] }
'

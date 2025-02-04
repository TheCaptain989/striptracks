#!/bin/bash

# shellcheck disable=all
striptracks_arr_config=/config/config.xml
striptracks_audiokeep=:org:jpn:eng:zho:chi:und
striptracks_debug=2
striptracks_eventtype=sonarr_eventtype
striptracks_json_quality_root=episodeFile
striptracks_log=/config/logs/striptracks.txt
striptracks_maxlog=4
striptracks_maxlogsize=512000
striptracks_newvideo='/data/media/tv/A Good Day to be a Dog (2023) [tvdbid-424266]/Season 01/A Good Day to be a Dog (2023) - S01E01 - The Curse Begins [HDTV-1080p][AC3 2.0][x264].mkv'
striptracks_pid=56770
striptracks_rescan_api=RescanSeries
striptracks_rescan_id=105
striptracks_script=striptracks-custom.sh
striptracks_subskeep=:eng:zho:chi:und
striptracks_title='A Good Day to be a Dog 01x01 - The Curse Begins'
striptracks_type=sonarr
striptracks_ver=2.10.0+0717927
striptracks_video='/data/media/tv/A Good Day to be a Dog (2023) [tvdbid-424266]/Season 01/A Good Day to be a Dog (2023) - S01E01 - The Curse Begins [HDTV-1080p][AC3 2.0][x264].mkv'
striptracks_video_api=episode
striptracks_video_folder='/data/media/tv/A Good Day to be a Dog (2023) [tvdbid-424266]'
striptracks_video_id=4729
striptracks_video_rootNode=.series
striptracks_video_type=series
striptracks_videofile_api=episodefile
striptracks_videofile_id=2728

striptracks_audiokeep=:kor:jpn:eng:zho:chi:und
striptracks_subskeep=:eng:zho:chi:und
striptracks_debug=1
striptracks_json=$(cat .github/tests/inc89.json)

function log {(
  while read -r
  do
    # shellcheck disable=2046
    echo $(date +"%Y-%m-%d %H:%M:%S.%1N")"|[$striptracks_pid]$REPLY"
  done
)}

# Process JSON data from MKVmerge; track selection logic
striptracks_json_processed=$(echo "$striptracks_json" | jq -jcM --arg AudioKeep "$striptracks_audiokeep" \
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
  {"tracks": [], "audio": {"normal": {}, "forced": {}, "default": {}}, "subtitles": {"normal": {}, "forced": {}, "default": {}}} ;
  (if ($track.properties.language == "" or $track.properties.language == null) then "und" else $track.properties.language end) as $track_lang |
  .[$track.type].normal[$track_lang] = (.[$track.type].normal[$track_lang] // 0) |
  if $track.properties.forced_track then .[$track.type].forced[$track_lang] = (.[$track.type].forced[$track_lang] // 0) else . end |
  if $track.properties.default_track then .[$track.type].default[$track_lang] = (.[$track.type].default[$track_lang] // 0) else . end |
  .[$track.type] as $track_counters |
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
  .[$track.type].normal[$track_lang] +=
    if .tracks[-1].striptracks_keep then
      1
    else 0 end | 
  .[$track.type].forced[$track_lang] +=
    if ($track.properties.forced_track and .tracks[-1].striptracks_keep) then
      1
    else 0 end |
  .[$track.type].default[$track_lang] +=
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
')
[ $striptracks_debug -ge 2 ] && echo "Debug|Track processing returned ${#striptracks_json_processed} bytes." | log
[ $striptracks_debug -ge 3 ] && echo "Track processing returned: $(echo "$striptracks_json_processed" | jq)" | awk '{print "Debug|"$0}' | log

# Write messages to log
echo "$striptracks_json_processed" | jq -crM --argjson Debug $striptracks_debug '
# Log removed tracks
def log_removed_tracks($type):
  if (.tracks | map(select(.type == $type and .striptracks_keep == false)) | length > 0) then
    "Info|Removing \($type) tracks: " +
    (.tracks | map(select(.type == $type and .striptracks_keep == false) | .striptracks_log) | join(", "))
  else empty end;

# Log the chapters, if any
.striptracks_log // empty,

# Log debug messages
( .tracks[] | (if $Debug >= 1 then .striptracks_debug_log else empty end),

 # Log messages for kept tracks
 (select(.striptracks_keep) | .striptracks_log // empty)
),

log_removed_tracks("audio"),
log_removed_tracks("subtitles"),

# Summary of kept tracks
"Info|Kept tracks: \(.tracks | map(select(.striptracks_keep)) | length) " +
"(audio: \(.tracks | map(select(.type == "audio" and .striptracks_keep)) | length), " +
"subtitles: \(.tracks | map(select(.type == "subtitles" and .striptracks_keep)) | length))"
' | log

# Check for no audio or subtitle tracks
if [ "$(echo "$striptracks_json_processed" | jq -crM '.tracks|map(select(.type=="audio" and .striptracks_keep))')" = "" ]; then
  striptracks_message="Warn|Script encountered an error when determining audio tracks to keep and must close."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 11
fi

# DEBUG/TEST
echo "$striptracks_json_processed" | jq -cr .
echo "Original tracks: $(echo "$striptracks_json" | jq -crM '
    "\(.tracks|map(select(.type=="audio" or .type =="subtitles"))|length) " +
    "(audio: \(.tracks|map(select(.type=="audio")) | length), " +
    "subtitles: \(.tracks|map(select(.type=="subtitles"))|length))"')"
echo "Processed tracks: $(echo "$striptracks_json_processed" | jq -crM '
    "\(.tracks|map(select((.type=="audio" or .type=="subtitles") and .striptracks_keep))|length) " +
    "(audio: \(.tracks|map(select(.type=="audio" and .striptracks_keep))|length), " +
    "subtitles: \(.tracks|map(select(.type=="subtitles" and .striptracks_keep))|length))"')"

# All tracks matched/no tracks removed
if [ "$(echo "$striptracks_json" | jq -crM '.tracks|map(select(.type=="audio" or .type=="subtitles"))|length')" = "$(echo "$striptracks_json_processed" | jq -crM '.tracks|map(select((.type=="audio" or .type=="subtitles") and .striptracks_keep))|length')" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|No tracks will be removed from video \"$striptracks_video\"" | log
  # Check if already MKV
  if [[ $striptracks_video == *.mkv ]]; then
    # Remuxing not performed
    striptracks_message="Info|No tracks would be removed from video. Setting Title only and exiting."
    echo "$striptracks_message" | log
    striptracks_mkvcommand="/usr/bin/mkvpropedit -q --edit info --set \"title=$striptracks_title\" \"$striptracks_video\""
    [ $striptracks_debug -ge 1 ] && echo "Debug|Executing: $striptracks_mkvcommand" | log
    striptracks_result=$(eval $striptracks_mkvcommand)
    striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
      striptracks_message=$(echo -e "[$striptracks_return] Error when setting video title: \"$striptracks_tempvideo\"\nmkvpropedit returned: $striptracks_result" | awk '{print "Error|"$0}')
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
      striptracks_exitstatus=13
    }
    end_script
  else
    [ $striptracks_debug -ge 1 ] && echo "Debug|Source video is not MKV. Remuxing anyway." | log
  fi
fi
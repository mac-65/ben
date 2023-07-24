#! /bin/bash
#
###############################################################################
# This is the "top level" music build file.  My expectations are that each
# song has a different “gold” source copy (there might also be duplicates)
# and probably a different way of extracting the particular track from the
# source.  E.g., some may be RAR archives, ZIP or straight FLAC sources.
#
###############################################################################
#H http://lifeofageekadmin.com/adding-cover-art-to-flac-file-from-command-line-and-gui/
# Using metaflac (part of flac-1.3.4-2.fc37.x86_64).
#   metaflac --import-picture-from="<image path>" "<FLAC path>"
#
#H https://stackoverflow.com/questions/67757023/adding-album-cover-art-to-flac-audio-files-using-ffmpeg
# Using ffmpeg
# ffmpeg -i audio.flac -i image.png -map 0:a -map 1 -codec copy -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic output.flac
#
#H https://stackoverflow.com/questions/2383973/an-efficient-way-to-detect-corrupted-png-files
# pngcheck +
#   find . -type f -print0 | xargs -0 -P0 sh -c 'magick identify +ping "$@" > /dev/null' sh
# magick identify is a tool from ImageMagick.
# By default, it only checks headers of the file for better performance.  Here
# we use ‘+ping’ to disable the feature and make identify read the whole file.
#
# https://stackoverflow.com/questions/22120041/prevent-libavformat-ffmpeg-from-adding-encoder-tag-to-output-help-strippin
#   https://trac.ffmpeg.org/ticket/6602
#   -fflags +bitexact
#
###############################################################################
# https://pypi.org/project/ffcuesplitter/
#
# There's a snippet of using ffmpeg to test a file (does this work w/MP3s?)
# https://unix.stackexchange.com/questions/654812/how-to-convert-ape-files-to-flac-in-linux
#
###############################################################################
# https://trac.ffmpeg.org/ticket/6602
# The "Encoded by" tag ...
#

HS1_CHARACTERS='‘’∕“”…■' ;
export G_DEBUG_check_format=0 ;

export MY_UNRAR='/usr/bin/unrar' ;
export ERROR_UNRAR_T=7 ;
# Who knew (not me)!  The 'UNZIP' enviornmental variable is “owned” by unzip.
export MY_UNZIP='/usr/bin/unzip' ;
export ERROR_ARCHIVE_TEST=7 ;
export FLAC='/usr/bin/flac' ;
export ERROR_FLAC_T=6 ;
export FFMPEG='/usr/bin/ffmpeg' ;
export FFMPEG_OPT='-y -nostdin -hide_banner' ;
export ERROR_FFMPEG_COVER=9 ;
export MAGICK='/usr/bin/gm' ;
export ERROR_IDENTIFY=11 ;
export EXIFTOOL='/usr/bin/exiftool' ;
export EGREP='/usr/bin/egrep' ;
export BANNER='/ant/banner' ;
export ERROR_GROUP_COUNT=15 ;
export ERROR_NOT_METADATA_TAG=17 ;
export ERROR_METADATA_TAG_ARG=18 ;
export ERROR_CHECK_FORMAT=14 ;
export ID3V2='/usr/bin/id3v2' ; # better than ffmpeg?

export ATTR_OFF="`tput sgr0`" ;
export ATTR_BOLD="`tput bold`" ;
export ATTR_UNDL="`tput smul`" ;
export ATTR_CLR_BOLD="${ATTR_OFF}${ATTR_BOLD}" ;
export ATTR_RED="${ATTR_OFF}`tput setaf 1`" ;
export ATTR_RED_BOLD="${ATTR_RED}${ATTR_BOLD}" ;
export ATTR_GREEN="${ATTR_OFF}`tput setaf 2;`" ;
export ATTR_GREEN_BOLD="${ATTR_GREEN}${ATTR_BOLD}" ;
export ATTR_YELLOW="${ATTR_OFF}`tput setaf 3`" ;
export ATTR_YELLOW_BOLD="${ATTR_YELLOW}${ATTR_BOLD}" ;
export ATTR_BLUE="${ATTR_OFF}`tput setaf 4`" ;
export ATTR_BLUE_BOLD="${ATTR_BLUE}${ATTR_BOLD}" ;
export ATTR_MAGENTA="${ATTR_OFF}`tput setaf 5`" ;
export ATTR_MAGENTA_BOLD="${ATTR_MAGENTA}${ATTR_BOLD}" ;
export ATTR_CYAN="${ATTR_OFF}`tput setaf 6`" ;
export ATTR_CYAN_BOLD="${ATTR_CYAN}${ATTR_BOLD}" ;
export ATTR_BROWN="${ATTR_OFF}`tput setaf 94`" ;
export ATTR_BROWN_BOLD="${ATTR_BROWN}${ATTR_BOLD}" ;
export OPEN_TIC='‘' ;
export ATTR_OPEN_TIC="${ATTR_CLR_BOLD}${OPEN_TIC}" ;
export CLOSE_TIC='’' ;
export ATTR_CLOSE_TIC="${ATTR_CLR_BOLD}${CLOSE_TIC}${ATTR_OFF}" ;

export ATTR_ERROR="${ATTR_RED_BOLD}ERROR -${ATTR_OFF}" ;
export ATTR_NOTE="${ATTR_OFF}`tput setaf 12`NOTE -${ATTR_OFF}";
export ATTR_TOOL="${ATTR_GREEN_BOLD}" ;

###############################################################################
#   #######
#   #       #    #  #    #   ####   #####   #    ####   #    #   ####
#   #       #    #  ##   #  #    #    #     #   #    #  ##   #  #
#   #####   #    #  # #  #  #         #     #   #    #  # #  #   ####
#   #       #    #  #  # #  #         #     #   #    #  #  # #       #
#   #       #    #  #   ##  #    #    #     #   #    #  #   ##  #    #
#   #        ####   #    #   ####     #     #    ####   #    #   ####
#
###############################################################################
#
my_mkdir() { # -quiet
  local MY_QUIET=0 ;
  if [ $# -eq 2 ] ; then
    MY_QUIET=1 ; shift ;
  fi
  local the_directory="$1" ; shift ;

  [ ${MY_QUIET} -eq 0 ] \
      && printf "${ATTR_BOLD}Checking '${ATTR_YELLOW_BOLD}%s${ATTR_CLR_BOLD}' ...\n" \
                "${the_directory}" ;
  if [ ! -d "${the_directory}" ] ; then # {
    printf "${ATTR_MAGENTA_BOLD}Building '${ATTR_YELLOW_BOLD}%s${ATTR_CLR_BOLD}' ...\n" \
                "${the_directory}" ;
    /bin/mkdir -p "${the_directory}" ;
  fi # }
  tput sgr0 ;
}


###############################################################################
#
my_chdir() {
  local the_directory="$1" ; shift ;

  RC=0 ;
  printf "${ATTR_GREEN_BOLD}Entering ${ATTR_CLR_BOLD}'${ATTR_CYAN_BOLD}%s${ATTR_CLR_BOLD}' ..."  \
         "${the_directory}" ;
  { pushd "${the_directory}" ; } >/dev/null 2>&1 ;
  printf "${ATTR_OFF}\n" ;

  [ -x 'Songs.sh' ] && . ./Songs.sh ; RC=$? ;

  { popd ; } >/dev/null 2>&1 ;

  return ${RC} ;
}


###############################################################################
# check_format()
#
check_format() { # regexp message variable expected_format
  my_regx="$1" ; shift ;
  my_msg="$1" ; shift ;
  my_var="$1" ; shift ;
  my_expect="$1" ; shift ;

  if [[ ! "${my_var}" =~ $my_regx ]] ; then # {
    printf "${ATTR_ERROR} ${ATTR_CYAN}%s timestamp ${ATTR_CLR_BOLD}'${ATTR_YELLOW}%s${ATTR_CLR_BOLD}'" \
           "${my_msg}" "${my_var}" ;
    printf " expecting format = '${ATTR_GREEN}%s${ATTR_CLR_BOLD}'.${ATTR_OFF}\n" "${my_expect}" ;
    if [ ${G_DEBUG_check_format} -eq 0 ] ; then
      exit ${ERROR_CHECK_FORMAT} ;
    fi # }
  fi # }
}


###############################################################################
# Lazy way to calculate the timestamps for FFMPEG from CUE sheet INDEX values.
#
# https://stackoverflow.com/questions/35494666/calculate-time-difference-in-format-of-hhmmss-ms
# https://en.wikipedia.org/wiki/Cue_sheet_(computing)
#
# The INDEX in a CUE sheet is specified as MM:SS:FF format, where FF is in the
# range of 00-74 (inclusive)  as there are 75 such frames per second of audio.
# The FFMPEG time format is HH:MM:SS.MILLISECONDS, so the frames would need
# to be converted to milliseconds.
# An INDEX 01 '04:04:25' would be '00:04:04.333' for FFMPEG.
#
G_TIME_RESULT='' ;
get_time_difference() { # 'cue | ms' "${END_TIME}" "${START_TIME}"

  local MY_TYPE="$1" ; shift ;
  local VARIABLE_1="$1" ; shift ;
  local VARIABLE_2='' ;

  #############################################################################
  # Add a "special" case hack for a CUE time with only a single ARG - we'll
  # treat it as a conversion request to a suitable FFMPEG time format string.
  #
  if [ $# -eq 1 ] ; then # {
    VARIABLE_2="$1" ; shift ;
  else # }{
    VARIABLE_2='00:00:00' ;
  fi # }

  if [ "${MY_TYPE}" = 'ms' ] ; then # {
    check_format '^[0-9][0-9]:[0-9][0-9]:[0-9][0-9][.][0-9][0-9][0-9]$' 'First' "${VARIABLE_1}" 'HH:MM:SS.MILLISECONDS' ;
    check_format '^[0-9][0-9]:[0-9][0-9]:[0-9][0-9][.][0-9][0-9][0-9]$' 'Second' "${VARIABLE_2}" 'HH:MM:SS.MILLISECONDS' ;
    VARIABLE_1_IN_MS=$( echo "${VARIABLE_1}" | awk -F'[:]|[.]' '{print $1 * 60 * 60 * 1000 + $2 * 60 * 1000 + $3 * 1000 + $4}' )
    VARIABLE_2_IN_MS=$( echo "${VARIABLE_2}" | awk -F'[:]|[.]' '{print $1 * 60 * 60 * 1000 + $2 * 60 * 1000 + $3 * 1000 + $4}' )
  else # }{
    check_format '^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$' 'First' "${VARIABLE_1}" 'HH:MM:FF' ;
    check_format '^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$' 'Second' "${VARIABLE_2}" 'HH:MM:FF' ;
    VARIABLE_1_IN_MS=$( echo "${VARIABLE_1}" | awk -F'[:]' '{print $1 * 60 * 1000 + $2 * 1000 + (($3 / 75) * 1000)}' )
    VARIABLE_2_IN_MS=$( echo "${VARIABLE_2}" | awk -F'[:]' '{print $1 * 60 * 1000 + $2 * 1000 + (($3 / 75) * 1000)}' )
  fi # }

  local DIFFERENCE_IN_MS=$(( VARIABLE_1_IN_MS - VARIABLE_2_IN_MS ))

  local RESIDUAL_DIFFERENCE_IN_MS=$DIFFERENCE_IN_MS

  #Calculate *hours* in difference
  local HOURS_IN_MS=$(( RESIDUAL_DIFFERENCE_IN_MS - RESIDUAL_DIFFERENCE_IN_MS % (60*60*1000) ))
  local HOURS=$(( HOURS_IN_MS / (60*60*1000) ))
  local RESIDUAL_DIFFERENCE_IN_MS=$(( RESIDUAL_DIFFERENCE_IN_MS - HOURS_IN_MS ))

  #Calculate *minutes* in difference
  local MINUTES_IN_MS=$(( RESIDUAL_DIFFERENCE_IN_MS - RESIDUAL_DIFFERENCE_IN_MS % (60*1000) ))
  local MINUTES=$(( MINUTES_IN_MS / (60*1000) ))
  local RESIDUAL_DIFFERENCE_IN_MS=$(( RESIDUAL_DIFFERENCE_IN_MS - MINUTES_IN_MS ))

  #Calculate *seconds* in difference
  local SECONDS_IN_MS=$(( RESIDUAL_DIFFERENCE_IN_MS - RESIDUAL_DIFFERENCE_IN_MS % (1000) ))
  local SECONDS=$(( SECONDS_IN_MS / 1000))
  local RESIDUAL_DIFFERENCE_IN_MS=$(( RESIDUAL_DIFFERENCE_IN_MS - SECONDS_IN_MS ))

  #Calculate *milliseconds* in difference
  local MILLISECONDS=$RESIDUAL_DIFFERENCE_IN_MS

  G_TIME_RESULT="$(printf "%.2d:%.2d:%.2d.%.3d" $HOURS $MINUTES $SECONDS $MILLISECONDS)" ;
}


###############################################################################
# Verify the specified audio file.
# There is no check (yet) for an MP3 audio file; still investigation options.
#
my_check_audio_file() { # "${TRACK}" ;
  local my_audio_file="$1" ; shift ;

  AUDIO_FILE_TYPE="${my_audio_file##*.}" ;
  if [ "${AUDIO_FILE_TYPE}" = 'flac' ] ; then # {
    printf "${ATTR_BOLD}Verifing '${ATTR_CLR_BOLD}$(tput setab 5)${my_audio_file}${ATTR_CLR_BOLD}' .${ATTR_OFF}" ;
    ${FLAC} --silent -t "${my_audio_file}" ; RC=$? ;
    if [ ${RC} -ne 0 ] ; then # {
      printf "${ATTR_BOLD}..${ATTR_RED_BOLD} FAILED!" ;
      printf "${ATTR_OFF}\n" ;
      exit ${ERROR_FLAC_T} ;
    else # }{
      printf "${ATTR_BOLD}..${ATTR_GREEN_BOLD} SUCCESS!" ;
      printf "${ATTR_OFF}\n" ;
    fi # }
  elif [ "${AUDIO_FILE_TYPE}" = 'mp3' ] ; then # }{
    printf "${ATTR_BOLD}Verifing '${ATTR_CLR_BOLD}$(tput setab 9)${my_audio_file}${ATTR_CLR_BOLD}' .${ATTR_OFF}" ;
    ${FFMPEG} ${FFMPEG_OPT} -v warning -i "${my_audio_file}" -f null - ; RC=$? ;
    if [ ${RC} -ne 0 ] ; then # {
      printf "${ATTR_BOLD}..${ATTR_RED_BOLD} FAILED!" ;
      printf "${ATTR_OFF}\n" ;
      exit ${ERROR_FLAC_T} ;
    else # }{
      printf "${ATTR_BOLD}..${ATTR_GREEN_BOLD} SUCCESS!" ;
      printf "${ATTR_OFF}\n" ;
    fi # }
  else # }{
    echo -en "${ATTR_RED_BOLD}" ; ${BANNER} 'Error!' ; echo -en "${ATTR_CLR_BOLD}" ;
    printf "Unhandled media type detected!${ATTR_OFF}" ;
    exit 3 ;
  fi # }
}


###############################################################################
# If there's a cover art image, that means the original encoder omitted adding
# the cover art to the music file(s) or we're changing it to a different image
# (this hase NOT been tested yet).
#
# NOTE, vlc maintains an album art cache in ~/.cache/vlc/art/artistalbum/.
# The problem with this strategy is that it is keyed from pair ARTIST / ALBUM.
# It really should include the ability to include the SONG_TITLE.
#
# The players 'mpv', 'smplayer', or 'ffplay' (appear to) always read/use the
# attachment in the audio file and show the correct album art for the track.
#
my_check_cover_art() { # "${COVER_ART}"
  local my_cover_art="$1" ; shift ;

  if [ "${my_cover_art}" != '' ] ; then # {
    printf "${ATTR_BOLD}Testing '${ATTR_YELLOW}" ;
    # I'm running 'identify' __twice__ so that I can capture the message and $?.
    ${MAGICK} identify +ping "${my_cover_art}" >/dev/null 2>&1 ; RC=$? ;
      MSG="$(${MAGICK} identify +ping "${my_cover_art}")" ;
    printf "%s" "${MSG}${ATTR_CLR_BOLD}' ..." ;
    if [ ${RC} -ne 0 ] ; then # {
      printf "${ATTR_BOLD}${ATTR_RED_BOLD} FAILED!" ;
      printf "${ATTR_OFF}\n" ;
      exit ${ERROR_IDENTIFY} ;
    else # }{
      printf "${ATTR_BOLD}${ATTR_GREEN_BOLD} SUCCESS!" ;
      printf "${ATTR_OFF}\n" ;
    fi # }
  else # }{
    printf "${ATTR_BOLD}  ==> ${ATTR_YELLOW_BOLD}NO COVER ARTWORK WAS PROVIDED ...${ATTR_OFF}\n" ;
  fi # }
}


###############################################################################
#
my_test_archive() { # "${MY_GOLD}"
  local my_gold="$1" ; shift ;

  local my_file_type="${my_gold##*.}" ;
  local RC=0 ;

  printf "${ATTR_BOLD}Testing '${ATTR_YELLOW}${my_gold}${ATTR_CLR_BOLD}' .${ATTR_OFF}" ;

  #############################################################################
  # These are the most common __archive__ types (maybe more later?) (APE and
  # FLAC are typically accompanied with a CUE sheet, making then "archives"):
  #
  if [ "${my_file_type}" = 'rar' ] ; then # {
    ${MY_UNRAR} t "${my_gold}" >/dev/null ; RC=$? ;
  elif [ "${my_file_type}" = 'zip' ] ; then # }{
    ${MY_UNZIP} -tqq "${my_gold}" ; RC=$? ;
  elif [ "${my_file_type}" = 'ape' ] ; then # }{
    ${FFMPEG} ${FFMPEG_OPT} -v warning -i "${my_gold}" -f null - ; RC=$? ;
  elif [ "${my_file_type}" = 'flac' ] ; then # }{
    ${FFMPEG} ${FFMPEG_OPT} -v warning -i "${my_gold}" -f null - ; RC=$? ;
  fi # }

  if [ ${RC} -ne 0 ] ; then # {
    printf "${ATTR_BOLD}..${ATTR_RED_BOLD} FAILED!" ;
    printf "${ATTR_OFF}\n" ;
    exit ${ERROR_UNRAR_T} ;
  else # }{
    printf "${ATTR_BOLD}..${ATTR_GREEN_BOLD} SUCCESS!" ;
    printf "${ATTR_OFF}\n" ;
  fi # }
}


###############################################################################
#
my_extract_archive() { # "${ARCHIVE}" "${LOCATION}" "${MUSIC_DIR}"
  local my_archive="$1" ; shift ;
  local location="$1" ; shift ;
  local music_dir="$1" ; shift ;

  local file_type="${my_archive##*.}" ;

  if [ "${music_dir}" != '' ] ; then # {
    { pushd "${location}" ; } >/dev/null 2>&1 ;
    if [ ! -d "${music_dir}" ] ; then # {
      printf "${ATTR_BOLD}Extracting '${ATTR_GREEN}${my_archive}${ATTR_CLR_BOLD}' ...${ATTR_OFF}" ;
      if [ "${file_type}" = 'rar' ] ; then # {
        ${MY_UNRAR} x "../${my_archive}" >/dev/null ; RC=$? ;
      elif [ "${file_type}" = 'zip' ] ; then # }{
        ${MY_UNZIP} -x "../${my_archive}" ; RC=$? ;
      fi # }

      if [ ${RC} -ne 0 ] ; then # {
        printf "${ATTR_BOLD}..${ATTR_RED_BOLD} FAILED!" ;
        printf "${ATTR_OFF}\n" ;
        exit ${ERROR_UNRAR_T} ;
      else # }{
        printf "${ATTR_BOLD}..${ATTR_GREEN_BOLD} SUCCESS!" ;
        printf "${ATTR_OFF}\n" ;
      fi # }
    fi # }
    { popd ; } >/dev/null 2>&1 ;
  fi # }
}


###############################################################################
# https://stackoverflow.com/questions/20193065/how-to-remove-id3-audio-tag-image-or-metadata-from-mp3-with-ffmpeg
# ffmpeg -i input.mp3 -map 0:a -c:a copy -map_metadata -1 output.mp3
#   -map 0:a Includes only audio (omits all images). See FFmpeg Wiki: Map for more details.
#   -c:a copy Enables stream copy mode so re-encoding is avoided.
#   -map_metadata -1 Omits all metadata.
#   -fflags +bitexact removes the ENCODER tag
#
# Some older encodings contain:
# - bad metadata (e.g., the Artist/Title tag is NOT the track's artist/title),
# - or metadata that is NOT UTF-8 encoding looks like garbage characters.
# The easiest solution is to discard all of the metadata in the input track,
# then add it back when we add in the album art and/or extra metadata.
#
my_encode_audio_track() { # discard_metadata "${MUSIC_TRACK}" "${TRACK}" "${EXTRA_METADATA}" "${TRACK_TITLE_SED}" "${SLICE_ARGS}" "${COVER_ART}"

  if [ $# -ne 7 ] ; then # {
    printf "${ATTR_RED_BOLD}" ; ${BANNER} 'Error' ; printf "${ATTR_CLR_BOLD}" ;
  fi # }
  local discard_all_metadata="$1" ; shift ; # FIXME - finish writing
  local audio_filename_in="$1" ; shift ;
  local audio_filename_out="$1" ; shift ;
  local my_extra_metadata="$1" ; shift ;
  local my_title_sed="$1" ; shift ;
  local ffmpeg_slice_args="$1" ; shift ;
  local cover_art="$1" ; shift ;

  local temp_out_filename='' ;

  if [ ${my_encode_audio_track_DEBUG} -eq 1 ] ; then # {
     set -x ;
  fi # }

  #############################################################################
  # The source has unusable metadata ...
  #
  if [ ${discard_all_metadata} -eq 1 ] ; then # {
    my_mkdir -quiet 'NO_RSYNC' ; # (We probably already did this; won't hurt.)
    if [ "${my_extra_metadata}" = '' ] ; then # {
        #######################################################################
        # This ISN'T an error per se, but we'll print a message about it ...
      printf 'NOTE :: stripping all metadata from output!!!\n' ; # FIXME better desc
    fi # }
    local output_file_type="${audio_filename_out##*.}" ;
    temp_out_filename="./NO_RSYNC/$(basename "${audio_filename_out}" ".${output_file_type}")-temp.${output_file_type}" ;

      #########################################################################
      # We do NOT handle the 'ffmpeg_slice_args' because I don't think there
      # are any audio files (with corrupt metadata) that also have a CUE sheet.
      #
    /bin/rm -f "${temp_out_filename}" ;
    ${FFMPEG} ${FFMPEG_OPT} \
              -i "${audio_filename_in}" \
              -map 0:a -c:a copy -map_metadata -1 -fflags +bitexact \
              "${temp_out_filename}" ;
    audio_filename_in="${temp_out_filename}" ;
  fi # }

  #############################################################################
  # Some of the (older) encoding may be missing the 'Title' metadata tag ...
  #
  # If the Title is missing, we'll apply a regex to the track's filename to
  # build its title then add it to the output via the FFMPEG command line.
  # Not perfect, but "good enough" ...
  #
  local audio_type="${audio_filename_out##*.}" ;
  local track_title="$(${EXIFTOOL} "${audio_filename_in}" | ${EGREP} '^Title  ')" ;

  if [ "${track_title}" = '' ] ; then # {
    track_title="$(basename "${audio_filename_out}" ".${audio_type}" \
                 | sed "${my_title_sed}")" ;
    ffmpeg_extra_metadata="${my_extra_metadata} -metadata 'title=${track_title}'" ;
  else # }{
    ffmpeg_extra_metadata="${my_extra_metadata}" ;
  fi # }

  echo -ne "    $(tput bold)--- '$(tput sgr0; tput setaf 5;)${audio_filename_out}$(tput sgr0; tput bold)' ---$(tput sgr0)" ;
  echo     "  ${ATTR_YELLOW_BOLD}<< Title='${ATTR_YELLOW}${track_title}${ATTR_YELLOW_BOLD}' >>${ATTR_OFF}" ;
 
  #############################################################################
  # Okay, if we have cover art, add it to the audio file.
  # Otherwise, build a hard link to the audio file.
  # Subtle - the placement of -ss and -t is important with artwork attachments.
  # https://superuser.com/questions/758338/keep-album-art-with-ffmpeg-while-cutting-a-mp3-file
  #
  local ffmpeg_codec='' ;
  local audio_filename_in_type="${audio_filename_in##*.}" ;
  local audio_filename_out_type="${audio_filename_out##*.}" ;
  if [ "${audio_filename_in_type}" = "${audio_filename_out_type}" ] ; then # {
    ffmpeg_codec='-codec copy' ;
  else # }{
      #########################################################################
      # If we're re-encoding (to FLAC) ensure the highest compression level.
    ffmpeg_codec='-compression_level 12' ;
  fi # }

  if [ "${cover_art}" != '' ] ; then # {
    eval set -- "${ffmpeg_extra_metadata}" ;
    ${FFMPEG} ${FFMPEG_OPT} \
              ${ffmpeg_slice_args} \
              -i "${audio_filename_in}" \
              -i "${cover_art}" \
              -map 0:a -map 1 \
              ${ffmpeg_codec} \
              -metadata:s:v title="Album cover" \
              -metadata:s:v comment="Cover (front)" \
              "$@" -disposition:v attached_pic \
          "${audio_filename_out}" ; RC=$? ;

  #############################################################################
  # This is UNTESTED if artwork already exists with 'ffmpeg_slice_args' non-EMPTY.
  elif [ "${ffmpeg_extra_metadata}" != '' ] ; then # }{
    eval set -- "${ffmpeg_extra_metadata}" ;
    ${FFMPEG} ${FFMPEG_OPT} \
              ${ffmpeg_slice_args} \
              -i "${audio_filename_in}" \
              -map 0:a \
              ${ffmpeg_codec} \
              "$@" \
          "${audio_filename_out}" ; RC=$? ;

  else # }{
    /bin/ln "${audio_filename_in}" "${audio_filename_out}" ; RC=$? ;

  fi # }

  [ "${temp_out_filename}" != '' ] && /bin/rm -f "${temp_out_filename}" ;

  { set +x ; } >/dev/null 2>&1 ;
  return ${RC} ;
}


###############################################################################
#                                   ##    ##
#    #    #    ##     #   #    #   #        #
#    ##  ##   #  #    #   ##   #  #          #
#    # ## #  #    #   #   # #  #  #          #
#    #    #  ######   #   #  # #  #          #
#    #    #  #    #   #   #   ##   #        #
#    #    #  #    #   #   #    #    ##    ##
#
###############################################################################
#

if [ $# -eq 1 ] ; then # {
  DIRECTORY="$1" ; shift ;
  if [ -x "${DIRECTORY}/Songs.sh" ] ; then # {
    my_chdir "${DIRECTORY}" ; RC=$? ;
  fi # }
else # }{
  find . -maxdepth 1 -type d ! -name '.git' | while read DIRECTORY ; do # {
    [ "${DIRECTORY}" = '.' ] && continue ;

    if [ -x "${DIRECTORY}/Songs.sh" ] ; then # {
      my_chdir "${DIRECTORY}" ; RC=$? ;
    fi # }
  done # }
fi # }

exit 0;


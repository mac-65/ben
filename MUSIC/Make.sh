#! /bin/bash
#
###############################################################################
# This is the "top level" music build file.  My expectations are that each
# song has a different “gold” source copy (there might also be duplicates)
# and probably a different way of extracting the particular track from the
# source.  E.g., some may be RAR archives, ZIP or straight FLAC sources.
#
###############################################################################
# Required tools (many of these are probably installed by default):
# - ffmpeg
# - sed + pcre2 (the library)
# - coreutils   - basename, cut, head, sort, tail, tee, et. al.
# - util-linux  - getopt (not bash's getopts())
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
# https://stackoverflow.com/questions/20193065/how-to-remove-id3-audio-tag-image-or-metadata-from-mp3-with-ffmpeg
# ffmpeg -i input.mp3 -map 0:a -c:a copy -map_metadata -1 output.mp3
#   -map 0:a Includes only audio (omits all images). See FFmpeg Wiki: Map for more details.
#   -c:a copy Enables stream copy mode so re-encoding is avoided.
#   -map_metadata -1 Omits all metadata.
#   -fflags +bitexact removes the ENCODER tag
#
# https://stackoverflow.com/questions/965053/extract-filename-and-extension-in-bash
#   AUDIO_FILE_TYPE="${TRACK##*.}" ;
#
###############################################################################
# https://stackoverflow.com/questions/76515791/eyed3-fails-to-run-on-rhel-8-8
# eyeD3 fails to run on RHEL 8.8
#
# Matches __exactly__ what I see ...  This is why I dislike script-kiddies ...
# - https://bugzilla.redhat.com/show_bug.cgi?id=1933591
#   https://bugzilla.redhat.com/attachment.cgi?id=1759946&action=diff
#
# According to the "bug report," it fails to run.  I receive the same-ish error
# message that is in the question, but it will still attach album artwork just
# fine (which is my use case).  Also, I can't find the cause of the error (I'm
# not big on python programming).  On what I think is an identical Fedora 37
# installation (I mean matching _every_ RPM/version) on VirtualBox, I do NOT
# receive the error message at eyeD3's startup.  The only difference between
# the two Fedora installations that should NOT matter is that the VirtualBox
# installation was updated all at once, while my desktop was incrementally
# updated over the past 6-7 months.  My theory is that there was a poison
# update along the way that was not properly cleaned up in its subsequent
# update(s).
# (Stands on soap box) Programming is _easy_ -- writing test cases that
# anticipate real-world use cases and catching regressions with the addition
# of new features is a paradigm shift few developers can successfully execute.
#
###############################################################################
# https://jmesb.com/how_to/create_id3_tags_using_ffmpeg :: IMPORTANT?
#
# ffmpeg32 -i in.mp3 -i metadata.txt -map_metadata 1 -c:a copy -id3v2_version 3 -write_id3v1 1 out.mp3
#                                                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# ...
# Remember the Version
#
# If you are planning on using the media files with metadata on Windows,
# DO NOT forget to use these options in your command line:
#
#   -id3v2_version 3
#   -write_id3v1 1
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
HS1_CHARACTERS='‘’∕“”…■ Height: 5′ 3″' ;
export G_DEBUG_check_format=0 ;

export MY_UNRAR='/usr/bin/unrar' ;
export ERROR_UNRAR_T=7 ;
# Who knew (not me)!  The 'UNZIP' enviornmental variable is “owned” by unzip.
export MY_UNZIP='/usr/bin/unzip' ;
export ERROR_ARCHIVE_TEST=7 ;
export FLAC='/usr/bin/flac' ;
export ERROR_FLAC_T=6 ;
export FFMPEG_OPT='-y -nostdin -hide_banner' ;
export FFMPEG_ID3='-id3v2_version 3 -write_id3v1 1' ;
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
#   ######                                #####
#   #     #  #####    ##    #####        #     #   ####   #####   #####
#   #     #  #       #  #   #    #       #        #    #  #    #  #
#   #     #  ####   #    #  #    #       #        #    #  #    #  ####
#   #     #  #      ######  #    #       #        #    #  #    #  #
#   #     #  #      #    #  #    #       #     #  #    #  #    #  #
#   ######   #####  #    #  #####         #####    ####   #####   #####
#
  if false ; then # {                   ## DBG
    eval set -- "${MUSIC_TRACKs}" ;      # DBG
    echo "$# = $@" ;                     # DBG
    IDX=1;                               # DBG
    while [ $# -ne 0 ] ; do # {          # DBG
      printf "%d = '%s'\n" ${IDX} "$1"   # DBG
      (( IDX++ )) ; shift ;              # DBG
    done # }                             # DBG
  fi # }                                ## DBG


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
###############################################################################
# Ctl-C, signals and exit handler stuff ...
# > To avoid the ‘stty: 'standard input': Inappropriate ioctl for device’
#   message, we need to "protect" the ‘stty -echoctl’ command.
#
if [[ -t 0 ]] ; then
  stty -echoctl ;       # hide '^C' on the terminal output
fi
export MY_MAKE_PID=$$ ; # I did NOT know about this one trick to exit :) ...

abort() {
   { set +x ; } >/dev/null 2>&1 ;

   my_func="$1" ; shift ;
   my_lineno="$1" ; shift ;

   tput sgr0 ;
   printf >&2 "${ATTR_ERROR} in '`tput setaf 3`%s`tput sgr0`()', line #%s\n" "${my_func}" "${my_lineno}" ;

   kill -s SIGTERM $MY_MAKE_PID ;
   exit 1 ; # I missed this the first time ...
}


###############################################################################
# cleanup()
#
cleanup() {

  echo 'CLEANUP -- not yet written' ;
}


###############################################################################
# check_binary( verbose, cli_option, executable )
#
# DOES NOT return if there was an error.
#
check_binary() {
  local my_verbose="$1" ; shift ; # display a SUCCESS message (TODO)
  local my_option="$1" ; shift ;  # the 'getopt' option of caller
  local my_binary="$1" ; shift ;  # search for this binary using 'which'

  while : ; do  # {
    if [ "${my_binary}" = '' ] ; then  # Pedantic, I know ...
      echo "${ATTR_ERROR} ‘${my_option}’ requires a valid executable name." >&2 ;
      break ;
    fi

      #########################################################################
      # Use 'which' to get a complete pathname of the ffmpeg executable, and
      # it also ensures that the file __is__ executable.
      #
      which "${my_binary}" >/dev/null 2>&1 ; RC=$? ;
      (( RC )) && { \
         printf >&2 "${ATTR_ERROR} ${ATTR_CLR_BOLD}The ‘${ATTR_CYAN_BOLD}%s${ATTR_CLR_BOLD}’\n" \
                    "${my_binary}" ;
         printf >&2 "        executable was not found by ‘which’.\n"
         break ; }

      local which_ffmpeg="$(which "${my_binary}")" ;

      #########################################################################
      # SUCCESS :: return directory's name as required.
      #
    printf '%s' "${which_ffmpeg}" ;
    return 0;
  done ;  # }

    ###########################################################################
    # FAILURE :: exit; we've already printed an appropriate error message above
    #
  abort ${FUNCNAME[0]} ${LINENO};
}


###############################################################################
#
init_global_options() {

  export G_OUTPUT_DIR='./' ;

  export G_FFMPEG_BIN="$(check_binary true '' 'ffmpeg')" ;
}


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
    ${G_FFMPEG_BIN} ${FFMPEG_OPT} -v warning -i "${my_audio_file}" -f null - ; RC=$? ;
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
    ${G_FFMPEG_BIN} ${FFMPEG_OPT} -v warning -i "${my_gold}" -f null - ; RC=$? ;
  elif [ "${my_file_type}" = 'flac' ] ; then # }{
    ${G_FFMPEG_BIN} ${FFMPEG_OPT} -v warning -i "${my_gold}" -f null - ; RC=$? ;
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
# my_copy_archive( gold_copy_on_system, archive_top_level_directory )
#
# Copy an archive file from its "home" location to the current directory.
#
# 'gold_copy_on_system' points to the source "gold" copy of the music archive,
#     e.g. “${HOME}/album_artist.zip” will be copied to “./album_artist.zip”.
#     Usually, this is the file that is added to GIT.
# 'archive_top_level_directory' is retrieved by listing the archive and
#     noting the top level __directory__ of the archive.  The existence of
#     this directory determines if the archive needs to be extracted.
#
my_copy_archive() { # "${GOLD_SOURCE}" "${DIRECTORY}"

  local gold_source="$1" ; shift ;

  if [ "${gold_source}" != '' ] ; then # {

    local gold_local="$(basename "${gold_source}")" ;
    local music_dir="$1" ; shift ;

    if [ ! -s "${gold_local}" ] ; then # {
      printf "${ATTR_BOLD}Copying '${ATTR_YELLOW}${gold_source}${ATTR_CLR_BOLD}'\n" ;
      printf "    --> '${ATTR_YELLOW}./${gold_local}${ATTR_CLR_BOLD}'${ATTR_OFF}\n" ;
      set +x ;
      /bin/rm -f "./${gold_local}" ;
      /bin/cp -p "${gold_source}" "./${gold_local}" ;
      { set +x ; } >/dev/null 2>&1 ;
    fi # }

      # We'll __always__ verify the GOLD standard ...
    my_test_archive "${gold_local}" ;

    my_mkdir -quiet './NO_RSYNC' ;
    my_extract_archive "${gold_local}" './NO_RSYNC' "${music_dir}" ;
  fi # }
}


###############################################################################
# Some older encodings contain:
# - bad metadata (e.g., the Artist/Title tag is NOT the track's artist/title),
# - or metadata that is NOT UTF-8 encoding looks like garbage characters.
#
# The easiest solution is to discard all of the metadata in the input track,
# then add it back when we add in the album art and/or extra metadata.
#
my_encode_audio_track() { # discard_metadata "${MUSIC_TRACK}" "${TRACK}" "${EXTRA_METADATA}" "${TRACK_TITLE_SED}" "${SLICE_ARGS}" "${COVER_ART}"

  if [ ${my_encode_audio_track_DEBUG} -eq 1 ] ; then # {
     set -x ;
  fi # }

  if [ $# -ne 7 ] ; then # {
    printf "${ATTR_RED_BOLD}" ; ${BANNER} 'Error' ; printf "${ATTR_CLR_BOLD}" ;
    exit 2 ;
  fi # }
  local discard_all_metadata="$1" ; shift ;
  local audio_filename_in="$1" ; shift ;
  local audio_filename_out="$1" ; shift ;
  local my_extra_metadata="$1" ; shift ;
  local my_title_sed="$1" ; shift ;
  local ffmpeg_slice_args="$1" ; shift ;
  local cover_art="$1" ; shift ;

  local temp_out_filename='' ;

    ###########################################################################
    # The source has unusable metadata ...
  if [ ${discard_all_metadata} = 'true' ] ; then # {
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
    /bin/rm -f "${temp_out_filename}" ;
    ${G_FFMPEG_BIN} ${FFMPEG_OPT} \
              -i "${audio_filename_in}" \
              -map 0:a -c:a copy -map_metadata -1 -fflags +bitexact \
              "${temp_out_filename}" ;
    audio_filename_in="${temp_out_filename}" ;
  fi # }

    ###########################################################################
    # Some of the (older) encoding may be missing the 'Title' metadata tag ...
    #
    # If the Title is missing, we'll apply a regex to the track's filename to
    # build its title then add it to the output via the FFMPEG command line.
    # Not perfect, but "good enough" ...
  local audio_type="${audio_filename_out##*.}" ;
  local track_title="$(${EXIFTOOL} "${audio_filename_in}" | ${EGREP} '^Title  ')" ;

  if [ "${track_title}" = '' ] ; then # {
    ## TODO FIXME :: SKIP this if the metadata already contains a 'title=' tag!
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
    ${G_FFMPEG_BIN} ${FFMPEG_OPT} \
              ${ffmpeg_slice_args} \
              -i "${audio_filename_in}" \
              -i "${cover_art}" \
              -map 0:a -map 1 \
              ${ffmpeg_codec} \
              -metadata:s:v title="Album cover" \
              -metadata:s:v comment="Cover (front)" \
              "$@" -disposition:v attached_pic \
              ${FFMPEG_ID3} \
          "${audio_filename_out}" ; RC=$? ;

    ###########################################################################
    # This is UNTESTED if the artwork already exists in the audio track and
    # 'ffmpeg_slice_args' is non-EMPTY.
  elif [ "${ffmpeg_extra_metadata}" != '' ] ; then # }{
    eval set -- "${ffmpeg_extra_metadata}" ;
    ${G_FFMPEG_BIN} ${FFMPEG_OPT} \
              ${ffmpeg_slice_args} \
              -i "${audio_filename_in}" \
              -map 0:a \
              ${ffmpeg_codec} \
              "$@" \
              ${FFMPEG_ID3} \
          "${audio_filename_out}" ; RC=$? ;

  else # }{
      #########################################################################
      #
    /bin/ln "${audio_filename_in}" "${audio_filename_out}" ; RC=$? ;

  fi # }

  [ "${temp_out_filename}" != '' ] && /bin/rm -f "${temp_out_filename}" ;

  { set +x ; } >/dev/null 2>&1 ;
  return ${RC} ;
}


###############################################################################
# APE files are lossless, but very primitive otherwise (no metadata, I think).
# https://myanimelist.net/anime/2164/Dennou_Coil
#
# Usually a CD encode as an APE file is a single APE file for the whole CD,
# so we'll have to extract each interesting title individuality.
#
# process_tracks "${TYPE_EXT_IN}" "${MUSIC_TRACKs}" "${EXTRA_METADATA}"
#
process_tracks() {
  local music_track_groups=8 ; # Some basic integrity checking ...

  local type_ext_in="$1" ; shift ;
  local music_tracks="$1" ; shift ;
  local extra_metadata="$1" ; shift ;

  local my_extraction_dir='./NO_RSYNC' ; # Woops, forgot to re-add this in!

  my_mkdir "${my_extraction_dir}" ;

if [ "${type_ext_in}" = 'ape' -o "${type_ext_in}" = 'mp3' ] ; then # {

  my_gold_source_checked='' ; # We have NOT tested any source ...

  eval set -- "${music_tracks}" ;
  while [ $# -ne 0 ] ; do # { ...for each audio track we're interested in.

      #########################################################################
      # Not too robust error checking and little better than no error checkng.
    if [ $# -lt ${music_track_groups} ] ; then # {
      printf "${ATTR_ERROR} ${ATTR_CLR_BOLD}Not enough items (%d) for this track in this group!${ATTR_OFF}" $# ;
      exit ${ERROR_GROUP_COUNT} ;
    fi # }

    local track_extra_metadata="${EXTRA_METADATA}" ;

    local my_discard_metadata="$1" ; shift ;
    local my_gold_source="$1" ; shift ;
    local audio_filename_out="$1" ; shift ;
    local audio_filename_out_fix="$1" ; shift ; # TODO finish this ...
    local track_title_sed="$1" ; shift ;
    local cover_art_filename="$1" ; shift ;
    local slice_args="$1" ; shift ;

    local must_have_tag=1 ; # We __must__ have at least 1 tag (even if it's EMPTY).
    while [ $# -gt 0 ] ; do # {
      ffmpeg_metadata="$1" ;
      if [ "${ffmpeg_metadata}" = '' ] ; then # {
        shift ; break ;
      elif [ "${ffmpeg_metadata}" != '-metadata' ] ; then # }{
        if [ ${must_have_tag} -eq 0 ] ; then # {
          break ;
        fi # }
        printf "${ATTR_ERROR} ${ATTR_CLR_BOLD}Found '%s' instead of '-metadata' tag.${ATTR_OFF}" "${ffmpeg_metadata}" ;
        exit ${ERROR_NOT_METADATA_TAG} ;
      elif [ $# -lt 1 ] ; then # }{
        printf "${ATTR_ERROR} ${ATTR_CLR_BOLD}'-metadata' tag has no argument.${ATTR_OFF}" "${ffmpeg_metadata}" ;
        exit ${ERROR_METADATA_TAG_ARG} ;
      fi # }
      shift ;
      ffmpeg_metadata_arg="$1" ; shift ;
      track_extra_metadata="${track_extra_metadata} -metadata '${ffmpeg_metadata_arg}'" ;
      must_have_tag=0 ;
    done # }

    ###########################################################################
    # Okay.  We've walked through a single track in the 'MUSIC_TRACKs' array.
    #
    # If 'my_gold_source' is a directory, then 'audio_filename_out' is the
    # track we want in __that__ directory -- that track will be copied to
    # 'my_extraction_dir'.  We'll reset 'my_gold_source' to point to the
    # copied track in 'my_extraction_dir' so that we can perform any encoding.
    # BUG :: We nee to "fix" the 'audio_filename_out' to conform to the
    #        "XX title.mp3" filename convention.
    # BUG :: Also, 08 produces a playable file with the artwork, but exiftool
    #        does not dump it correctly.  Is this because of the original file?
    #
    if [ -d "${my_gold_source}" ] ; then # {
      if [ "${audio_filename_out_fix}" != '' ] ; then # {
         copy_to_filename="${audio_filename_out_fix}" ;
      else # }{
         copy_to_filename="${audio_filename_out}" ;
      fi # }
      if [ ! -s "${my_extraction_dir}/${copy_to_filename}" ] ; then # {
        /bin/cp -p "${my_gold_source}/${audio_filename_out}" "${my_extraction_dir}/${copy_to_filename}" ;
      fi # }
      my_check_audio_file "${my_extraction_dir}/${copy_to_filename}" ;
      if [ "${audio_filename_out_fix}" != '' ] ; then # {
        audio_filename_out="${audio_filename_out_fix}" ;
      fi # }
      my_gold_source="${my_extraction_dir}/${copy_to_filename}" ; # HACK!
    elif [ "${my_gold_source_checked}" != "${my_gold_source}" ] ; then # }{
      my_gold_source_checked="${my_gold_source}" ;

      # We'll __always__ verify the GOLD standard ...
      my_test_archive "${my_gold_source}" ;
    fi # }

    if [ ! -s "${audio_filename_out}" ] ; then # {
      my_check_cover_art "${cover_art_filename}" ;

        #######################################################################
        # Set to '1' to enable 'set -x' in “my_encode_audio_track()” ...
      my_encode_audio_track_DEBUG=0 ; # Probably should make an argument of ().
      my_encode_audio_track "${my_discard_metadata}" \
                            "${my_gold_source}" \
                            "${audio_filename_out}" \
                            "${track_extra_metadata}" \
                            "${track_title_sed}" \
                            "${slice_args}" \
                            "${cover_art_filename}" ;
    fi # }

    my_check_audio_file "${audio_filename_out}" ;

  done # } ...for each audio track

fi # } "${TYPE_EXT_IN}" = 'ape'
}


###############################################################################
#
my_usage() {
  echo 'TODO :: WRITE USAGE!' ;
}


###############################################################################
#
# All command line options are __global__ with respect to any song directories.
#
# As a stylistic choice, I want to enforce *long options* which require an
# argument to use the '--option=argument' syntax.  To do this, I set those
# option's arguments as __optional__.  This causes 'getopt' to only consider
# an option as having an argument when it is preceded by the '=' character.
# That is, it always returns an argument for the option and if the argument
# is an EMPTY string (''), then an "optional" argument was NOT provided.
# I think this makes the command line easier to read and less error prone.
#
process_cmdline_args() {

  local my_flag="$1" ; shift ; # UNUSED right now ...

  # For some reason, making this 'local' does NOT set $? for ‘getopt’. {
  HS_OPTIONS=`getopt -o h:: \
      --long help::,\
ffmpeg::,\
output_dir:: \
    -n "${ATTR_ERROR} ${ATTR_BLUE_BOLD}${C_SCRIPT_NAME}${ATTR_YELLOW}" -- "$@"` ; # }

  if [ $? != 0 ] ; then # {
     my_usage 1 ;
  fi # }

  eval set -- "${HS_OPTIONS}" ;
  while true ; do  # {
    case "$1" in  # {
    --ffmpeg)
        G_FFMPEG_BIN="$(check_binary false "$1" "$2")" ;
        G_OPTION_GLOBAL_MESSAGES="${G_OPTION_GLOBAL_MESSAGES}$(\
          printf "  ${ATTR_FFMPEG}${ATTR_CLR_BOLD} ‘%s’.\\\n"  \
                 "${G_FFMPEG_BIN}")" ;
      shift 2 ;
      ;;
    --)
      shift ;
      break ;
      ;;
    *)
      echo -n "${ATTR_ERROR} fatal script error - option handler for " ;
      echo    "'${ATTR_YELLOW_BOLD}$1${ATTR_OFF}' not written!!!" ;
      echo    "${ATTR_YELLOW_BOLD}Terminating...${ATTR_OFF}" >&2 ; exit 5 ;
      ;;
    esac  # }
  done ;  # }

}

###############################################################################
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

init_global_options ;
process_cmdline_args 0 "$@" ;


if [ $# -ne 0 ] ; then # {
  while [ $# -ne 0 ] ; do # {
    DIRECTORY="$1" ; shift ;
    if [ -x "${DIRECTORY}/Songs.sh" ] ; then # {
      my_chdir "${DIRECTORY}" ; RC=$? ;
    fi # }
  done # }
else # }{
  find . -maxdepth 1 -type d ! -name '.git' ! -name '*IGNORE' | while read DIRECTORY ; do # {
    [ "${DIRECTORY}" = '.' ] && continue ;

    if [ -x "${DIRECTORY}/Songs.sh" ] ; then # {
      my_chdir "${DIRECTORY}" ; RC=$? ;
    fi # }
  done # }
fi # }

exit 0;


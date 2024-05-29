#! /bin/bash
#
#W '/home/sdl/Girls’ Last Tour OST' ;
#

###############################################################################
#
MY_CP='/bin/cp -ip' ;
MY_LN='/bin/ln -is' ;
MY_FFMPEG='/usr/bin/ffmpeg -y -nostdin -hide_banner' ;
MY_FFMPEG_MP3_OPTIONS='-c:a libmp3lame -ab 320K' ;
MY_FFMPEG_MAP_OPTIONS='-map_metadata 0 -id3v2_version 3' ;
MY_SEPARATOR='∕' ;
DGB='echo' ;
DBG='' ;


###############################################################################
#
usage() {
  [ $# -eq 1 ] && \
    printf "$(tput setaf 1; tput bold)Error -$(tput sgr0) %s.\n" "$1" ;
  printf 'Usage -\n  %s%s%s [-p description] [#] source_pathnames%s\n' \
         "$(tput bold)" "$(basename "$0")" "$(tput sgr0; tput setaf 3)" "$(tput sgr0)" ;
  printf '   -p - prefix the destination filename with this description.\n' ;
  printf '   #  - number of components of source pathname to use\n%s\n' \
         '        (default is 1, which is __simply__ the basename).' ;
  printf '      - NOTE, the CLI options are checked in the order listed.\n' ;
}

if [ $# -eq 0 ] || [ $# -eq 1 -a "$1" = '-h' ] ; then
  usage ;
  exit 0;
fi ;


###############################################################################
# Attach a commom prefix description to the destination filename.
#
MY_PREFIX_DESC='' ;
if [ $# -gt 1 -a "$1" = '-p' ] ; then # {
   shift ;
   MY_PREFIX_DESC="$1" ; shift ;
fi # }


###############################################################################
# We'll allow:
# - MY_COMPONENTs can be set in the environment;
# - a default value of 1; or
# - explicitly overridden on the command line.
#
[ -z "${MY_COMPONENTs}" ] \
    && MY_COMPONENTs=1 ; # We'll default to keep __just__ the filename ...

MY_REGX='^[0-9]+$' ;
if [[ $# -gt 0 && "$1" =~ ${MY_REGX} ]] ; then # {
   MY_COMPONENTs="$1" ; shift ;
fi ; # }


###############################################################################
#
if [ $# -eq 0 ] ; then # {
  usage 'No pathname(s) were provided' ;
  exit 2 ;
fi ; # }


###############################################################################
#
tput sgr0;
while [ $# -gt 0 ] ; do # {

  #############################################################################
  # ALERT❗❗❗  ＤＯ ＮＯＴ attempt this code on a Windoz or iOS platform!
  #
  SRC_PATHNAME="$1" ; shift ;
  DST_NAME="${MY_PREFIX_DESC}$(echo "${SRC_PATHNAME}" | rev | cut -d'/' -f1-${MY_COMPONENTs} | rev | sed -e 's#/#∕#g')" ;
  DST_NAME="${DST_NAME%.*}.mp3" ;

  ## printf '"%s" ===>> "%s"\n' "${SRC_PATHNAME}" "${DST_NAME}" ;
  # TODO :: See if DST_NAME already exists ...
  ${MY_FFMPEG} -i "${SRC_PATHNAME}" \
                  ${MY_FFMPEG_MP3_OPTIONS} \
                  ${MY_FFMPEG_MAP_OPTIONS} \
                  "${DST_NAME}" ;

done ; # }

exit 0 ;


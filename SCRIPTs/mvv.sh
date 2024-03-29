#! /bin/bash
#

HS1_CHARACTERS='‘’∕“”…' ;
###############################################################################
# Copy a file to the current directory keeping the last X component(s) in the
# destination filename.
#
usage() {
  printf "$(tput setaf 1; tput bold)Error -$(tput sgr0) %s.\n" "$1" ;
  printf 'Usage -\n  %s [-p description] [#] source_pathnames\n' "$(basename "$0")" ;
  printf '   -p - prefix the destination filename with this description.\n' ;
  printf '   #  - number of components of source pathname to use\n%s\n' \
         '        (default is 1, which is the basename).' ;
  printf '      - Note, option are checked in the order listed.\n' ;
}

###############################################################################
# We'll allow:
# - MY_COMPONENTs can be set in the environment;
# - a default value of 1; or
# - explicitly overridden on the command line.
#
MY_CP='/bin/cp -ip' ;
MY_LN='/bin/ln -is' ;
[ -z "${MY_COMPONENTs}" ] \
  && MY_COMPONENTs=1 ; # We'll default to keep __just__ the filename (basically
                       # equivalent to a “/bin/mv ./dir/file.png .” command).

MY_REGX='^[0-9]+$' ;
if [[ $# -gt 0 && "$1" =~ ${MY_REGX} ]] ; then # {
   MY_COMPONENTs="$1" ; shift ;
fi ; # }

###############################################################################
# Attach a commom prefix description to the destination filename.
#
MY_PREFIX_DESC='' ;
if [ $# -gt 0 -a "$1" = '-p' ] ; then # {
   shift ;
   MY_PREFIX_DESC="$1" ; shift ;
fi # }

if [ $# -eq 0 ] ; then # {
  usage 'No pathname(s) were provided' ;
  exit 2 ;
fi ; # }

###############################################################################
# Because of the way we're parsing the pathname string, a limit check on the
# maximum value of the MY_COMPONENTs argument won't affect anything ...
#
# echo 'TEMP/folder_path_1/folder_path_2/pic-0001.jpg' | rev | cut -d'/' -f1-3 | rev
#   folder_path_1/folder_path_2/pic-0001.jpg
#
tput sgr0;
while [ $# -gt 0 ] ; do # {
  SRC_PATHNAME="$1" ; shift ;
  DST_NAME="${MY_PREFIX_DESC}$(echo "${SRC_PATHNAME}" | rev | cut -d'/' -f1-${MY_COMPONENTs} | rev | sed -e 's#/#∕#g')" ;

  #############################################################################
  # HACK :: If we find the string 'NO_RSYNC/' in the source pathname,
  #         then we'll copy the file instead of linking to it because it was
  #         extracted from an archive file (rar or zip).
  #
  echo "${SRC_PATHNAME}" | /bin/grep -q 'NO_RSYNC/' ; RC=$? ;
  if [ ${RC} -eq 0 ] ; then MY_OP="${MY_CP}" ; else MY_OP="${MY_LN}" ; fi ;

  if [ -s "${SRC_PATHNAME}" ] ; then # {{

    printf "$(tput bold)%s$(tput sgr0) '$(tput setaf 3)%s$(tput sgr0)' " \
           "${MY_OP}" "${SRC_PATHNAME}" ;
    printf "'$(tput setaf 4;tput bold)%s$(tput sgr0)'\n" \
           "${DST_NAME}" ;
    ${MY_OP} "${SRC_PATHNAME}" "${DST_NAME}" ;
  else # }{
    printf "$(tput setaf 1; tput bold)ERROR -$(tput sgr0) "
    printf "Can’t stat $(tput bold)‘$(tput sgr0; tput setaf 6)%s$(tput sgr0; tput bold)’$(tput sgr0).\n" \
           "${SRC_PATHNAME}" ;
  fi # }}
done # }

exit 0;


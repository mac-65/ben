#! /bin/bash
#

SEARCH_RESULT_DIR='./SEARCH_RESULTs' ;
ARG_COUNT=$# ;

###############################################################################
# A quick and dirty hack to limit the number of results we parse ...
# The maximum amount on the search results page are 75 records.
#
MY_REGX='^[0-9]+$' ;
PARSE_COUNT_LIMIT=99 ;
if [[ ${ARG_COUNT} -gt 0 && "$1" =~ ${MY_REGX} ]] ; then # {
   PARSE_COUNT_LIMIT="$1" ; shift ;
fi ; # }

###############################################################################
# Perform some simple validation ...
#
ARG_COUNT=$# ;
if [[ ${ARG_COUNT} -eq 0 || ( ${ARG_COUNT} -eq 1 && "$1" = '-h' ) ]] ; then # {
   printf "Usage:\n  %s  $(tput setaf 3)%s$(tput sgr0)\n" \
          "$(basename $0)" \
          'results.html' ;
   printf "Where $(tput setaf 3)%s$(tput sgr0) are the search results from $(tput bold)Firefox’s $(tput setaf 5)%s$(tput sgr0)\n" \
          'results.html' \
          'Save Page As…' ;
   printf "Also, the directory '$(tput setaf 6)%s$(tput sgr0)' is made if it does not exist\n (for saving the search result’s file)." \
          "${SEARCH_RESULT_DIR}" ;
   echo ; echo ;
   exit 1;
elif [ "${MY_PARSE_HTML}" = '' ] ; then # }{
   printf "$(tput setaf 1; tput bold)ERROR$(tput sgr0) -- " ; \
   printf "$(tput bold)'$(tput setab 4)MY_PARSE_HTML$(tput sgr0; tput bold)' " ; \
   printf "is NOT set in the enviornment,$(tput sgr0) EXITING.\n" ;
   exit 4;
fi # }

###############################################################################
RESULT_FILE="$1" ; shift ; # This is the {Firefox} saved search results page.
DRY_RUN=0 ; # TODO :: set from CLI

if [ ! -d "${SEARCH_RESULT_DIR}" ] ; then # {
  printf "$(tput bold)MAKING '$(tput setaf 3)${SEARCH_RESULT_DIR}$(tput sgr0; tput bold)' .."
  MSG="$(/bin/mkdir "${SEARCH_RESULT_DIR}" 2>&1)" \
     || { printf ".\n$(tput setaf 1; tput bold)  ERROR$(tput sgr0; tput bold) - ${MSG}$(tput sgr0)\n" ; exit 2 ; }
  printf ". $(tput setaf 2)COMPLETE!\n" ;
fi # }

###############################################################################
# This is a hack that allows this script to figure out the target directory.
#
HAVE_FILES=1 ;
if [ ! -d ./files ] ; then # {
  HAVE_FILES=0 ;
fi # }


CLEANUP_DIR="$(basename "${RESULT_FILE}" '.html')_files" ;
if [ -d "${CLEANUP_DIR}" ] ; then
  /bin/rm -rf "./${CLEANUP_DIR}" ;
else
  printf "$(tput setaf 1; tput bold)NOTICE!$(tput sgr0; tput bold)%s '$(tput setaf 3)%s$(tput sgr0; tput bold)', %s$(tput sgr0)" \
     '  This script already ran for' "${RESULT_FILE}" 'Continue [yN]? ' ;
  read ANS ; my_regx='[Yy]' ;
  if [[ "${ANS}" =~ $my_regx ]] ; then
#-  echo 'SUCCESS, CONTINUE' ;
    printf "$(tput setaf 2; tput bold)CONTINUING $(tput sgr0)...\n"
  else
    echo 'ABORTED BY USER ...' ;
    exit 0;
  fi
fi

# MY_PARSE_HTML must be set in .bashrc or .profile ...
 cat "${RESULT_FILE}" \
   | egrep -v 'class="comments"' \
   | grep "${MY_PARSE_HTML}" \
   | while read RESULT_LINE ; do # {
##    printf "$(tput bold)<< $(tput sgr0; tput setaf 3)%s $(tput sgr0; tput bold)>>$(tput sgr0)\n" "${RESULT_LINE}" ;

      RESULT_LINK="$(echo "${RESULT_LINE}" \
                   | sed -e 's/^.*<a href="//' \
                         -e 's/" title=".*$//' \
                         -e 's#/view/#/download/#' \
                         -e 's/$/.torrent/')" ;
##    printf "  '%s'\n" "${RESULT_LINK}"

      RESULT_LINK_TITLE="$(echo "${RESULT_LINE}" \
                   | sed -e 's/^.* title="//' \
                         -e 's/">.*//')"

      #########################################################################
      # Isolate the target directory from the name and see if it's there ...
      # DIR="$(ls -d 'One Piece'*)" ; echo "'${DIR}'"
      #
      if [ ${HAVE_FILES} -eq 0 ] ; then # {
        TARGET_DIR="$(echo "${RESULT_LINK_TITLE}" \
                      | sed -e 's/^[[][A-Za-z][A-Za-z]*] //' \
                            -e 's/ - [0-9][0-9]* ([1-9][0-9]*[a-z]).*$//' \
                            -e "s/'/’/g")" ;
        TARGET_DIR="$(ls -d "${TARGET_DIR}"*)" ; RC=$? ;
        if [ ${RC} -ne 0 ] ; then # {
          printf "  $(tput setaf 3; tput bold)SKIPPING '$(tput setaf 5)%s$(tput setaf 3)'" \
                 "${TARGET_DIR}" ;
          printf "$(tput sgr0; tput bold), does NOT exist for this season.\n" ;
          continue ;
        fi # }
      else # }{
        TARGET_DIR='.' ;
      fi # }

      #########################################################################
      # The 'st.sh' script always uses './files', so let's check it outside of
      # __this__ script to save some time.
      #
      pushd "${TARGET_DIR}" >/dev/null 2>&1 \
        || { printf "  $(tput setaf 1; tput bold)FATAL ERROR!$(tput sgr0)\n" ; exit 2; };

      MY_TEST_NAME="./files/${RESULT_LINK_TITLE}.torrent" ;
      if [ -s "${MY_TEST_NAME}" ] ; then # {
        printf "  $(tput setaf 3; tput bold)SKIPPING '$(tput setaf 5)%s$(tput setaf 3)'" \
               "$(basename "${MY_TEST_NAME}")" ;
        printf "$(tput sgr0; tput bold), already in './files'\n" ;
      else # }{
        printf "  $(tput bold)GETTING '$(tput setaf 2)%s$(tput sgr0; tput bold)'$(tput sgr0)\n" \
               "${RESULT_LINK_TITLE}"
        if [ ${DRY_RUN} -eq 0 ] ; then # {
 :          st.sh "${RESULT_LINK}" "${RESULT_LINK_TITLE}" ;
        fi # }
      fi # }

      popd >/dev/null 2>&1 ;

   (( PARSE_COUNT_LIMIT -= 1 )) ;
   if [ ${PARSE_COUNT_LIMIT} -lt 1 ] ; then # {

     printf "$(tput bold; tput setaf 5)BREAKING LOOP ...$(tput sgr0)\n"
     break ;
   fi # }

 done # }

 if [ -d "${SEARCH_RESULT_DIR}" ] ; then # {
   printf "$(tput bold)SAVING '$(tput setaf 3)${RESULT_FILE}$(tput sgr0; tput bold)' .."
   MY_SAVE_BASE="$(basename "${RESULT_FILE}" '.html')" ;
   # The date timestamp should absolutely make collisions impossible!
   /bin/mv "${RESULT_FILE}" "${SEARCH_RESULT_DIR}/${MY_SAVE_BASE}-‘$(date)’.html" ;
   printf ". $(tput setaf 2)COMPLETE!\n" ;
   tput sgr0 ;
 fi # }


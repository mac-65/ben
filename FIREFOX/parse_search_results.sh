#! /bin/bash
#

SEARCH_RESULT_DIR='./SEARCH_RESULTs' ;
ARG_COUNT=$# ;
MY_DEBUG=0 ; # ... turns off the clean-up  parts for the HTML file.

###############################################################################
# A quick and dirty hack to limit the number of results we parse ...
# The maximum amount on the search results page are 75 records.
# Setting this on the CLI limits this script to the first X results.
#
MY_REGX='^[0-9]+$' ;
PARSE_COUNT_LIMIT=99 ;
if [[ ${ARG_COUNT} -gt 0 && "$1" =~ ${MY_REGX} ]] ; then # {
   PARSE_COUNT_LIMIT="$1" ; shift ;
fi ; # }
PARSE_COUNT_LIMIT_INITIAL=${PARSE_COUNT_LIMIT} ;

###############################################################################
# Perform some very simple validation ...
#
RESULT_FILE='' ;
ARG_COUNT=$# ;
if [[ ${ARG_COUNT} -eq 0 || ( ${ARG_COUNT} -eq 1 && "$1" = '-h' ) ]] ; then # {
  if [ ! -s *html ] ; then # {
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
  else # }{
    RESULT_FILE="$(echo -ne *html)" ;
  fi ; # }
elif [ "${MY_PARSE_HTML}" = '' ] ; then # }{
   printf "$(tput setaf 1; tput bold)ERROR$(tput sgr0) -- " ; \
   printf "$(tput bold)'$(tput setab 4)MY_PARSE_HTML$(tput sgr0; tput bold)' " ; \
   printf "is NOT set in the enviornment,$(tput sgr0) EXITING.\n" ;
   exit 4;
fi # }

###############################################################################
if [ "${RESULT_FILE}" = '' ] ; then
  RESULT_FILE="$1" ; shift ; # This is the {Firefox} saved search results page.
fi
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
  [[ ${MY_DEBUG} -eq 0 ]] && /bin/rm -rf "./${CLEANUP_DIR}" ;
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

      #########################################################################
      # Check the limit count *here* instead of the bottom of the loop to
      # include series which may not have been set up.  I was kinda on the
      # fence about this -- should the count __only__ mean just active series?
      #
      (( PARSE_COUNT_LIMIT -= 1 )) ;
      if [ ${PARSE_COUNT_LIMIT} -lt 0 ] ; then # {

        printf "$(tput bold; tput setaf 5)BREAKING LOOP ...$(tput sgr0)\n"
        break ;
      fi # }

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
      #
      if [ ${HAVE_FILES} -eq 0 ] ; then # {
        TARGET_DIR="$(echo "${RESULT_LINK_TITLE}" \
                      | sed -e 's/^[[][A-Za-z][A-Za-z]*] //' \
                            -e 's/ - [0-9][0-9]* ([1-9][0-9]*[a-z]).*$//' \
                            -e "s/'/’/g")" ;
        ls -d "${TARGET_DIR}"* >/dev/null 2>&1 ; RC=$? ;
        if [ ${RC} -ne 0 ] ; then # {
          printf "  $(tput setab 1; tput bold)SKIPPING$(tput sgr0; tput bold) '$(tput setaf 5)%s$(tput setaf 3)'" \
                 "${TARGET_DIR}" ;
          printf "$(tput sgr0; tput bold), is NOT configured this season.\n" ;
          continue ;
        else # }{
          #####################################################################
          # (I'm pretty sure there's a way to test if just the 'ls' failed,
          # but I'm feeling a little lazy right now 🤪.)
          #
          TARGET_DIR="$(ls -d "${TARGET_DIR}"* 2>/dev/null | head -1)" ;
        fi # }
      else # }{
        TARGET_DIR='.' ;
      fi # }

      #########################################################################
      # The 'st.sh' script always uses './files', so let's check it outside of
      # __this__ script to save some time.
      #
      pushd "${TARGET_DIR}" >/dev/null 2>&1 \
        || { printf "  $(tput setaf 1; tput bold)FATAL ERROR!$(tput sgr0; tput bold) -- " ; \
             printf "Can't pushd '${TARGET_DIR}'\n" ; \
             exit 2; \
           };

      MY_TEST_NAME="./files/${RESULT_LINK_TITLE}.torrent" ;
      if [ -s "${MY_TEST_NAME}" ] ; then # {
        printf "  $(tput setaf 3; tput bold)SKIPPING '$(tput setaf 5)%s$(tput setaf 3)'" \
               "$(basename "${MY_TEST_NAME}")" ;
        printf "$(tput sgr0; tput bold), already in './files'\n" ;
      else # }{
        printf "  $(tput bold)TRYING '$(tput setaf 2)%s$(tput sgr0; tput bold)'$(tput sgr0)\n" \
               "${RESULT_LINK_TITLE}"
        if [ ${DRY_RUN} -eq 0 ] ; then # {
           if [ ${MY_DEBUG} -eq 0 ] ; then
              st.sh "${RESULT_LINK}" "${RESULT_LINK_TITLE}" ;
           else # }{
              printf "    PWD = '%s'\n" "$(pwd)" ;
              echo '    ==> ' st.sh "'${RESULT_LINK}'" "'${RESULT_LINK_TITLE}'" ;
           fi # }
        fi # }
      fi # }

      popd >/dev/null 2>&1 ;

 done # }

 ##############################################################################
 # Yeah, we __always__ have a 'SEARCH_RESULT_DIR'; it's just how it evolved ...
 #
 if [[ ${MY_DEBUG} -eq 0 && -d "${SEARCH_RESULT_DIR}" ]] ; then # {
   MY_SAVE_BASE="$(basename "${RESULT_FILE}" '.html')" ;
   ############################################################################
   # The date timestamp should absolutely make collisions impossible!
   # ALSO, we ensure that, in the event we re-ran a search results file,
   # we don't try to overwrite it with itself ...
   #
   if [ ! -s "${SEARCH_RESULT_DIR}/${MY_SAVE_BASE}.html" ] ; then # {
     printf "$(tput bold)SAVING '$(tput setaf 3)${RESULT_FILE}$(tput sgr0; tput bold)' .." ;
     /bin/mv "${RESULT_FILE}" \
       "${SEARCH_RESULT_DIR}/${MY_SAVE_BASE}-[${PARSE_COUNT_LIMIT_INITIAL}]-‘$(date)’.html" ;
   else # }{
     printf "$(tput bold)RE-RUN OF '$(tput setaf 6)%s$(tput sgr0; tput bold)' IS .." \
       "${MY_SAVE_BASE}.html" ;
   fi # }
 else # }{
   printf "$(tput bold)DEBUG RUN IS .." ;
 fi # }
 printf ". $(tput setaf 2)COMPLETE!\n" ; tput sgr0 ;


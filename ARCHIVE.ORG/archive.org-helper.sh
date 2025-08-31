#! /bin/bash

# exit 0;

sigint_handler() {
  printf 'ABORTED BY USER\n' ;
  exit 3;
}

trap 'sigint_handler' SIGINT SIGHUP SIGTERM ; # trap -l


  #############################################################################
  # This is a "helper" script for retrieving archives from 'archive.org'.
  #
  # Retrieving archives can be done in at least two ways:
  #  - selecting a download option and saving the desired file one by one, or
  #  - downloading the torrent file and retrieving the archive via a client.
  #
  # FIRST OPTION -
  # The problem with the first option is the manual process involved can be
  # very tedious if there are many archives / files in each archive.  Each
  # file would need to be selected then saved to the desired local location.
  #
  # Also, if an archive contains multiple "items" (e.g., a CD set with two or
  # more CDs that have been rip'd), the cover art for each CD may share the
  # same filename ("cover.jpg"), but the "top-level" html page does NOT show
  # the context of each "cover.jpg" complicating the save process.
  #
  # SECOND OPTION -
  # While the torrent option is less tedious than manually downloading each
  # interesting file, this option has some interesting issues as well:
  #  - Sometimes the torrent file is not updated if additional items are
  #    added to a particular archive (e.g., the torrent file for the archive
  #    'https://archive.org/details/ragnarok-online-music-collection' only
  #    contains info for the item -->
  #    "2002.03.26 - Ragnarok Online soundTeMP Special Remix!! [FLAC] {SGCD-0579}/"
  #    The remaining CDs in the archive are __missing__ (as of this writing)
  #    from the torrent file.  I'm not sure, but this may be because the
  #    torrent file is generated only when an archive is first built?  Dunno.
  #    This is only discovered after the torrent is loaded in the client.
  #  - There may be files that the user is NOT interested in downloading.
  #    These may include auto-generated MP4 files from DVD archives, etc., and
  #    these can be filtered out using this script.
  #
  # This script tries to competently address the above issues; it's not perfect
  # and is still an on-going work-in-progress.
  #############################################################################
  # A cheat for a search result page -->
  # cat 'User Account.html' | grep '<a href="https://archive.org/details' | sed -e 's/^.*<a href="//' -e 's#" .*##'
  #
DBG=':' ;

WGET_FILE='echo /usr/bin/wget -c --quiet --show-progress' ;
WGET_FILE='/usr/bin/wget -c --quiet --show-progress' ;

  #############################################################################
  # For getting the HTML source file, we'll ignore any CLI arguments (which is
  # usually '--limit-rate=XXXk' since the source is generally not big enough
  # to cause any network competition).
  #
WGET_HTML='echo /usr/bin/wget -c --quiet --show-progress' ;
WGET_HTML='/usr/bin/wget -c --quiet --show-progress' ;

FILENAME_PATH_SEPARATOR='|' ;

###############################################################################
# Steps:
#  1. Make any archive notes __here__.
#  2. Edit the "LOCAL_*" variables as needed.
#  3. Add the desired URL links to the 'HTML_LINK' list below.
#
LOCAL_MP4s=0 ; # Set to '1' if the auto-generated ‘mp4’ files are wanted.
GLOBAL_LOGs=1 ; # Set to '1' if the log file in a subdirectory is wanted
               # (usually goes with the ‘.cue’ file, etc.)  We don't care
               # about any log file in the root directory of the archive.
GLOBAL_EXCLUDEs='_thumb[.]|[.]thumbs|[.]xml|[.]sqlite' ;
LOCAL_EXCLUDEs='' ; # Set to an egrep regexp to exclude other filenames.
      # ❗ Note, the "string" must be formatted as it appears in the html
      #    from the web page, i.e. ' ' should be '%20'.  This is annoying!
      #    Fortunately, the use case for this is generally limited to
      #    embedded SPACE characters - there may be others.  This script uses
      #    a sed command to convert these character(s) and only handles the
      #    SPACE character (other will be added as needed / discovered).
      #    Example - '01 RAQUEL WELCH.mp4' will become
      #              '01%20RAQUEL%20WELCH.mp4' to correctly match what's in
      #              the html (if the user wishes to exclude that download).
      #              REF :: https://archive.org/details/roustabout-1964
LOCAL_EXCLUDEs='[.]mp3$' ;
#LOCAL_EXCLUDEs+='|[.]ia[.]mp4' ; # Also set the above 'LOCAL_MP4s=1' ...

LOCAL_EXCLUDEs="$(echo "${LOCAL_EXCLUDEs}" | sed -e 's/ /%20/g')" ; # HACK!

HTML_DIR='./Html' ; # Used to save the html pages that we parse for the files.
DONE_DIR='./.DONE' ; # an entry is made if the link is fully retrieved.

###############################################################################
#    ######
#    #       #    #  #    #   ####   #####   #    ####   #    #
#    #       #    #  ##   #  #    #    #     #   #    #  ##   #
#    ####    #    #  # #  #  #         #     #   #    #  # #  #
#    #       #    #  #  # #  #         #     #   #    #  #  # #
#    #       #    #  #   ##  #    #    #     #   #    #  #   ##
#    #        ####   #    #   ####     #     #    ####   #    #
###############################################################################
#
#
get_and_parse_html_page() {

  set +x ;
  local URL_IN="$1" ; shift ;
  $DBG echo "$@" ; # DBG

   ############################################################################
   # If we already *have* the correct path, then this won't do anything ...
   # 'URL_RAW' has the "corrected" path and the trailing '/' character which
   # we test for to see if we'll download the/any log files in that location.
   #
  local URL_RAW="$(echo "${URL_IN}" \
                    | sed -e 's#archive.org/details#archive.org/download#')" ;
   ############################################################################
   # Clean up any trailing '/' character from the URL ...
   # 'URL_ROOT' is use to build URLs for retrieving files or traversing the
   # directory tree of the archive.
   #
  local URL_ROOT="$(echo "${URL_RAW}" | sed -e 's#/$##')" ; # remove '/'

   ############################################################################
   # Get these values now as we'll use it to build a filename if wget returns
   # the page as 'index.html'.  The 'echo -e' handles any %XX conversions for
   # us in the HTML link that was provided by the user (by scraping the link
   # in the browser) ...
   #
   # It's a little hacky, but the top level directory of the HTML link returns
   # its basename, where as a subdirectory will return 'index.html'.  So we
   # ensure that 'URL_PATHNAME' is not set to an EMPTY string by checking
   # for the '/' character at the end of the HTML link string.
   #
   # Also: for music archives, get the '.log' file (if present) from the rip;
   #       the 'echo -e' handles any %XX conversions for us in the HTML link.
   #

   ############################################################################
   # 'GET_LOGs' is set to indicate that any log files in the current directory
   # should be retrieved.  This is typical for music archives where a '.log'
   # file is built from the RIP of the music media (CD or otherwise).
   #
  local GET_LOGs=0 ;
  if [[ "${URL_RAW}" =~ /$ ]] ; then # {
    [[ "${GLOBAL_LOGs}" -eq 1 ]] && GET_LOGs=1 ;
  fi ; # }

    ###########################################################################
    # 'URL_PATHNAME' is used to build the relative path __locally__ to chdir
    # to before using wget to download the file.  We remove the "common" part
    # of the URL and use that string as the relative pathname of the directory,
    # e.g. -->
    #    'https://archive.org/details/kill-la-kill-ed1'  =>  'kill-la-kill-ed1'
    #
  local URL_PATHNAME="$(echo -e "$(echo "${URL_RAW}" | cut -d'/' -f5- | sed -e 's/%/\\x/g')")" ;

    #############################################################################
    # Build a filename from the URL link to get its html source.
    #
  local URL_FILENAME="$(echo "${URL_PATHNAME}" \
      | sed -e 's#/$##' -e "s#/#${FILENAME_PATH_SEPARATOR}#g")" ;

    #############################################################################
    # Get the html code for the page ...
    #
  local HTML_FILE_PATHNAME="${HTML_DIR}/${URL_FILENAME}" ;
  if [ -s "${HTML_FILE_PATHNAME}" ] ; then # {
    tput setaf 2 ; tput bold ; echo "ALREADY RETRIEVED '${URL_RAW}' ..." ; tput sgr0 ;
  else # }{
    tput setaf 3 ; tput bold ; echo "${WGET_HTML} '${URL_RAW}'"  ; tput sgr0 ;
    { pushd "${HTML_DIR}" ; } >/dev/null 2>&1 ;

      ${WGET_HTML} "${URL_RAW}" ; RC=$? ;
        # Did we get a 'ERROR 503: Service Temporarily Unavailable.' ?
      if [ ${RC} -eq 8 ] ; then # {
        printf "$(tput setaf 1; tput bold)FATAL - $(tput sgr0; tput bold)"
        printf "wget$(tput sgr0) encountered a error (probably a 503)%s\n" '!';
        # Abort the process and prevent an entry being made in ‘./.DONE’. This
        # should allow the script to pick up where it left off when it is rerun.
        exit 8;
      fi # }

        #########################################################################
        # Sometimes ... We'll get 'index.html' __instead__ of the basename of
        #           the wget pathname.  This usually happens when we're trying
        #           to get a subdirectory from the archive's "root" pathname.
        #           Fortunately, a simple rename fixes this script right up
        #           and everything proceeds normally for getting the contents.
        #
      if [ -s 'index.html' ] ; then # {
        /bin/mv 'index.html' "${URL_FILENAME}" ;
      fi # }
    { popd ; } >/dev/null 2>&1 ;
  fi # }

    #############################################################################
    #############################################################################
    # Okay, we got the URL source file for the URL passed in to this function ...
    #   - grep the interesting URL ('<a href=') tags.
    #   - remove any navigation tags (e.g., "Parent Directory," etc.)
    #   - remove any remaining HTML
    # At this point, we should have a list of:
    #   - filenames from the URL, and/or
    #   - directories (which are identified by their trailing '/' character).
    #
  cat "${HTML_FILE_PATHNAME}" \
      | grep '<td><a href="' \
      | egrep -v 'title="Parent Directory"' \
      | sed -e 's/^.*<td><a href="//' -e 's#">.*##' \
    \
      | if [ "${GLOBAL_EXCLUDEs}" = '' ] ; then cat - ; else egrep -v "${GLOBAL_EXCLUDEs}" ; fi \
      | if [ ${LOCAL_MP4s} -eq 1 ] ; then cat - ; else egrep -v '[.]mp4$' ; fi \
      | if [ ${GET_LOGs} -eq 1 ] ; then cat - ; else egrep -v '[.]log$' ; fi \
      | if [ "${LOCAL_EXCLUDEs}" = '' ] ; then cat - ; else egrep -v "${LOCAL_EXCLUDEs}" ; fi \
    \
    | while read MY_SPEC ; do # {
      if [[ "${MY_SPEC}" =~ /$ ]] ; then # {

        printf "$(tput sgr0 ; tput bold) SPEC = '$(tput setaf 5)%s'$(tput sgr0)\n" "${MY_SPEC}" ;

        get_and_parse_html_page "${URL_ROOT}/${MY_SPEC}" "$@" ;

        printf "$(tput sgr0 ; tput bold) > SPEC = '$(tput setaf 5)%s'$(tput sgr0)\n" "${MY_SPEC}" ;
        $DBG tput sgr0 ; $DBG tput setab 4 ; $DBG tput bold ;
        $DBG printf "RETURN FROM$(tput sgr0 ; tput bold ;) get_and_parse_html_page('%s')\n" \
               "${URL_ROOT}/${MY_SPEC}" ;
        continue ;
      fi # }

      #########################################################################
      # We "special case" the torrent files to the top level of the directory.
      #
      if [[ "${MY_SPEC}" =~ [.]torrent$ ]] ; then # {{
        TARGET_DIR='./files' ;
      else # }{
        TARGET_DIR="${URL_PATHNAME}" ;
      fi ; # }}
      $DBG printf "$(tput sgr0 ; tput bold)> TARGET_DIR = '$(tput setaf 5)%s'$(tput sgr0)\n" "${TARGET_DIR}" ;

     mkdir -p "${TARGET_DIR}" ;
     { pushd "${TARGET_DIR}" ; } >/dev/null 2>&1 ;

       ${WGET_FILE} "$@" "${URL_ROOT}/${MY_SPEC}" ;

     { popd ; } >/dev/null 2>&1 ;

    done # }

set +x ;
}

###############################################################################
#         #     #                         ##    ##
#         ##   ##    ##     #   #    #   #        #
#         # # # #   #  #    #   ##   #  #          #
#         #  #  #  #    #   #   # #  #  #          #
#         #     #  ######   #   #  # #  #          #
#         #     #  #    #   #   #   ##   #        #
#         #     #  #    #   #   #    #    ##    ##
###############################################################################
if true ; then # {

  mkdir -p "${HTML_DIR}" './files' ; # We save each torrent file in './files'.
  mkdir -p "${DONE_DIR}" ;
    ###########################################################################
    # Add the URLs from 'archive.org' here.  Simplist way is to copy them from
    # the browser and paste them below (the script will automatically convert
    # any hex characters in the copied URL as needed).
    #
    # If the first character of the URL is '-', the link will be ignored.
    #
  for HTML_LINK in \
     '# This is a comment.  Note it must be quoted.' \
      -https://archive.org/details/ragnarok-online-music-collection \
      https://archive.org/details/ragnarok-online-complete-soundtrack \
      https://archive.org/details/ragnarok-online-music-collection \
      https://archive.org/details/Saladedemais_-_MPTeam_-_Ragnarok_Online_Selection \
     '# This next link will be skipped.' \
     -https://archive.org/details/ragnarok-online-music-collection \
    ; do # {

    ###########################################################################
    # See if we've already completed this link ...
    #
    HTML_BASENAME="$(basename -- "${HTML_LINK}")" ;

    if [[ -f "${DONE_DIR}/${HTML_BASENAME}" ]] ; then
      tput sgr0 ; tput setab 7 ; tput bold ; tput setaf 4 ;
      echo "COMPLETED$(tput sgr0 ; tput bold ;) :: '$(tput setaf 5)${HTML_LINK:0}$(tput sgr0 ; tput bold ;)'" ;
      continue ;
    fi # }

    if [[ "${HTML_LINK}" =~ ^# ]] ; then # {{
       continue ; # Ignore any notes about the links from the user ...
    elif [[ "${HTML_LINK}" =~ ^- ]] ; then # }{
      tput sgr0 ; tput setab 3 ; tput bold ;
      echo "SKIPPING$(tput sgr0 ; tput bold ;) :: '$(tput setaf 5)${HTML_LINK:1}$(tput sgr0 ; tput bold ;)'" ;
      continue ;
    else # }{
      tput sgr0 ; tput setab 2 ; tput bold ;
      echo "RETRIEVING$(tput sgr0 ; tput bold ;) :: '$(tput setaf 33)${HTML_LINK:0}$(tput sgr0 ; tput bold ;)'" ;
    fi # }}
    tput sgr0 ;

    get_and_parse_html_page "${HTML_LINK}" "$@" ;

    date >> "${DONE_DIR}/${HTML_BASENAME}" ;

    set +x ;

  done # }

else # }{
  tput bold ; tput setaf 4 ; banner 'Complete!' ; tput sgr0 ;
fi # }

tput bold ; tput setaf 2 ; banner "$(date +'%D %r')" ; tput sgr0 ;

exit 0;


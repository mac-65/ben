#! /bin/bash
# © 2023
# ~/C/musings/SCRIPTs/find_and_link_installed_rpms.sh

shopt -s lastpipe ;

ATTR_OFF="`tput sgr0`" ;
ATTR_BOLD="`tput bold`" ;
ATTR_UNDL="`tput smul`" ;
ATTR_CLR_BOLD="${ATTR_OFF}${ATTR_BOLD}" ;
ATTR_RED="${ATTR_OFF}`tput setaf 1`" ;
ATTR_RED_BOLD="${ATTR_RED}${ATTR_BOLD}" ;
ATTR_GREEN="${ATTR_OFF}`tput setaf 2;`" ;
ATTR_GREEN_BOLD="${ATTR_GREEN}${ATTR_BOLD}" ;
ATTR_YELLOW="${ATTR_OFF}`tput setaf 3`" ;
ATTR_YELLOW_BOLD="${ATTR_YELLOW}${ATTR_BOLD}" ;
ATTR_BLUE="${ATTR_OFF}`tput setaf 4`" ;
ATTR_BLUE_BOLD="${ATTR_BLUE}${ATTR_BOLD}" ;
ATTR_MAGENTA="${ATTR_OFF}`tput setaf 5`" ;
ATTR_MAGENTA_BOLD="${ATTR_MAGENTA}${ATTR_BOLD}" ;
ATTR_CYAN="${ATTR_OFF}`tput setaf 6`" ;
ATTR_CYAN_BOLD="${ATTR_CYAN}${ATTR_BOLD}" ;
ATTR_BROWN="${ATTR_OFF}`tput setaf 94`" ;
ATTR_BROWN_BOLD="${ATTR_BROWN}${ATTR_BOLD}" ;
OPEN_TIC='‘' ;
ATTR_OPEN_TIC="${ATTR_CLR_BOLD}${OPEN_TIC}" ;
CLOSE_TIC='’' ;
ATTR_CLOSE_TIC="${ATTR_CLR_BOLD}${CLOSE_TIC}${ATTR_OFF}" ;

ATTR_ERROR="${ATTR_RED_BOLD}ERROR -${ATTR_OFF}" ;
ATTR_NOTE="${ATTR_OFF}`tput setaf 12`NOTE -${ATTR_OFF}";

###############################################################################
###############################################################################
# Generate a complete list of all of the RPMs installed on the system.
# Note, this script may contain bugs, etc.  Use at your own risk ...
#
# This script __works__ if, after an initial Fedora installation, updates to
# that installation are performed by (something like) --
#   mkdir -p RPMs ; cd RPMs ;
#   mkdir 0000-updates ; # a monotonically increasing value ...
#   cd 0000-updates ; mkdir INSTALL_FROM ;
#   dnf -y update --downloadonly --downloaddir=. ;
#  # It's generally a good idea to 'init S' the system when installing updates,
#  # __even__ if you think you don't need to (:)).
#   cd RPMs/0000-updates ; pushd INSTALL_FROM ;
#   for rpms in ../*.rpm ; do ln "${rpms}" ; done ;
#   dnf -y install --disablerepo=* *.rpm ; popd ;
#
# After the updates are installed / applied, a copy of those rpms will be saved
# in the directory 0000-updates.  This is really helpful if an update breaks
# the system (like that's never happened to me; RPMs (as far as I know) are
# NOT applied transactionally) and this provides a "restore to" point if that
# happens.  There seems to be too much ambiguity with the 'dnf history undo'
# et. al. commands reliability and operation.  It seems that the revert-to
# package(s) must still be available in the off-site repository, otherwise
# the rollback fails.  Sadly, the repos do NOT seem to maintain a history
# chain of obsoleted packages, so it seems in general, this method is NOT
# 100% reliable except in trivial cases.  Refer -->
#   https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/managing_software_with_the_dnf_tool/assembly_handling-package-management-history_managing-software-with-the-dnf-tool
#
# Because I've been using dnf incorrectly all of this time to perform updates,
# some RPMs have been installed without me keeping a copy of the RPM(s).
#
# dnf should ALWAYS be run as either -->
#    dnf -y update --disablerepo=* *.rpm
# or
#    dnf -y install --disablerepo=* *.rpm
# to prevent dnf for adding additional RPMs to an update (even if I specified
# 'dnf install').
#
###############################################################################

###############################################################################
# Some STAT counters (the ctl-C handler uses these, so ensure they're defined).
#
RPMs_DEST='./NO_RSYNC' ; # We'll make this from where the script is started
RPMs_DEST_DIR="${RPMs_DEST}/RPMs" ; # If present, then must be manually removed
RPMs_MISSING_LOG="${RPMs_DEST}/RPMs_MISSING.txt" ; # Script will empty this file
RPMs_TOTAL=0 ;      # Total # of RPMs installed on the system
RPMs_CURRENT=0 ;    # current counter
RPMs_SYSTEM=0 ;     # original packages from system installation
RPMs_ADDED=0 ;      # packages added after installation (updates or otherwise)
RPMs_MISSING=0 ;    # packages that I should have, but are missing.  I'll have
                    # to manually find and download / rebuild these packages.
RPMs_WGET_OKAY=0 ;
RPMs_WGET_FAIL=0 ;

RPMs_BASE_LIST='' ; # file containing output of 'rpm -qa | sort' which is
                    # the list of RPM files from a baseline DVD installation
RPMs_LOG_FILE='' ;  # ABORTED -- easier to just redirect on the commandline
                    # Ignore these auto-built RPM packages:
RPMs_BASE_URL='' ;  # If set, then get the __missing__ RPM from fedoraproject.org
RPMs_EGREP_TO_IGNORE='^gpg-pubkey|^kmod-v4l2loopback|^kmod-vhba|^kmod-VirtualBox' ;

###############################################################################
# Set some defaults ...
#
MY_LINK_TYPE='-s' ; # DEFAULT to a soft-link when linking the RPM package.
STATUS_ON_SINGLE_LINE=0 ; # Set = 0 for a rolling STATUS display.

###############################################################################
# Print out the stats for this run.
#
print_stats() {
  if [[ ${RPMs_BASE_LIST} = '' ]] ; then
    printf "TOTAL RPMs -- %d, PROCESSED -- %d, SYSTEM -- %d, ADDED/UPDATED -- %d.\n" \
           ${RPMs_TOTAL} ${RPMs_CURRENT} ${RPMs_SYSTEM} ${RPMs_ADDED} ;
  else
    printf "TOTAL RPMs -- %d, PROCESSED -- %d, SYSTEM -- %d, ADDED/UPDATED -- %d, MISSING -- %d.\n" \
           ${RPMs_TOTAL} ${RPMs_CURRENT} ${RPMs_SYSTEM} ${RPMs_ADDED} ${RPMs_MISSING} ;
  fi
  (( WGET_TOTAL = RPMs_WGET_OKAY + RPMs_WGET_FAIL )) ;
  printf " WGET RPMs -- %d, SUCCESS -- %d, FAILED -- %d.\n" \
           ${WGET_TOTAL} ${RPMs_WGET_OKAY} ${RPMs_WGET_FAIL} ;
}

###############################################################################
# Ctl-C handler stuff ...
#
stty -echoctl ; # hide ^C
sigint_handler() {
   MY_REASON='ABORTED' ;
   if [ $# -ne 0 ] ; then
      MY_REASON="$1" ; shift ;
   else
      echo ;
      print_stats ;
   fi
   { set +x ; } >/dev/null 2>&1 ;
   tput setaf 1 ; tput bold ;
   for yy in {01..03} ; do echo -n "${MY_REASON} BY USER  " ; done ; echo ; tput sgr0 ;
   exit 1 ;
}

sigexit_handler() {
   echo 'GOODBYE!' ;
}

#trap 'sigint_handler' SIGINT SIGTERM
trap 'sigint_handler' HUP INT QUIT TERM ; # Don't include 'EXIT' here...
trap 'sigexit_handler' EXIT

###############################################################################
#
usage() {
    { set +x ; } >/dev/null 2>&1 ;
    local MY_APP="$( basename $0 )" ; # $0 is GLOBAL

    if [ $# -ne 0 ] ; then
        echo ;
        tput setaf 1 ; tput bold ; echo -n 'ERROR - ' ; tput sgr0 ;
        MY_PAD='' ;
        while [ $# -ne 0 ] ; do
            MY_MSG="$1" ; shift ;
            echo "${MY_PAD}${MY_MSG}" ;
            MY_PAD='      - ' ;
        done
    fi
    tput setaf 2 ; tput bold ; echo    'Usage - ' ; tput sgr0 ;

 #  tput setaf 3 ; tput bold ;
 #  echo " ${MY_APP} [-hl] [-H|-C] [-r RPMs_baseline.txt] RPMs_dir [RPMs_dir ..]" ;
 #  tput sgr0 ;

    tput setaf 3 ; tput bold ;
    echo " ${MY_APP} [-hl] [-H|-C] [-r RPMs_baseline.txt] RPMs_dir [RPMs_dir ..]" ;
    tput sgr0 ;

    echo    '  -h  print this help message and exit.' ;
 #  echo    "  -l  log the activity to ‘${ATTR_YELLOW}${RPMs_DEST_DIR}.log${ATTR_OFF}’" ;
    echo    "  -b  url :: Download all of the baseline RPMs into the directory ‘${ATTR_GREEN}${RPMs_DEST}/RPMs_BASE${ATTR_OFF}’." ;
    echo    "      Example - -b 'https://archives.fedoraproject.org/pub/fedora/linux/releases/37/Everything/x86_64/os/Packages/'" ;
 #  echo    "      ${ATTR_RED_BOLD}NOTE!${ATTR_OFF}  The ‘${ATTR_YELLOW_BOLD}-r${ATTR_OFF}’ option MUST preceed this option." ;
    echo    '  -H  build HARD links to the RPMs’ location, otherwise SOFT links are used.' ;
    echo    '      Hard-links have the advantage of building an easily copied directory archive.' ;
    echo    '  -C  actually copy the RPM file to the RPMs’ location.' ;
    echo    '  -r  file containing list of baseline RPMs.  This file is used to identify' ;
    echo    "      RPMs that are part of the original installation so that they won't be" ;
    echo -n '      flagged as missing.  This is optional but ' ;
    echo    "${ATTR_CYAN_BOLD}highly recommended!${ATTR_OFF}" ;
    echo    '      To build this file, perform an install (in VirtualBox with a DVD) then run --' ;
    echo    "        ${ATTR_MAGENTA_BOLD}rpm -qa | sort > RPMs_baseline.txt${ATTR_OFF}" ;
    echo -n '  RPMs_dir' ;
    echo    '  directory to search for the RPMs.  More than one can be specified.' ;
    echo    " ${ATTR_YELLOW_BOLD}Notes:${ATTR_OFF} - This script’s error checking is very minimal ... :)" ;
    echo    "        - The RPM output directory defaults to ‘${ATTR_YELLOW}${RPMs_DEST_DIR}${ATTR_OFF}’." ;
    echo    "        - The RPM output directory must ${ATTR_RED_BOLD}NOT${ATTR_OFF} already exist." ;

    exit 1 ;
}


###############################################################################
###############################################################################
# download_the_base_rpm "${RPMs_BASE_URL}" "${RPM_FILE}" "${RPMs_DEST}/RPMs_BASE" ;
#
download_the_base_rpm() {
   local RPMs_URL="$1" ; shift ;
   local RPM_PACKAGE_NAME="$1" ; shift ;
   local DEST_DIR="$1" ; shift ;

   local SUBDIR="$(echo "${RPM_PACKAGE_NAME:0:1}" | tr '[:upper:]' '[:lower:]')" ;
   local PACKAGE_URL="${RPMs_URL}/${SUBDIR}/${RPM_PACKAGE_NAME}.rpm"

   echo -n "${ATTR_BOLD} >>>> " ;
   echo -n "${ATTR_BLUE_BOLD}OKAY, ${ATTR_YELLOW_BOLD}DOWNLOADING ‘${ATTR_OFF}"
   echo -n "${ATTR_BOLD}${RPM_PACKAGE_NAME}.rpm${ATTR_YELLOW_BOLD}’ FROM FEDORA$(tput sgr0) --" ;

   { pushd "${DEST_DIR}" ; } >/dev/null 2>&1 ;

     wget -c -a rpms.log "${PACKAGE_URL}" ; RC=$? ;
     if [ ${RC} -eq 0 ] ; then
       echo -n "${ATTR_GREEN_BOLD} SUCCESS" ;
       (( RPMs_WGET_OKAY++ )) ;
     else
       echo -n "${ATTR_RED_BOLD} FAILED, RC = ${RC}" ;
       (( RPMs_WGET_FAIL++ )) ;
     fi

   echo -n "${ATTR_OFF}" ;

   { popd >/dev/null ; } 2>&1 ;
}


###############################################################################
#       #     #                                 ##     ##
#       ##   ##    ##     #   #    #           #         #
#       # # # #   #  #    #   ##   #          #           #
#       #  #  #  #    #   #   # #  #          #           #
#       #     #  ######   #   #  # #          #           #
#       #     #  #    #   #   #   ##           #         #
#       #     #  #    #   #   #    #            ##     ##
#

set +x
MY_OPTIONS=`getopt -o 'hHCr:b:' --long 'help,hardlink,copy,rpms-list:' -n "${ATTR_ERROR} ${ATTR_YELLOW}$0${ATTR_OFF}" -- "$@"` ;

if [ $? != 0 ] ; then
    usage ;
fi

eval set -- "${MY_OPTIONS}" ;
while true ; do
  case "$1" in
    -h|--help)
        if [ $# -ne 2 ] ; then
          usage "Excess arguments were IGNORED for the ‘help’ option" ;
        else
          usage ;
        fi
        ;;
    -l)
        shift ;
        RPMs_LOG_FILE="${RPMs_DEST}/RPMs.log" ;
        ;;
    -H|--copy)
        shift ;
        MY_LINK_TYPE='' ;
        ;;
    -C|--copy)
        shift ;
        MY_LINK_TYPE='copy' ;
        ;;
    -r|--rpms-list)
        #######################################################################
        # What I want to do with this is to check if a RPM that doesn't show
        # up in the FIND, is really a part of the original installation set.
        # This will show RPMs that must be manually re-downloaded or updated.
        #
        ARG="$1" ; shift ;
        if [ "${RPMs_BASE_LIST}" = '' ] ; then # {
            RPMs_BASE_LIST="$1" ;
            ###################################################################
            # Is '-s' busted -- it should NOT return TRUE for a directory..?
            # Hence, the need for the additional '-f' test.  The spec at
            # https://pubs.opengroup.org/onlinepubs/9699919799/utilities/test.html
            # seems kinda murky as well (because of the lack of a "must" clause).
            #
            if test -f "${RPMs_BASE_LIST}" && test -s "${RPMs_BASE_LIST}" ; then
              shift ;
            else
              usage "The argument '${ATTR_MAGENTA_BOLD}${RPMs_BASE_LIST}${ATTR_OFF}':" \
                    '  does NOT exist;' \
                    '  is NOT a regular file;' \
                    '  or does NOT have a size greater than ZERO.' ;
            fi
        else # }{
            usage "'${ARG}' already specified with '${RPMs_BASE_LIST}'" ;
        fi # }
        ;;
    -b)
        ARG="$1" ; shift ;
        RPMs_BASE_URL="$1" ; shift ;
        mkdir -p "${RPMs_DEST}/RPMs_BASE" ;
        ;;
    --)
        shift ; # This is the last option
        break ;
        ;;
    *)
        echo "${ATTR_ERROR} fatal script error - option handler for '${ATTR_YELLOW_BOLD}$1${ATTR_OFF}' not written!!!" ;
        echo "${ATTR_YELLOW_BOLD}Terminating ...${ATTR_OFF}" >&2 ; exit 5 ;
        ;;
  esac
done


###############################################################################
# CLEANED UP :: Olde hacky way replaced with new hacky way above ...
#


###############################################################################
# We're going to 'fullpath' the commandline arguements since it'll make the
# links to the found RPM files easier to build.
#
EXPANDED_PATHS='' ;
if [ $# -eq 0 ] ; then
  usage "No RPM search directories were specified" ;
else
  for SEARCH_DIR in "$@" ; do
    if [ ! -d "${SEARCH_DIR}" ] ; then
        usage "'$(tput setaf 3)${SEARCH_DIR}$(tput sgr0)' is not a directory" ;
    fi

    ###########################################################################
    # There doesn't seem to be a way to do this without getting the 'realpath'.
    #
    { pushd "${SEARCH_DIR}" ; } >/dev/null 2>&1 ;
    EXPANDED_PATHS="${EXPANDED_PATHS} '$(/bin/pwd -L)'" ;
    { popd >/dev/null ; } 2>&1 ;
  done
fi


###############################################################################
#
if [ ! -d "${RPMs_DEST}" ] ; then
  printf "The working directory '${ATTR_GREEN}$(pwd)/${RPMs_DEST}${ATTR_OFF}' is not there, make (y/${ATTR_YELLOW_BOLD}N${ATTR_OFF})? " ;
  read MY_ANS;
  MY_PATTERN='[Yy]' ; # https://stackoverflow.com/questions/18709962/regex-matching-in-a-bash-if-statement
  if [[ ! "${MY_ANS}" =~ ${MY_PATTERN} ]] ; then
     sigint_handler 'CANCELLED' ;
  fi
fi

mkdir -p "${RPMs_DEST}" ;
{ echo -n '# ' ; date ; } > "${RPMs_MISSING_LOG}" ; # Empty out the missing RPMs log file.
if [ "${RPMs_LOG_FILE}" != '' ] ; then
  { echo -n '# ' ; date ; } > "${RPMs_LOG_FILE}" ; # Empty out the log file
fi


###############################################################################
#
if [ -d "${RPMs_DEST_DIR}" ] ; then
    usage "The directory '${RPMs_DEST_DIR}' must NOT exist" ;
fi
MY_MSG="$(mkdir -p "${RPMs_DEST_DIR}" 2>&1)" ;
if [ $? -eq 1 ] ; then usage "${MY_MSG}" ; fi

if [[ ${MY_LINK_TYPE} = '-s' ]] ; then
  echo "${ATTR_BOLD}NOTE -- ${ATTR_BROWN_BOLD}USING SOFT LINKS${ATTR_OFF} (${ATTR_BOLD}default${ATTR_OFF})" ;
elif [[ ${MY_LINK_TYPE} = 'copy' ]] ; then
  echo "${ATTR_BOLD}NOTE -- ${ATTR_BROWN_BOLD}WILL COPY EACH RPM FILE${ATTR_OFF}" ;
else
  echo "${ATTR_BOLD}NOTE -- ${ATTR_BROWN_BOLD}USING HARD LINKS${ATTR_OFF}" ;
fi

echo -n 'Searching for ' ; MY_FLAG=". $(tput bold; tput setaf 5)done!$(tput sgr0)" ;
RPMs_TOTAL="$(rpm -qa | wc -l)" ;
echo -n "$(tput setab 4 ; tput bold)${RPMs_TOTAL}$(tput sgr0) " ;
echo -n 'RPMs installed on system, sorting ..' ;

#-- exit 0; # DBG

eval set -- "${EXPANDED_PATHS}" ;

###############################################################################
###############################################################################
# Loop through each RPM that's installed on the system ...
#
rpm -qa  \
  | egrep -v "${RPMs_EGREP_TO_IGNORE}" \
  | sort \
  | while read RPM_FILE ; do
    [[ ${MY_FLAG} != '' ]] && { echo "${MY_FLAG}" ; MY_FLAG='' ; } ;

    (( RPMs_CURRENT++ )) ;

    printf "%4.d " ${RPMs_CURRENT} ;
    echo -n "$(tput bold)${RPM_FILE}$(tput sgr0; tput sgr0)"
    RPM_FOUND="$(find -H "$@" -type f -name "${RPM_FILE}*" | tail -1)" ;
    echo -ne "$(tput el)" ;

    tput bold ;
    if [[ ${RPM_FOUND} != '' ]] ; then
        MY_COLOR=2 ; # Okay, let's get a little FANCY ...
        echo "${RPM_FOUND}" | egrep --quiet 'updates/' \
                            && { MY_COLOR=6 ; } ;
        echo "${RPM_FOUND}" | egrep --quiet 'devels/'  \
                            && { MY_COLOR=4 ; } ;
        echo -n " >>>> '$(tput setaf ${MY_COLOR})${RPM_FOUND}$(tput sgr0)'" ;

        (( RPMs_ADDED++ )) ;

        { pushd "${RPMs_DEST_DIR}" ; } >/dev/null 2>&1 ;
            if [ "${MY_LINK_TYPE}" = 'copy' ] ; then
              MY_MSG="$(/bin/cp "${RPM_FOUND}" . 2>&1)" ;
            else
              MY_MSG="$(/bin/ln ${MY_LINK_TYPE} "${RPM_FOUND}" 2>&1)" ;
            fi
            if [ $? -ne 0 ] ; then
                usage "${MY_MSG}" ;
            fi
        { popd >/dev/null ; } 2>&1 ;
    elif [[ ${RPMs_BASE_LIST} != '' ]] ; then
        #######################################################################
        # One RPM contains an extended regex character
        # (the '+' in 'memtest86+-5.31-0.3.beta.fc34.x86_64'), so egrep won't
        # return the expected behavior...
        #
        grep --quiet "${RPM_FILE}" "${RPMs_BASE_LIST}" ;
        if [ $? -eq 0 ] ; then
          if [ "${RPMs_BASE_URL}" = '' ] ; then
            echo -n "$(tput setaf 2) OKAY $(tput setaf 3)RPM FROM ORIGINAL INSTALLATION$(tput sgr0)" ;
            (( RPMs_SYSTEM++ )) ;
          else
            download_the_base_rpm "${RPMs_BASE_URL}" "${RPM_FILE}" "${RPMs_DEST}/RPMs_BASE" ;
          fi

        else
          echo -n "$(tput setaf 1) FAIL $(tput setaf 1)RPM FROM UNKNOWN INSTALLATION$(tput sgr0)" ;
          echo "${RPM_FILE}" >> "${RPMs_MISSING_LOG}" ; # Log the actual missing RPM

          (( RPMs_MISSING++ )) ;
        fi
    else
        echo -n " >>>> $(tput setaf 3)RPM (PROBABLY) FROM ORIGINAL INSTALLATION$(tput sgr0)" ;

        (( RPMs_SYSTEM++ )) ; # FIXME
    fi

    if [ ${STATUS_ON_SINGLE_LINE} -eq 0 ] ; then
        echo ; # A scrolling STATUS display ...
    else
        echo -ne "\r" ;
        #sleep 0.025 ;
    fi
done

print_stats ;

echo ;


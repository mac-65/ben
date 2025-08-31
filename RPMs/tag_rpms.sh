#! /bin/bash

###############################################################################
# For an update of Fedora from one release to another in VirtualBox, find all
# of the RPMs that will be applied to the update and make a hard link, and log
# where the original RPMs were linked from.  Used on my VirtualBox upgrade of
# Fedora 39 to Fedora 40 (which BTW, for some reason in Virtualbox, took the
# better part of 6+ hours!)
#
# Currently this script is linked from -->
#   '/ito/RPMs/Fedora_40-1.14/40/metadata/RPMs/'
#

MY_APP="`basename "$0"`" ; # ... A clever trick ...

if [ $# -eq 0 ] ; then # {
   MY_LAST=0 ;
   ############################################################################
   # fedora-40-x86_64              fedora-cisco-openh264-40-x86_64
   # rpmfusion-free-40-x86_64      rpmfusion-free-updates-40-x86_64
   # rpmfusion-nonfree-40-x86_64   rpmfusion-nonfree-updates-40-x86_64
   # updates-40-x86_64
   while true ; do
     printf 'Scanning ...\r' ;
     find ../[fur]* -type f -name '*.rpm' -exec "./${MY_APP}" {} \; ;
     printf '%s -> ' "${MY_LAST}" ;
     MY_LAST=`ls *.rpm | wc -l` ;
     printf '%s\n' "${MY_LAST} RPM packages ..." ;
     printf 'Sleeping\r' ;
     sleep 60 ; done \
        | tee -a RPMs-log.txt
fi # }

if [ $# -eq 1 ] ; then # {
  MY_RPM="$1" ; shift ;

  MY_BASE="$(basename "${MY_RPM}")" ;
  if [ ! -f "${MY_BASE}" ] ; then # {{
    printf "$(tput bold)LINKING -$(tput setaf 3)'%s'$(tput sgr0)\n" \
       "${MY_RPM}" ;
    ln "${MY_RPM}" ;
  else # }{
    : printf "$(tput bold)SKIPPING -$(tput setaf 2)'%s'$(tput sgr0)\n" \
       "${MY_BASE}" ;
  fi # }}
fi # }


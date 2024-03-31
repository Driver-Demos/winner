#!/usr/bin/env bash
#
# gen-status.sh - create the top level status.md and status.html files
#
# Copyright (c) 2024 by Landon Curt Noll.  All Rights Reserved.
#
# Permission to use, copy, modify, and distribute this software and
# its documentation for any purpose and without fee is hereby granted,
# provided that the above copyright, this permission notice and text
# this comment, and the disclaimer below appear in all of the following:
#
#       supporting documentation
#       source copies
#       source works derived from this source
#       binaries derived from this source or from derived source
#
# LANDON CURT NOLL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
# INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
# EVENT SHALL LANDON CURT NOLL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
# USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
# chongo (Landon Curt Noll, http://www.isthe.com/chongo/index.html) /\oo/\
#
# Share and enjoy! :-)

# firewall - run only with a bash that is version 5.1.8 or later
#
# The "/usr/bin/env bash" command must result in using a bash that
# is version 5.1.8 or later.
#
# We could relax this version and insist on version 4.2 or later.  Versions
# of bash between 4.2 and 5.1.7 might work.  However, to be safe, we will require
# bash version 5.1.8 or later.
#
# WHY 5.1.8 and not 4.2?  This safely is done because macOS Homebrew bash we
# often use is "version 5.2.26(1)-release" or later, and the RHEL Linux bash we
# use often use is "version 5.1.8(1)-release" or later.  These versions are what
# we initially tested.  We recommend you either upgrade bash or install a newer
# version of bash and adjust your $PATH so that "/usr/bin/env bash" finds a bash
# that is version 5.1.8 or later.
#
# NOTE: The macOS shipped, as of 2024 March 15, a version of bash is something like
#	bash "version 3.2.57(1)-release".  That macOS shipped version of bash
#	will NOT work.  For users of macOS we recommend you install Homebrew,
#	(see https://brew.sh), and then run "brew install bash" which will
#	typically install it into /opt/homebrew/bin/bash, and then arrange your $PATH
#	so that "/usr/bin/env bash" finds "/opt/homebrew/bin" (or whatever the
#	Homebrew bash is).
#
# NOTE: And while MacPorts might work, we noticed a number of subtle differences
#	with some of their ported tools to suggest you might be better off
#	with installing Homebrew (see https://brew.sh).  No disrespect is intended
#	to the MacPorts team as they do a commendable job.  Nevertheless we ran
#	into enough differences with MacPorts environments to suggest you
#	might find a better experience with this tool under Homebrew instead.
#
if [[ -z ${BASH_VERSINFO[0]} ||
	 ${BASH_VERSINFO[0]} -lt 5 ||
	 ${BASH_VERSINFO[0]} -eq 5 && ${BASH_VERSINFO[1]} -lt 1 ||
	 ${BASH_VERSINFO[0]} -eq 5 && ${BASH_VERSINFO[1]} -eq 1 && ${BASH_VERSINFO[2]} -lt 8 ]]; then
    echo "$0: ERROR: bash version needs to be >= 5.1.8: $BASH_VERSION" 1>&2
    echo "$0: Warning: bash version >= 4.2 might work but 5.1.8 was the minimum we tested" 1>&2
    echo "$0: Notice: For macOS users: install Homebrew (see https://brew.sh), then run" \
	 ""brew install bash" and then modify your \$PATH so that \"#!/usr/bin/env bash\"" \
	 "finds the Homebrew installed (usually /opt/homebrew/bin/bash) version of bash" 1>&2
    exit 4
fi


# setup bash file matching
#
# We must declare arrays with -ag or -Ag, and we need loops to "export" modified variables.
# This requires a bash with a version 4.2 or later.  See the larger comment above about bash versions.
#
shopt -s nullglob	# enable expanded to nothing rather than remaining unexpanded
shopt -u failglob	# disable error message if no matches are found
shopt -u dotglob	# disable matching files starting with .
shopt -u nocaseglob	# disable strict case matching
shopt -u extglob	# enable extended globbing patterns
shopt -s globstar	# enable ** to match all files and zero or more directories and subdirectories

# set variables referenced in the usage message
#
export VERSION="1.2 2024-03-30"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
GIT_TOOL=$(type -P git)
export GIT_TOOL
if [[ -z "$GIT_TOOL" ]]; then
    echo "$0: FATAL: git tool is not installed or not in \$PATH" 1>&2
    exit 5
fi
"$GIT_TOOL" rev-parse --is-inside-work-tree >/dev/null 2>&1
status="$?"
if [[ $status -eq 0 ]]; then
    TOPDIR=$("$GIT_TOOL" rev-parse --show-toplevel)
fi
export TOPDIR
export DOCROOT_SLASH="./"
export TAGLINE="bin/$NAME"
export MD2HTML_SH="bin/md2html.sh"
export REPO_URL="https://github.com/ioccc-src/temp-test-ioccc"
export SITE_URL="https://ioccc-src.github.io/temp-test-ioccc"
JPARSE_TOOL=$(type -P jparse)
export JPARSE_TOOL
if [[ -z "$JPARSE_TOOL" ]]; then
    echo "$0: FATAL: jparse tool is not installed or not in \$PATH" 1>&2
    exit 5
fi
export IOCCC_STATUS_VERSION="1.0 2024-03-09"
#
export NOOP=
export DO_NOT_PROCESS=
export EXIT_CODE="0"

# clear options we will add to tools
#
unset TOOL_OPTION
declare -ag TOOL_OPTION
export MODTIME_METHOD=""

# output_modtime - file modification time in W3C Datetime format:
#
#       https://www.w3.org/TR/NOTE-datetime
#
# for use in XML format for sitemaps:
#
#       https://www.sitemaps.org/protocol.html
#
# usage:
#       output_modtime filename
#
function output_modtime
{
    local FILENAME;	# filename argument

    # parse args
    #
    if [[ $# -ne 1 ]]; then
        echo "$0: ERROR: in output_modtime: expected 1 arg, found $#" 1>&2
        return 1
    fi
    FILENAME="$1"

    # produce output given the MODTIME_METHOD
    #
    case "$MODTIME_METHOD" in

    # macOS stat
    #
    macos_stat)
	TZ=UTC stat -f '%Sm' -t '%FT%T+00:00' "$FILENAME"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: in output_modtime:" \
		 "TZ=UTC stat -f '%Sm' -t '%FT%T+00:00' $FILENAME failed, error code: $status" 1>&2
	    exit 1
	fi
	;;

    # RHEL Linux stat
    #
    RHEL_stat)
	TZ=UTC stat -c '%y' "$FILENAME" | sed -e 's/ /T/' -e 's/\.[0-9]* //' -e 's/\([0-9][0-9]\)$/:&/'
	status0="${PIPESTATUS[0]}"
	status1="${PIPESTATUS[1]}"
	if [[ $status0 -ne 0 || $status1 -ne 0 ]]; then
	    echo "$0: ERROR: in output_modtime:" \
		 "TZ=UTC stat -c '%y' $FILENAME | sed .. failed, error codes: $status0 and $status1" 1>&2
	    exit 1
	fi
	;;

    ls_D)
	# We want to look at the format of ls -D, not find
	#
	# SC2012 (info): Use find instead of ls to better handle non-alphanumeric filenames.
	# https://www.shellcheck.net/wiki/SC2012
	# shellcheck disable=SC2012
	TZ=UTZ ls -D '%FT%T+00:00' -ld "$FILENAME" | awk '{print $6;}'
	status0="${PIPESTATUS[0]}"
	status1="${PIPESTATUS[1]}"
	if [[ $status0 -ne 0 || $status1 -ne 0 ]]; then
	    echo "$0: ERROR: in output_modtime:" \
		 "TZ=UTZ ls -D '%FT%T+00:00' -ld $FILENAME | awk .. failed, error codes: $status0 and $status1" 1>&2
	    exit 1
	fi
	;;

    *) echo "0: in output_modtime: unknown MODTIME_METHOD value: $MODTIME_METHOD" 1>&2
	exit 9
	;;
    esac
    return 0
}

# output_status_json
#
# write an status.json file to standard output (stdout)
#
# usage:
#	output_status_json contest_status news.md status.json
#
# returns:
#	0 ==> no errors detected, but output may be empty
#     > 0 ==> function error number
#
function output_status_json
{
    local NEWS_MD_PATH;		# news.md file path
    local STATUS_PATH;		# status.json file path
    #
    local IOCCC_STATUS;		# IOCCC contest_status to set
    local NEWS_MD_MOD_DATE;	# modification date of news.md to set
    local STATUS_JSON_MOD_DATE;	# modification date of status.json to set
    #
    local OLD_CONTEST_STATUS;	# "contest_status" that was in status.json
    local NEW_CONTEST_STATUS;	# contest_status are and a potential new "contest_status"
    local OLD_STATUS_UPDATE;	# "status_update" that was in status.json
    local NEW_STATUS_UPDATE;	# a potential "status_update" string for now

    # parse args
    #
    if [[ $# -ne 3 ]]; then
	echo "$0: ERROR: in output_status_json: expected 3 args, found $#" 1>&2
	return 1
    fi
    NEW_CONTEST_STATUS="$1"
    if [[ -z $NEW_CONTEST_STATUS ]]; then
	echo "$0: ERROR: in output_status_json: contest_status arg is empty" 1>&2
	return 2
    fi
    NEWS_MD_PATH="$2"
    if [[ ! -e $NEWS_MD_PATH ]]; then
	echo "$0: ERROR: in output_status_json: news.md arg does not exist: $NEWS_MD_PATH" 1>&2
	return 3
    fi
    if [[ ! -f $NEWS_MD_PATH ]]; then
	echo "$0: ERROR: in output_status_json: news.md arg is not a file: $NEWS_MD_PATH" 1>&2
	return 4
    fi
    if [[ ! -r $NEWS_MD_PATH ]]; then
	echo "$0: ERROR: in output_status_json: news.md arg is not a readable file: $NEWS_MD_PATH" 1>&2
	return 5
    fi
    STATUS_PATH="$3"
    if [[ ! -e $STATUS_PATH ]]; then
	echo "$0: ERROR: in output_status_json: status.json.html arg does not exist: $STATUS_PATH" 1>&2
	return 6
    fi
    if [[ ! -f $STATUS_PATH ]]; then
	echo "$0: ERROR: in output_status_json: status.json.html arg is not a file: $STATUS_PATH" 1>&2
	return 7
    fi
    if [[ ! -r $STATUS_PATH ]]; then
	echo "$0: ERROR: in output_status_json: status.json.html arg is not a readable file: $STATUS_PATH" 1>&2
	return 8
    fi

    # obtain news.md.html file modification date
    #
    NEWS_MD_MOD_DATE=$(output_modtime "$NEWS_MD_PATH")
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: in output_status_json: modification date of $NEWS_MD_PATH failed, error: $status" 1>&2
	return 9
    fi
    if [[ -z $NEWS_MD_MOD_DATE ]]; then
	echo "$0: ERROR: in output_status_json: modification date of $NEWS_MD_PATH is empty" 1>&2
	return 10
    fi

    # determine the "contest_status" that was in status.json
    #
    OLD_CONTEST_STATUS=$(grep '"contest_status"[[:space:]]*:[[:space:]]*"' "$STATUS_PATH" |
			 sed -e 's/^.*:[[:space:]]*"//' -e 's/",*//')

    # determine the "status_update" that was in status.json
    #
    OLD_STATUS_UPDATE=$(grep '"status_update"[[:space:]]*:[[:space:]]*"' "$STATUS_PATH" |
			sed -e 's/^.*:[[:space:]]*"//' -e 's/",*//')

    # update the status.json file modification date if the "contest_status" changed
    #
    NEW_STATUS_UPDATE=$(output_modtime "$STATUS_PATH")
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: in output_status_json: modification date of $STATUS_PATH failed, error: $status" 1>&2
	return 11
    fi
    if [[ -z $NEW_STATUS_UPDATE ]]; then
	echo "$0: ERROR: in output_status_json: modification date of $STATUS_PATH is empty" 1>&2
	return 12
    fi

    # only update the "status_update" If the "contest_status" changed
    #
    if [[ $OLD_CONTEST_STATUS == "$NEW_CONTEST_STATUS" ]]; then
	IOCCC_STATUS="$OLD_CONTEST_STATUS"
	STATUS_JSON_MOD_DATE="$OLD_STATUS_UPDATE"
    else
	IOCCC_STATUS="$NEW_CONTEST_STATUS"
	STATUS_JSON_MOD_DATE="$NEW_STATUS_UPDATE"
    fi

    # output json
    #
    echo '{'
    echo '    "no_comment" : "mandatory comment: because comments were removed from the original JSON spec",'
    echo "    \"IOCCC_status_version\" : \"$IOCCC_STATUS_VERSION\","
    echo "    \"contest_status\" : \"$IOCCC_STATUS\","
    echo "    \"news_update\" : \"$NEWS_MD_MOD_DATE\","
    echo "    \"status_update\" : \"$STATUS_JSON_MOD_DATE\""
    echo '}'
    return 0
}

# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-d topdir] [-n] [-N]
			[-t tagline] [-T md2html.sh] [-u repo_url]
			[p | pending | o | open | j | judging | c | closed]

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-d topdir	set topdir (def: $TOPDIR)
			NOTE: The '-d topdir' is passed as leading options on tool command lines.
	-D docroot/	set the document root path followed by slash (def: $DOCROOT_SLASH)
			NOTE: The '-D docroot/' is passed as leading options on tool command lines.
			NOTE: 'docroot' must end in a slash

	-n		go thru the actions, but do not update any files (def: do the action)
			NOTE: -n is passed to tool
	-N		do not process anything, just parse arguments (def: process something)

	-t tagline	string to write about the tool that formed the markdown content (def: $TAGLINE)
			NOTE: 'tagline' may be enclosed within, but may NOT contain an internal single-quote, or double-quote.
	-T md2html.sh	run 'markdown to html tool' to convert markdown into HTML (def: $MD2HTML_SH)

	-u repo_url	Base level URL of target git repo (def: $REPO_URL)
			NOTE: The '-u repo_url' is passed as leading options on tool command lines.
	-w site_url	Base URL of the web site (def: $SITE_URL)
			NOTE: The '-w site_url' is passed as leading options on tool command lines.

	[p | pending]	Set the contest_status to pending
	[o | open]	Set the contest_status to open
	[j | judging]	Set the contest_status to judging
	[c | closed]	Set the contest_status to closed
			(def: do not change contest_status)

NOTE: The '-v level' is passed as initial command line options to the 'markdown to html tool' (md2html.sh).
      The 'tagline' is passed as '-t tagline' to the 'markdown to html tool' (md2html.sh), after the '-v level'.
      Any '-T md2html.sh', '-p tool', '-P pandoc_opts', '-u repo_url', '-U top_url'
      are passed to the 'markdown to html tool' (md2html.sh), and will be before any command line arguments.

Exit codes:
     0         all OK
     1	       some file is not found, not a readable file or is malformed
     2         -h and help string printed or -V and version string printed
     3         command line error
     4         bash version is too old
     5	       some internal tool is not found or not an executable file
     6	       problems found with or in the topdir or topdir/YYYY directory
 >= 10         internal error

$NAME version: $VERSION"

# parse command line
#
while getopts :hv:Vd:D:nNt:T:u:w: flag; do
  case "$flag" in
    h) echo "$USAGE" 1>&2
	exit 2
	;;
    v) V_FLAG="$OPTARG"
	;;
    V) echo "$VERSION"
	exit 2
	;;
    d) TOPDIR="$OPTARG"
	TOOL_OPTION+=("-d")
	TOOL_OPTION+=("$TOPDIR")
	;;
    D) # parse -D docroot/
	case "$OPTARG" in
	*/) ;;
	*) echo "$0: ERROR: in -D docroot/, the docroot must end in /" 1>&2
	   echo 1>&2
	   print_usage 1>&2
	   exit 3
	   ;;
	esac
	DOCROOT_SLASH="$OPTARG"
	# -D docroot/ always added after arg parsing
	;;
    n) NOOP="-n"
	;;
    N) DO_NOT_PROCESS="-N"
	;;
    t) # parse -t tagline
	case "$OPTARG" in
	*"'"*)
	    echo "$0: ERROR: in -t tagline, the tagline may not contain a single-quote character: $OPTARG" 1>&2
	    echo 1>&2
	    print_usage 1>&2
	    exit 3
	    ;;
	*'"'*)
	    echo "$0: ERROR: in -t tagline, the tagline may not contain a double-quote character: $OPTARG" 1>&2
	    echo 1>&2
	    print_usage 1>&2
	    exit 3
	    ;;
	*) ;;
	esac
	TAGLINE="$OPTARG"
	# -t tagline always added after arg parsing
	;;
    T) MD2HTML_SH="$OPTARG"
	TOOL_OPTION+=("-T")
	TOOL_OPTION+=("$MD2HTML_SH")
	;;
    u) REPO_URL="$OPTARG"
	TOOL_OPTION+=("-u")
	TOOL_OPTION+=("$REPO_URL")
	;;
    w) SITE_URL="$OPTARG"
	TOOL_OPTION+=("-w")
	TOOL_OPTION+=("$SITE_URL")
	;;
    \?) echo "$0: ERROR: invalid option: -$OPTARG" 1>&2
	echo 1>&2
	print_usage 1>&2
	exit 3
	;;
    :) echo "$0: ERROR: option -$OPTARG requires an argument" 1>&2
	echo 1>&2
	echo "$USAGE" 1>&2
	exit 3
	;;
    *) echo "$0: ERROR: unexpected value from getopts: $flag" 1>&2
	echo 1>&2
	echo "$USAGE" 1>&2
	exit 3
	;;
  esac
done

# remove the options
#
shift $(( OPTIND - 1 ));
#
# verify arg count and parse args
#
if [[ $V_FLAG -ge 5 ]]; then
    echo "$0: debug[5]: file argument count: $#" 1>&2
fi
#
if [[ $# -gt 1 ]]; then
    echo "$0: ERROR: expected 0 or 1 args, found: $#" 1>&2
    exit 3
fi
export CONTEST_STATUS=
if [[ $# -eq 1 ]]; then
    case "$1" in
    p|pending) CONTEST_STATUS="pending"
	;;
    o|open) CONTEST_STATUS="open"
	;;
    j|judging) CONTEST_STATUS="judging"
	;;
    c|closed) CONTEST_STATUS="closed"
	;;
    *) echo "$0: ERROR: unexpected status arg: $1" 1>&2
	echo 1>&2
	echo "$USAGE" 1>&2
	exit 3
	;;
    esac
fi

# always add the '-v level' option, unless level is empty, to the set of options passed to the md2html.sh tool
#
if [[ -n $V_FLAG ]]; then
    TOOL_OPTION+=("-v")
    TOOL_OPTION+=("$V_FLAG")
fi

# always add the '-t tagline' option, unless tagline is empty, to the set of options passed to the md2html.sh tool
#
if [[ -n $TAGLINE ]]; then
    TOOL_OPTION+=("-t")
    TOOL_OPTION+=("$TAGLINE")
fi

# always add the '-U URL' for the top level status.html file
#
TOOL_OPTION+=("-U")
TOOL_OPTION+=("$SITE_URL/status.html")

# always add the '-D docroot/' for the top level status.html file
#
TOOL_OPTION+=("-D")
TOOL_OPTION+=("$DOCROOT_SLASH")

# verify that we have a topdir directory
#
REPO_NAME=$(basename "$REPO_URL")
export REPO_NAME
if [[ -z $TOPDIR ]]; then
    echo "$0: ERROR: cannot find top of git repo directory" 1>&2
    echo "$0: Notice: if needed: $GIT_TOOL clone $REPO_URL; cd $REPO_NAME" 1>&2
    exit 6
fi
if [[ ! -e $TOPDIR ]]; then
    echo "$0: ERROR: TOPDIR does not exist: $TOPDIR" 1>&2
    echo "$0: Notice: if needed: $GIT_TOOL clone $REPO_URL; cd $REPO_NAME" 1>&2
    exit 6
fi
if [[ ! -d $TOPDIR ]]; then
    echo "$0: ERROR: TOPDIR is not a directory: $TOPDIR" 1>&2
    echo "$0: Notice: if needed: $GIT_TOOL clone $REPO_URL; cd $REPO_NAME" 1>&2
    exit 6
fi

# cd to topdir
#
if [[ ! -e $TOPDIR ]]; then
    echo "$0: ERROR: cannot cd to non-existent path: $TOPDIR" 1>&2
    exit 6
fi
if [[ ! -d $TOPDIR ]]; then
    echo "$0: ERROR: cannot cd to a non-directory: $TOPDIR" 1>&2
    exit 6
fi
export CD_FAILED
if [[ $V_FLAG -ge 5 ]]; then
    echo "$0: debug[5]: about to: cd $TOPDIR" 1>&2
fi
cd "$TOPDIR" || CD_FAILED="true"
if [[ -n $CD_FAILED ]]; then
    echo "$0: ERROR: cd $TOPDIR failed" 1>&2
    exit 6
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: now in directory: $(/bin/pwd)" 1>&2
fi

# verify that the md2html tool is executable
#
if [[ ! -e $MD2HTML_SH ]]; then
    echo  "$0: ERROR: md2html.sh does not exist: $MD2HTML_SH" 1>&2
    exit 5
fi
if [[ ! -f $MD2HTML_SH ]]; then
    echo  "$0: ERROR: md2html.sh is not a regular file: $MD2HTML_SH" 1>&2
    exit 5
fi
if [[ ! -x $MD2HTML_SH ]]; then
    echo  "$0: ERROR: md2html.sh is not an executable file: $MD2HTML_SH" 1>&2
    exit 5
fi

# verify readable non-empty news.md file
#
export NEWS_MD="news.md"
if [[ ! -e $NEWS_MD ]]; then
    echo  "$0: ERROR: news.md does not exist: $NEWS_MD" 1>&2
    exit 1
fi
if [[ ! -f $NEWS_MD ]]; then
    echo  "$0: ERROR: news.md is not a regular file: $NEWS_MD" 1>&2
    exit 1
fi
if [[ ! -r $NEWS_MD ]]; then
    echo  "$0: ERROR: news.md is not an executable file: $NEWS_MD" 1>&2
    exit 1
fi
if [[ ! -s $NEWS_MD ]]; then
    echo  "$0: ERROR: news.md is not an executable file: $NEWS_MD" 1>&2
    exit 1
fi

# verify readable non-empty status.json file
#
export STATUS_JSON="status.json"
if [[ ! -e $STATUS_JSON ]]; then
    echo  "$0: ERROR: status.json does not exist: $STATUS_JSON" 1>&2
    exit 1
fi
if [[ ! -f $STATUS_JSON ]]; then
    echo  "$0: ERROR: status.json is not a regular file: $STATUS_JSON" 1>&2
    exit 1
fi
if [[ ! -r $STATUS_JSON ]]; then
    echo  "$0: ERROR: status.json is not an executable file: $STATUS_JSON" 1>&2
    exit 1
fi
if [[ ! -s $STATUS_JSON ]]; then
    echo  "$0: ERROR: status.json is not an executable file: $STATUS_JSON" 1>&2
    exit 1
fi

# verify readable non-empty status.md file
#
export STATUS_MD="status.md"
if [[ ! -e $STATUS_MD ]]; then
    echo  "$0: ERROR: status.md does not exist: $STATUS_MD" 1>&2
    exit 1
fi
if [[ ! -f $STATUS_MD ]]; then
    echo  "$0: ERROR: status.md is not a regular file: $STATUS_MD" 1>&2
    exit 1
fi
if [[ ! -r $STATUS_MD ]]; then
    echo  "$0: ERROR: status.md is not an executable file: $STATUS_MD" 1>&2
    exit 1
fi
if [[ ! -s $STATUS_MD ]]; then
    echo  "$0: ERROR: status.md is not an executable file: $STATUS_MD" 1>&2
    exit 1
fi

# note status.html file
#
export STATUS_HTML="status.html"

# verify we have a non-empty readable .top file
#
export TOP_FILE=".top"
if [[ ! -e $TOP_FILE ]]; then
    echo  "$0: ERROR: .top does not exist: $TOP_FILE" 1>&2
    exit 6
fi
if [[ ! -f $TOP_FILE ]]; then
    echo  "$0: ERROR: .top is not a regular file: $TOP_FILE" 1>&2
    exit 6
fi
if [[ ! -r $TOP_FILE ]]; then
    echo  "$0: ERROR: .top is not an readable file: $TOP_FILE" 1>&2
    exit 6
fi
if [[ ! -s $TOP_FILE ]]; then
    echo  "$0: ERROR: .top is not a non-empty readable file: $TOP_FILE" 1>&2
    exit 6
fi

# determine how we can determine the file modification time in W3C Datetime format:
#
#	https://www.w3.org/TR/NOTE-datetime
#
# for use in XML format for sitemaps:
#
#	https://www.sitemaps.org/protocol.html
#
# Unfortunately there is NO single widely available, but simple command produce a modification
# time in W3C Datetime format.  At best we can try one of several methods in the hopes that
# we can find a method for the system in question.
#
# We will attempt to find the modification time in W3C Datetime of the .top file.
#
# Try macOS stat:
#
#	TZ=UTC stat -f '%Sm' -t '%FT%T+00:00' filename
#
TZ=UTC stat -f '%Sm' -t '%FT%T+00:00' "$TOP_FILE" > /dev/null 2>&1
status="$?"
if [[ $status -eq 0 ]]; then
    MODTIME_METHOD="macos_stat"
    if [[ $V_FLAG -ge 5 ]]; then
        echo "$0: debug[5]: TZ=UTC stat -f '%Sm' -t '%FT%T+00:00' works, MODTIME_METHOD: $MODTIME_METHOD" 1>&2
    fi

else

    # Try RHEL Linux stat:
    #
    #	TZ=UTC stat -c '%y' faq.md | sed -e 's/ /T/' -e 's/\.[0-9]* //' -e 's/\([0-9][0-9]\)$/:&/'
    #
    # NOTE: We only need to test the stat command.
    #
    TZ=UTC stat -c '%y' "$TOP_FILE" > /dev/null 2>&1
    status="$?"
    if [[ $status -eq 0 ]]; then
	MODTIME_METHOD="RHEL_stat"
	if [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: TZ=UTC stat -c '%y' works, MODTIME_METHOD: $MODTIME_METHOD" 1>&2
	fi

    else

	# Try ls -D:
	#
	#	TZ=UTZ ls -D '%FT%T+00:00' -ld
	#
	TZ=UTZ ls -D '%FT%T+00:00' -ld "$TOP_FILE" > /dev/null 2>&1
	status="$?"
	if [[ $status -eq 0 ]]; then
	    MODTIME_METHOD="ls_D"
	    if [[ $V_FLAG -ge 5 ]]; then
		echo "$0: debug[5]: TZ=UTZ ls -D '%FT%T+00:00' -ld works, MODTIME_METHOD: $MODTIME_METHOD" 1>&2
	    fi

	else
	    echo "$0: ERROR: we cannot determine how to form a file modification time in W3C Datetime formt" 1>&2
	    exit 9
	fi
    fi
fi

# print running info if verbose
#
# If -v 3 or higher, print exported variables in order that they were exported.
#
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: VERSION=$VERSION" 1>&2
    echo "$0: debug[3]: NAME=$NAME" 1>&2
    echo "$0: debug[3]: V_FLAG=$V_FLAG" 1>&2
    echo "$0: debug[3]: GIT_TOOL=$GIT_TOOL" 1>&2
    echo "$0: debug[3]: TOPDIR=$TOPDIR" 1>&2
    echo "$0: debug[3]: DOCROOT_SLASH=$DOCROOT_SLASH" 1>&2
    echo "$0: debug[3]: TAGLINE=$TAGLINE" 1>&2
    echo "$0: debug[3]: MD2HTML_SH=$MD2HTML_SH" 1>&2
    echo "$0: debug[3]: REPO_URL=$REPO_URL" 1>&2
    echo "$0: debug[3]: SITE_URL=$SITE_URL" 1>&2
    echo "$0: debug[3]: JPARSE_TOOL=$JPARSE_TOOL" 1>&2
    echo "$0: debug[3]: IOCCC_STATUS_VERSION=$IOCCC_STATUS_VERSION" 1>&2
    echo "$0: debug[3]: NOOP=$NOOP" 1>&2
    echo "$0: debug[3]: DO_NOT_PROCESS=$DO_NOT_PROCESS" 1>&2
    echo "$0: debug[3]: EXIT_CODE=$EXIT_CODE" 1>&2
    for index in "${!TOOL_OPTION[@]}"; do
	echo "$0: debug[3]: TOOL_OPTION[$index]=${TOOL_OPTION[$index]}" 1>&2
    done
    echo "$0: debug[3]: MODTIME_METHOD=$MODTIME_METHOD" 1>&2
    echo "$0: debug[3]: CONTEST_STATUS=$CONTEST_STATUS" 1>&2
    echo "$0: debug[3]: REPO_NAME=$REPO_NAME" 1>&2
    echo "$0: debug[3]: CD_FAILED=$CD_FAILED" 1>&2
    echo "$0: debug[3]: NEWS_MD=$NEWS_MD" 1>&2
    echo "$0: debug[3]: STATUS_JSON=$STATUS_JSON" 1>&2
    echo "$0: debug[3]: STATUS_MD=$STATUS_MD" 1>&2
    echo "$0: debug[3]: STATUS_HTML=$STATUS_HTML" 1>&2
    echo "$0: debug[3]: TOP_FILE=$TOP_FILE" 1>&2
fi

# validate JSON in status.json
#
"$JPARSE_TOOL" -q "$STATUS_JSON"
status="$?"
if [[ $status -ne 0 ]]; then
    echo  "$0: ERROR: status.json is not valid JSON, jparse error code: $status" 1>&2
    exit 1
fi

# obtain contest_status if CONTEST_STATUS was not set in the arg
#
# XXX - XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX - XXX
# XXX - GROSS HACK - GROSS HACK - GROSS HACK - GROSS HACK - GROSS HACK - GROSS HACK - GROSS HACK - XXX
# XXX - until we have the jnamval command, we must FAKE PARSE the author/author_handle.json file - XXX
# XXX - GROSS HACK - GROSS HACK - GROSS HACK - GROSS HACK - GROSS HACK - GROSS HACK - GROSS HACK - XXX
# XXX - XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX - XXX
#
if [[ -z $CONTEST_STATUS ]]; then

    # obtain the contest_status from status.json
    #
    CONTEST_STATUS=$(grep '"contest_status"[[:space:]]*:[[:space:]]*"' "$STATUS_JSON" |
		     sed -e 's/^.*:[[:space:]]*"//' -e 's/",*//')
    if [[ -z $CONTEST_STATUS ]]; then
	echo "$0: ERROR: cannot determine contest_status from status.json: $STATUS_JSON" 1>&2
	exit 1
    fi

    # validate and normalize the contest_status cfrom status.json
    #
    case "$CONTEST_STATUS" in
    p|pending) CONTEST_STATUS="pending"
	;;
    o|open) CONTEST_STATUS="open"
	;;
    j|judging) CONTEST_STATUS="judging"
	;;
    c|closed) CONTEST_STATUS="closed"
	;;
    *) echo "$0: ERROR: unexpected status from $status.json: $CONTEST_STATUS" 1>&2
	echo 1>&2
	echo "$USAGE" 1>&2
	exit 1
	;;
    esac
fi

# -N stops early before any processing is performed
#
if [[ -n $DO_NOT_PROCESS ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: arguments parsed, -N given, exiting 0" 1>&2
    fi
    exit 0
fi

# create a temporary status.json file
#
export TMP_STATUS_JSON=".$NAME.$$.entry.md"
if [[ $V_FLAG -ge 3 ]]; then
    echo  "$0: debug[3]: temporary status.json file: $TMP_STATUS_JSON" 1>&2
fi
if [[ -z $NOOP ]]; then
    trap 'rm -f $TMP_STATUS_JSON; exit' 0 1 2 3 15
    rm -f "$TMP_STATUS_JSON"
    if [[ -e $TMP_STATUS_JSON ]]; then
	echo "$0: ERROR: cannot remove temporary status.json file: $TMP_STATUS_JSON" 1>&2
	exit 10
    fi
    :> "$TMP_STATUS_JSON"
    if [[ ! -e $TMP_STATUS_JSON ]]; then
	echo "$0: ERROR: cannot create temporary status.json file: $TMP_STATUS_JSON" 1>&2
	exit 11
    fi
elif [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: because of -n, temporary status.json file is not used: $TMP_STATUS_JSON" 1>&2
fi

# generate the temporary status.json file
#
# In this stage, we use the date of the actual status.json file.
#
if [[ -z $NOOP ]]; then

    # generate a temporary status.json file based on current status, news.md and status.json
    #
    output_status_json "$CONTEST_STATUS" "$NEWS_MD" "$STATUS_JSON" > "$TMP_STATUS_JSON"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: failed to form temporary status.json file: $TMP_STATUS_JSON, error code: $status" 1>&2
        exit 12
    fi
    if [[ ! -s $TMP_STATUS_JSON ]]; then
	echo "$0: ERROR: failed to form temporary status.json, file missing or empty: $TMP_STATUS_JSON" 1>&2
        exit 13
    fi

    # check if temporary status.json file is different from the actual status.json file
    #
    if cmp -s "$STATUS_JSON" "$TMP_STATUS_JSON"; then

	# case: temporary status.json file is the same, nothing to do
	#
	if [[ $V_FLAG -ge 3 ]]; then
	    echo "$0: debug[3]: no change to status.json" 1>&2
	fi

    # case: temporary status.json file is different from the actual status.json
    #
    else

	# case: temporary status.json file needs to replace status.json
	#
	# We now must rebuild the temporary status.json file using the new modification time,
	# so we now touch the status.json file for a new modification time.
	touch -m "$STATUS_JSON"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: failed to touch -m $STATUS_JSON, error code: $status" 1>&2
	    exit 14
        fi
	#
	# Rebuild temporary status.json file with updated (touched) modification time
	#
	output_status_json "$CONTEST_STATUS" "$NEWS_MD" "$STATUS_JSON" > "$TMP_STATUS_JSON"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: failed to reform temporary status.json file: $TMP_STATUS_JSON, error code: $status" 1>&2
	    exit 15
	fi
	if [[ ! -s $TMP_STATUS_JSON ]]; then
	    echo "$0: ERROR: failed to reform temporary status.json, file missing or empty: $TMP_STATUS_JSON" 1>&2
	    exit 16
	fi
	#
	# touch the temporary status.json file to have the updated (touched) modification time
	#
	touch -m -r "$STATUS_JSON" "$TMP_STATUS_JSON"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: failed to touch -m -r $STATUS_JSON $TMP_STATUS_JSON, error code: $status" 1>&2
	    exit 17
        fi

	# move the temporary status.json file into place
	#
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: updating: $STATUS_JSON" 1>&2
	    mv -v -f "$TMP_STATUS_JSON" "$STATUS_JSON"
	    status="$?"
	    if [[ $status -ne 0 ]]; then
		echo "$0: ERROR: failed to mv -v -f $TMP_STATUS_JSON $STATUS_JSON, error code: $status" 1>&2
		exit 18
	    fi
	else
	    mv -f "$TMP_STATUS_JSON" "$STATUS_JSON"
	    status="$?"
	    if [[ $status -ne 0 ]]; then
		echo "$0: ERROR: failed to mv -f $TMP_STATUS_JSON $STATUS_JSON, error code: $status" 1>&2
		exit 19
	    fi
	fi
    fi

elif [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: because of -n, temporary status.json file is NOT written into: $TMP_STATUS_JSON" 1>&2
fi

# use the md2html.sh tool to form the status.html file, unless -n
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to run: $MD2HTML_SH ${TOOL_OPTION[*]} --" \
	     "status.md $STATUS_HTML" 1>&2
    fi
    "$MD2HTML_SH" "${TOOL_OPTION[@]}" -- \
      status.md "$STATUS_HTML"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: md2html.sh: $MD2HTML_SH ${TOOL_OPTION[*]} --" \
	     "status.md $STATUS_HTML" \
	     "failed, error: $status" 1>&2
	exit 20
    elif [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: now up to date: $STATUS_HTML" 1>&2
    fi

# report disabled by -n
#
elif [[ $V_FLAG -ge 5 ]]; then
    echo "$0: debug[5]: because of -n, did not run: $MD2HTML_SH ${TOOL_OPTION[*]} --" \
         "status.md $STATUS_HTML" 1>&2
fi

# file cleanup
#
if [[ -z $NOOP ]]; then
    rm -f -- "$TMP_STATUS_JSON"
elif [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: because of -n, disabled: rm -f -- $TMP_STATUS_JSON" 1>&2
fi

# All Done!!! -- Jessica Noll, Age 2
#
exit 0

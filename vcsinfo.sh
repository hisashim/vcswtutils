#!/bin/sh
# -*- coding: utf-8 -*-
#
# VCS working tree information inspector
# Copyright 2015 Hisashi Morita
# License: Public domain
#
# Usage: vcsinfo.sh [options] subcommand [dir]
#   subcommand:
#     branch    display branch
#     datetime  display date and time of the latest commit (in UTC)
#     log       display history
#     ls        display versioned files
#     rev       display revision
#   dir:
#     directory to inspect (default: .)
# Options:
#   --help    show help message
# Supported VCSs:
#   Git, Mercurial, Bazaar, and Subversion

set -e

APP=`basename $0`
APPVERSION=0.0.2
CMD="$1"

if [ "$2" ]; then
    WD="$2"
else
    WD="."
fi

if [ -t 1 ]; then
  ECHO='echo'
else
  ECHO='echo -n'
fi

which git    >/dev/null && GIT=TRUE
which hg     >/dev/null && HG=TRUE
which bzr    >/dev/null && BZR=TRUE
which svn    >/dev/null && SVN=TRUE
which svn2cl >/dev/null && SVN2CL=TRUE

case $CMD in
  branch)
    # Git
    if [ x"${GIT}" = xTRUE ]; then
      ((cd "${WD}" && git status --porcelain) >/dev/null 2>&1) && GIT_WD=TRUE
      if [ x"${GIT_WD}" = xTRUE ]; then
        [ ! "${BRANCH}" ] && BRANCH=`(cd ${WD}; git rev-parse --abbrev-ref HEAD)`
      fi
    fi
    # Mercurial
    if [ x"${HG}" = xTRUE ]; then
      ((cd "${WD}" && hg status) >/dev/null 2>&1) && HG_WD=TRUE
      if [ x"${HG_WD}" = xTRUE ]; then
        NB=`(cd ${WD}; hg branch)`
        BM=`(cd ${WD}; hg bookmarks | grep '^ \* ' \
            | sed 's/^ \* \([^ ]*\) *[^ ]*$/\1/g')`
        [ ! "${BRANCH}" ] && BRANCH=`(cd ${WD}; \
            [ ! ${BM} ] && echo ${NB} || echo ${NB}-${BM})`
      fi
    fi
    # Bazaar
    if [ x"${BZR}" = xTRUE ]; then
      bzr heads --help >/dev/null; [ x"$?" = x0 ] && BZR_HEADS=TRUE
      if [ x"${BZR_HEADS}" = xTRUE ] ; then
        (bzr status "${WD}" >/dev/null 2>&1) && BZR_WD=TRUE
        if [ x"${BZR_WD}" = xTRUE ]; then
          [ ! "${BRANCH}" ] && BRANCH=`(cd ${WD}; bzr heads \
              | grep '^ *branch nick: ' | sed 's/^ *branch nick: \(.*\)$/\1/g')`
        fi
      fi
    fi
    # Subversion
    if [ x"${SVN}" = xTRUE ]; then
      (svn info "${WD}" >/dev/null 2>&1) && SVN_WD=TRUE
      if [ x"${SVN_WD}" = xTRUE ]; then
        [ ! "${BRANCH}" ] && BRANCH=`cd ${WD}; \
            svn info | grep '^URL' | xargs -I{} basename {}`
      fi
    fi
    [ ! "${BRANCH}" ] && BRANCH=unknown
    $ECHO "${BRANCH}"
    ;;
  datetime)
    format=+%Y-%m-%dT%H:%M:%SZ
    normalize="xargs -I{} date -u --date {} ${format}"
    # Git
    if [ x"${GIT}" = xTRUE ]; then
      ((cd "${WD}" && git status --porcelain) >/dev/null 2>&1) && GIT_WD=TRUE
      if [ x"${GIT_WD}" = xTRUE ]; then
        [ ! "${DATETIME}" ] && DATETIME=`cd ${WD}; \
          git log -n 1 --format='%ci' | ${normalize}`
      fi
    fi
    # Mercurial
    if [ x"${HG}" = xTRUE ]; then
      ((cd "${WD}" && hg status) >/dev/null 2>&1) && HG_WD=TRUE
      if [ x"${HG_WD}" = xTRUE ]; then
        [ ! "${DATETIME}" ] && DATETIME=`cd ${WD}; \
          hg log -r tip -T xml | grep '<date>' \
          | sed 's/<date>\(.*\)<\/date>/\1/' | ${normalize}`
      fi
    fi
    # Bazaar
    if [ x"${BZR}" = xTRUE ]; then
      bzr heads --help >/dev/null; [ x"$?" = x0 ] && BZR_HEADS=TRUE
      if [ x"${BZR_HEADS}" = xTRUE ] ; then
        (bzr status "${WD}" >/dev/null 2>&1) && BZR_WD=TRUE
        if [ x"${BZR_WD}" = xTRUE ]; then
          [ ! "${DATETIME}" ] && DATETIME=`cd ${WD}; \
            bzr log -r-1 | grep 'timestamp' \
            | sed 's/^timestamp: //' | ${normalize}`
        fi
      fi
    fi
    # Subversion
    if [ x"${SVN}" = xTRUE ]; then
      (svn info "${WD}" >/dev/null 2>&1) && SVN_WD=TRUE
      if [ x"${SVN_WD}" = xTRUE ]; then
        [ ! "${DATETIME}" ] && DATETIME=`cd ${WD}; \
          svn info --xml | grep '<date>' \
          | sed 's/<date>\(.*\)<\/date>/\1/' | ${normalize}`
      fi
    fi
    [ ! "${DATETIME}" ] && DATETIME=unknown
    $ECHO "${DATETIME}"
    ;;
  log)
    # Git
    if [ x"${GIT}" = xTRUE ]; then
      ((cd "${WD}" && git status --porcelain) >/dev/null 2>&1) && GIT_WD=TRUE
      if [ x"${GIT_WD}" = xTRUE ]; then
        [ ! "${LOG}" ] && \
          LOG=`cd "${WD}"; git --no-pager log --format="%ai %aN %n%n%x09* %s%n"`
      fi
    fi
    # Mercurial
    if [ x"${HG}" = xTRUE ]; then
      ((cd "${WD}" && hg status) >/dev/null 2>&1) && HG_WD=TRUE
      if [ x"${HG_WD}" = xTRUE ]; then
        [ ! "${LOG}" ] && LOG=`cd "${WD}"; hg log --style changelog`
      fi
    fi
    # Bazaar
    if [ x"${BZR}" = xTRUE ]; then
      (bzr status "${WD}" >/dev/null 2>&1) && BZR_WD=TRUE
      if [ x"${BZR_WD}" = xTRUE ]; then
        [ ! "${LOG}" ] && LOG=`cd "${WD}"; bzr log --gnu-changelog`
      fi
    fi
    # Subversion
    if [ x"${SVN}" = xTRUE ]; then
      (svn info "${WD}" >/dev/null 2>&1) && SVN_WD=TRUE
      if [ x"${SVN_WD}" = xTRUE ]; then
        if [ x"${SVN2CL}" = xTRUE ]; then
          [ ! "${LOG}" ] && LOG=`cd "${WD}"; svn2cl --stdout --include-rev`
        else
          [ ! "${LOG}" ] && LOG=`cd "${WD}"; svn log -rBASE:0 -v`
        fi
      fi
    fi
    $ECHO "${LOG}"
    ;;
  ls)
    # Git
    if [ x"${GIT}" = xTRUE ]; then
      ((cd "${WD}" && git status --porcelain) >/dev/null 2>&1) && GIT_WD=TRUE
      if [ x"${GIT_WD}" = xTRUE ]; then
        [ ! "${FILES}" ] && FILES=`cd "${WD}" && git ls-files | sort`
      fi
    fi
    # Mercurial
    if [ x"${HG}" = xTRUE ]; then
      ((cd "${WD}" && hg status) >/dev/null 2>&1) && HG_WD=TRUE
      if [ x"${HG_WD}" = xTRUE ]; then
        [ ! "${FILES}" ] && \
          FILES=`cd "${WD}" && hg status --all | grep -v '^?' | cut -c3- | sort`
      fi
    fi
    # Bazaar
    if [ x"${BZR}" = xTRUE ]; then
      (bzr status "${WD}" >/dev/null 2>&1) && BZR_WD=TRUE
      if [ x"${BZR_WD}" = xTRUE ]; then
        [ ! "${FILES}" ] && \
          FILES=`cd "${WD}" \
                 && (bzr ls --versioned --recursive --kind file; \
                     bzr ls --versioned --recursive --kind symlink) | sort`
      fi
    fi
    # Subversion
    if [ x"${SVN}" = xTRUE ]; then
      (svn info "${WD}" >/dev/null 2>&1) && SVN_WD=TRUE
      if [ x"${SVN_WD}" = xTRUE ]; then
        [ ! "${FILES}" ] && \
          FILES=`cd "${WD}" && svn status --non-interactive -v . \
                 | grep -v '^?' | cut -c10- | awk '{ print \$4 }' \
                 | xargs -n 1 -I{} find {} -maxdepth 0 ! -type d | sort`
      fi
    fi
    $ECHO "${FILES}"
    ;;
  rev)
    # Git
    if [ x"${GIT}" = xTRUE ]; then
      ((cd "${WD}" && git status --porcelain) >/dev/null 2>&1) && GIT_WD=TRUE
      if [ x"${GIT_WD}" = xTRUE ]; then
        HASH=` (cd "${WD}" && git describe --all --long) | \
                sed "s/^.*-g\([0-9a-z]\+\)$/\1/g"`
        IFMOD=`(cd "${WD}" && git diff-index --quiet HEAD || echo -n 'M')`
        [ ! "${REV}" ] && REV=${HASH}${IFMOD}
      fi
    fi
    # Mercurial
    if [ x"${HG}" = xTRUE ]; then
      ((cd "${WD}" && hg status) >/dev/null 2>&1) && HG_WD=TRUE
      if [ x"${HG_WD}" = xTRUE ]; then
        [ ! "${REV}" ] && REV=`hg identify --id "${WD}" | sed "s/+/M/g"`
      fi
    fi
    # Bazaar
    if [ x"${BZR}" = xTRUE ]; then
      (bzr status "${WD}" >/dev/null 2>&1) && BZR_WD=TRUE
      if [ x"${BZR_WD}" = xTRUE ]; then
        REVNO=`bzr revno "${WD}"`
        IFMOD=`bzr status --versioned "${WD}" \
               | grep -q "^[a-z]*:" && echo -n "M"; true`
        [ ! "${REV}" ] && REV=${REVNO}${IFMOD}
      fi
    fi
    # Subversion
    if [ x"${SVN}" = xTRUE ]; then
      (svn info "${WD}" >/dev/null 2>&1) && SVN_WD=TRUE
      if [ x"${SVN_WD}" = xTRUE ]; then
        [ ! "${REV}" ] && REV=`svnversion "${WD}" | sed "s/:/-/g"`
      fi
    fi
    [ ! "${REV}" ] && REV=unknown
    $ECHO "${REV}"
    ;;
  --help|-h|'')
    HELP="$APP: VCS working tree information inspector

Usage: $APP [options] subcommand [dir]

  subcommand:
        branch    display branch
        datetime  display date and time of the latest commit (in UTC)
        log       display log
        ls        display versioned files
        rev       display revision

  dir:
        directory to inspect (default: .)

Options:
        --help                       show help message
        --version                    show version

Examples:
        $APP branch            #=> master
        $APP datetime          #=> 2000-12-31T23:59:59Z
        $APP log > ChangeLog
        $APP ls  > MANIFEST
        $APP rev               #=> abc123, abc123M, etc.

Supported VCSs:
        Git, Mercurial, Bazaar, and Subversion"
    $ECHO "${HELP}"
    exit 0
    ;;
  --version)
    echo $APPVERSION
    exit 0
    ;;
  *)
    ERROR="$APP: $CMD: unknown subcommand or option
  Type \`$APP --help' for usage"
    $ECHO "${ERROR}"
    exit 1
    ;;
esac

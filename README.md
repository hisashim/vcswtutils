VCSInfo: VCS working tree information inspector
==========

A utility to obtain information on version control systems working
trees.

Usage
--------

### Synopsis

    vcsinfo [options] subcommand [dir]

### Arguments

  * subcommand:
    - branch: display branch
    - log: display history
    - ls: display versioned files
    - rev: display revision

  * dir: directory to inspect (default: .)

  * options:
    - --help: show help message

### Examples

    $ vcsinfo branch            #=> master
    $ vcsinfo log > ChangeLog
    $ vcsinfo ls  > MANIFEST
    $ vcsinfo rev               #=> abc123, abc123M, etc.

Installation
--------

No installation required. Just copy it to anywhere you like.

    $ cp vcsinfo.rb vcsinfo
    $ chmod +x vcsinfo

Notes
--------

### Supported VCSs

  * Git, Mercurial, Bazaar, and Subversion.

### Files

  * vcsinfo.rb: Ruby version
  * vcsinfo.sh: shell script version

Copyright
--------

Copyright 2012 Hisashi Morita.

License
--------

Public domain.

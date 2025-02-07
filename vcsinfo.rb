#!/usr/bin/ruby
# -*- coding: utf-8 -*-
#
# VCS working tree information inspector
# Copyright 2012 Hisashi Morita
# License: Public Domain
#
# Usage: vcsinfo.rb [options] subcommand [dir]
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

require 'shellwords'

module VCSInfo
  VERSION = "0.0.2"
  class << self
    def cmd_exist?(cmd)
      `which #{cmd.shellescape} >/dev/null`
      Process.last_status.success?
    end

    def wt?(dir, vcs)
      ds = dir.shellescape
      case vcs
      when 'git' then e=`(cd #{ds} && git status --porcelain) 2>&1 >/dev/null`
      when 'hg'  then e=`(cd #{ds} && hg status) 2>&1 >/dev/null`
      when 'bzr' then e=`bzr status #{ds} 2>&1 >/dev/null`
      when 'svn' then e=`svn info #{ds} 2>&1 >/dev/null`
        # ignore SVN_ERR_WC_NOT_WORKING_COPY and warn otherwise
        unless /svn: (?:E155007)|(?:.*? is not a working copy)/m.match(e)
          $stderr.print(e)
        end
      else
        return false
      end
      Process.last_status.success?
    end

    def guess_vcs(dir)
      case
      when (cmd_exist? 'git' and wt?(dir, 'git')) then :git
      when (cmd_exist? 'hg'  and wt?(dir, 'hg'))  then :hg
      when (cmd_exist? 'bzr' and wt?(dir, 'bzr')) then :bzr
      when (cmd_exist? 'svn' and wt?(dir, 'svn')) then :svn
      else
        nil
      end
    end

    def branch(dir)
      ds = dir.shellescape
      case guess_vcs(dir)
      when :git
        `cd #{ds}; git rev-parse --abbrev-ref HEAD`.chomp
      when :hg
        named_branch = `cd #{ds}; hg branch`.chomp
        bookmark = `cd #{ds}; hg bookmarks | grep '^ \* '`.
          gsub(/^ \* ([^ ]+?) +?[^ ]*?$/, '\1').chomp
        [named_branch, bookmark].delete_if { |e| e.empty? }.join('-')
      when :bzr
        nick = `cd #{ds}; bzr heads | grep '^ *branch nick: '`.
            gsub(/^ *branch nick: ([^ ]+)$/, '\1').chomp
        nick
      when :svn
        `svn info #{ds} | grep '^URL' | xargs -I{} basename {}`.chomp
      else
        'unknown'
      end
    end

    def datetime(dir, format = '+%Y-%m-%dT%H:%M:%SZ')
      ds = dir.shellescape
      normalize = " | xargs -I{} date -u --date {} '#{format}'"
      cmd =
        case guess_vcs(dir)
        when :git
          "cd #{ds}; git log -n 1 --format='%ci'" + normalize
        when :hg
          "cd #{ds}; hg log -r tip -T xml | grep '<date>'" +
          " | sed 's/<date>\\(.*\\)<\\/date>/\\1/'" + normalize
        when :bzr
          "cd #{ds}; bzr log -r-1 | grep 'timestamp'" +
          " | sed 's/^timestamp: //'" + normalize
        when :svn
          "svn info --xml #{ds} | grep '<date>'" +
          " | sed 's/<date>\\(.*\\)<\\/date>/\\1/'" + normalize
        else
          return 'unknown'
        end
      `#{cmd}`.chomp
    end

    def log(dir)
      ds = dir.shellescape
      case guess_vcs(dir)
      when :git then `cd #{ds}; git --no-pager log \
                      --format=\"%ai %aN %n%n%x09* %s%n\"`
      when :hg  then `cd #{ds}; hg log --style changelog`
      when :bzr then `cd #{ds}; bzr log --gnu-changelog`
      when :svn then
        if cmd_exist? 'svn2cl' then `cd #{ds}; svn2cl --stdout --include-rev`
        else                        `cd #{ds}; svn log -rBASE:0 -v`
        end
      else
        nil
      end
    end

    def ls(dir)
      ds = dir.shellescape
      case guess_vcs(dir)
      when :git
        `cd #{ds} && git ls-files | sort`
      when :hg
        `cd #{ds} && hg status --all \
         | grep -v '^?' | cut -c3- | sort`
      when :bzr
        `cd #{ds} && \
         (bzr ls --versioned --recursive --kind file; \
          bzr ls --versioned --recursive --kind symlink) \
         | sort`
      when :svn
        `cd #{ds} && svn status --non-interactive -v . \
         | grep -v '^?' | cut -c10- | awk '{ print \$4 }' \
         | xargs -n 1 -I{} find {} -maxdepth 0 ! -type d \
         | sort`
      else
        nil
      end
    end

    def rev(dir)
      ds = dir.shellescape
      case guess_vcs(dir)
      when :git
        rev_id = `(cd #{ds} && git describe --all --long)`.
                 chomp.gsub(/\A.*?-g([0-9a-z]+).*\Z/, '\1')
        ifmod  = `(cd "${WD}" && git diff-index --quiet HEAD || echo -n 'M')`
        rev_id + ifmod
      when :hg
        `hg identify --id #{ds}`.chomp.gsub(/\+/, 'M')
      when :bzr
        rev_id = `bzr revno #{ds}`.chomp
        ifmod  = `bzr status --versioned #{ds}`.scan(/^\w+:/).empty? ? '' : 'M'
        rev_id + ifmod
      when :svn
        `svnversion #{ds}`.chomp.gsub(/:/, '-')
      else
        'unknown'
      end
    end
  end

  module CLI
    def self.called_as_an_application?
      $PROGRAM_NAME == __FILE__
    end

    def self.run
      require 'optparse'

      default_config = {
        :test => false
      }

      appfname = File.basename(__FILE__)
      clo = command_line_options = {}
      ARGV.options {|o|
        o.banner =<<-EOS.gsub(/^ {6}/, '')
          #{appfname}: VCS working tree information inspector

          Usage: #{appfname} [options] subcommand [dir]...

            subcommand:
                  branch    display branch
                  datetime  display date and time of the latest commit (in UTC)
                  log       display log
                  ls        display versioned files
                  rev       display revision

            dir:
                  directory to inspect (default: .)

          Options:
          EOS
        o.def_option('--help', 'show help message'){|s| puts o; exit}
        o.on_tail <<-EOS.gsub(/^ {6}/, '')

          Examples:
                  #{appfname} branch            #=> master
                  #{appfname} datetime          #=> 2000-12-31T23:59:59Z
                  #{appfname} log > ChangeLog
                  #{appfname} ls  > MANIFEST
                  #{appfname} rev               #=> abc123, abc123M, etc.

          Supported VCSs:
                  Git, Mercurial, Bazaar, and Subversion
          EOS
        o.parse!
      } or exit(1)

      if ARGV.empty?
        $stderr.print "#{appfname}: subcommand required\n"
        $stderr.print ARGV.options
        exit 1
      else
        unless [:branch, :datetime, :log, :ls, :rev].include?(ARGV.first.intern)
          $stderr.print "#{appfname}: #{ARGV.first}: unsupported subcommand\n"
          $stderr.print ARGV.options
          exit 1
        else
          clo[:subcmd] = ARGV.first.intern
        end
      end
      if ARGV.size < 2
        clo[:workdirs] = ['.']
      else
        clo[:workdirs] = ARGV[1..-1]
      end

      config = default_config.update(clo)

      result = config[:workdirs].map{|wd|
        out = VCSInfo.send(config[:subcmd], wd)
        out ? out.chomp : nil
      }
      print result.join("\n")
      print "\n" if $stdout.tty?
    end
  end
end

if VCSInfo::CLI.called_as_an_application?
  VCSInfo::CLI.run
end

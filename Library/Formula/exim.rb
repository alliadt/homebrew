require 'formula'

class Exim < Formula
  homepage 'http://exim.org'
  url 'http://ftp.exim.org/pub/exim/exim4/exim-4.85.tar.bz2'
  mirror 'http://www.mirrorservice.org/sites/ftp.exim.org/pub/exim/exim4/exim-4.85.tar.bz2'
  sha1 '6b40d5a6ae59f86b4780ad50aaf0d930330d7b67'

  bottle do
    revision 1
    sha256 "78e5eb89f3b324114f453d64f9a6955f60abe8fcde2e0c32acc19649e1cdbacb" => :yosemite
    sha256 "beae28cb7ca235377eeb0bc04218154a2a0c29ec2942fbae52ac67f321e99b41" => :mavericks
    sha256 "28f88bffa0447b615552d5a80c31ff8a762afd801a803429cf015af00aafae8b" => :mountain_lion
  end

  option 'support-maildir', 'Support delivery in Maildir format'

  depends_on 'pcre'
  depends_on 'berkeley-db4'
  depends_on 'openssl'

  def install
    cp 'src/EDITME', 'Local/Makefile'
    inreplace 'Local/Makefile' do |s|
      s.remove_make_var! "EXIM_MONITOR"
      s.change_make_var! "EXIM_USER", ENV['USER']
      s.change_make_var! "SYSTEM_ALIASES_FILE", etc/'aliases'
      s.gsub! '/usr/exim/configure', etc/'exim.conf'
      s.gsub! '/usr/exim', prefix
      s.gsub! '/var/spool/exim', var/'spool/exim'
      # http://trac.macports.org/ticket/38654
      s.gsub! 'TMPDIR="/tmp"', 'TMPDIR=/tmp'
      s << "SUPPORT_MAILDIR=yes\n" if build.include? 'support-maildir'
      s << "AUTH_PLAINTEXT=yes\n"
      s << "SUPPORT_TLS=yes\n"
      s << "TLS_LIBS=-lssl -lcrypto\n"
      s << "TRANSPORT_LMTP=yes\n"

      # For non-/usr/local HOMEBREW_PREFIX
      s << "LOOKUP_INCLUDE=-I#{HOMEBREW_PREFIX}/include\n"
      s << "LOOKUP_LIBS=-L#{HOMEBREW_PREFIX}/lib\n"
    end

    bdb4 = Formula["berkeley-db4"]

    inreplace 'OS/Makefile-Darwin' do |s|
      s.remove_make_var! %w{CC CFLAGS}
      # Add include and lib paths for BDB 4
      s.gsub! "# Exim: OS-specific make file for Darwin (Mac OS X).", "INCLUDE=-I#{bdb4.include}"
      s.gsub! "DBMLIB =", "DBMLIB=#{bdb4.lib}/libdb-4.dylib"
    end

    # The compile script ignores CPPFLAGS
    ENV.append 'CFLAGS', ENV.cppflags

    ENV.j1 # See: https://lists.exim.org/lurker/thread/20111109.083524.87c96d9b.en.html
    system "make"
    system "make INSTALL_ARG=-no_chown install"
    man8.install 'doc/exim.8'
    (bin+'exim_ctl').write startup_script
  end

  # Inspired by MacPorts startup script. Fixes restart issue due to missing setuid.
  def startup_script; <<-EOS.undent
    #!/bin/sh
    PID=#{var}/spool/exim/exim-daemon.pid
    case "$1" in
    start)
      echo "starting exim mail transfer agent"
      #{bin}/exim -bd -q30m
      ;;
    restart)
      echo "restarting exim mail transfer agent"
      /bin/kill -15 `/bin/cat $PID` && sleep 1 && #{bin}/exim -bd -q30m
      ;;
    stop)
      echo "stopping exim mail transfer agent"
      /bin/kill -15 `/bin/cat $PID`
      ;;
    *)
      echo "Usage: #{bin}/exim_ctl {start|stop|restart}"
      exit 1
      ;;
    esac
    EOS
  end

  def caveats; <<-EOS.undent
    Start with:
      exim_ctl start
    Don't forget to run it as root to be able to bind port 25.
    EOS
  end
end

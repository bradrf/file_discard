# The MIT License (MIT)
#
# Copyright (c) 2014 Brad Robel-Forrest
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'pathname'
require 'fileutils'

module FileDiscard

  VERSION = '0.0.1'

  ######################################################################
  # Module Methods

  def self.mix_it_in!
    [File, Pathname].each do |c|
      c.class_eval do
        def self.discard(*args)
          FileDiscard.discarder.discard(*args)
        end
        def discard(options = {})
          FileDiscard.discarder.discard(self, options)
        end
      end
    end
    self
  end

  def self.discard(*args)
    discarder.discard(*args)
  end

  def self.discarder=(discarder)
    @@discarder = discarder
  end

  def self.discarder
    @@discarder ||= case RUBY_PLATFORM
                    when /darwin/i then OsxDiscarder.new
                    when /linux/i then LinuxDiscarder.new
                    else
                      raise NotImplementedError
                        .new("Unsupported platform: #{RUBY_PLATFORM}")
                    end
  end

  ######################################################################
  # Discarders

  class Discarder
    def initialize(home_trash, mountpoint_trash_fmt)
      home = Pathname.new('~').expand_path
      @home_trash = home.join(home_trash)
      @home_mountpoint = mountpoint_of home
      @mountpoint_trash_fmt = mountpoint_trash_fmt
    end

    def discard(obj, move_options = {})
      pn = pathname_for obj
      trash = find_trash_for pn
      raise Errno::ENOENT.new(trash.to_s) unless trash.exist?
      dst = uniquify(trash.join(pn.basename))
      FileUtils.mv pn.expand_path, dst, move_options
    end

    private
      def mountpoint_of(pn)
        pn = pn.parent until pn.mountpoint?
        pn
      end

      def find_trash_for(pn)
        pd = pn.expand_path.realpath.dirname
        mp = mountpoint_of pd
        return @home_trash if mp == @home_mountpoint
        mp.join(@mountpoint_trash_fmt % Process.uid)
      end

      def pathname_for(obj)
        if obj.is_a? Pathname
          obj
        elsif obj.respond_to? :to_path
          Pathname.new(obj.to_path)
        else
          Pathname.new(obj)
        end
      end

      def uniquify(pn)
        return pn unless pn.exist?

        ext  = pn.extname
        base = pn.basename(ext).to_s
        dn   = pn.dirname

        count = 0
        fmt = bfmt = '%H.%M.%S'

        loop do
          ts = Time.now.strftime(fmt)
          pn = dn.join("#{base} #{ts}#{ext}")
          return pn unless pn.exist?
          fmt = bfmt + ".%#{count}N" # use fractional seconds, with increasing precision
          count += 1
        end
      end
  end # class Discarder

  class OsxDiscarder < Discarder
    def initialize
      super '.Trash', '.Trashes/%s'
    end
  end

  class LinuxDiscarder < Discarder
    def initialize
      super '.local/share/Trash', '.Trash-%s'
    end
  end

end # module FileDiscard

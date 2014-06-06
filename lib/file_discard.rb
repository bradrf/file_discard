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

  load "#{File.dirname(__FILE__)}/file_discard_version.rb"

  ######################################################################
  # Module Methods

  def self.mix_it_in!
    [File, Pathname].each do |klass|
      klass.class_eval do
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
    SPECIAL_DIRS = ['.','..']

    def initialize(home, home_trash, mountpoint_trash_fmt)
      home = pathname_for(home).expand_path
      @home_trash = home.join(home_trash)
      @home_mountpoint = mountpoint_of home
      @mountpoint_trash_fmt = mountpoint_trash_fmt
    end

    def discard(obj, move_options = {})
      pn = pathname_for obj
      if SPECIAL_DIRS.include?(pn.basename.to_s)
        raise Errno::EINVAL.new(SPECIAL_DIRS.join(' and ') << ' may not be removed')
      end
      trash = find_trash_for pn
      raise Errno::ENOENT.new(trash.to_s) unless trash.exist?
      move(pn, trash, move_options)
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

      def move(src, dst, options)
        src = src.expand_path
        dst = uniquify(dst.join(src.basename))
        FileUtils.mv src, dst, options
        yield src, dst if block_given?
      end

      def uniquify(pn)
        return pn unless pn.exist?

        dn   = pn.dirname
        ext  = pn.extname
        base = pn.basename(ext).to_s

        fmt = bfmt = '%H.%M.%S'

        10.times do |i|
          ts = Time.now.strftime(fmt)
          pn = dn.join("#{base} #{ts}#{ext}")
          return pn unless pn.exist?
          fmt = bfmt + ".%#{i}N" # use fractional seconds, with increasing precision
        end

        raise RuntimeError.new(%{Unable to uniquify "#{base}" (last attempt: #{pn})})
      end
  end # class Discarder

  class OsxDiscarder < Discarder
    def initialize(home = '~')
      super home, '.Trash', '.Trashes/%s'
    end
  end

  class LinuxDiscarder < Discarder
    def initialize(home = '~')
      super home, '.local/share/Trash/files', '.Trash-%s/files'
    end

    # Linux has a special layout for the trash folder and tracking for restore.
    # See http://www.freedesktop.org/wiki/Specifications/trash-spec/
    private
      def move(*args)
        super do |src, dst|
          dst.dirname.dirname.join('info',"#{dst.basename}.trashinfo").open('w') do |io|
            io.write <<EOF
[Trash Info]
Path=#{src}
DeletionDate=#{Time.now.strftime('%Y-%m-%dT%H:%M:%S')}
EOF
          end
        end
      end
  end

end # module FileDiscard

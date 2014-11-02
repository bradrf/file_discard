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

  # Extend Ruby's +File+ and +Pathname+ classes with Discarder.discard methods.
  def self.mix_it_in!
    [File, Pathname].each do |klass|
      klass.class_eval do
        # :nodoc:
        def self.discard(*args)
          FileDiscard.discarder.discard(*args)
        end
        # :nodoc:
        def discard(options = {})
          FileDiscard.discarder.discard(self, options)
        end
      end
    end
    self
  end

  # See Discarder.discard for usage.
  def self.discard(*args)
    discarder.discard(*args)
  end

  # Set the default discarder to use.
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

  @@create_trash_when_missing = false

  # Enable or disable the automatic creation of trash directories if they do not exist. The default
  # is to raise a TrashMissing exception).
  def self.create_trash_when_missing=(value)
    @@create_trash_when_missing = value
  end

  def self.create_trash_when_missing
    @@create_trash_when_missing
  end

  ######################################################################
  # Discarders

  # Raised when the configured trash directory for a given mountpoint does not exist.
  class TrashMissing < Errno::ENOENT; end;

  # The core logic for moving files to an appropriate trash directory.
  class Discarder
    SPECIAL_DIRS = ['.','..'] # :nodoc:

    def initialize(home, home_trash, mountpoint_trash_fmt)
      home = pathname_for(home).expand_path
      @home_trash = home.join(home_trash)
      @home_mountpoint = mountpoint_of home
      @mountpoint_trash_fmt = mountpoint_trash_fmt
    end

    # Request that +obj+ be moved to the trash.
    #
    # +options+ - a hash of any of the following:
    # * :directory - allow an empty directory to be discarded
    # * :recursive - allow a directory to be discarded even if not empty
    # * :verbose - report the move operation
    #
    # May raise:
    # * Errno::EINVAL - +obj+ is "." or ".." which are not allowed to be discarded
    # * Errno::EISDIR - +obj+ is a directory
    # * Errno::ENOTEMPTY - +obj+ is a directory with children
    # * Errno::ENOENT - +obj+ does not exist on the file system
    # * TrashMissing - the trash directory for the mountpoint associated with +obj+ did not exist
    #
    def discard(obj, options = {})
      pn = pathname_for obj
      if pn.directory?
        SPECIAL_DIRS.include?(pn.basename.to_s) and
          raise Errno::EINVAL.new(SPECIAL_DIRS.join(' and ') << ' may not be removed')
        unless options[:recursive]
          options[:directory] or raise Errno::EISDIR.new(pn.to_s)
          pn.children.any? and raise Errno::ENOTEMPTY.new(pn.to_s)
        end
      end

      if options.key?(:force) && options[:force] > 1
        $stderr.puts "Warning: Permanently removing #{pn}"
        FileUtils.rm_rf(pn, {verbose: options[:verbose] || false})
        return
      end

      trash = find_trash_for pn
      unless trash.exist?
        FileDiscard.create_trash_when_missing or raise TrashMissing.new(trash.to_s)
        trash.mkpath
      end

      move_options = options.has_key?(:verbose) ? {verbose: options[:verbose]} : {}
      move(pn, trash, move_options)
    end

    private
      def mountpoint_of(pn)
        pn = pn.parent until pn.mountpoint?
        pn
      end

      def find_trash_for(pn)
        pn_path = pn.expand_path
        if pn_path.symlink?
          # Use the containing directory's real path for symbolic links, not the target of the link
          pd = pn_path.dirname.realpath
        else
          pd = pn_path.realpath.dirname
        end
        mp = mountpoint_of(pd)
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
        options[:verbose] and puts "#{src} => #{dst}"
        File.rename(src, dst)
        block_given? and yield(src, dst)
      end

      def uniquify(pn)
        pn.exist? or return pn

        dn   = pn.dirname
        ext  = pn.extname
        base = pn.basename(ext).to_s

        fmt = bfmt = '%H.%M.%S'

        10.times do |i|
          ts = Time.now.strftime(fmt)
          pn = dn.join("#{base} #{ts}#{ext}")
          pn.exist? or return pn
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
          infodir = dst.dirname.dirname.join('info')
          infodir.directory? or infodir.mkpath
          infodir.join("#{dst.basename}.trashinfo").open('w') do |io|
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

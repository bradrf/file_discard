FileDiscard is a simple helper to make it easy for applications to move files to the correct trash folder. The location is determined by the platform and what file is being discarded (the latter is important so that files on other volumes/mountpoints are moved in to the appropriate trash folder).

## Getting Started

### Installation

```shell
> gem install file_discard
```

[![Gem Version](https://badge.fury.io/rb/file_discard.svg)](http://badge.fury.io/rb/file_discard)

### Using the Executable

Part of the `file_discard` gem is an executable that can be used as a drop-in replacement for "rm":

```shell
> discard
Usage: discard [options] file ...
    -d, --dir                        allow empty directories to be discarded
    -r                               allow directories to be discarded recursively
    -R, --recursive                  allow directories to be discarded recursively
    -v, --verbose                    show where files are discarded
    -h, --help                       show this message
        --version                    show version

Options ignored to provide compatibility with "rm":
    -f
    -i
    -I
```

### Using the Library

There are two ways for making discard requests. The easiest method extends Ruby's [`File`](http://www.ruby-doc.org/core/File.html) and [`Pathname`](http://www.ruby-doc.org/stdlib/libdoc/pathname/rdoc/Pathname.html) classes to use the new `discard` method instead of `unlink`:

```ruby
require 'file_discard'

FileDiscard.mix_it_in!

# open a file and discard it from the instance object...
f = File.open 'file1.txt', 'w'
f.puts 'one'
f.close
f.discard

# create a pathname and discard it from the instance object...
p = Pathname.new 'file2.txt'
p.open('w') {|io| io.puts 'two'}
p.discard

# open a file and discard it using the class...
f = File.open 'file3.txt', 'w'
f.puts 'three'
f.close
File.discard 'file3.txt'

# create a pathname and discard it using the class...
p = Pathname.new 'file4.txt'
p.open('w') {|io| io.puts 'four'}
Pathname.discard 'file4.txt'
```

Another approach is to leave Ruby's [`File`](http://www.ruby-doc.org/core/File.html) and [`Pathname`](http://www.ruby-doc.org/stdlib/libdoc/pathname/rdoc/Pathname.html) classes alone and work directly with FileDiscard:

```ruby
require 'file_discard'

# open a file and discard it...
f = File.open 'file5.txt', 'w'
f.puts 'five'
f.close
FileDiscard.discard 'file5.txt'

# create a pathname and discard it...
p = Pathname.new 'file6.txt'
p.open('w') {|io| io.puts 'six'}
FileDiscard.discard 'file6.txt'
```

#### More Options

A call to discard can enable a report of the operation that is taking place:

```ruby
require 'file_discard'

FileDiscard.mix_it_in!

# open a file and discard it from the instance object...
f = File.open 'file7.txt', 'w'
f.puts 'seven'
f.close
f.discard verbose:true
# ===> mv /path/to/file7.txt /Users/brad/.Trash/file7.txt

# create a pathname and discard it using the class...
p = Pathname.new 'file8.txt'
p.open('w') {|io| io.puts 'eight'}
Pathname.discard 'file8.txt', verbose:true
# ===> mv /path/to/file8.txt /Users/brad/.Trash/file8.txt
```

Other options can be enabled to allow discarding empty directories (:directory) or directories with items in them (:recursive).

Also of note is that FileDiscard will not blindly stomp on existing files already present in the trash. Instead, much like OS X's Finder, FileDiscard creates new file names based on the time when a collision occurs:

```ruby
require 'file_discard'

FileDiscard.mix_it_in!

# open a file and discard it from the instance object...
f = File.open 'samename.txt', 'w'
f.puts 'samename'
f.close
f.discard verbose:true
# ===> mv /path/to/samename.txt /Users/brad/.Trash/samename.txt

# create a pathname and discard it using the class...
p = Pathname.new 'samename.txt'
p.open('w') {|io| io.puts 'samename'}
Pathname.discard 'samename.txt', verbose:true
# ===> mv /path/to/samename.txt /Users/brad/.Trash/samename 17.49.44.txt
```

#### Exceptions

The most common exception raised will be if a discard request is made for a file that does not exist:

```ruby
require 'file_discard'

FileDiscard.mix_it_in!

p = Pathname.new 'missing1.txt'
p.discard
# ===> Errno::ENOENT: No such file or directory @ realpath_rec - /path/to/missing1.txt
```

## Creating New Discarders

If the built-in trash support isn't working for your platform, creating one is quite simple:

```ruby
require 'file_discard'

FileDiscard.mix_it_in!

class MyDiscarder < FileDiscard::Discarder
  def initialize(home = '/path/to/my/home')
    super home, 'a/trash/folder', '.place-for-mounted-trash-%s'
  end
end

FileDiscard.discarder = MyDiscarder.new

p = Pathname.new 'myfile.txt'
p.open('w') {|io| io.puts 'myfile'}
p.discard 'myfile.txt'

Pathname.new('/path/to/my/home/a/trash/folder').children
# ===> [#<Pathname:/path/to/my/home/a/trash/folder/myfile.txt>]
```

Each FileDiscard::Discarder is expected to provide the following (as passed to FileDiscard::Discarder.new):

1. `home`: An _absolute_ path to the home directory of the current user. FileDiscard will expand the path, so on systems that support it, special variables can be used (e.g. a tilde (~) will expand to the current user's home directory on OS X and Linux).

2. `home_trash`: A _relative_ path where the trash is expected from the `home` directory.

3. `mountpoint_trash_fmt`: A _relative_ path where the trash is expected from any given mountpoint. This string can optionally include a `%s` format specifier which will be replaced by the current user's numeric ID (ie. UID).

The FileDiscard::Discarder will rely on comparison between mountpoints (as determined by [`Pathname#mountpoint?`](http://www.ruby-doc.org/stdlib/libdoc/pathname/rdoc/Pathname.html#method-i-mountpoint-3F)) to decide if the home trash should be used or if a shared trash for another mounted volume should be used. In other words, if the mountpoint of the file being trashed is _not_ the same as the `home` directory's mountpoint, the discarder will use the trash located in the mountpoint associated with the file being discarded using the `mountpoint_trash_fmt` relative result as presented by the discarder.

If the trash location does not already exist, the FileDiscard::Discarder will not automatically create it. Instead, it will raise a FileDiscard::TrashMissing exception for any discard request that attempts to move a file to a trash that does not exist. It is expected that the caller will ensure the trash directories are present before attempting to discard files or make use of FileDiscard.create_trash_when_missing= to enable automatically creating missing trash folders.

For a more complex example, see FileDiscard::LinuxDiscarder.
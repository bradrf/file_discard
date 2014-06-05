`FileDiscard` is a simple helper to make it easy for applications to move files to the correct trash
folder. The location is determined by the platform and what file is being discarded (the latter is
important so that files on other volumes/mountpoints are moved in to the appropriate trash folder).

## Getting Started

There are two ways for making discard requests. The easiest method extends Ruby's
[`File`](http://www.ruby-doc.org/core/File.html) and
[`Pathname`](http://www.ruby-doc.org/stdlib/libdoc/pathname/rdoc/Pathname.html) classes:

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
p.write 'two'
p.discard

# open a file and discard it using the class...
f = File.open 'file3.txt', 'w'
f.puts 'three'
f.close
File.discard 'file3.txt'

# create a pathname and discard it using the class...
p = Pathname.new 'file4.txt'
p.write 'four'
Pathname.discard 'file4.txt'
```

Another approach is to leave Ruby's [`File`](http://www.ruby-doc.org/core/File.html) and
[`Pathname`](http://www.ruby-doc.org/stdlib/libdoc/pathname/rdoc/Pathname.html) classes alone and
work directly with `FileDiscard`:

```ruby
require 'file_discard'

# open a file and discard it...
f = File.open 'file5.txt', 'w'
f.puts 'five'
f.close
FileDiscard.discard 'file5.txt'

# create a pathname and discard it...
p = Pathname.new 'file6.txt'
p.write 'six'
FileDiscard.discard 'file6.txt'
```

### More Options

Under the covers, `FileDiscard` makes use of
[`FileUtils.mv`](http://ruby-doc.org/stdlib/libdoc/fileutils/rdoc/FileUtils.html#method-c-mv) and
passes any other options through:

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
p.write 'eight'
Pathname.discard 'file8.txt', verbose:true
# ===> mv /path/to/file8.txt /Users/brad/.Trash/file8.txt
```

Also of note is that `FileDiscard` will not blindly stomp on existing files already present in the
trash. Instead, much like OS X's Finder, `FileDiscard` creates new file names based on time when a
collision occurs:

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
p.write 'samename'
Pathname.discard 'samename.txt', verbose:true
# ===> mv /path/to/samename.txt /Users/brad/.Trash/samename 17.49.44.txt
```

### Exceptions

The most common exception raised will be if a discard request is made for a file that does not exist:

```ruby
require 'file_discard'

FileDiscard.mix_it_in!

p = Pathname.new 'missing1.txt'
p.discard
# ===> Errno::ENOENT: No such file or directory @ realpath_rec - /path/to/missing1.txt
```

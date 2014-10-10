require 'rake'
require 'rake/testtask'
require 'rake/clean'
require 'rdoc/task'
require 'rubygems/package_task'

task default: :test
task spec: :test
task build: :package

PKG_VERSION = '0.1.4'
NOW = Time.now.utc

# delay updating the version file unless building the gem or package
VER_FN = 'lib/file_discard_version.rb'
task :update_version do
  File.open(VER_FN,'w',0644) do |f|
    f.puts <<EOF
module FileDiscard
  # :nodoc:
  VERSION = '#{PKG_VERSION}'
  # :nodoc:
  RELEASE = '#{`git rev-parse --short HEAD`.chomp}:#{NOW.strftime('%Y%m%d%H%M%S')}'
end
EOF
  end
end

if File.exist? VER_FN
  task package: :update_version
  task gem: :update_version
else
  Rake::Task[:update_version].execute
end

Rake::TestTask.new do |t|
  t.pattern = "spec/*_spec.rb"
end

RDOC_EXTRA_FILES = ['README.md','LICENSE']

RDoc::Task.new :rdoc do |rdoc|
  rdoc.rdoc_files.include(*RDOC_EXTRA_FILES, 'lib/**/*.rb')
  rdoc.title    = 'FileDiscard'
  rdoc.main     = 'README.md'
  rdoc.rdoc_dir = 'rdoc'
end

def list_files
  if Dir.exist? '.git'
    files = `git ls-files -z`.split("\x0")
  else
    # e.g. when installed and tasks are run from there...
    files = Dir.glob('**/*').select{|e| File.file? e}
  end
  files.delete '.gitignore'
  files
end

spec = Gem::Specification.new do |s|
  s.name        = 'file_discard'
  s.summary     = 'Move files to the trash.'
  s.description = 'Simple helper to move files to the trash folder.'

  s.authors  = ['Brad Robel-Forrest']
  s.email    = 'brad+filediscard@gigglewax.com'
  s.homepage = 'https://github.com/bradrf/file_discard#readme'
  s.license  = 'MIT'

  s.version = PKG_VERSION
  s.date    = NOW.strftime('%Y-%m-%d')

  s.required_ruby_version = '>= 1.9.0'

  s.files       = list_files << 'lib/file_discard_version.rb'
  s.test_files  = s.files.grep(%r{^spec/})
  s.executables = %w(discard)

  s.has_rdoc          = true
  s.rdoc_options     += ['--title','FileDiscard','--main','README.md']
  s.extra_rdoc_files += RDOC_EXTRA_FILES
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

desc 'Start GitHub Readme Instant Preview service (see https://github.com/joeyespo/grip)'
task :grip do
  exec 'grip --gfm --context=bradrf/file_discard'
end

CLOBBER.include 'coverage', VER_FN

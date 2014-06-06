require 'rake'
require 'rake/testtask'
require 'rake/clean'
require 'rubygems/package_task'

task default: :test
task spec: :test
task build: :package

PKG_VERSION = '0.1.2'
NOW = Time.now.utc

# delay updating the version file unless building the gem or package
task :update_version do
  File.open('lib/file_discard_version.rb','w') do |f|
    f.puts <<EOF
module FileDiscard
  VERSION = '#{PKG_VERSION}'
  RELEASE = '#{`git rev-parse --short HEAD`.chomp}:#{NOW.strftime('%Y%m%d%H%M%S')}'
end
EOF
  end
end
task package: :update_version
task gem: :update_version

Rake::TestTask.new do |t|
  t.pattern = "spec/*_spec.rb"
end

def list_files
  if Dir.exist? '.git'
    `git ls-files -z`.split("\x0")
  else
    # e.g. when installed and tasks are run from there...
    Dir.glob('**/*').select{|e| File.file? e}
  end
end

spec = Gem::Specification.new do |s|
  s.name        = 'file_discard'
  s.version     = PKG_VERSION
  s.date        = NOW.strftime('%Y-%m-%d')
  s.summary     = 'Move files to the trash'
  s.description = 'Simple helper to move files to the trash folder'
  s.authors     = ['Brad Robel-Forrest']
  s.email       = 'brad+filediscard@gigglewax.com'
  s.files       = list_files << 'lib/file_discard_version.rb'
  s.test_files  = s.files.grep(%r{^spec/})
  s.executables = %w(discard)
  s.homepage    = 'https://github.com/bradrf/file_discard#readme'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 1.9.0'
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

desc 'Start GitHub Readme Instant Preview service (see https://github.com/joeyespo/grip)'
task :grip do
  exec 'grip --gfm --context=bradrf/file_discard'
end

CLOBBER.add 'coverage'

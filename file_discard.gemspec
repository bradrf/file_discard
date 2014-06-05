Gem::Specification.new do |s|
  Kernel.load 'lib/file_discard.rb'
  s.name        = 'file_discard'
  s.version     = FileDiscard::VERSION
  s.date        = Time.now.strftime('%Y-%m-%d')
  s.summary     = 'Move files to the trash'
  s.description = 'Simple helper to move files to the trash on OS X or Linux platforms'
  s.authors     = ['Brad Robel-Forrest']
  s.email       = 'brad+filediscard@gigglewax.com'
  s.files       = ['lib/file_discard.rb']
  s.homepage    = 'https://github.com/bradrf/file_discard#readme'
  s.license     = 'MIT'
end

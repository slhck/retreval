Gem::Specification.new do |s| 
  s.name	= "retreval" 
  s.summary	= "A Ruby API for Evaluating Retrieval Results" 
  s.description = File.read(File.join(File.dirname(__FILE__), 'README.md')) 
  # s.requirements = [ 'Nothing special' ]
  s.version = "0.1.1"
  s.author = "Werner Robitza"
  s.email = "werner.robitza@univie.ac.at"
  s.homepage = "http://github.com/slhck/retreval"
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>=1.9' 
  s.files	= Dir['**/**'] 
  s.executables = [ 'retreval' ] 
  s.test_files = Dir["test/test*.rb"] 
  s.has_rdoc	= true
end
require 'rubygems'
require 'rake'
require './lib/rfm'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "ginjo-rfm"
    gem.summary = "Ruby to Filemaker adapter"
    gem.description = "Rfm brings your FileMaker data to Ruby. Now your Ruby scripts and Rails applications can talk directly to your FileMaker server."
    gem.email = "http://groups.google.com/group/rfmcommunity"
    gem.homepage = "https://rubygems.org/gems/ginjo-rfm"
    gem.authors = ["Geoff Coffey", "Mufaddal Khumri", "Atsushi Matsuo", "Larry Sprock", "Bill Richardson"]
    gem.files = FileList['lib/**/*']
    gem.add_dependency('nokogiri')
    gem.add_development_dependency('jeweler')
    gem.add_development_dependency('rake')
    gem.add_development_dependency('rdoc')
    gem.add_development_dependency('yard')
    gem.add_development_dependency('rspec', '~>1.3.0')
    gem.rdoc_options = [ "--line-numbers", "--main", "README.md" ]
    gem.version = Rfm::VERSION
  end
  Jeweler::RubygemsDotOrgTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
	version = Rfm::VERSION
	rdoc.main = 'README.md'
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "Rfm #{version}"
  rdoc.rdoc_files.include('lib/**/*.rb', 'README*', 'CHANGELOG', 'lib/rfm/VERSION', 'LICENSE')
end

require 'yard'
require 'rdoc'
YARD::Rake::YardocTask.new do |t|
	# See http://rubydoc.info/docs/yard/file/docs/GettingStarted.md
	# See 'yardoc --help'
  t.files   = ['lib/**/*.rb', 'README', 'LICENSE', 'lib/rfm/VERSION', 'CHANGELOG']  # optional
  t.options = ['-oydoc', '--no-cache', '-mrdoc', '--no-private'] # optional
end


# Rspec 2 beginnings
# require 'rspec/core/rake_task'
# RSpec::Core::RakeTask.new(:spec) do |spec|
#   spec.libs << 'lib' << 'spec'
#   spec.spec_files = FileList['spec/**/*_spec.rb']
# end
# 
# RSpec::Core::RakeTask.new(:rcov) do |spec|
#   spec.libs << 'lib' << 'spec'
#   spec.pattern = 'spec/**/*_spec.rb'
#   spec.rcov = true
# end


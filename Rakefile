require 'rake'
require 'rake/testtask'
require 'rdoc/task'

task default: [:test]

Rake::TestTask.new('test') do |t|
  t.ruby_opts = ['-rsimplecov']
  t.pattern = 'test/**/*_test.rb'
end

RDoc::Task.new do |rdoc|
  rdoc.rdoc_files.include("lib/**/*.rb")
end

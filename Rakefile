require 'rake'
require 'rake/testtask'

task default: [:test]

Rake::TestTask.new('test') do |t|
  t.ruby_opts = ['-rsimplecov']
  t.pattern = 'test/**/*_test.rb'
end

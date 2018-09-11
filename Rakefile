require 'rubygems'
require 'rubygems/user_interaction'
require 'rake/testtask'
require 'ci/reporter/rake/test_unit'
require 'bundler/gem_tasks'

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

rule '.rb' => '.y' do |t|
  sh "racc -l -o #{t.name} #{t.source}"
end

desc 'Compile the racc parser from the grammar'
task compile: ['lib/sparkql/parser.rb', 'grammar']

desc 'Generate grammar Documenation'
task :grammar do
  puts 'Generating grammar documentation...'
  sh 'ruby script/markdownify.rb > GRAMMAR.md'
end

Rake::Task[:test].prerequisites.unshift 'lib/sparkql/parser.rb'
Rake::Task[:test].prerequisites.unshift 'grammar'

desc 'Default: run unit tests.'
task default: :test

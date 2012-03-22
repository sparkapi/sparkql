require "rubygems"
require 'rubygems/user_interaction'
require 'flexmls_gems/tasks'
require 'flexmls_gems/tasks/test_unit'
require 'flexmls_gems/tasks/rdoc'

rule '.rb' => '.y' do |t|
  sh "racc -l -o #{t.name} #{t.source}"
end

desc "Compile the racc parser from the grammar"
task :compile => "lib/sparkql/parser.rb"

Rake::Task[:test].prerequisites.unshift "lib/sparkql/parser.rb"

desc 'Default: run unit tests.'
task :default => :test


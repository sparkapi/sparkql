require "rubygems"
require 'rubygems/user_interaction'
require 'flexmls_gems/tasks'
require 'flexmls_gems/tasks/test_unit'
require 'flexmls_gems/tasks/rdoc'

file "lib/sparkql/parser.rb" => ["grammar/sparkql.y"] do
  puts "Rebuildings parser"
  sh('racc -o lib/sparkql/parser.rb grammar/sparkql.y')
end

Rake::Task[:test].prerequisites << "lib/sparkql/parser.rb"

desc 'Default: run unit tests.'
task :default => :test
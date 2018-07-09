require_relative 'lib/sparkql'

parser = Sparkql::Parser.new

filter = 10000.times.map { "City Eq 'Fargo'" }.join(' And ')

expression = parser.parse(filter)


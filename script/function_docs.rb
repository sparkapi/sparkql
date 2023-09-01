require 'yaml'
functions = YAML.load_file('config/functions.yml')

def parameters(details)
  arg_string = details['arguments'].map do |arg|
    types = arg['types']
    types << 'field' if arg['allow_field']
    types.join('\\|')
  end

  "(#{arg_string.join(', ')})"
end

puts "`name` | `type` (return type) | `args`"
puts "---- | ----------- | ----------"
functions.each do |name, details|
  puts "#{name} | #{details['return_type']} | #{parameters(details)}"
end


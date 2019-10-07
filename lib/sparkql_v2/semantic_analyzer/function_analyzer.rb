# frozen_string_literal: true

module SparkqlV2
  class SemanticAnalyzer
    # Checks the validity of a function while going through
    # semantic analyses
    class FunctionAnalyzer
      attr_accessor :function, :args, :errors
      FUNCTION_METADATA = YAML.load_file(File.join(SparkqlV2.config, 'functions.yml'))

      def initialize(function, args)
        @function = function
        @args = args
        @metadata = FUNCTION_METADATA[function['name']]
        @errors = []
      end

      def analyze
        return function unless metadata? && basic_arg_validation?

        name = function['name']
        # After this point we don't need to worry about checking field types
        function_valid?(name, args)
        function.merge(
          'type' => function_type(name, args)
        )
      end

      private

      def metadata?
        return true unless @metadata.nil?

        @errors << {
          token: function['name'],
          message: "Unsupported function call '#{function['name']}' for expression",
          status: :fatal
        }
        false
      end

      def arg_meta
        @metadata['arguments']
      end

      def function_type(name, _args)
        FUNCTION_METADATA[name]['return_type']
      end

      def coords?(coord_string)
        coord_string.split(' ').size > 1
      end

      def min_args(arg_meta)
        arg_meta.reject { |arg| arg.key?('default') }.size
      end

      def max_args(arg_meta)
        arg_meta.size
      end

      def valid_arg_count?(args, arg_meta)
        min_args = min_args(arg_meta)
        max_args = max_args(arg_meta)

        if args.size < min_args || args.size > max_args
          message = "requires between #{min_args} and #{max_args} arguments"
          @errors << { token: 'name', message: message, status: :fatal }
          return false
        end
        true
      end

      def accepts_field_argument?(meta, current_argument)
        return true unless !meta['allow_field']

        stack = [current_argument]

        while stack.size > 0
          arg = stack.pop
          if arg['name'] == 'field'
            @errors << {
              token: current_argument,
              message: 'Argument does not support a field',
              status: :fatal,
              syntax: false,
              constraint: true
            }
            return false
          elsif arg['function']
            arg['args'].each {|a| stack.push(a)}
          end
        end

        true
      end

      def accepts_type?(meta, current_argument)
        type = current_argument['type']
        return true unless !type.nil? && !meta['types'].include?(current_argument['type'])

        @errors << {
          token: current_argument,
          message: "Incorrect argument type: #{current_argument['type']}",
          status: :fatal,
          syntax: false,
          constraint: true
        }
        false
      end

      def basic_arg_validation?
        return false unless valid_arg_count?(args, arg_meta)

        arg_meta.each_with_index do |meta, index|
          current_argument = args[index]

          return false unless accepts_field_argument?(meta, current_argument)
          return false unless accepts_type?(meta, current_argument)
        end
        true
      end

      def regex_flags_valid?(args)
        if args[1] && args[1]['type'] == 'character' &&
           !VALID_REGEX_FLAGS.include?(args[1]['value'])
          errors << {
            token: args.first,
            message: 'Invalid Regex flag',
            status: :fatal,
            syntax: false,
            constraint: true
          }
        end
      end

      def regex_parses?(args)
        Regexp.new(args.first['value'])
      rescue StandardError
        errors << {
          token: args.first,
          message: 'Invalid Regexp',
          status: :fatal,
          syntax: false,
          constraint: true
        }
      end

      def regex_valid?(args)
        regex_flags_valid?(args)
        regex_parses?(args)
      end

      def wkt_valid?(args)
        GeoRuby::SimpleFeatures::Geometry.from_ewkt(args.first['value'])
      rescue GeoRuby::SimpleFeatures::EWKTFormatError
        @errors << {
          token: args.first['value'],
          message: 'wkt() requires valid WKT',
          status: :fatal,
          syntax: false,
          constraint: true
        }
      end

      def radius_second_arg_valid?(arg2)
        return unless arg2['value'] < 0

        @errors << {
          token: arg2,
          message: 'Second argument cannot be negative',
          status: :fatal,
          syntax: false,
          constraint: true
        }
      end

      def radius_first_arg_valid?(arg1)
        if !coords?(arg1['value']) &&
           arg1['value'] !~ /^\d{26}$/
          @errors << {
            token: arg1,
            message: 'First argument must be valid coordinates or a tech id',
            status: :fatal,
            syntax: false,
            constraint: true
          }
        end
      end

      def radius_valid?(args)
        radius_first_arg_valid?(args[0])
        radius_second_arg_valid?(args[1])
      end

      def function_valid?(name, args)
        case name
        when 'regex'
          regex_valid?(args)
        when 'wkt'
          wkt_valid?(args)
        when 'radius'
          radius_valid?(args)
        else
          true
        end
      end
    end
  end
end

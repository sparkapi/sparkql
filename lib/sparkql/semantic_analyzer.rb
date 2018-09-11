require 'georuby'
require 'geo_ruby/ewk'
module Sparkql
  # Performs:
  # - Type checking
  # - Coerces literals and casts identifiers
  # - Flags fields which are not searchable
  # Returns an annotated syntax tree
  # Needs to accept:
  # - Metadata
  # - AST
  #
  # Annotates nodes with
  #  - all identifiers
  #  - errors for invalid type comparisons
  #  - comparison
  class SemanticAnalyzer
    DATE_TYPES = [:datetime, :date].freeze
    NUMBER_TYPES = [:decimal, :integer].freeze
    VALID_REGEX_FLAGS = ['', 'i'].freeze
    INVALID_RANGE_TYPES = [:character, :shape, :boolean, :null].freeze

    def initialize(metadata)
      @metadata = metadata
      @errors = []
    end

    def visit(ast)
      if ast[:function]
        visit_function(ast)
      else
        send("visit_#{ast[:name]}", ast)
      end
    end

    attr_reader :errors

    def errors?
      !@errors.empty?
    end

    private

    def require_range_type!(*all)
      all.each do |item|
        @errors << {} if INVALID_RANGE_TYPES.include?(item[:type])
      end
    end

    def visit_literal(node)
      node.dup
    end

    def visit_field(node)
      meta = @metadata[node[:value]]

      if meta.nil?
        @errors << {
          token: node[:value],
          message: "standard field #{node[:value]} is invalid",
          status: :fatal
        }
        return node.dup
      end

      type = if meta[:searchable]
               meta[:type]
             else
               :drop
             end
      node.dup.merge(
        type: type
      )
    end

    def visit_custom_field(node)
      meta = @metadata[node[:value]]
      if meta.nil?
        @errors << {
          token: node[:value],
          message: "custom field #{node[:value]} is invalid",
          status: :fatal
        }
        return node.dup
      end

      type = if meta[:searchable]
               meta[:type]
             else
               :drop
             end
      node.dup.merge(
        type: type
      )
    end

    def visit_and(node)
      left = visit(node[:lhs])
      right = visit(node[:rhs])
      node.merge(
        lhs: left,
        rhs: right
      )
    end

    def visit_or(node)
      left = visit(node[:lhs])
      right = visit(node[:rhs])
      node.merge(
        lhs: left,
        rhs: right
      )
    end

    def visit_eq(node)
      left, right = coerce_if_necessary([visit(node[:lhs]), visit(node[:rhs])])

      node.merge(
        lhs: left,
        rhs: right
      )
    end

    def visit_ne(node)
      left, right = coerce_if_necessary([visit(node[:lhs]), visit(node[:rhs])])

      node.merge(
        lhs: left,
        rhs: right
      )
    end

    def visit_in(node)
      all = ([node[:lhs]] + node[:rhs]).map do |item|
        visit(item)
      end
      all = coerce_if_necessary(all)

      left = all.shift
      right = all
      node.merge(
        lhs: left,
        rhs: right
      )
    end

    def visit_gt(node)
      left, right = coerce_if_necessary([visit(node[:lhs]), visit(node[:rhs])])
      require_range_type!(left, right)

      node.merge(
        lhs: left,
        rhs: right
      )
    end

    def visit_ge(node)
      left, right = coerce_if_necessary([visit(node[:lhs]), visit(node[:rhs])])
      require_range_type!(left, right)

      node.merge(
        lhs: left,
        rhs: right
      )
    end

    def visit_lt(node)
      left, right = coerce_if_necessary([visit(node[:lhs]), visit(node[:rhs])])
      require_range_type!(left, right)

      node.merge(
        lhs: left,
        rhs: right
      )
    end

    def visit_le(node)
      left, right = coerce_if_necessary([visit(node[:lhs]), visit(node[:rhs])])
      require_range_type!(left, right)

      node.merge(
        lhs: left,
        rhs: right
      )
    end

    def visit_bt(node)
      left, rhs1, rhs2 = coerce_if_necessary([visit(node[:lhs]), visit(node[:rhs][0]), visit(node[:rhs][1])])
      require_range_type!(left, rhs1, rhs2)

      node.merge(
        lhs: left,
        rhs: [rhs1, rhs2]
      )
    end

    def visit_group(node)
      node.merge(
        lhs: left,
        rhs: right
      )
    end

    def visit_unary_not(node)
      node
    end

    def visit_function(function)
      arg_meta = Sparkql::FUNCTION_METADATA[function[:name]][:arguments]
      args = function[:args].map { |arg| visit(arg) }
      basic_arg_validation(args, arg_meta)

      if function[:name] == :regex
        if args[1] && args[1][:type] == :character &&
           !VALID_REGEX_FLAGS.include?(args[1][:value])
          errors << {
            token: args.first,
            message: 'Invalid Regex flag',
            status: :fatal,
            syntax: false,
            constraint: true
          }
        end

        begin
          Regexp.new(args.first[:value])
        rescue StandardError
          errors << {
            token: args.first,
            message: 'Invalid Regexp',
            status: :fatal,
            syntax: false,
            constraint: true
          }
        end
      elsif function[:name] == :wkt
        begin
          GeoRuby::SimpleFeatures::Geometry.from_ewkt(args.first[:value])
        rescue GeoRuby::SimpleFeatures::EWKTFormatError
          errors << {
            token: args.first[:value],
            message: 'wkt() requires valid WKT',
            status: :fatal,
            syntax: false,
            constraint: true
          }
        end
      elsif function[:name] == :radius
        arg2 = args[1]
        if arg2[:name] == :literal &&
           [:decimal, :integer].include?(arg2[:type]) &&
           arg2[:value] < 0
          errors << {
            token: arg2,
            message: 'Second argument cannot be negative',
            status: :fatal,
            syntax: false,
            constraint: true
          }
        end

        arg1 = args.first
        if arg1[:name] == :literal &&
           [:character].include?(arg1[:type]) &&
           (!is_coords?(arg1[:value]) &&
           arg1[:value] !~ /^\d{26}$/)
          errors << {
            token: arg1,
            message: 'First argument must be valid coordinates or a tech id',
            status: :fatal,
            syntax: false,
            constraint: true
          }
        end
      end

      type = case function[:name]
             when :length
               :integer
             when :toupper
               :character
             when :tolower
               :character
             when :now
               :datetime
             when :mindatetime
               :date
             when :maxdatetime
               :date
             when :fractionalseconds
               :decimal
             when :days
               :datetime
             when :regex
               :character
             when :radius
               :shape
             when :polygon
               :shape
             when :wkt
               :shape
             else
               raise "FUNCTION DOESN'T HAVE A RETURN TYPE!!!"
             end

      function.dup.merge(
        type: type
      )
    end

    def is_coords?(coord_string)
      coord_string.split(' ').size > 1
    end

    def basic_arg_validation(args, arg_meta)
      min_args = arg_meta.reject { |arg| arg.key?(:default) }.size
      max_args = arg_meta.size

      if args.size < min_args || args.size > max_args
        message = if min_args == max_args
                    "requires #{min_args} arguments"
                  else
                    "requires between #{min_args} and #{max_args} arguments"
                  end
        @errors << {
          token: 'name',
          message: message,
          status: :fatal
        }
        return
      end

      arg_meta.each_with_index do |meta, index|
        current_argument = args[index]

        if !meta[:allow_field] && current_argument[:name] == :field
          @errors << {
            token: current_argument,
            message: 'Argument does not support a field',
            status: :fatal,
            syntax: false,
            constraint: true
          }
        end

        next unless current_argument.key?(:type) && !meta[:types].include?(current_argument[:type])

        @errors << {
          token: current_argument,
          message: "Incorrect argument type: #{current_argument[:type]}",
          status: :fatal,
          syntax: false,
          constraint: true
        }
      end
    end

    def coerce_if_necessary(all_nodes)
      types = all_nodes.map { |node| node[:type] }
      if types.uniq.size == 1
        return all_nodes
      else
        if types.all? { |type| NUMBER_TYPES.include?(type) }
          all_nodes.map do |node|
            if node[:type] != NUMBER_TYPES.first
              {
                name: :coerce,
                lhs: node,
                rhs: NUMBER_TYPES.first
              }
            else
              node
            end
          end
        elsif types.all? { |type| DATE_TYPES.include?(type) }
          all_nodes.map do |node|
            if node[:type] != DATE_TYPES.first
              {
                name: :coerce,
                lhs: node,
                rhs: DATE_TYPES.first
              }
            else
              node
            end
          end
        else
          @errors << {
            message: 'Type mismatch in comparison.',
            status: :fatal
          }
          all_nodes
        end
      end
    end

    def numeric?(type)
      NUMBER_TYPES.include?(type)
    end
  end
end

# frozen_string_literal: true

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
    DATE_TYPES = ['datetime', 'date'].freeze
    NUMBER_TYPES = ['decimal', 'integer'].freeze
    VALID_REGEX_FLAGS = ['', 'i'].freeze
    INVALID_RANGE_TYPES = ['character', 'shape', 'boolean', 'null'].freeze

    def initialize(metadata)
      @metadata = metadata
      @errors = []
    end

    def visit(ast)
      if ast['function']
        visit_function(ast)
      else
        send("visit_#{ast['name']}", ast)
      end
    end

    attr_reader :errors

    def errors?
      !@errors.empty?
    end

    private

    def require_range_type!(*all)
      all.each do |item|
        @errors << {} if INVALID_RANGE_TYPES.include?(item['type'])
      end
    end

    def visit_literal(node)
      node.dup
    end

    def field_valid?(node, meta)
      if meta.nil?
        @errors << {
          token: node['value'],
          message: "standard field #{node['value']} is invalid",
          status: :fatal
        }
        return false
      end
      true
    end

    def custom_field_valid?(node, meta)
      if meta.nil?
        @errors << {
          token: node['value'],
          message: "custom field #{node['value']} is invalid",
          status: :fatal
        }
        return false
      end
      true
    end

    def type_for(meta)
      if meta['Searchable']
        meta['Type']
      else
        'drop'
      end
    end

    def visit_field(node)
      meta = @metadata[node['value']]

      return node.dup unless field_valid?(node, meta)

      node.dup.merge(
        'type' => type_for(meta)
      )
    end

    def visit_custom_field(node)
      meta = @metadata[node['value']]

      return node.dup unless custom_field_valid?(node, meta)

      node.dup.merge(
        'type' => type_for(meta)
      )
    end

    def visit_and(node)
      left = visit(node['lhs'])
      right = visit(node['rhs'])
      node.merge(
        'lhs' => left,
        'rhs' => right
      )
    end

    def visit_or(node)
      left = visit(node['lhs'])
      right = visit(node['rhs'])
      node.merge(
        'lhs' => left,
        'rhs' => right
      )
    end

    def visit_eq(node)
      left, right = coerce_if_necessary([visit(node['lhs']), visit(node['rhs'])])

      node.merge(
        'lhs' => left,
        'rhs' => right
      )
    end

    def visit_ne(node)
      left, right = coerce_if_necessary([visit(node['lhs']), visit(node['rhs'])])

      node.merge(
        'lhs' => left,
        'rhs' => right
      )
    end

    def visit_in(node)
      all = ([node['lhs']] + node['rhs']).map do |item|
        visit(item)
      end
      all = coerce_if_necessary(all)

      left = all.shift
      right = all
      node.merge(
        'lhs' => left,
        'rhs' => right
      )
    end

    def visit_gt(node)
      left, right = coerce_if_necessary([visit(node['lhs']), visit(node['rhs'])])
      require_range_type!(left, right)

      node.merge(
        'lhs' => left,
        'rhs' => right
      )
    end

    def visit_ge(node)
      left, right = coerce_if_necessary([visit(node['lhs']), visit(node['rhs'])])
      require_range_type!(left, right)

      node.merge(
        'lhs' => left,
        'rhs' => right
      )
    end

    def visit_lt(node)
      left, right = coerce_if_necessary([visit(node['lhs']), visit(node['rhs'])])
      require_range_type!(left, right)

      node.merge(
        'lhs' => left,
        'rhs' => right
      )
    end

    def visit_le(node)
      left, right = coerce_if_necessary([visit(node['lhs']), visit(node['rhs'])])
      require_range_type!(left, right)

      node.merge(
        'lhs' => left,
        'rhs' => right
      )
    end

    def visit_bt(node)
      nodes = [visit(node['lhs']), visit(node['rhs'][0]), visit(node['rhs'][1])]
      left, rhs1, rhs2 = coerce_if_necessary(nodes)
      require_range_type!(left, rhs1, rhs2)

      node.merge(
        'lhs' => left,
        'rhs' => [rhs1, rhs2]
      )
    end

    def visit_group(node)
      node.merge(
        'value' => visit(node['value'])
      )
    end

    def visit_unary_not(node)
      node.merge(
        'value' => visit(node['value'])
      )
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

    def function_type(name, _args)
      Sparkql::FUNCTION_METADATA[name]['return_type']
    end

    def visit_function(function)
      arg_meta = Sparkql::FUNCTION_METADATA[function['name']]['arguments']
      args = function['args'].map { |arg| visit(arg) }

      new_node = function.dup.merge(
        'type' => function_type(function['name'], args)
      )

      # After this point we don't need to worry about checking field types
      return new_node unless basic_arg_validation?(args, arg_meta)

      function_valid?(function['name'], args)

      new_node
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
      return true unless !meta['allow_field'] && current_argument['name'] == 'field'

      @errors << {
        token: current_argument,
        message: 'Argument does not support a field',
        status: :fatal,
        syntax: false,
        constraint: true
      }
      false
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

    def basic_arg_validation?(args, arg_meta)
      return false unless valid_arg_count?(args, arg_meta)

      arg_meta.each_with_index do |meta, index|
        current_argument = args[index]

        return false unless accepts_field_argument?(meta, current_argument)
        return false unless accepts_type?(meta, current_argument)
      end
      true
    end

    def coerce_numbers(types, all_nodes)
      return all_nodes unless types.all? { |type| NUMBER_TYPES.include?(type) }

      all_nodes.map do |node|
        coerce_to(node, NUMBER_TYPES.first)
      end
    end

    def coerce_dates(types, all_nodes)
      return all_nodes unless types.all? { |type| DATE_TYPES.include?(type) }

      all_nodes.map do |node|
        coerce_to(node, DATE_TYPES.first)
      end
    end

    def coerce_to(node, type)
      return node if node['type'] == type

      {
        'name' => 'coerce',
        'lhs' => node,
        'rhs' => type
      }
    end

    def coerce_if_necessary(all_nodes)
      types = all_nodes.map { |node| node['type'] }
      return all_nodes if (types.uniq - ['null']).size <= 1

      all_nodes = coerce_numbers(types, all_nodes)
      all_nodes = coerce_dates(types, all_nodes)

      type_mismatch?(all_nodes)
      all_nodes
    end

    def type_mismatch?(all_nodes)
      types = all_nodes.map { |node| node['type'] }.compact
      return false if types.all? { |type| DATE_TYPES.include?(type) }
      return false if types.all? { |type| NUMBER_TYPES.include?(type) }

      @errors << {
        message: 'Type mismatch in comparison.',
        status: :fatal
      }
      true
    end

    def numeric?(type)
      NUMBER_TYPES.include?(type)
    end
  end
end

# frozen_string_literal: true

require 'georuby'
require 'geo_ruby/ewk'
require_relative 'semantic_analyzer/function_analyzer'

module SparkqlV2
  # Performs:
  # - Type checking
  # - Coerces types
  # - Flags fields which are not searchable
  # Returns an annotated syntax tree
  class SemanticAnalyzer
    DATE_TYPES = ['datetime', 'date'].freeze
    NUMBER_TYPES = ['decimal', 'integer'].freeze
    VALID_REGEX_FLAGS = ['', 'i'].freeze
    INVALID_RANGE_TYPES = ['character', 'shape', 'boolean', 'null'].freeze

    def initialize(metadata)
      @metadata = metadata
      @errors = []
      @warnings = []
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

    def field_exists?(node, meta)
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

    def custom_field_exists?(node, meta)
      if meta.nil?
        @warnings << {
          token: node['value'],
          message: "custom field #{node['value']} is invalid",
          status: :fatal
        }
        return false
      end
      true
    end

    def field_searchable?(meta)
      return true if meta['searchable']

      @errors << {
        message: 'Field is not searchable',
        status: :fatal
      }
      false
    end

    def visit_field(node)
      meta = @metadata[node['value']]

      return node.dup unless field_exists?(node, meta)
      return node.dup unless field_searchable?(meta)

      node.dup.merge(meta)
    end

    def visit_custom_field(node)
      meta = @metadata[node['value']]

      return node.dup.merge('type' => 'drop') unless custom_field_exists?(node, meta)

      node.dup.merge(meta)
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
      all = ([node['lhs']] + node['rhs']['value']).map do |item|
        visit(item)
      end
      all = coerce_if_necessary(all)

      left = all.shift
      right = all
      node.merge(
        'lhs' => left,
        'rhs' => { 'value' => right }
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
      nodes = [visit(node['lhs']), visit(node['rhs']['value'][0]), visit(node['rhs']['value'][1])]
      left, rhs1, rhs2 = coerce_if_necessary(nodes)
      require_range_type!(left, rhs1, rhs2)

      node.merge(
        'lhs' => left,
        'rhs' => { 'value' => [rhs1, rhs2] }
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

    def visit_function(function)
      args = function['args'].map { |arg| visit(arg) }

      function_analyzer = FunctionAnalyzer.new(function, args)
      node = function_analyzer.analyze
      @errors.concat(function_analyzer.errors)
      node
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

      type_mismatch_after_coerce?(all_nodes)
      all_nodes
    end

    def type_mismatch_after_coerce?(all_nodes)
      types = all_nodes.map { |node| node['type'] }.compact.uniq
      return false if types.size <= 1

      @errors << {
        message: "Type mismatch in comparison. Attempted to compare #{types.inspect}.",
        status: :fatal
      }
      true
    end
  end
end

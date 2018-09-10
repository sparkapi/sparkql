module Sparkql
  # Performs:
  # - Type checking
  # - Coerces literals and casts identifiers
  # - Flags fields which are not searchable
  # Returns an annotated syntax tree
  class SemanticAnalyzer
    # Needs to accept:
    # - Metadata
    # - AST
    #
    # Annotates nodes with
    #  - all identifiers
    #  - errors for invalid type comparisons
    #  - comparison

    DATE_TYPES = [:datetime, :date]
    NUMBER_TYPES = [:decimal, :integer]

    def initialize(metadata)
      @metadata = metadata
      @errors = []
      @identifiers = []
    end

    def visit(ast)
      if ast[:function]
        visit_function(ast)
      else
        send("visit_#{ast[:name]}", ast)
      end
    end

    def errors
      @errors
    end

    def errors?
      @errors.size > 0
    end

    private

    def visit_literal(node)
      node.dup
    end

    def visit_field(node)
      if @metadata[node[:value]].nil?
        @errors << {
        }
      end
      node.dup
    end

    def visit_custom_field(node)
      if @metadata[node[:value]].nil?
        @errors << {
        }
      end
      node.dup
    end

    def visit_and(node)
      left = visit(node[:lhs])
      right = visit(node[:rhs])
      node.merge({
        lhs: left,
        rhs: right
      })
    end

    def visit_or(node)
      left = visit(node[:lhs])
      right = visit(node[:rhs])
      node.merge({
        lhs: left,
        rhs: right
      })
    end

    def visit_eq(node)
      left = visit(node[:lhs])
      right = visit(node[:rhs])
      node.merge({
        lhs: left,
        rhs: right
      })
    end

    def visit_neq(node)
      left = visit(node[:lhs])
      right = visit(node[:rhs])
      node.merge({
        lhs: left,
        rhs: right
      })
    end

    def visit_in(node)
      puts "visting: #{node.inspect}"
    end

    def visit_gt(node)
      left = visit(node[:lhs])
      right = visit(node[:rhs])
      node.merge({
        lhs: left,
        rhs: right
      })
    end

    def visit_ge(node)
      left = visit(node[:lhs])
      right = visit(node[:rhs])
      node.merge({
        lhs: left,
        rhs: right
      })
    end

    def visit_lt(node)
      puts "visting: #{node.inspect}"
    end

    def visit_le(node)
      puts "visting: #{node.inspect}"
    end

    def visit_bt(node)
      coerced_nodes = coerce_if_necessary([visit(node[:lhs]), visit(node[:rhs][0]), visit(node[:rhs][1])])
      node.merge({
        lhs: coerced_nodes[0],
        rhs: [coerced_nodes[0], coerced_nodes[1]]
      })
    end

    def visit_group(node)
      node.merge({
        lhs: left,
        rhs: right
      })
    end

    def visit_unary_not(node)
      node
    end

    def visit_function(function)
      # TODO Basic function validation


      # TODO Function specific validation
    end

    def coerce_if_necessary(all_nodes)
      types = all_nodes.map {|node| node[:type]}
      if types.uniq.size == 1
        return all_nodes
      else
        if types.all? { |type| NUMBER_TYPES.include?(type) }
          all_nodes.map do |node|
            if node[:type] == NUMBER_TYPES.first
              {
                name: :coerce,
                lhs: node,
                rhs: NUMBER_TYPES.first
              }
            else
              node
            end
          end
        elsif types.all? { |type| DATE_TYPES.include?(type )}
          all_nodes.map do |node|
            if node[:type] == DATE_TYPES.first
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
            message: "Type mismatch in comparison.",
            status: :fatal
          }
        end
      end
    end

    def numeric?(type)
      NUMBER_TYPES.include?(type)
    end

  end
end

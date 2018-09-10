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
      send(ast.visit_name, ast)
    end

    def errors
      @errors
    end

    def errors?
      @errors.size > 0
    end

    private

    # rubocop:disable Naming/MethodName
    def visit_Or(node)
      left = visit(node.left)
      right = visit(node.right)
      node.class.new(left, right)
    end

    def visit_Equal(node)
      left = visit(node.left)
      right = visit(node.right)
      node.class.new(left, right)
    end

    def visit_And(node)
      left = visit(node.left)
      right = visit(node.right)
      node.class.new(left, right)
    end

    def visit_Between(node)
      coerced_nodes = coerce_if_necessary([visit(node.left), visit(node.right[0]), visit(node.right[1])])
      node.class.new(coerced_nodes[0], [coerced_nodes[0], coerced_nodes[1]])
    end

    def coerce_if_necessary(all_nodes)
      types = all_nodes.map {|node| node.type}
      if types.uniq.size == 1
        return all_nodes
      else
        if types.all? { |type| NUMBER_TYPES.include?(type) }
          all_nodes.map do |node|
            if node.type == NUMBER_TYPES.first
              Sparkql::Nodes::Coerce.new(NUMBER_TYPES.first, node)
            else
              node
            end
          end
        elsif types.all? { |type| DATE_TYPES.include?(type )}
          all_nodes.map do |node|
            if node.type == DATE_TYPES.first
              Sparkql::Nodes::Coerce.new(DATE_TYPES.first, node)
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

    def visit_Identifier(node)
      if @metadata[node.value].nil?
        @errors << {}
      end
      node.class.new(node.value)
    end

    def visit_Literal(node)
      node.class.new(node.type, node.value)
    end

    def visit_GreaterThan(node)
      left = visit(node.left)
      right = visit(node.right)
      node.class.new(left, right)
    end

    def visit_GreaterThanOrEqualTo(node)
      left = visit(node.left)
      right = visit(node.right)
      node.class.new(left, right)
    end

    def visit_Group(node)
      node.class.new(node.value)
    end

    def visit_NotEqual(node)
      left = visit(node.left)
      right = visit(node.right)
      node.class.new(left, right)
    end

    def visit_Not(node)
      node
    end
    # rubocop:enable Naming/MethodName

  end
end

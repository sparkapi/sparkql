# Using an instance of ExpressionResolver to resolve the individual expressions,
# this class will evaluate the rest of a parsed sparkql string to true or false.
# Namely, this class will handle all the nesting, boolean algebra, and dropped
# fields. Plus, it has some optimizations built in to skip the processing for
# any expressions that don't contribute to the net result of the filter.
class Sparkql::Evaluator
  attr_reader :processed_count

  def initialize(expression_resolver)
    @resolver = expression_resolver
  end

  def evaluate(expressions)
    @processed_count = 0
    levels = {}
    block_groups = {}

    build_structures(levels, block_groups, expressions)

    final_result = process_structures(levels, block_groups)
    # If we didn't process anything, we consider that a success
    if final_result.nil?
      final_result = true
    end

    final_result
  end

  private

  # Take all the expressions and organize them into "chunks" appropriate for
  # evaluation. Each block group should process it's expressions, and every
  # block group injects itself as a placeholder expression in the block group a
  # level above it.
  #
  # When no block groups exist above, we must stub one out for processing.
  def build_structures(levels, block_groups, expressions)
    expressions.each do |expression|
      level = expression[:level]
      block = expression[:block_group]
      block_group = block_groups[block]

      if expression[:conjunction] == "Not" && expression[:conjunction_level] == level
        expression[:conjunction] = "And"
        expression[:unary] = "Not"
      end

      unless block_group
        block_groups[block] ||= block_builder(expression, level)
        block_group = block_groups[block]
        levels[level] ||= []
        levels[level] << block

        # When dealing with Not expression conjunctions at the block level,
        # it's far simpler to convert it into the equivalent "And Not"
        if block_group[:conjunction] == "Not"
          block_group[:unary] = "Not"
          block_group[:conjunction] = "And"
        end

        # Every block group _must_ be seen as an expression in another block
        # group.This aids in final resolution order when processing the levels
        #
        # This is even true if there's only one block group. We always end up
        # with a level -1 here to turn the top level expressions into a block
        # group for processing.
        current_level = level
        last_block_group = block_group
        while current_level >= 0
          current_level -= 1
          levels[current_level] ||= []
          last_block_group_id = levels[current_level].last
          if last_block_group_id
            block_groups[last_block_group_id][:expressions] << last_block_group
            break
          else
            block_id = "placeholder_for_#{block}_#{current_level}"
            placeholder_block = block_builder(last_block_group, current_level)
            placeholder_block[:expressions] << last_block_group

            levels[current_level] << block_id
            block_groups[block_id] = placeholder_block
            last_block_group = placeholder_block
          end
        end
      end

      block_group[:expressions] << expression
    end
  end

  # Starting from the deepest levels, we process block groups expressions and
  # reduce the block group to a result. This result is used in our placeholder
  # block groups at levels above, ending in a single final result.
  def process_structures(levels, block_groups)
    final_result = nil

    # Now go through each level starting with the deepest and working back up.
    levels.keys.sort.reverse.each do |level|
      # Process each block group  at this level and resolve the expressions in the group
      levels[level].each do |block|
        block_group = block_groups[block]

        block_result = nil
        block_group[:expressions].each do |expression|
          # If we encounter any or's in the same block group, we can cheat at
          # resolving the rest, if we are at a true
          if block_result && expression[:conjunction] == 'Or'
            break
          end

          expression_result = if expression.key?(:result)
                                # This is a reduced block group, just pass on
                                # the result
                                expression[:result]
                              else
                                @processed_count += 1
                                @resolver.resolve(expression) # true, false, :drop
                              end
          next if expression_result == :drop

          if expression[:unary] == "Not"
            expression_result = !expression_result
          end

          if block_result.nil?
            block_result = expression_result
            next
          end

          case expression[:conjunction]
          when 'Not'
            block_result &= !expression_result
          when 'And'
            block_result &= expression_result
          when 'Or'
            block_result |= expression_result
          else
            # Not a supported conjunction. We skip over this for backwards
            # compatibility.
          end
        end

        block_group.delete(:expressions)
        block_group[:result] = block_result
        final_result = block_result
      end
    end

    final_result
  end

  def block_builder(expressionable, level)
    {
      conjunction: expressionable[:conjunction],
      conjunction_level: expressionable[:conjunction_level],
      level: level,
      expressions: [],
      result: nil
    }
  end
end

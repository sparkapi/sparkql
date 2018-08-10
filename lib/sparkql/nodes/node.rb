module Sparkql
  module Nodes
    class Node
       def self.inherited(subclass)
         super
         visit_name = "visit_#{subclass.name.split('::').last}".to_sym
         subclass.send(:define_method, 'visit_name') { visit_name }
       end
    end
  end
end

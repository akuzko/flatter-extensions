module Flatter
  module Extensions
    module Order
      extend ::Flatter::Extension

      register_as :order

      mapper.add_option :index do
        def index
          options[:index] || 0
        end

        def mappers_chain(context)
          super.sort_by do |mapper|
            index = mapper.index
            index.is_a?(Hash) ? (index[context] || 0) : index
          end
        end
        private :mappers_chain
      end
    end
  end
end

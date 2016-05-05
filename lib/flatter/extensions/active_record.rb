module Flatter
  module Extensions
    module ActiveRecord
      extend ::Flatter::Extension

      module CallbacksControl
        def save_with_callbacks(callbacks)
          @_saving_callbacks = callbacks
          create_or_update
        ensure
          remove_instance_variable('@_saving_callbacks')
        end

        private

        def _run_save_callbacks
          return super unless defined? @_saving_callbacks
          @_saving_callbacks.include?(:save) ? super : yield
        end

        def _run_create_callbacks
          return super unless defined? @_saving_callbacks
          @_saving_callbacks.include?(:create) ? super : yield
        end

        def _run_update_callbacks
          return super unless defined? @_saving_callbacks
          @_saving_callbacks.include?(:update) ? super : yield
        end
      end

      register_as :active_record

      hooked do
        ::ActiveRecord::Base.send(:prepend, CallbacksControl)
        Flatter::Mapper::Collection::Concern.module_eval do
          alias build_collection_item_without_ar build_collection_item

          def build_collection_item
            return build_collection_item_without_ar unless mounter!.try(:ar?)

            mounter!.target.association(name.to_sym).try(:build) ||
              build_collection_item_without_ar
          end
        end
      end

      factory.extend do
        def default_target_from(mapper)
          return super unless mapper.ar?

          target_from_association(mapper.target) || super
        end
        private :default_target_from

        def target_from_association(target)
          reflection = reflection_from_target(target)

          return unless reflection.present?

          case reflection.macro
          when :has_one, :belongs_to
            target.public_send(name) || target.public_send("build_#{name}")
          when :has_many
            association = target.association(reflection.name)
            collection? ? association.load_target : association.build
          end
        end
        private :target_from_association

        def reflection_from_target(target)
          target_class = target.class
          reflection   = target_class.reflect_on_association(name.to_sym)
          reflection || target_class.reflect_on_association(name.pluralize.to_sym)
        end
        private :reflection_from_target
      end

      mapper.add_options :foreign_key, :mounter_foreign_key do
        extend ActiveSupport::Concern
        attr_reader :ar_error

        included do
          class_attribute :enabled_ar_callbacks
          self.enabled_ar_callbacks = []
        end

        class_methods do
          def enable_ar_callbacks(*callbacks)
            self.enabled_ar_callbacks += callbacks
            enabled_ar_callbacks.uniq!
          end

          def disable_ar_callbacks(*callbacks)
            self.enabled_ar_callbacks -= callbacks
          end

          alias enable_ar_callback enable_ar_callbacks
          alias disable_ar_callback disable_ar_callbacks
        end

        def apply(*)
          return super unless ar?

          !!::ActiveRecord::Base.transaction do
            super or raise ::ActiveRecord::Rollback
          end
        end

        def save
          !!::ActiveRecord::Base.transaction do
            begin
              @ar_error = nil
              super
            rescue ::ActiveRecord::StatementInvalid => e
              @ar_error = e
              raise ::ActiveRecord::Rollback
            end
          end
        end

        def delete_target_item(item)
          item.destroy! if ar?(item)
          super
        end

        def save_target
          return super unless ar?

          assign_foreign_keys_from_mountings

          result = target.save_with_callbacks(enabled_ar_callbacks)

          assign_foreign_keys_for_mountings if result

          result != false
        end
        protected :save_target

        def assign_foreign_keys_from_mountings
          associated_mountings(:mounter_foreign_key).each do |mounting|
            target[mounting.mounter_foreign_key] = mounting.target.id
          end
        end
        private :assign_foreign_keys_from_mountings

        def assign_foreign_keys_for_mountings
          associated_mountings(:foreign_key).each do |mounting|
            mounting.target[mounting.foreign_key] = target.id
          end
        end
        private :assign_foreign_keys_for_mountings

        def associated_mountings(key)
          root_mountings.select do |mounting|
            mounter = mounting.mounter
            mounter = mounter.mounter if mounter.trait?
            mounting.options.key?(key) && mounter == self
          end
        end
        private :associated_mountings

        def ar?(object = target)
          object.class < ::ActiveRecord::Base
        end
      end
    end
  end
end

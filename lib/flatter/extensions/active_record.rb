if defined? ActiveRecord
  module Flatter
    module Extensions
      module ActiveRecord
        extend ::Flatter::Extension

        module SkipCallbacks
          def save_without_callbacks
            @_saving_without_callbacks = true
            create_or_update
          ensure
            remove_instance_variable('@_saving_without_callbacks')
          end

          private

          def _run_save_callbacks
            @_saving_without_callbacks ? yield : super
          end

          def _run_create_callbacks
            @_saving_without_callbacks ? yield : super
          end

          def _run_update_callbacks
            @_saving_without_callbacks ? yield : super
          end
        end

        register_as :active_record

        depends_on :skipping

        hooked do
          ::ActiveRecord::Base.send(:prepend, SkipCallbacks)
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
              target.association(reflection.name).build
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
          def apply(*)
            return super unless ar?

            !!::ActiveRecord::Base.transaction do
              super or raise ::ActiveRecord::Rollback
            end
          end

          def save
            !!::ActiveRecord::Base.transaction do
              begin
                super
              rescue ::ActiveRecord::StatementInvalid
                raise ::ActiveRecord::Rollback
              end
            end
          end

          def save_target
            return super unless ar?

            assign_foreign_keys_from_mountings

            was_new = target.new_record?
            result = target.save_without_callbacks

            if result && was_new
              assign_foreign_keys_for_mountings
            end

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

          def skip!
            if ar?
              if target.new_record?
                target.instance_variable_set('@destroyed', true)
              else
                target.restore_attributes
              end
            end
            super
          end

          def ar?
            target.class < ::ActiveRecord::Base
          end
        end
      end
    end
  end
end

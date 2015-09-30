module Flatter
  module Extensions
    module Skipping
      extend ::Flatter::Extension

      register_as :skipping

      mapper.extend do
        def run_validations!
          if skipped?
            errors.clear
            true
          else
            super
          end
        end

        def run_save!
          skipped? ? true : super
        end

        def skip!
          @skipped = true
        end

        def skipped?
          !!@skipped
        end
      end
    end
  end
end

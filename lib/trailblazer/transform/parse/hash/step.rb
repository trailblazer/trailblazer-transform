module Trailblazer
  module Transform::Parse
    module Hash
      module Step
        module_function

        class Read
          def initialize(name:)
            @name = name
          end

                # We could use Representable here.
          def call(ctx, **)
            return unless ctx.key?(@name)
            ctx[:value] = ctx[@name]
            true
          end
        end
      end
    end
  end
end

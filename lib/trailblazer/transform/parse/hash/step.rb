module Trailblazer
  module Transform::Parse
    module Hash
      module Step # discuss: WHY STEP?
        module_function

        class Read
          def initialize(name:)
            @name = name
          end

          def ________________________call(ctx, document:, **)
            return unless document.key?(@name)
            ctx[:value] = document[@name]
            true
          end

          # note that we loose {fragment} here, which can be "saved" in a step before Read, if we need it. # DISCUSS
          def call(((_, my_state, data), flow_options), fragment:, **)
            return [ Activity::Left, [[_, my_state, data], flow_options] ] unless fragment.key?(@name)

            value = fragment[@name]

            return Activity::Right, [[value, my_state, data], flow_options]
          end

        end

        # Remember the originally read value.
        # so we can display it in the submitted form, for example.
        # this is an "optional" feature for a Reform-like API, but better.
        def track_read_value(((value, my_state, data), flow_options), **)
                      # "tracks history"
            my_state = my_state.merge( read_value: value )

          return Activity::Right, [[value, my_state, data], flow_options]
        end
      end
    end
  end
end

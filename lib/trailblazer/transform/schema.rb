module Trailblazer
  module Transform
    module Schema
      module_function

      # Create an activity to read, process and write a scalar property.
      # Write it to the passed {activity}.
      #
      # The activity looks as follows.
      #
      # [Read] -> [your process] -> [Write] -> End(:success)
      #   |             |--------------------> End(:failure)
      #   |
      #   -----------------------------------> End(:required)
      #
      # This activity is then added via `task Subprocess(<activity>)`.
      #
      # If the placement/wiring of automatically provided {activity} doesn't suit you,
      # use {:override}. # TODO, MORE DOCS.
      def property(activity, name, processor:, **options)
        flow = Module.new do
          extend Activity::Railway(name: name)

          step Parse::Hash::Step::Read.new(name: name), Output(:failure) => End(:required) # writes fragment to :{value}.
        pass Schema.method(:write_parsed)
          step Subprocess(processor)#, Output(:fail_fast) => "required"
          pass Transform::Process::Write.new(writer: "#{name}=")
        end

        insert(activity, name, processor: flow, **options)
      end

      def collection(activity, name, item_processor:, **options)
        processor = Transform::Process::Collection.new(activity: item_processor)

        property(activity, name, processor: processor, **options)
      end

      # private

      def insert(activity, name, processor:, override: nil, **options)
        return instance_exec(processor, &override) if override

        connections = {} # with empty connections, processor.success goes to the next property, everything else Ends.
        connections = { Activity::DSL::Helper::Output(:failure)  => Activity::DSL::Helper::Track(:success) ,
                        Activity::DSL::Helper::Output(:required) => Activity::DSL::Helper::Track(:success) } # "Reform-style": parse and validate all

        activity.task Activity::DSL::Helper::Subprocess( processor ), connections
      end
    end
  end
end

entity <expense>
  read # simply grab document
  process
  write # simply return


binding <price>
  scalar <price>
    read from { ..., price: 1 }
    process # coerce, validate
    return fragment, value

  model.price = value
  read.price = fragment # original data
  err.price = nil


binding <items>
  read from { items: [ .. ] }
  collection # collection logic wants to reuse as much scalar logic as possible.

    scalar <price>
      read from { ..., price: 1 }
      process # coerce, validate
      return fragment, value



  model.items = value
  read.items = fragment # original data
  err.items = nil

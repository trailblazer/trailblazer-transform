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
        flow = Binding(name, processor: processor)

        insert(activity, name, processor: flow, **options)
      end

      def collection(activity, name, item_processor:, **options)
        processor = Transform::Process::Collection.new(activity: item_processor)

        property(activity, name, processor: processor, **options)
      end

      require "trailblazer/context"
      def Binding(name, processor:, **options)
         flow = Module.new do
          extend Activity::Railway(name: name)

          # create a new "scope":
          step task: Binding.method(:scope)



          step Parse::Hash::Step::Read.new(name: name), Output(:failure) => End(:required) # writes fragment to :{value}.

          # "property"
          step ->(ctx, value:, **) { ctx[:read_fragment] = value; puts "@@@@@#{name} #{value.inspect}";true }
        # pass Schema.method(:write_parsed)

          pass Subprocess(processor), Output(:success) => Track(:success)#, Output(:fail_fast) => "required"
          # pass Transform::Process::Write.new(writer: "#{name}=")



          step task: Binding.method(:unscope)
        end
      end

      module Binding
        module_function

        # New context for a property.
        def scope((ctx, flow_options), **circuit_options)
          new_ctx = Trailblazer::Context(ctx)

          new_ctx[:document] = ctx[:value]

          return Trailblazer::Activity::Right, [new_ctx, flow_options], circuit_options
        end

        def unscope((new_ctx, flow_options), **circuit_options)
          ctx, scalar_values = new_ctx.decompose

# puts "#{name}@@@@@ #{scalar_values.inspect}" if name == :price

            # write
          ctx[name] = scalar_values

          return Trailblazer::Activity::Right, [ctx, flow_options], circuit_options
        end
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

=begin
write
  model.price = value
  read.price = fragment # original data
  err.price = nil

entity <expense>
  read # simply grab document
  process
  write # simply return


# entity == "nested property"

entity <invoice> # builds values, errors, (fragments) "populator"
  scalar <price>
    read from { price: { ... } } #=> fragment
    entity <price> # maintains values.amount, values.currency, errors.amount etc., original_values.amount, the "aggregate" ==> build the aggregate=populator
      scalar <amount> # don't write anything anywhere (value object, property)
        read from { ..., amount: 1 }
        process # coerce, validate
        return fragment, processed_value, error
      write #to the price "entity aggregate"

      scalar <currency>
        read from { ..., currency: :EUR }
        process # coerce, validate
        return fragment, processed_value, error
      write

    return processed_value <price entity>, errors <price entity.errors>
  write # to invoice entity



binding <items>
  read from { items: [ .. ] }
  collection # collection logic wants to reuse as much scalar logic as possible.

    scalar <price> # don't write anything anywhere (value object, property)
      read from { ..., price: 1 }
      process # coerce, validate
      return fragment, processed_value, error




  model.items = value
  read.items = fragment # original data
  err.items = nil
=end

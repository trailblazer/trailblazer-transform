module Trailblazer::Transform
  module Schema
    # Create an activity to read, process and write a scalar property.
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
    def property(name, processor:, **options)
      flow = Module.new do
        extend Trailblazer::Activity::Railway(name: name)

        step Parse::Hash::Step::Read.new(name: name), Output(:failure) => End(:required)
        step Subprocess(processor)#, Output(:fail_fast) => "required"
        pass Trailblazer::Transform::Process::Write.new(writer: "#{name}=")
      end

      insert(name, processor: flow, **options)
    end

    def collection(name, item_processor:, **options)
      processor = Trailblazer::Transform::Process::Collection.new(activity: item_processor)

      property(name, processor: processor, **options)
    end

    private

    def insert(name, processor:, override: nil, **options)
      return instance_exec(processor, &override) if override

      task Subprocess( processor )
    end
  end
end

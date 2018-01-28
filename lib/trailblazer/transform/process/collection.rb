module Trailblazer
  module Transform::Process
    class Collection
      # @param :activity The constant of the activity called per item in the dataset.
      def initialize(activity:)
        @activity = activity
      end

      def outputs
        Workflow.outputs # FIXME: can't we use Subprocess here?
      end
      # TODO: extend Interface

      def call( args, circuit_options )
        Workflow.( args, circuit_options.merge( activity: @activity) )
      end

      def self.run_instances( (ctx, flow_options), activity:, **circuit_options )
        ctx[:results] = ctx[:value].collect { |data| activity.( [{value: data}, flow_options], circuit_options ) }

        return Activity::Right, [ ctx, flow_options ]
      end

      def self.compute_end( (ctx, flow_options), ** )
        results = ctx[:results]

        was_success = !results.find { |(evt, _)| evt.to_h[:semantic] != :success }

        ctx[:value] = results.collect { |(evt, (ctx,_))| ctx[:value] }
        ctx[:error] = results.collect { |(evt, (ctx,_))| ctx[:error] }

        return was_success ? Activity::Right : Activity::Left , [ctx, flow_options]
      end

      # @needs :value
      # @gives :value
      module Workflow
        extend Activity::Railway()

        step task: Collection.method(:run_instances), id: "run_instances"
        step task: Collection.method(:compute_end),
          id: "compute_end" ,
          Output("FragmentBlank", :fragment_blank) => End(:fragment_blank) # not used, currently.
      end
    end
  end
end

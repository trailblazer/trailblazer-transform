require "test_helper"

class ProcessCollectionTest < Minitest::Spec
    # Collection
  #  ends:
  #   => FragmentNotFound/FragmentBlank
  #   => End.success
  #   => End.failure, invalid
  #
  #  interface
  #   ctx[:error] : array of errors
  #   ctx[:value] : array of collected results
  describe "Collection( PriceFloat )" do
    # this is the actual logic exected for each item:
    let(:instance) do
      Module.new do
        extend Trailblazer::Activity::Railway()

        step task: ->( (ctx, flow_options), ** ) do
          return Trailblazer::Activity::Right, [ctx, flow_options] if ctx[:value].is_a?(Integer)

          ctx[:error] = "#{ctx[:value].inspect} is wrong format"
          return Trailblazer::Activity::Left, [ctx, flow_options]
        end

        step task: ->( (ctx, flow_options), ** ) do
          ctx[:value] = ctx[:value] * 3

          return Trailblazer::Activity::Right, [ctx, flow_options]
        end
      end
    end

    let(:collection) { Trailblazer::Transform::Process::Collection.new( activity: instance ) }

    it "correct collection" do
      signal, (ctx, _) = collection.( [ { value: [9, 1] }, {} ], {} )

      assert_end collection, signal, :success
      ctx[:value].inspect.must_equal %{[27, 3]}
    end

    it "invalid collection`" do
      signal, (ctx, _) = collection.( [ { value: [9, "bla"] }, {} ], {} )

      assert_end collection, signal, :failure
      ctx[:value].inspect.must_equal %{[27, "bla"]}
      ctx[:error].inspect.must_equal %{[nil, "\\"bla\\" is wrong format"]}
    end

    # describe "Parse -> Collection( PriceFloat )" do
    #   let(:collection) do
    #     Module.new do
    #       extend Trailblazer::Activity::Railway()

    #       step Trailblazer::Transform::Parse::Hash::Step::Read.new(:items)
    #       Trailblazer::Transform::Process::Collection.new( activity: instance ) ) }
    #     end
    # end
  end
end

require "test_helper"

require "ostruct"

class TransformTest < Minitest::Spec

  module Transformer

  end

require "trailblazer/operation"

class Collection < Trailblazer::Operation
  def self.compute_end( (ctx, flow_options), ** )
    results = ctx[:results]

    was_success = !results.find { |(evt, _)| evt.class != Trailblazer::Operation::Railway::End::Success }

    ctx[:value] = results.collect { |(evt, (ctx,_))| ctx[:value] }
    ctx[:error] = results.collect { |(evt, (ctx,_))| ctx[:error] }

    return was_success ? Trailblazer::Activity::Right : Trailblazer::Activity::Left , [ctx, flow_options]
  end

  def self.run_instances( (ctx, flow_options), **circuit_options )
    ctx[:results] = ctx[:value].collect { |data| ctx[:instance].decompose.first.( [{value: data}, flow_options], circuit_options.merge( exec_context: ctx[:instance].new ) ) }

    return Trailblazer::Activity::Right, [ ctx, flow_options ]
  end

  step task: method(:run_instances), id: "run_instances"
  step( {:task => method(:compute_end),
    id: "compute_end" },
    {Output("FragmentBlank", :fragment_blank) => End(:fragment_blank, :fragment_blank)}, # not used, currently.
    )

end

class PriceFloat < Trailblazer::Operation
  step :filled?
  step :coerce_string # success: is string, fail: is nil
  fail :error_string, fail_fast: true # FragmentNotFound/FragmentBlank
  # step :empty?
  step :trim
  step :my_format
  fail :error_format
  step :coerce_float
  step :float_to_int # * 100

  def error_string(ctx, value:, **)
    ctx[:error] = "#{value.inspect} is blank string"
  end
  def error_format(ctx, value:, **)
    ctx[:error] = "#{value.inspect} is wrong format"
  end

  def filled?(ctx, value:, **)
    ! value.nil?
  end
  # TODO: use dry-types here
  def coerce_string(ctx, value:, **)
    value.to_s
  end

  def trim(ctx, value:, **)
    ctx[:value] = value.strip
  end

  def my_format(ctx, value:, **)
    value =~ /^\d\.\d$/
  end

  def coerce_float(ctx, value:, **)
    ctx[:value] = value.to_f
  end

  def float_to_int(ctx, value:, **)
    ctx[:value] = (value * 100).to_i
  end
end

module Steps
    # We could use Representable here.
  def parse(ctx, **)
    return unless ctx.key?(:unit_price)
    ctx[:value] = ctx[:unit_price]
    true
  end

  # I could be an End event, no step
  def error_required(ctx, **)
    ctx[:error] = "Fragment :unit_price not found"
    false
  end
  def error_format(ctx, value:, **)
    ctx[:error] = "#{value.inspect} is wrong format"
  end


  def set(ctx, value:, model:, **)
    model.unit_price = value
  end
end

# Normal configuration, like "property".
# This simply processes `hash[:unit_price]`.
class ExpenseUnitPrice < Trailblazer::Operation
  step :parse # sucess: fragment found
  fail :error_required, fail_fast: true # implies it wasn't sent! here, we could default

  step({task: ->((ctx, flow_options), **circuit_options) do
    PriceFloat.decompose.first.( [ctx, flow_options], circuit_options.merge( exec_context: PriceFloat.new ) )
  end, id: "PriceFloat"},
    PriceFloat.outputs[:fail_fast] => :fail_fast,
    PriceFloat.outputs[:failure] => :failure,
    PriceFloat.outputs[:success] => :success,
  )

  step :set

  # fail :parse_items_zero
  include Steps
end

# "custom" chainset
class UnitPriceOrItems < Trailblazer::Operation
  step :parse, fail_fast: true # sucess: fragment found
  step({task: ->((ctx, flow_options), **circuit_options) do
    PriceFloat.decompose.first.( [ctx, flow_options], circuit_options.merge( exec_context: PriceFloat.new ) )
  end, id: "PriceFloat"},
    PriceFloat.outputs[:fail_fast] => :fail_fast,
    PriceFloat.outputs[:failure] => :failure,
    PriceFloat.outputs[:success] => :success,
  )
  step :set, Output(:success) => "End.success"

  # this used to be implicit by placing `collection :items` after `property :unit_price`.
  step :items_present?, magnetic_to: [:fail_fast], fail_fast: true# success===> run Collection(PriceFloat), fail==>invalid, nothing given
  fail :error_required, magnetic_to: [:fail_fast], fail_fast: true

  step :collection_parse
  step({task: ->((ctx, flow_options), **circuit_options) do
    Collection.decompose.first.( [ctx, flow_options], circuit_options.merge( exec_context: Collection.new ) )
  end, id: "items"},
    # Collection.outputs[:fail_fast] => :fail_fast,
    Collection.outputs[:failure] => :failure,
    Collection.outputs[:success] => :success,
  )

  step :set_items


  include Steps

  def items_present?(ctx, **)
    return unless ctx.key?(:items)
    ctx[:items].size > 0
  end

  def error_required(ctx, **)
    ctx[:error] = "Fragment :unit_price not found, and no items"
    false
  end

  def collection_parse(ctx, **)
    ctx[:value] = ctx[:items]
  end

  def set_items(ctx, value:, model:, **)
    model.items = value
  end
end

  describe "UnitPriceOrItems" do
    let(:activity) { UnitPriceOrItems.decompose.first }

    it "fragment not found" do
      signal, (ctx, _) = activity.( [ { }, {} ], exec_context: UnitPriceOrItems.new )

      signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::FailFast} # FailFast signalizes "nothing found, for both paths"
      ctx[:error].must_equal %{Fragment :unit_price not found, and no items}
    end

    it ":unit_price given" do
      signal, (ctx, _) = activity.( [ { unit_price: " 2.7  ", model: OpenStruct.new }, {} ], exec_context: UnitPriceOrItems.new )

      signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::Success} # FailFast signalizes "nothing found, for both paths"
      ctx[:error].must_be_nil
      ctx[:model].inspect.must_equal %{#<OpenStruct unit_price=270>}
    end

    it "incorrect :unit_price" do
      signal, (ctx, _) = activity.( [ { unit_price: "999" }, {} ], exec_context: UnitPriceOrItems.new )

      signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::Failure} # FailFast signalizes "nothing found, for both paths"
      ctx[:error].must_equal %{"999" is wrong format}
    end

    it ":items given" do
      signal, (ctx, _) = activity.( [ { items: [ "9.9" ], model: OpenStruct.new, instance: PriceFloat }, {} ], exec_context: UnitPriceOrItems.new )
      # signal, (ctx, _) = activity.( [ { unit_price: "", items: [ "9.9" ], model: OpenStruct.new }, {} ], exec_context: UnitPriceOrItems.new )

      signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::Success} # FailFast signalizes "nothing found, for both paths"
      ctx[:model].inspect.must_equal %{#<OpenStruct items=[990]>}
      ctx[:error].must_be_nil
    end
  end

  # PriceFloat
  #  ends:
  #   => FragmentNotFound/FragmentBlank
  #   => End.success
  #   => End.failure, invalid
  #
  #  interface
  #   ctx[:error]
  #   ctx[:value]
  describe "PriceFloat" do
    let(:activity) { PriceFloat.decompose.first }

    it "fragment nil" do
      signal, (ctx, _) = activity.( [ { value: nil }, {} ], exec_context: PriceFloat.new )

      signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::FailFast}
      ctx[:error].must_equal %{nil is blank string}
    end

    it "wrong format" do
      signal, (ctx, _) = activity.( [ { value: " bla " }, {} ], exec_context: PriceFloat.new )

      signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::Failure}
      ctx[:error].must_equal %{"bla" is wrong format}
    end

    it "correct format" do
      signal, (ctx, _) = activity.( [ { value: "9.8" }, {} ], exec_context: PriceFloat.new )

      signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::Success}
      ctx[:value].must_equal 980
    end
  end

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
    let(:collection) { Collection.decompose.first }

    it "correct collection" do
      signal, (ctx, _) = collection.( [ { value: ["9.8", "1.2"], instance: PriceFloat } ], exec_context: Collection.new )

      signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::Success}
      ctx[:value].inspect.must_equal %{[980, 120]}
    end

    it "invalid collection" do
      signal, (ctx, _) = collection.( [ { value: ["9.8", "bla"], instance: PriceFloat } ], exec_context: Collection.new )

      signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::Failure}
      ctx[:value].inspect.must_equal %{[980, "bla"]}
      ctx[:error].inspect.must_equal %{[nil, "\\"bla\\" is wrong format"]}
    end
  end

  # ExpenseUnitPrice
  #  ends:
  #   => End.fail_fast => FragmentNotFound/FragmentBlank
  #   => End.success
  #   => End.failure, invalid
  #
  #  interface
  #   ctx[:error]
  #   ctx[:value]
  let(:activity) { ExpenseUnitPrice.decompose.first }

  it "fragment not found" do
    signal, (ctx, _) = activity.( [ { }, {} ], exec_context: ExpenseUnitPrice.new )

    signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::FailFast}
    ctx[:error].must_equal %{Fragment :unit_price not found}
  end

  it "fragment nil" do
    signal, (ctx, _) = activity.( [ { unit_price: nil }, {} ], exec_context: ExpenseUnitPrice.new )

    signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::FailFast}
    ctx[:error].must_equal %{nil is blank string}
  end

  it "wrong format" do
    signal, (ctx, _) = activity.( [ { unit_price: " bla " }, {} ], exec_context: ExpenseUnitPrice.new )

    signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::Failure}
    ctx[:error].must_equal %{"bla" is wrong format}
  end

  it "correct format" do
    signal, (ctx, _) = activity.( [ { unit_price: "9.8", model: OpenStruct.new }, {} ], exec_context: ExpenseUnitPrice.new )

    signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::Success}
    ctx[:model].inspect.must_equal %{#<OpenStruct unit_price=980>}
  end

=begin

# Reform was too declarative. No dynamic checks, etc, and too much implicit behavior (like parsing/populator)
# Reform: mix of representable and its own chains, hard to extend. Let's keep the "steps" but rewire them.
# The problem: a coercion _is_ a validation, but without an error msg etc, so why not simply chain it using
# the Activity mechanics that we already have?
# Much much more explicit than Reform
#
# no hard-to-learn DSL, but this all translates to TRB mechanics
#
# :value in the end is immutable graph with all coerced objects/scalars
#
# transform only handles UI/doc==>sane domain struct with error messages and originals. how to get that into the DB is up to you (coming soon!)

  # In the UI, we want the "Reform style" where an object graph represents the form UI
  class Transformer::UI # this is the document coming in
    property :target

    property :unit_price

    collection :items do
      property :unit_price
      property :vat
    end
  end


  class Transformer::Logic
    &parse(:unit_price)
      &nilify
      #/
      &trim
        &my_format?( /,\d{1,2}$/ ) # 1,23 or 1.004,56
          &coerce Float
            # all good
            & float * 100
        !error("wrong format")
      &set :unit_price # domain_model.unit_price = float
    #/
    &parse(:items)[0]
  end
=end

end

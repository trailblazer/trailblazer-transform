require "test_helper"

require "ostruct"

class TransformTest < Minitest::Spec

  Parse = Trailblazer::Transform::Parse

require "trailblazer/activity"

Activity = Trailblazer::Activity



# ::property
# @needs :value
module PriceFloat
  extend Activity::FastTrack()
  module_function

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

  step method(:filled?)
  step method(:coerce_string) # success: is string, fail: is nil
  fail method(:error_string), fail_fast: true # FragmentNotFound/FragmentBlank
  # step :empty?
  step method(:trim)
  step method(:my_format) # this is where Dry-v comes into play?
  fail method(:error_format)
  step method(:coerce_float)
  step method(:float_to_int) # * 100
end

module Steps
  module_function
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



  def self.set(ctx, value:, model:, **)
    model.unit_price = value
  end

    # I could be an End event, no step
  def self.error_required(ctx, **)
    ctx[:error] = "Fragment :unit_price not found"
    false
  end
end

# Normal configuration, like "property".
# This simply processes `hash[:unit_price]`.
# @needs :document
# @needs :model
# @gives :value
module DeserializeUnitPrice
  extend Activity::FastTrack()

  step Parse::Hash::Step::Read.new(name: :unit_price) # sucess: fragment found
  fail Steps.method(:error_required), fail_fast: true # implies it wasn't sent! here, we could default

  step Subprocess(PriceFloat), id: "PriceFloat"

  step Steps.method(:set)

  # fail :parse_items_zero
end

# "custom" chainset
class UnitPriceOrItems
  extend Activity::FastTrack()

  def self.items_present?(ctx, document:, **)
    return unless document.key?(:items)
    document[:items].size > 0
  end

  def self.set_items(ctx, value:, model:, **)
    model.items = value
  end

  step Parse::Hash::Step::Read.new(name: :unit_price), fail_fast: true # sucess: fragment found
  step task: PriceFloat, id: "PriceFloat",
    PriceFloat.outputs[:fail_fast] => :fail_fast,
    PriceFloat.outputs[:failure] => :failure,
    PriceFloat.outputs[:success] => :success

  step Steps.method(:set), Output(:success) => "End.success"

  # this used to be implicit by placing `collection :items` after `property :unit_price`.
  step method(:items_present?), magnetic_to: [:fail_fast], fail_fast: true# success===> run Collection(PriceFloat), fail==>invalid, nothing given
  fail :error_required, magnetic_to: [:fail_fast], fail_fast: true

  step Parse::Hash::Step::Read.new(name: :items)
  # step({task: ->((ctx, flow_options), **circuit_options) do
  #   Collection.( [ctx, flow_options], circuit_options )
  # end, id: "items"},
  #   # Collection.outputs[:fail_fast] => :fail_fast,
  #   Collection.outputs[:failure] => :failure,
  #   Collection.outputs[:success] => :success,
  # )

  step method(:set_items)


  include Steps


  def error_required(ctx, **)
    ctx[:error] = "Fragment :unit_price not found, and no items"
    false
  end

end

  describe "UnitPriceOrItems" do
    it "fragment not found" do
      signal, (ctx, _) = UnitPriceOrItems.( [ { document: {} }, {} ] )

      signal.to_h[:semantic].must_equal :fail_fast # FailFast signalizes "nothing found, for both paths"
      ctx[:error].must_equal %{Fragment :unit_price not found, and no items}
    end

    it ":unit_price given" do
      signal, (ctx, _) = UnitPriceOrItems.( [ { document: { unit_price: " 2.7  " }, model: OpenStruct.new }, {} ] )

      signal.to_h[:semantic].must_equal :success # FailFast signalizes "nothing found, for both paths"
      ctx[:error].must_be_nil
      ctx[:model].inspect.must_equal %{#<OpenStruct unit_price=270>}
    end

    it "incorrect :unit_price" do
      signal, (ctx, _) = UnitPriceOrItems.( [ {document: { unit_price: "999" }}, {} ] )

      signal.to_h[:semantic].must_equal :failure # FailFast signalizes "nothing found, for both paths"
      ctx[:error].must_equal %{"999" is wrong format}
    end

    it ":items given" do
      signal, (ctx, _) = UnitPriceOrItems.( [ { document: {items: [ "9.9" ]}, model: OpenStruct.new, instance: PriceFloat }, {} ] )
      # signal, (ctx, _) = activity.( [ { unit_price: "", items: [ "9.9" ], model: OpenStruct.new }, {} ], exec_context: UnitPriceOrItems.new )

      signal.to_h[:semantic].must_equal :success # FailFast signalizes "nothing found, for both paths"
      ctx[:model].inspect.must_equal %{#<OpenStruct items=[990]>}
      ctx[:error].must_be_nil
    end
  end

class Item
  extend Activity::Railway()

  def self.populator(ctx, **)
    ctx[:model] = Struct.new(:unit_price).new
  end

  def self.model(ctx, model:, **)
    model.freeze
    ctx[:value] = model
  end

  pass ->(ctx, value:, **) { ctx[:document] = value } # discuss: THIS SUCKS!
  step method(:populator)
  # property :unit_price

  # @needs :document
  step Subprocess( DeserializeUnitPrice ), id: "deserialize_unit_price"

  step method(:model)
end




  # "custom" chainset with items that are nested, again.
class UnitPriceOrNestedItems
  extend Activity::FastTrack()

  def self.error_required(ctx, **)
    ctx[:error] = "Fragment :unit_price not found, and no items"
    false
  end

  def self.set_items(ctx, value:, model:, **)
    pp ctx
    model.items = value
  end


  step Parse::Hash::Step::Read.new(name: :unit_price), fail_fast: true # sucess: fragment found
  step task: PriceFloat, id: "PriceFloat",
    PriceFloat.outputs[:fail_fast] => :fail_fast,
    PriceFloat.outputs[:failure] => :failure,
    PriceFloat.outputs[:success] => :success
  step Steps.method(:set), Output(:success) => "End.success"

  # this used to be implicit by placing `collection :items` after `property :unit_price`.
  step UnitPriceOrItems.method(:items_present?), magnetic_to: [:fail_fast], fail_fast: true# success===> run Collection(PriceFloat), fail==>invalid, nothing given
  fail method(:error_required), magnetic_to: [:fail_fast], fail_fast: true

  # read :items
  step Parse::Hash::Step::Read.new(name: :items)

  step Subprocess( Trailblazer::Transform::Process::Collection.new(activity: Item) ), id: "items"


  step method(:set_items)
end

module UnitPriceOrNestedItems2
  extend Activity::Path()

  task Parse::Hash::Step::Read.new(name: :unit_price), Output(Trailblazer::Activity::Left, :failure) => :items_track
  task task: PriceFloat, PriceFloat.outputs[:fail_fast] => :items_track, PriceFloat.outputs[:failure] => :failure
  task Steps.method(:set)

  task UnitPriceOrItems.method(:items_present?), magnetic_to: [:items_track], Output(:success) => :items_track, Output(Trailblazer::Activity::Left, :failure) => :required
  task Parse::Hash::Step::Read.new(name: :items), magnetic_to: [:items_track], Output(:success) => :items_track, Output(Trailblazer::Activity::Left, :failure) => :failure
  task "Collection", magnetic_to: [:items_track], Output(:success) => :items_track, Output(Trailblazer::Activity::Left, :failure) => :failure
  task UnitPriceOrNestedItems.method(:set_items), magnetic_to: [:items_track]

  task UnitPriceOrNestedItems.method(:error_required), magnetic_to: [:required], Output(:success) => :required

  task task: End(:failure), magnetic_to: [:failure], type: :End
  task task: End(:required), magnetic_to: [:required], type: :End
end

puts Trailblazer::Activity::Introspect.Cct(UnitPriceOrNestedItems2.to_h[:circuit])

=begin
property :unit_price
  Read(:unit_price) (key?)
  PriceFloat        (value.nil?)
  set

collection :items
  Read(:items)      (key?)
  Collection
  set_items
=end

module UnitPriceOrNestedItems3
  extend Activity::Path()

  module_function
  def items_present?(ctx, document:, **)
    return unless document.key?(:items)
    document[:items].size > 0
  end

  # property :unit_price
  task Parse::Hash::Step::Read.new(name: :unit_price), Output(Trailblazer::Activity::Left, :failure) => Path( track_color: :items_track ) do
    task UnitPriceOrNestedItems3.method(:items_present?), Output(Trailblazer::Activity::Left, :failure) => :required, id: "items_present?"

    # collection :items, populator:  do                         DeserializeItems
    task Parse::Hash::Step::Read.new(name: :items), Output(Trailblazer::Activity::Left, :failure) => :failure
    task Subprocess( Trailblazer::Transform::Process::Collection.new(activity: Item) ), Output(Trailblazer::Activity::Left, :failure) => :failure
    task Trailblazer::Transform::Process::Write.new(writer: :items=), Output(:success) => "End.success"

  end

  task Subprocess(PriceFloat), Output(:fail_fast) => "items_present?", Output(:failure) => :failure
  task Trailblazer::Transform::Process::Write.new(writer: :unit_price=)


  task UnitPriceOrNestedItems.method(:error_required), magnetic_to: [:required], Output(Trailblazer::Activity::Left, :failure) => :required

  task task: End(:failure),  magnetic_to: [:failure], type: :End
  task task: End(:required), magnetic_to: [:required], type: :End
end

module UnitPriceOrNestedItems4
  module PropertyUnitPrice
    extend Activity::Railway()

    step Parse::Hash::Step::Read.new(name: :unit_price), Output(:failure) => End(:required)
    step Subprocess(PriceFloat), Output(:fail_fast) => "required"
    step Trailblazer::Transform::Process::Write.new(writer: :unit_price=)
  end

  module CollectionItems
    extend Activity::Railway()

    step Parse::Hash::Step::Read.new(name: :items), Output(:failure) => :failure
    step Subprocess( Trailblazer::Transform::Process::Collection.new(activity: Item) ), Output(:failure) => :failure
    step Trailblazer::Transform::Process::Write.new(writer: :items=), Output(:success) => "End.success"
  end

  extend Activity::Path()

  task Subprocess( PropertyUnitPrice ) # success/failure/required

  task UnitPriceOrNestedItems3.method(:items_present?), Output(Trailblazer::Activity::Left, :failure) => :required, magnetic_to: [:required]

  task Subprocess( CollectionItems )#, magnetic_to: [:required]

  task task: End(:failure),  magnetic_to: [:failure], type: :End
  task task: End(:required), magnetic_to: [:required], type: :End
end

# it { UnitPriceOrNestedItems2.to_h[:circuit].must_equal UnitPriceOrNestedItems3.to_h[:circuit] }

puts Trailblazer::Activity::Introspect.Cct(UnitPriceOrNestedItems4.to_h[:circuit])

  describe "UnitPriceOrNestedItems" do
    it "fragment not found" do
      signal, (ctx, _) = UnitPriceOrNestedItems4.( [ { document: {} }, {} ] )

      signal.to_h[:semantic].must_equal :required # FailFast signalizes "nothing found, for both paths"
      ctx[:error].must_equal %{Fragment :unit_price not found, and no items}
    end

    it ":unit_price given" do
      signal, (ctx, _) = UnitPriceOrNestedItems4.( [ { document: {unit_price: " 2.7  "}, model: OpenStruct.new }, {} ] )

      signal.to_h[:semantic].must_equal :success # FailFast signalizes "nothing found, for both paths"
      ctx[:error].must_be_nil
      ctx[:model].inspect.must_equal %{#<OpenStruct unit_price=270>}
    end

    it "incorrect :unit_price" do
      signal, (ctx, _) = UnitPriceOrNestedItems4.( [ {document: { unit_price: "999" }}, {} ] )

      signal.to_h[:semantic].must_equal :failure # FailFast signalizes "nothing found, for both paths"
      ctx[:error].must_equal %{"999" is wrong format}
    end

    it ":items given" do
      signal, (ctx, _) = UnitPriceOrNestedItems4.( [ {document: { items: [ {unit_price: "9.9"} ] }, model: OpenStruct.new }, {} ] )

      signal.to_h[:semantic].must_equal :success # FailFast signalizes "nothing found, for both paths"
      ctx[:model].inspect.must_equal %{#<OpenStruct items=[#<struct unit_price=990>]>}
      ctx[:error].must_equal [nil]
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
    it "fragment nil" do
      signal, (ctx, _) = PriceFloat.( [ { value: nil }, {} ] )

      assert_end PriceFloat, signal, :fail_fast
      ctx[:error].must_equal %{nil is blank string}
    end

    it "wrong format" do
      signal, (ctx, _) = PriceFloat.( [ { value: " bla " }, {} ] )

      assert_end PriceFloat, signal, :failure
      ctx[:error].must_equal %{"bla" is wrong format}
    end

    it "correct format" do
      signal, (ctx, _) = PriceFloat.( [ { value: "9.8" }, {} ] )

      assert_end PriceFloat, signal, :success
      ctx[:value].must_equal 980
    end
  end

  # DeserializeUnitPrice
  #  ends:
  #   => End.fail_fast => FragmentNotFound/FragmentBlank
  #   => End.success
  #   => End.failure, invalid
  #
  #  interface
  #   ctx[:error]
  #   ctx[:value]
  it "fragment not found" do
    signal, (ctx, _) = DeserializeUnitPrice.( [ { document: {} }, {} ] )

    signal.to_h[:semantic].must_equal :fail_fast
    ctx[:error].must_equal %{Fragment :unit_price not found}
  end

  it "fragment nil" do
    signal, (ctx, _) = DeserializeUnitPrice.( [ {document: { unit_price: nil }}, {} ] )

    signal.to_h[:semantic].must_equal :fail_fast
    ctx[:error].must_equal %{nil is blank string}
  end

  it "wrong format" do
    signal, (ctx, _) = DeserializeUnitPrice.( [ { document: { unit_price: " bla " } }, {} ] )

    signal.to_h[:semantic].must_equal :failure
    ctx[:error].must_equal %{"bla" is wrong format}
  end

  it "correct format" do
    signal, (ctx, _) = DeserializeUnitPrice.( [ { document: { unit_price: "9.8"}, model: OpenStruct.new }, {} ] )

    signal.to_h[:semantic].must_equal :success
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



  problem with UPDATE is, we always have to check all fields, and hence "require" all fields to be filled out.
  Even if it's just a partial update, which in JSON would produce a smaller subset document, we need to go through all
  fields. That's why web forms suck (without JS)
=end

end

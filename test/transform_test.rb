require "test_helper"

class TransformTest < Minitest::Spec

  module Transformer

  end

require "trailblazer/operation"

class ExpenseUnitPrice < Trailblazer::Operation
  step :parse # sucess: fragment found
  fail :error_required, fail_fast: true # implies it wasn't sent! here, we could default

  step :coerce_string # success: is string, fail: is nil
  fail :error_string, fail_fast: true
  # step :empty?
  step :trim
  step :my_format
  fail :error_format
  step :coerce_float
  step :float_to_int # * 100

  step :set

  # fail :parse_items_zero


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
  def error_string(ctx, value:, **)
    ctx[:error] = "#{value.inspect} is no string"
  end
  def error_format(ctx, value:, **)
    ctx[:error] = "#{value.inspect} is wrong format"
  end

  # TODO: use dry-types here
  def coerce_string(ctx, value:, **)
    return if value.nil?
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

  def set(ctx, value:, model:, **)
    model.unit_price = value
  end
end

  let(:activity) { ExpenseUnitPrice.decompose.first }

  it "fragment not found" do
    signal, (ctx, _) = activity.( [ { }, {} ], exec_context: ExpenseUnitPrice.new )

    signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::FailFast}
    ctx[:error].must_equal %{Fragment :unit_price not found}
  end

  it "fragment nil" do
    signal, (ctx, _) = activity.( [ { unit_price: nil }, {} ], exec_context: ExpenseUnitPrice.new )

    signal.class.inspect.must_equal %{Trailblazer::Operation::Railway::End::FailFast}
    ctx[:error].must_equal %{nil is no string}
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

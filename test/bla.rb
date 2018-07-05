require "test_helper"
require_relative "flow_test"

module Trailblazer::Transform
  class Entity # aggregate
  end
end

class BlaTest < Minitest::Spec
  amount = Transform::Schema.Binding(:amount, processor: FlowTest::Amount)
  currency = Transform::Schema.Binding(:currency, processor: FlowTest::Amount)

  # pp amount.( {document: { amount: "9.1", currency: "1.2" }} )

  price_entity = Module.new do
    extend Trailblazer::Activity::Railway(name: :price)

    pass Subprocess(amount)
    pass Subprocess(currency)
  end

  price_scalar = Transform::Schema.Binding(:price, processor: price_entity)
  # price_scalar = Transform::Schema.Binding(:price, processor: entity)

  amounts_scalar = Transform::Schema.Binding(:amounts, processor: Transform::Process::Collection.new(activity: FlowTest::Amount))
  figures_scalar = Transform::Schema.Binding(:figures, processor: Transform::Process::Collection.new(activity: price_entity))

  # the "real" invoice
  invoice_entity = Module.new do
    extend Trailblazer::Activity::Railway(name: :price)

    pass Subprocess(price_scalar)
    pass Subprocess(currency)
    pass Subprocess(amounts_scalar)
    pass Subprocess(figures_scalar)
  end

  pp invoice_entity.({value: {price: {amount: "9.1", currency: "1.2"}, currency: "8.1",
    amounts: ["1.1", "2.1"],
    figures: [{amount: "3.4", currency: "5.6"}, {amount: "9.1", currency: "7.8"}]
     }}
  )
raise

  price_entity = Transform::Entity.new(
    [
      Transform::Schema.Binding(:amount, processor: FlowTest::Amount),
      Transform::Schema.Binding(:menge, processor: FlowTest::Amount)
    ]
  )
  # returns a "price object (parsed, value, msg)"

  invoice_entity = Transform::Entity.new(
    [
      Transform::Schema.Binding(:price, processor: price_entity),
    ]
  )

  document = {
    amount: "1.2",
    menge: "9.9",
  }

puts "yo"
  pp invoice_entity.([{fragment: document}], {})
 #{:parsed_fragments=>
 #  {#<Trailblazer::Activity: {amount}>=>"1.2",
 #   #<Trailblazer::Activity: {menge}>=>"9.9"},
 # :values=>
 #  {#<Trailblazer::Activity: {amount}>=>120,
 #   #<Trailblazer::Activity: {menge}>=>990},
 # :messages=>
 #  {#<Trailblazer::Activity: {amount}>=>
 #    #<Dry::Validation::Result output={:value=>"1.2"} errors={}>,
 #   #<Trailblazer::Activity: {menge}>=>
 #    #<Dry::Validation::Result output={:value=>"9.9"} errors={}>}}
end

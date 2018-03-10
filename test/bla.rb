require "test_helper"
require_relative "flow_test"

module Trailblazer::Transform
  class Entity # aggregate
  end
end

class BlaTest < Minitest::Spec

  def self.process_amount(((value, my_state, data), flow_options), **)
    value = value.sub(",", ".")
    value = value.to_f

    my_state = my_state.merge(message: {})

    return Trailblazer::Activity::Right, [ [value, my_state, data], flow_options ]
  end

  def self.finalize(((value, my_state, data), flow_options), **)
    my_state = my_state.merge( value: value )

                                                # DISCUSS.
    return Trailblazer::Activity::Right, [ [my_state, my_state, data], flow_options ]
  end
                        # FIXME
  def self.write(name, ((state, _, data), flow_options), **)
    data = data.merge( name => state )

    return Trailblazer::Activity::Right, [ [state, _, data], flow_options ]
  end

  document = {
    price: {
      amount:   "9,1",
      currency: "1.2"
    },
    currency: "8.1",
    amounts: ["1.1", "2.1"],
    figures: [
      {
        amount: "3.4",
        currency: "5.6"
      },
      {
        amount: "9.1",
        currency: "7.8"
      }
    ]
  }

  # fragment        = document[:price] #
  data            = {}

# :price
  your_state      = {}.freeze
  circuit_options = { fragment: document }.freeze

signal, res = Transform::Parse::Hash::Step::Read.new(name: :price).( [ [nil, your_state, data], {}], circuit_options )
signal, res = Transform::Parse::Hash::Step.method(:track_read_value).( res, circuit_options )

pp res; raise
  # :amount
  signal, res = Transform::Parse::Hash::Step::Read.new(name: :amount).( [ [nil, your_state, data], {}], circuit_options )
  signal, res = Transform::Parse::Hash::Step.method(:track_read_value).( res, circuit_options )
  signal, res = process_amount( res, circuit_options )
  signal, res = finalize( res, circuit_options )
  signal, res = write(:amount, res, circuit_options )
  # :currency
  signal, res = Transform::Parse::Hash::Step::Read.new(name: :currency).( res, circuit_options )
  signal, res = Transform::Parse::Hash::Step.method(:track_read_value).( res, circuit_options )
  signal, res = process_amount( res, circuit_options )
  signal, res = finalize( res, circuit_options )
  signal, res = write(:currency, res, circuit_options )

  puts "hallo@"
  pp res
exit





  amount = Transform::Schema.Binding(:amount, processor: FlowTest::Amount)
  currency = Transform::Schema.Binding(:currency, processor: FlowTest::Amount)

  # pp amount.( {document: { amount: "9.1", currency: "1.2" }} )

  fragment   = document[:price]
  your_state = {}.freeze

  pp amount.( [ [fragment, your_state, { document: document }], {}], **{} )



  price_entity = Module.new do
    extend Trailblazer::Activity::Railway(name: :price)

    pass Subprocess(amount)
    pass Subprocess(currency)
  end

  price_binding = Transform::Schema.Binding(:price, processor: price_entity)
  # price_binding = Transform::Schema.Binding(:price, processor: entity)








  amounts_scalar = Transform::Schema.Binding(:amounts, processor: Transform::Process::Collection.new(activity: FlowTest::Amount) )
  figures_scalar = Transform::Schema.Binding(:figures, processor: Transform::Process::Collection.new(activity: price_entity) )

  # the "real" invoice
  invoice_entity = Module.new do
    extend Trailblazer::Activity::Railway(name: :price)

    pass Subprocess( price_binding )
    pass Subprocess( currency )
    pass Subprocess( amounts_scalar )
    pass Subprocess( figures_scalar )
  end

  pp invoice_entity.( {value: { price:{ amount: "9.1", currency: "1.2" }, currency: "8.1",
    amounts: ["1.1", "2.1"],
    figures: [ { amount: "3.4", currency: "5.6" }, { amount: "9.1", currency: "7.8" }  ]
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
      Transform::Schema.Binding(:price, processor: price_entity ),
    ]
  )



  document = {
    amount: "1.2",
    menge: "9.9",
  }

puts "yo"
  pp invoice_entity.( [{fragment: document}], {} )
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

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

    if value == 9.1
      my_state = my_state.merge(message: {nine: true})
    else
      my_state = my_state.merge(message_: {})
    end

    return Trailblazer::Activity::Right, [ [value, my_state, data], flow_options ]
  end
                        # FIXME
  def self.write(name, ((value, my_state, data), flow_options), **)
    data = data.merge( name => [value, my_state] )

    return Trailblazer::Activity::Right, [ [value, my_state, data], flow_options ]
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


  def prepare(fragment)

  end

  # fragment        = document #
your_state      = {}.freeze
data            = {}
circuit_options = { fragment: document }.freeze


# :price
# price_state      = {}.freeze

# signal, res = Transform::Parse::Hash::Step::Read.new(name: :price).( [ [nil, price_state, data], {}], circuit_options )
# signal, res = Transform::Parse::Hash::Step.method(:track_read_value).( res, circuit_options )

# pp res; raise
  fragment        = document[:price] #
 circuit_options = { fragment: fragment, data: data }.freeze

  # pp circuit_options

  # :amount
 your_state      = {}.freeze
 # data            = res[0][2]
 data            = {}
  signal, res = Transform::Parse::Hash::Step::Read.new(name: :amount).( [ [nil, your_state, data], {}], circuit_options )
  signal, res = Transform::Parse::Hash::Step.method(:track_read_value).( res, circuit_options )
  signal, res = process_amount( res, circuit_options )
 signal, res = write(:amount, res, circuit_options )

  # :currency
 your_state      = {}.freeze
 data            = res[0][2]
  signal, res = Transform::Parse::Hash::Step::Read.new(name: :currency).( [ [nil, your_state, data], {}], circuit_options )
  signal, res = Transform::Parse::Hash::Step.method(:track_read_value).( res, circuit_options )
  signal, res = process_amount( res, circuit_options )
 signal, res = write(:currency, res, circuit_options )

  # {data} is now representing the "collect { amount, currency }"

 # data for {price}
 data = circuit_options[:data]

 res = [
  [
   res[0][2],
   {price_status: "eh"},
   data # price data
  ],
  res[1]
 ]



 # res = [ [res[0][2], {}, {}], res[1] ]

# signal, res = finalize( res, circuit_options )
signal, res = write(:price, res, circuit_options )


  puts "hallo@"
  pp res
raise





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

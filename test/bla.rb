require "test_helper"
require_relative "flow_test"

module Trailblazer::Transform
  class Entity # aggregate
    def initialize(properties)
      @properties = properties
    end

    # def call(fragment, form = { parsed_fragments:{}, values:{}, messages:{} }) # is this the "populator"?
    def call( (ctx, _), *) # is this the "populator"?
      fragment = ctx[:fragment]
      form     = { parsed_fragments:{}, values:{}, messages:{} } # "form" object


      @properties.each do |scalar|
        # scalar <amount>
        signal, (ctx, _) = scalar.( document: fragment )

        parsed_fragments, value, message = ctx[:read_fragment], ctx[:value], ctx[:schema_result]



        # write
        #
        # das ding merget sich in einen hash, kennt aber nicht seinen key
        form = form.merge(
          parsed_fragments: form[:parsed_fragments].merge( scalar => parsed_fragments ),
          values:           form[:values].merge( scalar => value ),
          messages:         form[:messages].merge( scalar => message ),
        )
      end

      { value: form[:values], parsed_fragments: form[:parsed_fragments] }
    end

    def outputs
      {  }
    end #FIXME
  end


end

class BlaTest < Minitest::Spec

  amount = Transform::Schema.Scalar(:amount, processor: FlowTest::Amount)
  currency = Transform::Schema.Scalar(:currency, processor: FlowTest::Amount)

  # pp amount.( {document: { amount: "9.1", currency: "1.2" }} )



  entity = Module.new do
    extend Trailblazer::Activity::Railway(name: :price)

    pass Subprocess(amount)
    pass Subprocess(currency)
  end

  price_scalar = Transform::Schema.Scalar(:price, processor: entity)

  pp price_scalar.( {value: { price:{ amount: "9.1", currency: "1.2" }}} )
raise




  price_entity = Transform::Entity.new(
    [
      Transform::Schema.Scalar(:amount, processor: FlowTest::Amount),
      Transform::Schema.Scalar(:menge, processor: FlowTest::Amount)
    ]
  )
  # returns a "price object (parsed, value, msg)"

  invoice_entity = Transform::Entity.new(
    [
      Transform::Schema.Scalar(:price, processor: price_entity ),
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

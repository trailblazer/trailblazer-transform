
# Price.() #        { read_fragment: { amount: "9,1" }, value: {
#  Amount.()    #     amount: { read_fragment: "9,1", value: 9.1 },
#  Currency.()



Processed = Struct.new(:fragment, :value)
Fragment = Struct.new(:parse)
Value = Struct.new(:content)

def entity(document)
  Fragment.new(document)
end

def read_amount(fragment) # <Fragment>
  Value.new(fragment.parse[:amount])
end

def process_amount(value) # <Value>
  Processed.new(value, value.content.to_f)
end

def read_currency(fragment) # <Fragment>
  Value.new(fragment.parse[:currency])
end

def process_currency(value) # <Value>
  Processed.new(value, value.content.to_sym)
end


def read_price(fragment)
  Value.new(fragment.parse[:price])
end
def process_price(fragment)
  bla = price_entity_processor(fragment, {})

  Processed.new(fragment, bla)
end

# entity iterates bindings
#  binding can be "nested" or scalar thing
#  binding always returns Processed structure
#
def price_entity_processor(fragment, entity_processed) # { name: <Processed>}
 # binding?
  value     = read_amount( fragment.content )                       # read
  processed = process_amount( value )
  entity_processed = entity_processed.merge( {amount: processed})   # write


  value     = read_currency( fragment.content )
  processed = process_currency( value )

  entity_processed = entity_processed.merge( {currency: processed})

  entity_processed
end


def process_invoice(value)
  bla = invoice_entity_processor(value, {})

  Processed.new(value, bla)
end

def invoice_entity_processor(fragment, entity_processed) # { name: <Processed>}
  value     = read_price( fragment.content )                      # read
  processed = process_price( value )
  entity_processed = entity_processed.merge( {price: processed})  # write

  value     = read_items( fragment.content )                      # read
  processed = process_items( value )
  entity_processed = entity_processed.merge( {items: processed})  # write # returns ProcessedCollection[ <Processed>, ... ]

  entity_processed
end

fragment  = entity(   price:   entity({ amount: "9.1", currency: "AUD" }),

  items: entity([ entity({ amount: "1.2", currency: "EUR" }), entity({ amount: "2.3", currency: "USD" })  ])

)


value = Value.new(fragment)
value = process_invoice( value )

pp value

## entity done


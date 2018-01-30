require "test_helper"

class SchemaTest < Minitest::Spec
  class Create #< Transform
    # The visual UI form's format.
    class Form < Transform::Form
      property :unit_price

      collection :items do
        property :price_gross
        property :vat_percentage
      end
    end

    property :unit_price
    collection :items, _activity: ->(original) { snippet },  do
      property :price_gross
      property :vat_percentage
    end
  end
end

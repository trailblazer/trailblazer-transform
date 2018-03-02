require "test_helper"

module Trailblazer::Transform
  class Flow
    extend Trailblazer::Activity::Path()
    extend Schema


  end
end

class FlowTest < Minitest::Spec
  module Amount
    extend Trailblazer::Activity::Path()

    pass ->(ctx, value:, **) { ctx[:value] = "Amount: #{value}" }
    _end task: End(:required)#, magnetic_to: [:required]
  end

  module InvoiceDate
    extend Trailblazer::Activity::Path()

    pass ->(ctx, value:, **) { ctx[:value] = Date.parse(value) }
    _end task: End(:required)#, magnetic_to: [:required]
  end

  class Expense < Transform::Flow
    property :amount,       processor: Amount
    property :invoice_date, processor: InvoiceDate
    # collection :items
  end
end

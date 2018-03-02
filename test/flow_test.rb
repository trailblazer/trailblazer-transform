require "test_helper"

module Trailblazer::Transform
  class Flow
    class << self
      attr_accessor :activity

      def property(*args, &block)
        Schema.property(activity, *args, &block)
      end
    end

    def self.inherited(subclass)
      activity = Module.new do # todo: MOVE TO SCHEMA
        extend Trailblazer::Activity::Path()

        _end task: End(:required), group: :end, magnetic_to: [:required]
        _end task: End(:failure), group: :end, magnetic_to: [:failure] # TODO: rename to :invalid?
      end

      subclass.activity = activity # fixme. doesn't inherit existing shit.
    end
  end
end

class FlowTest < Minitest::Spec
  module Amount
    extend Trailblazer::Activity::Path()

    pass ->(ctx, value:, **) { ctx[:value] = "Amount: #{value}" }

    _end task: End(:required)#, magnetic_to: [:required]
    _end task: End(:failure)#, magnetic_to: [:required]
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

  pp Expense.activity.to_h[:circuit]
end

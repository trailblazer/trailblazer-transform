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
  # @needs :value
  module Amount
    extend Trailblazer::Activity::Railway()

    module_function

    def error_string(ctx, value:, **)
      ctx[:error] = "#{value.inspect} is blank string"
    end

    def error_format(ctx, value:, **)
      ctx[:error] = "#{value.inspect} is wrong format"
    end

    def filled?(ctx, value:, **)
      !value.nil?
    end

    # TODO: use dry-types here
    def coerce_string(ctx, value:, **)
      value.to_s
    end

    def trim(ctx, value:, **)
      ctx[:value] = value.strip
    end

    require "dry/validation"

    def my_format(ctx, value:, **)
      schema = Dry::Validation.Schema do
        required(:value).filled(format?: /^\d\.\d$/)
      end

      result = schema.(value: value)

      ctx[:schema_result] = result

      result.success?
    end

    def coerce_float(ctx, value:, **)
      ctx[:value] = value.to_f
    end

    def float_to_int(ctx, value:, **)
      ctx[:value] = (value * 100).to_i
    end

    step method(:filled?)
    fail method(:error_string), Output(:failure) => "End.required" # FragmentNotFound/FragmentBlank

    step method(:coerce_string) # success: is string, fail: is nil
    # step :empty?
    step method(:trim)
    step method(:my_format) # this is where Dry-v comes into play?
    fail method(:error_format)
    step method(:coerce_float)
    step method(:float_to_int) # * 100

    _end task: End(:required), id: "End.required", magnetic_to: [:required]
  end

  module InvoiceDate
    extend Trailblazer::Activity::Path()

    pass ->(ctx, value:, **) { ctx[:value] = Date.parse(value) }
    _end task: End(:required) #, magnetic_to: [:required]
  end

  class Expense < Transform::Flow
    property :amount,       processor: Amount
    property :invoice_date, processor: InvoiceDate
    # collection :items
  end

  pp Expense.activity.to_h[:circuit]

  it "wrong {amount}" do
    read_data        = Struct.new(:amount, :invoice_date).new # raw parsed data.
    signal, (ctx, _) = Expense.activity.([{document: {amount: "  34.sd"}, read_data: read_data}, {}])

    pp ctx
  end

  it "correct {amount}, missing {invoice_date}" do
    model_from_populator = Struct.new(:amount, :invoice_date).new # i want well-formatted, typed data, only!
    read_data            = Struct.new(:amount, :invoice_date).new # raw parsed data.

    signal, (ctx, _) = Expense.activity.([{document: {amount: "  3.0"}, model: model_from_populator, read_data: read_data}, {}])

    # outer_model.invoice = model_from_populator

    pp ctx
  end
end

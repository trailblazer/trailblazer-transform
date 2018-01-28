module Trailblazer
  module Transform::Process
    class Write
      def initialize(writer:)
        @writer = writer
      end

      def call(ctx, value:, model:, **)
        model.send(@writer, value)
      end
    end
  end
end

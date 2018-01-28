$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "trailblazer-transform"

require "minitest/autorun"

require "trailblazer/transform/parse/hash/step"

Minitest::Spec.module_eval do
  def assert_end(activity, signal, semantic)
    signal.must_equal activity.outputs[semantic].signal
  end
end

require "trailblazer/transform"

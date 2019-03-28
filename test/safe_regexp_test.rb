# frozen_string_literal: true
require_relative "test_helper"

SingleCov.covered!

describe SafeRegexp do
  it "has a VERSION" do
    SafeRegexp::VERSION.must_match /^[\.\da-z]+$/
  end
end

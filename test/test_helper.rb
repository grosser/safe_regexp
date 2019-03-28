# frozen_string_literal: true
require "bundler/setup"

require "single_cov"
SingleCov.setup :minitest

require "maxitest/autorun"

require "safe_regexp/version"
require "safe_regexp"

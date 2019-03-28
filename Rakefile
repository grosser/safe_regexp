# frozen_string_literal: true
require "bundler/setup"
require "bundler/gem_tasks"
require "bump/tasks"
require "benchmark"

require "yaml"
travis = YAML.load_file(Bundler.root.join('.travis.yml'))
  .fetch('env')
  .map { |v| v.delete('TASK=') }

task default: travis

require "rake/testtask"
Rake::TestTask.new :test do |t|
  t.pattern = 'test/**/*_test.rb'
  t.warning = false
end

desc "Run rubocop"
task :rubocop do
  sh "rubocop --parallel"
end

task :performance do
  require 'safe_regexp'
  SafeRegexp.execute(/a/, :match?, 'a') # warmup
  time = Benchmark.realtime { 100.times { SafeRegexp.execute(/a/, :match?, 'a') } } / 100
  puts "Safe: #{(time * 1_000).round(5)}ms"

  time = Benchmark.realtime { /a/.match? 'a' } / 100
  puts "Unsafe: #{(time * 1_000).round(5)}ms"
end

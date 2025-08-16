require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = '--format documentation'
end

task :test do
  puts "Running tests..."
  system("bundle exec rspec > test.log")
  puts "Tests finished."
end

task default: :spec

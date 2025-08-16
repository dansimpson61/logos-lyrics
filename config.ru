require 'rake'

Rake.application.load_rakefile
Rake::Task['test'].invoke

require_relative 'app'
run Sinatra::Application

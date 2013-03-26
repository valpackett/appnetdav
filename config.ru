require 'rubygems'
require 'rack/fiber_pool'
require 'rack/raw_upload'
require 'raven'
require './app/adnresource.rb'
require './app/app.rb'

module Rack
  class Lint
    def call(env = nil)
      @app.call(env)
    end
  end
end

Raven.configure do |config|
  config.excluded_exceptions = ['Sinatra::NotFound']
end

use Rack::FiberPool
use Raven::Rack
use Rack::CommonLogger

map "/dav" do
  use Rack::RawUpload
  run RackDAV::Handler.new :resource_class => ADNResource
end

map "/" do
  run AppnetDAV
end

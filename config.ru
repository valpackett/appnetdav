require 'rubygems'
require 'rack/fiber_pool'
require 'rack/raw_upload'
require './app/adnresource.rb'
require './app/app.rb'

module Rack
  class Lint
    def call(env = nil)
      @app.call(env)
    end
  end
end

use Rack::FiberPool
use Rack::CommonLogger
use Rack::ShowExceptions

map "/dav" do
  use Rack::RawUpload
  run RackDAV::Handler.new :resource_class => ADNResource
end

map "/" do
  run AppnetDAV
end

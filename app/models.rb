require 'curator'
require 'uri'
require 'mongo'
require_relative 'const.rb'

unless MONGOLAB_URI.nil?
  conn = Mongo::Connection.from_uri MONGOLAB_URI
  db   = URI.parse(MONGOLAB_URI).path.gsub /^\//, ''
else
  conn = Mongo::Connection.new
  db   = "appnetdav"
end

Curator.configure(:mongo) do |config|
  config.environment = ENV['RACK_ENV'] || 'development'
  config.client      = conn
  config.database    = db
  config.migrations_path = File.expand_path(File.dirname(__FILE__) + "../migrations")
end


class Password
  include Curator::Model
  attr_accessor :id, :pwd, :key, :owner_adn_id
end

class PasswordRepository
  include Curator::Repository
  indexed_fields :owner_adn_id
end

require 'sinatra/base'
require 'em-synchrony'
require 'faraday'
require 'faraday_middleware'
require_relative 'const'

class ADN
  class << self
    attr_accessor :global
  end

  def initialize(token)
    @api = Faraday.new(:url => 'https://alpha-api.app.net/stream/0/') do |adn|
      adn.request  :authorization, 'Bearer', token
      adn.request  :multipart
      adn.request  :json
      adn.response :json, :content_type => /\bjson$/
      adn.adapter  :em_synchrony
    end
  end

  def method_missing(*args)
    @api.send *args
  end

  def me
    @api.get('users/me').body['data']
  end

  def new_file(file, type, filename, params={})
    params[:content] = Faraday::UploadIO.new file, type, filename
    @api.post 'files', params
  end

  def get_my_files(params={:include_incomplete => 0})
    @api.get 'users/me/files', params
  end

  def get_file(id)
    @api.get "files/#{id}"
  end

  def update_file(id, params)
    @api.put "files/#{id}", params
  end

  def delete_file(id)
    @api.delete "files/#{id}"
  end
end

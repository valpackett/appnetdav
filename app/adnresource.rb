require 'open-uri'
require 'rack_dav'
require 'mime/types'
require 'rumonade'
require_relative 'adn.rb'
require_relative 'models.rb'
require_relative 'monkey.rb'
require_relative 'lengthy_io.rb'

module RackDAV
  class Controller
    def initialize(request, response, options)
      @request  = request
      @response = response
      @options  = options
      @resource = resource_class.new('/dav' + url_unescape(request.path_info), @options, request, response, nil)
    end

    def move
      raise NotFound unless resource.exist?
      dest_uri = URI.parse(env['HTTP_DESTINATION'])
      destination = url_unescape(dest_uri.path)
      raise BadGateway if dest_uri.host and dest_uri.host != request.host
      raise Forbidden if destination == resource.path
      resource.move destination
    rescue URI::InvalidURIError => e
      raise BadRequest.new(e.message)
    end
  end
end

class ADNResource < RackDAV::Resource
  def initialize(path, options, request, response, files=nil)
    @path = path
    @options = options
    @request = request
    @response = response
    @adn = authenticate
    @files = files || @adn.get_my_files.body['data']
    @file = get_file
    puts @request.env['HTTP_USER_AGENT']
    if Option(@request.env['HTTP_USER_AGENT']).get_or_else('').include? 'Readdle'
      @options[:redirect] = true
    end
  end

  def get_file
    if root? || @request.put?
      {'sha1' => 'hello', 'mime_type' => 'text/plain', 'size' => 0, 'created_at' => ''}
    else
      upath = CGI.unescape path
      f = Option(@files.find { |f| '/dav/' + CGI.unescape(f['name']) == upath })
      if f.empty?
        {'sha1' => 'hello', 'mime_type' => 'text/plain', 'size' => 0,
         'created_at' => DateTime.now.to_s, 'url' => 'about:blank', 'id' => '0'}
      else
        @adn.get_file(f.get['id']).body['data']
      end
    end
  end

  def authenticate
    a = Rack::Auth::Basic::Request.new(@request.env)
    unless a.provided?
      @response.headers['WWW-Authenticate'] = 'Basic realm="AppnetDAV"'
      raise RackDAV::HTTPStatus::Unauthorized
    end
    username, password = a.credentials
    if username.include? '+redirect'
      username.gsub! '+redirect', ''
      @options[:redirect] = true
    end
    pwd = PasswordRepository.find_by_owner_adn_id(username).first
    raise RackDAV::HTTPStatus::Forbidden if pwd.nil? || password != pwd.pwd
    ADN.new pwd.key
  end

  def children
    if root? && @files
      @files.map { |f| c = child f['name'] }
    else
      []
    end
  end

  def root?
    @path == '/dav' || @path == '/dav/'
  end

  def collection?
    root?
  end

  def creation_date
    if root?
      DateTime.now
    else
      DateTime.parse @file['created_at']
    end
  end

  def last_modified
    creation_date
  end

  def set_property(name, value)
  end

  def etag
    @file['sha1']
  end

  def exist?
    !@file.nil?
  end

  def content_type
    @file['mime_type']
  end

  def content_length
    @file['size']
  end

  def make_collection
    raise RackDAV::HTTPStatus::Forbidden
  end

  def post(request, response)
    raise RackDAV::HTTPStatus::Forbidden
  end

  def get(request, response)
    if @options[:redirect]
      response.headers['Location'] = @file['url']
      response.headers['Content-Length'] = [0]
      raise RackDAV::HTTPStatus::SeeOther
    else
      response.body = open(@file['url'])
    end
  end

  def put(request, response)
    cl = request.content_length.to_i
    raise RackDAV::HTTPStatus::Forbidden if cl == 0
    if cl != 1 # iWork fix
      filename = CGI.unescape request.path_info.gsub('/', '')
      ctype = request.media_type || Option(MIME::Types.of(filename).first).map(&:content_type).get_or_else('application/octet-stream')
      rsp = @adn.new_file LengthyIO.new(request.body, cl), ctype, filename, :type => 'com.floatboth.appnetdav.file'
      raise RackDAV::HTTPStatus::InsufficientStorage if rsp.status == 507
    end
  end

  def move(dest)
    name = CGI.unescape(dest.gsub('/dav/', '').gsub('/', ''))
    @adn.update_file @file['id'], :name => name
  end

  def delete
    @adn.delete_file @file['id']
  end

  def child(name, options={})
    self.class.new('/dav/' + name, options, @request, @response, @files)
  end
end

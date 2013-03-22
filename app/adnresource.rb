require 'rack_dav'
require 'mime/types'
require_relative 'adn.rb'
require_relative 'models.rb'

module RackDAV
  class Controller
    def initialize(request, response, options)
      @request  = request
      @response = response
      @options  = options
      @resource = resource_class.new('/dav' + url_unescape(request.path_info), @options, request, response, nil)
    end

    def move
      raise NotFound if not resource.exist?
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

class LengthyIO < Struct.new(:io, :length)
  def read(*args)
    io.read(*args)
  end

  def method_missing(meth, *args)
    io.call(meth, *args)
  end
end

class ADNResource < RackDAV::Resource
  def initialize(path, options, request, response, files)
    @path = path
    @options = options
    @request = request
    @response = response
    a = Rack::Auth::Basic::Request.new(request.env)
    unless a.provided?
      response.headers['WWW-Authenticate'] = 'Basic realm="AppnetDAV"'
      raise RackDAV::HTTPStatus::Unauthorized
    end
    pwd = PasswordRepository.find_by_owner_adn_id a.credentials[0]
    raise RackDAV::HTTPStatus::Forbidden if pwd.empty?
    raise RackDAV::HTTPStatus::Forbidden if a.credentials[1] != pwd.first.pwd
    @adn = ADN.new pwd.first.key
    @files = @adn.get_my_files.body['data']
    if root? || request.put?
      @file = {'sha1' => 'aaa', 'mime_type' => 'text/html', 'size' => 0}
    else
      upath = CGI.unescape path
      f = @files.select { |f| '/dav/' + f['name'] == upath }
      @file = @adn.get_file(f.first['id']).body['data'] unless f.empty?
    end
  end

  def children
    if root?
      @files.map { |f| child f['name'] }
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
    true if @file || root?
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
    response.headers['Location'] = @file['url']
    response.headers['Content-Length'] = [0]
    raise RackDAV::HTTPStatus::SeeOther
  end

  def put(request, response)
    filename = CGI.unescape request.path_info.gsub('/', '')
    ctype = request.media_type || MIME::Types.of(filename).map(&:content_type).first
    @adn.new_file LengthyIO.new(request.body, request.content_length.to_i), ctype, filename, :type => 'com.floatboth.appnetdav.file'
  end

  def move(dest)
    @adn.update_file @file['id'], :name => CGI.unescape(dest.gsub('/dav/', '').gsub('/', ''))
  end

  def delete
    @adn.delete_file @file['id']
  end

  def child(name, option={})
    self.class.new('/dav/' + name, options, @request, @response, @files)
  end
end
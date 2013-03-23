require 'sinatra/base'
require 'sinatra/flash'
require 'rack/csrf'
require 'rack/ssl-enforcer'
require 'omniauth'
require 'omniauth-appdotnet'
require 'slim'
require 'multi_json'
require_relative 'adn.rb'
require_relative 'models.rb'

class AppnetDAV < Sinatra::Base
  set :session_secret, SESSION_SECRET
  set :server, :thin
  set :markdown, :layout_engine => :slim
  set :views, File.join(File.dirname(__FILE__), '..', 'views')
  set :public_folder, File.join(File.dirname(__FILE__), '..', 'public')

  register Sinatra::Flash

  configure :production do
    require 'newrelic_rpm'
    use Rack::SslEnforcer
  end
  use Rack::Session::Cookie, :secret => settings.session_secret
  use Rack::Csrf
  use OmniAuth::Builder do
    provider :appdotnet, ADN_ID, ADN_SECRET, :scope => 'files'
  end

  before do
    @adn = ADN.new session[:token]
    @me = @adn.me unless session[:token].nil?
  end

  not_found do
    slim :not_found
  end

  get '/auth/appdotnet/callback' do
    session[:token] = request.env['omniauth.auth']['credentials']['token']
    redirect request.env['omniauth.origin'] || '/'
  end

  get '/auth/logout' do
    session[:token] = nil
    redirect '/'
  end

  get '/' do
    if @me.nil?
      slim :landing
    else
      @host = request.host
      @passwords = PasswordRepository.find_by_owner_adn_id @me['id']
      slim :index
    end
  end

  post '/passwords' do
    halt 404 if @me.nil?
    pwd = Password.new :pwd => params[:pwd], :key => session[:token], :owner_adn_id => @me['id']
    PasswordRepository.save pwd
    flash[:message] = 'Successfully created a password.'
    redirect '/'
  end

  get '/passwords/:id/delete' do
    pwd = PasswordRepository.find_by_id params[:id]
    halt 404 unless pwd.owner_adn_id == @me['id']
    halt 404 unless pwd
    PasswordRepository.delete pwd
    flash[:message] = 'Successfully deleted a password.'
    redirect '/'
  end
end

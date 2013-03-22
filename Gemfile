source 'https://rubygems.org'

# serving
gem "thin"
gem "rack_dav"
gem "rack_csrf"
gem "rack-ssl-enforcer"
gem "rack-fiber_pool"
gem "rack-raw-upload"
gem "sinatra"
gem "sinatra-flash"
gem "slim"
gem "builder", "~> 3.0.0"

# requesting
gem "em-http-request"
gem "em-synchrony"
gem "faraday"
gem "faraday_middleware"
gem "omniauth"
gem "omniauth-appdotnet"

# storing
gem "curator", :git => "git://github.com/braintree/curator.git"
gem "mongo", "1.6.0"
gem "bson_ext", "1.6.0"

# etc
gem "oj"
gem "mime-types"

group :development, :test do
  gem "rspec"
  gem "rack-test"
  gem "shotgun"
end

group :production do
  # gem "newrelic_rpm"
end

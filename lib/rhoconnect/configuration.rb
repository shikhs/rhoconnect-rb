module Rhoconnect
  class Configuration
    attr_accessor :uri, :token, :authenticate, :sync_time_as_int, :app_endpoint, :http_proxy
    
    def initialize
      @sync_time_as_int = true
    end
      
  end

  class << self
    attr_accessor :configuration
  end

  # Configure Rhoconnect in an initializer:
  # like config/initializers/rhoconnect.rb
  #
  # Setup the Rhoconnect uri and api token.
  # Use rhoconnect:get_token to get the token value.
  #
  #   config.uri   = "http://myrhoconnect.com"
  #   config.token = "secrettoken"
  #   config.authenticate = lambda { |credentials| 
  #     User.authenticate(credentials) 
  #   }
  #
  # @example
  #   Rhoconnect.configure do |config|
  #     config.uri   = "http://myrhoconnect.com"
  #     config.token = "secrettoken"
  #   end
  def self.configure
    self.configuration = Configuration.new
    yield(configuration)
    # make a call to rhoconnect instance to set app url
    endpoint_url = ENV['APP_ENDPOINT'] || self.configuration.app_endpoint
    uri          = ENV['URI'] || self.configuration.uri
    if uri
      uri = URI.parse(uri)
      token    = uri.user
      uri.user = nil
      uri      = uri.to_s
    end
    token ||= ENV['token'] || self.configuration.token
    Rhoconnect::Client.set_app_endpoint(uri + "/api/source/save_adapter?attributes[adapter_url]=#{endpoint_url}&api_token=#{token}") if endpoint_url && uri && token
  end
end

Rhoconnect.configure { }
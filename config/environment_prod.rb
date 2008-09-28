# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when 
# you don't control web/app server and can't set it the proper way
ENV['RAILS_ENV'] = 'production'
# ENV['RAILS_ENV'] = 'development'

# Get rid of ?<timestamp> so caching works better.  See
# http://www.deathy.net/blog/2007/06/26/rails-asset-timestamping-and-why-its-bad/
# for more details
ENV["RAILS_ASSET_ID"] = ""

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

# Add a shared file for consts that are not configuration dependent
require File.join(File.dirname(__FILE__), 'consts')

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence those specified here
  
  # Skip frameworks you're not going to use
  # config.frameworks -= [ :action_web_service, :action_mailer ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level 
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  # config.action_controller.session_store = :active_record_store

  # A secret is required to generate an integrity hash for cookie session data.
  if RAILS_GEM_VERSION >= '2.0'
    config.action_controller.session = {
      :session_key => 'mo_session',
      :secret => '1f58da43b4419cd9c1a7ffb87c062a910ebd2925d3475aefe298e2a44d5e86541125c91c2fb8482b7c04f7dd89ecf997c09a6e28a2d01fc4819c75d2996e6641'
    }
  end

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc
  
  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  # config.active_record.schema_format = :ruby

  # See Rails::Configuration for more options
end

# Add new inflection rules using the following format 
# (all these examples are active by default):
# Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

# Include your application configuration below

# Temporary thing to log every request as soon as it hits Ruby -- or at least
# as close as I can make it.  I think this is mighty close to the socket accept
# system call...
if defined? TCPServer
  class TCPServer
    alias old_accept accept
    def accept(*args)
      result = old_accept(*args)
      RAILS_DEFAULT_LOGGER.warn(">>> #{Time.now} Received request.")
      result
    end
  end
end
if defined? Mongrel
  module Mongrel
    class HttpServer
      @@my_request_id = 0
      alias old_process_client process_client
      def process_client(*args)
        id = @@my_request_id += 1
        RAILS_DEFAULT_LOGGER.warn(">>> #{Time.now} Request ##{id} start.")
        result = old_process_client(*args)
        RAILS_DEFAULT_LOGGER.warn(">>> #{Time.now} Request ##{id} done.")
        result
      end
    end
  end
end

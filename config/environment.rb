# encoding: utf-8
#
#  = Configuration
#
#  This is essentially the "boot" script for the application.  (See below for
#  the precise order in which files are included and run.)
#
#  Configurations in this file will affect all three modes: PRODUCTION,
#  DEVELOPMENT and TEST.  They can be overridden with mode-specific
#  configurations in these three files:
#
#  * config/environments/production.rb
#  * config/environments/development.rb
#  * config/environments/test.rb
#
#  Make site-specific modifcations in these files:
#
#  * config/consts-site.rb
#  * config/environment-site.rb
#  * config/environments/production-site.rb
#  * config/environments/development-site.rb
#  * config/environments/test-site.rb
#
#  == Startup Procedure
#
#  [1. script/server]
#    Runs config/boot.rb, then runs commands/server (in rails gem).
#
#  [2. config/boot.rb]
#    Loads rubygems, loads rails gem, sets load path, DOES NOT RUN ANYTHING.
#
#  [3. commands/server]
#    Picks server and runs it.
#
#  [4. commands/servers/webrick]
#    Parses ARGV, runs config/environment.rb, runs server.
#
#  [5. config/environment.rb]
#    Does all the application-supplied configuration, in this order:
#    1. config/consts-site.rb (optional)
#    2. config/consts.rb
#    3. config/environment.rb
#    4. config/environment-site.rb (optional)
#    5. config/environments/RAILS_ENV.rb
#    6. config/environments/RAILS_ENC-site.rb (optional)
#
#  == Global Constants
#
#  Global Constants (e.g., DOMAIN and DEFAULT_LOCALE) are initialized in
#  config/consts.rb.
#
#  == Rails Configurator
#
#  The environment files are evaled in the context of a Rails::Initializer
#  instance.  The "local" variable +config+ gives you access to the
#  Rails::Configuration class.  This, among other things, lets you set class
#  variables in all the major Rails packages:
#
#    # This sets @@default_timezone in ActiveRecord::Base.
#    config.active_record.default_timezone = :utc
#
#  Global constants _can_ be defined in these configurator blocks, too.  Rails
#  automatically copies them into the Object class namespace (thereby making
#  them available to the entire application).  However, currently, no global
#  constants are defined this way -- they are defined outside, directly in the
#  main namespace.
#
################################################################################

# Make sure it's already booted.
require File.join(File.dirname(__FILE__), 'boot')

# This must be here -- config/boot.rb greps this file looking for it(!!)
RAILS_GEM_VERSION = '2.1.1'

# Short-hand for the three execution modes.
PRODUCTION  = (RAILS_ENV == 'production')
DEVELOPMENT = (RAILS_ENV == 'development')
TESTING     = (RAILS_ENV == 'test')

# Should be one of [:normal, :silent]
# :silent turns off event logging and email notifications
class RunLevel
  @@runlevel = :normal
  def self.normal()
    @@runlevel = :normal
  end
  
  def self.silent()
    @@runlevel = :silent
  end
  
  def self.is_normal?()
    @@runlevel == :normal
  end
end

# RUN_LEVEL = :normal # :silent

# Do site-specific global constants first.
file = File.join(File.dirname(__FILE__), 'consts-site')
require file if File.exists?(file + '.rb')

# Now provide defaults for the rest.
require File.join(File.dirname(__FILE__), 'consts')

# --------------------------------------------------------------------
#  General non-mode-specific, non-site-specific configurations here.
# --------------------------------------------------------------------

# Sacraficial goat and rubber chicken to get Globalite to behave correctly
# for rake tasks.
:some_new_symbol

Rails::Initializer.run do |config|

  # Add our local classes and modules (e.g., Textile and LoginSystem) and class
  # extensions (e.g., String and Symbol extensions) to the include path.
  config.load_paths += %W(
    #{RAILS_ROOT}/app/classes
    #{RAILS_ROOT}/app/extensions
  )

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  # config.action_controller.session_store = :active_record_store

  # A secret is required to generate an integrity hash for cookie session data.
  config.action_controller.session = {
    :session_key => 'mo_session',
    :secret => '1f58da43b4419cd9c1a7ffb87c062a910ebd2925d3475aefe298e2a44d5e86541125c91c2fb8482b7c04f7dd89ecf997c09a6e28a2d01fc4819c75d2996e6641'
  }

  # Enable page/fragment caching by setting a file-based store (remember to
  # create the caching directory and make it readable to the application) .
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

  # Make Active Record use UTC instead of local time.  This is critical if we
  # want to sync up remote servers.  It causes Rails to store dates in UTC and
  # convert from UTC to whatever we've set the timezone to when reading them
  # back in.  It shouldn't actually make any difference how the database is
  # configured.  It takes dates as a string, stores them however it chooses,
  # performing whatever conversions it deems fit, then returns them back to us
  # in exactly the same format we gave them to it.  (NOTE: only the first line
  # should be necessary, but for whatever reason, Rails is failing to do the
  # other configs on some platforms.)
  config.time_zone = ENV['TZ']
  if config.time_zone.nil?
    # Localization isn't loaded yet.
    raise 'TZ environment variable must be set. Run "rake -D time" for a list of tasks for finding appropriate time zone names.'
  end

  # This instructs ActionView how to mark form fields which have an error.
  # I just change the CSS class to "has_error", which gives it a red border.
  # This is superior to the default, which encapsulates the field in a div,
  # because that throws the layout off.  Just changing the border, while less
  # conspicuous, has no effect on the layout.
  config.action_view.field_error_proc = Proc.new { |html_tag, instance|
    html_tag.sub(/(<\w+)/, '\1 class="has_error"')
  }

  # Configure SMTP settings for ActionMailer.
  config.action_mailer.smtp_settings = MAIL_CONFIG

  # Include optional site-specific configs.
  file = __FILE__.sub(/.rb$/, '-site.rb')
  eval(IO.read(file), binding, file) if File.exists?(file)
end

# -------------------------------------
#  "Temporary" third-party bug-fixes.
# -------------------------------------

# Get rid of ?<timestamp> so caching works better.
# See http://www.deathy.net/blog/2007/06/26/rails-asset-timestamping-and-why-its-bad/ for more details.
ENV['RAILS_ASSET_ID'] = ''

# RedCloth 4.x has quite a few bugs still. This should roughly fix them until
# Jason Garber has time to fix them properly in the parser rules. :stopdoc:
module RedCloth
  class TextileDoc
    def to_html(*rules)

      # Pre-filters: losing square brackets if next to quotes, this
      # introduces a space -- not perfect, but close.
      self.gsub!('["', '[ "')
      self.gsub!('"]', '" ]')

      apply_rules(rules)
      result = to(RedCloth::Formatters::HTML).to_s.clone

      # Post-filters: not catching all the itallics, and seeing spans where
      # they don't belong.
      result.gsub!(/(^|\W)_+([A-Z][A-Za-z0-9]+)_+(\W|$)/, '\\1<i>\\2</i>\\3')
      result.gsub!(/<span>(.*?)<\/span>/, '%\\1%')

      return result
    end
  end
end

# There appears to be a bug in read_multipart.  I checked, this is never used
# by the live server.  But it *is* used by integration tests, and it fails
# hideously if you are foolish enough to try to upload a file in such tests.
# Apparently it simply forgot to unescape the parameter names.  Easy fix. -JPH
module ActionController
  class AbstractRequest
    class << self
      alias fubar_read_multipart read_multipart
      def read_multipart(*args)
        params = fubar_read_multipart(*args)
        new_params = {}
        for key, val in params
          new_params[URI.unescape(key)] = val
        end
        return new_params
      end
    end
  end
end

# Add the option to "orphan" attachments if you use ":dependent => :orphan" in
# the has_many association options.  This has the effect of doing *nothing* to
# the attachements.  The other options allowed by Rails already are:
#
#   :delete_all   Delete directly from database without callbacks.
#   :destroy      Call "destroy" on all attachments.
#   nil           Set the parent id to NULL.
#
# New option:
#
#   :orphan       Do nothing.
#
module ActiveRecord
  module Associations
    class HasManyAssociation
      alias original_delete_records delete_records
      def delete_records(records)
        if @reflection.options[:dependent] != :orphan
          original_delete_records(records)
        end
      end
    end
    module ClassMethods
      alias original_configure_dependency_for_has_many configure_dependency_for_has_many
      def configure_dependency_for_has_many(reflection)
        if reflection.options[:dependent] != :orphan
          original_configure_dependency_for_has_many(reflection)
        end
      end
    end
  end
end

################################################################################
# Stuff to get rails 2.1.1 working with ruby 1.9. -Jason, Feb 2011

# Need this to force encoding of views to all be utf-8.  (Rails 3 makes this
# globally configurable using 'config.encoding'.)
module ActionView
  module TemplateHandlers
    module Compilable
      alias _old_create_template_source create_template_source
      def create_template_source(*args)
        result = _old_create_template_source(*args)
        result.force_encoding('utf-8') if result.respond_to?(:force_encoding)
        return result
      end
    end
  end
end

# Easier to make ruby 1.8 forward-compatible in this case.
#   old: str[0] --> new: str[0].ord
if RUBY_VERSION < '1.9'
  class String
    def ord
      self[0]
    end
  end
  class Fixnum
    def ord
      self
    end
  end
end

# This is used by ym4r_gm plugin.
module ActionController
  class Base
    def self.relative_url_root
      ''
    end
  end
end

# This must have something to do with ruby 1.9.
module Ym4r
  module GmPlugin
    class Variable
      alias to_str to_s
    end
  end
end

# Near as I can tell there is simply a bug in the Rails 2.1.1 handling of
# encodings in assert_select.  It forces the text it's validating to be the
# same encoding as the selector.  This is fine of the selector is a string,
# because the selector takes on the source encoding of the caller's file, so
# we have control over it.  But Ruby second-guesses us when it creates regexen.
# They do NOT take on the encoding of the source file -- they are implictly
# downgraded to US-ASCII if no 8-bit characters are used.  This causes rails
# force the encoding of the text to US-ASCII, as well, causing it to crash.
# I can find no way to solve this problem without recasting the regexen with
# the following sleight of hand.  Ugly, but it works.
if RUBY_VERSION >= '1.9'
  require 'action_controller'
  require 'action_controller/assertions'
  module ActionController
    module Assertions
      module SelectorAssertions
        alias __old_assert_select assert_select
        def assert_select(*args, &block)
          args = args.map do |arg|
            case arg
            when Regexp ; /#{arg}/u
            when String ; arg.force_encoding('UTF-8')
            else        ; arg
            end
          end
          __old_assert_select(*args, &block)
        end
      end
    end
  end 
end

# This is used by passenger?
module ActionController
  class Base
    X_POWERED_BY = 'X-Powered-By'
  end
end

# This is a temporary fix to allow ruby 1.9 to read the old (corrupt) database
# correctly.  When we release the new server, we'll fix the database encoding,
# and this will change to allow ruby 1.8 to read the new (correct) database.
if RUBY_VERSION >= '1.9'
  require 'mysql2' unless defined? Mysql2
  module ActiveRecord
    module ConnectionAdapters
      class Mysql2Adapter < AbstractAdapter
        alias :_old_execute_ :execute
        def execute(sql, name = nil)
          _old_execute_(convert_to_old_encoding(sql), name)
        end
        #
        def select(sql, name = nil)
          result = execute(sql, name).each(:as => :hash)
          result.each do |hash|
            for v in hash.values
              v.replace(convert_from_old_encoding(v)) if v.is_a?(String)
            end
          end
          return result
        end
        #
        def select_rows(sql, name = nil)
          result = execute(sql, name).to_a
          result.each do |a|
            for v in a
              v.replace(convert_from_old_encoding(v)) if v.is_a?(String)
            end
          end
          return result
        end
        #
        def convert_to_old_encoding(str)
          str.force_encoding('windows-1252')
          begin
            str.encode('utf-8')
          rescue Encoding::UndefinedConversionError
            result = ""
            result.force_encoding('binary')
            str.each_char do |c|
              c = begin
                c.encode('utf-8')
              rescue
                c.force_encoding('binary')
                d = "\xc2"
                d.force_encoding('binary')
                d + c
              end
              c.force_encoding('binary')
              result += c
            end
            result.force_encoding('utf-8')
            result
          end
        end
        #
        def convert_from_old_encoding(str)
          begin
            result = str.encode('windows-1252')
            result.force_encoding('utf-8')
            result
          rescue Encoding::UndefinedConversionError
            result = ""
            result.force_encoding('binary')
            str.each_char do |c|
              c = begin
                c.encode('windows-1252')
              rescue
                c.force_encoding('binary')
                c[1,1]
              end
              c.force_encoding('binary')
              result += c
            end
            result.force_encoding('utf-8')
            result
          end
        end
      end
    end
  end
end

# This is a known bug in old ActionMailer versions.
if RUBY_VERSION >= '1.9'
  module ActionMailer
    class Base
      def perform_delivery_smtp(mail)
        destinations = mail.destinations
        mail.ready_to_send
        sender = mail['return-path'] || mail['from'] # <-- instead of "mail.from"
        Net::SMTP.start(smtp_settings[:address], smtp_settings[:port], smtp_settings[:domain],
            smtp_settings[:user_name], smtp_settings[:password], smtp_settings[:authentication]) do |smtp|
          smtp.sendmail(mail.encoded, sender, destinations)
        end
      end
    end
  end
end

# The test-unit plugin now provides this, but fails to give it all the same
# functionality of assert_match (ability to pass String instead of Regexp, in
# particular). 
if RUBY_VERSION >= '1.9'
  gem 'test-unit'
  require 'test/unit/assertions.rb' unless defined? Unit::Test::Assertions
  module Test
    module Unit
      module Assertions
        def assert_not_match(expect, actual, msg=nil)
          _wrap_assertion do
            expect = Regexp.new(expect) if expect.is_a?(String)
            msg = build_message(msg, "Expected <?> not to match <?>.", actual, expect)
            assert_block(msg) { actual !~ expect }
          end
        end
      end
    end
  end
end

# Multipart form data is read in as ASCII-8BIT / BINARY.  Apparently we can
# usually assume that it is actually UTF-8, so we just need to force the
# correct encoding.
if RUBY_VERSION >= '1.9'
  module ActionController
    class AbstractRequest
      class << self
        alias __get_typed_value get_typed_value
        def get_typed_value(value)
          result = __get_typed_value(value)
          result.force_encoding('utf-8') if result.respond_to?(:force_encoding)
          return result
        end
      end
    end
  end
end

# This tells browsers which encoding to use when sending POST data from forms.
# The magic hidden field is a workaround to force IE to pay attention to the
# requested character encoding.
module ActionView
  module Helpers
    module FormTagHelper
      alias __form_tag_html form_tag_html
      def form_tag_html(args)
        __form_tag_html(args.merge(:'accept-charset' => 'UTF-8')) +
          '<input name="_utf8" type="hidden" value="&#9731;" />'
      end
    end
  end
end

################################################################################

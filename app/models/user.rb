#
#  = User Model
#
#  Model describing a User.
#
#  Login is handled by lib/login_system.rb, a third-party package that we've
#  modified slightly.  It is enforced by adding <tt>before_filter
#  :login_required</tt> filters to the controllers.
#
#  We now support autologin or "remember me" login via a simple cookie and the
#  application-wide <tt>before_filter :autologin</tt> filter in
#  ApplicationController.
#
#  == Signup / Login Process
#
#  Only part of this site is available to anonymous guests.  Sign-up is a
#  two-step process, requiring email verification before the new User can log
#  in.  The full process is as follows:
#
#  1. Anonymous User pokes around until they try to post a Comment, say.  This
#     page requires a login (via +login_required+ filter in controller, see
#     below).  This causes the User to be redirected to <tt>/account/login</tt>.
#
#  2. If the User already has an account, they login here, and wind up
#     redirected back to the form that triggered the login.
#
#  3. If the User has no account, they click on "Create a new account" and go
#     to <tt>/account/signup</tt>.  They fill out the form and submit it.  This
#     creates a new User record, but this record is still unverified (verified
#     is +nil+).
#
#  4. A verification email is sent to the email address given in the sign-up
#     form.  Inside the email is a link to /account/verify.  This provides the
#     User +id+ and +auth_code+.
#
#  5. When they click on that link, the User record is updated and the User is
#     automatically logged in.
#
#  == ApplicationController Filters
#
#  The execution flow for an HTTP request as affects login, including all
#  application-wide filters, is as follows:
#
#  1. +browser_status+: Determine browser type and state of javascript.
#
#  2. +autologin+: Check if User is logged in by first looking at session, then
#     autologin cookie.  Requires User be verified.  Stores User in session,
#     cookie, User#current, and +@user+ (visible to controllers and views).
#     Sets all these to nil if no User logged in.
#
#  3. +check_user_alert+: Check if User has an alert to show, redirecting if so.
#
#  4. +set_locale+: Check if User has chosen a locale.
#
#  5. +login_required+: (optional) Redirects to <tt>/account/login</tt> if not
#     logged in.
#
#  == Contribution Score
#
#  Contribution score is just a cache.  It is very carefully kept up to date by
#  several callbacks in Model and a few other Model subclasses that modify the
#  score every time a User creates, edits or destroys an object.  It is also
#  automatically refreshed whenever anyone views the User's summary page, just
#  in case the callbacks ever fail.
#
#  == Alerts
#
#  Admins can create an alert for a User.  These are messages that they will
#  see the very next time they try to load a page.  Only one is allowed at a
#  time for the User right now.  All the information about the alert is stored
#  in a simple hash which is stored, serialized, as a +text+ column in the
#  database.  When the User sees the message, they have three options:
#
#  1. Acknowledge the alert by clicking on "okay", and the alert is deleted.
#  2. Tell it to display the message again in a day (see +alert_next_showing+).
#  3. Exit or navigate away without acknowledging it, causing the alert to be
#     shown over and over until they get tired and say "okay".
#
#  == Admin Mode
#
#  Any User can be granted administrator privileges.  However, we don't want
#  admins wandering around the site in "admin mode" during every-day usage.
#  Thus we additionally require that admin User's also turn on admin mode.
#  (There's a handy switch in the left-hand column of every page.)  This state
#  is stored in the session.  (See ApplicationController#is_in_admin_mode?)
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1.
#  sync_id::            Globally unique alphanumeric id, used to sync with remote servers.
#  created::            Date/time it was first created.
#  modified::           Date/time it was last modified.
#  verified::           Date/time the account was verified.
#  last_login::         Date/time the user last logged in.
#
#  ==== Administrative
#  login::              Login name (must be locally unique).
#  name::               Full name.
#  password::           Hashed password.
#  email::              Email address.
#  admin::              Allowed to enter admin mode?
#  created_here::       Was this account originally created on this server?
#  alert::              Alert message we need to display for User. (serialized)
#  bonuses::            List of zero or more contribution bonuses. (serialized)
#  contribution::       Contribution score (integer).
#
#  ==== Profile
#  mailing_address::    Mailing address used in naming_for_observer emails.
#  notes::              Free-form Textile notes (provided by User).
#  location::           Primary location (chosen by User).
#  image::              Mug-shot Image.
#  license::            Default license for Images this User uploads.
#
#  ==== Preferences
#  locale::             Language, e.g.: "en-US" or "pt-BR"
#  theme::              CSS theme, e.g.: "Amanita" or +nil+ for random
#  rows::               Number of rows of thumbnails to show in index.
#  columns::            Number of columns of thumbnails to show in index.
#  alternate_rows::     Alternate row colors?
#  alternate_columns::  Alternate column colors?
#  vertical_layout::    Show text below thumbnails in index?
#
#  ==== Email options
#  Send notifications if...
#  email_comments_owner::         ...someone comments on object I own.
#  email_comments_response::      ...someone responds to my Comment.
#  email_comments_all::           ...anyone comments on anything.
#  email_observations_consensus:: ...consensus changes on my Observation.
#  email_observations_naming::    ...someone proposes a Name for my Observation.
#  email_observations_all::       ...anyone changes an Observation.
#  email_names_author::           ...someone changes a Name I've authored.
#  email_names_editor::           ...someone changes a Name I've edited.
#  email_names_reviewer::         ...someone changes a Name I've reviewed.
#  email_names_all::              ...anyone changes a Name.
#  email_locations_author::       ...someone changes a Location I've authored.
#  email_locations_editor::       ...someone changes a Location I've edited.
#  email_locations_all::          ...anyone changes a Location.
#  email_general_feature::        ...you announce new features.
#  email_general_commercial::     ...someone sends me a commercial inquiry.
#  email_general_question::       ...someone sends me a general question.
#  email_digest::                 (not used yet)
#  email_html::                   Send HTML-formatted email?
#
#  ==== "Fake" attributes
#  place_name::             Allows User to enter location by name.
#  password_confirmation::  Used to confirm password during sign-up.
#
#  == Class methods
#
#  current::            Report the User that is currently logged in.
#  current_id::         Report the User (id) that is currently logged in.
#  all_alert_types::    List of accepted alert types.
#  authenticate::       Verify login + password.
#
#  == Instance methods
#
#  text_name::          User name as: "loging" (for debugging)
#  legal_name::         User name as: "First Last" or "login"
#  unique_text_name::   User name as: "First Last (login)" or "login"
#  auth_code::          Code used to verify autologin cookie and POSTs in API.
#  percent_complete::   How much of profile has User finished?
#  change_password::    Change password (on an existing record).
#  in_group?::          Is User in a given UserGroup?
#  remember_me?::       Does User want us to use the autologin cookie thing?
#  interest_in::        Return state of User's interest in a given object.
#  watching?::          Is User watching a given object?
#  ignoring?::          Is User ignoring a given object?
#  sum_bonuses::        Add up all the bonuses User has earned.
#
#  ==== Object ownership
#  comments::           Comment's they've posted.
#  images::             Image's they've uploaded.
#  interests::          Interest's they've indicated.
#  locations::          Location's they were last to edit.
#  names::              Name's they were last to edit.
#  namings::            Naming's they've proposed.
#  notifications::      Notification's they've requested.
#  observations::       Observation's they've posted.
#  projects_created::   Project's they've created.
#  queued_emails::      QueuedEmail's they're scheduled to receive.
#  species_lists::      SpeciesList's they've created.
#  votes::              Vote's they've cast.
#
#  ==== Other relationships
#  to_emails::          QueuedEmail's they've caused to be sent.
#  user_groups::        UserGroup's they're members of.
#  reviewed_images::    Image's they've reviewed.
#  reviewed_names::     Name's they've reviewed.
#  authored_names::     Name's they've authored.
#  edited_names::       Name's they've edited.
#  authored_locations:: Location's they've authored.
#  edited_locations::   Location's they've edited.
#  projects_admin::     Projects's they're an admin for.
#  projects_member::    Projects's they're a member of.
#
#  ==== Alert methods
#  alert_user::         Which admin created the alert.
#  alert_created::      When alert was created.
#  alert_next_showing:: When is the alert going to be shown next?
#  alert_type::         What type of alert, e.g., :bounced_email.
#  alert_notes::        Additional notes to add to message.
#  alert_message::      Actual message, translated into local language.
#
#  == Callbacks
#
#  crypt_password::     Password attribute is encrypted before object is created.
#
#  == Note on Globalization
#
#  The login name must be locally unique, however a remote server could in
#  theory simultaneously create an account with the same login.  This is dealt
#  with by tacking the server code on to the end locally.  Thus the local
#  account will be unchanged, but the remote account will have a different
#  login name on the two servers.  The end result looks like this:
#
#    server    US Fred's login   Russian Fred's login
#    US        "fred"            "fred (us1)"
#    Russia    "fred (ru1)"      "fred"
#
#  We check for this possibility in <tt>/account/login</tt>, just in case
#  Russian Fred tries to log in on the US server.
#
#  In any case, the US server will _not_ know Russian Fred's password, and will
#  redirect him to a special page which acknowledges that he has an account on
#  the US server, would he like to create a password so he can login on either
#  server?
#
#  There are several such attributes which are not transferred over, such as
#  +admin+ and +created_here+, a flag that is set to true on the server in
#  which the account was first created.  Here is a summary of attributes that
#  differ from server to server: (In this example the admin User, Fred, was
#  created on "us1" server.)
#
#    Attribute      Local Server    Remote Server
#    id             1502            1513
#    sync_id        1502us1         1502us1
#    login          fred            fred (us1)
#    password       xxxxxxxx        nil
#    admin          true            false
#    created_here   true            false
#    alert          anything        anything
#
################################################################################

class User < AbstractModel
  require 'digest/sha1'

  has_many :comments
  has_many :images
  has_many :interests
  has_many :locations
  has_many :location_descriptions
  has_many :names
  has_many :name_descriptions
  has_many :namings
  has_many :notifications
  has_many :observations
  has_many :projects_created, :class_name => "Project"
  has_many :queued_emails
  has_many :species_lists
  has_many :test_add_image_logs
  has_many :votes

  has_many :reviewed_images, :class_name => "Image", :foreign_key => "reviewer_id"
  has_many :reviewed_name_descriptions, :class_name => "NameDescription", :foreign_key => "reviewer_id"
  has_many :to_emails, :class_name => "QueuedEmail", :foreign_key => "to_user_id"

  has_and_belongs_to_many :user_groups,        :class_name => 'UserGroup',            :join_table => 'user_groups_users'
  has_and_belongs_to_many :authored_names,     :class_name => 'NameDescription',      :join_table => 'name_descriptions_authors'
  has_and_belongs_to_many :edited_names,       :class_name => 'NameDescription',      :join_table => 'name_descriptions_editors'
  has_and_belongs_to_many :authored_locations, :class_name => 'LocationDescription',  :join_table => 'location_descriptions_authors'
  has_and_belongs_to_many :edited_locations,   :class_name => 'LocationDescription',  :join_table => 'location_descriptions_editors'

  belongs_to :image         # mug shot
  belongs_to :license       # user's default license
  belongs_to :location      # primary location

  # Encrypt password before saving the first time.  (Subsequent modifications
  # go through +change_password+.)
  before_create :crypt_password
  after_create  {|user| UserGroup.create_user(user)}
  after_destroy {|user| UserGroup.destroy_user(user)}

  # This causes the data structures in these fields to be serialized
  # automatically with YAML and stored as plain old text strings.
  serialize :bonuses
  serialize :alert

  # Used to let User enter location by name in prefs form.
  attr_accessor :place_name

  # Used to let User enter password confirmation when signing up or changing
  # password.
  attr_accessor :password_confirmation

  # Report which User is currently logged in. Returns +nil+ if none.  This is
  # the same instance as is in the controllers' +@user+ instance variable.
  #
  #   user = User.current
  #
  def self.current
    @@user = nil if !defined?(@@user)
    return @@user
  end

  # Report which User is currently logged in. Returns id, or +nil+ if none.
  #
  #   user_id = User.current_id
  #
  def self.current_id
    @@user = nil if !defined?(@@user)
    return @@user && @@user.id
  end

  # Tell User model which User is currently logged in (if any).  This is used
  # by the +autologin+ filter.
  def self.current=(x)
    @@user = x
  end

  # Look up User record by login and hashed password.  Accepts any of +login+,
  # +name+ or +email+ in place of +login+.
  #
  #   user = User.authenticate('fred', 'password')
  #   user = User.authenticate('Fred Flintstone', 'password')
  #   user = User.authenticate('fred99@aol.com', 'password')
  #
  def self.authenticate(login, pass)
    find(:first, :conditions =>
      [ "(login = ? OR name = ? OR email = ?) AND password = ?",
        login, login, login, sha1(pass) ])
  end

  # Code used to authenticate via cookie, verify email, or XML request.
  #
  #   id   = params[:auth_id]
  #   code = params[:auth_code]
  #   user = User.find(id)
  #   raise if code != user.auth_code
  #
  def auth_code
    protected_auth_code
  end

  # Change password: pass in unecrypted password, sets 'password' attribute
  # with a hashed copy (that is what is stored in the database).
  #
  #   user.change_password('new_password')
  #
  def change_password(pass)
    if !pass.blank?
      update_attribute "password", self.class.sha1(pass)
    end
  end

  # Returns +login+ for debugging.
  def text_name
    login.to_s
  end

  # Return User's full name (if present) together with login.  This is
  # guaranteed to be unique.
  #
  #   name present:  "Fred Flintstone (fred99)"
  #   name missing:  "fred99"
  #
  def unique_text_name
    if !name.blank?
      sprintf("%s (%s)", name, login)
    else
      login
    end
  end

  # Return User's full name if present, else return login.
  #
  #   name present:  "Fred Flintstone"
  #   name missing:  "fred99"
  #
  def legal_name
    if self.name.to_s != ''
      self.name
    else
      self.login
    end
  end

  # Calculate the User's progress in completing their profile.  It is currently
  # based on three equal factors:
  # * notes = 33%
  # * location = 33%
  # * image = 33%
  #
  def percent_complete
    max = 3
    result = 0
    if self.notes && self.notes != ""
      result += 1
    end
    if self.location_id
      result += 1
    end
    if self.image_id
      result += 1
    end
    result * 100 / max
  end

  # Is the User in a given UserGroup?  (Specify group by name, not id.)
  #
  #   user.in_group?('reviewers')
  #
  def in_group?(group)
    result = false
    if group.is_a?(UserGroup)
      user_groups.include?(group)
    else
      user_groups.any? {|g| g.name == group.to_s}
    end
  end

  # Does this User want us to do the autologin cookie thing?
  def remember_me?
    self.remember_me
  end

  # Has this user expressed positive or negative interest in a given object?
  # Returns +:watching+ or +:ignoring+ if so, else +nil+.  Caches result.
  #
  #   case user.interest_in(observation)
  #   when :watching; ...
  #   when :ignoring; ...
  #   end
  #
  def interest_in(object)
    @interests ||= {}
    @interests["#{object.class.name} #{object.id}"] ||= begin
      state = Interest.connection.select_value %(
        SELECT state FROM interests
        WHERE user_id = #{id}
          AND object_type = '#{object.class.name}'
          AND object_id = #{object.id}
        LIMIT 1
      )
      state == '1' ? :watching : state == '0' ? :ignoring : nil
    end
  end

  # Has this user expressed positive interest in a given object?
  #
  #   user.watching?(observation)
  #
  def watching?(object)
    interest_in(object) == :watching
  end

  # Has this user expressed negative interest in a given object?
  #
  #   user.ignoring?(name)
  #
  def ignoring?(object)
    interest_in(object) == :ignoring
  end

  # Sum up all the bonuses the User has earned.
  #
  #   contribution += user.sum_bonuses
  #
  def sum_bonuses
    if bonuses
      bonuses.inject(0) {|sum, pair| sum + pair[0]}
    end
  end

  # Return an Array of Project's that this User is an admin for.
  def projects_admin
    Project.find_by_sql %(
      SELECT projects.* FROM projects, user_groups_users
      WHERE projects.admin_group_id = user_groups_users.user_group_id
        AND user_groups_users.user_id = #{id}
    )
  end

  # Return an Array of Project's that this User is a member of.
  def projects_member
    Project.find_by_sql %(
      SELECT projects.* FROM projects, user_groups_users
      WHERE projects.user_group_id = user_groups_users.user_group_id
        AND user_groups_users.user_id = #{id}
    )
  end

  # Get list of users to prime auto-completer.  Returns a simple Array of up to
  # 1000 (by contribution or created within the last month) login String's
  # (with full name in parens).
  def self.primer
    result = []
    if !File.exists?(USER_PRIMER_CACHE_FILE) ||
       File.mtime(USER_PRIMER_CACHE_FILE) < Time.now - 1.day

      # Get list of users sorted first by when they last logged in (if recent),
      # then by cotribution.
      result = self.connection.select_values(%(
        SELECT CONCAT(users.login, IF(users.name = "", "", CONCAT(" <", users.name, ">")))
        FROM users
        ORDER BY IF(last_login > CURRENT_TIMESTAMP - INTERVAL 1 MONTH, last_login, NULL) DESC,
                 contribution DESC
        LIMIT 1000
      )).uniq.sort

      open(USER_PRIMER_CACHE_FILE, 'w').write(result.join("\n") + "\n")
    else
      result = open(USER_PRIMER_CACHE_FILE).readlines.map(&:chomp)
    end
    return result
  end

  ##############################################################################
  #
  #  :section: Alert Stuff
  #
  ##############################################################################

  # List of all allowed alert types.
  #
  #   raise unless User.all_alert_types.include? :bogus_alert
  #
  def self.all_alert_types
    [:bounced_email, :other]
  end

  protected
  # Get alert structure, initializing it with an empty hash if necessary.
  def get_alert # :nodoc:
    self.alert ||= {}
  end
  public

  # When the alert was created.
  def alert_created
    get_alert[:created]
  end
  def alert_created=(x)
    get_alert[:created] = x
  end

  # ID of the admin User that created the alert.
  def alert_user_id
    get_alert[:user_id]
  end
  def alert_user_id=(x)
    get_alert[:user_id] = x
  end

  # Instance of admin User that created the alert.
  def alert_user
    User.find(alert_user_id)
  end
  def alert_user=(x)
    get_alert[:user_id] = x ? x.id : nil
  end

  # Next time the alert will be shown.
  def alert_next_showing
    get_alert[:next_showing]
  end
  def alert_next_showing=(x)
    get_alert[:next_showing] = x
  end

  # Type of alert (e.g., :bounced_email).
  def alert_type
    get_alert[:type]
  end
  def alert_type=(x)
    get_alert[:type] = x
  end

  # Additional notes admin added when creating alert.
  def alert_notes
    get_alert[:notes]
  end
  def alert_notes=(x)
    get_alert[:notes] = x
  end

  # Get the localization string for the alert message for this type of alert.
  # This is the actual message that will be displayed for the user in question.
  #
  #   <%= user.alert_message.tp %>
  #
  def alert_message
    "user_alert_message_#{alert_type}".to_sym
  end

################################################################################

protected

  # Encrypt a password.
  def self.sha1(pass) # :nodoc:
    Digest::SHA1.hexdigest("something__#{pass}__")
  end

  # Encrypted code used in autologin cookie and API authentication.
  def protected_auth_code # :nodoc:
    Digest::SHA1.hexdigest("SdFgJwLeR#{self.password}WeRtWeRkTj")
  end

  # This is a +before_create+ callback that encrypts the password before saving
  # the new user record.  (Not needed for updates because we use
  # change_password for that instead.)
  def crypt_password # :nodoc:
    write_attribute("password", self.class.sha1(password))
  end

  def validate # :nodoc:
    if self.login.to_s.blank?
      errors.add(:login, :validate_user_login_missing.t)
    elsif self.login.length < 3 or self.login.length > 40
      errors.add(:login, :validate_user_login_too_long.t)
    elsif (other = User.find_by_login(self.login)) && (other.id != self.id)
      errors.add(:login, :validate_user_login_taken.t)
    end

    if self.password.to_s.blank?
      errors.add(:password, :validate_user_password_missing.t)
    elsif self.password.length < 5 or password.length > 40
      errors.add(:password, :validate_user_password_too_long.t)
    end

    if self.email.to_s.blank?
      errors.add(:email, :validate_user_email_missing.t)
    elsif self.email.length > 80
      errors.add(:email, :validate_user_email_too_long.t)
    end

    if self.theme.to_s.length > 40
      errors.add(:theme, :validate_user_theme_too_long.t)
    end
    if self.name.to_s.length > 80
      errors.add(:name, :validate_user_name_too_long.t)
    end
  end

  def validate_on_create # :nodoc:
    if self.password_confirmation.to_s.blank?
      errors.add(:password, :validate_user_password_confirmation_missing.t)
    elsif self.password != self.password_confirmation
      errors.add(:password, :validate_user_password_no_match.t)
    end
  end
end

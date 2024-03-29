# encoding: utf-8
#
#  = QueuedEmail
#
#  Model to describe a single email.  There are several related classes in a
#  somewhat complicated relationship, so I'm going to describe them all here.
#
#  QueuedQueuedEmail::    Base class.
#  QueuedEmail::Xxxx::    Derived classes: one record per email.
#  AccountMailer::  This is the class that actually sends email.  It is never
#                   instantiated; it's just a collection of class methods.
#
#  In addition, each QueuedEmail record can own zero or more of each of these:
#
#  QueuedEmailInteger::  Contains a single integer, e.g., name id.
#  QueuedEmailString::   Contains a single fixed-length string.
#  QueuedEmailNote::     Contains a single arbitrary-length string.
#
#  The specific email classes know which data are required for themselves: how
#  to store it, how to retrieve it, and how to deliver the actual mail (via
#  AccountMailer).
#
#  == Typical execution flow
#
#  1. User takes some action that triggers an email (e.g. posting a comment)
#
#  2. The controller involved will queue the appropriate email with:
#
#       QueuedEmail::NameChange.create_email(from, to, comment)
#
#  3. This class method creates a database record, and attaches any data it
#     needs (in this case just one integer for the Comment ID).
#
#  4. That's it for a while. The record (and data) describing the email sit in
#     the database until a cronjob deems it time to finally send it.
#
#  5. (In the meantime some email records might actually be updated, e.g. if a
#     user quickly turns around and edits their comment.)
#
#  6. The cronjob runs:
#
#       rake email:send
#
#     which in turn looks up QueuedEmail records (automatically upgraded to the
#     appropriate subclass via the type column) and delivers them once they've
#     been around long enough.  It does this with:
#
#       email.send_email()
#
#  7. QueuedEmail::Blah grabs all the attached data it needs (often done in the
#     constructor, actually), and calls the appropriate AccountMailer method:
#
#       AccountMailer.comment(from, to, observation, comment)
#
#  8. AccountMailer renders the email message and dispatches it to postfix or
#     whichever mailserver is responsible for delivering email.
#
#  == Basic properties
#
#  1. has a sender (called "user")
#  2. has a receiver (called "to_user")
#  3. has a time (called "queued" -- when it was last modified)
#  4. has zero or more queued_email_integers
#  5. has zero or more queued_email_strings
#  6. has zero or one queued_email_note
#
#  == Class methods
#
#  all_flavors::      List of acceptable flavors (Symbol instances).
#  queue_emails::     Turn queuing on in test suite.
#
#  == Instance methods
#
#  create::           Initialize and save.
#  finish::           Does nothing.
#  send_email::       Calls send_email, catching errors.
#  dump::             Dumps all info about email to a string.
#  text_name::        Returns summary for debugging.
#  ---
#  add_integer::      Add one integer.
#  add_string::       Add one fixed-length string.
#  set_note::         Create arbitrary-length string.
#  add_to_note_list:: Add words to comma-joined list in note.
#  ---
#  get_integer::      Retrieve one integer.
#  get_object::       Retrieve object of given type.
#  get_string::       Retrieve one fixed-length string.
#  get_note::         Retrieve the arbitrary-length string.
#  get_note_list::    Split note apart by comma.
#  get_integers::     Get integers for given array of keys.
#  get_integers::     Same but returns hash instead of array.
#  get_strings::      Get strings for given array of keys.
#  get_strings::      Same but but returns hash instead of array.
#
#  *NOTE*: The last set of "get_blah" methods are all cached in the instance.
#
#  == Note on inheritance
#
#  The QueuedEmail subclasses use ActiveRecord's single table inheritance
#  capability.  All the subclasses' records are stored in one table,
#  "queued_emails".  The class is determined by the flavor.
#  QueuedEmail::CommentAdd's flavor is "QueuedEmail::CommentAdd", and so on.
#  When a QueuedEmail record is instantiated, it automatically is cast as the
#  correct class: 
#
#    # This returns an instance of QueuedEmail::CommentAdd.
#    email = QueuedEmail.find_by_flavor('QueuedEmail::CommentAdd')
#
#  Create records just like normal:
#
#    # This automatically sets flavor to 'QueuedEmail::CommentAdd'.
#    email = QueuedEmail::CommentAdd.new
#
################################################################################

class QueuedEmail < AbstractModel
  has_many :queued_email_integers, :dependent => :destroy
  has_many :queued_email_strings,  :dependent => :destroy
  has_one  :queued_email_note,     :dependent => :destroy
  belongs_to :user
  belongs_to :to_user, :class_name => "User", :foreign_key => "to_user_id"

  # This tells ActiveRecord to instantiate new records into the class referred
  # to in the 'flavor' column, e.g., QueuedEmail::NameChange.  The configuration is
  # important to convince it not to strip the "QueuedEmail::" off the front.
  set_inheritance_column 'flavor'
  self.store_full_sti_class = true

  # Ensure that all the subclasses get loaded.  Problem is some subclasses have
  # the same name as toplevel classes, e.g., QueuedEmail::Comment.  Thus the
  # constant QueuedEmail::Comment will already be "defined" if Comment is
  # loaded, so it won't know to try to load the one in QueuedEmail.  This way,
  # soon as QueuedEmail is defined, we know that all subclasses are also
  # properly defined, and we no longer have to rely on autoloading. 
  Dir["#{RAILS_ROOT}/app/models/queued_email/*.rb"].each do |file|
    if file.match(/(\w+).rb/)
      require "queued_email/#{$1}"
    end
  end

  # ----------------------------
  # :section: General methods.
  # ----------------------------

  # Return list of valid flavors (just a list of derived class names).  Returns
  # an array of String instances.  (Lists the app/models/email subdirectory and
  # caches it.)
  #
  #   # Validate flavor.
  #   raise unless QueuedEmail.all_flavors.include? 'QueuedEmail::CommentAdd'
  def self.all_flavors
    if !defined? @@all_flavors
      @@all_flavors = []
      Dir["#{RAILS_ROOT}/app/models/queued_email/*.rb"].each do |file|
        if file.match(/(\w+).rb/)
          @@all_flavors << "QueuedEmail::#{$1.camelize}"
        end
      end
    end
    return @@all_flavors
  end

  @@queue = false
  # This lets me turn queuing on in unit tests.
  #
  #   # Turn on queuing.
  #   QueuedEmail.queue_emails(true)
  #
  #   # Turn off queuing.
  #   QueuedEmail.queue_emails(false)
  def self.queue_emails(state)
    @@queue = state
  end

  # Create new email and save it.
  #
  #   module Email
  #     class ObjectEmail < QueuedEmail
  #       def self.create_for_comment(object)
  #
  #         # This creates email when one user comments on another's object.
  #         # NOTE: it will be instantiated as an QueuedEmail::ObjectEmail.
  #         email = create(object.comment.user, object.owner)
  #
  #         # Email has been saved, so it is safe to add data now.
  #         email.add_integer('object', object.id)
  #
  #         # Allow QueuedEmail to deliver it immediately if we aren't queuing.
  #         email.finish
  #
  #         # Returns an instance of QueuedEmail::ObjectEmail.
  #         # (Flavor will be "QueuedEmail::ObjectEmail".)
  #         return email
  #       end
  #     end
  #   end
  #
  def self.create(sender, receiver)
    # Let ActiveRecord::Base create the record for us.
    super(
      :user    => sender,
      :to_user => receiver,
      :queued  => Time.now
    )
  end

  # This is called after an email is created and populated.  In normal
  # production mode this does nothing.  In testing mode it "delivers" the email
  # immediately (via deliver_email) and then removes it from the queue.
  def finish
    self.class.debug_log("SAVE #{self.flavor} " +
         "from=#{user.login rescue 'nil'} " +
         "to=#{to_user.login rescue 'nil'} " +
         queued_email_integers.map {|x| "#{x.key}=#{x.value}"}.join(' ') +
         queued_email_strings.map {|x| "#{x.key}=\"#{x.value}\""}.join(' '))
    current_locale = Locale.code
    unless QUEUE_EMAIL || @@queue
      self.deliver_email if RunLevel.is_normal?
      self.destroy
    end
    Locale.code = current_locale
  end

  # This is called by <tt>rake email:send</tt>.  It just checks that sender !=
  # receiver, then passes it off to the subclass (via deliver_email). 
  def send_email
    return true if not RunLevel.is_normal?
    log_msg = "SEND #{self.flavor} " +
      "from=#{user.login rescue 'nil'} " +
      "to=#{to_user.login rescue 'nil'} " +
      queued_email_integers.map {|x| "#{x.key}=#{x.value}"}.join(' ') +
      queued_email_strings.map {|x| "#{x.key}=\"#{x.value}\""}.join(' ')
    self.class.debug_log(log_msg)
    current_locale = Locale.code
    result = false
    if user == to_user
      raise("Skipping email with same sender and recipient: #{user.email}\n") if !TESTING
    else
      result = deliver_email
    end
    Locale.code = current_locale
    return result
  rescue => e
    raise e if TESTING
    $stderr.puts('ERROR CREATING EMAIL')
    $stderr.puts(log_msg)
    $stderr.puts(e.to_s)
    $stderr.puts(e.backtrace)
    Locale.code = current_locale
    return false
  end

  # This method needs to be defined in the subclasses.
  def deliver_email
    error = "We forgot to define #{type}#deliver_email.\n"
    # Failing to send email should not throw an error in production
    if PRODUCTION
      $stderr.puts(error)
    else
      raise error
    end
  end

  # Returns "flavor from to" for debugging.
  def text_name
    "#{flavor.sub('QueuedEmail::','')} #{user ? user.login : 'no one'} -> #{to_user ? to_user.login : 'no one'}"
  end

  # Dump out all the info about a QueuedEmail record to a string.
  def dump
    result = ''
    result += "#{self.id}: from => #{self.user and self.user.login}, "
    result += "to => #{self.to_user.login}, flavor => #{self.flavor}, "
    result += "queued => #{self.queued}\n"
    for i in self.queued_email_integers
      result += "\t#{i.key.to_s} => #{i.value}\n"
    end
    for i in self.queued_email_strings
      result += "\t#{i.key.to_s} => #{i.value}\n"
    end
    if self.queued_email_note
      result += "\tNote: #{self.queued_email_note.value}\n"
    end
    result
  end

  # Add line to log to help keep track of what/when/why emails are being queued
  # and when they are actually sent.
  def self.debug_log(msg)
    File.open("#{RAILS_ROOT}/log/email-debug.log", 'a') do |fh|
      fh.puts("#{Time.now.api_time} #{msg}")
    end
  end

  # -------------------------------------
  # :section: Methods for getting data.
  # -------------------------------------

  # Get integer for the given key.
  # key:: name of integer to get
  #
  #   object_id = email.get_integer('object')
  #
  def get_integer(key)
    @integers ||= {}
    if @integers.has_key?(key)
      result = @integers[key]
    else
      int = QueuedEmailInteger.find_by_queued_email_id_and_key(self.id, key.to_s)
      result = @integers[key] = int ? int.value.to_i : nil
    end
    return result
  end

  # Look-up an object corresponding to a given integer (id).
  # key::       name of integer to get
  # model::     class of model to look for id in
  # allow_nil:: is nil/zero id acceptible? (if not will raise RecordNotFound)
  #
  #   comment = email.get_object('comment', Comment, :nil_okay)
  #
  def get_object(key, model, allow_nil=false)
    @objects ||= {}
    if @objects.has_key?(key)
      result = @objects[key]
    else
      id = get_integer(key)
      result = @objects[key] = (id == 0 && allow_nil) ? nil : model.safe_find(id)
    end
    result
  end

  # Get string for the given key.
  # key:: name of string to get
  #
  #   user_name = email.get_string('user')
  #
  def get_string(key)
    @strings ||= {}
    if @strings.has_key?(key)
      result = @strings[key]
    else
      str = QueuedEmailString.find_by_queued_email_id_and_key(self.id, key.to_s)
      result = @strings[key] = str ? str.value.to_s : nil
    end
    return result
  end

  # Get note.  Returns nil if no note saved.  *NOTE*: this can be used to
  # serialize arbitrary structures using YAML.
  #
  #   struct = YAML::load(email.get_note)
  #
  def get_note
    note = queued_email_note
    return note ? note.value.to_s : nil
  end

  # Get note, split on comma.  Useful if you are storing a list of words, e.g.,
  # list of the fields that have changed in an object.
  # 
  #   changed_fields = email.get_note_list
  #
  def get_note_list
    note = queued_email_note
    return note ? note.value.to_s.split(',') : nil
  end

  # Get integers for an Array of keys.  Returns either an Array of results in
  # the order requested, or it returns a hash of all available integers keyed
  # on their names.
  #
  #   ints = email.get_integers(['observation', 'naming', 'vote'])
  #   puts "obs_id = #{ints[0]}"
  #   puts "nam_id = #{ints[1]}"
  #   puts "vot_id = #{ints[2]}"
  #
  #   dict = email.get_integers(this_is_ignored, true)
  #   puts "obs_id = #{dict['observation']}"
  #   puts "nam_id = #{dict['naming']}"
  #   puts "vot_id = #{dict['vote']}"
  #
  def get_integers(keys, return_dict=false)
    @integers = {}
    for qi in self.queued_email_integers
      @integers[qi.key.to_s] = qi.value.to_i
    end
    if return_dict
      result = @integers
    else
      result = []
      for key in keys
        result.push(@integers[key.to_s])
      end
    end
    result
  end

  # Get strings for an Array of keys.  Returns either an Array of results in
  # the order requested, or it returns a hash of all available strings keyed
  # on their names.
  #
  #   strs = email.get_strings(['login', 'name'])
  #   puts "login = #{strs[0]}"
  #   puts "name  = #{strs[1]}"
  #
  #   dict = email.get_strings(this_is_ignored, true)
  #   strs "login = #{dict['login']}"
  #   strs "name  = #{dict['name']}"
  #
  def get_strings(keys, return_dict=false)
    @strings = {}
    for qs in self.queued_email_strings
      @strings[qs.key.to_s] = qs.value.to_s
    end
    if return_dict
      result = @strings
    else
      result = []
      for key in keys
        result.push(@strings[key.to_s])
      end
    end
    result
  end

  # -----------------------------------------------
  # :section: Methods for adding additional data.
  # -----------------------------------------------

  # Attach an integer to this email.
  #
  #   email.add_integer('observation_id', obs.id)
  #
  def add_integer(key, value)
    int = QueuedEmailInteger.find_by_queued_email_id_and_key(self.id, key.to_s)
    if !int
      int = QueuedEmailInteger.new()
      int.queued_email_id = self.id
      int.key = key.to_s
    end
    int.value = value.to_i
    int.save
    return int
  end

  # Attach a string to this email.  (*NOTE*: max length is 100 chars.)
  #
  #   email.add_string('login', user.login)
  #
  def add_string(key, value)
    str = QueuedEmailString.find_by_queued_email_id_and_key(self.id, key.to_s)
    if !str
      str = QueuedEmailString.new()
      str.queued_email_id = self.id
      str.key = key.to_s
    end
    str.value = value.to_s
    str.save
    return str
  end

  # Attach a note to this email.  This has no maximum length.  *NOTE*: this can
  # be used to store arbitrary structures using YAML.  It can also be used with
  # get_note_list and add_to_note_list to keep a simple Array of words.
  #
  #   # Just save a long string of text.
  #   email.add_note(obs.notes)
  #
  #   # Save a data structure.
  #   email.add_note(YAML::dump(obs.data))
  #
  #   # Save list of attributes that have changed.
  #   email.add_note(obs.changed.map(&:to_s).join(','))
  #
  def set_note(value)
    note = self.queued_email_note
    if !note
      note = QueuedEmailNote.new()
      note.queued_email_id = self.id
    end
    note.value = value
    note.save
    self.queued_email_note = note
  end

  # Add an Array of words to the note.  Note does not have to be initialized
  # before using this.  It ensures that there are no duplicates.  It converts
  # all values to strings before adding them. *NOTE*: words must not contain
  # commas! 
  #
  #   # Save a list of changed attribute names.
  #   email.add_to_note_list(obs.changed)
  #
  def add_to_note_list(values)
    note = self.queued_email_note
    if !note
      note = QueuedEmailNote.new()
      note.queued_email_id = self.id
    end
    old_val = note.value.to_s
    list = old_val.split(',') + values.map(&:to_s)
    new_val = list.uniq.join(',')
    if note.new_record? || old_val != new_val
      note.value = new_val
      note.save
    end
    self.queued_email_note = note
  end
end

################################################################################

# Tell rdoc not to document Email class.  (But do allow subclasses!)
class Email # :nodoc:
end


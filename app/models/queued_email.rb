class QueuedEmail < ActiveRecord::Base
  has_many :queued_email_integers,      :dependent => :destroy
  has_many :queued_email_strings,       :dependent => :destroy
  has_one :queued_email_note,           :dependent => :destroy
  belongs_to :user
  belongs_to :to_user, :class_name => "User", :foreign_key => "to_user_id"

  # Returns: array of symbols.  Essentially a constant array.
  def self.all_flavors()
    [:comment, :feature, :naming, :publish, :name_proposal, :consensus_change, :name_change]
  end

  # This lets me turn queuing on in unit tests.
  @@queue = false
  def self.queue_emails(state)
    @@queue = state
  end

  # Like initialize, but ensures that the objects is saved
  # and is ready to have parameters added.
  def setup(sender, receiver, flavor)
    self.user_id = sender ? sender.id : 0
    self.to_user = receiver
    self.flavor = flavor
    self.queued = Time.now()
    self.save()
  end

  # Centralized place to hang code after all the parameters are set.
  # For now it makes sure the email is sent if queuing is disabled.
  def finish
    unless QUEUE_EMAIL || @@queue
      self.send_email
    end
  end

  # The different types of email should be handled by separate classes
  def send_email
    result = nil
    begin
      result = self.deliver_email
    rescue
      print "Unable to send queued email:\n"
      self.dump()
      # Failing to send email should not throw an error in production
      raise unless ENV['RAILS_ENV'] == 'production'
    end
    result
  end

  # This instantiates an instance of the specific email type, then
  # tells it to deliver the mail.
  def deliver_email
    class_name = self.flavor.to_s.camelize + "Email"
    email = class_name.constantize.new(self)
    email.deliver_email
    return email
  end

  # Print out all the info about a QueuedEmail
  def dump
    print "#{self.id}: from => #{self.user and self.user.login}, to => #{self.to_user.login}, flavor => #{self.flavor}, queued => #{self.queued}\n"
    for i in self.queued_email_integers
      print "\t#{i.key.to_s} => #{i.value}\n"
    end
    for i in self.queued_email_strings
      print "\t#{i.key.to_s} => #{i.value}\n"
    end
    if self.queued_email_note
      print "\tNote: #{self.queued_email_note.value}\n"
    end
  end

  # ----------------------------
  #  Methods for getting data.
  # ----------------------------

  def get_integer(key)
    begin
      self.queued_email_integers.select {|qi| qi.key == key.to_s}.first.value
    rescue
    end
  end

  def get_string(key)
    begin
      self.queued_email_strings.select {|qs| qs.key == key.to_s}.first.value
    rescue
    end
  end

  def get_note
    begin
      self.queued_email_note.value
    rescue
    end
  end

  def get_integers(keys, return_dict=false)
    dict = {}
    for qi in self.queued_email_integers
      dict[qi.key] = qi.value
    end
    if return_dict
      result = dict
    else
      result = []
      for key in keys
        result.push(dict[key.to_s])
      end
    end
    result
  end

  def get_strings(keys, return_dict=false)
    dict = {}
    for qs in self.queued_email_strings
      dict[qs.key] = qs.value
    end
    if return_dict
      result = dict
    else
      result = []
      for key in keys
        result.push(dict[key.to_s])
      end
    end
    result
  end

  # --------------------------------------
  #  Methods for adding additional data.
  # --------------------------------------

  def add_integer(key, value)
    result = QueuedEmailInteger.new()
    result.queued_email = self
    result.key = key.to_s
    result.value = value
    result.save()
    result
  end

  def add_string(key, value)
    result = QueuedEmailString.new()
    result.queued_email = self
    result.key = key.to_s
    result.value = value
    result.save()
    result
  end

  def set_note(value)
    result = QueuedEmailNote.new()
    result.queued_email = self
    result.value = value
    result.save()
    result
  end
end

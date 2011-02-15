# encoding: utf-8
#
#  = Comment Model
#
#  A comment is a bit of text a User attaches to an object such as an
#  Observation.  It is polymorphic in the sense that Comment's can be attached
#  to any kind of object, including:
#
#  * Location
#  * Name
#  * Observation
#  * Project
#
#  == Adding Comments to Model
#
#  It's very easy.  Don't forget to add interests as well, because that will
#  allow the owner/authors of the object commented on to be notified of the
#  new comment.  Just follow these easy steps:
#
#  1. Add to +all_types+ Array in this file.
#  2. Add +has_many+ relationships to the model:
#
#       has_many :comments,  :as => :target, :dependent => :destroy
#       has_many :interests, :as => :target, :dependent => :destroy
#
#  3. Add interest "eyes" to the header section of the show_object view:
#
#       draw_interest_icons(@target)
#
#  4. Add show_comments partial at the bottom of the show_object view:
#
#       <%= render(:partial => 'comment/show_comments', :locals =>
#             { :target => @target, :controls => true, :limit => nil }) %>
#
#  5. Tell comment/_object shared view how to display the object (used to
#     embed info about object while user is posting/editing a comment):
#
#       when 'YourModel'
#         render(:partial => 'model/model', :target => target)
#
#  6. Tell Query how to do the polymorphic join (optional):
#
#       self.join_conditions => {
#         :comments => {
#           :new_table => :target,
#         }
#       }
#
#  == Attributes
#
#  id::        Locally unique numerical id, starting at 1.
#  sync_id::   Globally unique alphanumeric id, used to sync with remote servers.
#  created::   Date/time it was first created.
#  modified::  Date/time it was last modified.
#  user::      User that created it.
#  target::    Object it is attached to.
#  summary::   Summary line (100 chars).
#  comment::   Full text (any length).
#
#  == Instance Methods
#
#  text_name::              Alias for +summary+ for debugging.
#  target_type_localized::  Translate the name of the object type it's attached to.
#
#  ==== Logging
#  log_create::             Log creation on object's log if it can.
#  log_update::             Log update on object's log if it can.
#  log_destroy::            Log destruction on object's log if it can.
#
#  ==== Callbacks
#  notify_users::           Sends notification emails after creation.
#
#  == Polymorphism
#
#  ActiveRecord accomplishes polymorphism by storing the object _type_ along
#  side the usual object _id_.  So, while there are the convenience wrappers
#  +target+ and +target=+ that hide this detail, underneath there are actually
#  two columns in the database table:
#
#  target_type::  Class name of object (string).
#  target_id::    Id of object (integer).
#
#  Note that most of ActiveRecord's magic continues to work:
#
#    # Find first comment attached to an observation.
#    Comment.find_by_target(observation)
#
#    # Have we changed the object reference (either type or id)?
#    comment.target_changed?
#
################################################################################

class Comment < AbstractModel
  belongs_to :target, :polymorphic => true
  belongs_to :user

  after_create :notify_users

  # Returns Array of all valid +target_type+ values (Symbol's).
  def self.all_types
    [ Location, Name, Observation, Project ]
  end

  # Returns +summary+ for debugging.
  def text_name
    summary.to_s
  end

  # Returns the name of the object type, translated into the local language.
  # Returns '' if fails for any reason.  Equivalent to:
  #
  #   comment.target_type.downcase.to_sym.l
  #
  def target_type_localized
    self.target_type.downcase.to_sym.l rescue ''
  end

  ##############################################################################
  #
  #  :section: Logging
  #
  ##############################################################################

  # Log creation of comment on object's RSS log if it can.
  def log_create(target=self.target)
    if target && target.respond_to?(:log)
      target.log(:log_comment_added, :summary => summary, :touch => true)
    end
  end

  # Log update of comment on object's RSS log if it can.
  def log_update(target=self.target)
    if target && target.respond_to?(:log)
      target.log(:log_comment_updated, :summary => summary, :touch => false)
    end
  end

  # Log destruction of comment on object's RSS log if it can.
  def log_destroy(target=self.target)
    if target && target.respond_to?(:log)
      target.log(:log_comment_destroyed, :summary => summary, :touch => false)
    end
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # Callback called after creation.  Lots of people potentially can receive an
  # email whenever a Comment is posted:
  #
  # 1. the owner of the object
  # 2. users who already commented on the same object
  # 3. users who have expressed Interest in that object
  # 4. users masochistic enough to want to be notified of _all_ comments
  #
  def notify_users
    if target = self.target
      sender = self.user
      recipients = []

      # Send to owner/authors if they want.
      if target.respond_to?(:authors)
        owners = target.authors || []
      else
        owners = [target.user]
      end
      for user in owners
        recipients.push(user) if user && user.email_comments_owner
      end

      # Send to masochists who want to see all comments.
      for user in User.find_all_by_email_comments_all(true)
        recipients.push(user)
      end

      # Send to other people who have commented on this same object if they want.
      for other_comment in Comment.find(:all, :conditions =>
          ['comments.target_type = ? AND comments.target_id = ? AND users.email_comments_response = TRUE',
          target.class.to_s, target.id], :include => 'user')
        recipients.push(other_comment.user)
      end

      # Send to people who have registered interest.
      # Also remove everyone who has explicitly said they are NOT interested.
      for interest in Interest.find_all_by_target(target)
        if interest.state
          recipients.push(interest.user)
        else
          recipients.delete(interest.user)
        end
      end

      # Send comment to everyone (except the person who wrote the comment!)
      for recipient in recipients.uniq - [sender]
        if recipient.created_here
          QueuedEmail::CommentAdd.find_or_create_email(sender, recipient, self)
        end
      end
    end
  end

################################################################################

protected

  def validate # :nodoc:
    if !self.user && !User.current
      errors.add(:user, :validate_comment_user_missing.t)
    end

    if self.summary.to_s.blank?
      errors.add(:summary, :validate_comment_summary_missing.t)
    elsif self.summary.length > 100
      errors.add(:summary, :validate_comment_summary_too_long.t)
    end

    if self.target_type.to_s.length > 30
      errors.add(:target_type, :validate_comment_object_type_too_long.t)
    end
  end
end

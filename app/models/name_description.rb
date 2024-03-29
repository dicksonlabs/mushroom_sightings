# encoding: utf-8
#
#  = Name Descriptions
#
#  == Version
#
#  Changes are kept in the "name_descriptions_versions" table using
#  ActiveRecord::Acts::Versioned.
#
#  == Attributes
#
#  id::               (-) Locally unique numerical id, starting at 1.
#  sync_id::          (-) Globally unique alphanumeric id, used to sync with remote servers.
#  created::          (-) Date/time it was first created.
#  modified::         (V) Date/time it was last modified.
#  user::             (V) User that created it.
#  version::          (V) Version number.
#  merge_source_id::  (V) Used to keep track of descriptions that were merged into this one.
#                         Primarily useful in the past versions: stores id of latest version
#                         of the Description merged into this one at the time of the merge.
#
#  ==== Statistics
#  review_status::    (-) :vetted, :unvetted, :inaccurate, :unreviewed.
#  last_review::      (-) Last time it was reviewed.
#  reviewer::         (-) User that reviewed it.
#  ok_for_export::    (-) Boolean: is this ready for export to EOL?
#  num_views::        (-) Number of times it has been viewed.
#  last_view::        (-) Last time it was viewed.
#
#  ==== Description Fields
#  license::          (V) License description info is kept under.
#  classification::   (V) Taxonomic classification.
#  gen_desc::         (V) General description.
#  diag_desc::        (V) Diagnostic description.
#  distribution::     (V) Distribution.
#  habitat::          (V) Habitat.
#  look_alikes::      (V) Look-alikes.
#  uses::             (V) Uses.
#  notes::            (V) Other notes.
#  refs::             (V) References
#
#  ('V' indicates that this attribute is versioned in
#  name_descriptions_versions table.)
#
#  == Class Methods
#
#  all_note_fields::     NameDescriptive text fields: all.
#  eol_note_fields::     NameDescriptive text fields: ones that don't require special handling for EOL.
#  all_review_statuses:: Review status: allowed values.
#
#  == Instance Methods
#
#  ==== Attachments
#  versions::            Old versions.
#  comments::            Comments about this NameDescription. (not used yet)
#  interests::           Interest in this NameDescription
#
#  ==== Review Status
#  update_review_status:: Change review status.
#
#  == Callbacks
#
#  notify_users::       Notify authors, etc. of changes.
#
############################################################################

class NameDescription < Description
  belongs_to :license
  belongs_to :name
  belongs_to :project
  belongs_to :reviewer, :class_name => 'User', :foreign_key => 'reviewer_id'
  belongs_to :user

  has_many :comments,  :as => :target, :dependent => :destroy
  has_many :interests, :as => :target, :dependent => :destroy

  has_and_belongs_to_many :admin_groups,  :class_name => "UserGroup", :join_table => "name_descriptions_admins"
  has_and_belongs_to_many :writer_groups, :class_name => "UserGroup", :join_table => "name_descriptions_writers"
  has_and_belongs_to_many :reader_groups, :class_name => "UserGroup", :join_table => "name_descriptions_readers"
  has_and_belongs_to_many :authors,       :class_name => "User",      :join_table => "name_descriptions_authors"
  has_and_belongs_to_many :editors,       :class_name => "User",      :join_table => "name_descriptions_editors"

  EOL_NOTE_FIELDS = [:gen_desc, :diag_desc, :distribution, :habitat, :look_alikes, :uses]
  ALL_NOTE_FIELDS = [:classification] + EOL_NOTE_FIELDS + [:refs, :notes]

  acts_as_versioned(
    :table_name => 'name_descriptions_versions',
    :if_changed => ALL_NOTE_FIELDS,
    :association_options => { :dependent => :orphan }
  )
  non_versioned_columns.push(
    'sync_id',
    'created',
    'name_id',
    'review_status',
    'last_review',
    'reviewer_id',
    'ok_for_export',
    'num_views',
    'last_view',
    'source_type',
    'source_name',
    'project_id',
    'public',
    'locale'
  )

  versioned_class.before_save {|x| x.user_id = User.current_id}
  after_update :notify_users
  after_save :update_classification_cache

  # Don't add any authors until someone has written something "useful".
  def author_worthy?
    !gen_desc.blank? || !diag_desc.blank?
  end

  ################################################################################
  #
  #  :section: Descriptions
  #
  ################################################################################

  # Returns an Array of all the descriptive text fields that don't require any
  # special processing when they go to EOL.  Fields are all Symbol's.
  def self.eol_note_fields
    # These fields all get handled the same way when they go to EOL
    EOL_NOTE_FIELDS
  end

  # Returns an Array of all the descriptive text fields (Symbol's).
  #
  # *NOTE*: :references behave differently for EOL output and :notes get
  # ignored altogether.  Order is important for UI layout.
  #
  def self.all_note_fields
    ALL_NOTE_FIELDS
  end

  ##############################################################################
  #
  #  :section: Reviewing
  #
  ##############################################################################

  ALL_REVIEW_STATUSES = [:unreviewed, :unvetted, :vetted, :inaccurate]

  # Returns an Array of all possible values for +review_status+ (Symbol's).
  def self.all_review_statuses
    ALL_REVIEW_STATUSES
  end

  # Update the review status.  Saves the changes if there are no substantive
  # changes pending.  (Don't want to inadvertantly create multiple past_name
  # versions.)  Raises a RuntimeError if it fails to save for some reason.
  #
  # Note on permissions: Only reviewers can set the value to anything other
  # than :unreviewed.  The only way for this method to be called by a
  # non-reviewer is if a non-reviewer publishes a draft.  Note, the review
  # status can also get reset back to :unreviewed by edit_name in
  # name_controller if a non-reviewer makes any substantive change to the Name.
  #
  def update_review_status(value)
    user = User.current
    if not user.in_group?('reviewers')
      # This communicates the name of the old reviewer to notify_authors.
      # This allows it to notify the old reviewer of the change.
      @old_reviewer = reviewer
      value = :unreviewed
      reviewer_id = nil
    else
      reviewer_id = user.id
    end
    self.review_status = value
    self.reviewer_id   = reviewer_id
    self.last_review   = Time.now

    # Save unless there are substantive changes pending.
    if !save_version?
      save_without_our_callbacks
      if errors.length > 0
        raise "update_review_status failed: [#{dump_errors}]"
      end
    end
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # Make sure the classification cached in Name is kept up to date.
  def update_classification_cache
    if (name.description_id == id) and
       (name.classification != classification)
      name.classification = classification
      name.save
    end
  end

  # This is called after saving potential changes to a Name.  It will determine
  # if the changes are important enough to notify the authors, and do so.
  def notify_users

    # "altered?" is acts_as_versioned's equivalent to Rails's changed? method.
    # It only returns true if *important* changes have been made.  Even though
    # changing review_status doesn't cause a new version to be created, I want
    # to notify authors of that change.  (review_status_changed? is an implicit
    # method created by ActiveRecord)
    if altered? || review_status_changed?
      sender = User.current
      recipients = []

      # Tell admins of the change.
      for user in self.admins
        recipients.push(user) if user.email_names_admin
      end

      # Tell authors of the change.
      for user in self.authors
        recipients.push(user) if user.email_names_author
      end

      # Tell editors of the change.
      for user in self.editors
        recipients.push(user) if user.email_names_editor
      end

      # Tell reviewer of the change.
      reviewer = self.reviewer || @old_reviewer
      recipients.push(reviewer) if reviewer && reviewer.email_names_reviewer

      # Tell masochists who want to know about all name changes.
      for user in User.find_all_by_email_names_all(true)
        recipients.push(user)
      end

      # Send to people who have registered interest.
      # Also remove everyone who has explicitly said they are NOT interested.
      for interest in name.interests
        if interest.state
          recipients.push(interest.user)
        else
          recipients.delete(interest.user)
        end
      end

      # Send notification to all except the person who triggered the change.
      for recipient in recipients.uniq - [sender]
        if recipient.created_here
          QueuedEmail::NameChange.create_email(sender, recipient, name, self,
                                               review_status_changed?)
        end
      end
    end

    # No longer need this.
    @old_reviewer = nil
  end

################################################################################

protected

  def validate # :nodoc:
    begin
      self.classification = Name.validate_classification(parent.rank, self.classification)
    rescue => e
      errors.add(:classification, e.to_s)
    end
  end
end

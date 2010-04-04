#
#  = User Group Model
#
#  Model that describes a group of Users.  It used to be pretty
#  straight-forward.  There are now two new classes of groups that muddy the
#  waters: "all users" and "user N".  The first contains all users, whether
#  they are verified or not.  The second is a set of groups, one for each user,
#  each containing just that user and no others.  Both of these "meta-groups"
#  are considered "frozen" in that they can not be modified.  (Obviously,
#  "all users" is modified every time a user is created or destroyed, but no
#  user is allowed to make changes to it, even the admins.)
#
#  == Attributes
#
#  id::         Locally unique numerical id, starting at 1.
#  sync_id::    Globally unique alphanumeric id, used to sync with remote servers.
#  created::    Date/time it was first created.
#  modified::   Date/time it was last modified.
#  name::       Name of the group, must be unique.
#  meta::       Can members be added or removed from this group?
#
#  == Class methods
#
#  all_users::      Return the meta-group that contains all users.
#  one_user::       Return the meta-group that contains just the given user.
#  reviewers::      Return the group of "reviewers".
#
#  == Instance methods
#
#  users::          List of Users in the group.
#  project::        Project, if one defines their membership using this group.
#  admin_project::  Project, if one defines their admins using this group.
#  text_name::      Alias for +name+ for debugging.
#
#  == Callbacks
#
#  create_user::    Called after a new User is created.
#  destroy_user::   Called after a new User is destroyed.
#
################################################################################

class UserGroup < AbstractModel
  has_and_belongs_to_many :users
  has_one :project
  has_one :admin_project, :class_name => "Project", :foreign_key => "admin_group_id"

  # Returns +name+ for debugging.
  def text_name
    name.to_s
  end

  # Return the meta-group that contains all users.
  def self.all_users
    @@all_users ||= find_by_name('all users')
  end

  # Return the meta-group that contains just the given users.  Takes id or User.
  def self.one_user(user)
    user_id = user.is_a?(User) ? user.id.to_i : user.to_i
    @@one_users ||= {}
    @@one_users[user_id] ||= find_by_name("user #{user_id}")
  end

  # Return the meta-group that contains all users.
  def self.reviewers
    @@reviewers ||= find_by_name('reviewers')
  end

  # Callback that fires when a new User is created.
  # 1) Adds the new User to the "all users" meta-group.
  # 2) Creates a new meta-group that contains just that User.
  def self.create_user(user)
    all_users.users << user
    one_user = create!(
      :name => "user #{user.id}",
      :meta => true
    )
    one_user.users << user
  end

  # Callback that fires when a User is destroyed.
  # 1) Removes the User from the "all users" meta-group.
  # 2) Removes the User from their single-user meta-group.  (Can't delete it
  #    since various Description's might refer to it.  This just emasculates
  #    it.)
  def self.destroy_user(user)
    all_users.users.delete(user)
    one_user(user).users.delete(user)
  end
end

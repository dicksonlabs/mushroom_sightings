# encoding: utf-8
#
#  = Description Controller Helpers
#
#  This is a module that is included by all controllers that deal with
#  descriptions.  (Just LocationController and NameController right now.)
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  make_description_default::
#  merge_descriptions::
#  publish_descriptions::
#  adjust_permissions::
#
#  == Helpers
#  find_description::                   Look up a description based on id and controller name.
#  merge_description_notes::            Merge the notes fields of two descriptions.
#  initialize_description_source::      Initialize source info before serving creation form.
#  initialize_description_permissions:: Initialize permissions of new Description.
#  check_description_edit_permission::  Double check that no illegal changes are being made.
#  modify_description_permissions::     Update blah_groups based on changed to two public checkboxes.
#  update_writein::                     Update the permissions for a write-in user or group.
#  update_groups::                      Update one type of permissions for a Hash of groups.
#  update_group::                       Update one type of permission for one group.
#  flash_description_changes::          Show changes made to permissions.
#  group_name::                         Return human-readable name of UserGroup.
#  perform_merge::                      Merge one description into another if it can.
#
################################################################################

module DescriptionControllerHelpers

  ################################################################################
  #
  #  :section Actions
  #
  ################################################################################

  # Make a description the default one.  Description must be public-readable.
  def make_description_default # :norobots:
    pass_query_params
    if desc = find_description(params[:id])
      if !desc.public
        flash_error(:runtime_description_make_default_only_public.t)
      else
        desc.parent.description_id = desc.id
        desc.parent.log(:log_changed_default_description, :user => @user.login,
                        :name => desc.unique_partial_format_name,
                        :touch => true)
        desc.parent.save
      end
      redirect_to(:action => desc.show_action, :id => desc.id,
                  :params => query_params)
    end
  end

  # Merge a description with another.  User must be both an admin for the
  # old description (which will be destroyed) and a writer for the new one
  # (so they can modify it).  If there is a conflict, it dumps the user into
  # the edit_description form and forces them to do the merge and delete the
  # old description afterword.
  def merge_descriptions # :norobots:
    pass_query_params
    if src = find_description(params[:id])
      @description = src

      # Doesn't have permission to see source.
      if !src.is_reader?(@user)
        flash_error(:runtime_description_private.t)
        redirect_to(:action => src.parent.show_action, :id => src.parent_id,
                    :params => query_params)

      # POST method
      elsif request.method == :post
        delete_after = (params[:delete] == '1')
        target = params[:target].to_s
        if target.match(/^parent_(\d+)$/)
          target_id = $1
          if dest = find_or_goto_index(src.parent.class, target_id)
            do_move_description(src, dest, delete_after)
          end
        elsif target.match(/^desc_(\d+)$/)
          target_id = $1
          if dest = find_description(target_id)
            do_merge_description(src, dest, delete_after)
          end
        else
          flash_error(:runtime_invalid.t(:type => '"target"',
                                         :value => target))
        end
      end
    end
  end

  # Perform actual merge of two descriptions within the same parent.
  def do_merge_description(src, dest, delete_after)
    src_name = src.unique_partial_format_name
    src_title = src.format_name

    # Doesn't have permission to edit destination.
    if !dest.is_writer?(@user)
      flash_error(:runtime_edit_description_denied.t)
      @description = src

    # Conflict: render edit form.
    elsif !perform_merge(src, dest, delete_after)
      flash_warning(:runtime_description_merge_conflict.t)
      @description = dest
      @licenses = License.current_names_and_ids
      merge_description_notes(src, dest)
      @merge = true
      @old_desc_id = src.id
      @delete_after = delete_after
      render(:action => "edit_#{src.parent.type_tag}_description")

    # Merged successfully.
    else
      desc.parent.log(:log_object_merged_by_user, :user => @user.login,
                      :touch => true, :from => src_name,
                      :to => dest.unique_partial_format_name)
      flash_notice(:runtime_description_merge_success.
                   t(:old => src_title, :new => dest.format_name))
      redirect_to(:action => dest.show_action, :id => dest.id,
                  :params => query_params)
    end
  end

  # Perform actual move of a description from one name to another.
  def do_move_description(src, dest, delete_after)
    src_name = src.unique_partial_format_name
    src_title = src.format_name

    # Just transfer the description over.
    if delete_after
      make_dest_default = dest.description_id.nil? && src_was_default
      if src.parent.description_id == src.id
        src.parent.description_id = nil
        src.parent.save
        src.parent.log(:log_changed_default_description, :user => @user.login,
                       :name => :none, :touch => true)
      end
      src.parent = dest
      src.save
      Transaction.send("put_#{src.type_tag}", :parent => dest)
      src.parent.log(:log_object_moved_by_user, :user => @user.login,
                     :from => src_name, :to => dest.unique_format_name,
                     :touch => true)
      if make_dest_default && src.public
        dest.description_id = src
        dest.save
        dest.log(:log_changed_default_description, :user => @user.login,
                 :name => src.unique_partial_format_name, :touch => true)
      end
      flash_notice(:runtime_description_move_success.
                   t(:old => src_title, :new => dest.format_name))
      redirect_to(:action => src.show_action, :id => src.id,
                  :params => query_params)

    # Create a clone in the destination name/location.
    else
      desc = src.class.new(
        :parent      => dest,
        :source_type => src.source_type,
        :source_name => src.source_name,
        :project_id  => src.project_id,
        :locale      => src.locale,
        :public      => src.public,
        :license     => src.license,
        :all_notes   => src.all_notes
      )

      # I think a reviewer should be required to pass off on this before it
      # gets shared with reputable sources.  Synonymy is never a clean science.
      # if dest.is_a?(Name)
      #   desc.review_status = src.review_status
      #   desc.last_review   = src.last_review
      #   desc.reviewer_id   = src.reviewer_id
      #   desc.ok_for_export = src.ok_for_export
      # end

      # This can really gum up the works and it's really hard to figure out
      # what the problem is when it occurs, since the error message is cryptic.
      if dest.is_a?(Name) && !desc.classification.blank?
        begin
          Name.validate_classification(dest.rank, desc.classification)
        rescue => e
          flash_error(:runtime_description_move_invalid_classification.t)
          flash_error(e.to_s)
          desc.classification = ''
        end
      end

      # Okay, *now* we can try to save the new description...
      if !desc.save
        flash_object_errors(desc)
      else
        Transaction.send("post_#{src.type_tag}", {
          :id          => desc,
          :parent      => desc,
          :source_type => desc.source_type,
          :source_name => desc.source_name,
          :project     => desc.project,
          :locale      => desc.locale,
          :public      => desc.public,
          :license     => desc.license,
        }.merge(desc.all_notes))
        dest.log(:log_description_created, :user => @user.login,
                 :name => desc.unique_partial_format_name, :touch => true)
        flash_notice(:runtime_description_copy_success.
                     t(:old => src_title, :new => desc.format_name))
        redirect_to(:action => desc.show_action, :id => desc.id,
                    :params => query_params)
      end
    end
  end

  # Publish a draft description.  If the name has no description, just turn
  # the draft into a public description and make it the default.  If the name
  # has a default description try to merge the draft into it.  If there is a
  # conflict bring up the edit_description form to let the user do the merge.
  def publish_description # :norobots:
    pass_query_params
    if draft = find_description(params[:id])
      parent = draft.parent
      old = parent.description
      type = parent.type_tag
      old_partial   = old.unique_partial_format_name if old
      draft_partial = draft.unique_partial_format_name

      # Must be admin on the draft in order for this to work.  (Must be able
      # to delete the draft after publishing it.)
      if !draft.is_admin?(@user)
        flash_error(:runtime_edit_description_denied.t)
        redirect_to(:action => parent.show_action, :id => parent.id,
                    :params => query_params)

      # Can't merge it into itself!
      elsif old == draft
        flash_error(:runtime_description_already_default.t)
        redirect_to(:action => draft.show_action, :id => draft.id,
                    :params => query_params)

      # I've temporarily decided to always just turn it into a public desc.
      # User can then merge by hand if public desc already exists.
      else
        draft.source_type = :public
        draft.source_name = ''
        draft.project     = nil
        draft.admin_groups.clear
        draft.admin_groups << UserGroup.reviewers
        draft.writer_groups.clear
        draft.writer_groups << UserGroup.all_users
        draft.reader_groups.clear
        draft.reader_groups << UserGroup.all_users
        draft.save
        parent.log(:log_published_description, :user => @user.login,
                   :name => draft.unique_partial_format_name, :touch => true)
        parent.description = draft
        parent.save
        Transaction.send("put_#{type}_description",
          :id              => draft,
          :set_source_type => draft.source_type,
          :set_source_name => draft.source_name,
          :set_project     => draft.project,
          :set_admins      => draft.admin_groups,
          :set_writers     => draft.writer_groups,
          :set_readers     => draft.reader_groups
        )
        redirect_to(:action => parent.show_action, :id => parent.id,
                    :params => query_params)
      end
    end
  end

  # Adjust permissions on a description.
  def adjust_permissions # :norobots:
    pass_query_params
    if @description = find_description(params[:id])
      done = false

      # Doesn't have permission.
      if !@description.is_admin?(@user) and !is_in_admin_mode?
        flash_error(:runtime_description_adjust_permissions_denied.t)
        done = true

      # These types have fixed permissions.
      elsif [:public, :foreign].include?(@description.source_type) and
            !is_in_admin_mode?
        flash_error(:runtime_description_permissions_fixed.t)
        done = true

      # GET method.
      elsif request.method != :post
        @data = nil

      # POST method.
      else
        old_readers = @description.reader_groups.sort_by(&:id)
        old_writers = @description.writer_groups.sort_by(&:id)
        old_admins  = @description.admin_groups.sort_by(&:id)

        # Update permissions on list of users and groups at the top.
        update_groups(@description, :readers, params[:group_reader])
        update_groups(@description, :writers, params[:group_writer])
        update_groups(@description, :admins,  params[:group_admin])

        # Look up write-ins and adjust their permissions.
        @data = [nil]
        done = true
        for n in params[:writein_name].keys.sort
          name   = params[:writein_name][n].to_s     rescue ''
          reader = params[:writein_reader][n] == '1' rescue false
          writer = params[:writein_writer][n] == '1' rescue false
          admin  = params[:writein_admin][n]  == '1' rescue false
          if !name.blank? and
             !update_writein(@description, name, reader, writer, admin)
            @data << { :name => name, :reader => reader, :writer => writer,
                       :admin => admin }
            flash_error(:runtime_description_user_not_found.t(:name => name))
            done = false
          end
        end

        # Were any changes made?
        new_readers = @description.reader_groups.sort_by(&:id)
        new_writers = @description.writer_groups.sort_by(&:id)
        new_admins  = @description.admin_groups.sort_by(&:id)
        if (old_readers != new_readers) or
           (old_writers != new_writers) or
           (old_admins  != new_admins)

          # Give feedback to assure user that their changes were made.
          flash_description_changes(old_readers, new_readers, :reader)
          flash_description_changes(old_writers, new_writers, :writer)
          flash_description_changes(old_admins,  new_admins,  :admin)

          # Keep the "public" flag updated.
          public = @description.reader_groups.include?(UserGroup.all_users)
          if @description.public != public
            @description.public = public
            @description.save
          end

          # Log change with Transaction.
          Transaction.send("put_#{@description.type_tag}",
            :id          => @description,
            :set_readers => @description.reader_groups,
            :set_writers => @description.writer_groups,
            :set_admins  => @description.admin_groups
          )

          @description.parent.log(:log_changed_permissions,
                              :user => @user.login, :touch => false,
                              :name => @description.unique_partial_format_name)
        else
          flash_notice(:runtime_description_adjust_permissions_no_changes.t)
        end
      end

      if done
        redirect_to(:action => @description.show_action,
                    :id => @description.id, :params => query_params)

      # Gather list of all the groups, authors, editors and owner.
      # If the user wants more they can write them in.
      else
        @groups = (
          [UserGroup.all_users] +
          @description.admin_groups.sort_by(&:name) +
          @description.writer_groups.sort_by(&:name) +
          @description.reader_groups.sort_by(&:name) +
          [UserGroup.reviewers]
        ) + (
          [@description.user] +
          @description.authors.sort_by(&:login) +
          @description.editors.sort_by(&:login) +
          [@user]
        ).map {|user| UserGroup.one_user(user)}
        @groups.uniq!
        @groups = @groups.reject {|g| g.name.match(/^user \d+$/)} +
                  @groups.select {|g| g.name.match(/^user \d+$/)}
      end
    end
  end

  ################################################################################
  #
  #  :section Helpers
  #
  ################################################################################

  # Look up a name or location description by id, using the controller name
  # to decide which kind.
  def find_description(id)
    if self.class.name == 'NameController'
      find_or_goto_index(NameDescription, id)
    else
      find_or_goto_index(LocationDescription, id)
    end
  end

  # Tentatively merge the fields by sticking src's notes after dest's wherever
  # there is a conflict.  Give user a chance to merge them by hand.
  def merge_description_notes(src, dest)
    src_notes  = src.all_notes
    dest_notes = dest.all_notes
    for f in src_notes.keys
      if dest_notes[f].blank?
        dest_notes[f] = src_notes[f]
      elsif !src_notes[f].blank?
        dest_notes[f] += "\n\n--------------------------------------\n\n"
        dest_notes[f] += src_notes[f].to_s
      end
    end
    dest.all_notes = dest_notes
  end

  # Initialize source info before serving creation form.
  def initialize_description_source(desc)
    desc.license = @user.license

    # Creating a draft.
    if !params[:project].blank?
      project = Project.find(params[:project])
      if @user.in_group?(project.user_group)
        desc.source_type  = :project
        desc.source_name  = project.title
        desc.project      = project
        desc.public       = false
        desc.public_write = false
      else
        flash_error(:runtime_create_draft_create_denied.
                      t(:title => project.title))
        redirect_to(:controller => 'project', :action => 'show_project',
                    :id => project.id)
      end

    # Cloning an existing description.
    elsif !params[:clone].blank?
      clone = find_description(params[:clone])
      if clone.is_reader?(@user)
        desc.all_notes = clone.all_notes
        desc.source_type  = :user
        desc.source_name  = ''
        desc.project_id   = nil
        desc.public       = false
        desc.public_write = false
      else
        flash_error(:runtime_description_private.t)
        redirect_to(:action => 'show_name', :id => desc.parent_id)
      end

    # Otherwise default to :public description.
    else
      desc.source_type  = :public
      desc.source_name  = ''
      desc.project_id   = nil
      desc.public       = true
      desc.public_write = true
    end
  end

  # This is called right after a description is created.  It sets the admin,
  # read and write permissions for a new description.
  def initialize_description_permissions(desc)
    read  = desc.public
    write = (desc.public_write == '1')
    case desc.source_type

    # Creating standard "public" description.
    when :public
      flash_warning(:runtime_description_public_read_wrong.t)  if !read
      flash_warning(:runtime_description_public_write_wrong.t) if !write
      desc.reader_groups << UserGroup.all_users
      desc.writer_groups << UserGroup.all_users
      desc.admin_groups  << UserGroup.reviewers
      desc.public = true
      desc.save

    # Creating draft for project.
    when :project
      project = desc.project
      if read
        desc.reader_groups << UserGroup.all_users
      else
        desc.reader_groups << project.user_group
        desc.writer_groups << UserGroup.one_user(@user)
      end
      if write
        desc.writer_groups << UserGroup.all_users
      else
        desc.writer_groups << project.admin_group
        desc.writer_groups << UserGroup.one_user(@user)
      end
      desc.admin_groups << project.admin_group
      desc.admin_groups << UserGroup.one_user(@user)

    # Creating personal description, or entering one from a specific source.
    when :source, :user
      if read
        desc.reader_groups << UserGroup.all_users
      else
        desc.reader_groups << UserGroup.one_user(@user)
      end
      if write
        desc.writer_groups << UserGroup.all_users
      else
        desc.writer_groups << UserGroup.one_user(@user)
      end
      desc.admin_groups << UserGroup.one_user(@user)

    else
      raise :runtime_invalid_source_type.t(:value => desc.source_type.inspect)
    end
  end

  # Make sure user is allowed to make the changes they are trying to make.
  def check_description_edit_permission(desc, params)
    okay = true

    # Fail completely if they don't even have write permission.
    if !desc.is_writer?(@user)
      flash_error(:runtime_edit_description_denied.t)
      if desc.is_reader?(@user)
        redirect_to(:action => desc.show_action, :id => desc.id)
      else
        redirect_to(:action => desc.parent.show_action, :id => desc.parent_id)
      end
      okay = false
    end

    # Just ignore illegal changes otherwise.  Form should prevent these,
    # anyway, but user could try to get sneaky and make changes via URL.
    if params.is_a?(Hash)
      root = is_in_admin_mode?
      admin = desc.is_admin?(@user)
      author = desc.is_author?(@user)

      params.delete(:source_type) unless root
      params.delete(:source_name) unless root or ((admin || author) and
        (desc.source_type != :project && desc.source_type != :project))
      params.delete(:license_id) unless root or admin or author
    end

    return okay
  end

  # Modify permissions on an existing Description based on two over-simplified
  # "public readable" and "public writable" checkboxes.  Makes changes to the
  # UserGroup's and modifies the Transaction +args+ in place.
  # desc::      Description object, with +public+ and +public_write+ updated.
  # args::      Hash of args that will be used to create Transaction.
  def modify_description_permissions(desc, args)
    old_read = desc.public_was
    new_read = desc.public
    old_write = desc.public_write_was
    new_write = (desc.public_write == '1')

    # Ensure these special types don't change,
    case desc.source_type
    when :public
      flash_warning(:runtime_description_public_read_wrong.t)  if !new_read
      flash_warning(:runtime_description_public_write_wrong.t) if !new_write
      new_read  = true
      new_write = true
    when :foreign
      flash_warning(:runtime_description_foreign_read_wrong.t)  if !new_read
      flash_warning(:runtime_description_foreign_write_wrong.t) if new_write
      new_read  = true
      new_write = false
    end

    new_readers = []
    new_writers = []

    # "Public" means "all users" group.
    if !old_read && new_read
      new_readers << UserGroup.all_users
      desc.public = true
    end
    if !old_write && new_write
      new_writers << UserGroup.all_users
    end

    # "Not Public" means only the owner...
    if old_read && !new_read
      new_readers << UserGroup.one_user(desc.user)
    end
    if old_write && !new_write
      new_writers << UserGroup.one_user(desc.user)
    end

    # ...except in the case of projects.
    if (desc.source_type == :project) and
       (project = desc.project)
      if old_read && !new_read
        # Add project members to readers.
        new_readers << project.user_group
      end
      if old_write && !new_write
        # Add project admins to writers.
        new_writers << project.admin_group
      end
    end

    # Make changes official.
    if new_readers.any?
      args[:set_reader_groups] = desc.reader_groups = new_readers
    end
    if new_writers.any?
      args[:set_writer_groups] = desc.writer_groups = new_writers
    end
  end

  # Update the permissions for a write-in.
  def update_writein(desc, name, reader, writer, admin)
    result = true
    if name.match(/^(.*\S) +<.*>$/)
      group = User.find_by_login($1)
    else
      group = User.find_by_login(name) ||
              UserGroup.find_by_name(name)
    end
    if group.is_a?(User)
      group = UserGroup.one_user(group)
    end
    if group
      update_group(desc, :readers, group, reader)
      update_group(desc, :writers, group, writer)
      update_group(desc, :admins,  group, admin)
    else
      result = false
    end
    return result
  end

  # Update the permissions of a given type for the list of pre-filled-in
  # groups.
  def update_groups(desc, type, groups)
    for id, val in groups
      if group = UserGroup.safe_find(id)
        update_group(desc, type, group, (val == '1'))
      else
        flash_error(:runtime_description_user_not_found.t(:name => id))
      end
    end
  end

  # Update one group's permissions of a given type.
  def update_group(desc, type, group, value)
    method = type.to_s.sub(/s$/, '_groups')
    old_value = desc.send(method).include?(group)
    if old_value && !value
      desc.send(method).delete(group)
    elsif !old_value && value
      desc.send(method).push(group)
    end
  end

  # Throw up some flash notices to reassure user that we did in fact make the
  # changes they wanted us to make.
  def flash_description_changes(old_groups, new_groups, type)
    for group in new_groups - old_groups
      name = group_name(group)
      flash_notice(:"runtime_description_added_#{type}".t(:name => name))
    end
    for group in old_groups - new_groups
      name = group_name(group)
      flash_notice(:"runtime_description_removed_#{type}".t(:name => name))
    end
  end

  # Return name of group or user if it's a one-user group.
  def group_name(group)
    if group.name == 'all users'
      :adjust_permissions_all_users.t
    elsif group.name == 'reviewers'
      :REVIEWERS.t
    elsif group.name.match(/^user \d+$/)
      group.users.first.legal_name
    else
      group.name
    end
  end

  # Attempt to merge one description into another, deleting the old one
  # if requested.  It will only do so if there is no conflict on any of the
  # description fields, i.e. one or the other is blank for any given field.
  def perform_merge(src, dest, delete_after)
    src_notes  = src.all_notes
    dest_notes = dest.all_notes
    result = false

    # Mergeable if there are no fields which are non-blank in both descriptions.
    if src.class.all_note_fields.none? \
         {|f| !src_notes[f].blank? and !dest_notes[f].blank?}
      result = true

      # Copy over all non-blank descriptive fields.
      xargs = {}
      for f, val in src_notes
        if !val.blank?
          dest.send("#{f}=", val)
          xargs[:"set_#{f}"] = val
        end
      end

      # Store where merge came from in new version of destination.
      dest.merge_source_id = src.versions.latest.id rescue nil
      xargs[:set_merge_source] = src

      # Save changes to destination.
      dest.save
      Transaction.send("put_#{dest.type_tag}", xargs)

      # Copy over authors and editors.
      src.authors.each {|user| dest.add_author(user)}
      src.editors.each {|user| dest.add_editor(user)}

      # Delete old description if requested.
      if delete_after
        if !src.is_admin?(@user)
          flash_warning(:runtime_description_merge_delete_denied.t)
        else
          src_was_default = (src.parent.description_id == src.id)
          Transaction.send("delete_#{src.type_tag}", :id => src)
          flash_notice(:runtime_description_merge_deleted.
                         t(:old => src.unique_partial_format_name))
          src.destroy

          # Make destination the default if source used to be the default.
          if src_was_default && dest.public
            dest.parent.description = dest
            dest.parent.save
          end
        end
      end

    end
    return result
  end
end

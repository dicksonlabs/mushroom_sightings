#
#  = Project Controller
#
#  == Actions
#   L = login required
#   A = admin required
#   V = has view
#   P = prefetching allowed
#
#  ==== Index
#  list_projects::
#  project_search::
#  index_project::
#  show_selected_projects::  (helper)
#
#  ==== Show, Create, Edit
#  show_project::
#  next_project::
#  prev_project::
#  add_project::
#  edit_project::
#  destroy_project::
#
#  ==== Manage
#  admin_request::
#  add_members::
#  change_member_status::
#  set_status::              (helper)
#
################################################################################

class ProjectController < ApplicationController

  before_filter :login_required, :except => [
    :index_project,
    :list_projects,
    :next_project,
    :prev_project,
    :project_search,
    :show_project,
  ]

  before_filter :disable_link_prefetching, :except => [
    :admin_request,
    :edit_project,
    :show_project,
  ]

  ##############################################################################
  #
  #  :section: Index
  #
  ##############################################################################

  # Show list of selected projects, based on current Query.
  def index_project # :nologin: :norobots:
    query = find_or_create_query(:Project, :by => params[:by])
    show_selected_projects(query, :id => params[:id], :always_index => true)
  end

  # Show list of latest projects.  (Linked from left panel.)
  def list_projects # :nologin:
    query = create_query(:Project, :all, :by => :title)
    show_selected_projects(query)
  end

  # Display list of Project's whose title or notes match a string pattern.
  def project_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) and
       (project = Project.safe_find(pattern))
      redirect_to(:action => 'show_project', :id => project.id)
    else
      query = create_query(:Project, :pattern_search, :pattern => pattern)
      show_selected_projects(query)
    end
  end

  # Show selected list of projects.
  def show_selected_projects(query, args={})
    args = {
      :action => :list_projects,
      :letters => 'projects.title',
      :num_per_page => 10,
    }.merge(args)

    @links ||= []

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name',     :sort_by_title.t],
      ['created',  :sort_by_created.t],
      ['modified', :sort_by_modified.t],
    ]

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show, Create, Edit
  #
  ##############################################################################

  # Display project by itself.
  # Linked from: show_observation, list_projects
  # Inputs: params[:id] (project)
  # Outputs: @project
  def show_project # :nologin: :prefetch:
    store_location
    pass_query_params
    if @project = find_or_goto_index(Project, params[:id])
      @is_member = @project.is_member?(@user)
      @is_admin = @project.is_admin?(@user)

      @draft_data = Project.connection.select_all %(
        SELECT n.display_name, nd.id, nd.user_id
        FROM names n, name_descriptions nd, name_descriptions_admins nda
        WHERE nda.user_group_id = #{@project.admin_group_id}
          AND nd.id = nda.name_description_id
          AND n.id = nd.name_id
        ORDER BY n.text_name ASC, n.author ASC
      )

      @name_data = @draft_data.map {|d| d['display_name']}.uniq.length
    end
  end

  # Go to next project: redirects to show_project.
  def next_project # :nologin: :norobots:
    redirect_to_next_object(:next, Project, params[:id])
  end

  # Go to previous project: redirects to show_project.
  def prev_project # :nologin: :norobots:
    redirect_to_next_object(:prev, Project, params[:id])
  end

  # Form to create a project.
  # Linked from: list_projects
  # Inputs:
  #   params[:id] (project id)
  #   params[:project][:title]
  #   params[:project][:summary]
  # Success:
  #   Redirects to show_project.
  # Failure:
  #   Renders add_project again.
  #   Outputs: @project
  def add_project # :norobots:
    pass_query_params
    if request.method == :get
      @project = Project.new
    else
      title = params[:project][:title].to_s
      project = Project.find_by_title(title)
      user_group = UserGroup.find_by_name(title)
      admin_name = "#{title}.admin"
      admin_group = UserGroup.find_by_name(admin_name)
      if title.blank?
        flash_error(:add_project_need_title.t)
      elsif project
        flash_error(:add_project_already_exists.t(:title => project.title))
      elsif user_group
        flash_error(:add_project_group_exists.t(:group => title))
      elsif admin_group
        flash_error(:add_project_group_exists.t(:group => admin_name))
      else
        # Create members group.
        user_group = UserGroup.new
        user_group.name = title
        user_group.users << @user

        # Create admin group.
        admin_group = UserGroup.new
        admin_group.name = admin_name
        admin_group.users << @user

        # Create project.
        @project = Project.new(params[:project])
        # @project.created = Time.now
        @project.user = @user
        @project.user_group = user_group
        @project.admin_group = admin_group

        if !user_group.save
          flash_object_errors(user_group)
        elsif !admin_group.save
          flash_object_errors(admin_group)
        elsif !@project.save
          flash_object_errors(@project)
        else
          Transaction.post_user_group(
            :id   => admin_group,
            :name => admin_name
          )
          Transaction.post_user_group(
            :id   => user_group,
            :name => title
          )
          Transaction.post_project(
            :id          => @project,
            :title       => @project.title,
            :summary     => @project.summary,
            :admin_group => admin_group,
            :user_group  => user_group
          )
          @project.log_create
          flash_notice(:add_project_success.t)
          redirect_to(:action => :show_project, :id => @project.id,
                      :params => query_params)
        end
      end
    end
  end

  # Form to edit a project
  # Linked from: show_project
  # Inputs:
  #   params[:id]
  #   params[:project][:title]
  #   params[:project][:summary]
  # Success:
  #   Redirects to show_project.
  # Failure:
  #   Renders edit_project again.
  #   Outputs: @project
  def edit_project # :prefetch: :norobots:
    pass_query_params
    @project = Project.find(params[:id])
    if !check_permission!(@project.user_id)
      redirect_to(:action => 'show_project', :id => @project.id,
                  :params => query_params)
    elsif request.method == :post
      @title = params[:project][:title].to_s
      @summary = params[:project][:summary]
      xargs = {}
      xargs[:set_title]   = @title   if @project_title   != @title
      xargs[:set_summary] = @summary if @project_summary != @summary
      if @title.blank?
        flash_error(:add_project_need_title.t)
      elsif Project.find_by_title(@title) != @project
        flash_error(:add_project_already_exists.t(:title => @title))
      elsif !@project.update_attributes(params[:project])
        flash_object_errors(@project)
      else
        if !xargs.empty?
          xargs[:id] = @project
          Transaction.put_project(xargs)
        end
        @project.log_update
        flash_notice(:runtime_edit_project_success.t(:id => @project.id))
        redirect_to(:action => 'show_project', :id => @project.id,
                    :params => query_params)
      end
    end
  end

  # Callback to destroy a project.
  # Linked from: show_project, show_observation
  # Redirects to show_observation.
  # Inputs: params[:id]
  # Outputs: none
  def destroy_project # :norobots:
    pass_query_params
    @project = Project.find(params[:id])
    if !check_permission!(@project.user_id)
      redirect_to(:action => 'show_project', :id => @project.id,
                  :params => query_params)
    elsif !@project.destroy
      flash_error(:destroy_project_failed.t)
      redirect_to(:action => 'show_project', :id => @project.id,
                  :params => query_params)
    else
      @project.log_destroy
      Transaction.delete_project(:id => @project)
      flash_notice(:destroy_project_success.t)
      redirect_to(:action => :index_project, :params => query_params)
    end
  end

  ##############################################################################
  #
  #  :section: Manage
  #
  ##############################################################################

  # Form to compose email for the admins
  # Linked from: show_project
  # Inputs:
  #   params[:id]
  # Outputs:
  #   @project
  # Posts to the same action.  Redirects back to show_project.
  def admin_request # :prefetch: :norobots:
    sender = @user
    pass_query_params
    @project = Project.find(params[:id])
    if request.method == :post
      subject = params[:email][:subject]
      content = params[:email][:content]
      for receiver in @project.admin_group.users
        AccountMailer.deliver_admin_request(sender, receiver, @project,
                                            subject, content)
      end
      flash_notice(:admin_request_success.t(:title => @project.title))
      redirect_to(:action => 'show_project', :id => @project.id,
                  :params => query_params)
    end
  end

  # View that lists all users with links to add each as a member.
  # Linked from: show_project (for admins only)
  # Inputs:
  #   params[:id]
  #   params[:candidate]  (when click on user)
  # Outputs:
  #   @project, @users
  # "Posts" to the same action.  Stays on this view until done.
  def add_members # :norobots:
    pass_query_params
    @project = Project.find(params[:id])
    @users = User.all(:order => "login, name")
    if !@project.is_admin?(@user)
      redirect_to(:action => 'show_project', :id => @project.id,
                  :params => query_params)
    elsif !params[:candidate].blank?
      @candidate = User.find(params[:candidate])
      set_status(@project, :member, @candidate, :add)
    end
  end

  # Form to make a given User either a member or an admin.
  # Linked from: show_project, add_users, admin_request email
  # Inputs:
  #   params[:id]
  #   params[:candidate]
  #   params[:commit]
  # Outputs: @project, @candidate
  # Posts to same action.  Redirects to show_project when done.
  def change_member_status # :norobots:
    pass_query_params
    @project = Project.find(params[:id])
    @candidate = User.find(params[:candidate])
    if !@project.is_admin?(@user)
      flash_error(:change_member_status_denied.t)
      redirect_to(:action => 'show_project', :id => @project.id,
                  :params => query_params)
    elsif request.method == :post
      user_group = @project.user_group
      admin_group = @project.admin_group
      admin = member = :remove
      case params[:commit]
      when :change_member_status_make_admin.l
        admin = member = :add
      when :change_member_status_make_member.l
        member = :add
      end
      set_status(@project, :admin, @candidate, admin)
      set_status(@project, :member, @candidate, member)
      redirect_to(:action => 'show_project', :id => @project.id,
                  :params => query_params)
    end
  end

  # Add/remove a given User to/from a given UserGroup.
  # TODO: Changes should get logged
  def set_status(project, type, user, mode)
    group = project.send(type == :member ? :user_group : :admin_group)
    if mode == :add
      if !group.users.include?(user)
        group.users << user unless group.users.member?(user)
        Transaction.put_project(:id => project, :"add_#{type}" => user)
        project.send("log_add_#{type}", user)
      end
    else
      if group.users.include?(user)
        group.users.delete(user)
        Transaction.put_project(:id => project, :"del_#{type}" => user)
        project.send("log_remove_#{type}", user)
      end
    end
  end
end

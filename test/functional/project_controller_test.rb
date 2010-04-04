require File.dirname(__FILE__) + '/../boot'

class ProjectControllerTest < FunctionalTestCase

  def add_project_helper(title, summary)
    params = {
      :project => {
        :title => title,
        :summary => summary
      }
    }
    post_requires_login(:add_project, params)
    assert_form_action(:action => 'add_project') # Failure
  end

  def edit_project_helper(title, project)
    params = {
      :id => project.id,
      :project => {
        :title => title,
        :summary => project.summary
      }
    }
    post_requires_user(:edit_project, :show_project, params)
    assert_form_action(:action => 'edit_project') # Failure
  end

  def destroy_project_helper(project, changer)
    assert(project)
    drafts = NameDescription.find_all_by_source_name(project.title)
    assert(drafts.length > 0)
    params = { :id => project.id.to_s }
    requires_user(:destroy_project, :show_project, params, changer.login)
    assert_response(:action => :show_project)
    assert(Project.find(project.id))
    assert(UserGroup.find(project.user_group.id))
    assert(UserGroup.find(project.admin_group.id))
    assert_obj_list_equal(drafts, NameDescription.find_all_by_source_name(project.title))
  end

  def change_member_status_helper(changer, target_user, commit, admin_before, user_before, admin_after, user_after)
    eol_project = projects(:eol_project)
    assert_equal(admin_before, target_user.in_group?(eol_project.admin_group.name))
    assert_equal(user_before, target_user.in_group?(eol_project.user_group.name))
    params = {
      :id => eol_project.id,
      :candidate => target_user.id,
      :commit => commit.l
    }
    post_requires_login(:change_member_status, params, changer.login)
    assert_response(:action => 'show_project', :id => eol_project.id)
    target_user = User.find(target_user.id)
    assert_equal(admin_after, target_user.in_group?(eol_project.admin_group.name))
    assert_equal(user_after, target_user.in_group?(eol_project.user_group.name))
  end

################################################################################

  def test_add_project_existing
    add_project_helper(projects(:eol_project).title, "The Entoloma On Line Project")
  end

  def test_show_project
    get_with_dump(:show_project, :id => 1)
    assert_response('show_project')
  end

  def test_list_projects
    get_with_dump(:list_projects)
    assert_response('list_projects')
  end

  def test_add_project
    requires_login(:add_project)
    assert_form_action(:action => 'add_project')
  end

  def test_add_project_post
    title = "Amanita Research"
    summary = "The Amanita Research Project"
    project = Project.find_by_title(title)
    assert_nil(project)
    user_group = UserGroup.find_by_name(title)
    assert_nil(user_group)
    admin_group = UserGroup.find_by_name("#{title}.admin")
    assert_nil(admin_group)
    params = {
      :project => {
        :title => title,
        :summary => summary
      }
    }
    post_requires_login(:add_project, params)
    assert_response(:action => :show_project)
    project = Project.find_by_title(title)
    assert(project)
    assert_equal(title, project.title)
    assert_equal(summary, project.summary)
    assert_equal(@rolf, project.user)
    user_group = UserGroup.find_by_name(title)
    assert(user_group)
    assert_equal([@rolf], user_group.users)
    admin_group = UserGroup.find_by_name("#{title}.admin")
    assert(admin_group)
    assert_equal([@rolf], admin_group.users)
  end

  def test_add_project_empty_name
    add_project_helper('', "The Empty Project")
  end

  def test_add_project_existing_user_group
    add_project_helper('reviewers', "Journal Reviewers")
  end

  def test_edit_project
    project = projects(:eol_project)
    params = { "id" => project.id.to_s }
    requires_user(:edit_project, :show_project, params)
    assert_form_action(:action => 'edit_project')
  end

  def test_edit_project_post
    title = "EOL Project"
    summary = "This has become the Entoloma On Line project"
    project = Project.find_by_title(title)
    assert(project)
    assert_not_equal(summary, project.summary)
    params = {
      :id => project.id,
      :project => {
        :title => title,
        :summary => summary
      }
    }
    post_requires_user(:edit_project, :show_project, params)
    assert_response(:action => :show_project)
    project = Project.find_by_title(title)
    assert(project)
    assert_equal(summary, project.summary)
  end

  def test_edit_project_empty_name
    edit_project_helper('', projects(:eol_project))
  end

  def test_edit_project_existing
    edit_project_helper(projects(:bolete_project).title, projects(:eol_project))
  end

  def test_destroy_project
    project = projects(:bolete_project)
    assert(project)
    user_group = project.user_group
    assert(user_group)
    admin_group = project.admin_group
    assert(admin_group)
    drafts = NameDescription.find_all_by_source_name(project.title)
    project_draft_count = drafts.length
    assert(project_draft_count > 0)
    params = { :id => project.id.to_s }
    requires_user(:destroy_project, :show_project, params, 'dick')
    assert_response(:action => :index_project)
    assert_raises(ActiveRecord::RecordNotFound) do
      project = Project.find(project.id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      user_group = UserGroup.find(user_group.id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      admin_group = UserGroup.find(admin_group.id)
    end
    Name.connection.select_value %(
      SELECT COUNT(*) FROM name_descriptions_admins
      WHERE user_group_id IN (#{admin_group.id}, #{user_group.id})
    )
    Name.connection.select_value %(
      SELECT COUNT(*) FROM name_descriptions_writers
      WHERE user_group_id IN (#{admin_group.id}, #{user_group.id})
    )
    Name.connection.select_value %(
      SELECT COUNT(*) FROM name_descriptions_readers
      WHERE user_group_id IN (#{admin_group.id}, #{user_group.id})
    )
    for draft in drafts
      assert_not_equal(:project, draft.reload.source_type)
    end
  end

  def test_destroy_project_other
    destroy_project_helper(projects(:bolete_project), @rolf)
  end

  def test_destroy_project_member
    eol_project = projects(:eol_project)
    assert(eol_project.is_member?(@katrina))
    destroy_project_helper(eol_project, @katrina)
  end

  def test_post_admin_request
    eol_project = projects(:eol_project)
    params = {
      :id => eol_project.id,
      :email => {
        :subject => "Admin request subject",
        :message => "Message for admins"
      }
    }
    post_requires_login(:admin_request, params)
    assert_response(:action => "show_project", :id => eol_project.id)
    assert_flash(:admin_request_success.t(:title => eol_project.title))
  end

  def test_admin_request
    id = projects(:eol_project).id
    requires_login(:admin_request, :id => id)
    assert_form_action(:action => 'admin_request', :id => id)
  end

  def test_change_member_status
    project = projects(:eol_project)
    params = {
      :id => project.id,
      :candidate => @mary.id
    }
    requires_login(:change_member_status, params)
    assert_form_action(:action => 'change_member_status', :candidate => @mary.id)
  end

  # non-admin member -> non-admin member (should be a no-op)
  def test_change_member_status_member_make_member
    change_member_status_helper(@rolf, @katrina, :change_member_status_make_member, false, true, false, true)
  end

  # non-admin member -> admin member
  def test_change_member_status_member_make_admin
    change_member_status_helper(@mary, @katrina, :change_member_status_make_admin, false, true, true, true)
  end

  # non-admin member -> non-member
  def test_change_member_status_member_remove_member
    change_member_status_helper(@rolf, @katrina, :change_member_status_remove_member, false, true, false, false)
  end

  # admin member -> non-admin member
  def test_change_member_status_admin_make_member
    change_member_status_helper(@mary, @mary, :change_member_status_make_member, true, true, false, true)
  end

  # admin member -> admin member (should be a no-op)
  def test_change_member_status_admin_make_admin
    change_member_status_helper(@rolf, @mary, :change_member_status_make_admin, true, true, true, true)
  end

  # admin member -> non-member
  def test_change_member_status_admin_remove_member
    change_member_status_helper(@mary, @mary, :change_member_status_remove_member, true, true, false, false)
  end

  # non-member -> non-admin member
  def test_change_member_status_non_member_make_member
    change_member_status_helper(@rolf, @dick, :change_member_status_make_member, false, false, false, true)
  end

  # non-member -> admin member
  def test_change_member_status_non_member_make_admin
    change_member_status_helper(@mary, @dick, :change_member_status_make_admin, false, false, true, true)
  end

  # non-member -> non-member (should be a no-op)
  def test_change_member_status_non_member_remove_member
    change_member_status_helper(@rolf, @dick, :change_member_status_remove_member, false, false, false, false)
  end

  # The following should all be no-ops
  def test_change_member_status_by_member_make_member
    change_member_status_helper(@katrina, @dick, :change_member_status_make_member, false, false, false, false)
  end

  def test_change_member_status_by_non_member_make_admin
    change_member_status_helper(@dick, @katrina, :change_member_status_make_admin, false, true, false, true)
  end

  def test_change_member_status_by_member_remove_member
    change_member_status_helper(@katrina, @katrina, :change_member_status_remove_member, false, true, false, true)
  end

  # There are many other combinations that shouldn't work for change_member_status, but I think the above
  # covers the key cases

  # Make sure admin can see form.
  def test_add_members
    requires_login(:add_members, :id => projects(:eol_project).id)
  end

  # Make sure non-admin cannot see form.
  def test_add_members_non_admin
    project_id = projects(:eol_project).id
    requires_login(:add_members, { :id => project_id }, @katrina.login)
    assert_response(:action => 'show_project', :id => project_id)
  end

  # Make sure admin can add members.
  def test_add_member_admin
    eol_project = projects(:eol_project)
    target_user = @dick
    assert_equal(false, target_user.in_group?(eol_project.admin_group.name))
    assert_equal(false, target_user.in_group?(eol_project.user_group.name))
    params = {
      :id => eol_project.id,
      :candidate => target_user.id
    }
    requires_login(:add_members, params, @mary.login)
    assert_response(:success)
    target_user = User.find(target_user.id)
    assert_equal(false, target_user.in_group?(eol_project.admin_group.name))
    assert_equal(true, target_user.in_group?(eol_project.user_group.name))
  end

  # Make sure mere member cannot add members.
  def test_add_member_member
    eol_project = projects(:eol_project)
    target_user = @dick
    assert_equal(false, target_user.in_group?(eol_project.admin_group.name))
    assert_equal(false, target_user.in_group?(eol_project.user_group.name))
    params = {
      :id => eol_project.id,
      :candidate => target_user.id
    }
    requires_login(:add_members, params, @katrina.login)
    assert_response(:action => :show_project, :id => eol_project.id)
    target_user = User.find(target_user.id)
    assert_equal(false, target_user.in_group?(eol_project.admin_group.name))
    assert_equal(false, target_user.in_group?(eol_project.user_group.name))
  end
end

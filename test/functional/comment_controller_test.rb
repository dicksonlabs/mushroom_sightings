# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

class CommentControllerTest < FunctionalTestCase

  def test_list_comments
    get_with_dump(:list_comments)
    assert_response('list_comments')
  end

  def test_show_comment
    get_with_dump(:show_comment, :id => 1)
    assert_response('show_comment')
  end

  def test_show_comments_for_user
    get_with_dump(:show_comments_for_user, :id => 1)
    assert_response('list_comments')
  end

  def test_show_comments_by_user
    get_with_dump(:show_comments_by_user, :id => @rolf.id)
    assert_response(:action => 'show_comment', :id => 1,
                    :params => @controller.query_params(Query.last))
  end

  def test_add_comment
    requires_login(:add_comment, :id => 1, :type => 'Observation')
    assert_form_action(:action => 'add_comment', :id => 1, :type => 'Observation')
  end

  def test_edit_comment
    comment = comments(:minimal_comment)
    params = { "id" => comment.id.to_s }
    assert_equal("rolf", comment.user.login)
    requires_user(:edit_comment, ['observer', 'show_observation'], params)
    assert_form_action(:action => 'edit_comment')
  end

  def test_destroy_comment
    comment = comments(:minimal_comment)
    obs = comment.target
    assert(obs.comments.member?(comment))
    assert_equal("rolf", comment.user.login)
    params = {"id" => comment.id.to_s}
    requires_user(:destroy_comment, ['observer', 'show_observation'], params)
    assert_response(:controller => :observer, :action => :show_observation)
    assert_equal(9, @rolf.reload.contribution)
    obs.reload
    assert(!obs.comments.member?(comment))
  end

  def test_save_comment
    assert_equal(10, @rolf.contribution)
    obs = observations(:minimal_unknown)
    comment_count = obs.comments.size
    params = {
      :id => obs.id,
      :type => 'Observation',
      :comment => {
        :summary => "A Summary",
        :comment => "Some text."
      }
    }
    post_requires_login(:add_comment, params)
    assert_response(:controller => :observer, :action => :show_observation)
    assert_equal(11, @rolf.reload.contribution)
    obs.reload
    assert_equal(comment_count + 1, obs.comments.size)
    comment = Comment.last
    assert_equal("A Summary", comment.summary)
    assert_equal("Some text.", comment.comment)
  end

  def test_update_comment
    comment = comments(:minimal_comment)
    params = {
      :id => comment.id,
      :comment => {
        :summary => "New Summary",
        :comment => "New text."
      }
    }
    assert("rolf" == comment.user.login)
    post_requires_user(:edit_comment, ['observer', 'show_observation'], params)
    assert_equal(10, @rolf.reload.contribution)
    comment = Comment.find(comment.id)
    assert_equal("New Summary", comment.summary)
    assert_equal("New text.",   comment.comment)
  end
end

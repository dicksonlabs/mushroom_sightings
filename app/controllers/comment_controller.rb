# encoding: utf-8
#
#  = Comment Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  ==== Searches and Indexes
#  list_comments::
#  show_comments_by_user::
#  show_comments_for_target::
#  show_comments_for_user::
#  comment_search::
#  index_comment::
#  show_selected_comments::
#
#  ==== Show, Create and Edit
#  show_comment::
#  next_comment::
#  prev_comment::
#  add_comment::
#  edit_comment::
#  destroy_comment::
#  allowed_to_see!::
#
################################################################################

class CommentController < ApplicationController
  before_filter :login_required, :except => [
    :comment_search,
    :index_comment,
    :list_comments,
    :next_comment,
    :prev_comment,
    :show_comment,
    :show_comments_by_user,
    :show_comments_for_target,
    :show_comments_for_user,
  ]

  before_filter :disable_link_prefetching, :except => [
    :add_comment,
    :edit_comment,
    :show_comment,
  ]

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  # Show selected list of comments, based on current Query.  (Linked from
  # show_comment, next to "prev" and "next"... or will be.)
  def index_comment # :nologin: :norobots:
    query = find_or_create_query(:Comment, :by => params[:by])
    show_selected_comments(query, :id => params[:id], :always_index => true)
  end

  # Show list of latest comments. (Linked from left panel.)
  def list_comments # :nologin:
    query = create_query(:Comment, :all, :by => :created)
    show_selected_comments(query)
  end

  # Shows comments for a given user, most recent first.  (Linked from left
  # panel.)
  def show_comments_by_user # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id]) : @user
      query = create_query(:Comment, :by_user, :user => user)
      show_selected_comments(query)
    end
  end

  # Shows comments for a given user, most recent first.  (Linked from left
  # panel.)
  def show_comments_for_user # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id]) : @user
      query = create_query(:Comment, :for_user, :user => user)
      show_selected_comments(query)
    end
  end

  # Shows comments for a given object, most recent first.  (Linked from the
  # "and more..." thingy at the bottom of truncated embedded comment lists.)
  def show_comments_for_target # :nologin: :norobots:
    model = params[:type].to_s.constantize rescue nil
    if !model || !model.acts_like?(:model)
      flash_error(:runtime_invalid.t(:type => '"type"',
                                     :value => params[:type].to_s))
      redirect_back_or_default(:action => :list_comments)
    elsif target = find_or_goto_index(model, params[:id])
      query = create_query(:Comment, :for_target, :target => target.id,
                           :type => target.class.name)
      show_selected_comments(query)
    end
  end

  # Display list of Comment's whose text matches a string pattern.
  def comment_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) and
       (comment = Comment.safe_find(pattern))
      redirect_to(:action => 'show_comment', :id => comment.id)
    else
      query = create_query(:Comment, :pattern_search, :pattern => pattern)
      show_selected_comments(query)
    end
  end

  # Show selected list of comments.
  def show_selected_comments(query, args={})

    # (Eager-loading of names might fail when comments start to apply to
    # objects other than observations.)
    args = {
      :action => :list_comments,
      :num_per_page => 25,
      :include => [:target, :user],
    }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      # ['summary',  :sort_by_summary.t],
      ['user',     :sort_by_user.t],
      ['created',  :sort_by_posted.t],
      ['modified', :sort_by_modified.t],
    ]

    # Paginate by letter if sorting by user.
    if (query.params[:by] == 'user') or
       (query.params[:by] == 'reverse_user')
      args[:letters] = 'users.login'
    # Paginate by letter if sorting by summary.
    # elsif (query.params[:by] == 'summary') or
    #    (query.params[:by] == 'reverse_summary')
    #   args[:letters] = 'comments.summary'
    end

    @full_detail = (query.flavor == :for_target)

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show, Create and Edit
  #
  ##############################################################################

  # Display comment by itself.
  # Linked from: show_<object>, list_comments
  # Inputs: params[:id] (comment)
  # Outputs: @comment, @object
  def show_comment # :nologin: :prefetch:
    store_location
    pass_query_params
    if @comment = find_or_goto_index(Comment, params[:id],
                                     :include => [:target, :user])
      @target = @comment.target
      allowed_to_see!(@target)
    end
  end

  # Go to next comment: redirects to show_comment.
  def next_comment # :nologin: :norobots:
    redirect_to_next_object(:next, Comment, params[:id])
  end

  # Go to previous comment: redirects to show_comment.
  def prev_comment # :nologin: :norobots:
    redirect_to_next_object(:prev, Comment, params[:id])
  end

  # Form to create comment for an object.
  # Linked from: show_<object>
  # Inputs:
  #   params[:id] (object id)
  #   params[:type] (object type)
  #   params[:comment][:summary]
  #   params[:comment][:comment]
  # Success:
  #   Redirects to show_<object>.
  # Failure:
  #   Renders add_comment again.
  #   Outputs: @comment, @object
  def add_comment # :prefetch: :norobots:
    pass_query_params
    @target = Comment.find_object(params[:type], params[:id])
    if !allowed_to_see!(@target)
      # redirected already
    elsif request.method == :get
      @comment = Comment.new
      @comment.target = @target
    else
      @comment = Comment.new(params[:comment])
      @comment.target = @target
      if !@comment.save
        flash_object_errors(@comment)
      else
        type = @target.type_tag
        Transaction.post_comment(
          :id      => @comment,
          type     => @target,
          :summary => @comment.summary,
          :content => @comment.comment
        )
        @comment.log_create
        flash_notice(:runtime_form_comments_create_success.t(:id => @comment.id))
        redirect_to(:controller => @target.show_controller,
                    :action => @target.show_action, :id => @target.id,
                    :params => query_params)
      end
    end
  end

  # Form to edit a comment for an object..
  # Linked from: show_comment, show_object.
  # Inputs:
  #   params[:id]
  #   params[:comment][:summary]
  #   params[:comment][:comment]
  # Success:
  #   Redirects to show_object.
  # Failure:
  #   Renders edit_comment again.
  #   Outputs: @comment, @object
  def edit_comment # :prefetch: :norobots:
    pass_query_params
    @comment = Comment.find(params[:id])
    @target = @comment.target
    if !allowed_to_see!(@target)
      # redirected already
    elsif !check_permission!(@comment.user_id)
      redirect_to(:controller => @target.show_controller,
                  :action => @target.show_action, :id => @target.id,
                  :params => query_params)
    elsif request.method == :post
      @comment.attributes = params[:comment]
      xargs = {}
      xargs[:summary] = @comment.summary if @comment.summary_changed?
      xargs[:content] = @comment.comment if @comment.comment_changed?
      if xargs.empty?
        flash_notice(:runtime_no_changes.t)
        done = true
      elsif !@comment.save
        flash_object_errors(@comment)
      else
        xargs[:id] = @comment
        Transaction.put_comment(xargs)
        @comment.log_update
        flash_notice(:runtime_form_comments_edit_success.t(:id => @comment.id))
        done = true
      end
      if done
        redirect_to(:controller => @target.show_controller,
                    :action => @target.show_action, :id => @target.id,
                    :params => query_params)
      end
    end
  end

  # Callback to destroy a comment.
  # Linked from: show_comment, show_object.
  # Redirects to show_object.
  # Inputs: params[:id]
  # Outputs: none
  def destroy_comment # :norobots:
    pass_query_params
    @comment = Comment.find(params[:id])
    @target = @comment.target
    if !check_permission!(@comment.user_id)
      # all cases redirect to object show page
    elsif !@comment.destroy
      flash_error(:runtime_form_comments_destroy_failed.t(:id => params[:id]))
    else
      Transaction.delete_comment(:id => @comment)
      @comment.log_destroy
      flash_notice(:runtime_form_comments_destroy_success.t(:id => params[:id]))
    end
    redirect_to(:controller => @target.show_controller,
                :action => @target.show_action, :id => @target.id,
                :params => query_params)
  end

  # Make sure users can't see/add comments on objects they aren't allowed to
  # view!  Redirect and return +false+ if they can't, else return +true+.
  def allowed_to_see!(object)
    if object.respond_to?(:is_reader?) and
       !object.is_reader?(@user)
      flash_error(:runtime_show_description_denied.t)
      parent = object.parent
      redirect_to(:controller => parent.show_controller,
                  :action => parent.show_action, :id => parent.id)
      return false
    else
      return true
    end
  end
end

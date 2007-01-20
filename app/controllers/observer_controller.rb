# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

require 'find'
require 'ftools'

class Search
  attr_accessor :pattern
end

class ObserverController < ApplicationController
  before_filter :login_required, :except => (CSS + [:ask_webmaster_question,
                                                    :color_themes,
                                                    :images_by_title,
                                                    :index,
                                                    :intro,
                                                    :list_comments,
                                                    :list_images,
                                                    :list_observations,
                                                    :list_rss_logs,
                                                    :list_species_lists,
                                                    :name_index,
                                                    :news,
                                                    :next_image,
                                                    :next_observation,
                                                    :observations_by_name,
                                                    :observation_index,
                                                    :observation_search,
                                                    :prev_image,
                                                    :prev_observation,
                                                    :rss,
                                                    :send_webmaster_question,
                                                    :show_comment,
                                                    :show_image,
                                                    :show_name,
                                                    :show_observation,
                                                    :show_original,
                                                    :show_rss_log,
                                                    :show_species_list,
                                                    :species_lists_by_title])
  # Default page
  def index
    list_rss_logs
    render :action => 'list_rss_logs'
  end

  def login
    list_rss_logs
    render :action => 'list_rss_logs'
  end

  # left-hand panel -> list_comments.rhtml
  def list_comments
    @session['observation_ids'] = nil
    @session['observation'] = nil
    @session['image_ids'] = nil
    store_location
    @comment_pages, @comments = paginate(:comments,
                                     :order => "'created' desc",
                                     :per_page => 10)
  end

  def add_comment
    if verify_user(@session['user'])
      @comment = Comment.new
      @observation = Observation.find(params[:id])
    end
  end

  # show_observation.rhtml -> show_comment.rhtml
  def show_comment
    store_location
    @comment = Comment.find(params[:id])
  end

  # add_comment.rhtml -> save_comment -> add_comment.rhtml
  # Here's where params is used to create the comment and
  # the observation is recovered from session.
  def save_comment
    user = @session['user']
    if verify_user(user)
      @comment = Comment.new(params[:comment])
      @comment.created = Time.now
      @observation = @comment.observation
      # @comment.observation = @observation
      @comment.user = user
      if @comment.save
        @observation.log(sprintf('Comment, %s, added by %s', @comment.summary, user.login), true)
        flash[:notice] = 'Comment was successfully added.'
        redirect_to(:action => 'show_observation', :id => @observation)
      else
        flash[:notice] = sprintf('Unable to save comment: %s', @comment.summary)
        render :action => 'add_comment'
      end
    end
  end
  
  # show_comment.rhtml -> edit_comment.rhtml
  def edit_comment
    @comment = Comment.find(params[:id])
    unless check_user_id(@comment.user_id)
      render :action => 'show_comment'
    end
  end

  # edit_comment.rhtml -> update_comment -> show_comment.rhtml
  def update_comment
    @comment = Comment.find(params[:id])
    if check_user_id(@comment.user_id) # Even though edit makes this check, avoid bad guys going directly
      if @comment.update_attributes(params[:comment])
        if @comment.save
          @comment.observation.log(sprintf('Comment, %s, updated by %s',
                                           @comment.summary, @session['user'].login), true)
          flash[:notice] = 'Comment was successfully updated.'
        end
        redirect_to :action => 'show_comment', :id => @comment
      else
        render :action => 'edit_comment'
      end
    else
      render :action => 'show_comment'
    end
  end

  # show_comment.rhtml -> destroy -> show_observation.rhtml
  def destroy_comment
    @comment = Comment.find(params[:id])
    if check_user_id(@comment.user_id)
      id = @comment.observation_id
      @comment.observation.log(sprintf('Comment, %s, destroyed by %s',
                                       @comment.summary, @session['user'].login), false)
      @comment.destroy
      redirect_to :action => 'show_observation', :id => id
    else
      render :action => 'show_comment'
    end
  end

  # left-hand panel -> list_observations.rhtml
  def list_observations
    store_location
    @layout = calc_layout_params
    @session['observation_ids'] = self.query_ids("select id, `when` from observations order by `when` desc")
    @session['observation'] = nil
    @session['image_ids'] = nil
    @observation_pages, @observations = paginate(:observations,
                                                 :order => "`when` desc",
                                                 :per_page => @layout["count"])
  end

  # left-hand panel -> observations_by_name.rhtml
  def observations_by_name
    store_location
    @layout = calc_layout_params
    @session['observation_ids'] = self.query_ids("select o.id, n.search_name from observations o, names n where n.id = o.name_id order by text_name asc, `when` desc")
    @session['observation'] = nil
    @session['image_ids'] = nil
    @observation_pages, @observations = paginate(:observations, :include => "name",
                                                 :order => "names.search_name asc, `when` desc",
                                                 :per_page => @layout["count"])
    render :action => 'list_observations'
  end
  
  # left-hand panel -> observation_search.rhtml
  def observation_search
    store_location
    @layout = calc_layout_params
    search_data = params[:search]
    if search_data
      @session["pattern"] = search_data["pattern"]
    end
    pattern = @session["pattern"]
    if pattern.nil?
      pattern = ''
    end
    @search = Search.new
    @search.pattern = pattern
    conditions = sprintf("names.search_name like '%s%%'", pattern.gsub(/[*']/,"%"))
    query = sprintf("select o.id, names.search_name from observations o, names where %s order by names.search_name asc, `when` desc",
                    conditions)
    @session['observation_ids'] = self.query_ids(query)
    @session['observation'] = nil
    @session['image_ids'] = nil
    @observation_pages, @observations = paginate(:observations, :include => "name",
                                                 :order => "names.search_name asc, `when` desc",
                                                 :conditions => conditions,
                                                 :per_page => @layout["count"])
    render :action => 'list_observations'
  end

  # observation_index.rhtml
  def observation_index
    store_location
    # Used to be:
    # @observations = Observation.find(:all, :order => "'what' asc, 'when' desc")
    # Now use straight SQL to avoid extracting user info for each observation
    @data = Observation.connection.select_all("select o.id, n.observation_name, o.when, u.name, u.login" +
                                              " from observations o, users u, names n" +
                                              " where o.user_id = u.id and n.id = o.name_id" +
                                              " order by n.observation_name asc, 'when' desc")
    # Moved the calculation of observation_ids into the view since it's embedded in @data
    @session['observation'] = nil
    @session['image_ids'] = nil
  end

  # list_observations.rhtml -> show_observation.rhtml
  # Setup session to have the right observation.
  def show_observation
    store_location
    @observation = Observation.find(params[:id])
    @session['observation'] = params[:id].to_i
    @session['image_ids'] = nil
  end

  # left-hand panel -> new_observation.rhtml
  def new_observation
    if verify_user(@session['user'])
      @session['observation_ids'] = nil
      @session['observation'] = nil
      @session['image_ids'] = nil
      @observation = Observation.new
      @observation.name = Name.find_name(:Kingdom, 'Fungi').first
    end
  end
  
  # create_observation.rhtml -> multiple_names_create.rhtml
  def multiple_names_create
    args = @session[:args]
    @session[:args] = nil
    @observation = Observation.new(args)
    if check_user_id(@observation.user_id)
      @what = args[:what]
      @names = Name.find_names(@what)
    else 
      render :action => 'show_observation'
    end
  end

  def create_observation_with_selected_name
    user_id = params[:user_id]
    if check_user_id(user_id)
      # Verify that the user didn't change the what field
      input_what = params[:what]
      output_what = params[:observation][:what]
      if input_what != output_what
        params[:observation][:name_id] = nil
      end
    end
    create_observation
  end

  # create_observation.rhtml -> unknown_name_create.rhtml
  # This should get merged with the source for unknown_name along
  # with the rest of the commonality between create_observation and
  # update_observation.
  def unknown_name_create
    args = @session[:args]
    @session[:args] = nil
    @observation = Observation.new(args)
    if check_user_id(@observation.user_id)
      @what = args[:what]
      @session['observation'] = params[:id].to_i
    else 
      redirect_to :action => 'show_observation', :id => params[:id]
    end
  end

  def create_observation_with_new_name
    user_id = params[:user_id].to_i
    logger.warn("**++: user_id: %s" % user_id)
    if check_user_id(user_id)
      input_what = params[:what]
      logger.warn("**++: params[:what]: %s" % params[:what])
      output_what = params[:observation][:what]
      logger.warn("**++: params[:observation][:what]: %s" % params[:observation][:what])
      if input_what == output_what
        names = Name.names_from_string(output_what)
        if names.last.nil?
          flash[:notice] = "Unable to create the name %s", str
        else
          for n in names
            n.user_id = user_id
            n.save
          end
        end
      end
    end
    create_observation
  end

  # new_observation.rhtml -> list_observations.rhtml
  def create_observation
    user = @session['user']
    if verify_user(user)
      @observation = Observation.new(params[:observation])
      now = Time.now
      @observation.created = now
      @observation.modified = now
      @observation.user = user
      name_id = params[:observation][:name_id]
      if name_id
        names = [Name.find(name_id)]
      else
        names = Name.find_names(@observation.what)
      end
      if names.length == 1
        @observation.name = names[0]
        if @observation.save
          @observation.log('Observation created by ' + @session['user'].login, true)
          flash[:notice] = 'Observation was successfully created.'
          redirect_to :action => 'show_observation', :id => @observation
        else
          render :action => 'new_observation'
        end
      elsif names.length == 0
        # @observation.what has new name
        args = params[:observation]
        args[:user_id] = user.id
        @session[:args] = params[:observation]
        redirect_to :action => 'unknown_name_create'
      else
        # @observation.what matches more than one name
        @names = names
        args = params[:observation]
        args[:user_id] = user.id
        @session[:args] = params[:observation]
        flash[:notice] = 'More than one matching name was found'
        redirect_to :action => 'multiple_names_create'
      end
    end
  end
  
  # list_observation.rhtml, show_observation.rhtml -> edit_observation.rhtml
  # Setup session to have the right observation.
  def edit_observation
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      @session['observation'] = params[:id].to_i
    else 
      render :action => 'show_observation'
    end
  end
  
  # update_observation.rhtml -> multiple_names.rhtml
  def multiple_names
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      @what = params[:what]
      @names = Name.find_names(@what)
      @session['observation'] = params[:id].to_i
    else 
      render :action => 'show_observation'
    end
  end

  def update_observation_with_selected_name
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      # Verify that the user didn't change the what field
      input_what = params[:what]
      output_what = params[:observation][:what]
      if input_what != output_what
        params[:observation][:name_id] = nil
      end
    end
    update_observation
  end
  
  # update_observation.rhtml -> unknown_name.rhtml
  def unknown_name
    @observation = Observation.find(params[:id])
    @what = params[:what]
    if check_user_id(@observation.user_id)
      @session['observation'] = params[:id].to_i
    else 
      render :action => 'show_observation'
    end
  end

  def update_observation_with_new_name
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      input_what = params[:what]
      output_what = params[:observation][:what]
      if input_what == output_what
        names = Name.names_from_string(output_what)
        if names.last.nil?
          flash[:notice] = "Unable to create the name %s", str
        else
          user = @observation.user
          for n in names
            n.user = user
            n.save
          end
        end
      end
    end
    update_observation
  end

  # edit_observation.rhtml -> show_observation.rhtml
  # Updates modified and saves changes
  def update_observation
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id) # Even though edit makes this check, avoid bad guys going directly
      if params[:observation][:name_id].nil?
        names = Name.find_names(params[:observation][:what])
      else
        names = [Name.find(params[:observation][:name_id])]
      end
      if names.length == 1
        if @observation.update_attributes(params[:observation])
          @observation.name = names.first
          
          # Why does this work and the following line doesn't?
          # Tested with 'obs_mod' rather than 'modified'.  Same effect.
          @observation.modified = Time.now
          # @observation.touch
          @observation.save

          @observation.log('Observation updated by ' + @session['user'].login,
                           params[:log_change][:checked] == '1')

          flash[:notice] = 'Observation was successfully updated.'
          redirect_to :action => 'show_observation', :id => @observation
        else
          render :action => 'edit_observation'
        end
      elsif names.length == 0
        # @observation.what has new name
        redirect_to :action => 'unknown_name', :id => @observation, :what => params[:observation][:what]
      else
        # @observation.what matches more than one name
        @names = names
        flash[:notice] = 'More than one matching name was found'
        redirect_to :action => 'multiple_names', :id => @observation, :what => params[:observation][:what]
      end
    else
      render :action => 'show_observation'
    end
  end

  # list_observations.rhtml -> destroy -> list_observations.rhtml
  def destroy_observation
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      for l in @observation.species_lists
        l.log(sprintf('Observation, %s, destroyed by %s', @observation.unique_text_name, @observation.id, @session['user'].login))
      end
      @observation.orphan_log('Observation destroyed by ' + @session['user'].login)
      @observation.comments.each {|c| c.destroy }
      @observation.destroy
      redirect_to :action => 'list_observations'
    else
      render :action => 'show_observation'
    end
  end

  def prev_observation
    @observation = Observation.find(params[:id])
    obs = @session['observation_ids']
    index = obs.index(params[:id].to_i)
    if index.nil? or obs.nil? or obs.length == 0
      index = 0
    else
      index = index - 1
      if index < 0
        index = obs.length - 1
      end
    end
    id = obs[index]
    redirect_to :action => 'show_observation', :id => id
  end

  def next_observation
    @observation = Observation.find(params[:id])
    obs = @session['observation_ids']
    index = obs.index(params[:id].to_i)
    if index.nil? or obs.nil? or obs.length == 0
      index = 0
    else
      index = index + 1
      if index >= obs.length
        index = 0
      end
    end
    id = obs[index]
    redirect_to :action => 'show_observation', :id => id
  end

      
  ## Image support

  # Various -> list_images.rhtml
  def list_images
    @session['observation_ids'] = []
    @session['observation'] = nil
    @session['image_ids'] = self.query_ids("select id, `when` from images order by `when` desc")
    
    store_location
    @layout = calc_layout_params
    @image_pages, @images = paginate(:images,
                                     :order => "`when` desc",
                                     :per_page => @layout["count"])
  end

  # images_by_title.rhtml
  def images_by_title
    @session['observation_ids'] = nil
    @session['observation'] = nil
    @session['image_ids'] = nil
    store_location
    @images = Image.find(:all, :order => "'title' asc, 'when' desc")
  end

  # list_images -> show_image.rhtml
  # show_original.rhtml -> show_image.rhtml
  # Thumbnails should hook up to this
  def show_image
    store_location
    @image = Image.find(params[:id])
  end

  # show_image.rhtml -> show_original.rhtml
  def show_original
    store_location
    @image = Image.find(params[:id])
  end

  # list_images.rhtml, show_image.rhtml -> edit_image.rhtml
  def edit_image
    @image = Image.find(params[:id])
    unless check_user_id(@image.user_id)
      render :action => 'show_image'
    end
  end

  # edit_image.rhtml -> update_image -> show_image.rhtml
  def update_image
    @image = Image.find(params[:id])
    if check_user_id(@image.user_id) # Even though edit makes this check, avoid bad guys going directly
      if @image.update_attributes(params[:image])
        @image.modified = Time.now
        @image.save
        for o in @image.observations
          o.log(sprintf('Image, %s, updated by %s', @image.unique_text_name, @image.id, @session['user'].login), true)
        end
        flash[:notice] = 'Image was successfully updated.'
        redirect_to :action => 'show_image', :id => @image
      else
        render :action => 'edit_image'
      end
    else
      render :action => 'show_image'
    end
  end

  # list_images.rhtml -> list_images.rhtml
  # Should this be allowed?  How do we cleanup corresponding observations?
  def destroy_image
    @image = Image.find(params[:id])
    if check_user_id(@image.user_id)
      image_name = @image.unique_text_name
      for observation in Observation.find(:all, :conditions => sprintf("thumb_image_id = '%s'", @image.id))
        observation.log(sprintf('Image, %s, destroyed by %s', image_name, @session['user'].login), false)
        observation.thumb_image_id = nil
        observation.save
      end
      @image.destroy
      redirect_to :action => 'list_images'
    else
      render :action => 'show_image'
    end
  end

  # show_observation.rhtml -> reuse_image.rhtml
  def reuse_image
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      @image = Image.new
      @image.copyright_holder = @session['user'].legal_name
      @layout = calc_layout_params
      @image_pages, @images = paginate(:images,
                                       :order => "'when' desc",
                                       :per_page => @layout["count"])
    else
      render :action => 'show_observation'
    end
  end

  # deprecated
  def manage_images
    @observation = Observation.find(params[:id])
    logger.error("manage_images has been deprecated")
    flash[:notice] = 'manage_images has been deprecated'
    redirect_to(:action => 'show_observation', :id => @observation)
  end

  # show_observation.rhtml -> add_image.rhtml
  def add_image
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      @image = Image.new
      @image.copyright_holder = @session['user'].legal_name
    else
      render :action => 'show_observation'
    end
  end

  # test method for debugging image loading
  def do_load_test
    now = Time.now
    image_field = params[:image][:image]
    logger.warn(sprintf("  *** start %s: %s", now, image_field))
    content_type = image_field.content_type.chomp
    @img = image_field.read
    logger.warn(sprintf("  *** end %s: %s", now, Time.now))
    render :action => 'load_test'
  end

  # show_observation.rhtml -> remove_images.rhtml
  def remove_images
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      @image = Image.new
      @image.copyright_holder = @session['user'].legal_name
    else
      render :action => 'show_observation'
    end
  end
  
  def upload_image
    @observation = Observation.find(params[:observation][:id])
    if check_user_id(@observation.user_id)
      # Upload image
      @image = Image.new(params[:image])
      @image.created = Time.now
      @image.modified = @image.created
      @image.user = @session['user']
      if @image.save
        if @image.save_image
          @observation.log(sprintf('Image, %s, created by %s', @image.unique_text_name, @session['user'].login), true)
          @observation.add_image(@image)
          @observation.save
        else
          logger.error("Unable to upload image")
          flash[:notice] = 'Invalid image'
        end
      end
      redirect_to(:action => 'show_observation', :id => @observation)
    else
      render :action => 'show_observation'
    end
  end

  # remove_images.rhtml -> delete_images -> show_observation.rhtml
  def delete_images
    @observation = Observation.find(params[:observation][:id])
    if check_user_id(@observation.user_id)
      # Delete images
      images = params[:selected]
      if images
        images.each do |image_id, do_it|
          if do_it == 'yes'
            image = @observation.remove_image_by_id(image_id)
            if !image.nil?
              @observation.log(sprintf('Image, %s, removed by %s', image.unique_text_name, @session['user'].login), false)
            end
          end
        end
      end
      redirect_to(:action => 'show_observation', :id => @observation)
    else
      render :action => 'show_observation'
    end
  end

  def add_image_to_obs
    @observation = Observation.find(params[:obs_id])
    if check_user_id(@observation.user_id)
      image = @observation.add_image_by_id(params[:id])
      if !image.nil?
        @observation.log(sprintf('Image, %s, reused by %s', image.unique_text_name, @session['user'].login), true)
      end
      redirect_to(:action => 'show_observation', :id => @observation)
    end
  end
  
  # reuse_image.rhtml -> reuse_image_by_id -> show_observation.rhtml
  def reuse_image_by_id
    @observation = Observation.find(params[:observation][:id])
    if check_user_id(@observation.user_id)
      image = @observation.add_image_by_id(params[:observation][:idstr].to_i)
      if !image.nil?
        @observation.log(sprintf('Image, %s, reused by %s', image.unique_text_name, @session['user'].login), true)
      end
      redirect_to(:action => 'show_observation', :id => @observation)
    end
  end

  # deprecated along with manage_images
  def save_image
    @observation = @session['observation']
    logger.error("save_image has been deprecated")
    flash[:notice] = 'save_image has been deprecated'
    redirect_to(:action => 'show_observation', :id => @observation)
  end

  # left-hand panel -> new_species_list.rhtml
  def new_species_list
    user = @session['user']
    if verify_user(user)
      read_session
    end
  end

  # list_species_list.rhtml & notes links -> show_species_list.rhtml
  # Use session to store the current species list since this parallels
  # the usage for show_observation.
  def show_species_list
    store_location
    @species_list = SpeciesList.find(params[:id])
    @session[:species_list] = @species_list
  end

  # Needs both a species_list and an observation.
  def remove_observation_from_species_list
    species_list = SpeciesList.find(params[:species_list])
    if check_user_id(species_list.user_id)
      observation = Observation.find(params[:observation])
      species_list.modified = Time.now
      species_list.observations.delete(observation)
      redirect_to :action => 'manage_species_lists', :id => observation
    end
  end

  # Needs both a species_list and an observation.
  def add_observation_to_species_list
    species_list = SpeciesList.find(params[:species_list])
    if check_user_id(species_list.user_id)
      observation = Observation.find(params[:observation])
      species_list.modified = Time.now
      species_list.observations << observation
      redirect_to :action => 'manage_species_lists', :id => observation
    end
  end
  
  # left-hand panel -> list_species_lists.rhtml
  def list_species_lists
    @session['observation_ids'] = nil
    @session['observation'] = nil
    @session['image_ids'] = nil
    store_location
    @species_list_pages, @species_lists = paginate(:species_lists,
                                                   :order => "'when' desc, 'id' desc",
                                                   :per_page => 10)
  end

  # list_species_lists.rhtml -> destroy -> list_species_lists.rhtml
  def destroy_species_list
    @species_list = SpeciesList.find(params[:id])
    if check_user_id(@species_list.user_id)
      @species_list.orphan_log('Species list destroyed by ' + @session['user'].login)
      @species_list.destroy
      redirect_to :action => 'list_species_lists'
    else
      render :action => 'show_species_list'
    end
  end

  # species_lists_by_title.rhtml
  def species_lists_by_title
    @session['observation_ids'] = nil
    @session['observation'] = nil
    @session['image_ids'] = nil
    store_location
    @species_lists = SpeciesList.find(:all, :order => "'what' asc, 'when' desc")
  end

  def read_session
    # Pull all the state out of the session and clean out the session
    @species_list = @session['species_list']
    @session['species_list'] = nil
    @list_members = @session['list_members']
    @session['list_members'] = nil
    @new_names = @session['new_names']
    @session['new_names'] = nil
    @multiple_names = @session['multiple_names']
    @session['multiple_names'] = nil
    @member_notes = @session['member_notes']
    @session['member_notes'] = nil
    @names_only = @session['names_only']
    @session['names_only'] = nil
  end
  
  # list_species_list.rhtml, show_species_list.rhtml -> edit_species_list.rhtml
  # Setup session to have the right species_list.
  def edit_species_list
    species_list = SpeciesList.find(params[:id])
    if check_user_id(species_list.user_id)
      read_session
      @species_list = species_list
    else 
      render :action => 'show_species_list'
    end
  end

  def create_approved_names(name_list, approved_names, user)
    if approved_names
      for ns in name_list
        name_str = ns.strip
        if approved_names.member? name_str
          logger.warn("  **: create_approved_names: %s" % name_str)
          names = Name.names_from_string(name_str)
          logger.warn("  **: %s names from %s" % [names.length, name_str])
          if names.last.nil?
            flash[:notice] = "Unable to create the name %s", name_str
          else
            for n in names
              n.user = user
              n.save
            end
          end
        end
      end
    end
  end

  # Verify the user and derive the species list.  If id is provided then
  # load the species list from the database, otherwise use the args.
  def get_user_and_species_list(id, args, names_only)
    user = nil
    species_list = nil
    now = Time.now
    if id
      species_list = SpeciesList.find(id)
      user_id = species_list.user_id
      if check_user_id(user_id)
        user = species_list.user
        if not names_only
          species_list.modified = now
          if not species_list.update_attributes(params[:species_list]) # Does save
            species_list = nil
          end
        end
      end
    else
      user = @session['user']
      if verify_user(user)
        args["created"] = now
        args["modified"] = now
        args["user"] = user
        species_list = SpeciesList.new(args)
      else
        user = nil
      end
    end
    [user, species_list]
  end

  def do_action(action, id, args, names_only, notes, sorter)
    if args
      # Store all the state in the session since we can't put it in the database yet
      # and it's too awkward to pass through the URL effectively
      @session['species_list'] = SpeciesList.new(args)
      @session['list_members'] = sorter.all_name_strs.join("\r\n")
      @session['new_names'] = sorter.new_name_strs.uniq
      @session['multiple_names'] = sorter.multiple_name_strs.uniq
      @session['member_notes'] = notes
      if names_only
        @session['names_only'] = ["true"]
      else
        @session['names_only'] = ["false"]
      end
    end
    redirect_to :action => action, :id => id
  end
  
  def process_species_list(id, params, type_str, action)
    args = params[:species_list]
    names_only = (params[:names_only][:first] != "false")
    user, species_list = get_user_and_species_list(id, args, names_only)
    if user
      notes = params[:member][:notes]
      list = params[:list][:members]
      create_approved_names(list, params[:approved_names], user)
      sorter = NameSorter.new
      sorter.chosen_names = params[:chosen_names]
      sorter.sort_names(list)
      if species_list
        species_list.process_file_data(sorter)
        if sorter.only_single_names
          if names_only
            flash[:notice] = "All names are now in the database."
            action = 'name_index'
            args = nil
          else
            if species_list.save
              species_list.log("Species list %s by %s" % [type_str, user.login])
              flash[:notice] = "Species List was successfully %s." % type_str
              sp_args = { :created => species_list.modified, :user => user, :notes => notes,
                          :where => species_list.where }
              sp_when = species_list.when # Can't use params since when is split up
              logger.warn("  **: about to create %s new observations" % sorter.single_names.length)
              for name, timestamp in sorter.single_names
                sp_args[:when] = timestamp || sp_when
                species_list.construct_observation(name, sp_args)
              end
              action = 'show_species_list'
              id = species_list.id
              args = nil
            end
          end
        end
      end
      do_action(action, id, args, names_only, notes, sorter)
    else
      redirect_to :action => 'list_species_lists'
    end
  end

  def update_species_list
    process_species_list(params[:id], params, 'updated', 'edit_species_list')
  end

  def create_species_list
    process_species_list(nil, params, 'created', 'new_species_list')
  end

  # show_observation.rhtml -> manage_species_lists.rhtml
  def manage_species_lists
    user = @session['user']
    if verify_user(user)
      @observation = Observation.find(params[:id])
    end
  end

  # users_by_name.rhtml
  # Restricted to the admin user
  def users_by_name
    if check_permission(0)
      @users = User.find(:all, :order => "'last_login' desc")
    else
      redirect_to :action => 'list_observations'
    end
  end
  
  def ask_webmaster_question
    @user = @session['user']
  end
  
  def send_webmaster_question
    sender = @params['user']['email']
    if sender.nil? or sender.strip == ''
      flash[:notice] = "You must provide a return address."
      redirect_to :action => 'ask_webmaster_question'
    else
      AccountMailer.deliver_webmaster_question(@params['user']['email'], @params['question']['content'])
      flash[:notice] = "Delivered question or comment."
      redirect_back_or_default :action => "list_rss_logs"
    end
  end

  # email_features.rhtml
  # Restricted to the admin user
  def email_features
    if check_permission(0)
      @users = User.find(:all, :conditions => "feature_email=1")
    else
      redirect_to :action => 'list_observations'
    end
  end
  
  def test_feature_email
    users = User.find(:all, :conditions => "feature_email=1")
    user = users[1]
    email = AccountMailer.create_email_features(user, @params['feature_email']['content'])
    render(:text => "<pre>" + email.encoded + "</pre>")
  end
  
  def send_feature_email
    users = User.find(:all, :conditions => "feature_email=1")
    for user in users
      AccountMailer.deliver_email_features(user, @params['feature_email']['content'])
    end
    flash[:notice] = "Delivered feature mail."
    redirect_to :action => 'users_by_name'
  end

  def ask_question
    @observation = Observation.find(params['id'])
    if !@observation.user.question_email
      flash[:notice] = "Permission denied"
      redirect_to :action => 'show_observation', :id => @observation
    end
  end
  
  def test_question
    sender = @session['user']
    observation = Observation.find(params['id'])
    question = @params['question']['content']
    email = AccountMailer.create_question(sender, observation, question)
    render(:text => "<pre>" + email.encoded + "</pre>")
  end
  
  def send_question
    sender = @session['user']
    observation = Observation.find(params['id'])
    question = @params['question']['content']
    AccountMailer.deliver_question(sender, observation, question)
    flash[:notice] = "Delivered question."
    redirect_to :action => 'show_observation', :id => observation
  end

  def commercial_inquiry
    @image = Image.find(params['id'])
    if !@image.user.commercial_email
      flash[:notice] = "Permission denied"
      redirect_to :action => 'show_image', :id => @image
    end
  end
  
  def test_commercial_inquiry
    sender = @session['user']
    image = Image.find(params['id'])
    commercial_inquiry = @params['commercial_inquiry']['content']
    email = AccountMailer.create_commercial_inquiry(sender, image, commercial_inquiry)
    render(:text => "<pre>" + email.encoded + "</pre>")
  end
  
  def send_commercial_inquiry
    sender = @session['user']
    image = Image.find(params['id'])
    commercial_inquiry = @params['commercial_inquiry']['content']
    AccountMailer.deliver_commercial_inquiry(sender, image, commercial_inquiry)
    flash[:notice] = "Delivered commercial inquiry."
    redirect_to :action => 'show_image', :id => image
  end

  def rss
    @headers["Content-Type"] = "application/xml" 
    @logs = RssLog.find(:all, :order => "'modified' desc",
                        :conditions => "datediff(now(), modified) <= 31")
    render_without_layout
  end
  
  # left-hand panel -> list_rss_logs.rhtml
  def list_rss_logs
    store_location
    @layout = calc_layout_params
    query = "select observation_id as id, modified from rss_logs where observation_id is not null and " +
            "modified is not null order by 'modified' desc"
    @session['observation_ids'] = self.query_ids(query)
    @session['observation'] = nil
    @session['image_ids'] = nil
    @rss_log_pages, @rss_logs = paginate(:rss_log,
                                         :order => "'modified' desc",
                                         :per_page => @layout["count"])
  end
  
  def show_rss_log
    store_location
    @rss_log = RssLog.find(params['id'])
  end
  
  def next_image
    current_image_id = params[:id].to_i
    (image_ids, current_observation) = current_image_state
    if image_ids # nil value means it wasn't set and the session data doesn't have anything to help
      obs_ids = @session['observation_ids']
      if image_ids == [] # current image list is empty, try for the next
        image_ids, current_observation = next_image_list(current_observation, obs_ids)
      end
      if image_ids != [] # empty list means there isn't a next_image_list with any content
        index = image_ids.index(current_image_id)
        if index.nil? # Not in the list so start at the first element
          current_image_id = image_ids[0]
        else
          index = index + 1
          if index >= image_ids.length # Run off the end of the current list
            image_ids, current_observation = next_image_list(current_observation, obs_ids)
            if image_ids != [] # Just in case
              current_image_id = image_ids[0]
            end
          else
            current_image_id = image_ids[index]
          end
        end
      end
    end
    @session['image_ids'] = image_ids
    @session['observation'] = current_observation
    redirect_to :action => 'show_image', :id => current_image_id
  end
  
  def prev_image
    current_image_id = params[:id].to_i
    (image_ids, current_observation) = current_image_state
    if image_ids # nil value means it wasn't set and the session data doesn't have anything to help
      obs_ids = @session['observation_ids']
      if image_ids == [] # current image list is empty, try for the next
        image_ids, current_observation = prev_image_list(current_observation, obs_ids)
      end
      if image_ids != [] # empty list means there isn't a next_image_list with any content
        index = image_ids.index(current_image_id)
        if index.nil? # Not in the list so start with the last element
          current_image_id = image_ids[-1]
        else
          index = index - 1
          if index < 0 # Run off the front of the current list
            image_ids, current_observation = prev_image_list(current_observation, obs_ids)
            if image_ids != [] # Just in case
              current_image_id = image_ids[-1]
            end
          else
            current_image_id = image_ids[index]
          end
        end
      end
    end
    @session['image_ids'] = image_ids
    @session['observation'] = current_observation
    redirect_to :action => 'show_image', :id => current_image_id
  end

  def resize_images
    if check_permission(0)
      for image in Image.find(:all)
        image.calc_size()
        image.resize_image(160, 160, image.thumbnail)
      end
    else
      flash[:notice] = "You must be an admin to access resize_images"
    end
    redirect_to :action => 'list_images'
  end
  
  def show_past_name
    store_location
    @past_name = PastName.find(params[:id])
    @other_versions = PastName.find(:all, :conditions => "name_id = %s" % @past_name.name_id, :order => "version desc")
  end
  
  # show_name.rhtml
  def show_name
    store_location
    @name = Name.find(params[:id])
    @past_name = PastName.find(:all, :conditions => "name_id = %s and version = %s" % [@name.id, @name.version - 1]).first
    @data = Observation.connection.select_all("select o.id, o.when, o.modified, o.when, o.thumb_image_id, o.where," +
                                              " u.name, u.login, n.observation_name" +
                                              " from observations o, users u, names n" +
                                              " where n.id = " + params[:id] +
                                              " and o.user_id = u.id and n.id = o.name_id" +
                                              " order by o.when desc")
    observation_ids = []
		@data.each { |d| observation_ids.push(d["id"].to_i) }
		session['observation_ids'] = observation_ids
		session['image_ids'] = nil
  end
  
  # show_name.rhtml -> edit_name.rhtml
  def edit_name
    user = @session['user']
    if verify_user(user)
      @name = Name.find(params[:id])
    else
    end
  end

  # edit_name.rhtml -> show_name.rhtml
  # Updates modified and saves changes
  def update_name
    user = @session['user']
    if verify_user(user)
      name = Name.find(params[:id])
      past_name = PastName.make_past_name(name)
      begin
        name.modified = Time.new
        name.change_text_name(params[:name][:text_name], params[:name][:author], params[:name][:rank])
        name.notes = params[:name][:notes]
        name.version = name.version + 1
        name.user = user
        past_name.save
        name.save
      rescue RuntimeError => err
        flash[:notice] = err.to_s
        redirect_to :action => 'edit_name', :id => name
      else
        redirect_to :action => 'show_name', :id => name
      end
    end
  end

  # name_index.rhtml
  def name_index
    store_location
    @names = Name.find(:all, :order => "'text_name' asc, 'author' asc")
  end

  # Ultimately running large queries like this and storing the info in the session
  # may become unwieldy.  Storing the query and selecting chunks will scale better.
  helper_method :query_ids
  def query_ids(query)
    result = []
    data = Observation.connection.select_all(query)
    for d in data
      id = d['id']
      if id
        result.push(id.to_i)
      end
    end
    result
  end

  # Get initial image_ids and observation_id
  helper_method :current_image_state
  def current_image_state
    obs_ids = @session['observation_ids']
    observation_id = @session['observation']
    if observation_id.nil? and obs_ids
      if obs_ids.length > 0
        observation_id = obs_ids[0]
      end
    end
    image_ids = @session['image_ids']
    if image_ids.nil? and observation_id
      images = Observation.find(observation_id).images
      image_ids = []
      for i in images
        image_ids.push(i.id)
      end
    end
    [image_ids, observation_id]
  end

  helper_method :next_id
  def next_id(id, id_list)
    result = id
    if id_list.length > 0
      result = id_list[0]
      index = id_list.index(id)
      if index
        index = index + 1
        if index < id_list.length
          result = id_list[index]
        end
      end
    end
    result
  end

  helper_method :next_image_list
  def next_image_list(observation_id, id_list)
    image_list = []
    current_id = observation_id
    if id_list.length > 0
      index = id_list.index(observation_id)
      if index.nil?
        index = id_list.length - 1
        observation_id = id_list[index]
      end
      current_id = observation_id
      while image_list == []
        current_id = next_id(current_id, id_list)
        if current_id == observation_id
          break
        end
        images = Observation.find(current_id).images
        image_list = []
        for i in images
          image_list.push(i.id)
        end
      end
    end
    [image_list, current_id]
  end
  
  helper_method :prev_id
  def prev_id(id, id_list)
    result = id
    if id_list.length > 0
      result = id_list[-1]
      index = id_list.index(id)
      if index
        index = index - 1
        if index >= 0
          result = id_list[index]
        end
      end
    end
    result
  end

  helper_method :prev_image_list
  def prev_image_list(observation_id, id_list)
    image_list = []
    current_id = observation_id
    if id_list.length > 0
      index = id_list.index(observation_id)
      if index.nil?
        index = 0
        observation_id = id_list[index]
      end
      current_id = observation_id
      while image_list == []
        current_id = prev_id(current_id, id_list)
        if current_id == observation_id
          break
        end
        images = Observation.find(current_id).images
        image_list = []
        for i in images
          image_list.push(i.id)
        end
      end
    end
    [image_list, current_id]
  end

  helper_method :check_permission
  def check_permission(user_id)
    user = @session['user']
    !user.nil? && user.verified && ((user_id == @session['user'].id) || (@session['user'].id == 0))
  end
  
  helper_method :calc_color
  def calc_color(row, col, alt_rows, alt_cols)
    color = 0
    if alt_rows
      color = row % 2
    end
    if alt_cols
      if (col % 2) == 1
        color = 1 - color
      end
    end
    color
  end

  helper_method :calc_image_ids
  def calc_image_ids(obs)
    result = nil
    if obs
      result = []
      for ob_id in obs:
        img_ids = Observation.connection.select_all("select image_id from images_observations" +
                                          " where observation_id=" + ob_id.to_s)
        for h in img_ids
          result.push(h['image_id'].to_i)
        end
      end
    end
    result
  end
  
  helper_method :calc_layout_params
  def calc_layout_params
    result = {}
    result["rows"] = 5
    result["columns"] = 3
    result["alternate_rows"] = true
    result["alternate_columns"] = true
    result["vertical_layout"] = true
    user = @session['user']
    if user
      result["rows"] = user.rows if user.rows
      result["columns"] = user.columns if user.columns
      result["alternate_rows"] = user.alternate_rows
      result["alternate_columns"] = user.alternate_columns
      result["vertical_layout"] = user.vertical_layout
    end
    result["count"] = result["rows"] * result["columns"]
    result
  end

  protected

  def check_user_id(user_id)
    result = check_permission(user_id)
    unless result
      flash[:notice] = 'Permission denied.'
    end
    result
  end

  def verify_user(user)
    result = false
    if @session['user'].verified.nil?
      redirect_to :controller => 'account', :action=> 'reverify', :id => @session['user'].id
    else
      result = true
    end
    result
  end
  # Look in obs_extras.rb for code for uploading directory trees of images.
end

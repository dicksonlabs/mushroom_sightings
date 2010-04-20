#
#  = Main Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  ==== RssLog's
#  list_rss_logs::
#  index_rss_log::
#  show_rss_log::
#  next_rss_log::
#  prev_rss_log::
#  rss::
#
#  ==== Observation's
#  show_observation::
#  next_observation::
#  prev_observation::
#  create_observation::
#  edit_observation::
#  destroy_observation::
#  create_naming::
#  edit_naming::
#  destroy_naming::
#  cast_vote::
#  show_votes::
#
#  ==== Notification's
#  show_notifications::
#  list_notifications::
#
#  ==== Observation Index
#  index_observation::
#  list_observations::
#  observations_by_name::
#  observations_by_user::
#  observations_at_location::
#  observations_at_where::
#  observation_search::
#  advanced_search::
#  show_selected_observations:: (helper)
#
#  ==== Searches
#  pattern_search::
#  advanced_search_form::
#  refine_search::
#
#  ==== Textile Object Links
#  lookup_comment::
#  lookup_image::
#  lookup_location::
#  lookup_name::
#  lookup_observation::
#  lookup_project::
#  lookup_species_list::
#  lookup_user::
#  lookup_general:: (helper)
#
#  ==== Description Authors
#  review_authors::    Let authors/reviewers add/remove authors from descriptions.
#  author_request::    Let non-authors request authorship credit on descriptions.
#
#  ==== Users
#  change_user_bonuses::
#  index_user::
#  users_by_name::
#  users_by_contribution::
#  show_user::
#  show_site_stats::
#
#  ==== Email Questions
#  ask_webmaster_question::
#  email_features::
#  send_feature_email::
#  ask_user_question::
#  ask_observation_question::
#  commercial_inquiry::
#  email_question:: (helper)
#
#  ==== Site Info
#  intro::
#  how_to_help::
#  how_to_use::
#  news::
#  textile_sandbox::
#  translators_note::
#
#  ==== Global Callbacks
#  no_ajax::
#  no_browser::
#  no_javascript::
#  no_session::
#  turn_javascript_on::
#  turn_javascript_off::
#
#  ==== Themes
#  color_themes::
#  Agaricus::
#  Amanita::
#  Cantharellus::
#  Hygrocybe::
#
#  ==== Test Views
#  throw_error::
#  throw_mobile_error::
#
#  ==== Admin Tools
#  recalc::
#  refresh_vote_cache::
#  clear_session::
#  w3c_tests::
#
################################################################################

class ObserverController < ApplicationController
  require 'find'
  require 'ftools'
  require 'set'

  require_dependency 'refine_search'
  include RefineSearch

  before_filter :login_required, :except => CSS + [
    :advanced_search,
    :advanced_search_form,
    :ask_webmaster_question,
    :color_themes,
    :how_to_help,
    :how_to_use,
    :index,
    :index_observation,
    :index_rss_log,
    :index_user,
    :intro,
    :list_observations,
    :list_rss_logs,
    :lookup_comment,
    :lookup_image,
    :lookup_location,
    :lookup_name,
    :lookup_observation,
    :lookup_project,
    :lookup_species_list,
    :lookup_user,
    :news,
    :next_observation,
    :no_ajax,
    :no_browser,
    :no_javascript,
    :no_session,
    :observation_search,
    :observations_by_name,
    :observations_by_user,
    :observations_at_where,
    :observations_at_location,
    :pattern_search,
    :prev_observation,
    :refine_search,
    :rss,
    :show_observation,
    :show_rss_log,
    :show_site_stats,
    :show_user,
    :show_votes,
    :textile,
    :textile_sandbox,
    :throw_error,
    :throw_mobile_error,
    :translators_note,
    :turn_javascript_nil,
    :turn_javascript_off,
    :turn_javascript_on,
    :user_search,
    :users_by_contribution,
    :w3c_tests,
  ]

  before_filter :disable_link_prefetching, :except => [
    :create_naming,
    :create_observation,
    :edit_naming,
    :edit_observation,
    :show_observation,
    :show_user,
    :show_votes,
  ]

  ##############################################################################
  #
  #  :section: General Stuff
  #
  ##############################################################################

  # Default page.  Just displays latest happenings.  The actual action is
  # buried way down toward the end of this file.
  def index # :nologin:
    list_rss_logs
  end

  # Provided just as a way to verify the before_filter.
  # This page should always require the user to be logged in.
  def login # :norobots:
    list_rss_logs
  end

  # Another test method.  Repurpose as needed.
  def throw_error # :nologin: :norobots:
    raise "Something bad happened."
  end

  # Used for initial investigation of specialized mobile support
  def throw_mobile_error # :nologin: :norobots:
    if request.env["HTTP_USER_AGENT"].index("BlackBerry")
      raise "This is a BlackBerry!"
    else
      raise request.env["HTTP_USER_AGENT"].to_s
    end
  end

  # Intro to site.
  def intro # :nologin:
  end

  # Recent features.
  def news # :nologin:
  end

  # Help page.
  def how_to_use # :nologin:
    @min_pos_vote = Vote.agreement(Vote.min_pos_vote).l
    @min_neg_vote = Vote.agreement(Vote.min_neg_vote).l
    @maximum_vote = Vote.agreement(Vote.maximum_vote).l
  end

  # A few ways in which users can help.
  def how_to_help # :nologin:
  end

  # Info on color themes.
  def color_themes # :nologin:
  end

  # Explanation of why not having AJAX is bad.
  def no_ajax # :nologin: :norobots:
  end

  # Explanation of why it's important that we recognize the user's browser.
  def no_browser # :nologin: :norobots:
  end

  # Explanation of why having javascript disabled is bad.
  def no_javascript # :nologin: :norobots:
  end

  # Explanation of why having cookies disabled is bad.
  def no_session # :nologin: :norobots:
  end

  # Simple form letting us test our implementation of Textile.
  def textile_sandbox # :nologin:
    if request.method != :post
      @code = nil
    else
      @code = params[:code]
      @submit = params[:commit]
    end
    render(:action => :textile_sandbox)
  end

  # I keep forgetting the stupid "_sandbox" thing.
  alias_method :textile, :textile_sandbox # :nologin:

  # Force javascript on.
  def turn_javascript_on # :nologin: :norobots:
    session[:js_override] = :on
    flash_notice(:turn_javascript_on_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to('/')
  end

  # Force javascript off.
  def turn_javascript_off # :nologin: :norobots:
    session[:js_override] = :off
    flash_notice(:turn_javascript_off_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to('/')
  end

  # Enable auto-detection.
  def turn_javascript_nil # :nologin: :norobots:
    session[:js_override] = nil
    flash_notice(:turn_javascript_nil_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to('/')
  end

  # Simple list of all the files in public/html that are linked to the W3C
  # validator to make testing easy.
  def w3c_tests # :nologin:
    render(:layout => false)
  end

  # Allow translator to enter a special note linked to from the lower left.
  def translators_note # :nologin:
  end

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  def lookup_comment;      lookup_general(Comment);     end # :nologin
  def lookup_image;        lookup_general(Image);       end # :nologin
  def lookup_location;     lookup_general(Location);    end # :nologin
  def lookup_name;         lookup_general(Name);        end # :nologin
  def lookup_observation;  lookup_general(Observation); end # :nologin
  def lookup_project;      lookup_general(Project);     end # :nologin
  def lookup_species_list; lookup_general(SpeciesList); end # :nologin
  def lookup_user;         lookup_general(User);        end # :nologin

  # Alternative to controller/show_object/id.  These were included for the
  # benefit of the textile wrapper: We don't want to be looking up all these
  # names and objects every time we display comments, etc.  Instead we make
  # _object_ link to these lookup_object methods, and defer lookup until the
  # user actually clicks on one.  These redirect to the appropriate
  # controller/action after looking up the object.
  def lookup_general(model)
    obj = nil
    id = params[:id].to_s.gsub('_',' ').strip_squeeze
    begin
      if id.match(/^\d+$/)
        obj = model.find(id)
      else
        case model.to_s

          when 'Name'
            if parse = Name.parse_name(id)
              obj = Name.find_by_search_name(parse[3]) ||
                    Name.find_by_text_name(parse[0])
            end

          when 'Location'
            pattern = id.downcase.gsub(/\W+/, '%')
            ids = Location.connection.select_values %(
              SELECT id FROM locations
              WHERE LOWER(locations.search_name) LIKE '%#{pattern}%'
            )
            obj = Location.find(ids.first) if ids.length == 1

          when 'User'
            obj = User.find_by_login(id) ||
                  User.find_by_name(id)

        end
      end
    rescue
    end
    if obj
      redirect_to(:controller => obj.show_controller,
                  :action => obj.show_action, :id => obj.id)
    else
      type = model.type_tag
      flash_error(:runtime_object_no_match.t(:match => id, :type => type))
      goto_index(model)
    end
  end

  # This is the action the search bar commits to.  It just redirects to one of
  # several "foreign" search actions:
  #   comment/image_search
  #   image/image_search
  #   location/location_search
  #   name/name_search
  #   observer/observation_search
  #   observer/user_search
  #   project/project_search
  #   species_list/species_list_search
  def pattern_search # :nologin: :norobots:
    pattern = params[:search][:pattern].to_s.strip_squeeze rescue nil
    type    = params[:search][:type].to_sym                rescue nil

    # Save it so that we can keep it in the search bar in subsequent pages.
    session[:pattern] = pattern
    session[:search_type] = type

    case type
    when :observation, :user, :google
      ctrlr = 'observer'
    when :comment, :image, :location, :name, :project, :species_list
      ctrlr = type
    else
      flash_error(:runtime_invalid.t(:type => :search, :value => type.inspect))
      redirect_back_or_default(:action => 'list_rss_logs')
    end

    # If pattern is blank, this would devolve into a very expensive index.
    if pattern.blank?
      type = 'rss_log' if type == :google
      redirect_to(:controller => ctrlr, :action => "list_#{type}s")
    elsif type == :google
      pat = URI.escape("site:#{DOMAIN} #{pattern}")
      redirect_to("http://google.com?q=#{pat}")
    else
      redirect_to(:controller => ctrlr, :action => "#{type}_search",
                  :pattern => pattern)
    end
  end

  # Advanced search form.  When it posts it just redirects to one of several
  # "foreign" search actions:
  #   image/advanced_search
  #   name/advanced_search
  #   observer/advanced_search
  def advanced_search_form # :nologin: :norobots:
    if request.method != :post
      @location_primer = Location.primer
      @name_primer     = Name.primer
      @user_primer     = User.primer
    else
      model = params[:search][:type].to_s.camelize.constantize

      # Pass along all given search fields (remove angle-bracketed user name,
      # though, since it was only included by the auto-completer as a hint).
      search = {}
      if !(x = params[:search][:name].to_s).blank?
        search[:name] = x
      end
      if !(x = params[:search][:location].to_s).blank?
        search[:location] = x
      end
      if !(x = params[:search][:user].to_s).blank?
        search[:user] = x.sub(/ <.*/, '')
      end
      if !(x = params[:search][:content].to_s).blank?
        search[:content] = x
      end

      # Create query (this just validates the parameters).
      query = create_query(model, :advanced_search, search)

      # Let the individual controllers execute and render it.
      redirect_to(:controller => model.show_controller,
        :action => 'advanced_search', :params => query_params(query))
    end
  end

  # Allow users to refine an existing query.
  def refine_search # :nologin:
    # Create a bogus object with all the parameters used in the form.
    @values = Wrapper.new(params[:values] || {})
    @first_time = params[:values].blank?
    @goto_index = true if params[:commit] == :refine_search_goto_index.l
    @errors = []

    # Query has expired!
    if !(@query = find_query)
      flash_error(:runtime_search_has_expired.t)
      redirect_back_or_default(:action => 'list_rss_logs')

    else
      # Need to know about change to basic flavor immediately.
      if @first_time || @values.model_flavor.blank?
        query2 = @query
      else
        model2, flavor2 = @values.model_flavor.to_s.split(' ', 2)
        query2 = Query.template(model2.camelize, flavor2) rescue @query
      end
      model2  = query2.model_symbol
      flavor2 = query2.flavor

      # Get Array of parameters we can play with.
      @fields = refine_search_get_fields(query2)

      # Modify the query on POST, test it out, and redirect or re-serve form.
      if !@first_time &&
         (request.method == :post) and !is_robot?
        params2 = refine_search_clone_params(query2, @query.params)
        @errors = refine_search_change_params(@fields, @values, params2)

        if @errors.any?
          # Already flashed errors.

        # No changes.  This may not be apparent due to vagaries of parsing.
        # This will change all the form values to be what's currently in the
        # query.  The user will then know exactly why we say "no changes".
        elsif (model2  == @query.model_symbol) and
              (flavor2 == @query.flavor) and
              (params2 == @query.params)
          flash_notice(:runtime_no_changes.t) if !@goto_index

        else
          begin
            # Create and initialize the new query to test it out.
            query2 = Query.lookup(model2, flavor2, params2)
            query2.initialize_query
            query2.save
            @query = query2
            if !@goto_index
              flash_notice(:refine_search_success.t(:num => @query.num_results))
            end
          rescue => e
            flash_error(e)
            # flash_error(e.backtrace.join("<br>"))
          end
        end
      end
    end

    # Redisplay the index if user presses "Index".
    if @goto_index
      redirect_to(:controller => @query.model.show_controller,
                  :action => @query.model.index_action,
                  :params => query_params(@query))
    else
      @flavor_field = refine_search_flavor_field
      @values.model_flavor = "#{model2.to_s.underscore} #{flavor2}"
      refine_search_initialize_values(@fields, @values, @query)
    end
  end

  # Displays matrix of selected Observation's (based on current Query).
  def index_observation # :nologin: :norobots:
    query = find_or_create_query(:Observation, :by => params[:by])
    show_selected_observations(query, :id => params[:id],
                               :always_index => true)
  end

  # Displays matrix of all Observation's, sorted by date.
  def list_observations # :nologin:
    query = create_query(:Observation, :all, :by => :date)
    show_selected_observations(query)
  end

  # Displays matrix of all Observation's, alphabetically.
  def observations_by_name # :nologin: :norobots:
    query = create_query(:Observation, :all, :by => :name)
    show_selected_observations(query)
  end

  # Displays matrix of User's Observation's, by date.
  def observations_by_user # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id]) : @user
      query = create_query(:Observation, :by_user, :user => user)
      show_selected_observations(query)
    end
  end

  # Displays matrix of Observation's at a Location, by date.
  def observations_at_location # :nologin: :norobots:
    if location = find_or_goto_index(Location, params[:id])
      query = create_query(:Observation, :at_location, :location => location)
      show_selected_observations(query)
    end
  end

  # Display matrix of Observation's whose 'where' matches a string.
  def observations_at_where # :nologin: :norobots:
    where = params[:where].to_s
    query = create_query(:Observation, :at_where, :location => where)
    show_selected_observations(query)
  end

  # Display matrix of Observation's whose notes, etc. match a string pattern.
  def observation_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) and
       (observation = Observation.safe_find(pattern))
      redirect_to(:action => 'show_observation', :id => observation.id)
    else
      query = create_query(:Observation, :pattern_search, :pattern => pattern)
      show_selected_observations(query)
    end
  end

  # Displays matrix of advanced search results.
  def advanced_search # :nologin: :norobots:
    begin
      query = find_query(:Observation)
      show_selected_observations(query)
    rescue => err
      flash_error(err)
      redirect_to(:controller => 'observer', :action => 'advanced_search_form')
    end
  end

  # Show selected search results as a matrix with 'list_observations' template.
  def show_selected_observations(query, args={})
    store_query_in_session(query)
    @links ||= []
    args = {
      :action => 'list_observations',
      :matrix => true,
      :include => [:name, :location, :user, :rss_log],
    }.merge(args)

    # Add some extra links to the index user is sent to if they click on an
    # undefined location.
    if query.flavor == :at_where
      @links += [
        [ :list_observations_location_define.l, { :controller => 'location',
          :action => 'create_location', :where => params[:location] } ],
        [ :list_observations_location_merge.l, { :controller => 'location',
          :action => 'list_merge_options', :where => params[:location] } ],
        [ :list_observations_location_all.l, { :controller => 'location',
          :action => 'list_locations' } ],
      ]
    end

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name',       :sort_by_name.t],
      ['date',       :sort_by_date.t],
      ['user',       :sort_by_user.t],
      ['created',    :sort_by_posted.t],
      [(query.flavor == :by_rss_log ? 'rss_log' : 'modified'),
                     :sort_by_modified.t],
      ['confidence', :sort_by_confidence.t],
      ['thumbnail_quality', :sort_by_thumbnail_quality.t],
      ['num_views',  :sort_by_num_views.t],
    ]

    # Add "show map" link if this query can be coerced into a location query.
    if query.is_coercable?(:Location)
      @links << [:show_object.t(:type => :map), {
                  :controller => 'location',
                  :action => 'map_locations',
                  :params => query_params(query),
                }]
      @links << [:show_objects.t(:type => :location), {
                  :controller => 'location',
                  :action => 'index_location',
                  :params => query_params(query),
                }]
    end

    # Add "show names" link if this query can be coerced into a name query.
    if query.is_coercable?(:Name)
      @links << [:show_objects.t(:type => :name), {
                  :controller => 'name',
                  :action => 'index_name',
                  :params => query_params(query),
                }]
    end

    # Add "show images" link if this query can be coerced into an image query.
    if query.is_coercable?(:Image)
      @links << [:show_objects.t(:type => :image), {
                  :controller => 'image',
                  :action => 'index_image',
                  :params => query_params(query),
                }]
    end

    # Paginate by letter if sorting by user.
    if (query.params[:by] == 'user') or
       (query.params[:by] == 'reverse_user')
      args[:letters] = 'users.login'
    # Paginate by letter if names are included in query.
    elsif query.uses_table?(:names)
      args[:letters] = 'names.text_name'
    end

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show Observation
  #
  ##############################################################################

  # Display observation and related namings, comments, votes, images, etc.
  # This should be redirected_to, not rendered, due to large number of
  # @variables that need to be set up for the view.  Lots of views are used:
  #   show_observation
  #   _show_observation
  #   _show_images
  #   _show_namings
  #   _show_comments
  #   _show_footer
  # Linked from countless views as a fall-back.
  # Inputs: params[:id]
  # Outputs:
  #   @observation
  #   @confidence/agreement_menu    (used to create vote menus)
  #   @votes                        (user's vote for each naming.id)
  def show_observation # :nologin: :prefetch:
    pass_query_params
    store_location

    # Make it really easy for users to elect to go public with their votes.
    if params[:go_public] == '1'
      @user.votes_anonymous = :no
      @user.save
      flash_notice(:show_votes_gone_public.t)
    elsif params[:go_private] == '1'
      @user.votes_anonymous = :yes
      @user.save
      flash_notice(:show_votes_gone_private.t)
    end

    # Make it easy for users to change thumbnail size.
    if !params[:set_thumbnail_size].blank?
      set_default_thumbnail_size(params[:set_thumbnail_size])
    end

    if @observation = find_or_goto_index(Observation, params[:id], :include => [
                        {:comments => :user},
                        :images,
                        :location,
                        :name,
                        {:namings => [:name, :user, {:votes => :user}]},
                        {:species_lists => :location},
                        :user,
                     ])
      update_view_stats(@observation)

      # Decide if the current query can be used to create a map.
      query = find_query(:Observation)
      @mappable = query && query.is_coercable?(:Location)

      if @user
        # This happens when user clicks on "Update Votes".
        if request.method == :post
          if params[:vote]
            flashed = false
            for naming in @observation.namings
              if (value = params[:vote][naming.id.to_s][:value].to_i rescue nil) and
                 @observation.change_vote(naming, value) and
                 !flashed
                flash_notice(:runtime_show_observation_success.t)
                flashed = true
              end
            end
          end
        end

        # Provide a list of user's votes to view.
        @votes = {}
        for naming in @observation.namings
          vote = naming.votes.select {|x| x.user_id == @user.id}.first
          vote ||= Vote.new(:value => 0)
          @votes[naming.id] = vote
        end
        @confidence_menu = translate_menu(Vote.confidence_menu)
        @agreement_menu  = translate_menu(Vote.agreement_menu)
      end
    end
  end

  # Go to next observation: redirects to show_observation.
  def next_observation # :nologin: :norobots:
    redirect_to_next_object(:next, Observation, params[:id])
  end

  # Go to previous observation: redirects to show_observation.
  def prev_observation # :nologin: :norobots:
    redirect_to_next_object(:prev, Observation, params[:id])
  end

  ##############################################################################
  #
  #  :section: Create and Edit Observations
  #
  ##############################################################################

  # Form to create a new observation, naming, vote, and images.
  # Linked from: left panel
  #
  # Inputs:
  #   params[:observation][...]         observation args
  #   params[:name][:name]              name
  #   params[:approved_name]            old name
  #   params[:chosen_name][:name_id]    name radio boxes
  #   params[:vote][...]                vote args
  #   params[:reason][n][...]           naming_reason args
  #   params[:image][n][...]            image args
  #   params[:good_images]              images already downloaded
  #   params[:was_js_on]                was form javascripty? ('yes' = true)
  #
  # Outputs:
  #   @observation, @naming, @vote      empty objects
  #   @what, @names, @valid_names       name validation
  #   @confidence_menu                  used for vote option menu
  #   @reason                           array of naming_reasons
  #   @images                           array of images
  #   @licenses                         used for image license menu
  #   @new_image                        blank image object
  #   @good_images                      list of images already downloaded
  #
  def create_observation # :prefetch: :norobots:
    # These are needed to create pulldown menus in form.
    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(Time.now)
    @confidence_menu = translate_menu(Vote.confidence_menu)

    # Clear search list.
    clear_query_in_session

    # Create empty instances first time through.
    if request.method != :post
      @observation     = Observation.new
      @naming          = Naming.new
      @vote            = Vote.new
      @what            = '' # can't be nil else rails tries to call @name.name
      @names           = nil
      @valid_names     = nil
      @reason          = init_naming_reasons(@naming)
      @images          = []
      @good_images     = []
      @location_primer = Location.primer
      @name_primer     = Name.primer

      # Grab defaults for date and location from last observation the user
      # edited if it was less than an hour ago.
      last_observation = Observation.find_by_user_id(@user.id, :order => 'modified DESC')
      if last_observation && last_observation.modified > Time.now - 1.hour
        @observation.when     = last_observation.when
        @observation.where    = last_observation.where
        @observation.location = last_observation.location
      end

    else
      # Create everything roughly first.
      @observation = create_observation_object(params[:observation])
      @naming      = create_naming_object(params[:naming], @observation)
      @vote        = create_vote_object(params[:vote], @naming)
      @good_images = update_good_images(params[:good_images])
      @bad_images  = create_image_objects(params[:image], @observation, @good_images)

      # Validate name.
      given_name  = params[:name][:name].to_s           rescue ''
      chosen_name = params[:chosen_name][:name_id].to_s rescue ''
      (success, @what, @name, @names, @valid_names) =
        resolve_name(given_name, params[:approved_name], chosen_name)
      @naming.name = @name if @name

      # Validate objects.
      success = validate_observation(@observation) if success
      success = validate_naming(@naming) if @name && success
      success = validate_vote(@vote)     if @name && success
      success = false                    if @bad_images != []

      # If everything checks out save observation.
      if success &&
        (success = save_observation(@observation))
        flash_notice(:runtime_observation_success.t(:id => @observation.id))
        @observation.log(:log_observation_created)
      end

      # Once observation is saved we can save everything else.
      if success
        if @name
          create_naming_reasons(@naming, params[:reason])
          save_naming(@naming)
          @observation.reload
          @observation.change_vote(@naming, @vote.value)
        end
        attach_good_images(@observation, @good_images)

        # Check for notifications.
        if has_unshown_notifications?(@user, :naming)
          redirect_to(:action => 'show_notifications', :id => @observation.id)
        else
          redirect_to(:action => 'show_observation', :id => @observation.id)
        end

      # If anything failed reload the form.
      else
        @reason          = init_naming_reasons(@naming, params[:reason])
        @images          = @bad_images
        @new_image.when  = @observation.when
        @location_primer = Location.primer
        @name_primer     = Name.primer
      end
    end
  end

  # Form to edit an existing observation.
  # Linked from: left panel
  #
  # Inputs:
  #   params[:id]                       observation id
  #   params[:observation][...]         observation args
  #   params[:image][n][...]            image args
  #   params[:log_change][:checked]     log change in RSS feed?
  #
  # Outputs:
  #   @observation                      populated object
  #   @images                           array of images
  #   @licenses                         used for image license menu
  #   @new_image                        blank image object
  #   @good_images                      list of images already attached
  #
  def edit_observation # :prefetch: :norobots:
    pass_query_params
    @observation = Observation.find(params[:id], :include =>
                                    [:name, :images, :location])
    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(@observation.when)

    # Make sure user owns this observation!
    if !check_permission!(@observation.user_id)
      redirect_to(:action => 'show_observation', :id => @observation.id,
                  :params => query_params)

    # Initialize form.
    elsif request.method != :post
      @images      = []
      @good_images = @observation.images

    else
      # Update observation first.
      success = update_observation_object(@observation, params[:observation])

      # Now try to upload images.
      @good_images = update_good_images(params[:good_images])
      @bad_images  = create_image_objects(params[:image], @observation, @good_images)
      attach_good_images(@observation, @good_images)

      # Only save observation if there are changes.
      if success && @observation.changed?
        @observation.modified = Time.now
        if success = save_observation(@observation)
          flash_notice(:runtime_edit_observation_success.t(:id => @observation.id))
          touch = (params[:log_change][:checked] == '1' rescue false)
          @observation.log(:log_observation_updated, :touch => touch)
        end
      end

      # Redirect to show_observation on success.
      if success && @bad_images == []
        redirect_to(:action => 'show_observation', :id => @observation.id,
                  :params => query_params)

      # Reload form if anything failed.
      else
        @images = @bad_images
        @new_image.when = @observation.when
      end
    end
  end

  # Callback to destroy an observation (and associated namings, votes, etc.)
  # Linked from: show_observation
  # Inputs: params[:id] (observation)
  # Redirects to list_observations.
  def destroy_observation # :norobots:

    # All of this just to decide where to redirect after deleting observation.
    @observation = Observation.find(params[:id])
    next_state = nil
    if this_state = find_query(:Observation)
      this_state.current = @observation
      next_state = this_state.next
    end

    if !check_permission!(@observation.user_id)
      flash_error(:runtime_destroy_observation_denied.t(:id => @observation.id))
      redirect_to(:action => 'show_observation', :id => @observation.id,
                  :params => query_params(this_state))
    elsif !@observation.destroy
      flash_error(:runtime_destroy_observation_failed.t(:id => @observation.id))
      redirect_to(:action => 'show_observation', :id => @observation.id,
                  :params => query_params(this_state))
    else
      Transaction.delete_observation(:id => @observation)
      flash_notice(:runtime_destroy_observation_success.t(:id => params[:id]))
      if next_state
        redirect_to(:action => 'show_observation', :id => next_state.current_id,
                    :params => query_params(next_state))
      else
        redirect_to(:action => 'list_observations')
      end
    end
  end

  ##############################################################################
  #
  #  :section: Create and Edit Namings
  #
  ##############################################################################

  # Form to propose new naming for an observation.
  # Linked from: show_observation
  #
  # Inputs (post):
  #   params[:id]                       observation id
  #   params[:name][:name]              name
  #   params[:approved_name]            old name
  #   params[:chosen_name][:name_id]    name radio boxes
  #   params[:vote][...]                vote args
  #   params[:reason][n][...]           naming_reason args
  #   params[:was_js_on]                was form javascripty? ('yes' = true)
  #
  # Outputs:
  #   @observation, @naming, @vote      empty objects
  #   @what, @names, @valid_names       name validation
  #   @confidence_menu                  used for vote option menu
  #   @reason                           array of naming_reasons
  #
  def create_naming # :prefetch: :norobots:
    pass_query_params
    @observation = Observation.find(params[:id])
    @confidence_menu = translate_menu(Vote.confidence_menu)

    # Create empty instances first time through.
    if request.method != :post
      @naming      = Naming.new
      @vote        = Vote.new
      @what        = '' # can't be nil else rails tries to call @name.name
      @names       = nil
      @valid_names = nil
      @reason      = init_naming_reasons(@naming)

    else
      # Create everything roughly first.
      @naming = create_naming_object(params[:naming], @observation)
      @vote   = create_vote_object(params[:vote], @naming)

      # Validate name.
      given_name  = params[:name][:name].to_s           rescue ''
      chosen_name = params[:chosen_name][:name_id].to_s rescue ''
      (success, @what, @name, @names, @valid_names) =
        resolve_name(given_name, params[:approved_name], chosen_name)
      if !@name
        if !given_name.match(/\S/)
          @naming.errors.add(:name, :validate_naming_name_missing.t)
          flash_object_errors(@naming)
        end
        success = false
      end

      if success && @observation.name_been_proposed?(@name)
        flash_warning(:runtime_create_naming_already_proposed.t)
        success = false
      end

      # Validate objects.
      @naming.name = @name
      success = validate_naming(@naming) if success
      success = validate_vote(@vote)     if success

      if success
        # Save changes now that everything checks out.
        create_naming_reasons(@naming, params[:reason])
        save_naming(@naming)
        @observation.reload
        @observation.change_vote(@naming, @vote.value)
        @observation.log(:log_naming_created, :name => @naming.format_name)

        # Check for notifications.
        if has_unshown_notifications?(@user, :naming)
          redirect_to(:action => 'show_notifications', :id => @observation.id,
                      :params => query_params)
        else
          redirect_to(:action => 'show_observation', :id => @observation.id,
                      :params => query_params)
        end

      # If anything failed reload the form.
      else
        @reason = init_naming_reasons(@naming, params[:reason])
      end
    end
  end

  # Form to edit an existing naming for an observation.
  # Linked from: show_observation
  #
  # Inputs:
  #   params[:id]                       naming id
  #   params[:name][:name]              name
  #   params[:approved_name]            old name
  #   params[:chosen_name][:name_id]    name radio boxes
  #   params[:vote][...]                vote args
  #   params[:reason][n][...]           naming_reason args
  #   params[:was_js_on]                was form javascripty? ('yes' = true)
  #
  # Outputs:
  #   @observation, @naming, @vote      empty objects
  #   @what, @names, @valid_names       name validation
  #   @confidence_menu                  used for vote option menu
  #   @reason                           array of naming_reasons
  #
  def edit_naming # :prefetch: :norobots:
    pass_query_params
    @naming = Naming.find(params[:id])
    @observation = @naming.observation
    @vote = Vote.find(:first, :conditions =>
      ['naming_id = ? AND user_id = ?', @naming.id, @naming.user_id])
    @confidence_menu = translate_menu(Vote.confidence_menu)

    # Make sure user owns this naming!
    if !check_permission!(@naming.user_id)
      redirect_to(:action => 'show_observation', :id => @observation.id,
                  :params => query_params)

    # Initialize form.
    elsif request.method != :post
      @what        = @naming.text_name
      @names       = nil
      @valid_names = nil
      @reason      = init_naming_reasons(@naming)

    else
      # Validate name.
      given_name  = params[:name][:name].to_s           rescue ''
      chosen_name = params[:chosen_name][:name_id].to_s rescue ''
      (success, @what, @name, @names, @valid_names) =
        resolve_name(given_name, params[:approved_name], chosen_name)
      if !@name
        if !given_name.match(/\S/)
          @naming.errors.add(:name, :validate_naming_name_missing.t)
          flash_object_errors(@naming)
        end
        success = false
      end

      if success and (@naming.name != @name) and
         @observation.name_been_proposed?(@name)
        flash_warning(:runtime_edit_naming_someone_else.t)
        success = false
      end

      # Owner is not allowed to change a naming once it's been used by someone
      # else.  Instead I automatically clone it and make changes to the clone.
      # I assume there will be no validation problems since we're cloning
      # pre-existing valid objects.
      if success and !@naming.editable? and (@name != @naming.name)
        @naming = create_naming_object(params[:naming], @observation)
        @vote   = create_vote_object(params[:vote], @naming)

        # Validate objects.
        @naming.name = @name
        success = validate_naming(@naming) if success
        success = validate_vote(@vote)     if success

        # Save changes now that everything checks out.
        if success
          create_naming_reasons(@naming, params[:reason])
          save_naming(@naming)
          @observation.reload
          @observation.change_vote(@naming, @vote.value, @naming.user)
          @observation.log(:log_naming_created, :name => @naming.format_name)
          flash_warning 'Sorry, someone else has given this a positive vote,
            so we had to create a new Naming to accomodate your changes.'
        end

      # Owner is allowed to change the naming so long as no one else has used it.
      # They are also allowed to change the reasons even if others have used it.
      elsif success

        # If user's changed the name, it sorta invalidates any votes that
        # others might have cast prior to this.
        need_to_calc_consensus = false
        need_to_log_change = false
        if @name != @naming.name
          for vote in @naming.votes
            if vote.user_id != @user.id
              vote.destroy
            end
          end
          need_to_calc_consensus = true
          need_to_log_change = true
        end

        # Update reasons.
        create_naming_reasons(@naming, params[:reason])

        # Make changes to naming.
        success = update_naming_object(@naming, @name, need_to_log_change)

        # Save everything if it all checks out.
        if success
          # Only change vote if changed value.
          if (new_val = params[:vote][:value].to_i rescue nil) and
             (!@vote || @vote.value != new_val)
            @observation.change_vote(@naming, new_val)
            need_to_calc_consensus = false
          end
          if need_to_calc_consensus
            @observation.reload
            @observation.calc_consensus
          end
        end
      end

      # Redirect to observation on success, reload form if anything failed.
      if success
        redirect_to(:action => 'show_observation', :id => @observation.id,
                    :params => query_params)
      else
        @reason = init_naming_reasons(@naming, params[:reason])
      end
    end
  end

  # Callback to destroy a naming (and associated votes, etc.)
  # Linked from: show_observation
  # Inputs: params[:id] (observation)
  # Redirects back to show_observation.
  def destroy_naming # :norobots:
    pass_query_params
    @naming = Naming.find(params[:id])
    @observation = @naming.observation
    if !check_permission!(@naming.user_id)
      flash_error(:runtime_destroy_naming_denied.t(:id => @naming.id))
    elsif !@naming.deletable?
      flash_warning(:runtime_destroy_naming_someone_else.t)
    elsif !@naming.destroy
      flash_error(:runtime_destroy_naming_failed.t(:id => @naming.id))
    else
      Transaction.delete_naming(:id => @naming)
      flash_notice(:runtime_destroy_naming_success.t(:id => params[:id]))
    end
    redirect_to(:action => 'show_observation', :id => @observation.id,
                :params => query_params)
  end

  # I'm tired of tweaking show_observation to call calc_consensus for debugging.
  # I'll just leave this stupid action in and have it forward to show_observation.
  def recalc # :root: :norobots:
    pass_query_params
    id = params[:id]
    begin
      @observation = Observation.find(id)
      flash_notice(:observer_recalc_old_name.t(:name => @observation.name.display_name))
      text = @observation.calc_consensus(true)
      flash_notice text if !text.blank?
      flash_notice(:observer_recalc_new_name.t(:name => @observation.name.display_name))
    rescue => err
      flash_error(:observer_recalc_caught_error.t(:error => err))
    end
    # render(:text => '', :layout => true)
    redirect_to(:action => 'show_observation', :id => id,
                :params => query_params)
  end

  ##############################################################################
  #
  #  :section: Vote Stuff
  #
  ##############################################################################

  # Create vote if none exists; change vote if exists; delete vote if setting
  # value to -1 (owner of naming is not allowed to do this).
  # Linked from: (nowhere)
  # Inputs: params[]
  # Redirects to show_observation.
  def cast_vote # :norobots:
    pass_query_params
    naming = Naming.find(params[:id])
    observation = naming.observation
    value = params[:value].to_i
    observation.change_vote(naming, value)
    redirect_to(:action => 'show_observation', :id => observation.id,
                :params => query_params)
  end

  # Show breakdown of votes for a given naming.
  # Linked from: show_observation
  # Inputs: params[:id] (naming)
  # Outputs: @naming
  def show_votes # :nologin: :prefetch:
    pass_query_params
    @naming = find_or_goto_index(Naming, params[:id], :include => [:name, :votes])
  end

  # Refresh vote cache for all observations in the database.
  def refresh_vote_cache # :root: :norobots:
    if is_in_admin_mode?
      # Naming.refresh_vote_cache
      Observation.refresh_vote_cache
      flash_notice(:refresh_vote_cache.t)
      redirect_to(:action => 'list_rss_logs')
    end
  end

  ##############################################################################
  #
  #  :section: Reviewer Utilities
  #
  ##############################################################################

  # Form to compose email for the authors/reviewers.  Linked from show_<object>.
  # TODO: Use queued_email mechanism.
  def author_request # :norobots:
    pass_query_params
    @object = AbstractModel.find_object(params[:type], params[:id])
    if request.method == :post
      subject = params[:email][:subject] rescue ''
      content = params[:email][:content] rescue ''
      for receiver in (@object.authors + UserGroup.reviewers.users).uniq
        AccountMailer.deliver_author_request(@user, receiver, @object, subject, content)
      end
      flash_notice(:request_success.t)
      parent = @object.parent
      redirect_to(:controller => @object.show_controller,
                  :action => @object.show_action, :id => @object.id,
                  :params => query_params)
    end
  end

  # Form to adjust permissions for a user with respect to a project.
  # Linked from: show_(object) and author_request email
  # Inputs:
  #   params[:id]
  #   params[:type]
  #   params[:add]
  #   params[:remove]
  # Success:
  #   Redraws itself.
  # Failure:
  #   Renders show_name.
  #   Outputs: @name, @authors, @users
  def review_authors # :norobots:
    pass_query_params
    @object = AbstractModel.find_object(params[:type], params[:id])
    @authors = @object.authors
    parent = @object.parent
    if @authors.member?(@user) or @user.in_group?('reviewers')
      @users = User.all(:order => "login, name")
      new_author = params[:add] ?  User.find(params[:add]) : nil
      if new_author and not @authors.member?(new_author)
        @object.add_author(new_author)
        flash_notice("Added #{new_author.legal_name}")
        # Should send email as well
      end
      old_author = params[:remove] ? User.find(params[:remove]) : nil
      if old_author and @authors.member?(old_author)
        @object.remove_author(old_author)
        flash_notice("Removed #{old_author.legal_name}")
        # Should send email as well
      end
    else
      flash_error(:review_authors_denied.t)
      redirect_to(:controller => parent.show_controller,
                  :action => parent.show_action, :id => parent.id,
                  :params => query_params)
    end
  end

  # Callback to let reviewers change the export status of a Name from the
  # show_name page.
  def set_export_status # :norobots:
    pass_query_params
    id    = params[:id].to_s
    type  = params[:type].to_s
    value = params[:value].to_s
    model = type.camelize.constantize rescue nil
    if !is_reviewer?
      flash_error(:runtime_admin_only.t)
      redirect_back_or_default('/')
    elsif !model or
          !model.respond_to?(:column_names) or
          !model.column_names.include?('ok_for_export')
      flash_error(:runtime_invalid.t(:type => '"type"', :value => type))
      redirect_back_or_default('/')
    elsif !value.match(/^[01]$/)
      flash_error(:runtime_invalid.t(:type => '"value"', :value => value))
      redirect_back_or_default('/')
    elsif obj = find_or_goto_index(model, id)
      obj.ok_for_export = (value == '1')
      obj.save_without_our_callbacks
      redirect_to(:controller => obj.show_controller,
                  :action => obj.show_action, :id => id,
                  :params => query_params)
    end
  end

  ##############################################################################
  #
  #  :section: Notifications
  #
  ##############################################################################

  # Displays notifications related to a given naming and users.
  # Inputs: params[:naming], params[:observation]
  # Outputs:
  #   @notifications
  def show_notifications # :norobots:
    pass_query_params
    data = []
    if @observation = find_or_goto_index(Observation, params[:id])
      for q in QueuedEmail.find_all_by_flavor_and_to_user_id('QueuedEmail::NameTracking', @user.id)
        naming_id, notification_id, shown = q.get_integers([:naming, :notification, :shown])
        if shown.nil?
          notification = Notification.find(notification_id)
          if notification.note_template
            data.push([notification, Naming.find(naming_id)])
          end
          q.add_integer(:shown, 1)
        end
      end
      @data = data.sort_by { rand }
    end
  end

  # Lists notifications that the given user has created.
  # Inputs: none
  # Outputs:
  #   @notifications
  def list_notifications # :norobots:
    @notifications = Notification.find_all_by_user_id(@user.id, :order => :flavor)
  end

  ##############################################################################
  #
  #  :section: User support
  #
  ##############################################################################

  # User index, restricted to admins.
  def index_user # :nologin: :norobots:
    if !is_in_admin_mode? and
       !find_query(:User)
      flash_error(:runtime_search_has_expired.t)
      redirect_to(:action => 'list_rss_logs')
    else
      query = find_or_create_query(:User, :by => params[:by])
      show_selected_users(query, :id => params[:id], :always_index => true)
    end
  end

  # User index, restricted to admins.
  def users_by_name # :norobots:
    if !is_in_admin_mode?
      flash_error(:permission_denied.t)
      redirect_to(:action => 'list_rss_logs')
    else
      query = create_query(:User, :all, :by => :name)
      show_selected_users(query)
    end
  end

  # Display list of User's whose name, notes, etc. match a string pattern.
  def user_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) and
       (user = User.safe_find(pattern))
      redirect_to(:action => 'show_user', :id => user.id)
    else
      query = create_query(:User, :pattern_search, :pattern => pattern)
      show_selected_users(query)
    end
  end

  def show_selected_users(query, args={})
    store_query_in_session(query)
    @links ||= []
    args = {
      :action => 'list_users',
      :include => :user_groups,
      :matrix  => !is_in_admin_mode?,
    }.merge(args)

    # Add some alternate sorting criteria.
    if is_in_admin_mode?
      args[:sorting_links] = [
        ['id',         :sort_by_id.t],
        ['login',      :sort_by_login.t],
        ['name',       :sort_by_name.t],
        ['created',    :sort_by_created.t],
        ['modified',   :sort_by_modified.t],
        ['last_login', :sort_by_last_login.t],
      ]
    else
      args[:sorting_links] = [
        ['login',      :sort_by_login.t],
        ['name',       :sort_by_name.t],
        ['created',    :sort_by_created.t],
        ['location',   :sort_by_location.t],
        ['contribution', :sort_by_contribution.t],
      ]
    end

    # Paginate by "correct" letter.
    if (query.params[:by] == 'login') or
       (query.params[:by] == 'reverse_login')
      args[:letters] = 'users.login'
    else
      args[:letters] = 'users.name'
    end

    show_index_of_objects(query, args)
  end

  # users_by_contribution.rhtml
  def users_by_contribution # :nologin: :norobots:
    SiteData.new
    @users = User.all(:order => "contribution desc, name, login")
  end

  # show_user.rhtml
  def show_user # :nologin: :prefetch:
    store_location
    id = params[:id]
    if @show_user = find_or_goto_index(User, id, :include => :location)
      @user_data = SiteData.new.get_user_data(id)
      query = Query.lookup(:Observation, :by_user, :user => @show_user,
                           :by => :thumbnail_quality)
      @observations = query.results(:limit => 6, :include => :thumb_image)
    end
  end

  # Go to next user: redirects to show_user.
  def next_user # :norobots:
    redirect_to_next_object(:next, User, params[:id])
  end

  # Go to previous user: redirects to show_user.
  def prev_user # :norobots:
    redirect_to_next_object(:prev, User, params[:id])
  end

  # Admin util linked from show_user page that lets admin add or change bonuses
  # for a given user.
  def change_user_bonuses # :root: :norobots:
    @user2 = User.find(params[:id])
    if is_in_admin_mode?
      if request.method != :post

        # Reformat bonuses as string for editing, one entry per line.
        @val = ''
        if @user2.bonuses
          @val = @user2.bonuses.map { |points, reason|
            sprintf('%-6d %s', points, reason.gsub(/\s+/, ' '))
          }.join("\n")
        end

      else
        # Parse new set of values.
        @val = params[:val]
        line_num = 0
        errors = false
        bonuses = []
        for line in @val.split("\n")
          line_num += 1
          if match = line.match(/^\s*(\d+)\s*(\S.*\S)\s*$/)
            bonuses.push([match[1].to_i, match[2].to_s])
          else
            flash_error("Syntax error on line #{line_num}.")
            errors = true
          end
        end

        # Success: update user's contribution.
        if !errors
          contrib = @user2.contribution.to_i

          # Subtract old bonuses.
          if @user2.bonuses
            for points, reason in @user2.bonuses
              contrib -= points
            end
          end

          # Add new bonuses
          for points, reason in bonuses
            contrib += points
          end

          # Update database.
          @user2.bonuses      = bonuses
          @user2.contribution = contrib
          @user2.save
          Transaction.put_user(
            :id               => @user2,
            :set_bonuses      => bonuses,
            :set_contribution => contrib
          )

          redirect_to(:action => 'show_user', :id => @user2.id)
        end
      end
    else
      redirect_to(:action => 'show_user', :id => @user2.id)
    end
  end

  ##############################################################################
  #
  #  :section: Site Stats
  #
  ##############################################################################

  # show_site_stats.rhtml
  def show_site_stats # :nologin: :norobots:
    store_location
    @site_data = SiteData.new.get_site_data

    # Add some extra stats.
    @site_data[:observed_taxa] = Name.connection.select_value %(
      SELECT COUNT(DISTINCT name_id) FROM observations
    )
    @site_data[:listed_taxa] = Name.connection.select_value %(
      SELECT COUNT(*) FROM names
    )

    # Get the last six observations whose thumbnails are highly rated.
    query = Query.lookup(:Observation, :all, :by => :modified,
                         :where => 'images.vote_cache >= 3',
                         :join => :'images.thumb_image')
    @observations = query.results(:limit => 6, :include => :thumb_image)
  end

  # server_status.rhtml
  # Restricted to the admin user
  # Reports on the health of the system
  def server_status # :root: :norobots:
    if is_in_admin_mode?
      case params[:commit]
      when :system_status_gc.l
        ObjectSpace.garbage_collect
        flash_notice("Collected garbage")
      when :system_status_clear_caches.l
        clear_browser_status_cache
        String.clear_textile_cache
        flash_notice("Cleared caches")
      end
      @cache_size = browser_status_cache_size
      @textile_name_size = String.textile_name_size
    else
      redirect_to(:action => 'list_observations')
    end
  end

  ##############################################################################
  #
  #  :section: Email Stuff
  #
  ##############################################################################

  # email_features.rhtml
  # Restricted to the admin user
  def email_features # :root: :norobots:
    if !is_in_admin_mode?
      flash_error(:permission_denied.t)
      redirect_to(:action => 'list_rss_logs')
    else
      @users = User.all(:conditions => "email_general_feature=1 and verified is not null")
      if request.method == :post
        for user in @users
          QueuedEmail::Feature.create_email(user, params[:feature_email][:content])
        end
        flash_notice(:send_feature_email_success.t)
        redirect_to(:action => 'users_by_name')
      end
    end
  end

  def ask_webmaster_question # :nologin: :norobots:
    @email = params[:user][:email] if params[:user]
    @content = params[:question][:content] if params[:question]
    @email_error = false
    if request.method != :post
      @email = @user.email if @user
    elsif @email.blank? or @email.index('@').nil?
      flash_error (:runtime_ask_webmaster_need_address.t)
      @email_error = true
    elsif /http:/ =~ @content or /<[\/a-zA-Z]+>/ =~ @content
      flash_error(:runtime_ask_webmaster_antispam.t)
    elsif @content.blank?
      flash_error(:runtime_ask_webmaster_need_content.t)
    else
      AccountMailer.deliver_webmaster_question(@email, @content)
      flash_notice(:runtime_ask_webmaster_success.t)
      redirect_to(:action => "list_rss_logs")
    end
  end

  def ask_user_question # :norobots:
    @target = User.find(params[:id])
    if email_question(@user) &&
       (request.method == :post)
      subject = params[:email][:subject]
      content = params[:email][:content]
      AccountMailer.deliver_user_question(@user, @target, subject, content)
      flash_notice(:runtime_ask_user_question_success.t)
      redirect_to(:action => 'show_user', :id => @target.id)
    end
  end

  def ask_observation_question # :norobots:
    @observation = Observation.find(params[:id])
    if email_question(@observation) &&
       (request.method == :post)
      question = params[:question][:content]
      AccountMailer.deliver_observation_question(@user, @observation, question)
      flash_notice(:runtime_ask_observation_question_success.t)
      redirect_to(:action => 'show_observation', :id => @observation.id,
                  :params => query_params)
    end
  end

  def commercial_inquiry # :norobots:
    @image = Image.find(params[:id])
    if email_question(@image, :email_general_commercial) &&
       (request.method == :post)
      commercial_inquiry = params[:commercial_inquiry][:content]
      AccountMailer.deliver_commercial_inquiry(@user, @image, commercial_inquiry)
      flash_notice(:runtime_commercial_inquiry_success.t)
      redirect_to(:controller => 'image', :action => 'show_image',
                  :id => @image.id, :params => query_params)
    end
  end

  def email_question(target, method=:email_general_question)
    result = false
    user = target.is_a?(User) ? target : target.user
    if user.send(method)
      result = true
    else
      flash_error(:permission_denied.t)
      redirect_to(:controller => target.show_controller,
                  :action => target.show_action, :id => target.id,
                  :params => query_params)
    end
    return result
  end

  ##############################################################################
  #
  #  :section: RSS support
  #
  ##############################################################################

  # Displays matrix of selected RssLog's (based on current Query).
  def index_rss_log # :nologin: :norobots:
    if request.method == :post
      types = RssLog.all_types.select {|type| params["show_#{type}"] == '1'}
      types = 'all' if types.length == RssLog.all_types.length
      types = 'none' if types.empty?
      types = types.map(&:to_s).join(' ')
      query = find_or_create_query(:RssLog, :type => types)
    elsif !params[:type].blank?
      types = params[:type].split & (['all'] + RssLog.all_types)
      query = find_or_create_query(:RssLog, :type => types.join(' '))
    else
      query = find_query(:RssLog)
      query ||= create_query(:RssLog, :all,
                             :type => @user ? @user.default_rss_type : 'all')
    end
    show_selected_rss_logs(query, :id => params[:id], :always_index => true)
  end

  # This is the main site index.  Nice how it's buried way down here, huh?
  def list_rss_logs # :nologin:
    query = create_query(:RssLog, :all,
                         :type => @user ? @user.default_rss_type : 'all')
    show_selected_rss_logs(query)
  end

  # Show selected search results as a matrix with 'list_rss_logs' template.
  def show_selected_rss_logs(query, args={})
    store_query_in_session(query)
    set_query_params(query)

    args = {
      :action => 'list_rss_logs',
      :matrix => true,
      :include => {
        :observation  => [:location, :name, :thumb_image, :user],
        :name         => :user,
        :species_list => [:location, :user],
      },
    }.merge(args)

    @types = query.params[:type].to_s.split.sort
    @links = []

    # Let the user make this their default and fine tune.
    if @user
      if params[:make_default] == '1'
        @user.default_rss_type = @types.join(' ')
        @user.save_without_our_callbacks
      elsif @user.default_rss_type.to_s.split.sort != @types
        @links << [:rss_make_default.t, { :action => 'index_rss_log',
                   :make_default => 1, :params => query_params }]
      end
    end

    show_index_of_objects(query, args)
  end

  # Show a single RssLog.
  def show_rss_log # :nologin:
    pass_query_params
    store_location
    @rss_log = find_or_goto_index(RssLog, params['id'])
  end

  # Go to next RssLog: redirects to show_<object>.
  def next_rss_log # :norobots:
    redirect_to_next_object(:next, RssLog, params[:id])
  end

  # Go to previous RssLog: redirects to show_<object>.
  def prev_rss_log # :norobots:
    redirect_to_next_object(:prev, RssLog, params[:id])
  end

  # this is the site's rss feed.
  def rss # :nologin:
    headers["Content-Type"] = "application/xml"
    @logs = RssLog.all(:conditions => "datediff(now(), modified) <= 31",
                       :order => "modified desc", :limit => 100, :include => [
                         :name, :species_list, { :observation  => :name },
                       ])
    render(:action => "rss", :layout => false)
  end

  ##############################################################################
  #
  #  :section: create and edit helpers
  #
  #    create_observation_object(...)     create rough first-drafts.
  #    create_naming_object(...)
  #    create_vote_object(...)
  #
  #    validate_observation(...)          validate first-drafts.
  #    validate_naming(...)
  #    validate_vote(...)
  #
  #    save_observation(...)              Save validated objects.
  #    save_naming(...)
  #
  #    update_observation_object(...)     Update and save existing objects.
  #    update_naming_object(...)
  #
  #    init_naming_reasons(...)           Handle naming reasons.
  #    create_naming_reasons(...)
  #
  #    init_image()                       Handle image uploads.
  #    create_image_objects(...)
  #    update_good_images(...)
  #    attach_good_images(...)
  #
  #    resolve_name(...)                  Validate name.
  #
  ##############################################################################

  # Roughly create observation object.  Will validate and save later once we're sure everything is correct.
  # INPUT: params[:observation] (and @user)
  # OUTPUT: new observation
  def create_observation_object(args)
    now = Time.now
    observation = Observation.new(args)
    observation.created  = now
    observation.modified = now
    observation.user     = @user
    observation.name     = Name.unknown
    return observation
  end

  # Roughly create naming object.  Will validate and save later once we're sure everything is correct.
  # INPUT: params[:naming], observation (and @user)
  # OUTPUT: new naming
  def create_naming_object(args, observation)
    now = Time.now
    naming = Naming.new(args)
    naming.created     = now
    naming.modified    = now
    naming.user        = @user
    naming.observation = observation
    return naming
  end

  # Roughly create vote object.  Will validate and save later once we're sure everything is correct.
  # INPUT: params[:vote], naming (and @user)
  # OUTPUT: new vote
  def create_vote_object(args, naming)
    now = Time.now
    vote = Vote.new(args)
    vote.created     = now
    vote.modified    = now
    vote.user        = @user
    vote.naming      = naming
    vote.observation = naming.observation
    return vote
  end

  # Make sure there are no errors in observation.
  def validate_observation(observation)
    success = true
    if !observation.valid?
      flash_object_errors(observation)
      success = false
    end
    return success
  end

  # Make sure there are no errors in naming.
  def validate_naming(naming)
    success = true
    if !naming.valid?
      flash_object_errors(naming)
      success = false
    end
    return success
  end

  # Make sure there are no errors in vote.
  def validate_vote(vote)
    success = true
    if !vote.valid?
      flash_object_errors(vote)
      success = false
    end
    return success
  end

  # Save observation now that everything is created successfully.
  def save_observation(observation)
    success = true
    args = {}
    if observation.new_record?
      args[:method] = 'post'
      args[:action] = 'observation'
      args[:date]   = observation.when
      if observation.location_id
        args[:location] = observation.location
      else
        args[:location] = observation.where
      end
      args[:notes]     = observation.notes.to_s
      args[:specimen]  = !!observation.specimen
      args[:thumbnail] = observation.thumb_image_id.to_i
      args[:is_collection_location] = observation.is_collection_location
    else
      args[:method]   = 'put'
      args[:action]   = 'observation'
      args[:set_date] = observation.when                if observation.when_changed?
      if observation.where_changed? or observation.location_id_changed?
        if observation.location_id
          args[:set_location] = observation.location
        else
          args[:set_location] = observation.where
        end
      end
      args[:set_notes]     = observation.notes               if observation.notes_changed?
      args[:set_specimen]  = observation.specimen            if observation.specimen_changed?
      args[:set_thumbnail] = observation.thumb_image_id.to_i if observation.thumb_image_id_changed?
      args[:set_is_collection_location] = observation.is_collection_location
    end
    if observation.save
      args[:id] = observation
      Transaction.create(args)
    else
      flash_error(:runtime_no_save_observation.t)
      flash_object_errors(observation)
      success = false
    end
    return success
  end

  # Update observation, check if valid.
  def update_observation_object(observation, args)
    success = true
    if !observation.update_attributes(args)
      flash_object_errors(observation)
      success = false
    end
    return success
  end

  # Save naming now that everything is created successfully.
  def save_naming(naming)
    success = true
    args = {}
    if naming.new_record?
      args[:method]      = 'post'
      args[:action]      = 'naming'
      args[:name]        = naming.name
      args[:observation] = naming.observation
    else
      args[:method]          = 'put'
      args[:action]          = 'naming'
      args[:set_name]        = naming.name        if naming.name_id_changed?
      args[:set_observation] = naming.observation if naming.observation_id_changed?
    end
    if naming.save
      args[:id] = naming
      Transaction.create(args)
      flash_notice(:runtime_naming_created.t)
    else
      flash_error(:runtime_no_save_naming.t)
      flash_object_errors(naming)
      success = false
    end
    return success
  end

  # Update naming and log changes.
  def update_naming_object(naming, name, log)
    naming.name = name
    naming.save
    flash_notice(:runtime_naming_updated.t)
    naming.observation.log(:log_naming_updated, :name => naming.format_name,
                           :touch => log)

    # Always tell Transaction to change reasons, even if no changes.
    args = {:id => naming}
    args[:set_name] = name
    for reason in naming.get_reasons.select(&:used?)
      args["set_reason_#{reason.num}".to_sym] = reason.notes
    end
    Transaction.put_naming(args)

    return true
  end

  # Initialize the naming_reasons objects used by the naming form.
  def init_naming_reasons(naming, args=nil)
    result = {}
    for reason in naming.get_reasons
      num = reason.num

      # Use naming's reasons by default.
      result[num] = reason

      # Override with values in params.
      if args
        if x = args[num.to_s]
          check = x[:check]
          notes = x[:notes]
          # Reason is "used" if checked or notes non-empty.
          if (check == '1') or
             !notes.blank?
            reason.notes = notes
          elsif
            reason.delete
          end
        else
          reason.delete
        end
      end

    end
    return result
  end

  # Creates all the reasons for a naming.
  # Gets checkboxes and notes from params[:reason].
  def create_naming_reasons(naming, args=nil)
    args ||= {}

    # Need to know if JS was on because it changes how we deal with unchecked
    # reasons that have notes: if JS is off these are considered valid, if JS
    # was on the notes are hidden when the box is unchecked thus it is invalid.
    was_js_on = (params[:was_js_on] == 'yes')

    for reason in naming.get_reasons
      num = reason.num
      if x = args[num.to_s]
        check = x[:check]
        notes = x[:notes]
        if (check == '1') or
           (!was_js_on && !notes.blank?)
          reason.notes = notes
        else
          reason.delete
        end
      else
        reason.delete
      end
    end
  end

  # Attempt to upload any images.  We will attach them to the observation
  # later, assuming we can create it.  Problem is if anything goes wrong, we
  # cannot repopulate the image forms (security issue associated with giving
  # file upload fields default values).  So we need to do this immediately,
  # even if observation creation fails.  Keep a list of images we've downloaded
  # successfully in @good_images (stored in hidden form field).
  #
  # INPUT: params[:image], observation, good_images (and @user)
  # OUTPUT: list of images we couldn't create
  def create_image_objects(args, observation, good_images)
    bad_images = []
    if args
      i = 0
      while args2 = args[i.to_s]
        if !(upload = args2[:image]).blank?
          name = upload.full_original_filename if upload.respond_to?(:full_original_filename)
          image = Image.new(args2)
          image.created = Time.now
          image.modified = image.created
          # If image.when is 1950 it means user never saw the form field, so we should use default instead.
          image.when = observation.when if image.when.year == 1950
          image.user = @user
          if !image.save
            bad_images.push(image)
            flash_object_errors(image)
          elsif !image.process_image
            logger.error('Unable to upload image')
            flash_notice(:runtime_no_upload_image.t(:name => (name ? "'#{name}'" : "##{image.id}")))
            bad_images.push(image)
            flash_object_errors(image)
          else
            Transaction.post_image(
              :id               => image,
              :date             => image.when,
              :notes            => image.notes.to_s,
              :copyright_holder => image.copyright_holder.to_s,
              :license          => image.license || 0
            )
            flash_notice(:runtime_image_uploaded.t(:name => (name ? "'#{name}'" : "##{image.id}")))
            good_images.push(image)
            if observation.thumb_image_id == -i
              observation.thumb_image_id = image.id
            end
          end
        end
        i += 1
      end
    end
    if observation.thumb_image_id && observation.thumb_image_id.to_i <= 0
      observation.thumb_image_id = nil
    end
    return bad_images
  end

  # List of images that we've successfully downloaded, but which haven't been
  # attached to the observation yet.  Also supports some mininal editing.
  # INPUT: params[:good_images] (also looks at params[:image_<id>_notes])
  # OUTPUT: list of images
  def update_good_images(arg)
    # Get list of images first.
    images = (arg || '').split(' ').map do |id|
      Image.find(id.to_i)
    end

    # Now check for edits.
    for image in images
      notes = params["image_#{image.id}_notes"]
      if image.notes != notes
        image.notes = notes
        image.modified = Time.now
        args = { :id => image }
        args[:set_date]             = image.when             if image.when_changed?
        args[:set_notes]            = image.notes            if image.notes_changed?
        args[:set_copyright_holder] = image.copyright_holder if image.copyright_holder_changed?
        args[:set_license]          = image.license          if image.license_id_changed?
        if !image.save
          flash_object_errors(image)
        else
          Transaction.put_image(args)
          flash_notice(:runtime_image_updated_notes.t(:id => image.id))
        end
      end
    end

    return images
  end

  # Now that the observation has been successfully created, we can attach
  # any images that were downloaded earlier
  def attach_good_images(observation, images)
    if images
      for image in images
        if !observation.image_ids.include?(image.id)
          observation.add_image(image)
          observation.log_create_image(image)
        end
      end
    end
  end

  # Initialize image for the dynamic image form at the bottom.
  def init_image(default_date)
    image = Image.new
    image.when             = default_date
    image.license          = @user.license
    image.copyright_holder = @user.legal_name
    return image
  end

  # Resolves the name using these heuristics:
  #   First time through:
  #     Only 'what' will be filled in.
  #     Prompts the user if not found.
  #     Gives user a list of options if matches more than one. ('names')
  #     Gives user a list of options if deprecated. ('valid_names')
  #   Second time through:
  #     'what' is a new string if user typed new name, else same as old 'what'
  #     'approved_name' is old 'what'
  #     'chosen_name' hash on name.id: radio buttons
  #     Uses the name chosen from the radio buttons first.
  #     If 'what' has changed, then go back to "First time through" above.
  #     Else 'what' has been approved, create it if necessary.
  #
  # INPUTS:
  #   what            params[:name][:name]            Text field.
  #   approved_name   params[:approved_name]          Last name user entered.
  #   chosen_name     params[:chosen_name][:name_id]  Name id from radio boxes.
  #   (@user -- might be used by one or more things)
  #
  # RETURNS:
  #   success       true: okay to use name; false: user needs to approve name.
  #   name          Name object if it resolved without reservations.
  #   names         List of choices if name matched multiple objects.
  #   valid_names   List of choices if name is deprecated.
  #
  def resolve_name(what, approved_name, chosen_name)
    success    = true
    name       = nil
    names      = nil
    valid_name = nil

    what2 = what.to_s.gsub('_', ' ').strip_squeeze
    if !what2.blank? && !Name.names_for_unknown.member?(what2.downcase)
      success = false

      ignore_approved_name = false
      # Has user chosen among multiple matching names or among multiple approved names?
      if !chosen_name.blank?
        names = [Name.find(chosen_name)]
        # This tells it to check if this name is deprecated below EVEN IF the user didn't change the what field.
        # This will solve the problem of multiple matching deprecated names discussed below.
        ignore_approved_name = true
      else
        # Look up name: can return zero (unrecognized), one (unambiguous match),
        # or many (multiple authors match).
        names = Name.find_names(what2)
      end

      # Create temporary name object for it.  (This will not save anything
      # EXCEPT in the case of user supplying author for existing name that
      # has no author.)
      if names.empty? and
         (name = create_needed_names(approved_name, what2))
        names << name
      end

      # No matches -- suggest some correct names to make Debbie happy.
      if names.empty?
        valid_names = guess_correct_name(what2)
        @suggest_corrections = true

      # Only one match (or we just created an approved new name).
      elsif names.length == 1
        target_name = names.first
        # Single matching name.  Check if it's deprecated.
        if target_name.deprecated and (ignore_approved_name or (approved_name != what))
          # User has not explicitly approved the deprecated name: get list of
          # valid synonyms.  Will display them for user to choose among.
          valid_names = target_name.approved_synonyms
        else
          # User has selected an unambiguous, accepted name... or they have
          # chosen or approved of their choice.  Either way, go with it.
          name = target_name
          # Fill in author, just in case user has chosen between two authors.
          # If the form fails for some other reason and we don't do this, it
          # will ask the user to choose between the authors *again* later.
          what = name.search_name
          # (This is the only way to get out of here with success.)
          success = true
        end

      # Multiple matches.
      elsif names.length > 1
        if names.reject {|n| n.deprecated}.empty?
          # Multiple matches, all of which are deprecated.  Check if they all
          # have the same set of approved names.  Pain in the butt, but otherwise
          # can get stuck choosing between Helvella infula Fr. and H. infula
          # Schaeff. without anyone mentioning that both are deprecated by
          # Gyromitra infula.
          valid_set = Set.new()
          for n in names
            valid_set.merge(n.approved_synonyms)
          end
          valid_names = valid_set.sort_by(&:search_name)
        end
      end
    end

    return [success, what, name, names, valid_names]
  end

  ##############################################################################
  #
  #  :stopdoc: These are for backwards compatibility.
  #
  ##############################################################################

  def rewrite_url(obj, old_method, new_method)
    url = request.request_uri
    if url.match(/\?/)
      base = url.sub(/\?.*/, '')
      args = url.sub(/^[^?]*/, '')
    elsif url.match(/\/\d+$/)
      base = url.sub(/\/\d+$/, '')
      args = url.sub(/.*(\/\d+)$/, '\1')
    else
      base = url
      args = ''
    end
    base.sub!(/\/\w+\/\w+$/, '')
    return "#{base}/#{obj}/#{new_method}#{args}"
  end

  # Create redirection methods for all of the actions we've moved out
  # of this controller.  They just rewrite the URL, replacing the
  # controller with the new one (and optionally renaming the action).
  def self.action_has_moved(obj, old_method, new_method=nil)
    new_method = old_method if !new_method
    class_eval(<<-EOS)
      def #{old_method}
        redirect_to rewrite_url('#{obj}', '#{old_method}', '#{new_method}')
      end
    EOS
  end

  action_has_moved 'comment', 'add_comment'
  action_has_moved 'comment', 'destroy_comment'
  action_has_moved 'comment', 'edit_comment'
  action_has_moved 'comment', 'list_comments'
  action_has_moved 'comment', 'show_comment'
  action_has_moved 'comment', 'show_comments_for_user'

  action_has_moved 'image', 'add_image'
  action_has_moved 'image', 'destroy_image'
  action_has_moved 'image', 'edit_image'
  action_has_moved 'image', 'license_updater'
  action_has_moved 'image', 'list_images'
  action_has_moved 'image', 'next_image'
  action_has_moved 'image', 'prev_image'
  action_has_moved 'image', 'remove_images'
  action_has_moved 'image', 'reuse_image'
  action_has_moved 'image', 'show_image'

  action_has_moved 'name', 'approve_name'
  action_has_moved 'name', 'bulk_name_edit'
  action_has_moved 'name', 'change_synonyms'
  action_has_moved 'name', 'deprecate_name'
  action_has_moved 'name', 'edit_name'
  action_has_moved 'name', 'map'
  action_has_moved 'name', 'observation_index'
  action_has_moved 'name', 'show_name'
  action_has_moved 'name', 'show_past_name'

  action_has_moved 'observer', 'show_user_observations', 'observations_by_user'

  action_has_moved 'species_list', 'add_observation_to_species_list'
  action_has_moved 'species_list', 'create_species_list'
  action_has_moved 'species_list', 'destroy_species_list'
  action_has_moved 'species_list', 'edit_species_list'
  action_has_moved 'species_list', 'list_species_lists'
  action_has_moved 'species_list', 'manage_species_lists'
  action_has_moved 'species_list', 'remove_observation_from_species_list'
  action_has_moved 'species_list', 'show_species_list'
  action_has_moved 'species_list', 'species_lists_by_title'
  action_has_moved 'species_list', 'upload_species_list'
end

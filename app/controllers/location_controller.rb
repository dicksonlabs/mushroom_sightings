#
#  = Location Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
################################################################################

class LocationController < ApplicationController
  include DescriptionControllerHelpers

  before_filter :login_required, :except => [
    :advanced_search,
    :index_location,
    :index_location_description,
    :list_location_descriptions,
    :list_locations,
    :location_descriptions_by_author,
    :location_descriptions_by_editor,
    :location_search,
    :locations_by_editor,
    :locations_by_user,
    :map_locations,
    :next_location,
    :prev_location,
    :next_location_description,
    :prev_location_description,
    :show_location,
    :show_location_description,
    :show_past_location,
    :show_past_location_description,
  ]

  before_filter :disable_link_prefetching, :except => [
    :create_location,
    :create_location_description,
    :edit_location,
    :edit_location_description,
    :show_location,
    :show_location_description,
    :show_past_location,
    :show_past_location_description,
  ]

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  # Displays a list of selected locations, based on current Query.
  def index_location # :nologin: :norobots:
    query = find_or_create_query(:Location, :by => params[:by])
    show_selected_locations(query, :id => params[:id], :always_index => true)
  end

  # Displays a list of all locations.
  def list_locations # :nologin:
    query = create_query(:Location, :all, :by => :name)
    show_selected_locations(query, :undef_by_frequency => true)
  end

  # Display list of locations that a given user is author on.
  def locations_by_user # :nologin: :norobots:
    user = User.find(params[:id])
    @error = :runtime_locations_by_user_error.t(:user => user.legal_name)
    query = create_query(:Location, :by_user, :user => user)
    show_selected_locations(query, :undef_by_frequency => true)
  end

  # Display list of locations that a given user is editor on.
  def locations_by_editor # :nologin: :norobots:
    user = User.find(params[:id])
    @error = :runtime_locations_by_editor_error.t(:user => user.legal_name)
    query = create_query(:Location, :by_editor, :user => user)
    show_selected_locations(query)
  end

  # Displays a list of locations matching a given string.
  def location_search # :nologin: :norobots:
    query = create_query(:Location, :pattern_search, :pattern => params[:pattern].to_s)
    show_selected_locations(query, :undef_by_frequency => true)
  end

  # Displays matrix of advanced search results.
  def advanced_search # :nologin: :norobots:
    begin
      query = find_query(:Location)
      show_selected_locations(query, :undef_by_frequency => true)
    rescue => err
      flash_error(err)
      redirect_to(:controller => 'observer', :action => 'advanced_search_form')
    end
  end

  # Show selected search results as a list with 'list_locations' template.
  def show_selected_locations(query, args={})
    @links ||= []
    args[:letters] = 'locations.search_name'
    args[:link_all_sorts] = args[:undef_by_frequency]

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name',    :sort_by_name.t],
      ['created', :sort_by_created.t],
      [(query.flavor == :by_rss_log ? 'rss_log' : 'modified'),
                  :sort_by_modified.t],
    ]

    # Add "show observations" link if this query can be coerced into an
    # observation query.
    if query.is_coercable?(:Observation)
      @links << [:show_objects.t(:type => :observation), {
                  :controller => 'observer',
                  :action => 'index_observation',
                  :params => query_params(query),
                }]
    end

    # Add "show descriptions" link if this query can be coerced into an
    # observation query.
    if query.is_coercable?(:LocationDescription)
      @links << [:show_objects.t(:type => :description), {
                  :action => 'index_location_description',
                  :params => query_params(query),
                }]
    end

    # Get matching *undefined* locations.
    if query2 = coerce_query_for_undefined_locations(query)
      select_args = {
        :group => 'observations.where',
        :select => 'observations.where AS w, COUNT(observations.id) AS c',
      }
      if args[:undef_by_frequency]
        select_args[:order] = 'c DESC'
        # (This tells it to say "by name" and "by frequency" by the subtitles.
        # If user has explicitly selected the order, then this is disabled.)
        @default_orders = true
      end
      @undef_pages = paginate_letters(:letter2, :page2, 50)
      @undef_data = query2.select_rows(select_args)
      @undef_pages.used_letters = @undef_data.map {|row| row[0][0,1]}.uniq
      if (letter = params[:letter2].to_s.downcase) != ''
        @undef_data = @undef_data.select {|row| row[0][0,1].downcase == letter}
      end
      @undef_pages.num_total = @undef_data.length
      @undef_data = @undef_data[@undef_pages.from..@undef_pages.to]
    else
      @undef_pages = nil
      @undef_data = nil
    end

    # Paginate the defined locations using the usual helper.   
    args[:always_index] = (@undef_pages && @undef_pages.num_total > 0)
    args[:action] = 'list_locations'
    show_index_of_objects(query, args)
  end

  # Map results of a search or index.
  def map_locations # :nologin: :norobots:
    query = find_or_create_query(:Location)
    @title = query.flavor == :all ? :map_locations_global_map.t :
                             :map_locations_title.t(:locations => query.title)
    @locations = query.results
  end

  # Try to turn this into a query on observations.where instead.
  # Yes, still a kludge, but a little better than tweaking SQL by hand...
  def coerce_query_for_undefined_locations(query)
    model  = :Observation
    flavor = query.flavor
    args   = query.params.dup
    result = nil

    # Select only observations with undefined location.
    if !args[:where]
      args[:where] = []
    elsif !args[:where].is_a?(Array)
      args[:where] = [args[:where]]
    end
    args[:where] << 'observations.where IS NOT NULL'

    # "By name" means something different to observation.
    if args[:by].blank? or
       (args[:by] == 'name')
      args[:by] = 'where'
    end

    case query.flavor

    # These are okay as-is.
    when :all, :by_user
      true

    # Clearly all observations have an observation!
    when :with_observations,
         :with_observations_by_user
      flavor = :all

    # Temporarily kludge in pattern search the old way.
    when :pattern_search
      flavor = :all
      search = query.google_parse(args[:pattern])
      args[:where] += query.google_conditions(search, 'observations.where')
      args.delete(:pattern)

    # Simple coercions.
    when :with_observations_in_set
      flavor = :in_set
    when :with_observations_in_species_list
      flavor = :in_species_list
    when :with_observations_of_children
      flavor = :of_children
    when :with_observations_of_name
      flavor = :of_name

    # None of the rest make sense.
    else
      flavor = nil
    end

    # Create query if okay.  (Still need to tweak select and group clauses.)
    if flavor
      result = create_query(model, flavor, args)

      # Also make sure it doesn't reference locations anywhere.  This would
      # presumably be the result of customization of one of the above flavors.
      if result.query.match(/\Wlocations\./)
        result = nil
      end
    end

    return result
  end

  ################################################################################
  #
  #  :section: Description Searches and Indexes
  #
  ################################################################################

  # Displays a list of selected locations, based on current Query.
  def index_location_description # :nologin: :norobots:
    query = find_or_create_query(:LocationDescription, :by => params[:by])
    show_selected_location_descriptions(query, :id => params[:id],
                                        :always_index => true)
  end

  # Displays a list of all location_descriptions.
  def list_location_descriptions # :nologin:
    query = create_query(:LocationDescription, :all, :by => :name)
    show_selected_location_descriptions(query)
  end

  # Display list of location_descriptions that a given user is author on.
  def location_descriptions_by_author # :nologin: :norobots:
    user = User.find(params[:id])
    @error = :runtime_location_descriptions_by_author_error.
               t(:user => user.legal_name)
    query = create_query(:LocationDescription, :by_author, :user => user)
    show_selected_location_descriptions(query)
  end

  # Display list of location_descriptions that a given user is editor on.
  def location_descriptions_by_editor # :nologin: :norobots:
    user = User.find(params[:id])
    @error = :runtime_location_descriptions_by_editor_error.
               t(:user => user.legal_name)
    query = create_query(:LocationDescription, :by_editor, :user => user)
    show_selected_location_descriptions(query)
  end

  # Show selected search results as a list with 'list_locations' template.
  def show_selected_location_descriptions(query, args={})
    store_query_in_session(query)
    @links ||= []
    args = { :action => 'list_location_descriptions',
             :num_per_page => 50 }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name',     :sort_by_name.t],
      ['created',  :sort_by_created.t],
      ['modified', :sort_by_modified.t],
    ]

    # Add "show locations" link if this query can be coerced into an
    # observation query.
    if query.is_coercable?(:Location)
      @links << [:show_objects.t(:type => :location), {
                  :action => 'index_location',
                  :params => query_params(query),
                }]
    end

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show Location
  #
  ##############################################################################

  # Show a Location and one of its LocationDescription's, including a map.
  def show_location # :nologin: :prefetch:
    store_location
    pass_query_params
    clear_query_in_session

    # Load Location and LocationDescription along with a bunch of associated
    # objects.
    loc_id = params[:id]
    desc_id = params[:desc]
    if @location = find_or_goto_index(Location, loc_id,
                                      :include => [:user, :descriptions])

      # Load default description if user didn't request one explicitly.
      desc_id = @location.description_id if desc_id.blank?
      if desc_id.blank?
        @description = nil
      elsif @description = LocationDescription.safe_find(desc_id, :include =>
                                         [:authors, :editors, :license, :user])
        @description = nil if !@description.is_reader?(@user)
      else
        flash_error(:runtime_object_not_found.t(:type => :description,
                                                :id => desc_id))
      end

      update_view_stats(@location)
      update_view_stats(@description) if @description

      # Get a list of projects the user can create drafts for.
      @projects = @user && @user.projects_member.select do |project|
        !@location.descriptions.any? {|d| d.belongs_to_project?(project)}
      end
    end
  end

  # Show just a LocationDescription.
  def show_location_description # :nologin: :prefetch:
    store_location
    pass_query_params
    if @description = find_or_goto_index(LocationDescription, params[:id],
                         :include => [ :authors, :editors, :license, :user,
                                       {:location => :descriptions} ])

      # Public or user has permission.
      if @description.is_reader?(@user)
        @location = @description.location
        update_view_stats(@description)

        # Get a list of projects the user can create drafts for.
        @projects = @user && @user.projects_member.select do |project|
          !@location.descriptions.any? {|d| d.belongs_to_project?(project)}
        end

      # User doesn't have permission to see this description.
      else
        if @description.source_type == :project
          flash_error(:runtime_show_draft_denied.t)
          if project = Project.find_by_title(@description.source_name)
            redirect_to(:controller => 'project', :action => 'show_project',
                        :id => project.id)
          else
            redirect_to(:action => 'show_location', :id => @description.location_id)
          end
        else
          flash_error(:runtime_show_description_denied.t)
          redirect_to(:action => 'show_location', :id => @description.location_id)
        end
      end
    end
  end

  # Show past version of Location.  Accessible only from show_location page.
  def show_past_location # :nologin: :prefetch: :norobots:
    store_location
    pass_query_params
    if @location = find_or_goto_index(Location, params[:id])
      @location.revert_to(params[:version].to_i)
    end
  end

  # Show past version of LocationDescription.  Accessible only from
  # show_location_description page.
  def show_past_location_description # :nologin: :prefetch: :norobots:
    store_location
    pass_query_params
    if @description = find_or_goto_index(LocationDescription, params[:id])
      if params[:merge_source_id].blank?
        @description.revert_to(params[:version].to_i)
      else
        @merge_source_id = params[:merge_source_id]
        version = LocationDescription::Version.find(@merge_source_id)
        @old_parent_id = version.location_description_id
        subversion = params[:version]
        if !subversion.blank? and
           (version.version != subversion.to_i)
          version = LocationDescription::Version.
            find_by_version_and_location_description_id(params[:version], @old_parent_id)
        end
        @description.clone_versioned_model(version, @description)
      end
    end
  end

  # Go to next location: redirects to show_location.
  def next_location # :nologin: :norobots:
    redirect_to_next_object(:next, Location, params[:id])
  end

  # Go to previous location: redirects to show_location.
  def prev_location # :nologin: :norobots:
    redirect_to_next_object(:prev, Location, params[:id])
  end

  # Go to next location: redirects to show_location.
  def next_location_description # :nologin: :norobots:
    redirect_to_next_object(:next, LocationDescription, params[:id])
  end

  # Go to previous location: redirects to show_location.
  def prev_location_description # :nologin: :norobots:
    redirect_to_next_object(:prev, LocatioDescriptionn, params[:id])
  end

  ##############################################################################
  #
  #  :section: Create/Edit Location
  #
  ##############################################################################

  def create_location # :prefetch: :norobots:
    store_location
    pass_query_params

    # (Used when linked from "define this location".)
    @where = params[:where]

    # (Used when linked from user profile: sets primary location after done.)
    @set_user = (params[:set_user] == "1")

    # Reder a blank form.
    if request.method != :post
      @location = Location.new

    else
      # Set to true below if created successfully, or if a matching location
      # already exists.  In either case, we're done with this form.
      done = false

      # Look to see if the display name is already use.  If it is then just use
      # that location and ignore the other values.  Probably should be smarter
      # with warnings and merges and such...
      name = params[:location][:display_name].strip_squeeze rescue ''
      @location = Location.find_by_display_name(name)

      # Location already exists.
      if @location
        flash_warning(:runtime_location_already_exists.t(:name => name))
        done = true

      # Need to create location.
      elsif (@location = Location.new(params[:location])) and
            @location.save
        Transaction.post_location(
          :id      => @location,
          :created => @location.created,
          :name    => @location.display_name,
          :north   => @location.north,
          :south   => @location.south,
          :east    => @location.east,
          :west    => @location.west,
          :low     => @location.low,
          :high    => @location.high
        )
        flash_notice(:runtime_location_success.t(:id => @location.id))
        done = true

      # Failed to create location
      else
        flash_object_errors @location
      end

      # If done, update any observations at @where string originally passed in,
      # and set user's primary location if called from profile.
      if done
        if !@where.blank?
          update_observations_by_where(@location, @where)
        end
        if @set_user
          @user.location = @location
          @user.save
          Transaction.put_user(
            :id           => @user,
            :set_location => @location
          )
        end
        redirect_to(:action => 'show_location', :id => @location.id)
      end
    end
  end

  def edit_location # :prefetch: :norobots:
    store_location
    pass_query_params
    @location = Location.find(params[:id])
    done = false
    if request.method == :post

      # First check if user changed the name to one that already exists.
      name = params[:location][:display_name].strip_squeeze rescue ''
      merge = Location.find_by_display_name(name)

      # Merge with another location.
      if merge && merge != @location

        # Swap order if only one is mergable.
        if !@location.mergable? && merge.mergable?
          @location, merge = merge, @location
        end

        # Admins can actually merge them, then redirect to other location.
        if is_in_admin_mode? || @location.mergable?
          merge.merge(@location)
          merge.save if merge.changed?
          @location = merge
          done = true

        # Non-admins just send email-request to admins.
        else
          flash_warning(:runtime_merge_locations_warning.t)
          content = :email_location_merge.t(:user => @user.login,
                  :this => @location.display_name, :that => merge.display_name)
          AccountMailer.deliver_webmaster_question(@user.email, content)
        end

      # Otherwise it is safe to change the name.
      else
        @location.display_name = name
      end

      # Just update this location.
      if !done
        for key, val in params[:location]
          if key != 'display_name'
            @location.send("#{key}=", val)
          end
        end

        args = {}
        args[:set_name]  = @location.display_name if @location.display_name_changed?
        args[:set_north] = @location.north        if @location.north_changed?
        args[:set_south] = @location.south        if @location.south_changed?
        args[:set_west]  = @location.west         if @location.west_changed?
        args[:set_east]  = @location.east         if @location.east_changed?
        args[:set_high]  = @location.high         if @location.high_changed?
        args[:set_low]   = @location.low          if @location.low_changed?

        # No changes made.
        if !@location.changed?
          flash_warning(:runtime_edit_location_no_change.t)
          redirect_to(:action => 'show_location', :id => @location.id)

        # There were error(s).
        elsif !@location.save
          flash_object_errors @location

        # Updated successfully.
        else
          if !args.empty?
            args[:id] = @location
            Transaction.put_location(args)
          end
          flash_notice(:runtime_edit_location_success.t(:id => @location.id))
          done = true
        end
      end
    end

    if done
      redirect_to(:action => 'show_location', :id => @location.id)
    end
  end

  def create_location_description # :prefetch: :norobots:
    store_location
    pass_query_params
    @location = Location.find(params[:id])
    @licenses = License.current_names_and_ids

    # Render a blank form.
    if request.method == :get
      @description = LocationDescription.new
      @description.location = @location
      initialize_description_source(@description)

    # Create new description.
    else
      @description = LocationDescription.new
      @description.location = @location
      @description.attributes = params[:description]

      if @description.valid?
        initialize_description_permissions(@description)
        @description.save

        Transaction.post_location_description(
          @description.all_notes.merge(
            :id            => @description,
            :created       => @description.created,
            :source_type   => @description.source_type,
            :source_name   => @description.source_name,
            :locale        => @description.locale,
            :license       => @description.license,
            :admin_groups  => @description.admin_groups,
            :writer_groups => @description.writer_groups,
            :reader_groups => @description.reader_groups
          )
        )

        # Log action in parent location.
        @description.location.log(:log_object_created_by_user_with_name,
                 :type => :description, :user => @user.login, :touch => true,
                 :name => @description.unique_partial_format_name)

        flash_notice(:runtime_location_description_success.t(
                     :id => @description.id))
        redirect_to(:action => 'show_location_description',
                    :id => @description.id)

      else
        flash_object_errors @description
      end
    end
  end

  def edit_location_description # :prefetch: :norobots:
    store_location
    pass_query_params
    @description = LocationDescription.find(params[:id])
    @licenses = License.current_names_and_ids

    if !check_description_edit_permission(@description, params[:description])
      # already redirected

    elsif request.method == :post
      @description.attributes = params[:description]

      args = {}
      args["set_source_type"] = @description.source_type if @description.source_type_changed?
      args["set_source_name"] = @description.source_name if @description.source_name_changed?
      args["set_locale"]      = @description.locale      if @description.locale_changed?
      args["set_license"]     = @description.license     if @description.license_id_changed?
      for field in LocationDescription.all_note_fields
        if @description.send("#{field}_changed?")
          args["set_#{field}".to_sym] = @description.send(field)
        end
      end

      # Modify permissions based on changes to the two "public" checkboxes.
      modify_description_permissions(@description, args)

      # No changes made.
      if args.empty?
        flash_warning(:runtime_edit_location_description_no_change.t)
        redirect_to(:action => 'show_location_description',
                    :id => @description.id)

      # There were error(s).
      elsif !@description.save
        flash_object_errors(@description)

      # Updated successfully.
      else
        flash_notice(:runtime_edit_location_description_success.t(
                     :id => @description.id))

        if !args.empty?
          args[:id] = @description
          Transaction.put_location_description(args)
        end

        # Log action in parent location.
        @description.location.log(:log_object_updated_by_user_with_name,
                 :type => :description, :user => @user.login, :touch => true,
                 :name => @description.unique_partial_format_name)

        # Delete old description after resolving conflicts of merge.
        if (params[:delete_after] == 'true') and
           (old_desc = LocationDescription.safe_find(params[:old_desc_id]))
          v = @description.versions.latest
          v.merge_source_id = old_desc.versions.latest.id
          v.save
          if !old_desc.is_admin?(@user)
            flash_warning(:runtime_description_merge_delete_denied.t)
          else
            flash_notice(:runtime_description_merge_deleted.
                           t(:old => old_desc.partial_format_name))
            @description.location.log(:log_object_merged_by_user,
                     :user => @user.login, :touch => true,
                     :from => old_desc.unique_partial_format_name,
                     :to => @description.unique_partial_format_name)
            old_desc.destroy
          end
        end

        redirect_to(:action => 'show_location_description',
                    :id => @description.id)
      end
    end
  end

  def destroy_location_description # :norobots:
    pass_query_params
    @description = LocationDescription.find(params[:id])
    if @description.is_admin?(@user)
      flash_notice(:runtime_destroy_description_success.t)
      @description.location.log(:log_object_destroyed_by_user_with_name,
               :type => :description, :user => @user.login, :touch => true,
               :name => @description.unique_partial_format_name)
      @description.destroy
      redirect_to(:action => 'show_location', :id => @description.location_id,
                  :params => query_params)
    else
      flash_error(:runtime_destroy_description_not_admin.t)
      if @description.is_reader?(@user)
        redirect_to(:action => 'show_location_description', :id => @description.id,
                    :params => query_params)
      else
        redirect_to(:action => 'show_location', :id => @description.location_id,
                    :params => query_params)
      end
    end
  end

  ##############################################################################
  #
  #  :section: Merging Locations
  #
  ##############################################################################

  # Show a list of defined locations that match a given +where+ string, in
  # order of closeness of match.
  def list_merge_options # :norobots:
    store_location
    @where = params[:where].to_s

    # Split list of all locations into "matches" and "non-matches".  Try
    # matches in the following order:
    #   1) all that start with full "where" string
    #   2) all that start with everything in "where" up to the comma
    #   3) all that start with the first word in "where"
    #   4) there just aren't any matches, give up
    all = Location.all(:order => 'display_name')
    @matches, @others = (
      split_out_matches(all, @where) or
      split_out_matches(all, @where.split(',').first) or
      split_out_matches(all, @where.split(' ').first) or
      [nil, all]
    )
  end

  # Split up +list+ into those that start with +substring+ and those that
  # don't.  If none match, then return nil.
  def split_out_matches(list, substring)
    matches = list.select do |loc|
      (loc.display_name.to_s[0,substring.length] == substring) or
      (loc.search_name.to_s[0,substring.length] == substring)
    end
    if matches.empty?
      nil
    else
      [matches, list - matches]
    end
  end

  # Adds the Observation's associated with <tt>obs.where == params[:where]</tt>
  # into the given Location.  Linked from +list_merge_options+, I think.
  def add_to_location # :norobots:
    location = Location.find(params[:location])
    where = params[:where].strip_squeeze rescue ''
    if !where.blank? and
       update_observations_by_where(location, where)
      flash_notice(:runtime_location_merge_success.t(:this => where,
                   :that => location.display_name))
    end
    redirect_to(:action => 'list_locations')
  end

  # Move all the Observation's with a given +where+ into a given Location.
  def update_observations_by_where(location, where)
    success = true
    observations = Observation.find_all_by_where(where)
    for o in observations
      unless o.location_id
        o.location_id = location.id
        o.where = nil
        if o.save
          Transaction.put_observation(
            :id           => o,
            :set_location => location
          )
        else
          flash_error :runtime_location_merge_failed.t(:name => o.unique_format_name)
          success = false
        end
      end
    end
    return success
  end
end

# list_locations::          . V .
# locations_by_user::       . . .
# locations_by_editor::     . . .
# location_search::         . . .
# advanced_search::         . . .
# index_location::          . . .
# map_locations::           . V .
# show_selected_locations:: (helper)
# coerce_query_for_undefined_locations::
#                           (helper)
# 
# list_location_descriptions::          .
# location_descriptions_by_author::         .
# location_descriptions_by_editor::         .
# index_location_description::          
# show_selected_location_descriptions:: (helper)
# 
# show_location
# show_location_description
# show_past_location
# show_past_location_description
# next_location
# prev_location
# next_location_description
# prev_location_description
# create_location
# edit_location
# create_location_description
# edit_location_description
# destroy_location_description
# list_merge_options
# add_to_location
# 
# split_out_matches(list, substring)
# update_observations_by_where(location, where)
# 
# adjust_permissions.rhtml
# create_location.rhtml
# create_location_description.rhtml
# edit_location.rhtml
# edit_location_description.rhtml
# list_location_descriptions.rhtml
# list_locations.rhtml
# list_merge_options.rhtml
# merge_descriptions.rhtml
# show_location.rhtml
# show_location_description.rhtml
# show_past_location.rhtml
# show_past_location_description.rhtml

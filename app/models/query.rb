#
#  = Query Model
#
################################################################################

class Query < AbstractQuery
  belongs_to :user

  # Parameters allowed in every query.
  self.global_params = {
    # Allow every query to customize its title.
    :title? => [:string],
  }

  # Parameters allowed in every query for a given model.
  self.model_params = {
    :Comment => {
    },
    :Image => {
    },
    :Location => {
    },
    :LocationDescription => {
    },
    :Name => {
      :misspellings? => {:string => [:no, :either, :only]},
      :deprecated?   => {:string => [:either, :no, :only]},
    },
    :NameDescription => {
    },
    :Observation => {
      # :date_created
      # :date_modified
      # :date_observed
      # :user
      # :name
      # :location
      # :species_list
      # :confidence
      # :specimen
      # :is_col_loc
      # :confidence
      # :has_location
      # :has_notes
      # :has_name
      # :has_images
      # :has_votes
      # :has_comments
      # :notes_has
      # :comments_has
    },
    :Project => {
    },
    :RssLog => {
    },
    :SpeciesList => {
    },
    :User => {
    },
  }

  # Parameters required for each flavor.
  self.flavor_params = {
    :advanced_search => {
      :name?     => :string,
      :location? => :string,
      :user?     => :string,
      :content?  => :string,
    },
    :all => {
      :type? => :string,
    },
    :at_location => {
      :location => Location,
    },
    :at_where => {
      :location => :string,
    },
    :by_author => {
      :user => User,
    },
    :by_editor => {
      :user => User,
    },
    :by_user => {
      :user => User,
    },
    :for_user => {
      :user => User,
    },
    :in_set => {
      :ids => [AbstractModel],
    },
    :in_species_list => {
      :species_list => SpeciesList,
    },
    :inside_observation => {
      :observation => Observation,
      :outer       => Query,
    },
    :of_children => {
      :name => Name,
      :all? => :boolean,
    },
    :of_name => {
      :name          => Name,
      :synonyms?     => {:string => [:no, :all, :exclusive]},
      :nonconsensus? => {:string => [:no, :all, :exclusive]},
    },
    :of_parents => {
      :name => Name,
    },
    :pattern_search => {
      :pattern => :string,
    },
    :with_descriptions_by_author => {
      :user => User,
    },
    :with_descriptions_by_editor => {
      :user => User,
    },
    :with_descriptions_by_user => {
      :user => User,
    },
    :with_descriptions_in_set => {
      :ids        => [AbstractModel],
      :old_title? => :string,
      :old_by?    => :string,
    },
    :with_observations_at_location => {
      :location => Location,
    },
    :with_observations_at_where => {
      :location => :string,
    },
    :with_observations_by_user => {
      :user => User,
    },
    :with_observations_in_set => {
      :ids => [Observation],
      :old_title? => :string,
      :old_by?    => :string,
    },
    :with_observations_in_species_list => {
      :species_list => SpeciesList,
    },
    :with_observations_of_children => {
      :name => Name,
      :all? => :boolean,
    },
    :with_observations_of_name => {
      :name          => Name,
      :synonyms?     => {:string => [:no, :all, :exclusive]},
      :nonconsensus? => {:string => [:no, :all, :exclusive]},
    },
  }

  # Allowed flavors for each model.
  self.allowed_model_flavors = {
    :Comment => [
      :all,                   # All comments, by created.
      :by_user,               # Comments created by user, by modified.
      :in_set,                # Comments in a given set.
      :for_user,              # Comments sent to used, by modified.
      :pattern_search,        # Comments matching a pattern, by modified.
    ],
    :Image => [
      :advanced_search,       # Advanced search results.
      :all,                   # All images, by created.
      :by_user,               # Images created by user, by modified.
      :in_set,                # Images in a given set.
      :inside_observation,    # Images belonging to outer observation query.
      :pattern_search,        # Images matching a pattern, by ???.
      :with_observations,                 # Images with observations, alphabetically.
      :with_observations_at_location,     # Images with observations at a defined location.
      :with_observations_at_where,        # Images with observations at an undefined 'where'.
      :with_observations_by_user,         # Images with observations by user.
      :with_observations_in_set,          # Images with observations in a given set.
      :with_observations_in_species_list, # Images with observations in a given species list.
      :with_observations_of_children,     # Images with observations of children a given name.
      :with_observations_of_name,         # Images with observations of a given name.
    ],
    :Location => [
      :advanced_search,       # Advanced search results.
      :all,                   # All locations, alphabetically.
      :by_user,               # Locations created by a given user, alphabetically.
      :by_editor,             # Locations modified by a given user, alphabetically.
      :by_rss_log,            # Locations with RSS logs, in RSS order.
      :in_set,                # Locations in a given set.
      :pattern_search,        # Locations matching a pattern, alphabetically.
      :with_descriptions,                 # Locations with descriptions, alphabetically.
      :with_descriptions_by_author,       # Locations with descriptions authored by a given user, alphabetically.
      :with_descriptions_by_editor,       # Locations with descriptions edited by a given user, alphabetically.
      :with_descriptions_by_user,         # Locations with descriptions created by a given user, alphabetically.
      :with_descriptions_in_set,          # Locations with descriptions in a given set, alphabetically.
      :with_observations,                 # Locations with observations, alphabetically.
      :with_observations_by_user,         # Locations with observations by user.
      :with_observations_in_set,          # Locations with observations in a given set.
      :with_observations_in_species_list, # Locations with observations in a given species list.
      :with_observations_of_children,     # Locations with observations of children of a given name.
      :with_observations_of_name,         # Locations with observations of a given name.
    ],
    :LocationDescription => [
      :all,                   # All location descriptions, alphabetically.
      :by_author,             # Location descriptions that list given user as an author, alphabetically.
      :by_editor,             # Location descriptions that list given user as an editor, alphabetically.
      :by_user,               # Location descriptions created by a given user, alphabetically.
      :in_set,                # Location descriptions in a given set.
    ],
    :Name => [
      :advanced_search,       # Advanced search results.
      :all,                   # All names, alphabetically.
      :by_user,               # Names created by a given user, alphabetically.
      :by_editor,             # Names modified by a given user, alphabetically.
      :by_rss_log,            # Names with RSS logs, in RSS order.
      :in_set,                # Names in a given set.
      :of_children,           # Names of children of a name.
      :of_parents,            # Names of parents of a name.
      :pattern_search,        # Names matching a pattern, alphabetically.
      :with_descriptions,                 # Names with descriptions, alphabetically.
      :with_descriptions_by_author,       # Names with descriptions authored by a given user, alphabetically.
      :with_descriptions_by_editor,       # Names with descriptions edited by a given user, alphabetically.
      :with_descriptions_by_user,         # Names with descriptions created by a given user, alphabetically.
      :with_descriptions_in_set,          # Names with descriptions in a given set, alphabetically.
      :with_observations,                 # Names with observations, alphabetically.
      :with_observations_at_location,     # Names with observations at a defined location.
      :with_observations_at_where,        # Names with observations at an undefined 'where'.
      :with_observations_by_user,         # Names with observations by user.
      :with_observations_in_set,          # Names with observations in a given set.
      :with_observations_in_species_list, # Names with observations in a given species list.
    ],
    :NameDescription => [
      :all,                   # All name descriptions, alphabetically.
      :by_author,             # Name descriptions that list given user as an author, alphabetically.
      :by_editor,             # Name descriptions that list given user as an editor, alphabetically.
      :by_user,               # Name descriptions created by a given user, alphabetically.
      :in_set,                # Name descriptions in a given set.
    ],
    :Observation => [
      :advanced_search,       # Advanced search results.
      :all,                   # All observations, by date.
      :at_location,           # Observations at a location, by modified.
      :at_where,              # Observations at an undefined location, by modified.
      :by_rss_log,            # Observations with RSS log, in RSS order.
      :by_user,               # Observations created by user, by modified.
      :in_set,                # Observations in a given set.
      :in_species_list,       # Observations in a given species list, by modified.
      :of_children,           # Observations of children of a given name.
      :of_name,               # Observations with a given name.
      :pattern_search,        # Observations matching a pattern, by name.
    ],
    :Project => [
      :all,                   # All projects, by title.
      :by_rss_log,            # Projects with RSS logs, in RSS order.
      :in_set,                # Projects in a given set.
      :pattern_search,        # Projects matching a pattern, by title.
    ],
    :RssLog => [
      :all,                   # All RSS logs, most recent activity first.
      :in_set,                # RSS logs in a given set.
    ],
    :SpeciesList => [
      :all,                   # All species lists, alphabetically.
      :at_location,           # Species lists at a location, by modified.
      :at_where,              # Species lists at an undefined location, by modified.
      :by_rss_log,            # Species lists with RSS log, in RSS order
      :by_user,               # Species lists created by user, alphabetically.
      :in_set,                # Species lists in a given set.
      :pattern_search,        # Species lists matching a pattern, alphabetically.
    ],
    :User => [
      :all,                   # All users, by name.
      :in_set,                # Users in a given set.
      :pattern_search,        # Users matching login/name, alphabetically.
    ],
  }

  # Map each pair of tables to the foreign key name.
  self.join_conditions = {
    :comments => {
      :location_descriptions => :object,
      :locations     => :object,
      :name_descriptions => :object,
      :names         => :object,
      :observations  => :object,
      :projects      => :object,
      :users         => :user_id,
    },
    :images => {
      :users         => :user_id,
      :licenses      => :license_id,
    },
    :images_observations => {
      :images        => :image_id,
      :observations  => :observation_id,
    },
    :interests => {
      :locations     => :object,
      :names         => :object_id,
      :observations  => :object_id,
      :users         => :user_id,
    },
    :location_descriptions => {
      :locations     => :location_id,
      :users         => :user_id,
    },
    :location_descriptions_admins => {
      :location_descriptions => :location_description_id,
      :user_groups   => :user_group_id,
    },
    :location_descriptions_authors => {
      :location_descriptions => :location_description_id,
      :users         => :user_id,
    },
    :location_descriptions_editors => {
      :location_descriptions => :location_description_id,
      :users         => :user_id,
    },
    :location_descriptions_readers => {
      :location_descriptions => :location_description_id,
      :user_groups   => :user_group_id,
    },
    :location_descriptions_versions => {
      :location_descriptions => :location_description_id,
    },
    :location_descriptions_writers => {
      :location_descriptions => :location_description_id,
      :user_groups   => :user_group_id,
    },
    :locations => {
      :licenses      => :license_id,
      :'location_descriptions.default' => :description_id,
      :rss_logs      => :rss_log_id,
      :users         => :user_id,
    },
    :locations_versions => {
      :locations     => :location_id,
    },
    :name_descriptions => {
      :names         => :name_id,
      :users         => :user_id,
    },
    :name_descriptions_admins => {
      :name_descriptions => :name_description_id,
      :user_groups   => :user_group_id,
    },
    :name_descriptions_authors => {
      :name_descriptions => :name_description_id,
      :users         => :user_id,
    },
    :name_descriptions_editors => {
      :name_descriptions => :name_description_id,
      :users         => :user_id,
    },
    :name_descriptions_readers => {
      :name_descriptions => :name_description_id,
      :user_groups   => :user_group_id,
    },
    :name_descriptions_versions => {
      :name_descriptions => :name_description_id,
    },
    :name_descriptions_writers => {
      :name_descriptions => :name_description_id,
      :user_groups   => :user_group_id,
    },
    :names => {
      :licenses      => :license_id,
      :'name_descriptions.default' => :description_id,
      :rss_logs      => :rss_log_id,
      :users         => :user_id,
      :'users.reviewer' => :reviewer_id,
    },
    :names_versions => {
      :names         => :name_id,
    },
    :namings => {
      :names         => :name_id,
      :observations  => :observation_id,
      :users         => :user_id,
    },
    :notifications => {
      :names         => :obj,
      :users         => :user_id,
    },
    :observations => {
      :locations     => :location_id,
      :names         => :name_id,
      :rss_logs      => :rss_log_id,
      :users         => :user_id,
      :'images.thumb_image' => :thumb_image_id,
    },
    :observations_species_lists => {
      :observations  => :observation_id,
      :species_lists => :species_list_id,
    },
    :projects => {
      :users         => :user_id,
      :user_groups   => :user_group_id,
      :'user_groups.admin_group' => :admin_group_id,
    },
    :rss_logs => {
      :locations     => :location_id,
      :names         => :name_id,
      :observations  => :observation_id,
      :species_lists => :species_list_id,
    },
    :species_lists => {
      :locations     => :location_id,
      :rss_logs      => :rss_log_id,
      :users         => :user_id,
    },
    :user_groups_users => {
      :user_groups   => :user_group_id,
      :users         => :user_id,
    },
    :users => {
      :images        => :image_id,
      :licenses      => :license_id,
      :locations     => :location_id,
    },
    :votes => {
      :namings       => :naming_id,
      :observations  => :observation_id,
      :users         => :user_id,
    },
  }

  # Return the default order for this query.
  def default_order
    case model_symbol
    when :Comment             ; 'created'
    when :Image               ; 'created'
    when :Location            ; 'name'
    when :LocationDescription ; 'name'
    when :Name                ; 'name'
    when :NameDescription     ; 'name'
    when :Observation         ; 'date'
    when :Project             ; 'title'
    when :RssLog              ; 'modified'
    when :SpeciesList         ; 'title'
    when :User                ; 'name'
    end
  end

  ##############################################################################
  #
  #  :section: Titles
  #
  ##############################################################################

  # Holds the title, as a localization with args.  The default is
  # <tt>:query_title_{model}_{flavor}</tt>, passing in +params+ as args.
  #
  #   self.title_args = {
  #     :tag => :app_advanced_search,
  #     :pattern => clean_pattern,
  #   }
  #
  attr_accessor :title_args

  # Put together a localized title for this query.  (Intended for use as title
  # of the results index page.)
  def title
    initialize_query if !initialized?
    if raw = title_args[:raw]
      raw
    else
      title_args[:tag].to_sym.t(title_args)
    end
  end

  ##############################################################################
  #
  #  :section: Coercion
  #
  ##############################################################################

  # Attempt to coerce a query for one model into a related query for another
  # model.  This is currently only defined for a very few specific cases.  I
  # have no idea how to generalize it.  Returns a new Query in rare successful
  # cases; returns +nil+ in all other cases.
  def coerce(new_model, just_test=false)
    old_model  = self.model_symbol
    old_flavor = self.flavor
    new_model  = new_model.to_s.to_sym

    # Going from list_rss_logs to showing observation, name, etc.
    if (old_model  == :RssLog) and
       (old_flavor == :all) and
       (new_model.to_s.constantize.reflect_on_association(:rss_log) rescue false)
      just_test or begin
        params2 = params.dup
        params2.delete(:type)
        self.class.lookup(new_model, :by_rss_log, params2)
      end

    # Going from objects with observations to those observations themselves.
    elsif ( (new_model == :Observation) and
            [:Image, :Location, :Name].include?(old_model) and
            old_flavor.to_s.match(/^with_observations/) ) or
          ( (new_model == :LocationDescription) and
            (old_model == :Location) and
            old_flavor.to_s.match(/^with_descriptions/) ) or
          ( (new_model == :NameDescription) and
            (old_model == :Name) and
            old_flavor.to_s.match(/^with_descriptions/) )
      just_test or begin
        if old_flavor.to_s.match(/^with_[a-z]+$/)
          new_flavor = :all
        else
          new_flavor = old_flavor.to_s.sub(/^with_[a-z]+_/,'').to_sym
        end
        params2 = params.dup
        if params2[:title]
          params2[:title] = "raw " + title
        elsif params2[:old_title]
          # This is passed through from previous coerce.
          params2[:title] = "raw " + params2[:old_title]
          params2.delete(:old_title)
        end
        if params2[:old_by]
          # This is passed through from previous coerce.
          params2[:by] = params2[:old_by]
          params2.delete(:old_by)
        elsif params2[:by]
          # Can't be sure old sort order will continue to work.
          params2.delete(:by)
        end
        self.class.lookup(new_model, new_flavor, params2)
      end

    # Going from observations to objects with those observations.
    elsif ( (old_model == :Observation) and
            [:Image, :Location, :Name].include?(new_model) ) or
          ( (old_model == :LocationDescription) and
            (new_model == :Location) ) or
          ( (old_model == :NameDescription) and
            (new_model == :Name) )
      just_test or begin
        if old_model == :Observation
          type1 = :observations
          type2 = :observation
        else
          type1 = :descriptions
          type2 = old_model.to_s.underscore.to_sym
        end
        if old_flavor == :all
          new_flavor = :"with_#{type1}"
        else
          new_flavor = :"with_#{type1}_#{old_flavor}"
        end
        params2 = params.dup
        if params2[:title]
          # This can spiral out of control, but so be it.
          params2[:title] = "raw " +
            :"query_title_with_#{type1}s_in_set".
              t(:type1 => title, :type => type2)
        end
        if params2[:by]
          # Can't be sure old sort order will continue to work.
          params2.delete(:by)
        end
        if old_flavor == :in_set
          params2.delete(:title) if params2.has_key?(:title)
          self.class.lookup(new_model, :"with_#{type1}_in_set",
              params2.merge(:old_title => title, :old_by => params[:by]))
        elsif old_flavor == :advanced_search || old_flavor == :pattern_search
          params2.delete(:title) if params2.has_key?(:title)
          self.class.lookup(new_model, :"with_#{type1}_in_set",
              :ids => result_ids, :old_title => title, :old_by => params[:by])
        elsif (new_model == :Location) and
              (old_flavor == :at_location)
          self.class.lookup(new_model, :in_set,
                                     :ids => params2[:location])
        elsif (new_model == :Name) and
              (old_flavor == :of_name)
          # TODO -- need 'synonyms' flavor
          # params[:synonyms] == :all / :no / :exclusive
          # params[:misspellings] == :either / :no / :only
          nil
        elsif allowed_model_flavors[new_model].include?(new_flavor)
          self.class.lookup(new_model, new_flavor, params2)
        end
      end

    # Let superclass handle anything else.
    else
      super
    end
  end

  ##############################################################################
  #
  #  :section: Queries
  #
  ##############################################################################

  # Give query a default title before passing off to standard initializer.
  def initialize_query
    self.title_args = params.merge(
      :tag  => "query_title_#{flavor}".to_sym,
      :type => model_string.underscore.to_sym
    )
    super
  end

  # Allow all queries to customize title.
  def initialize_global
    if args = params[:title]
      for line in args
        raise "Invalid syntax in :title parameter: '#{line}'" if line !~ / /
        title_args[$`.to_sym] = $'
      end
    end
  end

  # ----------------------------
  #  Sort orders.
  # ----------------------------

  # Tell SQL how to sort results using the <tt>:by => :blah</tt> mechanism.
  def initialize_order(by)
    table = model.table_name
    case by

    when 'modified', 'created', 'last_login'
      if model.column_names.include?(by)
        "#{table}.#{by} DESC"
      end

    when 'date'
      if model.column_names.include?('date')
        "#{table}.date DESC"
      elsif model.column_names.include?('when')
        "#{table}.when DESC"
      elsif model.column_names.include?('created')
        "#{table}.created DESC"
      end

    when 'name'
      if model == Image
        self.join << {:images_observations => {:observations => :names}}
        self.group = 'images.id'
        'MIN(names.search_name) ASC, images.when DESC'
      elsif model == Location
        'locations.search_name ASC'
      elsif model == LocationDescription
        self.join << :locations
        'locations.search_name ASC, location_descriptions.created ASC'
      elsif model == Name
        'names.text_name ASC, names.author ASC'
      elsif model == NameDescription
        self.join << :names
        'names.text_name ASC, names.author ASC, name_descriptions.created ASC'
      elsif model == Observation
        self.join << :names
        'names.text_name ASC, names.author ASC, observations.when DESC'
      elsif model.column_names.include?('search_name')
        "#{table}.search_name ASC"
      elsif model.column_names.include?('name')
        "#{table}.name ASC"
      elsif model.column_names.include?('title')
        "#{table}.title ASC"
      end

    when 'title', 'login', 'summary', 'copyright_holder', 'where'
      if model.column_names.include?(by)
        "#{table}.#{by} ASC"
      end

    when 'user'
      if model.column_names.include?('user_id')
        self.join << :users
        'IF(users.name = "" OR users.name IS NULL, users.login, users.name) ASC'
      end

    when 'location'
      if model.column_names.include?('location_id')
        self.join << :locations
        'locations.search_name ASC'
      end

    when 'rss_log'
      if model.column_names.include?('rss_log_id')
        self.join << :rss_logs
        'rss_logs.modified DESC'
      end

    when 'confidence'
      if model_symbol == :Image
        self.join << {:images_observations => :observations}
        "observations.vote_cache DESC"
      elsif model_symbol == :Observation
        "observations.vote_cache DESC"
      end

    when 'image_quality'
      if model_symbol == :Image
        "images.vote_cache DESC"
      end

    when 'thumbnail_quality'
      if model_symbol == :Observation
        self.join << :'images.thumb_image'
        "images.vote_cache DESC, observations.vote_cache DESC"
      end

    when 'contribution'
      if model_symbol == :User
        'users.contribution DESC'
      end
    end
  end

  # ----------------------------
  #  Name customization.
  # ----------------------------

  def initialize_name

    # Is the name misspelt?
    case params[:misspellings] || :no
    when :no   ; self.where << 'names.correct_spelling_id IS NULL'
    when :only ; self.where << 'names.correct_spelling_id IS NOT NULL'
    end

    # Is the name deprecated?
    case params[:deprecated] || :either
    when :no   ; self.where << 'names.deprecated IS FALSE'
    when :only ; self.where << 'names.deprecated IS TRUE'
    end
  end

  # --------------------------------------------
  #  Queries that essentially have no filters.
  # --------------------------------------------

  def initialize_all
    if (by = params[:by]) and
       (by = :"sort_by_#{by}")
      title_args[:tag]   = :query_title_all_by
      title_args[:order] = by.t
    end

    # Allow users to filter RSS logs for the object type they're interested in.
    if model_symbol == :RssLog
      x = params[:type] ||= 'all'
      if x == 'none'
        self.where << 'FALSE'
      elsif x != 'all'
        self.where << x.split.map do |type|
          "rss_logs.#{type}_id IS NOT NULL"
        end.join(' OR ')
      end
    elsif params[:type]
      raise "Can't use :type parameter in :#{model_symbol} :all queries!"
    end
  end

  def initialize_by_rss_log
    self.join << :rss_logs
    params[:by] ||= 'rss_log'
  end

  # ----------------------------
  #  Get user contributions.
  # ----------------------------

  def initialize_by_user
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    table = model.table_name
    if model.column_names.include?('user_id')
      self.where << "#{table}.user_id = '#{params[:user]}'"
    else
      raise "Can't figure out how to select #{model_string} by user_id!"
    end
    case model_symbol
    when :Observation
      params[:by] ||= 'modified'
    when :Image
      params[:by] ||= 'modified'
    when :Location, :Name, :LocationDescription, :NameDescription
      params[:by] ||= 'name'
    when :SpeciesList
      params[:by] ||= 'title'
    when :Comment
      params[:by] ||= 'created'
    end
  end

  def initialize_for_user
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.join << :observations
    self.where << "observations.user_id = '#{params[:user]}'"
    params[:by] ||= 'created'
  end

  def initialize_by_author
    initialize_by_editor
  end

  def initialize_by_editor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    case model_symbol
    when :Name, :Location
      version_table = "#{model.table_name}_versions".to_sym
      self.join << version_table
      self.where << "#{version_table}.user_id = '#{params[:user]}'"
      self.where << "#{model.table_name}.user_id != '#{params[:user]}'"
    when :NameDescription, :LocationDescription
      glue_table = "#{model.name.underscore}s_#{flavor}s".
                      sub('_by_', '_').to_sym
      self.join << glue_table
      self.where << "#{glue_table}.user_id = '#{params[:user]}'"
      params[:by] ||= 'name'
    else
      raise "No editors or authors in #{model_string}!"
    end
  end

  # -----------------------------------
  #  Various subsets of Observations.
  # -----------------------------------

  def initialize_at_location
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    self.join << :names
    self.where << "#{model.table_name}.location_id = '#{params[:location]}'"
    params[:by] ||= 'name'
  end

  def initialize_at_where
    title_args[:where] = params[:where]
    pattern = clean_pattern(params[:location])
    self.join << :names
    self.where << "#{model.table_name}.where LIKE '%#{pattern}%'"
    params[:by] ||= 'name'
  end

  def initialize_in_species_list
    species_list = find_cached_parameter_instance(SpeciesList, :species_list)
    title_args[:species_list] = species_list.format_name
    self.join << :names
    self.join << :observations_species_lists
    self.where << "observations_species_lists.species_list_id = '#{params[:species_list]}'"
    params[:by] ||= 'name'
  end

  # ----------------------------------
  #  Queryies dealing with synonyms.
  # ----------------------------------

  def initialize_of_name
    name = find_cached_parameter_instance(Name, :name)

    synonyms     = params[:synonyms]     || :no
    nonconsensus = params[:nonconsensus] || :no

    title_args[:tag] = :query_title_of_name
    title_args[:tag] = :query_title_of_name_synonym      if synonyms != :no
    title_args[:tag] = :query_title_of_name_nonconsensus if nonconsensus != :no
    title_args[:name] = name.display_name

    if synonyms == :no
      name_ids = [name.id] + name.misspelling_ids
    elsif synonyms == :all
      name_ids = name.synonym_ids
    elsif synonyms == :exclusive
      name_ids = name.synonym_ids - [name.id] - name.misspelling_ids
    else
      raise "Invalid synonym inclusion mode: '#{synonyms}'"
    end
    set = clean_id_set(name_ids)

    if nonconsensus == :no
      self.where << "observations.name_id IN (#{set})"
      self.where << "observations.vote_cache >= 0"
      self.order = "observations.vote_cache DESC, observations.when DESC"
    elsif nonconsensus == :all
      self.where << "observations.name_id IN (#{set}) AND " +
                    "observations.vote_cache >= 0 OR " +
                    "namings.name_id IN (#{set}) AND " +
                    "namings.vote_cache >= 0"
      self.order = "IF(observations.vote_cache > namings.vote_cache, " +
                   "observations.vote_cache, namings.vote_cache) DESC, " +
                   "observations.when DESC"
    elsif nonconsensus == :exclusive
      self.where << "namings.name_id IN (#{set})"
      self.where << "namings.vote_cache >= 0"
      self.where << "observations.name_id NOT IN (#{set})"
      self.order = "namings.vote_cache DESC, observations.when DESC"
    else
      raise "Invalid nonconsensus inclusion mode: '#{nonconsensus}'"
    end

    # Different join conditions for different models.
    if model_symbol == :Observation
      if nonconsensus != :no
        self.join << :namings
      end

    elsif model_symbol == :Location
      if nonconsensus != :no
        self.join << :observations
      else
        self.join << {:observations => :namings}
      end
      self.where << "observations.is_collection_location IS TRUE"

    elsif model_symbol == :Image
      if nonconsensus == :no
        self.join << {:images_observations => :observations}
      else
        self.join << {:images_observations => {:observations => :namings}}
      end
    end
  end

  # --------------------------------------------
  #  Queries dealing with taxonomic hierarchy.
  # --------------------------------------------

  def initialize_of_children
    name = find_cached_parameter_instance(Name, :name)
    title_args[:name] = name.display_name
    all = params[:all]
    all = false if params[:all].nil?
    params[:by] ||= 'name'

    # If we have to rely on classification strings, just let Name do it, and
    # create a pseudo-query based on ids returned by +name.children+.
    if all || name.above_genus?
      set = clean_id_set(name.children(all).map(&:id))
      self.where << "names.id IN (#{set})"

    # If at genus or below, we can deduce hierarchy purely by syntax.
    else
      self.where << "names.text_name LIKE '#{name.text_name} %'"
      if !all
        if name.rank == :Genus
          self.where << "names.text_name NOT LIKE '#{name.text_name} % %'"
        else
          self.where << "names.text_name NOT LIKE '#{name.text_name} % % %'"
        end
      end
    end

    # Add appropriate joins.
    if model_symbol == :Observation
      self.join << :names
    elsif model_symbol == :Image
      self.join << {:images_observations => {:observations => :names}}
    elsif model_symbol == :Location
      self.join << {:observations => :names}
    end
  end

  def initialize_of_parents
    name = find_cached_parameter_instance(Name, :name)
    title_args[:name] = name.display_name
    all = params[:all] || false
    set = clean_id_set(name.parents(all).map(&:id))
    self.where << "names.id IN (#{set})"
    params[:by] ||= 'name'
  end

  # ---------------------------------------------------------------------
  #  Coercable image/location/name queries based on observation-related
  #  conditions.
  # ---------------------------------------------------------------------

  def initialize_with_observations
    if model_symbol == :Image
      self.join << {:images_observations => :observations}
    else
      self.join << :observations
    end
    params[:by] ||= 'name'
  end

  def initialize_with_observations_at_location
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    if model_symbol == :Image
      self.join << {:images_observations => :observations}
    else
      self.join << :observations
    end
    self.where << "observations.location_id = '#{params[:location]}'"
    self.where << 'observations.is_collection_location IS TRUE'
    params[:by] ||= 'name'
  end

  def initialize_with_observations_at_where
    location = params[:location]
    title_args[:where] = location
    if model_symbol == :Image
      self.join << {:images_observations => :observations}
    else
      self.join << :observations
    end
    self.where << "observations.where LIKE '%#{clean_pattern(location)}%'"
    self.where << 'observations.is_collection_location IS TRUE'
    params[:by] ||= 'name'
  end

  def initialize_with_observations_by_user
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    if model_symbol == :Image
      self.join << {:images_observations => :observations}
    else
      self.join << :observations
    end
    self.where << "observations.user_id = '#{params[:user]}'"
    if model_symbol == :Location
      self.where << 'observations.is_collection_location IS TRUE'
    end
    params[:by] ||= 'name'
  end

  def initialize_with_observations_in_set
    title_args[:observations] = params[:old_title] ||
      :query_title_in_set.t(:type => :observation)
    set = clean_id_set(params[:ids])
    if model_symbol == :Image
      self.join << {:images_observations => :observations}
    else
      self.join << :observations
    end
    self.where << "observations.id IN (#{set})"
    if model_symbol == :Location
      self.where << 'observations.is_collection_location IS TRUE'
    end
    params[:by] ||= 'name'
  end

  def initialize_with_observations_in_species_list
    species_list = find_cached_parameter_instance(SpeciesList, :species_list)
    title_args[:species_list] = species_list.format_name
    if model_symbol == :Image
      self.join << {:images_observations => {:observations => :observations_species_lists}}
    else
      self.join << {:observations => :observations_species_lists}
    end
    self.where << "observations_species_lists.species_list_id = '#{params[:species_list]}'"
    if model_symbol == :Location
      self.where << 'observations.is_collection_location IS TRUE'
    end
    params[:by] ||= 'name'
  end

  def initialize_with_observations_of_children
    initialize_of_children
  end

  def initialize_with_observations_of_name
    initialize_of_name
    title_args[:tag] = title_args[:tag].to_s.sub('title', 'title_with_observations').to_sym
  end

  # ---------------------------------------------------------------
  #  Coercable location/name queries based on description-related
  #  conditions.
  # ---------------------------------------------------------------

  def initialize_with_descriptions
    type = model.name.underscore
    self.join << :"#{type}_descriptions"
    params[:by] ||= 'name'
  end

  def initialize_with_descriptions_by_author
    initialize_with_descriptions_by_editor
  end

  def initialize_with_descriptions_by_editor
    type = model.name.underscore
    glue = flavor.to_s.sub(/^.*_by_/, '')
    desc_table = :"#{type}_descriptions"
    glue_table = :"#{type}_descriptions_#{glue}s"
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.join << { desc_table => glue_table }
    self.where << "#{glue_table}.user_id = '#{params[:user]}'"
    params[:by] ||= 'name'
  end

  def initialize_with_descriptions_by_user
    type = model.name.underscore
    desc_table = :"#{type}_descriptions"
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.join << desc_table
    self.where << "#{desc_table}.user_id = '#{params[:user]}'"
    params[:by] ||= 'name'
  end

  # ----------------------------
  #  Pattern search.
  # ----------------------------

  def initialize_pattern_search
    pattern = params[:pattern].to_s.strip_squeeze
    clean  = clean_pattern(pattern)
    search = google_parse(pattern)

    case model_symbol

      when :Comment
        self.where += google_conditions(search,
          'CONCAT(comments.summary,comments.comment)')

      when :Image
        self.join << {:images_observations => {:observations =>
          [:locations!, :names] }}
        self.where += google_conditions(search,
          'CONCAT(names.search_name,images.copyright_holder,images.notes,' +
          'IF(locations.id,locations.search_name,observations.where))')

      when :Location
        self.join << :"location_descriptions.default!"
        self.where << 'location_descriptions.public IS TRUE OR ' +
                      'location_descriptions.public IS NULL'
        note_fields = LocationDescription.all_note_fields.map do |x|
          "IF(location_descriptions.#{x} IS NULL, '', location_descriptions.#{x})"
        end
        self.where += google_conditions(search,
            "CONCAT(locations.search_name,#{note_fields.join(',')})")

      when :Name
        self.join << :"name_descriptions.default!"
        self.where << 'name_descriptions.public IS TRUE OR ' +
                      'name_descriptions.public IS NULL'
        note_fields = NameDescription.all_note_fields.map do |x|
          "IF(name_descriptions.#{x} IS NULL, '', name_descriptions.#{x})"
        end
        self.where += google_conditions(search,
            "CONCAT(names.search_name,#{note_fields.join(',')})")

      when :Observation
        self.join << [:locations!, :names]
        self.where += google_conditions(search,
          'CONCAT(names.search_name,observations.notes,' +
          'IF(locations.id,locations.search_name,observations.where))')

      when :Project
        self.where += google_conditions(search,
          'CONCAT(projects.title,projects.summary)')

      when :SpeciesList
        self.join << :locations!
        self.where += google_conditions(search,
          'CONCAT(species_lists.title,species_lists.notes,' +
          'IF(locations.id,locations.search_name,species_lists.where))')

      when :User
        self.where += google_conditions(search,
          'CONCAT(users.login,users.name)')

      else
        raise "Forgot to tell me how to build a :#{flavor} query for #{model}!"
      end
    end

  # ----------------------------
  #  Advanced search.
  # ----------------------------

  def initialize_advanced_search
    name     = google_parse(params[:name])
    user     = google_parse(params[:user].to_s.gsub(/ *<[^<>]*>/, ''))
    location = google_parse(params[:location])
    content  = google_parse(params[:content])

    # Force user to enter *something*.
    if name.blank? and user.blank? and location.blank? and content.blank?
      raise :runtime_no_conditions.t
    end

    # This case is a disaster.  Perform it as an observation query, then
    # coerce into images.
    if (model_symbol == :Image) and !content.blank?
      self.executor = lambda do |args|
        args2 = args.dup
        args2.delete(:select)
        params2 = params.dup
        params2.delete(:by)
        ids = self.class.lookup(:Observation, flavor, params2).result_ids(args2)
        ids = clean_id_set(ids)
        args2 = args.dup
        extend_join(args2)  << :images_observations
        extend_where(args2) << "images_observations.observation_id IN (#{ids})"
        model.connection.select_rows(query(args2))
      end
      return
    end

    case model_symbol
    when :Image
      self.join << {:images_observations => {:observations => :users}}      if !user.blank?
      self.join << {:images_observations => {:observations => :names}}      if !name.blank?
      self.join << {:images_observations => {:observations => :locations!}} if !location.blank?
      self.join << {:images_observations => :observations}                  if !content.blank?
    when :Location
      self.join << {:observations => :users} if !user.blank?
      self.join << {:observations => :names} if !name.blank?
      self.join << :observations             if !content.blank?
    when :Name
      self.join << {:observations => :users}      if !user.blank?
      self.join << {:observations => :locations!} if !location.blank?
      self.join << :observations                  if !content.blank?
    when :Observation
      self.join << :names      if !name.blank?
      self.join << :users      if !user.blank?
      self.join << :locations! if !location.blank?
    end

    # Name of mushroom...
    if !name.blank?
      self.where += google_conditions(name, 'names.search_name')
    end

    # Who observed the mushroom...
    if !user.blank?
      self.where += google_conditions(user, 'CONCAT(users.login,users.name)')
    end

    # Where the mushroom was seen...
    if !location.blank?
      if model_symbol == :Location
        self.where += google_conditions(location, 'locations.search_name')
      else
        self.where += google_conditions(location,
          'IF(locations.id,locations.search_name,observations.where)')
      end
    end

    # Content of observation and comments...
    if !content.blank?

      # # This was the old query using left outer join to include comments.
      # self.join << case model_symbol
      # when :Image       ; {:images_observations => {:observations => :comments!}}
      # when :Location    ; {:observations => :comments!}
      # when :Name        ; {:observations => :comments!}
      # when :Observation ; :comments!
      # end
      # self.where += google_conditions(content,
      #   'CONCAT(observations.notes,IF(comments.id,CONCAT(comments.summary,comments.comment),""))')

      # Cannot do left outer join from observations to comments, because it
      # will never return.  Instead, break it into two queries, one without
      # comments, and another with inner join on comments.
      self.executor = lambda do |args|
        args2 = args.dup
        extend_where(args2)
        args2[:where] += google_conditions(content, 'observations.notes')
        results = model.connection.select_rows(query(args2))

        args2 = args.dup
        extend_join(args2) << case model_symbol
        when :Image       ; {:images_observations => {:observations => :comments}}
        when :Location    ; {:observations => :comments}
        when :Name        ; {:observations => :comments}
        when :Observation ; :comments
        end
        extend_where(args2)
        args2[:where] += google_conditions(content,
          'CONCAT(observations.notes,comments.summary,comments.comment)')
        results |= model.connection.select_rows(query(args2))
      end
    end
  end

  # ----------------------------
  #  Nested queries.
  # ----------------------------

  def initialize_inside_observation
    obs = find_cached_parameter_instance(Observation, :observation)
    title_args[:observation] = obs.unique_format_name

    ids = []
    ids << obs.thumb_image_id if obs.thumb_image_id
    ids += obs.image_ids - [obs.thumb_image_id]
    initialize_in_set(ids)

    self.outer_id = params[:outer]

    # Tell it to skip observations with no images!
    self.tweak_outer_query = lambda do |outer|
      extend_join(outer.params) << :images_observations
    end
  end
end

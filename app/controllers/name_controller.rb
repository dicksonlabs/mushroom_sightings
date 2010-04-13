#
#  = Name Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  index_name::                  List of results of index/search.
#  list_names::                  Alphabetical list of all names, used or otherwise.
#  observation_index::           Alphabetical list of names people have seen.
#  names_by_user::               Alphabetical list of names created by given user.
#  names_by_editor::             Alphabetical list of names edited by given user.
#  name_search::                 Seach for string in name, notes, etc.
#  map::                         Show distribution map.
#  index_name_description::      List of results of index/search.
#  list_name_descriptions::      Alphabetical list of all name_descriptions, used or otherwise.
#  name_descriptions_by_author:: Alphabetical list of name_descriptions authored by given user.
#  name_descriptions_by_editor:: Alphabetical list of name_descriptions edited by given user.
#  show_name::                   Show info about name.
#  show_past_name::              Show past versions of name info.
#  prev_name::                   Show previous name in index.
#  next_name::                   Show next name in index.
#  show_name_description::       Show info about name_description.
#  show_past_name_description::  Show past versions of name_description info.
#  prev_name_description::       Show previous name_description in index.
#  next_name_description::       Show next name_description in index.
#  create_name::                 Create new name.
#  edit_name::                   Edit name.
#  create_name_description::     Create new name_description.
#  edit_name_description::       Edit name_description.
#  destroy_name_description::    Destroy name_description.
#  make_description_default::    Make a description the default one.
#  merge_descriptions::          Merge a description with another.
#  publish_description::         Publish a draft description.
#  adjust_permissions::          Adjust permissions on a description.
#  change_synonyms::             Change list of synonyms for a name.
#  deprecate_name::              Deprecate name in favor of another.
#  approve_name::                Flag given name as "accepted" (others could be, too).
#  bulk_name_edit::              Create/synonymize/deprecate a list of names.
#
#  ==== Helpers
#  deprecate_synonym::         (used by change_synonyms)
#  check_for_new_synonym::     (used by change_synonyms)
#  dump_sorter::               Error diagnostics for change_synonyms.
#
################################################################################

class NameController < ApplicationController
  include DescriptionControllerHelpers

  before_filter :login_required, :except => [
    :advanced_search,
    :authored_names,
    :eol,
    :eol_preview,
    :index_name,
    :index_name_description,
    :map,
    :list_name_descriptions,
    :list_names,
    :name_search,
    :name_descriptions_by_author,
    :name_descriptions_by_editor,
    :names_by_user,
    :names_by_editor,
    :needed_descriptions,
    :next_name,
    :next_name_description,
    :observation_index,
    :prev_name,
    :prev_name_description,
    :show_name,
    :show_name_description,
    :show_past_name,
    :show_past_name_description,
    :test_index,
  ]

  before_filter :disable_link_prefetching, :except => [
    :approve_name,
    :bulk_name_edit,
    :change_synonyms,
    :create_name,
    :create_name_description,
    :deprecate_name,
    :edit_name,
    :edit_name_description,
    :show_name,
    :show_name_description,
    :show_past_name,
    :show_past_name_description,
  ]

  ##############################################################################
  #
  #  :section: Indexes and Searches
  #
  ##############################################################################

  # Display list of names in last index/search query.
  def index_name # :nologin: :norobots:
    query = find_or_create_query(:Name, :by => params[:by])
    show_selected_names(query, :id => params[:id], :always_index => true)
  end

  # Display list of all (correctly-spelled) names in the database.
  def list_names # :nologin:
    query = create_query(:Name, :all, :by => :name)
    show_selected_names(query)
  end

  # Display list of names that have observations.
  def observation_index # :nologin: :norobots:
    query = create_query(:Name, :with_observations)
    show_selected_names(query)
  end

  # Display list of names that have authors.
  def authored_names # :nologin: :norobots:
    query = create_query(:Name, :with_descriptions)
    show_selected_names(query)
  end

  # Display list of names that a given user is author on.
  def names_by_user # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id]) : @user
      query = create_query(:Name, :by_user, :user => user)
      show_selected_names(query)
    end
  end

  # Display list of names that a given user is editor on.
  def names_by_editor # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id]) : @user
      query = create_query(:Name, :by_editor, :user => user)
      show_selected_names(query)
    end
  end

  # Display list of the most popular 100 names that don't have descriptions.
  def needed_descriptions # :nologin: :norobots:
    # NOTE!! -- all this extra info and help will be lost if user re-sorts.
    data = Name.connection.select_rows %(
      SELECT names.id, name_counts.count
      FROM names LEFT OUTER JOIN descriptions ON names.id = descriptions.name_id,
           (SELECT count(*) AS count, name_id
            FROM observations group by name_id) AS name_counts
      WHERE names.id = name_counts.name_id
        AND names.rank = 'Species'
        AND (names.gen_desc IS NULL OR names.gen_desc = '')
        AND name_counts.count > 1
        AND descriptions.name_id IS NULL
        AND CURRENT_TIMESTAMP - modified > #{1.week.to_i}
      ORDER BY name_counts.count DESC, names.search_name ASC
      LIMIT 100
    )
    @help = :needed_descriptions_help
    query = create_query(:Name, :in_set, :ids => data.map(&:first),
                         :title => ":needed_descriptions_title")
    show_selected_names(query, :num_per_page => 100) do |name|
      # Add number of observations (parenthetically).
      row = data.select {|id,count| id == name.id}.first
      row ? "(#{count} #{:observations.t})" : ''
    end
  end

  # Display list of names that match a string.
  def name_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) and
       (name = Name.safe_find(pattern))
      redirect_to(:action => 'show_name', :id => name.id)
    else
      query = create_query(:Name, :pattern_search, :pattern => pattern)
      show_selected_names(query)
    end
  end

  # Displays list of advanced search results.
  def advanced_search # :nologin: :norobots:
    begin
      query = find_query(:Name)
      show_selected_names(query)
    rescue => err
      flash_error(err)
      redirect_to(:controller => 'observer', :action => 'advanced_search_form')
    end
  end

  # Used to test pagination.
  def test_index # :nologin: :norobots:
    query = find_query(:Name) or raise "Missing query: #{params[:q]}"
    if params[:test_anchor]
      @test_pagination_args = {:anchor => params[:test_anchor]}
    end
    show_selected_names(query, :num_per_page => params[:num_per_page].to_i)
  end

  # Show selected search results as a list with 'list_names' template.
  def show_selected_names(query, args={})
    store_query_in_session(query)
    @links ||= []
    args = {
      :action => 'list_names',
      :letters => 'names.text_name',
      :num_per_page => (params[:letter].to_s.match(/^[a-z]/i) ? 500 : 50),
    }.merge(args)

    # Tired of not having an easy link to list_names.
    if query.flavor == :with_observations
      @links << [:all_objects.t(:type => :name), { :action => 'list_names' }]
    end

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name',      :sort_by_name.t],
      ['created',   :sort_by_created.t],
      [(query.flavor == :by_rss_log ? 'rss_log' : 'modified'),
                    :sort_by_modified.t],
      ['num_views', :sort_by_num_views.t],
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

    # Add "show descriptions" link if this query can be coerced into a
    # description query.
    if query.is_coercable?(:NameDescription)
      @links << [:show_objects.t(:type => :description), {
                  :action => 'index_name_description',
                  :params => query_params(query),
                }]
    end

    # Add some extra fields to the index for authored_names.
    if query.flavor == :with_descriptions
      show_index_of_objects(query, args) do |name|
        if desc = name.description
          [ desc.authors.map(&:login).join(', '),
            desc.note_status.map(&:to_s).join('/'),
            :"review_#{desc.review_status}".t ]
        else
          []
        end
      end
    else
      show_index_of_objects(query, args)
    end
  end

  ##############################################################################
  #
  #  :section: Description Indexes and Searches
  #
  ##############################################################################

  # Display list of names in last index/search query.
  def index_name_description # :nologin: :norobots:
    query = find_or_create_query(:NameDescription, :by => params[:by])
    show_selected_name_descriptions(query, :id => params[:id],
                                    :always_index => true)
  end

  # Display list of all (correctly-spelled) name_descriptions in the database.
  def list_name_descriptions # :nologin:
    query = create_query(:NameDescription, :all, :by => :name)
    show_selected_name_descriptions(query)
  end

  # Display list of name_descriptions that a given user is author on.
  def name_descriptions_by_author # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id]) : @user
      query = create_query(:NameDescription, :by_author, :user => user)
      show_selected_name_descriptions(query)
    end
  end

  # Display list of name_descriptions that a given user is editor on.
  def name_descriptions_by_editor # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id]) : @user
      query = create_query(:NameDescription, :by_editor, :user => user)
      show_selected_name_descriptions(query)
    end
  end

  # Show selected search results as a list with 'list_names' template.
  def show_selected_name_descriptions(query, args={})
    store_query_in_session(query)
    @links ||= []
    args = {
      :action => 'list_name_descriptions',
      :num_per_page => 50
    }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name',      :sort_by_name.t],
      ['created',   :sort_by_created.t],
      ['modified',  :sort_by_modified.t],
      ['num_views', :sort_by_num_views.t],
    ]

    # Add "show names" link if this query can be coerced into an
    # observation query.
    if query.is_coercable?(:Name)
      @links << [:show_objects.t(:type => :name), {
                  :action => 'index_name',
                  :params => query_params(query),
                }]
    end

    show_index_of_objects(query, args)
  end

  ################################################################################
  #
  #  :section: Show Name
  #
  ################################################################################

  # Show a Name, one of its NameDescription's, associated taxa, and a bunch of
  # relevant Observations.
  def show_name # :nologin: :prefetch:
    pass_query_params
    store_location
    clear_query_in_session

    # Load Name and NameDescription along with a bunch of associated objects.
    name_id = params[:id]
    desc_id = params[:desc]
    if @name = find_or_goto_index(Name, name_id,
                                  :include => [:user, :descriptions])

      # Display default description if user didn't request one explicitly.
      desc_id = @name.description_id if desc_id.blank?
      if desc_id.blank?
        @description = nil
      elsif @description = NameDescription.safe_find(desc_id, :include =>
                                         [:authors, :editors, :license, :user])
        @description = nil if !@description.is_reader?(@user)
      else
        flash_error(:runtime_object_not_found.t(:type => :description,
                                                :id => desc_id))
      end

      update_view_stats(@name)
      update_view_stats(@description) if @description

      # Get a list of projects the user can create drafts for.
      @projects = @user && @user.projects_member.select do |project|
        !@name.descriptions.any? {|d| d.belongs_to_project?(project)}
      end

      # Get list of immediate parents.
      @parents = @name.parents

      # Create query for immediate children.
      @children_query = create_query(:Name, :of_children, :name => @name)

      # Create search queries for observation lists.
      @consensus_query = create_query(:Observation, :of_name, :name => @name,
                                      :by => :confidence)
      @synonym_query = create_query(:Observation, :of_name, :name => @name,
                                    :synonyms => :exclusive,
                                    :by => :confidence)
      @other_query = create_query(:Observation, :of_name, :name => @name,
                                  :synonyms => :all, :nonconsensus => :exclusive,
                                  :by => :confidence)
      if @name.below_genus?
        @subtaxa_query = create_query(:Observation, :of_children, :name => @name,
                                      :all => true, :by => :confidence)
      end

      # Paginate each of the sections independently.
      @children_pages  = paginate_numbers(:children_page, 24)
      @consensus_pages = paginate_numbers(:consensus_page, 12)
      @synonym_pages   = paginate_numbers(:synonym_page, 12)
      @other_pages     = paginate_numbers(:other_page, 12)
      if @subtaxa_query
        @subtaxa_pages = paginate_numbers(:subtaxa_page, 12)
      end

      args = { :include => [:name, :location, :thumb_image, :user] }
      @children_data  = @children_query.paginate(@children_pages)
      @consensus_data = @consensus_query.paginate(@consensus_pages, args)
      @synonym_data   = @synonym_query.paginate(@synonym_pages, args)
      @other_data     = @other_query.paginate(@other_pages, args)
      if @subtaxa_query
        @subtaxa_data = @subtaxa_query.paginate(@subtaxa_pages, args)
      end
    end
  end

  # Show just a NameDescription.
  def show_name_description # :nologin: :prefetch:
    store_location
    pass_query_params
    if @description = find_or_goto_index(NameDescription, params[:id],
                        :include => [:authors, :editors, :license, :reviewer,
                                     :user, {:name=>:descriptions}])

      # Public or user has permission.
      if @description.is_reader?(@user)
        @name = @description.name
        update_view_stats(@description)

        # Get a list of projects the user can create drafts for.
        @projects = @user && @user.projects_member.select do |project|
          !@name.descriptions.any? {|d| d.belongs_to_project?(project)}
        end

      # User doesn't have permission to see this description.
      else
        if @description.source_type == :project
          flash_error(:runtime_show_draft_denied.t)
          if project = @description.project
            redirect_to(:controller => 'project', :action => 'show_project',
                        :id => project.id)
          else
            redirect_to(:action => 'show_name', :id => @description.name_id)
          end
        else
          flash_error(:runtime_show_description_denied.t)
          redirect_to(:action => 'show_name', :id => @description.name_id)
        end
      end
    end
  end

  # Show past version of Name.  Accessible only from show_name page.
  def show_past_name # :nologin: :prefetch: :norobots:
    pass_query_params
    store_location
    if @name = find_or_goto_index(Name, params[:id])
      @name.revert_to(params[:version].to_i)

      # Old correct spellings could have gotten merged with something else and no longer exist.
      if @name.is_misspelling?
        @correct_spelling = Name.connection.select_value %(
          SELECT display_name FROM names WHERE id = #{@name.correct_spelling_id}
        )
      else
        @correct_spelling = ''
      end
    end
  end

  # Show past version of NameDescription.  Accessible only from
  # show_name_description page.
  def show_past_name_description # :nologin: :prefetch: :norobots:
    pass_query_params
    store_location
    if @description = find_or_goto_index(NameDescription, params[:id])
      if params[:merge_source_id].blank?
        @description.revert_to(params[:version].to_i)
      else
        @merge_source_id = params[:merge_source_id]
        version = NameDescription::Version.find(@merge_source_id)
        @old_parent_id = version.name_description_id
        subversion = params[:version]
        if !subversion.blank? and
           (version.version != subversion.to_i)
          version = NameDescription::Version.
            find_by_version_and_name_description_id(params[:version], @old_parent_id)
        end
        @description.clone_versioned_model(version, @description)
      end
    end
  end

  # Go to next name: redirects to show_name.
  def next_name # :nologin: :norobots:
    redirect_to_next_object(:next, Name, params[:id])
  end

  # Go to previous name: redirects to show_name.
  def prev_name # :nologin: :norobots:
    redirect_to_next_object(:prev, Name, params[:id])
  end

  # Go to next name: redirects to show_name.
  def next_name_description # :nologin: :norobots:
    redirect_to_next_object(:next, NameDescription, params[:id])
  end

  # Go to previous name_description: redirects to show_name_description.
  def prev_name_description # :nologin: :norobots:
    redirect_to_next_object(:prev, NameDescription, params[:id])
  end

  # Callback to let reviewers change the review status of a Name from the
  # show_name page.
  def set_review_status # :norobots:
    pass_query_params
    id = params[:id]
    desc = NameDescription.find(id)
    if is_reviewer?
      desc.update_review_status(params[:value])
    end
    redirect_to(:action => 'show_name', :id => desc.name_id,
                :params => query_params)
  end

  ##############################################################################
  #
  #  :section: Create and Edit
  #
  ##############################################################################

  # Create a new name; accessible from name indexes.
  def create_name # :prefetch: :norobots:
    store_location
    pass_query_params

    # Reder a blank form.
    if request.method != :post
      @name = Name.new
      @name.rank = :Species
      @can_make_changes = true

    else
      begin
        # Look up name to see if it already exists.
        text_name = params[:name][:text_name].to_s.strip_squeeze
        author    = params[:name][:author].to_s.strip_squeeze
        name_str  = text_name
        matches   = nil
        if !author.blank?
          matches = Name.find_all_by_text_name_and_author(text_name, author)
          name_str += " #{author}"
        else
          matches = Name.find_all_by_text_name(text_name)
        end

        # Name already exists.
        if matches.length > 0
          flash_error(:runtime_name_create_already_exists.t(:name => name_str))
          name = matches[0]

        # Create name.
        else
          # This returns a list of names starting with genus, on down to the
          # given name: genus, species, variety, ...
          names = Name.names_from_string(name_str)
          name = names.last
          raise(:runtime_unable_to_create_name.t(:name => name_str)) if !name

          # Not quite right since names_from_string sets rank too.  I don't
          # understand the subtlety of this. -JPH
          name.rank = rank = params[:name][:rank].to_s

          # This fills in the four name formats.
          name.change_text_name(text_name, author, rank)

          # I guess this is all that's left.
          name.citation = params[:name][:citation]

          # This saves this name, and genus/species above it as necessary.
          for n in names
            save_name(n, :log_name_updated) if n
          end
        end

      # Anything causing changes not to get saved ends up here.
      rescue RuntimeError => err
        @name = Name.new
        flash_error(err.to_s) if !err.nil?
        flash_object_errors(@name)
        @name.attributes = params[:name]
        @can_make_changes = true

      else
        # If no errors occurred, either the name was created successfully, or
        # it already exists.  In either case redirect to the name in question.
        redirect_to(:action => 'show_name', :id => name.id,
                    :params => query_params)
      end
    end
  end

  # Make changes to name; accessible from show_name page.
  def edit_name # :prefetch: :norobots:
    store_location
    pass_query_params
    @name = Name.find(params[:id])

    # Initialize misspelling fields.  Start with just a checkbox.  If user
    # checks it, it guesses the correct spelling.  If it fails to guess, it
    # flashes an error, and subsequent times through it presents a text field
    # (with auto-completer).
    @misspelling = false
    if @name.is_misspelling? || (params[:name] && params[:name][:misspelling] == '1')
      @name.misspelling = true
      @name_primer = Name.primer
    end

    # Only allowed to make substantive changes if you own all the references
    # to it.  I think checking that the user owns all the namings that use it
    # is correct.  Maybe we should also check observations?  But the
    # observation simply caches the winning naming's name.  Actually not
    # necessarily: obs might use the accepted name if the winning name is
    # deprecated.  Hmmm, I'll check it to be safe.
    @can_make_changes = true
    if !is_in_admin_mode?
      for obj in @name.namings + @name.observations
        if obj.user_id != @user.id
          @can_make_changes = false
          break
        end
      end
    end

    if request.method == :post
      any_errors = false
      begin
        # Look up name to see if it already exists.
        text_name = params[:name][:text_name].to_s.strip_squeeze
        author    = params[:name][:author].to_s.strip_squeeze
        rank      = params[:name][:rank].to_s
        name_str  = text_name
        matches   = nil
        if !author.blank?
          matches = Name.find_all_by_text_name_and_author(text_name, author)
          name_str += " #{author}"
        else
          matches = Name.find_all_by_text_name(text_name)
        end

        # Take first one that isn't us if there are several matches.  This is
        # the name that we will merge this name into.
        merge = nil
        for match in matches || []
          if match.id != @name.id
            merge = match
            break
          end
        end

        # Merge this name into another.
        if merge
          # Swap order if only one is mergable.
          if !@name.mergable? && merge.mergable?
            @name, merge = merge, @name
          end

          # Admins can actually merge them, then redirect to other location.
          if is_in_admin_mode? || @name.mergable?

            # Copy over any info this name has that the other name doesn't.
            # Use other name's info where there's conflict.  (Reason: this is
            # most often used to *get rid* of a misspelt name, such names are
            # frequently accidentally created, often with incorrect rank and
            # bogus author.)
            if merge.author.blank?
              merge.author = author
            end
            if merge.citation.blank?
              merge.citation = params[:name][:citation].to_s.strip_squeeze
            end
            if merge.notes.blank?
              merge.notes = params[:name][:notes].to_s.strip rescue ''
            end
            if params[:name][:deprecated] != '1'
              merge.deprecated = false
            end
            merge.change_text_name(merge.text_name, merge.author, merge.rank,
                                   :save_parents)

            merge.merge(@name)
            save_name(merge, :log_name_updated) if merge.changed?
            flash_notice(:runtime_edit_name_merge_success.t(
              :this => @name.search_name, :that => merge.search_name))
            @name = merge

          # Non-admins just send email-request to admins.
          else
            flash_warning(:runtime_merge_names_warning.t)
            content = :email_name_merge.t(:user => @user.login,
                      :this => @name.display_name, :that => merge.display_name)
            AccountMailer.deliver_webmaster_question(@user.email, content)
          end

        # Not merging.
        else
          # This can be blank if name in use and therefore not editable.
          if !text_name.blank?
            @name.change_text_name(text_name, author, rank, :save_parents)
          end

          @name.citation = params[:name][:citation].to_s.strip_squeeze rescue ''
          @name.notes = params[:name][:notes].to_s.strip rescue ''

          # Let user call this name a misspelling.
          @misspelling = (params[:name][:misspelling] == '1') rescue false
          @correct_spelling = params[:name][:correct_spelling].to_s.strip_squeeze rescue ''
          if !update_correct_spelling(@name, @misspelling, @correct_spelling)
            # In case of error, save the rest of the changes, but stay in form.
            any_errors = true
          end

          # Save any changes.
          if !@name.changed?
            flash_warning(:runtime_edit_name_no_change.t)
          elsif !save_name(@name, :log_name_updated)
            raise(:runtime_unable_to_save_changes.t)
          else
            flash_notice(:runtime_edit_name_success.t(
                         :name => @name.search_name))
          end
        end

      rescue RuntimeError => err
        # Anything causing changes not to get saved ends up here.
        flash_error(err.to_s) if !err.nil?
        flash_object_errors(@name)
        @name.attributes = params[:name]

      else
        if !any_errors
          # If no errors occurred, assume changes were made successfully.
          redirect_to(:action => 'show_name', :id => @name.id,
                      :params => query_params)
        end
      end
    end
  end

  def create_name_description # :prefetch: :norobots:
    store_location
    pass_query_params
    @name = Name.find(params[:id])
    @licenses = License.current_names_and_ids

    # Render a blank form.
    if request.method == :get
      @description = NameDescription.new
      @description.name = @name
      initialize_description_source(@description)

    # Create new description.
    else
      @description = NameDescription.new
      @description.name = @name
      @description.attributes = params[:description]

      if @description.valid?
        initialize_description_permissions(@description)
        @description.save

        Transaction.post_name_description(
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

        # Make this the "default" description if there isn't one and this is
        # publicly readable.
        if !@name.description and
           @description.public
          @name.description = @description
        end

        # Keep the parent's classification cache up to date.
        if (@name.description == @description) and
           (@name.classification != @description.classification)
          @name.classification = @description.classification
        end

        # Log action in parent name.
        @description.name.log(:log_description_created,
                 :user => @user.login, :touch => true,
                 :name => @description.unique_partial_format_name)

        # Save any changes to parent name.
        @name.save if @name.changed?

        flash_notice(:runtime_name_description_success.t(
                     :id => @description.id))
        redirect_to(:action => 'show_name_description',
                    :id => @description.id)

      else
        flash_object_errors @description
      end
    end
  end

  def edit_name_description # :prefetch: :norobots:
    store_location
    pass_query_params
    @description = NameDescription.find(params[:id])
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
      for field in NameDescription.all_note_fields
        if @description.send("#{field}_changed?")
          args["set_#{field}".to_sym] = @description.send(field)
        end
      end

      # Modify permissions based on changes to the two "public" checkboxes.
      modify_description_permissions(@description, args)

      # If substantive changes are made by a reviewer, call this act a
      # "review", even though they haven't actually changed the review
      # status.  If it's a non-reviewer, this will revert it to "unreviewed".
      if @description.save_version?
        @description.update_review_status(@description.review_status)
      end

      # No changes made.
      if args.empty?
        flash_warning(:runtime_edit_name_description_no_change.t)
        redirect_to(:action => 'show_name_description',
                    :id => @description.id)

      # There were error(s).
      elsif !@description.save
        flash_object_errors(@description)

      # Updated successfully.
      else
        flash_notice(:runtime_edit_name_description_success.t(
                     :id => @description.id))

        if !args.empty?
          args[:id] = @description
          Transaction.put_name_description(args)
        end

        # Update name's classification cache.
        name = @description.name
        if (name.description == @description) and
           (name.classification != @description.classification)
          name.classification = @description.classification
          name.save
        end

        # Log action to parent name.
        name.log(:log_description_updated, :touch => true, :user => @user.login,
                 :name => @description.unique_partial_format_name)

        # Delete old description after resolving conflicts of merge.
        if (params[:delete_after] == 'true') and
           (old_desc = NameDescription.safe_find(params[:old_desc_id]))
          v = @description.versions.latest
          v.merge_source_id = old_desc.versions.latest.id
          v.save
          if !old_desc.is_admin?(@user)
            flash_warning(:runtime_description_merge_delete_denied.t)
          else
            flash_notice(:runtime_description_merge_deleted.
                           t(:old => old_desc.partial_format_name))
            name.log(:log_object_merged_by_user,
                     :user => @user.login, :touch => true,
                     :from => old_desc.unique_partial_format_name,
                     :to => @description.unique_partial_format_name)
            old_desc.destroy
          end
        end

        redirect_to(:action => 'show_name_description',
                    :id => @description.id)
      end
    end
  end

  def destroy_name_description # :norobots:
    pass_query_params
    @description = NameDescription.find(params[:id])
    if @description.is_admin?(@user)
      flash_notice(:runtime_destroy_description_success.t)
      @description.name.log(:log_description_destroyed,
               :user => @user.login, :touch => true,
               :name => @description.unique_partial_format_name)
      @description.destroy
      redirect_to(:action => 'show_name', :id => @description.name_id,
                  :params => query_params)
    else
      flash_error(:runtime_destroy_description_not_admin.t)
      if @description.is_reader?(@user)
        redirect_to(:action => 'show_name_description', :id => @description.id,
                    :params => query_params)
      else
        redirect_to(:action => 'show_name', :id => @description.name_id,
                    :params => query_params)
      end
    end
  end

  # Update the misspelling status.
  #
  # name::             Name whose status we're changing.
  # misspelling::      Boolean: is the "this is a misspelling" box checked?
  # correct_spelling:: String: the correct name, as entered by the user.
  #
  # 1) If the checkbox is unchecked, it clears all the misspelling stuff.
  # 2) If the checkbox is checked and a name is entered, it validates it.
  # 3) If the checkbox is checked but no name entered, it tries to guess.
  #
  # There are no side-effects (except that the "correct name" is marked as "not
  # a misspelling").  All changes are made (but not saved) to +name+.  It
  # returns true if everything went well.  If anything at all fails, it clears
  # all the misspelling stuff in +name+, prints an error message and makes the
  # user fix whatever it is.
  #
  def update_correct_spelling(name, misspelling, correct_spelling)
    result = true

    # Clear status if checkbox unchecked.
    if !misspelling
      name.misspelling = false
      name.correct_spelling = nil

    else
      name2 = nil

      # User has told us what the correct spelling should be.  Make sure
      # this is a valid name!
      if correct_spelling.blank?
        name.misspelling = true
        name2 = Name.find_by_search_name(correct_spelling)
        name2 ||= Name.find_by_text_name(correct_spelling)
        if !name2
          flash_error(:runtime_form_names_misspelling_bad.t)
        elsif result.id == self.id
          flash_error(:runtime_form_names_misspelling_same.t)
        end

        # User just checked the box, but didn't tell us the correct
      else
        # answer -- let's see if we can guess it before complaining.
        begin
          name2 = name.guess_correct_spelling
        rescue => err
          flash_error(err)
        end
      end

      # Found a good name: make that the correct spelling for this one.
      if name2
        name.misspelling = true
        name.correct_spelling = name2
        name.merge_synonyms(name2)
        name.change_deprecated(true)

        # Make sure the "correct" name isn't also a misspelled name!
        if name2.is_misspelling?
          name2.correct_spelling = nil
          save_name(name2, :log_name_unmisspelled, :other => name.display_name)
        end

      # If anything at all goes wrong, clear the misspelling and make the
      # user fix whatever it was.
      else
        name.misspelling = false
        name.correct_spelling = nil
        result = false
      end
    end

    return result
  end

  ################################################################################
  #
  #  :section: Synonymy
  #
  ################################################################################

  # Form accessible from show_name that lets a user review all the synonyms
  # of a name, removing others, writing in new, etc.
  def change_synonyms # :prefetch: :norobots:
    pass_query_params
    @name = Name.find(params[:id])
    @list_members     = nil
    @new_names        = nil
    @synonym_name_ids = []
    @synonym_names    = []
    @deprecate_all    = true
    if request.method == :post
      list = params[:synonym][:members].strip_squeeze
      @deprecate_all = (params[:deprecate][:all] == '1')

      # Create any new names that have been approved.
      construct_approved_names(list, params[:approved_names], @deprecate_all)

      # Parse the write-in list of names.
      sorter = NameSorter.new
      sorter.sort_names(list)
      sorter.append_approved_synonyms(params[:approved_synonyms])

      # Are any names unrecognized (only unapproved names will still be
      # unrecognized at this point) or ambiguous?
      if !sorter.only_single_names
        dump_sorter(sorter)
      # Has the user NOT had a chance to choose from among the synonyms of any
      # names they've written in?
      elsif !sorter.only_approved_synonyms
        flash_notice :name_change_synonyms_confirm.t
      else
        now = Time.now

        # Create synonym and add this name to it if this name not already
        # associated with a synonym.
        if !@name.synonym_id
          @name.synonym = Synonym.create
          @name.save
          Transaction.post_synonym(
            :id => @name.synonym
          )
          Transaction.put_name(
            :id          => @name,
            :set_synonym => @name.synonym
          )
        end

        # Go through list of all synonyms for this name and written-in names.
        # Exclude any names that have un-checked check-boxes: newly written-in
        # names will not have a check-box yet, names written-in in previous
        # attempt to submit this form will have checkboxes and therefore must
        # be checked to proceed -- the default initial state.
        proposed_synonyms = params[:proposed_synonyms] || {}
        for n in sorter.all_synonyms
          # Synonymize all names that have been checked, or that don't have
          # checkboxes.
          if proposed_synonyms[n.id.to_s] != '0'
            if n.synonym_id != @name.synonym_id
              @name.transfer_synonym(n)
              Transaction.put_name(
                :id          => n,
                :set_synonym => @name.synonym
              )
            end
          end
        end

        # De-synonymize any old synonyms in the "existing synonyms" list that
        # have been unchecked.  This creates a new synonym to connect them if
        # there are multiple unchecked names -- that is, it splits this
        # synonym into two synonyms, with checked names staying in this one,
        # and unchecked names moving to the new one.
        check_for_new_synonym(@name, @name.synonyms, params[:existing_synonyms] || {})

        # Deprecate everything if that check-box has been marked.
        success = true
        if @deprecate_all
          for n in sorter.all_names
            if !deprecate_synonym(n)
              # Already flashed error message.
              success = false
            end
          end
        end

        if success
          redirect_to(:action => 'show_name', :id => @name.id,
                      :params => query_params)
        else
          flash_object_errors(@name)
          flash_object_errors(@name.synonym)
        end
      end

      @list_members     = sorter.all_line_strs.join("\r\n")
      @new_names        = sorter.new_name_strs.uniq
      @synonym_name_ids = sorter.all_synonyms.map(&:id)
      @synonym_names    = @synonym_name_ids.map {|id| Name.find(id)}
    end
  end

  # Form accessible from show_name that lets the user deprecate a name in favor
  # of another name.
  def deprecate_name # :prefetch: :norobots:
    pass_query_params

    # These parameters aren't always provided.
    params[:proposed]    ||= {}
    params[:comment]     ||= {}
    params[:chosen_name] ||= {}
    params[:is]          ||= {}

    @name    = Name.find(params[:id])
    @what    = params[:proposed][:name].to_s.strip_squeeze rescue ''
    @comment = params[:comment][:comment].to_s.strip_squeeze rescue ''

    @list_members     = nil
    @new_names        = []
    @synonym_name_ids = []
    @synonym_names    = []
    @deprecate_all    = '1'
    @names            = []
    @misspelling      = (params[:is][:misspelling] == '1')
    @name_primer      = Name.primer

    if request.method == :post
      if @what.blank?
        flash_error :runtime_name_deprecate_must_choose.t

      else
        # Find the chosen preferred name.
        if params[:chosen_name][:name_id]
          @names = [Name.find(params[:chosen_name][:name_id])]
        else
          @names = Name.find_names(@what)
        end
        if @names.empty? and
           (new_name = create_needed_names(params[:approved_name], @what))
          @names = [new_name]
        end
        target_name = @names.first

        # No matches: try to guess.
        if @names.empty?
          @valid_names = guess_correct_name(@what)
          @suggest_corrections = true

        # If written-in name matches uniquely an existing name:
        elsif target_name && @names.length == 1
          now = Time.now

          # Merge this name's synonyms with the preferred name's synonyms.
          @name.merge_synonyms(target_name)

          # Change target name to "undeprecated".
          target_name.change_deprecated(false)
          save_name(target_name, :log_name_approved,
                    :other => @name.search_name)

          # Change this name to "deprecated", set correct spelling, add note.
          @name.change_deprecated(true)
          if @misspelling
            @name.misspelling = true
            @name.correct_spelling = target_name
          end
          save_name(@name, :log_name_deprecated,
                    :other => target_name.search_name)
          if !@comment.blank?
            post_comment(:deprecate, @name, @comment)
          end

          redirect_to(:action => 'show_name', :id => @name.id,
                      :params => query_params)
        end

      end # @what
    end # :post
  end

  # Form accessible from show_name that lets a user make call this an accepted
  # name, possibly deprecating its synonyms at the same time.
  def approve_name # :prefetch: :norobots:
    pass_query_params
    @name = Name.find(params[:id])
    @approved_names = @name.approved_synonyms
    comment = params[:comment][:comment] rescue ''
    comment = comment.strip_squeeze
    if request.method == :post

      # Deprecate others first.
      others = []
      if params[:deprecate][:others] == '1'
        for n in @name.approved_synonyms
          n.change_deprecated(true)
          save_name(n, :log_name_deprecated, :other => @name.search_name)
          others << n.search_name
        end
      end

      # Approve this now.
      @name.change_deprecated(false)
      tag = :log_approved_by
      args = {}
      if others != []
        tag = :log_name_approved
        args[:other] = others.join(', ')
      end
      save_name(@name, tag, args)
      if !comment.blank?
        post_comment(:approve, @name, comment)
      end

      redirect_to(:action => 'show_name', :id => @name.id,
                  :params => query_params)
    end
  end

  # Helper used by change_synonyms.  Deprecates a single name.  Returns true
  # if it worked.  Flashes an error and returns false if it fails for whatever
  # reason.
  def deprecate_synonym(name)
    result = true
    unless name.deprecated
      begin
        name.change_deprecated(true)
        result = save_name(name, :log_deprecated_by)
      rescue RuntimeError => err
        flash_error(err.to_s)
        result = false
      end
    end
    return result
  end

  # If changing the synonyms of a name that already has synonyms, the user is
  # presented with a list of "existing synonyms".  This is a list of check-
  # boxes.  They all start out checked.  If the user unchecks one, then that
  # name is removed from this synonym.  If the user unchecks several, then a
  # new synonym is created to synonymize all those names.
  def check_for_new_synonym(name, candidates, checks)
    new_synonym_members = []
    # Gather all names with un-checked checkboxes.
    for n in candidates
      if (name != n) && (checks[n.id.to_s] == '0')
        new_synonym_members.push(n)
      end
    end
    len = new_synonym_members.length
    if len > 1
      name = new_synonym_members.shift
      name.synonym = new_synonym = Synonym.create
      name.save
      Transaction.post_synonym(
        :id => new_synonym
      )
      Transaction.put_name(
        :id          => name,
        :set_synonym => new_synonym
      )
      for n in new_synonym_members
        name.transfer_synonym(n)
        Transaction.put_name(
          :id          => n,
          :set_synonym => new_synonym
        )
      end
    elsif len == 1
      name = new_synonym_members.first
      name.clear_synonym
      Transaction.put_name(
        :id          => name,
        :set_synonym => 0
      )
    end
  end

  def dump_sorter(sorter)
    logger.warn("tranfer_synonyms: only_single_names or only_approved_synonyms is false")
    logger.warn("New names:")
    for n in sorter.new_line_strs
      logger.warn(n)
    end
    logger.warn("\nSingle names:")
    for n in sorter.single_line_strs
      logger.warn(n)
    end
    logger.warn("\nMultiple names:")
    for n in sorter.multiple_line_strs
      logger.warn(n)
    end
    if sorter.chosen_names
      logger.warn("\nChosen names:")
      for n in sorter.chosen_names
        logger.warn(n)
      end
    end
    logger.warn("\nSynonym names:")
    for n in sorter.all_synonyms.map(&:id)
      logger.warn(n)
    end
  end

  # Post a comment after approval or deprecation if the user entered one.
  def post_comment(action, name, message)
    summary = :"name_#{action}_comment_summary".l
    comment = Comment.create!(
      :object  => name,
      :summary => summary,
      :comment => message
    )
    Transaction.post_comment(
      :id      => comment,
      :object  => name,
      :summary => summary,
      :comment => message
    )
  end

  ##############################################################################
  #
  #  :section: EOL Feed
  #
  ##############################################################################

  # Send stuff to eol.
  def eol # :nologin: :norobots:
    headers["Content-Type"] = "application/xml"
    @max_secs = params[:max_secs] ? params[:max_secs].to_i : nil
    @timer_start = Time.now()
    eol_data(['unvetted', 'vetted'], params[:last_name])
    render(:action => "eol", :layout => false)
  end

  # Show the data getting sent to EOL
  def eol_preview # :nologin: :norobots:
    @timer_start = Time.now
    eol_data(['unvetted', 'vetted'])
    @timer_end = Time.now
  end

  # Show the data not getting sent to EOL
  def eol_need_review # :norobots:
    eol_data(['unreviewed'])
    @title = :eol_need_review_title.t
    render(:action => 'eol_preview')
  end

  # Gather data for EOL feed.
  def eol_data(review_status_list, last_name=nil)
    @names      = []
    @descs      = {} # name.id    -> [NameDescription, NmeDescription, ...]
    @image_data = {} # name.id    -> [img.id, obs.id, user.id, lic.id, date]
    @users      = {} # user.id    -> user.legal_name
    @licenses   = {} # license.id -> license.url
    @authors    = {} # desc.id    -> "user.legal_name, user.legal_name, ..."

    # Get name descriptions that are exportable.
    rsl = review_status_list.join("', '")
    conditions = "review_status IN ('#{rsl}') AND " +
                 "gen_desc IS NOT NULL AND " +
                 "ok_for_export = 1 AND " +
                 "public = 1"
    descs = NameDescription.all(:conditions => conditions)

    # Fill in @descs, @users, @authors, @licenses.
    for desc in descs
      name_id = desc.name_id.to_i
      @descs[name_id] ||= []
      @descs[name_id] << desc
      authors = Name.connection.select_values(%(
        SELECT user_id FROM name_descriptions_authors
        WHERE name_description_id = #{desc.id}
      )).map(&:to_i)
      authors = [desc.user_id] if authors.empty?
      for author in authors
        @users[author.to_i] ||= User.find(author).legal_name
      end
      @authors[desc.id] = authors.map {|id| @users[id.to_i]}.join(', ')
      @licenses[desc.license_id] ||= desc.license.url if desc.license_id
    end

    # Get corresponding names.
    name_ids = @descs.keys.map(&:to_s).join(',')
    @names = Name.all(:conditions => "id IN (#{name_ids})",
                      :order => 'text_name ASC, author ASC')

    # Get corresponding images.
    image_data = Name.connection.select_all %(
      SELECT name_id, image_id, observation_id, images.user_id,
             images.license_id, images.created
      FROM observations, images_observations, images
      WHERE observations.name_id IN (#{name_ids})
      AND observations.vote_cache >= 2.4
      AND observations.id = images_observations.observation_id
      AND images_observations.image_id = images.id
      AND images.vote_cache >= 2
      AND images.ok_for_export
      ORDER BY observations.vote_cache
    )

    # Fill in @image_data, @users, and @licenses.
    for row in image_data
      name_id    = row['name_id'].to_i
      user_id    = row['user_id'].to_i
      license_id = row['license_id'].to_i
      image_datum = row.values_at('image_id', 'observation_id', 'user_id',
                                  'license_id', 'created')
      @image_data[name_id] ||= []
      @image_data[name_id].push(image_datum)
      @users[user_id]       ||= User.find(user_id).legal_name
      @licenses[license_id] ||= License.find(license_id).url
    end
  end

  ################################################################################
  #
  #  :section: Other Stuff
  #
  ################################################################################

  # Utility accessible from a number of name pages (e.g. indexes and
  # show_name?) that lets you enter a whole list of names, together with
  # synonymy, and create them all in one blow.
  def bulk_name_edit # :prefetch: :norobots:
    @list_members = nil
    @new_names    = nil
    if request.method == :post
      list = params[:list][:members].strip_squeeze rescue ''
      construct_approved_names(list, params[:approved_names])
      sorter = NameSorter.new
      sorter.sort_names(list)
      if sorter.only_single_names
        sorter.create_new_synonyms
        flash_notice :name_bulk_success.t
        redirect_to(:controller => 'observer', :action => 'list_rss_logs')
      else
        if sorter.new_name_strs != []
          # This error message is no longer necessary.
          flash_error "Unrecognized names given, including: #{sorter.new_name_strs[0].inspect}" if TESTING
        else
          # Same with this one... err, no this is not reported anywhere.
          flash_error "Ambiguous names given, including: #{sorter.multiple_line_strs[0].inspect}"
        end
        @list_members = sorter.all_line_strs.join("\r\n")
        @new_names    = sorter.new_name_strs.uniq.sort
      end
    end
  end

  # Draw a map of all the locations where this name has been observed.
  def map # :nologin: :norobots:
    pass_query_params
    @name = Name.find(params[:id])
    @query = create_query(:Location, :with_observations_of_name, :name => @name)
    @locations = @query.results
  end

  # Form accessible from show_name that lets a user setup tracker notifications
  # for a name.
  def email_tracking # :norobots:
    pass_query_params
    name_id = params[:id]
    @notification = Notification.find_by_flavor_and_obj_id_and_user_id(:name, name_id, @user.id)

    # Initialize form.
    if request.method != :post
      @name = Name.find(name_id)
      if Name.ranks_above_genus.member?(@name.rank)
        flash_warning(:email_tracking_enabled_only_for.t(:name => @name.display_name, :rank => @name.rank))
      end
      if @notification
        @note_template = @notification.note_template
      else
        mailing_address = @user.mailing_address.strip
        mailing_address = ':mailing_address' if mailing_address.blank?
        @note_template = :email_tracking_note_template.l(
          :species_name => @name.text_name,
          :mailing_address => mailing_address,
          :users_name => @user.legal_name
        )
      end

    # Submit form.
    else
      name = Name.find(name_id)
      case params[:commit]
      when :ENABLE.l, :UPDATE.l
        note_template = params[:notification][:note_template]
        note_template = nil if note_template.blank?
        if @notification.nil?
          @notification = Notification.new(:flavor => :name, :user => @user,
              :obj_id => name_id, :note_template => note_template)
          flash_notice(:email_tracking_now_tracking.t(:name => name.display_name))
        else
          @notification.note_template = note_template
          flash_notice(:email_tracking_updated_messages.t)
        end
        @notification.save
      when :DISABLE.l
        @notification.destroy
        flash_notice(:email_tracking_no_longer_tracking.t(:name => name.display_name))
      end
      redirect_to(:action => 'show_name', :id => name_id, :params => query_params)
    end
  end
end

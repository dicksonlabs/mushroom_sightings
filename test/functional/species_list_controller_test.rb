require File.dirname(__FILE__) + '/../boot'

class SpeciesListControllerTest < ControllerTestCase
  fixtures :locations
  fixtures :names
  fixtures :observations
  fixtures :observations_species_lists
  fixtures :species_lists
  fixtures :users

  def spl_params(spl)
    params = {
      :id => spl.id,
      :species_list => {
        :where => spl.where,
        :title => spl.title,
        "when(1i)" => spl.when.year.to_s,
        "when(2i)" => spl.when.month.to_s,
        "when(3i)" => spl.when.day.to_s,
        :notes => spl.notes
      },
      :list => { :members => "" },
      :checklist_data => {},
      :member => { :notes => "" },
    }
  end

################################################################################

  def test_list_species_lists
    get_with_dump(:list_species_lists)
    assert_response('list_species_lists')
  end

  def test_show_species_list
    get_with_dump(:show_species_list, :id => 1)
    assert_response('show_species_list')
  end

  def test_species_lists_by_title
    get_with_dump(:species_lists_by_title)
    assert_response('species_lists_by_title')
  end

  def test_species_lists_by_user
    get_with_dump(:species_lists_by_user, :id => @rolf.id)
    assert_response('list_species_lists')
  end

  def test_destroy_species_list
    spl = @first_species_list
    assert(spl)
    id = spl.id
    params = { :id => id.to_s }
    assert_equal("rolf", spl.user.login)
    requires_user(:destroy_species_list, [:show_species_list], params)
    assert_response(:action => :list_species_lists)
    assert_raises(ActiveRecord::RecordNotFound) do
      SpeciesList.find(id)
    end
  end

  def test_manage_species_lists
    obs = @coprinus_comatus_obs
    params = { :id => obs.id.to_s }
    requires_login(:manage_species_lists, params)
  end

  def test_add_observation_to_species_list
    sp = @first_species_list
    obs = @coprinus_comatus_obs
    assert(!sp.observations.member?(obs))
    params = { :species_list => sp.id, :observation => obs.id }
    requires_login(:add_observation_to_species_list, params)
    assert_response(:action => :manage_species_lists)
    assert(sp.reload.observations.member?(obs))
  end

  def test_remove_observation_from_species_list
    spl = @unknown_species_list
    obs = @minimal_unknown
    assert(spl.observations.member?(obs))
    params = { :species_list => spl.id, :observation => obs.id }
    owner = spl.user.login
    assert_not_equal('rolf', owner)

    # Try with non-owner (can't use requires_user since failure is a redirect)
    # effectively fails and gets redirected to show_species_list
    requires_login(:remove_observation_from_species_list, params)
    assert_response(:action => :show_species_list)
    assert(spl.reload.observations.member?(obs))

    login owner
    get_with_dump(:remove_observation_from_species_list, params)
    assert_response(:action => "manage_species_lists")
    assert(!spl.reload.observations.member?(obs))
  end

  # ----------------------------
  #  Create lists.
  # ----------------------------

  def test_create_species_list
    requires_login(:create_species_list)
    assert_form_action(:action => 'create_species_list')
  end

  # Test constructing species lists in various ways.
  def test_construct_species_list
    list_title = "List Title"
    params = {
      :list => { :members => @coprinus_comatus.text_name },
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      }
    }
    post_requires_login(:create_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(18, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert_not_nil(spl)
    assert(spl.name_included(@coprinus_comatus))
  end

  def test_construct_species_list_existing_genus
    list_title = "List Title"
    params = {
      :list => { :members => "#{@agaricus.rank} #{@agaricus.text_name}" },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      }
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(18, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert_not_nil(spl)
    assert(spl.name_included(@agaricus))
  end

  def test_construct_species_list_new_family
    list_title = "List Title"
    rank = :Family
    new_name_str = "Agaricaceae"
    new_list_str = "#{rank} #{new_name_str}"
    assert_nil(Name.find_by_text_name(new_name_str))
    params = {
      :list => { :members => new_list_str },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
      :approved_names => [new_name_str]
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(28, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert_not_nil(spl)
    new_name = Name.find_by_text_name(new_name_str)
    assert_not_nil(new_name)
    assert_equal(rank, new_name.rank)
    assert(spl.name_included(new_name))
  end

  # <name> = <name> shouldn't work in construct_species_list
  def test_construct_species_list_synonym
    list_title = "List Title"
    name = @macrolepiota_rachodes
    synonym_name = @lepiota_rachodes
    assert(!synonym_name.deprecated)
    assert_nil(synonym_name.synonym)
    params = {
      :list => { :members => "#{name.text_name} = #{synonym_name.text_name}"},
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response('create_species_list')
    assert_equal(10, @rolf.reload.contribution)
    assert(!synonym_name.reload.deprecated)
    assert_nil(synonym_name.synonym)
  end

  def test_construct_species_list_junk
    list_title = "List Title"
    new_name_str = "This is a bunch of junk"
    assert_nil(Name.find_by_text_name(new_name_str))
    params = {
      :list => { :members => new_name_str },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
      :approved_names => [new_name_str]
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response('create_species_list')
    assert_equal(10, @rolf.reload.contribution)
    assert_nil(Name.find_by_text_name(new_name_str))
    assert_nil(SpeciesList.find_by_title(list_title))
  end

  def test_construct_species_list_double_space
    list_title = "Double Space List"
    new_name_str = "Lactarius rubidus  (Hesler and Smith) Methven"
    params = {
      :list => { :members => new_name_str },
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
      :approved_names => new_name_str.squeeze(" ")
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response(:action => :show_species_list)
    # Must be creating Lactarius sp as well as L. rubidus (and spl and obs/splentry/naming).
    assert_equal(38, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert_not_nil(spl)
    obs = spl.observations.first
    assert_not_nil(obs)
    assert_not_nil(obs.modified)
    name = Name.find_by_search_name(new_name_str.squeeze(" "))
    assert_not_nil(name)
    assert(spl.name_included(name))
  end

  def test_construct_species_list_rankless_taxon
    list_title = "List Title"
    new_name_str = "Agaricaceae"
    assert_nil(Name.find_by_text_name(new_name_str))
    params = {
      :list => { :members => new_name_str },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
      :approved_names => [new_name_str]
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(28, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert_not_nil(spl)
    new_name = Name.find_by_text_name(new_name_str)
    assert_not_nil(new_name)
    assert_equal(:Genus, new_name.rank)
    assert(spl.name_included(new_name))
  end

  # Rather than repeat everything done for update_species, this construct
  # species just does a bit of everything:
  #   Written in:
  #     Lactarius subalpinus (deprecated, approved)
  #     Amanita baccata      (ambiguous, checked Arora in radio boxes)
  #     New name             (new, approved from previous post)
  #   Checklist:
  #     Agaricus campestris  (checked)
  #     Lactarius alpigenes  (checked, deprecated, approved, checked box for preferred name Lactarius alpinus)
  # Should result in the following list:
  #   Lactarius subalpinus
  #   Amanita baccata Arora
  #   New name
  #   Agaricus campestris
  #   Lactarius alpinus
  #   (but *NOT* L. alpingenes)
  def test_construct_species_list_extravaganza
    deprecated_name = @lactarius_subalpinus
    list_members = [deprecated_name.text_name]
    multiple_name = @amanita_baccata_arora
    list_members.push(multiple_name.text_name)
    new_name_str = "New name"
    list_members.push(new_name_str)
    assert_nil(Name.find_by_text_name(new_name_str))

    checklist_data = {}
    current_checklist_name = @agaricus_campestris
    checklist_data[current_checklist_name.id.to_s] = "checked"
    deprecated_checklist_name = @lactarius_alpigenes
    approved_name = @lactarius_alpinus
    checklist_data[deprecated_checklist_name.id.to_s] = "checked"

    list_title = "List Title"
    params = {
      :list => { :members => list_members.join("\r\n") },
      :checklist_data => checklist_data,
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "6",
        "when(3i)" => "4",
        :notes => "List Notes"
      },
    }
    params[:approved_names] = [new_name_str]
    params[:chosen_names] =
        { multiple_name.text_name.gsub(/\W/,"_") => multiple_name.id.to_s }
    params[:approved_deprecated_names] =
        [deprecated_name.text_name, deprecated_checklist_name.search_name]
    params[:chosen_approved_names] =
        { deprecated_checklist_name.search_name.gsub(/\W/,"_") => approved_name.id.to_s }

    login('rolf')
    post(:create_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(50, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert(spl.name_included(deprecated_name))
    assert(spl.name_included(multiple_name))
    assert(spl.name_included(Name.find_by_text_name(new_name_str)))
    assert(spl.name_included(current_checklist_name))
    assert(!spl.name_included(deprecated_checklist_name))
    assert(spl.name_included(approved_name))
  end

  def test_construct_species_list_nonalpha_multiple
    # First try creating it with ambiguous name "Warnerbros bugs-bunny".
    # (There are two such names with authors One and Two, respectively.)
    params = {
      :list => { :members => "\n Warnerbros  bugs-bunny " },
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => "Testing nonalphas",
        "when(1i)" => "2008",
        "when(2i)" => "1",
        "when(3i)" => "31",
        :notes => ""
      },
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response('create_species_list')
    assert_equal(10, @rolf.reload.contribution)
    assert_equal("Warnerbros bugs-bunny",
                 @controller.instance_variable_get('@list_members'))
    assert_equal([], @controller.instance_variable_get('@new_names'))
    assert_equal(["Warnerbros bugs-bunny"],
                 @controller.instance_variable_get('@multiple_names'))
    assert_equal([], @controller.instance_variable_get('@deprecated_names'))

    # Now re-post, having selected Two.
    params = {
      :list => { :members => "Warnerbros bugs-bunny\r\n" },
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => "Testing nonalphas",
        "when(1i)" => "2008",
        "when(2i)" => "1",
        "when(3i)" => "31",
        :notes => ""
      },
      :chosen_names => { "Warnerbros_bugs_bunny" => @bugs_bunny_two.id },
    }
    post(:create_species_list, params)
    assert_response(:action => "show_species_list")
    assert_equal(18, @rolf.reload.contribution)
    spl = SpeciesList.last
    assert(spl.name_included(@bugs_bunny_two))
  end

  # -----------------------------------------------
  #  Test changing species lists in various ways.
  # -----------------------------------------------

  def test_edit_species_list
    spl = @first_species_list
    params = { :id => spl.id.to_s }
    assert_equal('rolf', spl.user.login)
    requires_user(:edit_species_list, :show_species_list, params)
    assert_response('edit_species_list')
    assert_form_action(:action => 'edit_species_list')
  end

  def test_update_species_list_nochange
    spl = @unknown_species_list
    sp_count = spl.observations.size
    params = spl_params(spl)
    post_requires_user(:edit_species_list, :show_species_list, params,
                       spl.user.login)
    assert_response(:action => :show_species_list)
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
  end

  def test_update_species_list_text_add_multiple
    spl = @unknown_species_list
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "Coprinus comatus\r\nAgaricus campestris"
    owner = spl.user.login
    assert_not_equal('rolf', owner)
    login('rolf')
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10, @rolf.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
    login owner
    post_with_dump(:edit_species_list, params)
    assert_response(:action => "show_species_list")
    assert_equal(16, spl.user.reload.contribution)
    assert_equal(sp_count + 2, spl.reload.observations.size)
  end

  def test_update_species_list_text_add
    spl = @unknown_species_list
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "Coprinus comatus"
    params[:species_list][:where] = "New Place"
    params[:species_list][:title] = "New Title"
    params[:species_list][:notes] = "New notes."
    owner = spl.user.login
    assert_not_equal('rolf', owner)
    login('rolf')
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10, @rolf.reload.contribution)
    assert(spl.reload.observations.size == sp_count)
    login owner
    post_with_dump(:edit_species_list, params)
    assert_response(:action => "show_species_list")
    assert_equal(13, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert_equal("New Place", spl.where)
    assert_equal("New Title", spl.title)
    assert_equal("New notes.", spl.notes)
  end

  def test_update_species_list_text_notifications
    spl = @first_species_list
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "Coprinus comatus\r\nAgaricus campestris"
    login('rolf')
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
  end

  def test_update_species_list_new_name
    spl = @unknown_species_list
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "New name"
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response('edit_species_list')
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
  end

  def test_update_species_list_approved_new_name
    spl = @unknown_species_list
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "New name"
    params[:approved_names] = ["New name"]
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    # Creates New sp and New name, as well as an observations/splentry/naming.
    assert_equal(33, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
  end

  def test_update_species_list_multiple_match
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @amanita_baccata_arora
    assert(!spl.name_included(name))
    params = spl_params(spl)
    params[:list][:members] = name.text_name
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response('edit_species_list')
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
    assert(!spl.name_included(name))
  end

  def test_update_species_list_chosen_multiple_match
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @amanita_baccata_arora
    assert(!spl.name_included(name))
    params = spl_params(spl)
    params[:list][:members] = name.text_name
    params[:chosen_names] = {name.text_name.gsub(/\W/,"_") => name.id}
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(13, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_deprecated
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:list][:members] = name.text_name
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response('edit_species_list')
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
    assert(!spl.name_included(name))
  end

  def test_update_species_list_approved_deprecated
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:list][:members] = name.text_name
    params[:approved_deprecated_names] = [name.text_name]
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(13, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_checklist_add
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_alpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "checked"
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(13, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_deprecated_checklist
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "checked"
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response('edit_species_list')
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
    assert(!spl.name_included(name))
  end

  def test_update_species_list_approved_deprecated_checklist
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "checked"
    params[:approved_deprecated_names] = [name.search_name]
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(13, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_approved_renamed_deprecated_checklist
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    approved_name = @lactarius_alpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "checked"
    params[:approved_deprecated_names] = [name.search_name]
    params[:chosen_approved_names] =
                { name.search_name.gsub(/\W/,"_") => approved_name.id.to_s }
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(13, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(!spl.name_included(name))
    assert(spl.name_included(approved_name))
  end

  def test_update_species_list_approved_rename
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    approved_name = @lactarius_alpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    assert(!spl.name_included(approved_name))
    params[:list][:members] = name.text_name
    params[:approved_deprecated_names] = name.text_name
    params[:chosen_approved_names] =
                { name.text_name.gsub(/\W/,"_") => approved_name.id.to_s }
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(13, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(!spl.name_included(name))
    assert(spl.name_included(approved_name))
  end

  # ----------------------------
  #  Upload files.
  # ----------------------------

  def test_upload_species_list
    spl = @first_species_list
    params = {
      :id => spl.id
    }
    requires_user(:upload_species_list, :show_species_list, params)
    assert_form_action(:action => 'upload_species_list')
  end

  def test_read_species_list
    # TODO: Test read_species_list with a file larger than 13K to see if it
    # gets a TempFile or a StringIO.
    spl = @first_species_list
    assert_equal(0, spl.observations.length)
    list_data = "Agaricus bisporus\r\nBoletus rubripes\r\nAmanita phalloides"
    file = StringIOPlus.new(list_data)
    file.content_type = 'text/plain'
    params = {
      "id" => spl.id,
      "species_list" => {
        "file" => file
      }
    }
    post_requires_login(:upload_species_list, params)
    assert_response('edit_species_list')
    assert_equal(10, @rolf.reload.contribution)
    # Doesn't actually change list, just feeds it to edit_species_list
    assert_equal(list_data, @controller.instance_variable_get('@list_members'))
  end

  # ----------------------------
  #  Name lister and reports.
  # ----------------------------

  def test_make_report
    now = Time.now

    User.current = @rolf
    tapinella = Name.create(
      :author => '(Batsch) Šutara',
      :text_name => 'Tapinella atrotomentosa',
      :search_name => 'Tapinella atrotomentosa (Batsch) Šutara',
      :deprecated => false,
      :rank => :Species,
      :review_status => :unreviewed
    )

    list = @first_species_list
    args = {
      :where    => 'limbo',
      :when     => now,
      :created  => now,
      :modified => now,
      :user     => @rolf,
      :specimen => false,
    }
    list.construct_observation(args.merge(:what => tapinella))
    list.construct_observation(args.merge(:what => @fungi))
    list.construct_observation(args.merge(:what => @coprinus_comatus))
    list.construct_observation(args.merge(:what => @lactarius_alpigenes))
    list.save # just in case

    get(:make_report, :id => list.id, :type => 'txt')
    assert_response_equal_file('test/fixtures/reports/test.txt')

    get(:make_report, :id => list.id, :type => 'rtf')
    assert_response_equal_file('test/fixtures/reports/test.rtf') do |x|
      x.sub(/\{\\createim\\yr.*\}/, '')
    end

    get(:make_report, :id => list.id, :type => 'csv')
    assert_response_equal_file('test/fixtures/reports/test.csv')
  end

  def test_name_lister
    # This will have to be very rudimentary, since the vast majority of the
    # complexity is in Javascript.  Sigh.
    get(:name_lister)

    params = {
      :results => [
        'Amanita baccata|sensu Borealis*',
        'Coprinus comatus*',
        'Fungi*',
        'Lactarius alpigenes'
      ].join("\n")
    }

    @request.session[:user_id] = 1
    post(:name_lister, params.merge(:commit => :name_lister_submit_spl.l))
    ids = @controller.instance_variable_get('@objs').map {|n| n.id}
    assert_equal([6, 2, 1, 14], ids)
    assert_response('create_species_list')

    @request.session[:user_id] = nil
    post(:name_lister, params.merge(:commit => :name_lister_submit_txt.l))
    assert_response_equal_file('test/fixtures/reports/test2.txt')

    @request.session[:user_id] = nil
    post(:name_lister, params.merge(:commit => :name_lister_submit_rtf.l))
    assert_response_equal_file('test/fixtures/reports/test2.rtf') do |x|
      x.sub(/\{\\createim\\yr.*\}/, '')
    end

    @request.session[:user_id] = nil
    post(:name_lister, params.merge(:commit => :name_lister_submit_csv.l))
    assert_response_equal_file('test/fixtures/reports/test2.csv')
  end

  def test_name_resolution
    params = {
      :species_list => {
        :when  => Time.now,
        :where => 'somewhere',
        :title => 'title',
        :notes => 'notes',
      },
      :member => { :notes => "" },
      :list => {},
    }
    @request.session[:user_id] = 1

    params[:list][:members] = [
      'Fungi',
      'Agaricus sp',
      'Psalliota sp.',
      '"One"',
      '"Two" sp',
      '"Three" sp.',
      'Agaricus "blah"',
      'Chlorophyllum Author',
      'Lepiota sp Author',
    ].join("\n")
    params[:approved_names] = [
      'Psalliota sp.',
      '"One"',
      '"Two" sp',
      '"Three" sp.',
      'Agaricus "blah"',
      'Chlorophyllum Author',
      'Lepiota sp Author',
    ].join('/')
    post(:create_species_list, params)
    assert_response(:action => "show_species_list")
    assert_equal([
      'Fungi sp.',
      'Agaricus sp.',
      'Psalliota sp.',
      'Chlorophyllum sp. Author',
      'Lepiota sp. Author',
      '"One" sp.',
      '"Two" sp.',
      '"Three" sp.',
      'Agaricus "blah"',
    ].sort, assigns(:species_list).observations.map {|x| x.name.search_name}. sort)

    params[:list][:members] = [
      'Fungi',
      'Agaricus sp',
      'Psalliota sp.',
      '"One"',
      '"Two" sp',
      '"Three" sp.',
      'Agaricus "blah"',
      'Chlorophyllum Author',
      'Lepiota sp Author',
      'Lepiota sp. Author',
    ].join("\n")
    params[:approved_names] = [
      'Psalliota sp.',
    ].join('/')
    post(:create_species_list, params)
    assert_response(:action => "show_species_list")
    assert_equal([
      'Fungi sp.',
      'Agaricus sp.',
      'Psalliota sp.',
      'Chlorophyllum sp. Author',
      'Lepiota sp. Author',
      'Lepiota sp. Author',
      '"One" sp.',
      '"Two" sp.',
      '"Three" sp.',
      'Agaricus "blah"',
    ].sort, assigns(:species_list).observations.map {|x| x.name.search_name}.sort)
  end
end

# Test typical sessions of user who never creates an account or contributes.

require File.dirname(__FILE__) + '/../boot'

class LurkerTest < IntegrationTestCase
  def test_poke_around
    # Start at index.
    get('/')
    assert_template('observer/list_rss_logs')

    # Click on first observation.
    click(:href => /^\/\d+\?/, :in => :results)
    assert_template('observer/show_observation')
    push_page

    # Click on the first image.
    click(:label => :image, :in => 'div.show_images')
    click(:label => :image, :href => /show_image.*full_size/)

    # Go back to observation and click on "About...".
    go_back
    click(:label => 'About', :href => /show_name/)
    assert_template('name/show_name')
    push_page(:name)

    # Take a look at the distribution map.
    click(:label => 'Distribution Map', :in => :tabs)
    assert_template('name/map')

    # Check out a few links from left-hand panel.
    click(:label => 'How To Use',     :in => :left_panel)
    click(:label => 'Español',        :in => :left_panel)
    click(:label => 'Contribuidores', :in => :left_panel)
    click(:label => 'English',        :in => :left_panel)
    click(:label => 'List Projects',  :in => :left_panel)
    click(:label => 'Comments',       :in => :left_panel)
    click(:label => 'Site Stats',     :in => :left_panel)
  end

  def test_show_observation
    # Start with Observation #2 since it has everything.
    get('/2')
    push_page

    # Check out the RSS log.
    save_path = path
    click(:label => 'Show Log')
    click(:label => 'Show Observation')
    assert_equal(save_path, path,
                 "Went to RSS log and returned, expected to be the same.")

    # Mary has done several things to it (observation itself, naming, comment).
    assert_select('a[href^=/observer/show_user/2]', :minimum => 3)
    click(:label => 'Mary Newbie')
    assert_template('observer/show_user')

    # Check out location.
    go_back
    click(:label => 'Burbank, California') # Don't include USA due to <span>
    assert_template('location/show_location')

    # Check out species list.
    go_back
    click(:label => 'List of mysteries')
    assert_template('species_list/show_species_list')
    # (Make sure observation #2 is shown somewhere.)
    assert_select('a[href^=/2?]')

    # Click on name.
    go_back
    # (Should be at least two links to show the name Fungi.)
    assert_select('a[href^=/name/show_name/1]', :minimum => 2)
    click(:label => /About.*Fungi/)
    # (Make sure the page contains create_name_description.)
    assert_select('a[href^=/name/create_name_description/1]')

    # And lastly there are some images.
    go_back
    assert_select('a[href^=/image/show_image]', :minimum => 2)
    click(:label => :image, :href => /show_image/)
    # (Make sure observation #2 is shown somewhere.)
    assert_select('a[href^=/2?]')
  end

  def test_search
    get('/')

    # Search for a name.  (Only one.)
    form = open_form('form[action*=search]')
    form.change('pattern', 'Coprinus comatus')
    form.select('type', 'Names')
    form.submit('Search')
    assert_match(/^.name.show_name.2\?/, path)

    # Search for observations of that name.  (Only one.)
    form.select('type', 'Observations')
    form.submit('Search')
    assert_match(/^.3\?/, path)

    # Search for images of the same thing.  (Still only one.)
    form.select('type', 'Images')
    form.submit('Search')
    assert_match(/^.image.show_image.5\?/, path)

    # There should be no locations of that name, though.
    form.select('type', 'Locations')
    form.submit('Search')
    assert_template('location/list_locations')
    assert_flash(/no.*found/i)
    assert_select('div.results a[href]', false)

    # This should give us just about all the locations.
    form.change('pattern', 'california OR canada')
    form.select('type', 'Locations')
    form.submit('Search')
    assert_select('div.results a[href]') do |links|
      labels = links.map {|l| l.to_s.html_to_ascii}
      assert(labels.any? {|l| l.match(/Canada$/)},
             "Expected one of the results to be in Canada.\n" +
             "Found these: #{labels.inspect}")
      assert(labels.any? {|l| l.match(/USA$/)},
             "Expected one of the results to be in the US.\n" +
             "Found these: #{labels.inspect}")
    end
  end

  def test_obs_at_location
    # Start at distribution map for Fungi.
    get('/name/map/1')

    # Get a list of locations shown on map. (One defined, one undefined.)
    click(:label => 'Show Locations', :in => :tabs)
    assert_template('location/list_locations')

    # Click on the defined location.
    click(:label => /Burbank/)
    assert_template('location/show_location')

    # Get a list of observations from there.  (Several so goes to index.)
    click(:label => 'Observations at this Location', :in => :tabs)
    assert_template('observer/list_observations')
    save_results = get_links('div.results a[href^=?]', /^.\d+/)

    # Try sorting differently.
    click(:label => 'Date', :in => :tabs)
    results = get_links('div.results a[href^=?]', /^.\d+/)
    assert_equal(save_results.length, results.length)
    click(:label => 'User', :in => :tabs)
    results = get_links('div.results a[href^=?]', /^.\d+/)
    assert_equal(save_results.length, results.length)
    click(:label => 'Reverse Order', :in => :tabs)
    results = get_links('div.results a[href^=?]', /^.\d+/)
    assert_equal(save_results.length, results.length)
    click(:label => 'Name', :in => :tabs)
    results = get_links('div.results a[href^=?]', /^.\d+/)
    assert_equal(save_results.length, results.length)
    save_results = results
    query_params = parse_query_params(save_results.first)

    # Go to first observation, and try stepping back and forth.
    click(:href => /^\/\d+\?/, :in => :results)
    save_path = path
    assert_equal(query_params, parse_query_params)
    click(:label => '« Prev', :in => :tabs)
    assert_flash(/there are no more observations/i)
    assert_equal(save_path, path)
    assert_equal(query_params, parse_query_params)
    click(:label => 'Next »', :in => :tabs)
    assert_flash(nil)
    assert_equal(query_params, parse_query_params)
    save_path = path
    click(:label => 'Next »', :in => :tabs)
    assert_flash(nil)
    assert_equal(query_params, parse_query_params)
    click(:label => '« Prev', :in => :tabs)
    assert_flash(nil)
    assert_equal(query_params, parse_query_params)
    assert_equal(save_path, path,
                 "Went next then prev, should be back where we started.")
    click(:label => 'Index', :href => /index/, :in => :tabs)
    results = get_links('div.results a[href^=?]', /^.\d+/)
    assert_equal(query_params, parse_query_params(results.first))
    assert_equal(save_results, results,
                 "Went to show_obs, screwed around, then back to index. " +
                 "But the results were not the same when we returned.")
  end
end

require File.dirname(__FILE__) + '/../boot'

class SearchStateTest < Test::Unit::TestCase

  def assert_state_exists(id)
    assert(!id.nil? && SearchState.find(id))
  end

  def assert_state_not_exists(id)
    assert_nil(SearchState.safe_find(id))
  end

################################################################################

  def test_cleanup
    # This avoids any possible difference in time zone between mysql and you.
    now = DateTime.parse(SearchState.connection.select_value("SELECT NOW()"))

    s11 = SearchState.new(:access_count => 0, :timestamp => now - 1.minute)
    s12 = SearchState.new(:access_count => 0, :timestamp => now - 1.hour + 1.minute)
    s13 = SearchState.new(:access_count => 0, :timestamp => now - 1.hour - 1.minute)
    s14 = SearchState.new(:access_count => 0, :timestamp => now - 1.day + 1.minute)
    s15 = SearchState.new(:access_count => 0, :timestamp => now - 1.day - 1.minute)
    s21 = SearchState.new(:access_count => 1, :timestamp => now - 1.minute)
    s22 = SearchState.new(:access_count => 1, :timestamp => now - 1.hour + 1.minute)
    s23 = SearchState.new(:access_count => 1, :timestamp => now - 1.hour - 1.minute)
    s24 = SearchState.new(:access_count => 1, :timestamp => now - 1.day + 1.minute)
    s25 = SearchState.new(:access_count => 1, :timestamp => now - 1.day - 1.minute)

    s11.save
    s12.save
    s13.save
    s14.save
    s15.save
    s21.save
    s22.save
    s23.save
    s24.save
    s25.save

    s11 = s11.id
    s12 = s12.id
    s13 = s13.id
    s14 = s14.id
    s15 = s15.id
    s21 = s21.id
    s22 = s22.id
    s23 = s23.id
    s24 = s24.id
    s25 = s25.id

    assert_state_exists(s11)
    assert_state_exists(s12)
    assert_state_exists(s13)
    assert_state_exists(s14)
    assert_state_exists(s15)
    assert_state_exists(s21)
    assert_state_exists(s22)
    assert_state_exists(s23)
    assert_state_exists(s24)
    assert_state_exists(s25)

    SearchState.cleanup

    assert_state_exists(s11)
    assert_state_exists(s12)
    assert_state_not_exists(s13)
    assert_state_not_exists(s14)
    assert_state_not_exists(s15)
    assert_state_exists(s21)
    assert_state_exists(s22)
    assert_state_exists(s23)
    assert_state_exists(s24)
    assert_state_not_exists(s25)
  end

  def test_query_types
    for query_type, params in [
      [ :species_list_observations, {} ],
      [ :name_observations, {} ],
      [ :synonym_observations, {} ],
      [ :other_observations, {} ],
      [ :observations, {} ],
      [ :images, { :obs => 2 } ],
      [ :rss_logs, {} ]
    ] do
      # Create new state and save.
      state = SearchState.lookup(params, query_type)
      state.save
      id = state.id

      # Look it up and test.
      params[:search_seq] = id.to_s
      state = SearchState.lookup(params)
      assert_equal(id, state.id)
      assert_equal(1, state.access_count)
      assert_equal(query_type, state.query_type)
      assert(state.query)
    end
  end
end

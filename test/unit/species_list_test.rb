require File.dirname(__FILE__) + '/../test_helper'

class SpeciesListTest < Test::Unit::TestCase
  fixtures :species_lists

  # Replace this with your real tests.
  def test_truth
    assert_kind_of SpeciesList, species_lists(:first)
  end
end
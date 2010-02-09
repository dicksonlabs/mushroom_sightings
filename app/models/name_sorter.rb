#
#  = Name Sorter
#
#  This class is used by a few controllers (e.g.  NameController,
#  SpeciesListController) to help parse lists of names, such as in
#  bulk_name_edit, create/edit_species_list, and change_synonyms.  It uses
#  NameParse to parse individual lines, then gathers unrecognized names,
#  deprecated names, accepted names, etc. 
#
#  This is extraordinarily complicated-looking, but once you've worked out the
#  execution flow and what the method and attribute names mean, you'll see that
#  it's not so bad.  Still, I'd caution against making any changes here unless
#  you really know what you're doing.
#
#  1. First create and populate object:
#    sorter = NameSorter.new
#
#    # Pass in a list of name strings, or one string at a time.
#    sorter.sort_names(list_of_name_strs)
#    sorter.add_name(name_str)
#
#    # After the first pass, if there were names with multiple matches, the user
#    # may choose which ones they mean.
#    sorter.add_chosen_names(hash_mapping_name_ids_to_name_ids)
#
#    # Likewise, after the first pass, the user can tell NameSorter that it's
#    # okay to use certain deprecated names.
#    sorter.add_approved_deprecated_names(list_of_name_strings)
#
#    # Likewise, after the first pass, if some names are deprecated, the user
#    # may choose which approved synonyms they want to use.
#    sorter.append_approved_synonyms(list_of_name_ids)
#    sorter.push_synonym(id_or_name)
#
#  2. Now query object:
#
#    # Check an external list of Names for unapproved deprecated names.  (The
#    # second version takes a hash that you get back from a list of checkboxes.)
#    # These set the internal flag below, has_unapproved_deprecated_names.
#    check_for_deprecated_names(list_of_names)
#    check_for_deprecated_checklist(checkbox_list)
#
#    # Have all deprecated names that are left been approved by the user?
#    has_unapproved_deprecated_names
#
#    # Are all names recognized and unambiguously match a single Name?
#    only_single_names
#
#    # Has the user entered any "Species one = Species two" lines?
#    # (This syntax is not allowed while populating species lists, for example.)
#    has_new_synonyms
#
#    # Checks to make sure user has had a chance to choose from among the synonyms
#    # of any name they've listed that has synonyms.  This is a bit misnamed.
#    only_approved_synonyms
#
#  3. And finally act upon the result:
#
#    # Once ambiguous and unrecognized names have been cleared up, use this to
#    # implement the synonymies specified using the "Species = Synonym" syntax.
#    create_new_synonyms
#
#    # Get a full list of all possible synonyms for the listed names.
#    all_synonyms
#
#    # Reconstruct the original list:
#    new_line_strs         # New names.
#    multiple_line_strs    # Ambiguous names.
#    single_line_strs      # Recognized, unambiguous names.
#    all_line_strs         # (all of the above)
#
#    # Extract lists of name strings:
#    new_name_strs         # New names.
#    deprecated_name_strs  # Deprecated names.
#    synonym_name_strs     # Synonyms.
#
#    # Lists of Name objects:
#    all_names             # All recognized Name's.
#    single_names          # All unambiguous recognized Name's, as [Name, Time].
#    deprecated_names      # All deprecated Name's.
#    multiple_names        # Representatives of sets of ambiguous Name's.
#
################################################################################

class NameSorter
  attr_accessor :approved_deprecated_names
  attr_accessor :approved_synonyms
  attr_accessor :chosen_names

  attr_reader :has_new_synonyms
  attr_reader :has_unapproved_deprecated_names
  attr_reader :synonym_data
  attr_reader :all_names

  attr_reader :deprecated_name_strs
  attr_reader :deprecated_names
  attr_reader :multiple_line_strs
  attr_reader :multiple_names
  attr_reader :single_line_strs
  attr_reader :single_names
  attr_reader :new_line_strs
  attr_reader :new_name_strs

  def initialize
    @approved_deprecated_names = [] # Array of String's
    @approved_synonyms         = [] # Array of Name's
    @chosen_names              = {} # Hash mapping Name id to Name id

    @has_new_synonyms                = false
    @has_unapproved_deprecated_names = false
    @synonym_data              = [] # Array of [NameParse, [Name, Name, ...]]
    @all_names                 = [] # Array of Name's

    @deprecated_name_strs      = [] # Array of String's
    @deprecated_names          = [] # Array of Name's
    @multiple_line_strs        = [] # Array of String's
    @multiple_names            = [] # Array of Name's
    @single_line_strs          = [] # Array of String's
    @single_names              = [] # Array of [Name, Time]
    @new_line_strs             = [] # Array of String's      # whole line
    @new_name_strs             = [] # Array of String's      # just parsed name
  end

  def all_line_strs
    @new_line_strs + @multiple_line_strs + @single_line_strs
  end

  def reset_new_names
    @new_line_strs = []
    @new_name_strs = []
  end

  def only_single_names
    (@new_name_strs == []) and (@multiple_line_strs == [])
  end

  def push_synonym(arg)
    if arg.is_a?(Fixnum)
      @approved_synonyms.push(Name.find(arg))
    elsif arg.is_a?(ActiveRecord::Base)
      @approved_synonyms.push(arg)
    else
      raise TypeError.new("NameSorter synonyms must be Fixnum or ActiveRecord::Base, not #{arg.clasS}.")
    end
  end

  def append_approved_synonyms(synonyms)
    if synonyms # Allow for nil
      if synonyms.class == String
        synonyms = synonyms.split("/")
      end
      if synonyms.class == Array
        synonyms.each {|id| push_synonym(id.to_i)}
      else
        raise TypeError.new("Only Arrays can be appended to a NameSorter synonym list not %s" % synonyms.class)
      end
    end
  end

  def add_chosen_names(new_names)
    if new_names
      @chosen_names.merge!(new_names)
    end
  end

  def add_approved_deprecated_names(new_names)
    if new_names
      for n in new_names
        @approved_deprecated_names += n.split("/")
      end
    end
  end

  def check_for_deprecated_name(name, name_str=nil)
    if name.deprecated
      str = name_str || name.search_name
      @deprecated_name_strs.push(str)
      @deprecated_names.push(name)
      if @approved_deprecated_names.nil? or
         !@approved_deprecated_names.member?(str) and
         !@approved_deprecated_names.member?(name.id.to_s)
        @has_unapproved_deprecated_names = true
      end
    end
  end

  def check_for_deprecated_names(names, name_str=nil)
    for n in names
      check_for_deprecated_name(n, name_str)
    end
  end

  def check_for_deprecated_checklist(checklist)
    if checklist
      for key, value in checklist
        if value == '1'
          check_for_deprecated_name(Name.find(key.to_i))
        end
      end
    end
  end

  # Add a single name to the list.  It calculates "stats" as it goes, such as
  # whether the name has multiple synonyms, whether it is deprecated, whether
  # it is unrecognized, etc.
  def add_name(spl_line, timestamp=nil)
    # Need to store all this data
    name_parse = NameParse.new(spl_line)
    line_str = name_parse.line_str
    name_str = name_parse.name
    chosen = false

    # Need all deprecated names even when another name is chosen
    # in case something else forces a redisplay
    names = name_parse.find_names
    check_for_deprecated_names(names, name_str)

    # Check radio boxes for multiple-names and/or approved-names that have
    # been selected -- these take priority over all else.
    if @chosen_names
      for name in names
        if chosen_id = @chosen_names[name.id.to_s]
          @single_line_strs.push(line_str) # (name_str)
          chosen_name = Name.find(chosen_id)
          names = [chosen_name]
          @single_names.push([chosen_name, timestamp])
          @all_names.push(chosen_name)
          chosen = true
          break
        end
      end
    end

    # If no radio boxes checked, all names must match uniquely or we have
    # problems.  There are three cases:
    #   1) new names -- no matches
    #   2) good names -- exactly one match
    #   3) ambiguous names -- multiple matches
    if not chosen
      @all_names += names
      len = names.length
      if len == 0
        @new_line_strs.push(line_str)
        @new_name_strs.push(name_parse.search_name)
      elsif len == 1
        @single_line_strs.push(line_str)
        @single_names.push([names.first, nil])
      else
        @multiple_line_strs.push(line_str)
        # Add a representative to @multiple_names -- doesn't matter which.
        @multiple_names.push(names.first)
      end
    end

    # Did user specify a synonym via the "Name = Synonym" syntax?
    if name_parse.has_synonym
      @has_new_synonyms = true
      if name_parse.find_synonym_names.length == 0
        @new_name_strs.push(name_parse.synonym_search_name)
      end
      @synonym_data.push([name_parse, names]) # Keep names in addition to parse for the chosen filter
    end
  end

  # Deprecate all the "Species = Synonym" synonyms, and synonymize them.
  # This relies on both the species and the synonym already existing and being
  # unambiguous.  That is, only_single_names must be true.
  def create_new_synonyms
    for parse, names in @synonym_data
      if names.length == 1
        # Merging earlier in this loop may have affected this name implicitly;
        # reload to pick up potential changes. 
        name = names.first.reload
        synonym_names = parse.find_synonym_names
        for s in synonym_names
          s.change_deprecated(true)
          s.save
          name.merge_synonyms(s)
        end
      else
        raise TypeError.new("Unexpected ambiguity: #{names.map{|n| n.search_name}.join(', ')}")
      end
    end
  end

  # Get a (mostly) full list of all the synonyms of the listed names, including
  # the names themselves... except for the names that have no synonyms.
  # Returns a list of name strings (display_name in particular), not objects. 
  def synonym_name_strs
    result = []
    for name in @all_names
      if name.synonym_id
        result += name.synonyms.map(&:display_name)
      end
    end
    result
  end

  # This gathers a full list of all the names in the list passed in and all
  # their synonyms.  This is thus the set of all possible synonyms.  It adds to
  # this the synonyms from the previous pass, just in case.  It returns a list
  # of Name ids (not objects).  (*NOTE*: This is a superset of +all_names+.) 
  def all_synonyms
    result = @approved_synonyms.dup
    for name in @all_names
      result += name.synonyms
    end
    result.uniq
  end

  # This takes all the names in the list, gathers all the possible synonyms for
  # them, then makes sure the user has had a chance to choose from among them
  # all (via @approved_synonyms).  This will fail if the user enters a name
  # with a synonym on the first pass; and it can also fail on subsequent passes
  # if they change the list of names and add a new name with another synonym.
  # The idea is not to force the user to choose any particular synonyms, but
  # instead just to make sure they have a chance to *see* all the synonyms.
  def only_approved_synonyms
    result = true
    ok_name_ids = (@approved_synonyms + @all_names).map(&:id)
    # error_string = "ok_nameids: [%s]\n" % ok_name_ids.join(', ') +
    # "all_synonyms: [%s]\n" % self.all_synonyms.map(&:id).join(', ')
    for name in all_synonyms
      # error_string += "%s\n" % name.id
      if not ok_name_ids.member?(name.id)
        # raise TypeError.new("member? failed")
        result = false
        break
      end
    end
    # raise TypeError.new(error_string)
    result
  end

  # Add a list of name strings.
  def sort_names(name_list)
    for n in name_list
      if n.match(/\S/)
        add_name(n)
      end
    end
  end
end

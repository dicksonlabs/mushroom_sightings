# encoding: utf-8
#
#  = Site Data
#
#  This class manages user contributions / rankings.
#
#  == Class Methods
#
#  update_contribution::    Callback that keeps User contribution up to date.
#
#  == Instance Methods
#  ==== Public
#  get_site_data::           Returns stats for entire site.
#  get_user_data::           Returns stats for given user.
#  get_all_user_data::       Returns stats for all users.
#  ==== Private
#  load_user_data::          Populates @user_data.
#  load_field_counts::       Populates a single column in @user_data.
#  calc_metric::             Calculates contribution score of a single user.
#  get_field_count::         Looks up total number of entries in a given table.
#
#  == Internal Data Structure
#
#  The private method load_user_data caches its information in the instance
#  variable +@user_data+.  Its structure is as follows:
#
#    @user_data = {
#      user.id => {
#        :id         => user.id,
#        :name       => user.unique_text_name,
#        :bonuses    => user.sum_bonuses,
#        :<category> => <num_records_in_category>,
#        :metric     => <weighted_sum_of_category_counts>,
#      },
#    }
#
################################################################################

class SiteData

  ##############################################################################
  #
  #  :section: Category Definitions
  #
  #  User's contributions are the weighted sum of the number of records in
  #  several categories, such as Observation's posted, Image's uploaded, Name's
  #  authored, etc.  These categories are described by a set of constants:
  #
  #  ALL_FIELDS::       List of category names, in order.
  #  FIELD_WEIGHTS::    Weight of each category, i.e. number of points for each record.
  #  FIELD_TABLES::     Table to query.
  #  FIELD_CONDITIONS:: Additional conditions.
  #
  #  The basic query for stats for the entire site is:
  #
  #    SELECT COUNT(*) FROM table
  #
  #  The basic query for stats for a single user is:
  #
  #    SELECT COUNT(*) FROM table WHERE user_id = 123
  #
  #  The only exception is species_list_entries, which does a simple join:
  #
  #    SELECT COUNT(*) FROM species_lists s, observations_species_lists os
  #      WHERE user_id = 123 AND s.id = os.species_list_id
  #
  ##############################################################################

  # List of the categories.  This might be the order they appear in show_user.
  ALL_FIELDS = [
    :name_descriptions_authors,
    :name_descriptions_editors,
    :names,
    :names_versions,
    :location_descriptions_authors,
    :location_descriptions_editors,
    :locations,
    :locations_versions,
    :images,
    :species_lists,
    :species_list_entries,
    :observations,
    :comments,
    :namings,
    :votes,
    :users,
  ]

  # Relative score for each category.
  FIELD_WEIGHTS = {
    :comments                      => 1,
    :images                        => 10,
    :location_descriptions_authors => 50,
    :location_descriptions_editors => 5,
    :locations                     => 10,
    :locations_versions            => 5,
    :name_descriptions_authors     => 100,
    :name_descriptions_editors     => 10,
    :names                         => 10,
    :names_versions                => 10,
    :namings                       => 1,
    :observations                  => 1,
    :species_list_entries          => 1,
    :species_lists                 => 5,
    :users                         => 0,
    :votes                         => 1,
  }

  # Table to query to get score for each category.  (Default is same as the
  # category name.)
  FIELD_TABLES = {
    :species_list_entries => 'observations_species_lists',
  }

  # Additional conditions to use for each category.
  FIELD_CONDITIONS = {
    :users => '`verified` IS NOT NULL'
  }

################################################################################
#
# :section: Public Interface
#
################################################################################

  # This is called every time any object (not just one we care about) is
  # created or destroyed.  Figure out what kind of object from the class name,
  # and then update the owner's contribution as appropriate.
  def self.update_contribution(mode, obj, user_id=nil)

    # Two modes: 1) pass in object, 2) pass in field name
    if obj.is_a?(ActiveRecord::Base)
      field = obj.class.to_s.tableize.to_sym
      user_id ||= obj.user_id rescue nil
    else
      field = obj
      user_id ||= User.current_id
    end

    weight = FIELD_WEIGHTS[field]
    if weight && weight > 0 && user_id
      weight = -weight if mode == :del
      User.connection.update %(
        UPDATE users SET contribution =
          IF(contribution IS NULL, #{weight}, contribution + #{weight})
        WHERE id = #{user_id}
      )
    end

    # Debugging information: show transaction log of all objects created and
    # destroyed, plus all editors/authors added and removed.
    if false
      desc = field.to_s
      if obj.is_a?(ActiveRecord::Base)
        desc += " (new)"              if obj.new_record?
        desc += " ##{obj.id}"         if obj.id
        desc += " (#{obj.text_name})" if obj.respond_to?(:text_name)
      end
      action = ''
      if weight && weight > 0 && user_id
        user = User.safe_find(user_id)
        action += " --> #{user.login} = #{user.contribution}"
      end
      puts ">>>> #{mode} #{weight} #{desc} #{action}"
      puts obj.args.inspect if obj.is_a?(Transaction)
    end
  end

  # Return stats for entire site.  Returns simple hash mapping category to
  # number of records of that category.
  #
  #   data = SiteData.new.get_site_data
  #   num_images = data[:images]
  #
  def get_site_data
    result = {}
    for field in ALL_FIELDS
      result[field] = get_field_count(field)
    end
    result
  end

  # Return stats for a single User.  Returns simple hash mapping category to
  # number of records of that category.
  #
  #   data = SiteData.new.get_user_data(user_id)
  #   num_images = data[:images]
  #
  def get_user_data(id)
    load_user_data(id)
    @user_data[@user_id]
  end

  # Load stats for all User's.  Returns nothing.  Use get_user_data to query
  # individual User's stats.  (This is probably prohibitively expensive.)
  #
  #   data = SiteData.new
  #   data.get_all_user_data
  #   for user in user_list
  #     hash = data.get_user_data(user.id)
  #   end
  #
  def get_all_user_data
    load_user_data(nil)
  end

################################################################################
#
# :section: Private Helpers
#
################################################################################

private

  # Calculate score for a set of results:
  #
  #   score = calc_metric(
  #     :images        => 10,
  #     :observations  => 10,
  #     :comments      => 23,
  #     :species_lists => 1,
  #     ...
  #   )
  #
  def calc_metric(data) # :doc:
    metric = 0
    if data
      for field in ALL_FIELDS
        if data[field]
          # This fixes the double-counting of created records.
          if field.to_s.match(/^(\w+)_versions$/)
            data[field] -= data[$1] || 0
          end
          metric += FIELD_WEIGHTS[field] * data[field]
        end
      end
      metric += data[:bonuses].to_i
      data[:metric] = metric
    end
    return metric
  end

  # Do a query for the number of records in a given category for the entire
  # site.  This is not cached.  Most of these should be inexpensive queries.
  #
  #   count = get_field_count(:images)
  #   # SELECT COUNT(*) FROM `images`
  #
  #   count = get_field_count(:users)
  #   # SELECT COUNT(*) FROM `users` WHERE `verified` IS NOT NULL
  #
  def get_field_count(field) # :doc:
    table = FIELD_TABLES[field] || field.to_s
    query = []
    query << 'SELECT COUNT(*)'
    query << "FROM `#{table}`"
    if cond = FIELD_CONDITIONS[field]
      query << "WHERE #{cond}"
    end
    if field.to_s.match(/^(\w+)s_versions/)
      # Does this actually make sense??
      # parent = $1
      # query[0] = "SELECT COUNT(DISTINCT #{parent}_id, user_id)"
      0
    else
      query = query.join("\n")
      User.connection.select_value(query).to_i
    end
  end

  # Do a query to get the number of records in a given category broken down
  # by User.  This is cached in @user_data.  Gets for a single User, or if
  # none passed in, gets stats for every User.
  #
  #   # Get number of images for current user.
  #   load_field_counts(:images, User.current.id)
  #   num_images = @user_data[User.current.id][:images]
  #
  #   # Get number of images for all users.
  #   load_field_counts(:images)
  #   for user_id User.all.map(&;id)
  #     num_images = @user_data[user_id][:images]
  #   end
  #
  def load_field_counts(field, user_id=nil) # :doc:
    count  = '*'
    table  = FIELD_TABLES[field] || field.to_s
    tables = "#{table} t"
    conditions = "t.user_id " + (user_id ? "= #{user_id}" : "> 0")

    # Exception for species list entries.
    if field == :species_list_entries
      tables = "species_lists t, #{table} os"
      conditions += " AND os.species_list_id = t.id"
    end

    # Exception for past versions.
    if table.match(/^(\w+)s_versions/)
      parent = $1
      count = "DISTINCT #{parent}_id"
      tables += ", #{parent}s p"
      conditions += " AND t.#{parent}_id = p.id"
      conditions += " AND t.user_id != p.user_id"
    end

    query = %(
      SELECT COUNT(#{count}) AS cnt, t.user_id
      FROM #{tables}
      WHERE #{conditions}
      GROUP BY t.user_id
      ORDER BY cnt DESC
    )

    # Get data as:
    #   data = [
    #     [count, user_id],
    #     [count, user_id],
    #     ...
    #   ]
    data = User.connection.select_rows(query)

    # Fill in @user_data structure.
    for count, user_id in data
      user_id = user_id.to_i
      @user_data[user_id] ||= {}
      @user_data[user_id][field] = count.to_i
    end
  end

  # Load all the stats for a given User.  (Load for all User's if none given.)
  #
  #   load_user_data(user.id)
  #   user.contribution = @user_data[user.id][:metric]
  #
  def load_user_data(id=nil) # :doc:
    if !id
      @user_id = nil
      users = User.all
    else
      @user_id = id.to_i
      users = [User.find(id)]
    end

    # Prime @user_data structure.
    @user_data = {}
    for user in users
      @user_data[user.id] = {
        :id      => user.id,
        :name    => user.unique_text_name,
        :bonuses => user.sum_bonuses,
      }
    end

    # Load record counts for each category.
    # (The :users category only applies to site-wide stats.)
    for field in ALL_FIELDS - [:users]
      load_field_counts(field)
    end

    # Calculate full contribution for each user.  This will also correct some
    # double-counting of versioned records.
    for user in users
      contribution = calc_metric(@user_data[user.id])
      # Make sure contribution caches are correct.
      if user.contribution != contribution
        user.contribution = contribution
        user.save
      end
    end
  end
end

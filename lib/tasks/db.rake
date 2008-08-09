namespace :cache do
  desc "Refresh all the caches"
  task :all => [
    :refresh_contributions,
    :refresh_votes
  ]

  desc "Recalculate user contributions"
  task(:refresh_contributions => :environment) do
    print "Refreshing user.contribution...\n"
    SiteData.new.get_all_user_data
  end

  desc "Recalculate vote caches for observations and namings"
  task(:refresh_votes => :environment) do
    print "Refreshing naming.vote_cache...\n"
    for n in Naming.find(:all)
      print "##{n.id}\r"
      n.calc_vote_table
    end
    print "Refreshing observation.vote_cache...\n"
    for o in Observation.find(:all)
      print "##{o.id}\r"
      o.calc_consensus
    end
    print "Done.    \n"
  end
  
  desc "Reset the queued_emails flavor enum"
  task(:refresh_queued_emails => :environment) do
    print "Refreshing flavor enum for queued_emails...\n"
    ActiveRecord::Migration.add_column :queued_emails, :flavor_tmp, :enum, :limit => QueuedEmail.all_flavors
    QueuedEmail.connection.update("update queued_emails set flavor_tmp=flavor+0")
    ActiveRecord::Migration.remove_column :queued_emails, :flavor
    ActiveRecord::Migration.add_column :queued_emails, :flavor, :enum, :limit => QueuedEmail.all_flavors
    QueuedEmail.connection.update("update queued_emails set flavor=flavor_tmp")
    ActiveRecord::Migration.remove_column :queued_emails, :flavor_tmp
  end
end

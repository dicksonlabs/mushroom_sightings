# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class ObservationTest < UnitTestCase

  def create_new_objects
    @cc_obs = Observation.new
    @cc_obs.user = @mary
    @cc_obs.when = Time.now
    @cc_obs.where = "Glendale, California"
    @cc_obs.notes = "New"
    @cc_obs.name = names(:fungi)

    @cc_nam = Naming.new
    @cc_nam.user = @mary
    @cc_nam.name = names(:fungi)
    @cc_nam.observation = @cc_obs
  end

################################################################################

  # Add an observation to the database
  def test_create
    create_new_objects
    assert_kind_of(Observation, observations(:minimal_unknown))
    assert_kind_of(Observation, @cc_obs)
    assert_kind_of(Naming, namings(:minimal_unknown_naming))
    assert_kind_of(Naming, @cc_nam)
    assert_save(@cc_obs)
    assert_save(@cc_nam)
  end

  def test_update
    create_new_objects
    assert_save(@cc_nam)
    assert_equal names(:fungi), @cc_nam.name
    @cc_nam.name = names(:coprinus_comatus)
    assert_save(@cc_nam)
    @cc_nam.reload
    assert_equal(names(:coprinus_comatus).search_name, @cc_nam.text_name)
  end

  # Test setting a name using a string
  def test_validate
    create_new_objects
    @cc_obs.user = nil
    @cc_obs.when = nil
    @cc_obs.where = nil
    assert(!@cc_obs.save)
    assert_equal(3, @cc_obs.errors.count)
    assert_equal(:validate_observation_user_missing.t, @cc_obs.errors.on(:user))
    assert_equal(:validate_observation_when_missing.t, @cc_obs.errors.on(:when))
    assert_equal(:validate_observation_where_missing.t, @cc_obs.errors.on(:where))
  end

  def test_destroy
    create_new_objects
    User.current = @rolf
    assert_save(@cc_obs)
    assert_save(@cc_nam)
    @cc_obs.destroy
    assert_raise(ActiveRecord::RecordNotFound) { Observation.find(@cc_obs.id) }
    assert_raise(ActiveRecord::RecordNotFound) { Naming.find(@cc_nam.id) }
  end

  def test_all_observations_order
    obs = Observation.all(:order => "id")
    assert_equal(observations(:coprinus_comatus_obs).id, obs[2].id)
    assert_equal(observations(:detailed_unknown).id, obs[1].id)
  end

  def test_remove_image_twice
    observations(:minimal_unknown).images = [
      images(:commercial_inquiry_image),
      images(:disconnected_coprinus_comatus_image),
      images(:connected_coprinus_comatus_image)
    ]
    observations(:minimal_unknown).thumb_image = images(:commercial_inquiry_image)
    observations(:minimal_unknown).remove_image(images(:commercial_inquiry_image))
    assert_equal(observations(:minimal_unknown).thumb_image, images(:disconnected_coprinus_comatus_image))
    observations(:minimal_unknown).remove_image(images(:disconnected_coprinus_comatus_image))
    assert_equal(observations(:minimal_unknown).thumb_image, images(:connected_coprinus_comatus_image))
  end

  def test_name_been_proposed
    assert(observations(:coprinus_comatus_obs).name_been_proposed?(names(:coprinus_comatus)))
    assert(observations(:coprinus_comatus_obs).name_been_proposed?(names(:agaricus_campestris)))
    assert(!observations(:coprinus_comatus_obs).name_been_proposed?(names(:conocybe_filaris)))
  end

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------

  def test_email_notification_1
    Notification.all.map(&:destroy)
    QueuedEmail.queue_emails(true)

    obs = observations(:coprinus_comatus_obs)

    # Make sure Rolf has requested emails.
    @rolf.email_comments_owner = true
    @rolf.email_comments_response = true
    @rolf.email_observations_naming = true
    @rolf.email_observations_consensus = true
    assert_save(@rolf)

    # Make sure observation name starts as Coprinus comatus.
    assert_equal(names(:coprinus_comatus), obs.name)

    # Observation owner is not notified if comment added by themselves.
    # (Rolf owns coprinus_comatus_obs, one naming, two votes, conf. around 1.5.)
    User.current = @rolf
    new_comment = Comment.create(
      :summary => 'This is Rolf...',
      :target  => obs
    )
    assert_equal(0, QueuedEmail.count)

    # Observation owner is not notified if naming added by themselves.
    User.current = @rolf
    new_naming = Naming.create(
      :observation => obs,
      :name        => names(:agaricus_campestris),
      :vote_cache  => 0
    )
    assert_equal(0, QueuedEmail.count)
    assert_equal(names(:coprinus_comatus), obs.reload.name)

    # Observation owner is not notified if consensus changed by themselves.
    User.current = @rolf
    obs.change_vote(new_naming, 3)
    assert_equal(names(:agaricus_campestris), obs.reload.name)
    assert_equal(0, QueuedEmail.count)

    # Make Rolf opt out of all emails.
    @rolf.email_comments_owner = false
    @rolf.email_comments_response = false
    @rolf.email_observations_naming = false
    @rolf.email_observations_consensus = false
    assert_save(@rolf)

    # Rolf should not be notified of anything here, either...
    User.current = @dick
    new_comment = Comment.create(
      :summary => 'This is Dick...',
      :target  => observations(:coprinus_comatus_obs)
    )
    assert_equal(0, QueuedEmail.count)

    User.current = @dick
    new_naming = Naming.create(
      :observation => obs,
      :name        => names(:peltigera),
      :vote_cache  => 0
    )
    assert_equal(0, QueuedEmail.count)
    assert_equal(names(:agaricus_campestris), obs.reload.name)

    # Make sure this changes consensus...
    @dick.contribution = 100000000000
    assert_save(@dick)

    User.current = @dick
    obs.change_vote(new_naming, 3)
    assert_equal(names(:peltigera), obs.reload.name)
    assert_equal(0, QueuedEmail.count)
  end

  def test_email_notification_2
    Notification.all.map(&:destroy)
    QueuedEmail.queue_emails(true)

    obs = observations(:coprinus_comatus_obs)

    # Make sure Rolf has requested no emails (will turn on one at a time to be
    # sure the right pref affects the right notification).
    @rolf.email_comments_owner = false
    @rolf.email_comments_response = false
    @rolf.email_observations_naming = false
    @rolf.email_observations_consensus = false
    assert_save(@rolf)

    # Observation owner is notified if comment added by someone else.
    # (Rolf owns observations(:coprinus_comatus_obs), one naming, two votes, conf. around 1.5.)
    @rolf.email_comments_owner = true
    assert_save(@rolf)
    User.current = @mary
    new_comment = Comment.create(
      :summary => 'This is Mary...',
      :target  => obs
    )
    assert_equal(1, QueuedEmail.count)
    assert_email(0,
      :flavor  => 'QueuedEmail::CommentAdd',
      :from    => @mary,
      :to      => @rolf,
      :comment => new_comment.id
    )

    # Observation owner is notified if naming added by someone else.
    @rolf.email_comments_owner = false
    @rolf.email_observations_naming = true
    assert_save(@rolf)
    User.current = @mary
    new_naming = Naming.create(
      :observation => obs.reload,
      :name        => names(:agaricus_campestris),
      :vote_cache  => 0
    )
    assert_equal(2, QueuedEmail.count)
    assert_email(1,
      :flavor      => 'QueuedEmail::NameProposal',
      :from        => @mary,
      :to          => @rolf,
      :observation => obs.id,
      :naming      => new_naming.id
    )

    # Observation owner is notified if consensus changed by someone else.
    @rolf.email_observations_naming = false
    @rolf.email_observations_consensus = true
    assert_save(@rolf)
    # (Actually, Mary already gave this her highest possible vote,
    # so think of this as Mary changing Rolf's vote. :)
    User.current = @mary
    obs.change_vote(namings(:coprinus_comatus_other_naming), 3, @rolf)
    assert_equal(3, votes(:coprinus_comatus_other_naming_rolf_vote).reload.value)
    assert_equal(3, QueuedEmail.count)
    assert_email(2,
      :flavor      => 'QueuedEmail::ConsensusChange',
      :from        => @mary,
      :to          => @rolf,
      :observation => obs.id,
      :old_name    => names(:coprinus_comatus).id,
      :new_name    => names(:agaricus_campestris).id
    )

    # Make sure Mary gets notified if Rolf responds to her comment.
    @mary.email_comments_response = true
    assert_save(@mary)
    User.current = @rolf
    new_comment = Comment.create(
      :summary => 'This is Rolf...',
      :target  => observations(:coprinus_comatus_obs)
    )
    assert_equal(4, QueuedEmail.count)
    assert_email(3,
      :flavor  => 'QueuedEmail::CommentAdd',
      :from    => @rolf,
      :to      => @mary,
      :comment => new_comment.id
    )
  end

  def test_email_notification_3
    Notification.all.map(&:destroy)
    QueuedEmail.queue_emails(true)

    obs = observations(:coprinus_comatus_obs)

    # Make sure Rolf has requested emails.
    @rolf.email_comments_owner = true
    @rolf.email_comments_response = true
    @rolf.email_observations_naming = true
    @rolf.email_observations_consensus = true
    assert_save(@rolf)

    # Make sure Dick has requested no emails.
    @dick.email_comments_owner = false
    @dick.email_comments_response = false
    @dick.email_observations_naming = false
    @dick.email_observations_consensus = false
    assert_save(@dick)

    # Make Rolf ignore his own observation (will override prefs).
    Interest.create(
      :target => obs,
      :user   => @rolf,
      :state  => false
    )

    # But make Dick watch it (will override prefs).
    Interest.create(
      :target => observations(:coprinus_comatus_obs),
      :user   => @dick,
      :state  => true
    )

    # Watcher is notified if comment added.
    # (Rolf owns observations(:coprinus_comatus_obs), one naming, two votes, conf. around 1.5.)
    User.current = @mary
    new_comment = Comment.create(
      :summary => 'This is Mary...',
      :target  => observations(:coprinus_comatus_obs)
    )
    assert_equal(1, QueuedEmail.count)
    assert_email(0,
      :flavor  => 'QueuedEmail::CommentAdd',
      :from    => @mary,
      :to      => @dick,
      :comment => new_comment.id
    )

    # Watcher is notified if naming added.
    User.current = @mary
    new_naming = Naming.create(
      :observation => observations(:coprinus_comatus_obs),
      :name        => names(:agaricus_campestris),
      :vote_cache  => 0
    )
    assert_equal(2, QueuedEmail.count)
    assert_email(1,
      :flavor      => 'QueuedEmail::NameProposal',
      :from        => @mary,
      :to          => @dick,
      :observation => observations(:coprinus_comatus_obs).id,
      :naming      => new_naming.id
    )

    # Watcher is notified if consensus changed.
    # (Actually, Mary already gave this her highest possible vote,
    # so think of this as Mary changing Rolf's vote. :)
    User.current = @mary
    obs.change_vote(namings(:coprinus_comatus_other_naming), 3, @rolf)
    assert_equal(3, votes(:coprinus_comatus_other_naming_rolf_vote).reload.value)
    assert_save(votes(:coprinus_comatus_other_naming_rolf_vote))
    assert_equal(3, QueuedEmail.count)
    assert_email(2,
       :flavor      => 'QueuedEmail::ConsensusChange',
       :from        => @mary,
       :to          => @dick,
       :observation => observations(:coprinus_comatus_obs).id,
       :old_name    => names(:coprinus_comatus).id,
       :new_name    => names(:agaricus_campestris).id
    )

    # Now have Rolf make a bunch of changes...
    User.current = @rolf

    # Watcher is also notified of changes in the observation.
    obs.notes = 'I have new information on this observation.'
    obs.save
    assert_equal(4, QueuedEmail.count)

    # Make sure subsequent changes update existing email.
    obs.where = 'Somewhere else'
    obs.save
    assert_equal(4, QueuedEmail.count)

    # Same deal with adding and removing images.
    obs.add_image(images(:disconnected_coprinus_comatus_image))
    assert_equal(4, QueuedEmail.count)
    obs.remove_image(images(:disconnected_coprinus_comatus_image))
    assert_equal(4, QueuedEmail.count)

    # All the above modify this email:
    assert_email(3,
      :flavor      => 'QueuedEmail::ObservationChange',
      :from        => @rolf,
      :to          => @dick,
      :observation => observations(:coprinus_comatus_obs).id,
      :note        => 'notes,location,thumb_image_id,added_image,removed_image'
    )
  end

  def test_email_notification_4
    Notification.all.map(&:destroy)
    QueuedEmail.queue_emails(true)

    obs = observations(:coprinus_comatus_obs)

    marys_interest = Interest.create(
      :target => observations(:coprinus_comatus_obs),
      :user   => @mary,
      :state  => false
    )

    dicks_interest = Interest.create(
      :target => observations(:coprinus_comatus_obs),
      :user   => @dick,
      :state  => false
    )

    katrinas_interest = Interest.create(
      :target => observations(:coprinus_comatus_obs),
      :user   => @katrina,
      :state  => false
    )

    # Make change to observation.
    marys_interest.state = true
    assert_save(marys_interest)

    User.current = @rolf
    observations(:coprinus_comatus_obs).notes = 'I have new information on this observation.'
    observations(:coprinus_comatus_obs).save
    assert_equal(1, QueuedEmail.count)
    assert_email(0,
      :flavor      => 'QueuedEmail::ObservationChange',
      :from        => @rolf,
      :to          => @mary,
      :observation => observations(:coprinus_comatus_obs).id,
      :note        => 'notes'
    )

    # Add image to observation.
    marys_interest.state = false
    assert_save(marys_interest)
    dicks_interest.state = true
    assert_save(dicks_interest)

    User.current = @rolf
    obs.reload.add_image(images(:disconnected_coprinus_comatus_image))
    assert_equal(2, QueuedEmail.count)
    assert_email(1,
      :flavor      => 'QueuedEmail::ObservationChange',
      :from        => @rolf,
      :to          => @dick,
      :observation => observations(:coprinus_comatus_obs).id,
      :note        => 'thumb_image_id,added_image'
    )

    # Destroy observation.
    dicks_interest.state = false
    assert_save(dicks_interest)
    katrinas_interest.state = true
    assert_save(katrinas_interest)

    User.current = @rolf
    obs.reload.destroy
    assert_equal(3, QueuedEmail.count)
    assert_email(2,
      :flavor      => 'QueuedEmail::ObservationChange',
      :from        => @rolf,
      :to          => @katrina,
      :observation => 0,
      :note        => '**__Coprinus comatus__** (O.F. Müll.) Pers. (3)'
    )
  end

#   def test_vote_favorite
#     @fungi = names(:fungi)
#     @name1 = names(:agaricus_campestris)
#     @name2 = names(:coprinus_comatus)
#     @name3 = names(:conocybe_filaris)
# 
#     User.current = @rolf
#     obs = Observation.create!(
#       :when    => Date.today,
#       :where   => "anywhere",
#       :name_id => @fungi.id
#     )
# 
#     User.current = @rolf
#     nam1 = Naming.create!(
#       :observation_id => obs.id,
#       :name_id => @name1.id
#     )
# 
#     User.current = @mary
#     nam2 = Naming.create!(
#       :observation_id => obs.id,
#       :name_id => @name2.id
#     )
# 
#     User.current = @dick
#     nam3 = Naming.create!(
#       :observation_id => obs.id,
#       :name_id => @name3.id
#     )
# 
#     # Okay, nothing has votes yet.
#     obs.reload
#     assert_equal(@fungi, obs.name)
#     assert_equal(nil, obs.consensus_naming)
#     assert_equal(false, obs.owner_voted?(nam1))
#     assert_equal(false, obs.user_voted?(nam1, @rolf))
#     assert_equal(false, obs.user_voted?(nam1, @mary))
#     assert_equal(false, obs.user_voted?(nam1, @dick))
#     assert_equal(nil, obs.owners_vote(nam1))
#     assert_equal(nil, obs.users_vote(nam1, @rolf))
#     assert_equal(nil, obs.users_vote(nam1, @mary))
#     assert_equal(nil, obs.users_vote(nam1, @dick))
#     assert_equal(false, obs.is_users_favorite?(nam1, @rolf))
#     assert_equal(false, obs.is_users_favorite?(nam1, @mary))
#     assert_equal(false, obs.is_users_favorite?(nam1, @dick))
# 
#     # They're all the same, none with votes yet, so first apparently wins.
#     obs.calc_consensus
#     assert_names_equal(@name1, obs.name)
#     assert_equal(nam1, obs.consensus_naming)
# 
#     # Play with Rolf's vote for his naming (first naming).
#     obs.change_vote(nam1, 2, @rolf)
#     assert_true(obs.owner_voted?(nam1))
#     assert_true(obs.user_voted?(nam1, @rolf))
#     assert_true(vote = obs.owners_vote(nam1))
#     assert_equal(vote, obs.users_vote(nam1, @rolf))
#     assert_equal(vote, nam1.users_vote(@rolf))
#     assert_true(obs.is_owners_favorite?(nam1))
#     assert_true(obs.is_users_favorite?(nam1, @rolf))
#     assert_true(nam1.is_users_favorite?(@rolf))
#     assert_names_equal(@name1, obs.name)
#     assert_equal(nam1, obs.consensus_naming)
# 
#     obs.change_vote(nam1, 0.01, @rolf)
# puts obs.dump_votes
#     assert_true(obs.is_owners_favorite?(nam1))
#     assert_names_equal(@name1, obs.name)
#     assert_equal(nam1, obs.consensus_naming)
# 
#     obs.change_vote(nam1, -0.01, @rolf)
#     assert_false(obs.is_owners_favorite?(nam1))
#     assert_false(nam1.is_users_favorite?(@rolf))
#     assert_names_equal(@name1, obs.name)
#     assert_equal(nam1, obs.consensus_naming)
# 
#     # Play with Rolf's vote for other namings.
#     obs.change_vote(nam2, 1, @rolf)
#     assert_false(nam1.is_owners_favorite?)
#     assert_true(nam2.is_owners_favorite?)
#     assert_false(nam3.is_owners_favorite?)
#     assert_names_equal(@name2, obs.name)
#     assert_equal(nam2, obs.consensus_naming)
# 
#     obs.change_vote(nam3, 2, @rolf)
#     assert_false(nam1.is_owners_favorite?)
#     assert_false(nam2.is_owners_favorite?)
#     assert_true(nam3.is_owners_favorite?)
#     assert_names_equal(@name3, obs.name)
#     assert_equal(nam3, obs.consensus_naming)
# 
#     obs.change_vote(nam1, 3, @rolf)
#     assert_true(nam1.is_owners_favorite?)
#     assert_false(nam2.is_owners_favorite?)
#     assert_false(nam3.is_owners_favorite?)
#     assert_names_equal(@name1, obs.name)
#     assert_equal(nam1, obs.consensus_naming)
# 
#     obs.change_vote(nam1, 1, @rolf)
#     assert_false(nam1.is_owners_favorite?)
#     assert_false(nam2.is_owners_favorite?)
#     assert_true(nam3.is_owners_favorite?)
#     assert_names_equal(@name3, obs.name)
#     assert_equal(nam3, obs.consensus_naming)
# 
#     # Play with Mary's vote.
#     obs.change_vote(nam1, 1, @mary)
#     obs.change_vote(nam2, 2, @mary)
#     obs.change_vote(nam3, -1, @mary)
#     assert_false(nam1.is_users_favorite?(@mary))
#     assert_true(nam2.is_users_favorite?(@mary))
#     assert_false(nam3.is_users_favorite?(@mary))
#     assert_names_equal(@name3, obs.name)
#     assert_equal(nam3, obs.consensus_naming)
# 
#     obs.change_vote(nam2, 0.01, @mary)
#     assert_true(nam1.is_users_favorite?(@mary))
#     assert_false(nam2.is_users_favorite?(@mary))
#     assert_false(nam3.is_users_favorite?(@mary))
#     assert_names_equal(@name3, obs.name)
#     assert_equal(nam3, obs.consensus_naming)
# 
#     obs.change_vote(nam1, -0.01, @mary)
#     assert_false(nam1.is_users_favorite?(@mary))
#     assert_true(nam2.is_users_favorite?(@mary))
#     assert_false(nam3.is_users_favorite?(@mary))
#     assert_false(nam1.is_users_favorite?(@rolf))
#     assert_false(nam2.is_users_favorite?(@rolf))
#     assert_true(nam3.is_users_favorite?(@rolf))
#     assert_false(nam1.is_users_favorite?(@dick))
#     assert_false(nam2.is_users_favorite?(@dick))
#     assert_false(nam3.is_users_favorite?(@dick))
#     assert_names_equal(@name3, obs.name)
#     assert_equal(nam3, obs.consensus_naming)
#   end
end

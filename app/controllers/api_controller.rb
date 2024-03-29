# encoding: utf-8
#
#  = API and AJAX Controller
#
#  This controller handles the XML interface.
#
#  == Actions
#
#  xml_rpc::      Entry point for XML-RPC requests.
#  <table>::      Entry point for REST requests.
#  ajax::         Entry point for AJAX requests.
#  test::         Test action that just renders "test".
#
################################################################################

require 'geocoder'

class ApiController < ApplicationController
  require 'xmlrpc/client'

  # Disable all filters except set_locale.
  skip_filter   :browser_status
  skip_filter   :check_user_alert
  skip_filter   :autologin
  skip_filter   :extra_gc

  before_filter :disable_link_prefetching
  before_filter { User.current = nil }

  # Used for testing.
  def test
    render(:text => 'test', :layout => false)
  end

  # ----------------------------
  #  XML-RPC
  # ----------------------------

  # Standard entry point for XML-RPC requests.
  def xml_rpc
    begin
      @@xmlrpc_reader ||= XMLRPC::XMLParser::REXMLStreamParser.new
      method, args = @@xmlrpc_reader.parseMethodCall(request.content)
      if (args.length != 1) or
         !args[0].is_a?(Hash)
        raise "Invalid request; expecting a single hash of named parameters."
      end
      args = args.first
      args[:method] = method
      args[:_safe] = false
      xact = Transaction.new(args)
      xact.validate_args
      api = xact.execute
      render_results(api)
    rescue => e
      api = API.new
      @errors = api.convert_error(e, 501, nil, true)
      render_results(api)
    end
  end

  # ----------------------------
  #  REST
  # ----------------------------

  # Standard entry point for REST requests.
  def comments;      rest_query(:comment);      end
  def images;        rest_query(:image);        end
  def interests;     rest_query(:interest);     end
  def licenses;      rest_query(:license);      end
  def locations;     rest_query(:location);     end
  def names;         rest_query(:name);         end
  def namings;       rest_query(:naming);       end
  def notifications; rest_query(:notification); end
  def observations;  rest_query(:observation);  end
  def projects;      rest_query(:project);      end
  def species_lists; rest_query(:species_list); end
  def synonyms;      rest_query(:synonym);      end
  def user_groups;   rest_query(:user_group);   end
  def users;         rest_query(:user);         end
  def votes;         rest_query(:vote);         end

  def rest_query(type)
    @start_time = Time.now

    # Massage params into a proper set of args.
    args = {}
    for key in params.keys
      args[key.to_sym] = params[key]
    end
    args.delete(:controller)
    args[:method] = request.method.to_s
    args[:action] = type.to_s
    args[:http_request_body] = request if request.content_length.to_i > 0
    args[:_safe] = false

    api = API.execute(args)
    render_results(api)
  end

  def render_results(api)
    headers['Content-Type'] = 'application/xml'

    @results = api.results
    @errors  = api.errors
    @user    = api.user
    @query   = api.query
    @detail  = api.detail
    @number  = api.number
    @page    = api.page
    @pages   = api.pages
    @version = api.version

    begin
      if [:get, :post].include?(request.method)
        render(:layout => 'api')
      else
        render(:layout => 'api', :text => '')
      end
    rescue => e
      @errors << api.convert_error(e, 501, nil, true)
      render(:layout => 'api', :text => '')
    end
  end

  # ----------------------------
  #  AJAX
  # ----------------------------

  # Standard entry point for AJAX requests.  AJAX requests are routed here from
  # URLs that look like this:
  #
  #   http://domain.org/ajax/method
  #   http://domain.org/ajax/method/id
  #   http://domain.org/ajax/method/type/id
  #
  # Syntax of successful responses vary depending on the method.
  #
  # Errors are status 500, with the response body being the error message.
  # Semantics of the error possible messages varies depending on the method.
  #
  def ajax
    begin
      send("ajax_#{params[:method]}")
    rescue => e
      msg = e.to_s
      msg += "\n" + e.backtrace.join("\n") if DEVELOPMENT
      render(:text => msg, :layout => false, :status => 500)
    end
  end

  # Process AJAX request for auto-completion of species name.
  # type::   Type of strings we're auto-completing.
  # letter:: First letter user typed in.
  #
  # Valid types are:
  # name::     Returns Name#text_name starting with the given letter.
  # location:: Returns Observation#where or Location#display_name with a word
  #            starting with the given letter.
  # species_list:: Returns SpeciesList#title starting with the given letter.
  # user::     Returns "login <Full Name>" with a word starting with the given letter.
  #
  # Examples:
  #
  #   /ajax/auto_complete/name/A
  #   /ajax/auto_complete/location/w
  #
  def ajax_auto_complete
    type  = params[:type].to_s
    instr = params[:id].to_s
    letter = ' '
    scientific = false
    user = login_for_ajax
    if user
      scientific = (user.location_format == :scientific)
    end
    @items = []
    if instr.match(/^(\w)/)
      letter = $1
      case type

      when 'location'
        @items = Observation.connection.select_values(%(
          SELECT DISTINCT `where` FROM observations
          WHERE `where` LIKE '#{letter}%' OR
                `where` LIKE '% #{letter}%'
        )) + Location.connection.select_values(%(
          SELECT DISTINCT `name` FROM locations
          WHERE `name` LIKE '#{letter}%' OR
                `name` LIKE '% #{letter}%'
        ))
        if scientific
          @items.map! {|i| Location.reverse_name(i)}
        end
        @items.sort!

      when 'name'
        @items = Name.connection.select_values %(
          SELECT text_name FROM names
          WHERE text_name LIKE '#{letter}%'
          AND correct_spelling_id IS NULL
          ORDER BY text_name ASC
        )

      when 'name2'
        @items = Name.connection.select_values(%(
          SELECT text_name FROM names
          WHERE text_name LIKE '#{instr}%'
          AND correct_spelling_id IS NULL
          ORDER BY text_name ASC
        )).sort_by {|x| (x.match(' ') ? 'b' : 'a') + x}
        # This sort puts genera and higher on top, everything else on bottom,
        # and sorts alphabetically within each group.
        letter = ''

      when 'project'
        @items = Project.connection.select_values %(
          SELECT title FROM projects
          WHERE title LIKE '#{letter}%'
             OR title LIKE '%#{letter}%'
          ORDER BY title ASC
        )

      when 'species_list'
        @items = SpeciesList.connection.select_values %(
          SELECT title FROM species_lists
          WHERE title LIKE '#{letter}%'
             OR title LIKE '%#{letter}%'
          ORDER BY title ASC
        )

      when 'user'
        @items = User.connection.select_values %(
          SELECT CONCAT(users.login, IF(users.name = "", "", CONCAT(" <", users.name, ">")))
          FROM users
          WHERE login LIKE '#{letter}%'
             OR name LIKE '#{letter}%'
             OR name LIKE '% #{letter}%'
          ORDER BY login ASC
        )
      end
    end

    # Result is the letter requested followed by results, one per line.  (It
    # truncates any results that have newlines in them -- that's an error.)
    render(:layout => false, :inline => letter +
      %(<%= @items.uniq.map {|n| h(n.gsub(/[\r\n].*/,'')) + "\n"}.join('') %>))
  end

  # Process AJAX request for casting votes.
  # type::   Type of object.
  # id::     ID of object.
  # value::  Value of vote.
  #
  # Valid types are:
  # naming:: Vote on a proposed id -- any logged-in user.
  # image::  Vote on an image -- only reviewers.
  #
  # Examples:
  #
  #   /ajax/vote/naming/1234?value=2
  #   /ajax/vote/image/1234?value=4
  #
  def ajax_vote
    type  = params[:type].to_s
    id    = params[:id].to_s
    value = params[:value].to_s

    result = nil
    if user = login_for_ajax
      case type

      when 'naming'
        if (value = Vote.validate_value(val)) and
           (naming = Naming.safe_find(id))
          naming.observation.change_vote(naming, value, user)
          Transaction.put_naming(:id => naming, :_user => user,
                                 :set_vote => value)
          render(:text => result.to_s)
        else
          render(:text => '')
        end

      when 'image'
        if (value == '0' or (value = Image.validate_vote(value))) and
           (image = Image.safe_find(id))
          value = nil if value == '0'
          image.change_vote(user, value)
          Transaction.put_image(:id => image, :_user => user,
                                :set_vote => value)
          @image, @user = image, user
          render(:inline => '<%= image_vote_tabs(@image) %>')
        else
          render(:text => '')
        end
      end
    end
  end

  # Process AJAX request for geocoding and location name.
  # name::   Name of location
  #
  # Valid types are:
  # name:: Comma separate string in the order indicated by the user's preference (default is Postal)
  #
  # Examples:
  #
  #   /ajax/geocode?name=Falmouth, Massachusetts, USA
  #
  def ajax_geocode
    name  = params[:name].to_s
    if params[:format]
      name = Location.reverse_name(name) if params[:format] == "scientific"
    else
      name = Location.reverse_name(name) if login_for_ajax.location_format == :scientific
    end
    render(:inline => Geocoder.new(name).ajax_response)
  end

  # Process AJAX requests for Pivotal stories.
  # type::   Type of request: 'story', 'vote', 'comment'
  # id::     ID of story.
  # value::  Value of comment or vote (as necessary).
  #
  # Examples:
  #
  #   /ajax/pivotal/story/991235
  #   /ajax/pivotal/vote/991235?value=2
  #   /ajax/pivotal/comment/991235?value=Blah%20blah%20blah...
  #
  def ajax_pivotal
    type  = params[:type].to_s
    id    = params[:id].to_s
    value = params[:value].to_s
    case type
    when 'story'
      @story = Pivotal.get_story(id)
      render(:inline => '<%= pivotal_story(@story) %>')
    when 'vote'
      @user = login_for_ajax
      @story = Pivotal.cast_vote(id, @user, value)
      render(:inline => '<%= pivotal_vote_controls(@story) %>')
    when 'comment'
      user = login_for_ajax
      story = Pivotal.get_story(id)
      @comment = Pivotal.post_comment(id, user, value)
      @num = story.comments.length + 1
      render(:inline => '<%= pivotal_comment(@comment, @num) %>')
    else
      raise("Invalid type \"#{type}\" in Pivotal AJAX controller.")
    end
  end
end

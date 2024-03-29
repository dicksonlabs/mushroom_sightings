# encoding: utf-8
#
#  = Integration Session Test Helpers
#
#  Methods in this class are available to all the integration tests.
#
#  ==== Debugging
#  dump_links::       Show list of all the links on the last page rendered.
#  save_page::        Save response from last request in a file.
#  get::              Call get_via_redirect with extra error checking.
#  post::             Call post_via_redirect with extra error checking.
#  get_without_redirecting::  Call the original 'get'.
#  post_without_redirecting:: Call the original 'post'.
#
#  ==== Helpers
#  parse_query_params:: Get (our) query params from the given URL.
#  get_links::        Get an Array of URLs for a set of links.
#  login::            Log in a given user.
#  logout::           Log out the current user.
#
#  ==== Navigation
#  push_page::        Save response from last query so we can go back to it.
#  go_back::          Go back a number of times.
#  click::         Click on first link that matches the given args.
#
#  ==== Forms
#  open_form::          Encapsulate filling out and posting a given form.
#
################################################################################

module SessionExtensions

  ##############################################################################
  #
  #  :section: Debugging
  #
  ##############################################################################

  # Dump out a list of all the links on the last page rendered.
  def dump_links
    assert_select('a[href]') do |links|
      for link in links
        puts "link: #{link.attributes['href']}"
      end
    end
  end

  # Save response from last request so you can look at it in a browser.
  def save_page(file=nil)
    file ||= "#{RAILS_ROOT}/public/test.html"
    File.open(file, 'w') do |fh|
      fh.write(response.body)
    end
  end

  # Call get/post_via_redirect, checking for 500 errors and missing language
  # tags.  Saves body of all successful responses for debugging, too.
  def process_with_error_checking(method, url, *args)
    @doing_with_error_checking = true
    Symbol.missing_tags = []
    send("#{method}_via_redirect", url, *args)
    if status == 500
      if error = controller.instance_variable_get('@error')
        msg = "#{error}\n#{error.backtrace.join("\n")}"
      else
        msg = 'Got unknown 500 error from outside our application?!'
      end
      assert_block(msg) { false }
    end
    assert_equal([], Symbol.missing_tags, "Language tag(s) are missing.")
    save_page
  ensure
    @doing_with_error_checking = false
  end

  # Override all 'get' calls and do a bunch of extra error checking.
  def get(*args)
    if !@doing_with_error_checking
      process_with_error_checking('get', *args)
    else
      super
    end
  end

  # Override all 'post' calls and do a bunch of extra error checking.
  def post(*args)
    if !@doing_with_error_checking
      process_with_error_checking('post', *args)
    else
      super
    end
  end

  # Call the original +get+.
  def get_without_redirecting(*args)
    @doing_with_error_checking = true
    get(*args)
  ensure
    @doing_with_error_checking = false
  end

  # Call the original +post+.
  def post_without_redirecting(*args)
    @doing_with_error_checking = true
    post(*args)
  ensure
    @doing_with_error_checking = false
  end

  ##############################################################################
  #
  #  :section: Random Helpers
  #
  ##############################################################################

  # Get string representing (our) query from the given URL.  Defaults to the
  # current page's URL.  (In practice, for now, this is just the Query id.)
  def parse_query_params(url=path)
    path, query = url.split('?')
    params = CGI.parse(query)
    params['q']
  end

  # Get an Array of URLs for the given links.
  #
  #   # This gets all the name links in the results of the last page.
  #   urls = get_links('div.results a[href^=/name/show_name]')
  #
  def get_links(*args)
    clean_our_backtrace do
      results = []
      assert_select(*args) do |links|
        results = links.map {|l| l.attributes['href']}
      end
      return results
    end
  end

  # Login the given user, do no testing, doesn't re-get login form if already
  # served.
  def login(login, password='testpassword', remember_me=true)
    login = login.login if login.is_a?(User)
    get('/account/login') if path != '/account/login'
    open_form do |form|
      form.change('login', login)
      form.change('password', password)
      form.change('remember_me', remember_me)
      form.submit('Login')
    end
  end

  # Logion the given user, testing to make sure it was successful.
  def login!(user, *args)
    login(user, *args)
    assert_flash(/success/i)
    user = User.find_by_login(user) if user.is_a?(String)
    assert_users_equal(user, assigns(:user), "Wrong user ended up logged in!")
  end

  # Logout the current user and make sure it was successful.
  def logout
    click(:label => 'Logout')
    assert_flash(/success/i)
  end

  # Look up a given form, initialize a Hash of parameters for it, and wrap up
  # the whole thing in a Form instance.  Returns (and yields) an instance of
  # IntegrationSession::Form.  (If no parameters passed, by default it looks
  # for a form that posts back to the same page.)
  def open_form(*args)
    form = nil
    clean_our_backtrace do
      if args == []
        action = path.sub(/\?.*/, '')
        args << "form[action*=#{action}]"
      end
      assert_select(*args) do |elems|
        assert_equal(1, elems.length,
                     "Found multiple forms matching #{args.inspect}.")
        elem = elems.first
        assert_equal('form', elem.name,
                     "Expected #{args.inspect} to find a form!")
        form = Form.new(self, elem)
        yield(form) if block_given?
      end
    end
    return form
  end

  ##############################################################################
  #
  #  :section: Navigation
  #
  ##############################################################################

  # Save response from last query on the page stack.
  def push_page(name='')
    @page_stack ||= []
    @page_stack.push({
      :name => name,
      :body => response.body,
    })
  end

  # Go back one or more times and restore a previous query result.  If called
  # with no argument, it just restores the previous page and doesn't affect the
  # stack.  If called with 2, it pops one page off the stack then restores the
  # page before that.  And so on.
  def go_back(arg=1)
    if arg.is_a?(Fixnum)
      while arg > 1
        @page_stack.pop
        arg -= 1
      end
    else
      while @page_stack.any? and (@page_stack.last[:name] != arg)
        @page_stack.pop
      end
      if @page_stack.empty?
        raise("Missing page called #{name.inspect}!")
      end
    end
    response.body = @page_stack.last[:body]
    @html_document = HTML::Document.new(response.body)
    save_page
  end

  # Click on the first link matching the given args.  Args can be:
  # label:: Label contains a String or matches a Regexp.
  # href::  URL starts with a String or matches a Regexp.
  # in::    Link contained in a given element type(s).
  def click(args={})
    clean_our_backtrace do
      select = 'a[href]'
      sargs  = []

      # Filter links based on URL.
      if arg = args[:href]
        if arg.is_a?(Regexp)
          if arg.to_s.match(/^..-mix:\^/)
            select = "a[href^=?]"
          else
            select = "a[href*=?]"
          end
          sargs << arg
        else
          select = "a[href^=#{arg}]"
        end
      end

      # Filter links by parent element types.
      if arg = args[:in]
        if arg == :tabs
          arg = 'div#left_tabs'
        elsif arg == :left_panel
          arg = 'table.LeftSide'
        elsif arg == :results
          arg = 'div.results'
        end
        select = "#{arg} #{select}"
      end

      done = false
      assert_select(select, *sargs) do |links|
        for link in links
          match = true

          # Filter based on link "label" (can be an image too, for example).
          if arg = args[:label]
            if arg == :image
              match = false if !link.to_s.match(/<img /)
            elsif arg.is_a?(Regexp)
              match = false if !link.to_s.match(arg)
            else
              match = false if !link.to_s.index(arg)
            end
          end

          # Click on first link that matches everything.
          if match
            url = CGI.unescapeHTML(link.attributes['href'])
            get(url)
            done = true
            break
          end
        end
      end

      assert_block("Expected a link matching: #{args.inspect}") { done }
    end
  end
end

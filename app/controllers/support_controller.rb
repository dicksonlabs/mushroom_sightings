class SupportController < ApplicationController
  def donate
    store_location
    @donation = Donation.new
    @donation.user = @user
    @donation.amount = 100.00
    if @user
      @donation.who = @user.name
      @donation.email = @user.email
    end
  end
  
  def create_donation
    if is_in_admin_mode?
      @donation = Donation.new
      if request.method == :post
        @donation.amount = params['donation']['amount']
        @donation.who = params['donation']['who']
        @donation.anonymous = params['donation']['anonymous']
        @donation.email = params['donation']['email']
        @donation.reviewed = true
        @donation.save
      end
    else
      flash_error(:create_donation_not_allowed.l)
      redirect_to(:action => 'donate')
    end
  end
  
  def confirm
    @donation = Donation.new
    if request.method == :post
      amount = params['donation']['amount']
      if amount == "other"
        amount = params['donation']['other_amount']
      end
      @donation.amount = amount
      @donation.who = params['donation']['who']
      @donation.anonymous = params['donation']['anonymous']
      @donation.email = params['donation']['email']
      @donation.reviewed = false
      @donation.save
    end
  end
  
  def review_donations
    if is_in_admin_mode?
      if request.method == :post
        params[:reviewed].each { |x,y|
          d = Donation.find(x)
          d.reviewed = y
          d.save
        }
      end
      @donations = Donation.find(:all, :order => "created_at DESC")
      @reviewed = {}
      for d in @donations
        @reviewed[d.id] = d.reviewed
      end
    else
      flash_error(:review_donations_not_allowed.l)
      redirect_to(:action => 'donate')
    end
  end
  
  def donors
    store_location
    @donor_list = Donation.get_donor_list
  end
  
  def letter
    store_location
  end
  
  def thanks
    @donation = Donation.new
    # Merge cookies and params to work around an issue with tests and cookies
    ['donation_amount', 'who', 'anon', 'email'].each {|arg| params[arg] = (cookies[arg] or params[arg])}
    @donation.amount = params['donation_amount']
    if @donation.amount.nil?
      flash_error(:thanks_no_amount.l)
      redirect_to(:controller => :observer, :action => 'ask_webmaster_question')
    end
    @donation.who = params['who']
    @donation.anonymous = (params['anon'] == 'true')
    @donation.email = params['email']
    @donation.reviewed = false
    @donation.user = @user
    @donation.save
    store_location
  end
end

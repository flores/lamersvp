require 'rubygems'
require 'redis'
require 'json'
require 'sinatra'
require 'sinatra/captcha'
require 'aws/ses'
require 'sanitize'

set :port, 5062

NEXT_EVENT = "A get together somewhere!"
WAITING_LIST = "waiting list"
RSVP_LIMIT = 95
CONTACT = "rsvp@someaddress"

REDIS = Redis.new

def rsvps_left()
  rsvps = REDIS.keys "#{NEXT_EVENT}*"
  RSVP_LIMIT - rsvps.length
end

def waitinglist_count()
  rsvps = REDIS.keys "#{WAITING_LIST}*"
  rsvps.length
end

def rsvp(redis_connection,user)
  REDIS.set "#{redis_connection}:#{user['email']}", user.to_json
end

def already_rsvpd(email)
  if (REDIS.exists "#{NEXT_EVENT}:#{email}") || (REDIS.exists "#{WAITING_LIST}:#{email}")
    return true
  else
    return false
  end
end

def delete(redis_connection,email)
  REDIS.del("#{redis_connection}:#{email}")
end

def get_auth(email)
  object = JSON.parse(REDIS.get "#{NEXT_EVENT}:#{email}")
  object["cancel"]
end

def send_email(email,string)
  ses = AWS::SES::Base.new(
    :access_key_id  => 'id',
    :secret_access_key => 'key'
  )
  # stick the user info into the subject instead of headers
  ses.send_email(
    :to => email,
    :from => CONTACT,
    :subject => "Thanks for confirming for #{NEXT_EVENT}",
    :body => "Hi there.  You've confirmed one seat for #{NEXT_EVENT}.
    
If you have any questions, please feel free to reply to this email.

Should you need to cancel, please visit mysite.com/cancel/#{string}"
  )
end

def send_waitinglist_email(email,string)
  ses = AWS::SES::Base.new(
    :access_key_id  => 'id',
    :secret_access_key => 'key'
  )
  # stick the user info into the subject instead of headers
  ses.send_email(
    :to => email,
    :from => CONTACT,
    :subject => "Thanks for getting on our #{NEXT_EVENT} waiting list",
    :body => "Hi there.  You're now on our waiting list for #{NEXT_EVENT}.

We'll email you if a seat becomes available.

If you have any questions, please feel free to reply to this email."

  )
end


# jacked from http://vitobotta.com/sinatra-contact-form-jekyll/
def valid_email?(email)
  if email =~ /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/
    domain = email.match(/\@(.+)/)[1]
    Resolv::DNS.open do |dns|
      @mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
    end
    @mx.size > 0 ? true : false
  else
    false
  end
end
# /jacked

get '/rsvp' do
  @seats = rsvps_left
  if @seats > 0 
    erb :open
  else
    @seats = RSVP_LIMIT - @seats
    @waitinglist = waitinglist_count
    erb :waitinglist
  end
end

post '/rsvp' do
  @msg=''
  if captcha_pass?
    user = Hash.new
    params[:user].each do |k,v|
      user[k] = Sanitize.clean(v)
    end
    unless (user[:name])
      @msg = "Hey, friend.  Please enter your first and last name. We might have name tags."
      erb :msg
    end
    email = user["email"]
    user["cancel"] = rand(36**15).to_s(36)
    unless valid_email?(email)
      @msg = "your email looks fake.  are you a bot?"
      erb :msg
    end
    if !already_rsvpd(email)
      if rsvps_left > 0
	rsvp(NEXT_EVENT,user)
	send_email(email,user["cancel"])
	erb :confirmed
      else
	rsvp(WAITING_LIST,user)
	send_waitinglist_email(email,user["cancel"])
	erb :confirmed_waitinglist
      end
    else
      @msg = "you are already rsvp'd for this event"
      erb :msg
    end
  else
    @msg = "the captcha was wrong.  are you a bot?"
    erb :msg
  end
end

get '/cancel/:authstring' do |authstring|
  @seats = rsvps_left
  @authstring = authstring
  erb :confirm_cancel
end

post '/cancel/:authstring' do |authstring|
  email = params["email"]
  if already_rsvpd(email)
    if authstring == get_auth(email)
      delete(NEXT_EVENT,email)
      @msg = "You have canceled from our #{NEXT_EVENT} event"
    else
      @msg = "Sorry, I think this request is bogus.  Email us at #{CONTACT} to cancel"
    end
  else
    @msg = "Sorry, I do not know this email.  Email us at #{CONTACT} to cancel"
  end
  erb :msg
end

get '/rsvplist' do
  @rsvps = Hash.new
  list = REDIS.keys "#{NEXT_EVENT}*"
  list.each do |rsvp|
    @rsvps[rsvp] = JSON.parse(REDIS.get rsvp)
  end
  erb :list
end


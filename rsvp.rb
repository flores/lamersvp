require 'rubygems'
require 'redis'
require 'json'
require 'sinatra'
require 'sinatra/captcha'
require 'aws/ses'
require 'sanitize'

set :port, 5062

NEXT_EVENT = "A get together somewhere!"
RSVP_LIMIT = 95
CONTACT = "rsvp@someaddress"

REDIS = Redis.new

def rsvps_left()
  rsvps = REDIS.keys "#{NEXT_EVENT}*"
  RSVP_LIMIT - rsvps.length
end

def rsvp(user)
  REDIS.set "#{NEXT_EVENT}:#{user['email']}", user.to_json
end

def already_rsvpd(email)
  REDIS.exists "#{NEXT_EVENT}:#{email}"
end

def delete(email)
  REDIS.del("#{NEXT_EVENT}:#{email}")
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
    erb :closed
  end
end

post '/rsvp' do
  if rsvps_left > 0 
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
      if valid_email?(email)
	unless already_rsvpd(email)
	  rsvp(user)
	  send_email(email,user["cancel"])
	  erb :confirmed
	else
	  @msg = "you are already rsvp'd for this event"
	  erb :msg
	end
      else
	@msg = "your email looks fake.  are you a bot?"
	erb :msg
      end
    else
      @msg = "the captcha was wrong.  are you a bot?"
      erb :msg
    end
  else #someone is fucking with us
    erb :closed
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
      delete(email)
      @msg = "You have canceled from our #{NEXT_EVENT} event"
    else
      @msg = "Sorry, I think this request is bogus.  Email us at #{CONTACT} to cancel"
    end
  else
    @msg = "Sorry, I do not know this email.  Email us at #{CONTACT} to cancel"
  end
  erb :msg
end

#get '/rsvplist' do
#  @rsvplist = REDIS.keys "#{NEXT_EVENT}*"
#  erb :list
#end


require 'rubygems'
require 'redis'
require 'json'
require 'sinatra'
require 'sinatra/captcha'

set :port, 5061

REDIS = Redis.new
NEXT_EVENT = 20120329
RSVP_LIMIT = 10

def rsvps_left()
  rsvps = REDIS.keys "#{NEXT_EVENT}*"
  RSVP_LIMIT - rsvps.length
end

def already_rsvpd(email)
  REDIS.exists "#{NEXT_EVENT}:#{email}"
end

def delete(email)
  REDIS.del "#{NEXT_EVENT}:#{email}"
end

def get_auth(email)
  object = JSON.parse(REDIS.get "#{NEXT_EVENT}:#{email}")
  object["cancel"]
end

# placeholder for automated email confirmation
def send_email(email,string)
  ses = AWS::SES::Base.new(
    :access_key_id  => 'someid',
    :secret_access_key => 'somekey'
  )
  # stick the user info into the subject instead of headers
  ses.send_email(
    :to => email,
    :from => 'someemail',
    :subject => "Thanks for confirming for our #{NEXT_EVENT} event!"
    :body => body
  )
end

# jacked from http://vitobotta.com/sinatra-contact-form-jekyll/#captcha-verification
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
      user = params[:user]
      email = user["email"]
      user["cancel"] = rand(36**15).to_s(36)
      if valid_email?(email)
	unless already_rsvpd(email)
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

get '/rsvp/cancel/:email/:authstring' do |email,authstring|
  if already_rsvpd(email)
    if authstring == get_auth(email)
      @msg "You have canceled from our #{NEXT_EVENT} event"
    else
      @msg "Sorry, I think this request is bogus.  Email us to cancel"
    end
  else
    @msg "Sorry, I do not know this email."
  end
  erb :msg
end

get '/rsvplist' do
  @rsvp_list = REDIS.keys "#{NEXT_EVENT}*"
  erb :list
end


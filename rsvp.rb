require 'rubygems'
require 'redis'
require 'json'
require 'sinatra'
require 'sinatra/captcha'
require 'aws/ses'
require 'sanitize'
require 'haml'

set :port, 8000

REDIS = Redis.new
NEXT_EVENT = "thisistotallyatest"
# no limit at this event
RSVP_LIMIT = 0

def rsvps_left()
  rsvps = REDIS.keys "#{NEXT_EVENT}*"
#  RSVP_LIMIT - rsvps.length
  rsvps.length
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

# placeholder for automated email confirmation
def send_email(email,string)
  ses = AWS::SES::Base.new(
    :access_key_id  => 'SEKRETZ',
    :secret_access_key => 'KEYZ'
  )
  # stick the user info into the subject instead of headers
  ses.send_email(
    :to => email,
    :from => 'rsvp@js.la',
    :subject => "You've confirmed one seat for js.la on Thursday, April 26th, at 7pm",
    :body => "Hi.  We'll be sending more information later.

Should you need to cancel please visit http://js.la:8000/cancel/#{string}

If you have any questions please feel free to reply to this email.

See you there!

the js.la team
"
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
#  if @seats > 0 
    erb :open
#  else
#    erb :closed
#  end
end

post '/rsvp' do
#  if rsvps_left > 0 
    if captcha_pass? 
      user = Hash.new
      params[:user].each do |k,v|
        user[k] = Sanitize.clean(v)
      end
      email = user["email"]
      user["cancel"] = rand(36**15).to_s(36)
      if valid_email?(email)
      delete(email)
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
#  else #someone is fucking with us
#    erb :closed
#  end
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
      @msg = "You have canceled from our April 16th event"
    else
      @msg = "Sorry, I think this request is bogus.  Email us at rsvp@js.la to cancel"
    end
  else
    @msg = "Sorry, I do not know this email.  Email us at rsvp@js.la to cancel"
  end
  erb :msg
end

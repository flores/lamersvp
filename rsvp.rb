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
  rsvps = REDIS.scard NEXT_EVENT
  RSVP_LIMIT - rsvps
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
      if valid_email?(user["email"])
	REDIS.sadd NEXT_EVENT, user.to_json
	erb :confirmed
      else
	"your email looks fake.  are you a bot?"
      end
    else
      "the captcha was wrong.  are you a bot?"
    end
  else #someone is fucking with us
    erb :closed
  end
end

get '/rsvplist' do
  @rsvp_list = REDIS.sort NEXT_EVENT
  erb :list
end


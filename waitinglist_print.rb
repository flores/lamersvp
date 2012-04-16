require 'rubygems'
require 'redis'
require 'json'

REDIS = Redis.new
NEXT_EVENT = 20120329

@rsvps = Hash.new
list = REDIS.keys "#{NEXT_EVENT}-Waitinglist*"
list.each do |rsvp|
  @rsvps[rsvp] = JSON.parse(REDIS.get rsvp)
  puts "#{@rsvps[rsvp]['time']}\t#{@rsvps[rsvp]['name']}\t#{@rsvps[rsvp]['email']}\t#{@rsvps[rsvp]['org']}\n"
end

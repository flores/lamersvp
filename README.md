#LAMERsvp

Sometimes we have a [meetup](http://js.la) or party, and all we want is to give our people an easy way to RSVP and cancel.

Software and services I've found are just way too complicated, but this isn't:

- Allows a limit on seats to an event
- Once that limit is reached, switches over to a waiting list
- Emails confirming the RSVP (with a unique cancellation link) or a spot on the waiting list
- Uses Sinatra for the UI, Redis for the data store, and AWS-SES for emailing



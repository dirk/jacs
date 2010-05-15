require 'active_support'
require 'xmpp4r-simple'

# Little utility to make me less insane.
class Array
  def second
    self[1]
  end
end

require File.dirname(__FILE__) + '/activejabber'
require File.dirname(__FILE__) + '/actionjabber'
require 'rubygems'
require 'twitter_oauth'
require 'lib/user'
require 'kconv'
require 'dm-core'

class Batch
  def initialize config
    @@config = config
  end

  def execute
    users = User.all
    users.each {|user|
      @client = TwitterOAuth::Client.new(
        :consumer_key => @@config['consumer_key'],
        :consumer_secret => @@config['consumer_secret'],
        :token => user.twitter_token,
        :secret => user.twitter_secret
      )

      @client.user.each { |status|
        p status['text']
      }
#      p user
    }

    return true
  end
end
require 'rubygems'
require 'dm-core'
require 'dm-timestamps'

class User
    include DataMapper::Resource

    property :user_id, Serial
    property :twitter_token, String, :length => 500
    property :twitter_secret, String, :length => 500
    property :mixi_email, String, :length => 500
    property :mixi_password, String, :length => 500
    property :hatena_id, String, :length => 500
    property :hatena_haiku_password, String, :length => 500
    property :wasser_id, String, :length => 500
    property :wasser_password, String, :length => 500
    property :gcal_feed_url, String, :length => 500
    property :gcal_mail, String, :length => 500
    property :gcal_password, String, :length => 500
    property :echo_twitter_url, String, :length => 1
    property :twitter_url, String, :length => 30
    property :last_tweeted_at, DateTime, :default => DateTime.now
    property :created_at, DateTime
    property :updated_at, DateTime
end
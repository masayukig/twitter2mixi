require 'rubygems'
require 'dm-core'
require 'dm-timestamps'

class User
    include DataMapper::Resource

    property :user_id, Integer, :serial => true
    property :twitter_token, String, :size => 500
    property :twitter_secret, String, :size => 500
    property :mixi_email, String, :size => 500
    property :mixi_password, String, :size => 500
    property :last_tweeted_at, DateTime
    property :created_at, DateTime
    property :updated_at, DateTime
end
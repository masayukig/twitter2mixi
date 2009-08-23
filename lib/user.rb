require 'dm-core'

class User
    include DataMapper::Resource

    property :user_id, Integer, :serial => true
    property :twitter_token, String, :size => 500
    property :twitter_secret, String, :size => 500
    property :mixi_email, String, :size => 500
    property :mixi_password, String, :size => 500
    property :last_status, String, :size => 500
    property :create_datetime,	DateTime, :default => Proc.new{ Time.now }
    property :lastlogin_datetime,	DateTime, :default => Proc.new { Time.now }
end
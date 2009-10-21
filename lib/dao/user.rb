require "date"
require 'rubygems'
require 'dm-core'
require 'dm-timestamps'

class User
    include DataMapper::Resource
    has n, :webservices

    property :id, Integer, :serial => true
    property :active_flg, Boolean, :default => true

    property :twitter_token, String, :length => 500
    property :twitter_secret, String, :length => 500

    property :twitter_id, Integer                               # ID
    property :twitter_name, String, :length => 500                # 名前
    property :twitter_screen_name, String, :length => 500         # スクリーン名
    property :twitter_location, String, :length => 500            # 居住地
    property :twitter_description, String, :length => 500         # 自己紹介
    property :twitter_profile_image_url, String, :length => 500   # アイコンURL
    property :twitter_url, String, :length => 500                 # ユーザ自身のURL

    property :last_tweeted_at, DateTime, :default => DateTime.now
    property :created_at, DateTime
    property :updated_at, DateTime

end

class Webservice
    include DataMapper::Resource
    belongs_to :user
    has n, :statuses

    property :id, Integer, :serial => true
    property :name, String, :length => 500

    property :active_flg, Boolean, :default => false

    property :account, String, :length => 500
    property :password, String, :length => 500
    property :extend, String, :length => 500
    property :login_error_datetime, DateTime
    property :login_success_datetime, DateTime

    property :created_at, DateTime
    property :updated_at, DateTime

end

class Status
    include DataMapper::Resource
    belongs_to :webservice

    property :id, Integer, :serial => true
    property :status, String, :length => 500
    property :created_at, DateTime
    property :updated_at, DateTime

end

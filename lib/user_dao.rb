require 'rubygems'
require 'dm-core'
require 'lib/user'
require 'net/http'
require 'uri'
require 'json'

class UserDao
  attr_reader :login_flg
  attr_accessor :User

  def initialize config
    @config = config
    return false if @config == nil

    # アカウント情報の初期化
    logout

    # DB初期化
    #    DataMapper.setup(:default, "sqlite3::memory:")
    DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db/t2m_#{@config['env']}.db")
    #DataObjects::Sqlite3.logger = DataObjects::Logger.new("log/datamapper_#{@config['env']}.log", 0)
    DataMapper.auto_upgrade!
  end

  def db_init
    DataMapper.auto_migrate!
  end

  # [token]
  #   Twitterのアクセストークン
  # [secret]
  #   Twitterのシークレットトークン
  # [返り値]
  #   整数: 会員番号(user_id)
  #   false: 異常終了(TODO 未実装)
  #
  # 既に会員になっていたらLogin状態で正常終了する
  def login token, secret
    user = User.first(:twitter_token => token, :twitter_secret => secret)
    return false if user == nil
    user_id = user.user_id

    # 会員情報を保存
    @twitter_token = token
    @twitter_secret = secret
    @login_flg = true
    return user_id
  end

  # ログアウト処理
  def logout
    # ユーザアカウント情報の初期化
    @login_flg = false
    @twitter_token = nil
    @twitter_secret = nil
  end

  # [token]
  #   Twitterのアクセストークン
  # [secret]
  #   Twitterのシークレットトークン
  # [返り値]
  #   整数: 会員番号(user_id)
  #   false: 異常終了(TODO 未実装)
  #
  # 既に会員になっていたらLogin状態で正常終了する
  def twitter_regist token, secret
    # 既にログイン済みであればエラー
    return false if @login_status
    # 既に会員登録されていればログイン処理を行い終了
    if User.first(:twitter_token => token, :twitter_secret => secret)
      return login token, secret
    end

    # 新規会員
    user = User.new
    user.attributes = {:twitter_token => token, :twitter_secret => secret}
    user.save
    @login_flg = true
    @twitter_token = token
    @twitter_secret = secret
    return user.user_id
  end

  # [email]
  #   MixiのEメール
  # [password]
  #   Mixiのパスワード
  # [返り値]
  #   true: 正常終了
  #   false: ログイン状態でないと異常終了
  #
  # ログインしている状態で、Mixi会員情報を追加登録する
  def mixi_regist email, password
    # ログイン状態でなければ異常終了
    return false if @login_flg == false

    # 既に同じ情報で登録済みだったら正常終了
    user = User.first(:twitter_token => @twitter_token, :twitter_secret => @twitter_secret, :mixi_email => email, :mixi_password => password)
    return true if user != nil

    # 過去に既に同じMixiアカウントで登録があったら過去のアカウント情報を削除する
    user = User.first(:mixi_email => email, :mixi_password => password)
    user.destroy if user != nil

    # ツイッターアカウントの登録があるか確認
    user = User.first(:twitter_token => @twitter_token, :twitter_secret => @twitter_secret)
    return false if user == nil

    # Mixiアカウント情報の保持
    user.attributes = {:mixi_email => email, :mixi_password => password}
    user.save
    return true
  end

  # [返り値]
  #   true: 正常終了
  #   false: ログイン状態でないと異常終了
  #
  # ログインしている状態で、twitter, Mixi会員情報を削除する
  def unregist
    # ログイン状態でなければ異常終了
    return false if @login_flg == false

    # アカウント情報を削除する
    user = User.first(:twitter_token => @twitter_token, :twitter_secret => @twitter_secret)
    user.destroy if user != nil
  end

  def last_status= last_status
    # ログイン状態でなければ異常終了
    return false if @login_flg == false

    user = User.first(:twitter_token => @twitter_token, :twitter_secret => @twitter_secret)
    return false if user == nil

    user.attributes = {:last_status => last_status}
    user.save
    return true
  end

  def last_status
    # ログイン状態でなければ異常終了
    return nil if @login_flg == false
    user = User.first(:twitter_token => @twitter_token, :twitter_secret => @twitter_secret)
    return nil if user == nil
    return user.last_status
  end

  # [screen_name]
  #   MixiのEメールtwitterのscreen name
  # [返り値]
  #   true: 正常終了
  #   false: 異常終了
  #
  # loginメソッドでログイン後に、
  # twitterのscreen nameを使用し、ユーザのtwitterページURLを生成。
  # 短いURLにして、DBへ保持。(短いURLはbit.lyのサービスを利用)
  def make_short_twitter_url screen_name
    # ログイン状態でなければ異常終了
    return false if @login_flg == false

    user = User.first(:twitter_token => @twitter_token, :twitter_secret => @twitter_secret)
    return false if user == nil

    # Twitterへの短いリンク生成
    url = "http://api.bit.ly/shorten?version=2.0.1&longUrl=http://twitter.com/#{screen_name}&login=#{@config['bitly_login_id']}&apiKey=#{@config['bitly_api_key']}"
    uri = URI.parse(url)
    # TODO エラー処理実装
    Net::HTTP.start(uri.host, uri.port) do |http|
      puts "http:#{http}"
      request = Net::HTTP::Get.new(uri.request_uri)
      http.request(request) do |response|
        #raise 'Response is not chuncked' unless response.chunked?
        response.read_body do |body|
          # 空行は無視する = JSON形式でのパースに失敗したら次へ
          bitly_response = JSON.parse(body) rescue next
          # 削除通知など、'text'パラメータを含まないものは無視して次へ
          next unless bitly_response['results']
          twitter_url = bitly_response['results']["http://twitter.com/#{screen_name}"]['shortUrl']
          user.attributes = {:twitter_url => twitter_url}
          user.save
          puts "user.twitter_url:#{user.twitter_url}"
        end
      end
    end
  end

  def get_all_count
    return User.all.count
  end
end


require 'rubygems'
require 'dm-core'
require 'user'

class UserDao
  attr_reader :login_flg

  def initialize config
    @config = config
    return false if @config == nil

    # アカウント情報の初期化
    logout

    # DB初期化
#    DataMapper.setup(:default, "sqlite3::memory:")
    DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db/t2m.sqlite3")
    DataObjects::Sqlite3.logger = DataObjects::Logger.new('log/datamapper.log', 0)
    DataMapper.auto_upgrade!
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
    user_id = User.first(:twitter_token => token, :twitter_secret => secret).user_id
    return false if user_id == nil

    # 会員情報を保存
    @twitter_token = token
    @twitter_secret = secret
    @login_flg = true
    return user_id
  end

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

    user = User.first(:twitter_token => @twitter_token, :twitter_secret => @twitter_secret)
    return false if user == nil

    user.attributes = {:mixi_email => email, :mixi_password => password}
    user.save
    return true
  end


end

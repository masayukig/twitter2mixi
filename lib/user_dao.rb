require 'sqlite3'

class UserDao
  attr_reader :login_flg

  def initialize config
    @config = config
    # アカウント情報の初期化
    logout
  end

  def init_db
    return false if @config == nil

    # テーブル新規作成
    sql = <<EOD
drop table IF EXISTS users;
create table users (
    user_id INT
  , twitter_token VARCHAR
  , twitter_secret VARCHAR
  , mixi_email VARCHAR
  , mixi_password VARCHAR
	, create_datetime	DATETIME
	, lastlogin_datetime	DATETIME
);
EOD

    @db = SQLite3::Database.new(@config['dbpath'])
    @db.execute_batch(sql)
    
    # TODO DBに正しく書き込めたか判断してT/Fを返す
    return true
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
    user_id = user_exist? token
    return false if user_id == nil

    # 会員情報を保存
    @twiter_token = token
    @twiter_secret = secret
    @login_flg = true
    return user_id
  end

  def logout
    # ユーザアカウント情報の初期化
    @login_flg = false
    @twiter_token = nil
    @twiter_secret = nil
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
    if user_exist? token
      return login token, secret
    end

    # 新規会員
    user_id = get_max_user_id + 1
    sql =
      "INSERT INTO users (user_id, twitter_token, twitter_secret, create_datetime, lastlogin_datetime)
       VALUES (#{user_id}, '#{token}', '#{secret}', datetime('now', 'localtime'), datetime('now', 'localtime'));"
    @db.execute(sql)
    @login_flg = true
    @twiter_token = token
    @twiter_secret = secret

    user_id = @db.execute('select last_insert_rowid() as user_id')[0][0].to_i
    # TODO DBに正しく書き込めたか判断してT/Fを返す
    return user_id
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



  end

  # [token]
  #   Twitterのアクセストークン
  # [secret]
  #   Twitterのシークレットトークン
  #
  # ユーザーが既に登録されているか確認
  def user_exist? token
    sql = "select user_id from users where twitter_token='#{token}';"
    result = @db.execute(sql)
    return false if result[0] == nil
    return false if result[0][0] == nil
    return result[0][0].to_i
  end

  def get_max_user_id
    sql = "select max(user_id) as max from users;"
    max = @db.execute(sql)
    return max[0][0].to_i
  end


end

require 'rubygems'
require 'twitter_oauth'
require 'kconv'
require 'lib/mixi_client'
require 'dm-core'
require 'lib/user'
require 'time'
require 'lib/user_dao'

class Batch
  def initialize config
    @@config = config

    # DB初期化
    #    DataMapper.setup(:default, "sqlite3::memory:")
    DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db/t2m_#{@@config['env']}.db")
    DataObjects::Sqlite3.logger = DataObjects::Logger.new("log/datamapper_#{@@config['env']}.log", 0)
    DataMapper.auto_upgrade!
    
    @debug_flg = true
  end

  # [返り値]
  #   Twitter2Mixiしたツブヤキの合計数
  #
  def execute
    count = 0
    users = User.all
    users.each {|user|
      next if user == nil
      next if user.twitter_token == nil || user.twitter_secret == nil
      next if user.mixi_email == nil    || user.mixi_password == nil

      puts "Start: #{Time.new} mixi_account=#{user.mixi_email}" if @debug_flg

      # ショートURLの生成
      # twitter_urlがあるか？をチェック
#      puts "user.twitter_url:#{user.twitter_url}" if @debug_flg
#      if user.twitter_url == nil || user.twitter_url == ''
#        # user_dao初期化
#        user_dao = UserDao.new @@config
#        # 一度ログインし、Twitter向けのアドレス生成
#        user_dao.login user.twitter_token, user.twitter_secret
#        user_dao.make_short_twitter_url screen_name
#      end
#
      # Twitterクライント準備
      client = TwitterOAuth::Client.new(
          :consumer_key => @@config['consumer_key'],
          :consumer_secret => @@config['consumer_secret'],
          :token => user.twitter_token,
          :secret => user.twitter_secret
      )
      timeline = Array.new
      # 最新のつぶやき時間を取得
      created_at = Time.parse(client.user[0]['created_at']) 
      # screen_nameの取得
      screen_name = client.user[0]['user']['screen_name']

      # ────────────────────
      # 一番初めの同期作業
      # ────────────────────
      if user.last_tweeted_at == nil
        puts "一番初めの同期作業".tosjis if @debug_flg

        # 最終ステータスをDBに保存
        # 最新のつぶやき時間をDBに保持
        user.last_tweeted_at = created_at 
        user.save
        next
      end

      # ────────────────────
      # 一番初め以外の同期作業
      # ────────────────────

      # 最新のTwitterつぶやき時間 < DB上の最新Twitterつぶやき時間ならば、何もしない
      # (Twitter上の最新つぶやきをユーザが手動削除に対応)
      if created_at < user.last_tweeted_at.to_time
        puts "ユーザがつぶやきを削除?(created_at: #{created_at} , last_tweeted_at: #{user.last_tweeted_at} ".tosjis if @debug_flg
        next
      end

      # Twitterステータス20件取得
      begin
        client.user.each { |status|
          if "#{status.class}" == 'Hash'
              # 既にmixi echo済みだったらBreak
              break if Time.parse(status['created_at']) <= user.last_tweeted_at.to_time
              timeline << replace(status['text'])
          else
              puts "status.class is #{status.class}" if @debug_flg
          end
        }
      rescue
        p $!
        next
      end

      # timeline チェック。echo対象つぶやきが無ければ、次のユーザ処理
      if timeline.empty?
        next
      end

      # Mixiへログインする
      mixiclient = MixiClient.new
#      mixiclient.dontsubmit if @debug_flg
      mixiclient.login(user.mixi_email, user.mixi_password)
      # TODO falseが帰ってきた時の処理

      # エコー書き出し
      echos = mixiclient.write_echos(timeline)
      count += echos if echos != nil
      # Mixiからログアウトを行う
      mixiclient.logout

      # 最終ステータスをDBに保存
      if count != 0  # mixi echoしたときのみ、DB更新
        user.last_tweeted_at = created_at
        user.save
      end
    }

    return count
  end

  # Twitterの文字列を置換
  def replace text
    # TODO 他の特殊文字でどのようになるか調査、機種依存文字、TAB、<>タグなど
    text = text.gsub(/\r\n|\r|\n/, ' ')
    text = text.chomp
  end
end

puts 'start twiter2mixi batch'

# コンフィグ情報読込
config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../config.yml')

# バッチ処理実行
batch = Batch.new config
count = batch.execute

# 終了メッセージ
puts "twitter2mixi: #{count}"
puts 'finish!'

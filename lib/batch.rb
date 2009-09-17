# -*- coding: utf-8 -*-
require 'rubygems'
require 'twitter_oauth'
require 'kconv'
require 'lib/mixi_client'
require 'lib/hatena_client'
require 'lib/wasser_client'
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

      # Twitterクライント準備
      client = TwitterOAuth::Client.new(
          :consumer_key => @@config['consumer_key'],
          :consumer_secret => @@config['consumer_secret'],
          :token => user.twitter_token,
          :secret => user.twitter_secret
      )
      # Twitterステータス20件取得
      timeline = Array.new
      created_at = Time.parse(client.user[0]['created_at']) # 最新のつぶやき時間を取得
      screen_name = client.user[0]['user']['screen_name'] # get screen_name
      client.user.each { |status|
        if "#{status.class}" == 'Hash'
          status_created_at = Time.parse(status['created_at'])
          break if user.last_tweeted_at != nil && status_created_at <= user.last_tweeted_at.to_time # 既にmixi echo済み
          text = status['text']
          text = replace(text)
          text = delete_reply(text)
          if (text != nil && text != '')
            timeline << text
          end
        else
          puts "status.class is #{status.class}" if @debug_flg
        end
      }

      puts "user.twitter_url:#{user.twitter_url}"
      # ユーザがtwitter_urlのechoを希望している、かつ、twitter_urlがあるか？をチェック
      if user.echo_twitter_url == '1' && (user.twitter_url == nil || user.twitter_url == '')
         # user_dao初期化
        @user_dao = UserDao.new @@config
        @user_dao.save_short_users_url(screen_name, user.twitter_token, user.twitter_secret)
      end
      if user.echo_twitter_url != '1'
        # ユーザがtwitter_urlのechoを希望していなければ、twitter_urlをクリア
        user.twitter_url = ''
      end

      # timeline チェック。echo対象つぶやきが無ければ、次のユーザ処理
      if timeline.empty?
        next
      end
      # 一番初めの同期作業
      if user.last_tweeted_at == nil
        puts "一番初めの同期作業".tosjis if @debug_flg

        # 最終ステータスをDBに保存
        user.last_tweeted_at = created_at # 最新のつぶやき時間をDBに保持
        user.save
        next
      end

      # 最新のTwitterつぶやき時間 < DB上の最新Twitterつぶやき時間
      # ならば、何もしない
      # (Twitter上の最新つぶやきをユーザが手動削除にも対応できる)
      if created_at < user.last_tweeted_at.to_time
        puts "ユーザがつぶやきを削除?(created_at: #{created_at} , last_tweeted_at: #{user.last_tweeted_at} ".tosjis if @debug_flg

        next
      end

      # Mixiへログインする
      mixiclient = MixiClient.new
#      mixiclient.dontsubmit if @debug_flg
      mixiclient.login(user.mixi_email, user.mixi_password)
      # TODO falseが帰ってきた時の処理

      # エコー書き出し
      echos = mixiclient.write_echos(timeline, user.twitter_url)
      
      count += echos if echos != nil
      # Mixiからログアウトを行う
      #mixiclient.logout

      # wasser書き出し処理
      # FIXME:暫定
      wasserclient = WasserClient.new
      is_success = wasserclient.login_wasser(user.wasser_id, user.wasser_password)
      puts "is_success:#{is_success}"
      # wasser 書き出し
      wasserclient.write_wassers(timeline, user.twitter_url)
      # Hatena haiku書き出し処理
      if user.hatena_id != nil && user.hatena_id != ''
        # hatena haikuへログイン
        hatenaclient = HatenaClient.new
        is_success = hatenaclient.login_haiku(user.hatena_id, user.hatena_haiku_password)
        # haiku書き出し
        hatenaclient.write_haikus(timeline, user.twitter_url)
      end

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

  # @で始まる文字列を削除
  # twitterの返信は他のサービスに転送したくない人のための機能
  def delete_reply_status text
    text = text.gsub(/^@.*/, '')
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

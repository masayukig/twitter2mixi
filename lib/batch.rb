# -*- coding: utf-8 -*-
require 'rubygems'
require 'twitter_oauth'
require 'kconv'
require 'lib/mixi_client'
require 'lib/hatena_client'
require 'lib/wasser_client'
require 'lib/gcal_client'
require 'dm-core'
require 'lib/user'
require 'time'
require 'lib/user_dao'
require 'lib/timeline'
require 'thread'

class Batch
  def initialize config
    @config = config
    @debug_flg = true
  end

  # [返り値]
  #   Twitter2Mixiしたツブヤキの合計数
  #
  def execute user_q, no = ''
    count = 0
    while true
      user = user_q.pop
      if user == nil
        puts "[#{no}]Finish: count=#{count}" 
        return count
      end
      
      next if user.twitter_token == nil || user.twitter_secret == nil
      next if user.mixi_email == nil    || user.mixi_password == nil

      puts "[#{no}]Start: #{Time.now.strftime("%Y-%m-%d %H:%M:%S")} mixi_account=#{user.mixi_email}" if @debug_flg

      # ショートURLの生成
      # twitter_urlがあるか？をチェック
#      puts "[#{no}]user.twitter_url:#{user.twitter_url}" if @debug_flg
#      if user.twitter_url == nil || user.twitter_url == ''
        # user_dao初期化
#        user_dao = UserDao.new @config
        # 一度ログインし、Twitter向けのアドレス生成
#        user_dao.login user.twitter_token, user.twitter_secret
#        user_dao.make_short_twitter_url screen_name
#      end

      # Twitterクライント準備
      client = TwitterOAuth::Client.new(
          :consumer_key => @config['consumer_key'],
          :consumer_secret => @config['consumer_secret'],
          :token => user.twitter_token,
          :secret => user.twitter_secret
      )
      next if client == nil
      next if client.user == nil
      next if client.user[0] == nil
      next if client.user[0]['created_at'] == nil
      next if client.user[0]['user'] == nil

      timeline = Array.new
      timelines = Array.new # TODO timelineクラスを作成し、それで管理？？
      # 最新のつぶやき時間を取得
      created_at = Time.parse(client.user[0]['created_at'])
      # screen_nameの取得
      screen_name = client.user[0]['user']['screen_name']

      # ────────────────────
      # 一番初めの同期作業
      # ────────────────────
      if user.last_tweeted_at == nil
        puts "[#{no}]一番初めの同期作業".tosjis if @debug_flg

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
        puts "[#{no}]ユーザがつぶやきを削除?(created_at: #{created_at} , last_tweeted_at: #{user.last_tweeted_at} ".tosjis if @debug_flg
        next
      end

      # Twitterステータス20件取得
      begin
        client.user.each { |status|
          if "#{status.class}" == 'Hash'
            status_created_at = Time.parse(status['created_at'])
            break if user.last_tweeted_at != nil && status_created_at <= user.last_tweeted_at.to_time # 既にmixi echo済み
            text = status['text']
            text = replace(text)
            text = delete_reply_status(text)
            if (text != nil && text != '')
              timeline << text
              # TODO 現在、gcal_clientしか使用していないが、他clientもtimelinesを使用するようにする
              timeline_tmp = Timeline.new
              timeline_tmp.text = text
              timeline_tmp.created_at = created_at
              timelines << timeline_tmp
            end
          else
            puts "[#{no}]status.class is #{status.class}" if @debug_flg
          end
        }
      rescue
        p $!
        next
      end
      # timeline チェック。echo対象つぶやきが無ければ、次のユーザ処理
      if timeline.empty?
        puts "[#{no}]つぶやき対象無し".tosjis if @debug_flg
        next
      end

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

      # Mixiへログインする
      mixiclient = MixiClient.new
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

      # Gcal書き出し
      gcalclient = GcalClient.new
      is_success = gcalclient.login(user.gcal_mail, user.gcal_password, user.gcal_feed_url)
      gcalclient.write_messages(timelines, user.twitter_url)

      # 最終ステータスをDBに保存
      if count != 0  # mixi echoしたときのみ、DB更新
        user.last_tweeted_at = created_at
        user.save
      end
    end

    # ここに処理は来ない
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

  def main max_thread
    user_q = Queue.new

    User.all.each { |user|
      next if user == nil
      next if user.twitter_token == nil || user.twitter_secret == nil
      next if user.mixi_email == nil    || user.mixi_password == nil
      user_q.push(user)
    }
    for i in 1..max_thread
      user_q.push(nil)
    end
    count = 0
    threads = []
    for no in 1..max_thread
      threads.push(Thread.new {
        count += execute user_q, no
      })
#      puts "start up no.#{no} thread."
    end
    threads.each {|t| p t.join.value}

    return count
  end
end


# コンフィグ情報読込
config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../config.yml')

# DB初期化
#    DataMapper.setup(:default, "sqlite3::memory:")
DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db/t2m_#{config['env']}.db")
#DataObjects::Sqlite3.logger = DataObjects::Logger.new("log/datamapper_#{config['env']}.log", 0)
DataMapper.auto_upgrade!

puts "Start twiter2mixi batch at #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"
puts "max_thread_number = #{config['max_thread_number']}"

# バッチ処理実行
batch = Batch.new config
count = batch.main config['max_thread_number']

# 終了メッセージ
puts "twitter2mixi: #{count}"
puts "Finish! at #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"

# -*- coding: utf-8 -*-
require 'rubygems'
require 'twitter_oauth'
require 'kconv'
require 'lib/client/mixi_client'
require 'lib/client/gcal_client'
require 'dm-core'
require 'time'
require 'lib/dao/user'
require 'lib/dao/user_dao'
require 'yaml'
require 'thread'

class Batch
  attr_accessor :user_count #処理したユーザ数

  def initialize config
    @user_count = 0
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
      puts "[#{no}]Start:(Userid=#{user.id}) #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}" if @debug_flg

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

      # envが'test'なら、更新しない。
      # next if @config['env'] == 'test'
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

      # 最新のつぶやき時間を取得
      created_at = Time.parse(client.user[0]['created_at']) 

      # 会員情報の更新
      user.twitter_id                 = client.user[0]['user']['id']
      user.twitter_name               = client.user[0]['user']['name']
      user.twitter_screen_name        = client.user[0]['user']['screen_name']
      user.twitter_location           = client.user[0]['user']['location']
      user.twitter_description        = client.user[0]['user']['description']
      user.twitter_profile_image_url  = client.user[0]['user']['profile_image_url']
      user.twitter_url                = client.user[0]['user']['url']
      user.save

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
              # 既にmixi echo済みだったらBreak
              break if Time.parse(status['created_at']) <= user.last_tweeted_at.to_time
              text = status['text']
              text = replace(text)
              timeline << text if (text != nil && text != '')
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

      # ──────────
      # Mixi書き出し
      # ──────────
      # Webサービス アカウントの取得
      webservice = Webservice.first(:user_id => user.id, :name => 'mixi')
      # ログインする
      client = MixiClient.new
      client.login(webservice.account, webservice.password)
      extend_ary = YAML.load("#{webservice.extend}")
      # 「@」が入っていればすべて除外
      timeline.delete_if {|x| /^.*@.*/ =~ x} if extend_ary != nil && extend_ary.index('inner_at_not_sync') != nil
      # 先頭が「@」から始まっていれば除外
      timeline.delete_if {|x| /^@.*/ =~ x} if extend_ary != nil && extend_ary.index('first_at_not_sync') != nil
      # エコー書き出し
      i = client.post_statuses(timeline)
      count += i if i != nil

      # ──────────
      # Gcal書き出し
      # ──────────
      # Webサービス アカウントの取得
#      webservice = Webservice.first(:user_id => user.id, :name => 'gcal')
#      extend = webservice.extend
#      if extend != nil
#        extend_ary = YAML.load(extend)
#        gcal_feed_url = extend_ary['gcal_feed_url']
#        if gcal_feed_url != nil
#          # ログインする
#          client = GcalClient.new
#          is_success = client.login(webservice.account, webservice.password)
#          is_success = client.set_feed_url(gcal_feed_url)
#          client.post_statuses(timeline)
#        end
#      end

      # ──────────
      # 終了処理
      # ──────────
      # 最終ステータスをDBに保存
      if i != 0  # mixi echoしたときのみ、DB更新
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

    # 最初にスレッドを作成し、随時処理していく
    count = 0
    threads = []
    for no in 1..max_thread
      threads.push(Thread.new {
        count += execute user_q, no
      })
      puts "start up no.#{no} thread."
    end

    User.all.each { |user|
      next if user == nil
      next if user.twitter_token == nil || user.twitter_secret == nil
      next if user.twitter_token == '' || user.twitter_secret == ''
      next if user.active_flg == false

      webservice = Webservice.first(:user_id => user.id, :name => 'mixi')
      next if webservice == nil
      next if webservice.account == nil || webservice.password == nil || webservice.active_flg == false
      next if webservice.account == '' || webservice.password == ''

#      p user
#      p webservice
#      p YAML.load(webservice.extend)

      user_q.push(user)
    }
    for i in 1..max_thread
      user_q.push(nil)
    end

    threads.each {|t| p t.join(@config['thread_timeout']).value}

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

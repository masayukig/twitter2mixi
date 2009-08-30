require 'rubygems'
require 'twitter_oauth'
require 'kconv'
require 'lib/mixi_client'
require 'dm-core'
require 'lib/user'
require 'time'

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
      client.user.each { |status|
        if "#{status.class}" == 'Hash'
            status_created_at = Time.parse(status['created_at'])
            break if user.last_tweeted_at != nil && status_created_at <= user.last_tweeted_at.to_time # 既にmixi echo済み
            text = status['text']
            timeline << replace(text)
        else
            puts "status.class is #{status.class}" if @debug_flg
        end
      }
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

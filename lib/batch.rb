require 'rubygems'
require 'twitter_oauth'
require 'kconv'
require 'lib/mixi_client'
require 'dm-core'
require 'lib/user'

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
      client.user.each { |status|
        if "#{status.class}" == 'Hash'
            text = status['text']
            timeline << replace(text)
        else
            puts "status.class is #{status.class}" if @debug_flg
        end
      }

      # 一番初めの同期作業
      if user.last_status == nil
        puts "一番初めの同期作業".tosjis if @debug_flg

        # 最終ステータスをDBに保存
        user.last_status = timeline[0]
        user.save
        next
      end

      # 最新のTwitterつぶやきメッセージと最終Mixiエコーが、
      # 同じであれば何もしない
      if user.last_status == timeline[0]
        puts "変化無し".tosjis if @debug_flg
        next
      end

      # 最新Twitter20件の中に、最終Mixiエコーが無ければ、最終Mixiエコーを更新のみで終了
      # Twitter上の最新つぶやきをユーザが手動削除の可能性有り
      if timeline.index(user.last_status) == nil
        puts "同期失敗!(最新口コミ削除された可能性有り)".tosjis if @debug_flg

        # 最終ステータスをDBに保存
        user.last_status = timeline[0]
        user.save
        next
      end

      # Mixiへログインする
      mixiclient = MixiClient.new
#      mixiclient.dontsubmit if @debug_flg
      mixiclient.login(user.mixi_email, user.mixi_password)
      # TODO falseが帰ってきた時の処理

      # エコー書き出し
      echos = mixiclient.write_echos(timeline, user.last_status)
      count += echos if echos != nil
      # Mixiからログアウトを行う
      mixiclient.logout

      # 最終ステータスをDBに保存
      user.last_status = timeline[0]
      user.save

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

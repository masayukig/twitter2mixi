require 'rubygems'
require 'twitter_oauth'
require 'kconv'
require 'lib/mixi_client'
require 'dm-core'
require 'lib/user'

class Batch
  def initialize config
    @@config = config
    @mixiclient = MixiClient.new

    # DB初期化
    #    DataMapper.setup(:default, "sqlite3::memory:")
    DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db/t2m_#{@@config['env']}.db")
    DataObjects::Sqlite3.logger = DataObjects::Logger.new("log/datamapper_#{@@config['env']}.log", 0)
    DataMapper.auto_upgrade!
  end

  # [返り値]
  #   Twitter2Mixiしたツブヤキの合計数
  #
  def execute
    count = 0
    users = User.all
    users.each {|user|
      @client = TwitterOAuth::Client.new(
        :consumer_key => @@config['consumer_key'],
        :consumer_secret => @@config['consumer_secret'],
        :token => user.twitter_token,
        :secret => user.twitter_secret
      )

timeline = Array.new
      @client.user.each { |status|
timeline << replace(status['text'])
      }

      # Mixiへログインする
      @mixiclient.login(user.mixi_email, user.mixi_password)
      # TODO falseが帰ってきた時の処理

      # エコー書き出し
      echos = @mixiclient.write_echos(timeline, user.last_status)
      count += echos if echos != nil

      # Mixiからログアウトを行う
      @mixiclient.logout

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

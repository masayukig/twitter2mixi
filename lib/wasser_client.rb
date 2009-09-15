require 'rubygems'
gem "mechanize", "0.8.5" 
require 'mechanize'
require 'kconv'
require 'logger'

# 環境準備
# gem install mechanize --version "= 0.8.5"

class WasserClient
  def initialize
    # Mechanizeの初期化
    @agent = WWW::Mechanize.new
    @login_flg = false
    @dontsubmit_flg = false

    # ログ出力
    WWW::Mechanize.log = Logger.new(File.expand_path(File.dirname(__FILE__)) + '/../log/mechanize_wasser.log')
    WWW::Mechanize.log.level = Logger::INFO

  end

  # [id]
  #   Wasser id
  # [password]
  #   Wasser パスワード
  #
  # Wasserへ ログイン
  # 成功したらTrueを返します。失敗したらFalseを返します。
  def login_wasser id, password
    WWW::Mechanize.log.info("wasser login by #{id}")

    is_success = false
    result = ''
    begin
      result = @agent.auth(id, password)
      is_success = true
    rescue
      WWW::Mechanize.log.warn("wasser login failed. #{$!}")
      @login_flg = false
      is_success = false
    end
    WWW::Mechanize.log.info("wasser login result:#{is_success}:#{result}")
    @login_flg = is_success
    return is_success
  end

  # TODO ログアウト処理実装 （必要？)
  # ログアウト処理
  def logout
    return nil if @login_flg == false

    # ログアウトを開く
#    page = @agent.get("http://wasser.jp")
#    # TODO もう少しまともなログイン判定を実装
#    @login_flg = page.header['content-type'] != 'text/html; charset=ISO-8859-1'
  end

  # [message]
  #   1200文字以下のエコー文章
  # [twitter_url]
  #   twitter_url
  # [返り値]
  #   ログインしていなければnilを返す
  #   
  # エコー書き込み
  # 書き込む際に、" #{twitter_url}"という文字列を後ろに付加します。
  # 正しく書き込めたらTrue、エラーしたらFalseを返します
  def write_wasser message, twitter_url
    return nil if @login_flg == false

    begin
      # wasser へ書き込み
      page = @agent.post("http://api.wassr.jp/statuses/update.json", {"status" => message + twitter_url})
    rescue
      # TODO エラー処理実装
    end
    return message
  end

  # [timeline]
  #   最大20件の本人のツブヤキ配列（新しい順）
  # [twitter_url]
  #   twitterのurl
  # [返り値]
  #   ツブヤキ件数
  # 
  # 受け取ったtimelineを全てwasserに書き込みます
  # 書き込む際に、" #{twitter_url}"という文字列を後ろに付加します。
  def write_wassers timeline, twitter_url
    return nil if @login_flg == false
    return nil if timeline == nil

    count = 0
    # 差分のみwasserへ書き込み（古い順）
    timeline.reverse_each {|text|
      count += 1 if write_wasser(text, twitter_url) != nil
      sleep 0.5
    }

    return count
  end
  
  def dontsubmit
    @dontsubmit_flg = true
  end

end

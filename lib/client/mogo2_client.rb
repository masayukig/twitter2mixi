require 'lib/client/client'

class Mogo2Client < Client
  def initialize
    super
  end

  # [id]
  #   Mogo2 id
  # [password]
  #   Mogo2 パスワード
  #
  # Mogo2へ ログイン
  # 成功したらTrueを返します。失敗したらFalseを返します。
  def login id, password
    WWW::Mechanize.log.info("mogo2 login by #{id}")

    is_success = false
    result = ''
    begin
      result = @agent.auth(id, password)
      is_success = true
    rescue
      WWW::Mechanize.log.warn("mogo2 login failed. #{$!}")
      @login_flg = false
      is_success = false
    end
    WWW::Mechanize.log.info("mogo2 login result:#{is_success}:#{result}")
    @login_flg = is_success
    return is_success
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
  def post_status message, twitter_url
    return nil if @login_flg == false

    begin
      # wasser へ書き込み
      page = @agent.post("http://api.mogo2.jp/statuses/update.json", {"status" => message + twitter_url})
    rescue
      # TODO エラー処理実装
      WWW::Mechanize.log.warn("mogo2 post_status failed. #{$!}")
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
  # 受け取ったtimelineを全てmogo2に書き込みます
  # 書き込む際に、" #{twitter_url}"という文字列を後ろに付加します。
  def post_statuses timeline, twitter_url
    return nil if @login_flg == false
    return nil if timeline == nil

    count = 0
    # 差分のみmogo2へ書き込み（古い順）
    timeline.reverse_each {|text|
      count += 1 if post_status(text, twitter_url) != nil
      sleep 0.5
    }

    return count
  end
end

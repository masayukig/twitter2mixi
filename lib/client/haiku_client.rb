require 'lib/client/client'

class HaikuClient < Client
  def initialize
    super
  end

  # [id]
  #   Hatena id
  # [password]
  #   Hatena haiku パスワード
  #
  # Hatena haikuへ ログイン
  # 成功したらTrueを返します。失敗したらFalseを返します。
  def login id, password
    WWW::Mechanize.log.info("haiku login by #{id}")

    is_success = false
    begin
      result = @agent.auth(id, password)
      is_success = true
    rescue
      WWW::Mechanize.log.warn("haiku login failed. #{$!}")
      @login_flg = false
      is_success = false
    end
    WWW::Mechanize.log.info("hatena haiku login result:#{is_success}")
    @login_flg = is_success
    return is_success
  end

  # TODO ログアウト処理実装 （必要？)
  # ログアウト処理
  def logout
    return nil if @login_flg == false

    # ログアウトを開く
#    page = @agent.get("http://hatena.ne.jp")
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
  def post_status message, twitter_url
    return nil if @login_flg == false

    begin
      # hatena haiku へ書き込み
      page = @agent.post("http://h.hatena.ne.jp/api/statuses/update.json", {"status" => message + twitter_url})
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
  # 受け取ったtimelineを全てHatena haikuに書き込みます
  # 書き込む際に、" #{twitter_url}"という文字列を後ろに付加します。
  def post_statuses timeline, twitter_url
    return nil if @login_flg == false
    return nil if timeline == nil

    count = 0
    # 差分のみhatena haikuへ書き込み（古い順）
    timeline.reverse_each {|text|
      count += 1 if post_status(text, twitter_url) != nil
      sleep 0.5
    }

    return count
  end
end

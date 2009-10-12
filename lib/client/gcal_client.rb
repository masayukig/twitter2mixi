require 'lib/client/client'

class GcalClient < Client
  def initialize
    super
  end

  # [gcal_mail]
  #   Email addr for Google Calendar
  # [gcal_password]
  #   Password for Google Calendar
  #
  # ログイン
  # 成功したらtrueを返します。失敗したらfalseを返します。
  def login gcal_mail, gcal_password
    begin
      # GoogleCalendarの初期化
      @logger.debug("mail:#{gcal_mail}, password:#{gcal_password}")
      @srv = GoogleCalendar::Service.new(gcal_mail, gcal_password)

      @logger.info("gcal login by #{gcal_mail}")
      @login_flg = true
    rescue
      @logger.warn("gcal login failed. #{$!}")
      @login_flg = false
    end
    @logger.info("gcal login result:#{@login_flg}")
    return @login_flg
  end

  # [gcal_feed_url]
  #   Feed URL for Google Calendar
  def set_feed_url gcal_feed_url
    begin
      @cal = GoogleCalendar::Calendar.new(@srv, gcal_feed_url)
      @logger.info("gcal set feed_url #{gcal_feed_url}")
      @login_flg = true
    rescue
      @logger.warn("gcal login failed. #{$!}")
      @login_flg = false
    end
    @logger.info("gcal login result:#{@login_flg}")
    return @login_flg
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
  def post_status message, date, twitter_url = nil
    return nil if @login_flg == false
    @logger.debug("message:#{message}, date:#{date.to_s}")

    begin
      # gcal へ書き込み
      event = @cal.create_event
      event.title = message
      event.desc = message
      event.st = date
      event.en = date
      event.save!
      @logger.debug("message wrote.#{event.to_s}")
    rescue
      # TODO エラー処理実装
      @logger.warn("write error. #{event.to_s}:, #{$!}")
    end
    return message
  end

  # [timeline]
  #   最大20件の本人のツブヤキ(時間も含む)配列（新しい順）
  # [twitter_url]
  #   twitterのurl
  # [返り値]
  #   ツブヤキ件数
  # 
  # 受け取ったtimelineの内、ハッシュタグ"#gcal"のついているものをgcalに書き込みます
  def post_statuses timeline, twitter_url = nil
    return nil if @login_flg == false

    count = 0
    # 差分のみgcalへ書き込み（古い順）
    timeline.reverse_each {|timeline|
      if (timeline.text.index("#gcal") != nil)
        count += 1 if post_status(timeline.text, timeline.created_at, twitter_url) != nil
        sleep 0.5
      end
    }

    return count
  end
end

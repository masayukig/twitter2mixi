require 'rubygems'
require 'kconv'
require "gcalapi"
require "logger"
gem "mechanize", "0.8.5" 
require 'mechanize'

class Client
  def initialize
    # Mechanizeの初期化
    @agent = WWW::Mechanize.new
    @login_flg = false
    @dontsubmit_flg = false

    # ログ出力
    WWW::Mechanize.log = Logger.new(File.expand_path(File.dirname(__FILE__)) + '/../../log/mechanize.log')
    WWW::Mechanize.log.level = Logger::INFO

    # ログ出力
    now = Time.now
    @logger = Logger.new(File.expand_path(File.dirname(__FILE__)) + '/../../log/test.log')
    @logger.level = Logger::DEBUG
  end

  # ログアウト処理
  def logout
    return nil if @login_flg == false
    @login_flg = false
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
  def write message, date, twitter_url
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

  # [timelines]
  #   最大20件の本人のツブヤキ(時間も含む)配列（新しい順）
  # [twitter_url]
  #   twitterのurl
  # [返り値]
  #   ツブヤキ件数
  # 
  # 受け取ったtimelineの内、ハッシュタグ"#gcal"のついているものをgcalに書き込みます
  def write_messages timelines, twitter_url
    return nil if @login_flg == false
    return nil if timelines == nil

    count = 0
    # 差分のみgcalへ書き込み（古い順）
    timelines.reverse_each {|timeline|
      if (timeline.text.index("#gcal") != nil)
        count += 1 if write(timeline.text, timeline.created_at, twitter_url) != nil
        sleep 0.5
      end
    }

    return count
  end
  
  def dontsubmit
    @dontsubmit_flg = true
  end

end

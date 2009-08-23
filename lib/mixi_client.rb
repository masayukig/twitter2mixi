require 'rubygems'
gem "mechanize", "0.8.5" 
require 'mechanize'
require 'kconv'

# 環境準備
# gem install mechanize --version "= 0.8.5"

class MixiClient
  def initialize
    # Mechanizeの初期化
    @agent = WWW::Mechanize.new
    @login_flg = false
  end

  # [email]
  #   ログインアカウントEメール
  # [password]
  #   ログインパスワード
  #
  # Mixiへ ログイン
  # 成功したらTrueを返します。失敗したらFalseを返します。
  def login email, password
    page = @agent.get('http://mixi.jp/')
    form = page.forms[0]
    form.fields.find {|f| f.name == 'email'}.value = email
    form.fields.find {|f| f.name == 'password'}.value = password
    form.fields.find {|f| f.name == 'next_url'}.value = '/home.pl'
    page = @agent.submit(form, form.buttons.first)

    # とりあえず、
    # ログイン成功すると「text/html; charset=ISO-8859-1」が返ってきて
    # ログイン失敗すると「text/html; charset=EUC-JP」が返ってくる
    # TODO もう少しまともなログイン判定を実装
    @login_flg = page.header['content-type'] == 'text/html; charset=ISO-8859-1'
  end

  # ログアウト処理
  def logout
    return nil if @login_flg == false

    # ログアウトを開く
    page = @agent.get("http://mixi.jp/logout.pl")
  end

  # [message]
  #   1200文字以下のエコー文章
  #   
  # エコー書き込み
  # 正しく書き込めたらTrue、エラーしたらFalseを返します
  def write_echo message
    return nil if @login_flg == false

    # mixi エコー を開く
    page = @agent.get("http://mixi.jp/recent_echo.pl")

    # エコー書き込み
    form = page.forms[1]
    form.fields.find { |f| f.name == 'body' }.value = message.toeuc
    page = @agent.submit( form, form.buttons.first )

    # とりあえずエラー処理無し
    # TODO エラー処理実装
    return message if true
  end

  # [timeline]
  #   最大20件の本人のツブヤキ配列（新しい順）
  # [last_status]
  #   Mixiエコーに書き込んだ最後のツブヤキ
  # [返り値]
  #   ツブヤキ件数
  # 
  # timelineの中に、last_statusがある時は、その前までMixiエコーに書き込みます
  # timelineの中に、last_statusがない時は、timelineの全てをMixiエコーに書き込みます
  def write_echos timeline, last_status
    return nil if @login_flg == false
    return nil if timeline==nil

    # 最終更新ツブヤキの差分抽出
    count = 0
    timeline_diff = Array.new
    timeline.each{|text|
      break if text == last_status && last_status != nil
      timeline_diff << text
      count += 1
    }

    # 差分のみMixiEchoへ書き込み（古い順）
    timeline_diff.reverse_each {|text|
      write_echo text
    }

    return count
  end

end

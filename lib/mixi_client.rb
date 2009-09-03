require 'rubygems'
gem "mechanize", "0.8.5" 
require 'mechanize'
require 'kconv'
require 'logger'

# 環境準備
# gem install mechanize --version "= 0.8.5"

class MixiClient
  def initialize
    # Mechanizeの初期化
    @agent = WWW::Mechanize.new
    @login_flg = false
    @dontsubmit_flg = false

    # ログ出力
    WWW::Mechanize.log = Logger.new(File.expand_path(File.dirname(__FILE__)) + '/../log/mechanize.log')
    WWW::Mechanize.log.level = Logger::INFO

  end

  # [email]
  #   ログインアカウントEメール
  # [password]
  #   ログインパスワード
  #
  # Mixiへ ログイン
  # 成功したらTrueを返します。失敗したらFalseを返します。
  def login email, password
    WWW::Mechanize.log.info("mixi login by #{email}")

    # ログインしている人でも一度強制ログアウト
    page = @agent.get('http://mixi.jp/logout.pl')

    form = page.forms[0]
    form.fields.find {|f| f.name == 'email'}.value = email
    form.fields.find {|f| f.name == 'password'}.value = password
    form.fields.find {|f| f.name == 'next_url'}.value = '/home.pl'
    page = @agent.submit(form, form.buttons.first)

    # TODO もう少しまともなログイン判定を実装
    # とりあえず、
    # ログイン成功すると「text/html; charset=ISO-8859-1」が返ってきて
    # ログイン失敗すると「text/html; charset=EUC-JP」が返ってくる
    @login_flg = page.header['content-type'] == 'text/html; charset=ISO-8859-1'
  end

  # ログアウト処理
  def logout
    return nil if @login_flg == false

    # ログアウトを開く
    page = @agent.get("http://mixi.jp/logout.pl")
    # TODO もう少しまともなログイン判定を実装
    @login_flg = page.header['content-type'] != 'text/html; charset=ISO-8859-1'
  end

  # Mixiエコーの利用を開始する
  def active_echo
    return false if @login_flg == false

    # mixi エコー を開く
    page = @agent.get("http://mixi.jp/guide_echo.pl")

    # エコーのアクティベーション
    form = page.form_with(:action => 'change_opt_echo.pl')
    if activate_link = page.link_with(:href => /change_opt_echo\.pl/)
      page = @agent.get("http://mixi.jp/#{activate_link.href}")
      return true if page != nil
    end

    return false
  end

  def active_echo?
    return false if @login_flg == false

    # mixi エコー を開く
    page = @agent.get("http://mixi.jp/recent_echo.pl")

    # エコー書き込み用のフォームを探す
    form = page.form_with(:action => 'add_echo.pl')
    # エコーをアクティベートしていないとフォーム取得できない
    return false if form == nil

    return true
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
  def write_echo message, twitter_url
    return nil if @login_flg == false

    # mixi エコー を開く
    page = @agent.get("http://mixi.jp/recent_echo.pl")
    # エコー書き込み用のフォームを探す
    form = page.form_with(:action => 'add_echo.pl')

    # エコーをアクティベートしていなかったらアクティベート処理
    if form == nil
      active_echo
      # mixi エコー を開く
      page = @agent.get("http://mixi.jp/recent_echo.pl")
      # エコー書き込み用のフォームを探す
      form = page.form_with(:action => 'add_echo.pl')
      # それでもフォーム取得できなければエラー
      return nil if form == nil
    end

    if (message.toeuc + " " + twitter_url).split(//e).length > 150
      url_length = (" " + twitter_url).length
      message_length = 150 - url_length - 2 # ".."分も削除
      message = message.toeuc.split(//e)[0..message_length - 1].join + ".."
    end
    form.field_with(:name => 'body').value = message.toeuc + " " + twitter_url
    page = @agent.submit( form, form.buttons.first ) if @dontsubmit_flg == false
    # TODO エラー処理実装
    return message
  end

  # [timeline]
  #   最大20件の本人のツブヤキ配列（新しい順）
  # [twitter_url]
  #   twitterのurl
  # [返り値]
  #   ツブヤキ件数
  # 
  # 受け取ったtimelineを全てMixiエコーに書き込みます
  # 書き込む際に、" #{twitter_url}"という文字列を後ろに付加します。
  def write_echos timeline, twitter_url
    return nil if @login_flg == false
    return nil if timeline == nil

    count = 0
    # 差分のみMixiEchoへ書き込み（古い順）
    timeline.reverse_each {|text|
      count += 1 if write_echo(text, twitter_url) != nil
      sleep 0.5
    }

    return count
  end
  
  def dontsubmit
    @dontsubmit_flg = true
  end

end

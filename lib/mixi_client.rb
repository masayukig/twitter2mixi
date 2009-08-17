require 'rubygems'
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

  # [message]
  #   1200文字以下のエコー文章
  #   
  # エコー書き込み
  # 正しく書き込めたらTrue、エラーしたらFlaseを返します
  def write_echo message
    return nil if @login_flg == false

    # mixi エコー を開く
    page = @agent.get("http://mixi.jp/recent_echo.pl")

    # エコー書き込み
    form = page.forms[1]
    form.fields.find { |f| f.name == 'body' }.value = message.toeuc
    page = @agent.submit( form,form.buttons.first )

    p page
    # とりあえずエラー処理無し
    # TODO エラー処理実装
    return message if true
  end

end

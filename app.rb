require 'rubygems'
require 'sinatra'
require 'twitter_oauth'
require 'kconv'
require 'yaml'
require 'lib/dao/user_dao'

configure do
  set :sessions, true
  @@config = YAML.load_file("config.yml") rescue nil || {}
  @@uc_flg = false

  @webservices = @@config['webservices']
  @webservices.each { |@webservice|
    require "lib/client/#{@webservice['name']}_client"
  }
end

before do
  # loginflgの設定
  @login_flg = session[:login_flg]
  @configenv = @@config['env']
  @configenv_ja = 'ステージング' if @configenv=='staging'
  @configenv_ja = '開発' if @configenv=='development'
  @webservices = @@config['webservices']

  # 工事中FLGですべての画面UCにリダイレクト
  redirect 'uc' if request.path_info != '/uc' && request.path_info != '/css/main.css' && @@uc_flg
  @debug_flg = true

  # user_dao初期化
  if request.path_info != '/'
    @user_dao = UserDao.new @@config
    @user_dao.login session[:access_token], session[:secret_token]
  end

  if request.path_info =~ /[.ico|.jpg|.css|^\/uc|^\/]$/
    @twitter_client = nil
  else
    # Twitterクライント初期化
    @twitter_client = TwitterOAuth::Client.new(
     :consumer_key => @@config['consumer_key'],
      :consumer_secret => @@config['consumer_secret'],
      :token => session[:access_token],
      :secret => session[:secret_token]
    )
  end
end

# ────────────────────────────────────────────────
# TOP
# ────────────────────────────────────────────────
get '/' do
  redirect '/member' if @login_flg
  erb :home
end

# ────────────────────────────────────────────────
# 会員 各WEBサービスの設定
# ────────────────────────────────────────────────
# 表示
get '/member/setting/:name' do |name|
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  pass if name == 'active'
  pass if name == 'inactive'

  # 設定ファイル読込
  @webservices.each { |@webservice|
    break if @webservice['name'] == name
  }
  @path = "/member/setting/#{name}"
  @flash_mess = "あなたの、#{@webservice['account_name']}のアカウントを教えて下さい。"
  
  params[:account]  = @user_dao.account name
  params[:password] = @user_dao.password name
  params[:extend]   = YAML.load("#{@user_dao.extend name}")

  erb :"member/webservice/common"
end

# 更新
post '/member/setting/:name' do |name|
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  # もし直リンクだったら/に戻す
  redirect '/' if session[:access_token] == '' || session[:secret_token] == ''
  redirect "/member/setting/#{name}" if params[:account] == '' || params[:password] == ''

  # 設定ファイル読込
  @webservices.each { |@webservice|
    break if @webservice['name'] == name
  }

  # 各WEBサービスのクライント初期化
  case name
  when 'mixi'
    client = MixiClient.new
  when 'gcal'
    client = GcalClient.new
  when 'haiku'
    client = HaikuClient.new
  when 'wassr'
    client = WassrClient.new
  else
    redirect '/'
  end

  # アカウントが正しいかログイン確認
  ret = client.login(params[:account], params[:password])
  if name == 'gcal'
    ret = ret && client.set_feed_url(params[:gcal_feed_url])
  end

  if ret
    # 正しいアカウントだった
    @flash_mess = "#{@webservice['ja']}の正しいアカウント情報を確認できました。"
    @user_dao.regist name, params[:account], params[:password]
    @user_dao.login_success name
    # 各WEBサービス
    if params[:extend] == nil
      @user_dao.regist name, YAML.dump(nil)
    else
      case name
      when 'gcal'
        @user_dao.regist name, YAML.dump(params[:extend])
      when 'mixi'
        @user_dao.regist name, YAML.dump(params[:extend])
      end
    end
  else
    # 正しいアカウントではなかった
    @flash_mess = "#{@webservice['ja']}へログインに失敗しました。"
    @user_dao.login_error name
  end

  erb :'/member/webservice/common'
end

# ────────────────────────────────────────────────
# 会員 設定 各機能の有効
# ────────────────────────────────────────────────
get '/member/setting' do 
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  @path = '/member/setting'
  erb :"member/setting"
end

post '/member/setting' do 
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg

  @path = '/member/setting'
  erb :"member/setting"
end

get '/member/setting/active' do
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  @user_dao.active_flg = true
  redirect '/member/setting'
end

get '/member/setting/inactive' do
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  @user_dao.active_flg = false
  redirect '/member/setting'
end

get '/member/setting/active/:name' do |name|
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  @user_dao.webservice_active_flg name, true
  redirect "/member/setting/#{name}"
end

get '/member/setting/inactive/:name' do |name|
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  @user_dao.webservice_active_flg(name, false)
  redirect "/member/setting/#{name}"
end

# ────────────────────────────────────────────────
# 会員 設定以外
# ────────────────────────────────────────────────
# 初回登録時
get '/member/registsuccess' do 
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  # もし直リンクだったら/に戻す
  redirect '/' if session[:access_token] == nil || session[:secret_token] == nil

  @flash_mess = 'Twitter2mixiへのご利用ありがとうございます。'
  erb :"member/setting"
end

get '/member' do 
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  # もし直リンクだったら/に戻す
  redirect '/' if session[:access_token] == nil || session[:secret_token] == nil

  @flash_mess = ''
  if @user_dao.login session[:access_token], session[:secret_token]
    @flash_mess = 'ログインしました。'
  else
    @flash_mess = 'Twitter2mixiへ、ようこそ。'
  end

  redirect '/member/setting'
end

# ログアウト
get '/member/logout' do
  # セッションの初期化
  session[:login_flg] = nil
  session[:request_token] = nil
  session[:request_token_secret] = nil
  session[:access_token] = nil
  session[:secret_token] = nil

  redirect '/'
end

# 退会
get '/member/unregist' do
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg

  erb :'member/unregist'
end

# 退会(実行)
post '/member/unregist' do
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  # もし直リンクだったら/に戻す
  redirect '/' if session[:access_token] == '' || session[:secret_token] == ''

  if @user_dao.unregist
    @login_flg = nil
    session[:login_flg] = nil
    session[:access_token] = nil
    session[:secret_token] = nil
    @flash_mess = 'Twitter2mixi登録を解除しました。'
    erb :'member/unregist_success'
  else
    @flash_mess = 'Twitter2mixi登録解除に失敗しました。'
    erb :'member/unregist'
  end
end

# ────────────────────────────────────────────────
# その他
# ────────────────────────────────────────────────
# 工事中画面
get '/uc' do
  # 工事中FLGでなければHOMEへリダイレクト
  redirect '/' if not @@uc_flg

  erb :uc
end

# ────────────────────────────────────────────────
# OAuth認証
# ────────────────────────────────────────────────
# store the request tokens and send to Twitter
get '/connect' do
  request_token = @twitter_client.request_token(:oauth_callback => @@config['oauth_confirm_url'])
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret
  redirect request_token.authorize_url
end
# auth URL is called by twitter after the user has accepted the application
# this is configured on the Twitter application settings page
get '/auth' do
  # 引数が無ければ/に戻す
  redirect '/' unless params[:oauth_verifier]

  # Exchange the request token for an access token.
  @access_token = @twitter_client.authorize(
    session[:request_token],
    session[:request_token_secret],
    :oauth_verifier => params[:oauth_verifier]
  )
  
  if @twitter_client.authorized?
    # Storing the access tokens so we don't have to go back to Twitter again
    # in this session.  In a larger app you would probably persist these details somewhere.
    session[:access_token] = @access_token.token
    session[:secret_token] = @access_token.secret
    session[:login_flg] = true

    # 会員登録
    @user_dao.twitter_regist session[:access_token], session[:secret_token]
    redirect '/member/registsuccess'
  else
    redirect '/'
  end
end

# ────────────────────────────────────────────────
# ヘルパー
# ────────────────────────────────────────────────
helpers do 
  def partial(name, options={})
    erb("#{name.to_s}".to_sym, options.merge(:layout => false))
  end
end

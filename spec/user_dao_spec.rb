require 'spec/spec_helper'
require 'lib/user_dao'

describe 'UserDaoの仕様' do
  before(:each) do
    # コンフィグ情報読込
    @config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/testdata.yaml')

    @user_dao = UserDao.new @config
    @user_dao.init_db


  end

  it '会員用テーブルの初期化を問題なく出来る' do
    @user_dao.init_db.should be_true
  end

  it '正しい値での会員の新規登録できTrueを返し、ログイン状態になる' do
    @user_dao.login_flg.should be_false
    @user_dao.twitter_regist('test_token', 'test_secret').should be_true
    @user_dao.login_flg.should be_true
  end

  it '重複登録があってもTrueを返し、ログイン状態になる' do
    @user_dao.login_flg.should be_false
    @user_dao.twitter_regist('test_token', 'test_secret').should == 1
    @user_dao.login_flg.should be_true
    @user_dao.twitter_regist('test_token', 'test_secret').should == 1
    @user_dao.login_flg.should be_true
    @user_dao.twitter_regist('test_token1', 'test_secret').should == 2
    @user_dao.login_flg.should be_true
  end

  it 'user_exist?は未会員であればfalseを返し、既存会員であれば会員IDを返す' do
    @user_dao.user_exist?('test_token').should == false
    @user_dao.twitter_regist('test_token', 'test_secret').should == 1
    @user_dao.user_exist?('test_token').should == 1
    @user_dao.twitter_regist('test_token2', 'test_secret').should == 2
    @user_dao.user_exist?('test_token2').should == 2
    @user_dao.user_exist?('test_token3').should == false

  end

  it '正しくない値(Eメールエラー)での会員の新規登録でエラーとなりfalseを返す'
  it '正しくない値(EメールがNil)での会員の新規登録でエラーとなりfalseを返す'
  it '正しくない値(パスワードがNil)で会員の新規登録でエラーとなりfalseを返す'

  it '正しいトークンとシークレットでログイン状態となりユーザ情報を取得できる'
  it '正しくないトークンとシークレットではログインが失敗しnilが返ってくる'

  it 'ログインしている会員に'
  it ''
  it ''
  it ''

end


require 'spec/spec_helper'
require 'lib/user_dao'

describe 'UserDaoの仕様' do
  before(:each) do
    @user_dao = UserDao.new
  end

  it '正しい値での会員の新規登録できTrueを返す'
  it '正しい値だが重複登録なので会員登録でエラーとなりfalseを返す'
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


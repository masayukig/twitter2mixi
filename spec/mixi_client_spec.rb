require 'spec/spec_helper'
require 'lib/mixi_client'

describe 'MixiClientの仕様' do
  before do
    @mixiclient = MixiClient.new

    # コンフィグ情報読込
    @config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/testdata.yaml')
  end

  it 'テストアカウントでログインできること' do
    @mixiclient.login(@config['mixiemail'], @config['mixipassword']).should be_true
  end

  it 'ログインエラーするとnilが返ってくる' do
    @mixiclient.login(@config['mixiemail'], 'password').should be_false
  end

  it '正しくログイン後、問題ないEchoしたらその文章が返ってくる' do
    @mixiclient.login(@config['mixiemail'], @config['mixipassword']).should be_true
    message = 'テストちゅう。問題ないエコー文章。From MixiClient'
    @mixiclient.write_echo(message).should == message
  end

  it 'nilでログインするとnilが返ってくる'
  it 'nil文をEchoしたらnilが返ってくる'
  it '1200文字オーバーのEcho文は書き込めないのでnilがかえる'
  it '改行文字入りの文章は、半角スペースに置換されて返ってくる'
end

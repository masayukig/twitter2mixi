require 'spec/spec_helper'
require 'lib/mixi_client'

describe 'MixiClientの仕様' do
  before do
    @mixiclient = MixiClient.new

    # コンフィグ情報読込
    @config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../config.yml')
  end

  it 'ログインが成功するとTrueを返すこと' do
    @mixiclient.login(@config['mixiemail'], @config['mixipassword']).should be_true
  end

  it 'ログインエラーするとFalseが返ってくる' do
    @mixiclient.login(@config['mixiemail'], 'password').should be_false
  end

  it '正しくログイン後、問題ないEchoしたらその文章が返ってくる' do
    @mixiclient.login(@config['mixiemail'], @config['mixipassword']).should be_true
    message = 'テストちゅう。問題ないエコー文章。From MixiClient'
    @mixiclient.write_echo(message).should == message
  end

  it 'エコー機能が無効であれば有効にすることが出来る' do
    @mixiclient.login(@config['mixiemail'], @config['mixipassword']).should be_true
    @mixiclient.active_echo if @mixiclient.active_echo? == false
    @mixiclient.active_echo?.should be_true
  end

  it '一度ログインしてそのログアウトしたらエコー書き込みに失敗する' do
    @mixiclient.login(@config['mixiemail'], @config['mixipassword']).should be_true
    @mixiclient.logout.should be_true
    message = '一度ログインしてそのログアウトしたらエコー書き込みに失敗するテストちゅう。From MixiClient'
    @mixiclient.write_echo(message).should be_nil
  end

  it 'nilでログインするとnilが返ってくる'
  it 'nil文をEchoしたらnilが返ってくる'
  it '1200文字オーバーのEcho文は書き込めないのでnilがかえる'
  it '改行文字入りの文章は、半角スペースに置換されて返ってくる'

  it 'timelineを一括エコー書き込み'do
    @mixiclient.login(@config['mixiemail'], @config['mixipassword']).should be_true
    timeline = Array.new
    timeline << 'はじめのツブヤキ'
    timeline << '2回目のツブヤキ'
    timeline << '3回目のツブヤキ(一番古い)'
    @mixiclient.write_echos(timeline, '3回目のツブヤキ(一番古い)').should == 2
  end
end

require 'rubygems'
require 'mechanize'
require 'kconv'

agent = WWW::Mechanize.new
page = agent.get('http://twitter.com/nashiki/')

puts page.body.tosjis


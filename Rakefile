require 'rubygems'
require 'spec/rake/spectask'

task :default => :spec

desc "Run all specs in spec directory"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_opts = ['--format specdoc', '--color']
  t.spec_files = FileList['test/**/*_spec.rb']
end

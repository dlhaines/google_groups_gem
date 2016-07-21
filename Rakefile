require "bundler/gem_tasks"
#task :default => :spec
require 'rake/testtask'

#Rake::TestTask.new do |t|
#  t.libs << 'test'
#end


task :demo_notes do
  puts <<END_OF_STRING
   NOTE: It is expected that some tests will show 'Deferred' and 'S' (skip) test results.  Those are for items
   not yet implemented or not usually tested.
END_OF_STRING
end

test_files = FileList['test/test_*rb']

desc 'Run GGB demo tests'
Rake::TestTask.new(:demo => :demo_notes) do |t|
  t.ruby_opts += ["-W1"]
  t.libs.push 'lib'
  t.test_files = test_files
  t.verbose = true
end

desc "Run Tests"
task :default => :test


# task :demo_notes do
#   puts <<END_OF_STRING
#   NOTE: It is expected that some tests will show 'Deferred' and 'S' (skip) test results.  Those are for items
#   not yet implemented or not usually tested.
# END_OF_STRING
# end

# namespace 'test' do
#   test_files = FileList['test_*rb']
#
#   desc 'Run GGB demo tests'
#   Rake::TestTask.new(:demo => :demo_notes) do |t|
#     t.ruby_opts += ["-W1"]
#     t.libs.push 'lib'
#     t.test_files = test_files
#     t.verbose = true
#   end
# end
#
# desc 'Run all tests'
# task 'test' => %w(test:demo)
# task 'default' => 'test'

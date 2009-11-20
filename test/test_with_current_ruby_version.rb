require 'mkmf'
require File.dirname(__FILE__) + '/../lib/ruby_core_source'

hdrs = proc { have_header("vm_core.h") and have_header("iseq.h") }
# todo 1.8 version

if !Ruby_core_source::create_makefile_with_core(hdrs, "foo")
  puts 'fail'
  # error
  exit(1)
end
puts 'success'
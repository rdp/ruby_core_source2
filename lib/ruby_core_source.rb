require 'rbconfig'
require 'tempfile'
require 'tmpdir'
require 'yaml'
require File.join(File.dirname(__FILE__), 'contrib', 'uri_ext')
require 'archive/tar/minitar' # a gem
require 'zlib'
require 'fileutils'

module Ruby_core_source

  def create_makefile_with_core(hdrs, name)

    #
    # First, see if the gem already has the needed headers
    #
    if hdrs.call
      create_makefile(name)
      return true
    end

    ruby_dir = ""
    svn_version = nil
    if RUBY_PATCHLEVEL < 0 # -1 means from trunk
      Tempfile.open("preview-revision") { |temp|
        uri = URI.parse("http://cloud.github.com/downloads/mark-moseley/ruby_core_source/preview_revision.yml")
        uri.download(temp)
        revision_map = YAML::load(File.open(temp.path))
        ruby_dir = revision_map[RUBY_REVISION]
        if ruby_dir.nil?
          if RUBY_DESCRIPTION =~ /dev.*trunk (\d+)/
            #svn_version = 'svn-r' + $1 # TODO rdp
            svn_version = $1
          else
            return false
          end
        end
      }
    else
      ruby_dir = "ruby-" + RUBY_VERSION.to_s + "-p" + RUBY_PATCHLEVEL.to_s
    end

    #
    # Check if core headers were already downloaded; if so, use them
    #
    dest_dir = Config::CONFIG["rubyhdrdir"] + "/" + ( ruby_dir || svn_version )
    with_cppflags("-I" + dest_dir) {
      if hdrs.call
        create_makefile(name)
        return true
      end
    }


    #
    # Download the headers
    #
    Tempfile.open("ruby-src") { |temp|

      if !svn_version
        # download it
        uri_path = "http://ftp.ruby-lang.org/pub/ruby/1.9/" + ruby_dir + ".tar.gz"
        temp.binmode
        uri = URI.parse(uri_path)
        uri.download(temp) # download it to temp
        tgz = Zlib::GzipReader.new(File.open(temp, "rb"))
      else
        ruby_dir = svn_version
      end


      FileUtils.mkdir_p(dest_dir)
      Dir.mktmpdir { |dir|
        inc_dir = dir + "/" + ruby_dir + "/*.inc"
        hdr_dir = dir + "/" + ruby_dir + "/*.h"
        if svn_version
          Dir.rmdir dir
          # recreate it
          svn_dir = dir + '/' + svn_version
          system("svn co -r#{svn_version} http://svn.ruby-lang.org/repos/ruby/trunk #{svn_dir}")
          Dir.chdir(svn_dir) do
            # create id.h (needed and must be created for some reason)
            system("sh -c 'autoconf'")
            system("sh -c './configure'")
            system("sh -c 'make id.h'") 
          end
        else
          Archive::Tar::Minitar.unpack(tgz, dir) # here's where it unpacks 'em all
        end
        FileUtils.cp(Dir.glob([ inc_dir, hdr_dir ]), dest_dir)        
      }
    }

    with_cppflags("-I" + dest_dir) {
      if hdrs.call
        create_makefile(name)
        return true
      end
    }
    return false
  end
  module_function :create_makefile_with_core

end

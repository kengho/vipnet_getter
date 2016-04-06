module VipnetCoordinatorSettingsGrabber
  # returns path to tempfile with iplirconf or nil if any problem occured
  def iplirconf(hostname, password)
    username = "vipnet"

    # add digest to known_hosts if needed
    require "ruby_expect"
    exp_ssh_digest = RubyExpect::Expect.spawn("/usr/bin/ssh #{username}@#{hostname}")
    exp_ssh_digest.timeout = 3
    exp_ssh_digest.procedure do
      each do
        expect /Are you sure you want to continue connecting \(yes\/no\)\?\s*$/ do
          send "yes"
        end
      end
    end

    iplirconf = String.new
    logged = false

    # logging
    exp = RubyExpect::Expect.spawn("/usr/bin/ssh #{username}@#{hostname}")
    exp.timeout = 3
    exp.procedure do
      each do
        expect /password:\s*$/ do
          send password
          puts "entering password"
        end
        # for some reason if pw is not incorrect, script wait for timeout and dont expect ">" for "iplir show config"
        # thus, code below doesn't work
        # expect /Permission denied, please try again/ do
        # puts "permission denied"
        # end
        expect />\s*$/ do
          send "iplir show config"
          # when running with cron, message appears:
          # WARNING: terminal is not fully functional
          #-  (press RETURN)
          send 13 # enter
          logged = true
          puts "iplir show config"
        end
      end
      return nil if !logged

      # reading iplirconf
      retflag = false
      while !retflag
        retval = any do
          expect /.*:/m do
            iplirconf += last_match.to_s
            last_match.to_s.split("\n").each do |line|
              if line =~ /default= auto/
                retflag = true
                break
              end
            end
            send 34 # pagedown
          end
        end
      end
    end

    # remove regular trash caused by "send 34"
    iplirconf = iplirconf.gsub(":\e[K\r\e[K:\e[K3\b3\e[K4\b4\r\e[K", "")
    # remove trash in the beginning
    iplirconf = iplirconf.gsub("iplir show config\r\n\e[?1049h\e[?1h\e=\r", "")
    # remove trash in the end
    iplirconf = iplirconf[/.*default= auto\r\n/m, 0]
    # replace \r\n by \n
    iplirconf = iplirconf.gsub("\r", "")
    # dunno what's the source of this
    iplirconf = iplirconf.gsub(":\x1B[K\x1B[K:\x1B[K1\x081\x1B[K3\x083\x1B[K", "")
    # remove trash caused by "terminal is not fully functional" issue when running script with cron
    iplirconf = iplirconf.gsub("::3\x083", "")
    iplirconf = iplirconf.gsub("4\x084", "")
    iplirconf = iplirconf.gsub("iplir show config\nWARNING: terminal is not fully functional\n-  (press RETURN):1\x081", "")
    iplirconf = iplirconf.gsub("4\x084", "")
    # add return if necessary
    iplirconf += "\n" if iplirconf[-4..-1] != "\n\n"

    require "tempfile"
    iplirconf_file = Tempfile.new("iplirconf")
    iplirconf_file.write(iplirconf)
    iplirconf_file.flush
    iplirconf_file.path
  end

  module_function :iplirconf
end

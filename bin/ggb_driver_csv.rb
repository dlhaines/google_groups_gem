#!/usr/bin/env ruby
# Class to support adding files to GGB archive based on command file.
# This is a demonstration, not a full command line tool.

# read in a csv file file commands in the following format:
# <id> is a group id, either internal google id or the group email address.

# group_create <id> <name> <email> <description>    => make sure this group exists
# group_delete <id> <name> => get rid of this group
# group_list

# group_member_add <id> <member email> => add member to group
# group_member_list <id> => get a list of the current members (include role)
# get_email_from_file(filename) => get an email to insert, DUMMY IMPLEMENTATION

# group_migration_insert <id> <email content as string format is message/rfc822> => insert standard email

#### UNIMPLEMENTED
# group_settings <id> <description> => (limited) update description
# group_member_delete <id> <member email> => get rid of member.

## Add new method by duplicating some method below, setting up this config hash,
## and setting up the command line arguments to be passed in.  Methods that are added
## will automatically be recognized.
#
# config = {
#       ## command line args passed in
#     :args => args,
#       ## exact number of args required, including command name
#     :required_args => 4,
#       ## name (as symbol) of method to call in ggb_service_account.rb.
#     :method_symbol => :insert_new_group,
#       ## define a proc that will be called on the results of the Google API call.
#     :handle_result => Proc.new { |result|
#       puts "create group: #{args[1]}"
#       puts "#{args[0]}: result: #{result.inspect}"
#     },
#       ## name of the section of config yaml file that defines the google service.
#     :service_name => 'ADMIN_DIRECTORY'
# }

#require_relative 'ggb_service_account'
require_relative '../lib/ggb'

$file = "ggb_test_A.csv"
#$file = "Gemfile"

class GGBDriverCSV
  # Define class to parse commands and invoke ggb_service_account methods.

  def create_test_email(group_id, from_name, from_email)
    # Format an RFC822 message
    now = Time.now
    message_id = "#{now.to_f}-#{group_id}"
    message_date = now.strftime '%a, %d %b %Y %T %z'
    message = <<-EOF
Message-ID: <#{message_id}>
Date: #{message_date}
To: #{group_id}
From: "#{from_name}" <#{from_email}>
Subject: Groups Migration API Test #{now.iso8601}

This is a test.
    EOF
  end


  ########## parse and run commands
  def start(file)
    File.open(file).each do |line|
      line.chomp!

      # skip comments and empty lines
      next if (line[/^\s*#/])
      next if (line[/^\s*$/])

      elements = line.split('|')

      command = elements[0]

      # invoke method if it exists.  Adding a corresponding
      # method is sufficient to add the command.
      if GGBDriverCSV.method_defined? command
        self.send(command, elements)
      else
        #puts ">>>>>>>>> not implemented: [#{command}] [#{args}]"
        puts ">>>>>>>>> not implemented: [#{command}]"
      end

    end
  end

  ######## group commands

  def group_create(args)

    config = {
        :args => args,
        :required_args => 4,
        :method_symbol => :insert_new_group,
        :handle_result => Proc.new { |result|
          puts "create group: #{args[1]}"
          puts "#{args[0]}: result: #{result.inspect}"
        },
        :service_name => 'ADMIN_DIRECTORY'
    }

    run_request(config, [{"email": args[1], "name": args[2], "description": args[3]}])
  end

  def group_delete(args)

    config = {
        :args => args,
        :required_args => 2,
        :method_symbol => :delete_group,
        :handle_result => Proc.new { |result|
          puts "#{args[0]}: result: #{result.inspect}"
        },
        :service_name => 'ADMIN_DIRECTORY'
    }

    run_request(config, args[1])
  end

  def group_info(args)

    config = {
        :args => args,
        :required_args => 2,
        :method_symbol => :get_group_info,
        :handle_result => Proc.new { |result|
          puts "group_info: for #{args[1]}"
          puts "result.inspect: #{result.inspect}"
          result
        },
        :service_name => 'ADMIN_DIRECTORY'
    }

    run_request(config, args[1])
  end


  def group_list(args)

    config = {
        :args => args,
        :required_args => 1,
        :method_symbol => :list_groups,
        :handle_result => Proc.new { |result|
          puts "group_list:"
          result.groups.each { |g| puts "\temail: #{g.email}" }
          result.groups
        },
        :service_name => 'ADMIN_DIRECTORY'
    }

    run_request(config, [])
  end

  ##### group member commands

  def group_member_list(args)

    config = {
        :args => args,
        :required_args => 2,
        :method_symbol => :list_members,
        :handle_result => Proc.new { |result|
          puts "group_member_list: #{args[1]}"
          if !result.nil? && !result.members.nil?
            result.members.each { |g| puts "\temail: #{g.email}" }
            result.members
          end
        },
        :service_name => 'ADMIN_DIRECTORY'
    }

    run_request(config, args[1])
  end

  # member settings:
  #member = {
  #      'email': @common_fake,
  #      'role': 'OWNER'
  #  }
  def group_member_add(args)

    config = {
        :args => args,
        :required_args => 4,
        :method_symbol => :insert_member,
        :handle_result => Proc.new { |result|
          puts "group_member_add: group: #{args[1]} user: #{args[2]}"
          puts "group_member_add: result: #{result.inspect}"
        },
        :service_name => 'ADMIN_DIRECTORY'
    }

    use_args = [args[1], {'email': args[2], 'role': args[3]}]

    run_request(config, use_args)
  end

  # dummy implementation
  def get_email_from_file(file)
    group_id = "GGB-csv-test-ZZZ@discussions-dev.its.umich.edu"
    from_name = "GGB CPM csv tester"
    from_email = "GGB-CPM-csv_tester@umich.edu"
    create_test_email(group_id, from_name, from_email)
  end

  def group_migration_insert(args)

    config = {
        :args => args,
        :required_args => 3,
        :method_symbol => :insert_archive,
        :handle_result => Proc.new { |result|
          puts "#{__method__}: group: #{args[1]} email: #{args[2]}"
          puts "#{__method__}: result: #{result.inspect}"
        },
        :service_name => 'GROUPS_MIGRATION'
    }

    email = get_email_from_file args[2]
    use_args = [args[1], email]

    run_request(config, use_args)
  end

  ##########################################

  def run_request(config, use_args)

    result = check_args(config)
    return nil if result.nil?

    s = GGBServiceAccount.new()
    s.configure('default.yml', config[:service_name])

    # run the method
    begin
      result = s.send(config[:method_symbol], *use_args)
    rescue => exp
      puts "rescue: handle rescue: #{use_args}"
      # handle known exception cases.
      case exp.message
        when /duplicate/
          puts ">>> DUPLICATE <<<"
          return true
        else
          puts ">>>>>>>>>>>> FAILED <<<<<<<<<<<"
      end
      puts "rescue: #{exp.inspect}"
      puts "rescue: #{exp.backtrace}"
      return ">>>>>>>>>>>> FAILED <<<<<<<<<<<"
    end

    # handle the results
    config[:handle_result].(result)
  end

  # sanity check the calls.
  def check_args(config)
    if config[:args].length != config[:required_args]
      puts "error: wrong number of args. #{config[:required_args]} are required.  #{config[:method_name]}: #{config[:args]}"
      return nil
    end
    true
  end

end

# invoke if called standalone, but allow including in another file also.
if __FILE__ == $0
  s = GGBDriverCSV.new()
  s.start($file)
end

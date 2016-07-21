require 'minitest'
require 'minitest/autorun'
require 'minitest/unit'
require 'shoulda'

require_relative '../lib/ggb'

## Test / demonstrate calling the UMich google group apis

# A skip in a setup section can be used to skip all tests in that context.
# Some tests have skips since they require a specific setup that won't
# always be there.  They are included because they may be useful for specific
# situations.

### TTD:
# - factor out the domain and email.
# - factor out constants

#### Standard values for testing
# Used to construct safe group names for testing.
SUFFIX="@discussions-dev.its.umich.edu"
PREFIX="GGB-CPM-TEST-inserted-group-"
# No group will ever have this name.
NEVER_A_GROUP="GGB-CPM-bored_of_the_rings#{SUFFIX}"
# This group will always exist.
ETERNAL_GROUP="ggb-cpm-eternal@discussions-dev.its.umich.edu"
EMAIL_INSERT_TEST_GROUP="ggb-test-group-insert@discussions-dev.its.umich.edu"

CONFIG_TEST_FILE = 'default.yml'

class GGBServiceAccountTest < Minitest::Test

  # utility to construct useful test group names
  def create_group_name(root)
    "#{PREFIX}#{root}#{SUFFIX}"
  end

  #From: "Alice Smith" <alice@example.com>
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

  context "TEST ENVIRONMENT" do
    should "have configuration file" do
      assert File.exist?(CONFIG_TEST_FILE), "should have readable configuration file: [#{CONFIG_TEST_FILE}]"
    end
  end

  ## Test our use of the group settings service.

  context "SERVICE: GROUP SETTINGS:" do

    setup do
      #skip "skip all group settings tests"
      @s = GGBServiceAccount.new()
      @s.configure(CONFIG_TEST_FILE, 'GROUP_SETTINGS')
    end

    teardown do
    end

    context "CONFIGURATION" do

      should "read default information and create a new service" do
        gac = ENV['GOOGLE_APPLICATION_CREDENTIALS']
        assert_match /\.json$/, gac, "google application credentials should be json file."
        assert_operator gac.length, :>, 6, "path to credentials should be non-trivial."
      end

    end

    context "READ" do
      should "get settings for existing group" do
        group_settings = @s.get_group_settings
        # check for description in standard format.
        assert_match /UPDATED description at:/, group_settings.description, "Verify test group description"
        # verify that email is plausible
        assert_match /.*\@.*.umich.edu$/, group_settings.email, "Verify email is plausible"
      end

    end

    context "UPDATE" do

      should "modify description" do
        initial_settings = @s.get_group_settings
        initial_description = initial_settings.description
        sleep(1) # make sure time stamp in description should be different
        # modify settings object to have new description
        initial_settings.description = "UPDATED description at: #{Time.now.iso8601}"
        update_result = @s.update_group_settings(initial_settings)
        updated_description = update_result.description
        refute_equal initial_description, updated_description, "description should have changed"
      end

    end
    
  end

  ## Test our use of the admin directory service for groups.
  context "SERVICE: ADMIN DIRECTORY:" do

    setup do
      #skip "skip all Admin directory tests"
      @s = GGBServiceAccount.new()
      @s.configure(CONFIG_TEST_FILE, 'ADMIN_DIRECTORY')
    end

    teardown do
    end

    context "GROUPS:" do

      # operations: delete, get, insert, list, patch, update

      ####
      should "DELETE should return nil for non-extant group" do
        result = @s.delete_group NEVER_A_GROUP
        assert_nil result, "Return nil if can not delete a group"
      end

      should "DELETE existing group" do
        skip "not for automated testing since must know that group already exists."
        key = create_group_name("DELETE-ME")
        @s.delete_group key
      end

      ### Get information for existing group.  The information is different than that
      ### from the groupsettings service.

      # This test assumes the cited group always exists with a specific format.
      should "GET" do
        key = ETERNAL_GROUP
        group_info = @s.get_group_info(key)
        #puts "GET: #{ETERNAL_GROUP} members: #{group_info.inspect}"
        assert_match /Test group for GGB CPM testing that will always exist/, group_info.description, "AD: find known group info: #{key}"
      end

      ### Insert a new group
      # not for automated test but see CREATE AND DELETE GROUP
      should "INSERT NEW GROUP" do
        skip "not for automated testing since group may already exist."
        key = create_group_name("E")
        group_info = @s.get_group_info(key)
        fail "group already exists: #{key}" if (!group_info.nil?)

        ng_test = {
            "email": key,
            "name": "CPM group insert test",
            "description": "This is a group inserted by CPM testing"
        }

        result = @s.insert_new_group(ng_test)
        refute_nil result, "Created group #{key}"
      end

      ### list the available groups.
      should "LIST" do
        group_list = @s.list_groups
        assert_operator group_list.groups.length, :>, 2, "should have at least 3 groups."
        #group_list.groups.each {|g| puts "group: [#{g.email}]\t[#{g.description}]"}
      end

      ## List with paging
      should_eventually "LIST WITH PAGED RESULT" do

      end

      ### Use patch to be efficient.
      # maybe, but maybe not important, comment out for now.
      # should_eventually "PATCH" do
      # end

      ### Use update to be efficient.
      # maybe, but maybe not important, comment out for now.
      # update same properties used when inserting a group.
      # should_eventually "UPDATE" do
      # end

      ###############################
      ##### composite tests

      should "CREATE AND DELETE GROUP" do

        # create a unique group
        key = create_group_name("GROUP-CREATE-DELETE")
        group_info = @s.get_group_info(key)
        fail "group already exists: #{key}" if (!group_info.nil?)

        ng_test = {
            "email": key,
            "name": "CPM group insert test",
            "description": "This is a group inserted by CPM testing"
        }

        result = @s.insert_new_group(ng_test)
        refute_nil result, "Created group #{key}"

        # delete that group
        delete_result = @s.delete_group key
      end

    end


    ############# Group members methods #################
    # methods are delete, get, insert, list, patch, update
    context "GROUP MEMBERS:" do
      setup do
        #skip
        @common_member = 'gsilver@umich.edu'
        @common_fake = 'ggb-cpm-fake@umich.edu'
      end

      # {
      #     "kind": "admin#directory#member",
      #     "etag": etag,
      #     "id": string,
      #     "email": string,
      #     "role": string,
      #     "type": string
      # }

      should "INSERT" do
        skip "not for automated testing since must know member status ahead of time"
        member = {
            'email': @common_member,
            'role': 'OWNER'
        }
        member_result = @s.insert_member ETERNAL_GROUP, member
        refute_nil member_result, "should insert user #{member.inspect} into #{ETERNAL_GROUP}"
      end

      should "DELETE" do
        skip "not for automated testing since must know member status ahead of time"
        member = @common_member
        delete_result = @s.delete_member ETERNAL_GROUP, member
        assert_nil delete_result, "should get nothing"
      end


      # possible roles are OWNER and MEMBER
      should "INSERT_AND_DELETE" do

        member = {
            'email': @common_fake,
            'role': 'OWNER'
        }

        # clear out the fake user if it is already there
        begin
          @s.delete_member ETERNAL_GROUP, @common_fake
        rescue => exp
        end

        member_result = @s.insert_member ETERNAL_GROUP, member
        refute_nil member_result, "should insert user #{@common_fake} into #{ETERNAL_GROUP}"

        # make sure they are removed.
        delete_result = @s.delete_member ETERNAL_GROUP, @common_fake
        assert_nil delete_result, "should get nil from delete"

        # should not be able to find the deleted user.
        begin
          get_result = @s.get_member ETERNAL_GROUP, @common_fake
          fail "should have thrown ClientError as user should not exist"
        rescue Google::Apis::ClientError => exp
          assert_match /notFound:/, exp.message
        end
      end

      should "GET" do
        member = @common_member
        result = @s.get_member ETERNAL_GROUP, member
        assert_match @common_member, result.email
      end

      should "LIST" do
        member_list = @s.list_members ETERNAL_GROUP
        assert_operator member_list.members.length, :>, 0, "should have at least 1 member"
      end

      # maybe someday if it matters.
      #   should_eventually "PATCH" do
      #     # modify membership settings for user
      #   end
      #   should_eventually "UPDATE" do
      #   # modify membership settings for user
      # end

    end
  end


  ## test email archive migration
  context "SERVICE: GROUPS MIGRATION:" do

    setup do
      @s = GGBServiceAccount.new()
      @s.configure(CONFIG_TEST_FILE, 'GROUPS_MIGRATION')
    end

    context "INSERT:" do

      should "ADD EMAIL" do
        group_id = EMAIL_INSERT_TEST_GROUP
        test_email = create_test_email group_id, "Dave Haines", "dlhaines@umich.edu"
        response = @s.insert_archive(group_id, test_email)
        assert_equal "SUCCESS", response.response_code, "added new email"
      end

      should "FAIL TO INSERT WHEN BAD GROUP" do
        group_id = EMAIL_INSERT_TEST_GROUP+".XXX"
        test_email = create_test_email group_id, "Dave Haines", "dlhaines@umich.edu"
        begin
          response = @s.insert_archive(group_id, test_email)
        rescue => exp
          response = nil
        end
        assert_nil response, "nonsense group id should not work"
      end

      # NOTE: bad user email will work fine

    end

    context "ATTACHMENTS:" do
      should_eventually "handle attachments" do

      end
    end
  end
end



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

# Some tests are useful, but not in automated setting.
#RUN_EVERYTHING = true
RUN_EVERYTHING = false

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
        group_settings_json = @s.get_group_settings
        group_settings = JSON.parse(group_settings_json)
        refute_nil group_settings, "read existing group description"
        # check for description in standard format.
        assert_match /UPDATED description at:/, group_settings['description'], "Verify test group description"
        # verify that email is plausible
        assert_match /.*\@.*.umich.edu$/, group_settings['email'], "Verify email is plausible"
      end

    end

    context "UPDATE" do

      should "modify description" do
        skip "implement later"
        puts "update modify description"
        initial_settings_json = @s.get_group_settings
        puts "UPDATE modify description: #{initial_settings_json}"
        initial_settings = JSON.parse(initial_settings_json)
        refute_nil initial_settings, "modify existing group description"
        #puts "modify description: initial_settings: #{initial_settings}"
        initial_description = initial_settings['description']
        sleep(1) # make sure time stamp in description should be different
        # modify settings object to have new description
        #initial_settings.description = "UPDATED description at: #{Time.now.iso8601}"
        initial_settings['description'] = "UPDATED description at: #{Time.now.iso8601}"
        update_result_json = @s.update_group_settings(initial_settings)
        update_result = JSON.parse(update_result_json)
        updated_description = update_result['description']
        refute_equal initial_description, updated_description, "description should have changed"
      end

    end

  end

  ## Test our use of the admin directory service for groups.
  context "SERVICE: ADMIN DIRECTORY:" do

    setup do
      @s = GGBServiceAccount.new()
      @s.configure(CONFIG_TEST_FILE, 'ADMIN_DIRECTORY')
    end

    teardown do
    end

    context "GROUPS:" do

      # operations: delete, get, insert, list, patch, update

      ####
      should "DELETE should return nil for non-extant group" do
        assert_raises GGBServiceAccountError, "Return nil if can not delete a group" do
          @s.delete_group NEVER_A_GROUP
        end
      end

      if RUN_EVERYTHING
        should "DELETE existing group" do
          key = create_group_name("DELETE-ME")
          @s.delete_group key
        end
      end

      ### Get information for existing group.  The information is different than that
      ### from the groupsettings service.

      # This test assumes the cited group always exists with a specific format.
      should "GET" do
        key = ETERNAL_GROUP
        group_info = @s.get_group_info(key)
        group_info = JSON.parse(group_info)
        assert_match /Test group for GGB CPM testing that will always exist/, group_info['description'], "AD: find known group info: #{key}"
      end

      ### Insert a new group
      # not for automated test but see CREATE AND DELETE GROUP
      if RUN_EVERYTHING
        should "INSERT NEW GROUP" do
          key = create_group_name("EE")
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
      end

      ### Fail if group name is for bad domain
      # To test for wrong domain could use the subs below, but
      # don't want automated test against production domain.
      #key.sub!('-dev','')
      #key.sub!('.its','')
      should "NOT INSERT NEW GROUP in bad domain" do
        key = create_group_name("SHOULD_FAIL_BAD_DOMAIN")
        # create a bad domain
        key = key.sub('@', '@XXX')

        assert_raises GGBServiceAccountError, "not have this group already" do
          @s.get_group_info(key)
        end

        ng_test = {
            "email": key,
            "name": "CPM group insert test",
            "description": "This is a group inserted by CPM testing"
        }

        assert_raises GGBServiceAccountError, "do not create group" do
          @s.insert_new_group(ng_test)
        end
      end


      ### list the available groups.
      should "LIST" do
        group_list = @s.list_groups
        group_list = JSON.parse(group_list)
        assert_operator group_list['groups'].length, :>, 2, "should have at least 3 groups."
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

        ng_test = {
            "email": key,
            "name": "CPM group insert test",
            "description": "This is a group inserted by CPM testing"
        }

        # it's ok if the group already exists
        begin
          result = @s.insert_new_group(ng_test)
          refute_nil result, "Created group #{key}"
        rescue GGBServiceAccountError => ggb_err
          assert_equal 409, ggb_err.status_code, "group creation failed"
        end

        # Delete that group.
        @s.delete_group key

        # verify that the group is gone.
        begin
          @s.get_group_info(key)
          fail "should not find group after deletion"
        rescue GGBServiceAccountError => ggb_err
          assert_equal 404, ggb_err.status_code, "group should not exist"
        end

      end

      ############# Group members methods #################
      # methods are delete, get, insert, list, patch, update
      context "GROUP MEMBERS:" do
        setup do
          @common_member = 'gsilver@umich.edu'
          @test_member = 'GGB-CPM-TEST-TRANSIENT@umich.edu'
          @eternal_member = 'GGB-CPM-TEST-ETERNAL-MEMBER@umich.edu'
          @common_fake = 'GGB-FAKE@umich.edu'
        end

        # member object
        # {
        #     "kind": "admin#directory#member",
        #     "etag": etag,
        #     "id": string,
        #     "email": string,
        #     "role": string,
        #     "type": string
        # }

        if RUN_EVERYTHING
          should "INSERT" do
            member = {
                'email': @test_member,
                'role': 'OWNER'
            }
            member_result = @s.insert_member ETERNAL_GROUP, member
            refute_nil member_result, "should insert user #{member.inspect} into #{ETERNAL_GROUP}"
          end

          should "DELETE" do
            member = @test_member
            delete_result = @s.delete_member ETERNAL_GROUP, member
            assert_nil delete_result, "should get nothing"
          end
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

          assert_raises GGBServiceAccountError, "missing user causes exception" do
            get_result = @s.get_member ETERNAL_GROUP, @common_fake
          end

          # should not be able to find the deleted user.
          #begin
          #  get_result = @s.get_member ETERNAL_GROUP, @common_fake

          #          fail "should have raised ClientError as user should not exist"
          #        rescue Google::Apis::ClientError => exp
          #          assert_match /notFound:/, exp.message
        end

        should "GET" do
          member = @eternal_member
          result_json = @s.get_member ETERNAL_GROUP, member
          result = JSON.parse(result_json)
          #puts "members: get: #{result.inspect}"
          #assert_match @eternal_member, result.email
          assert_match @eternal_member, result['email']
          #fail "verify member get"
        end

        should "LIST all" do
          member_list_json = @s.list_members ETERNAL_GROUP
          member_list = JSON.parse(member_list_json)
          assert_operator member_list['members'].length, :>, 0, "should have at least 1 member"
        end

        # maybe someday if it matters.
        #   should_eventually "PATCH" do
        #     # modify membership settings for user
        #   end
        #   should_eventually "UPDATE" do
        #   # modify membership settings for user
        # end

      end
      #end


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
            response_json = @s.insert_archive(group_id, test_email)
            response = JSON.parse(response_json)
            assert_equal "SUCCESS", response['responseCode'], "added new email"
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
  end
end


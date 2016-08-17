require 'minitest'
require 'minitest/autorun'

require 'shoulda'
require_relative '../lib/ggb'

require_relative 'test_helper'

## Test / demonstrate calling the UMich google group apis

# A skip in a setup section can be used to skip all tests in that context.
# Some tests have skips since they require a specific setup that won't
# always be there.  They are included because they may be useful for specific
# situations.

class GGBServiceAdminDirectoryTest < Minitest::Test

  include TestHelper

  # # utility to construct useful test group names
  # def create_group_name(root)
  #   "#{PREFIX}#{root}#{SUFFIX}"
  # end

  context "TEST ENVIRONMENT" do
    should "have configuration file" do
      assert File.exist?(CONFIG_TEST_FILE), "should have readable configuration file: [#{CONFIG_TEST_FILE}]"
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
          assert_match @eternal_member, result['email']
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
      
    end

  end
end


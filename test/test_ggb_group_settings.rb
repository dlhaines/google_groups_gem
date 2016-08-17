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


class GGBServiceGroupSettingsTest < Minitest::Test

  include TestHelper

  context "TEST ENVIRONMENT" do
    should "have configuration file" do
      assert File.exist?(CONFIG_TEST_FILE), "should have readable configuration file: [#{CONFIG_TEST_FILE}]"
    end
  end

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
end

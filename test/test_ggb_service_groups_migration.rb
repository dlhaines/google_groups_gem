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

class GGBServiceGroupsMigrationTest < Minitest::Test

  include TestHelper


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

      # NOTE: bad user email address will insert fine.

    end

    context "ATTACHMENTS:" do
      should_eventually "handle attachments" do

      end
    end
  end
end


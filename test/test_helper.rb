## Common test setup / utilities

require 'minitest'
require 'minitest/autorun'
require 'minitest/unit'

require 'shoulda'

#### Standard values for testing
# Used to construct safe group names for testing.
SUFFIX="@discussions-dev.its.umich.edu"
PREFIX="GGB-CPM-TEST-inserted-group-"
# No group will ever have this name.
NEVER_A_GROUP="GGB-CPM-bored_of_the_rings#{SUFFIX}"
# This group will always exist.
ETERNAL_GROUP="ggb-cpm-eternal@discussions-dev.its.umich.edu"
#EMAIL_INSERT_TEST_GROUP="ggb-test-group-insert@discussions-dev.its.umich.edu"
EMAIL_INSERT_TEST_GROUP="ggb-test-group-20160615@discussions-dev.its.umich.edu"

CONFIG_TEST_FILE = 'default.yml'

RUN_EVERYTHING = false

module TestHelper

  # convenience function to create a reasonable group name
  # utility to construct useful test group names
  def create_group_name(root)
    "#{PREFIX}#{root}#{SUFFIX}"
  end

  def new_epoch_time
    sleep 1
    Time.new.to_i
  end

end

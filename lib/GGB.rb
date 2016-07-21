# Demonstrate using Google service account with default application configuration.

# This serves as an adaptor to hide Google API SDK details and make it easy to call required GGB methods from Ruby.

# Create UMich API instance for google groups API.  One instance of the API is bound to a specific domain
# and a specific API.
# E.g. A single instance may only work with GROUP_SETTINGS and discussions-dev.
# This makes no attempt to deal with additional Google API standard options such as fields.

# Method names correspond directly to the names available in the relevant Google API SDK.
# The caller should map between the needs of a specific application and this service.  Not all
# functionallity in the SDK is surfaced here.

# Read configuration from a yml file.
# NOTE: I could not get the patch approach to work so updates require a wholesale replacement.

## TTD:
## - deal with paging
## - throw errors if not appropriate response.
## - pass in configuration file when create API.
## - make it possible to turn on logging and set logging level from configuration file.
## - recommend to NOT use email as id, since it could change.

require "ggb/version"

require 'json'
require 'yaml'

require 'googleauth'
require 'google/apis/groupssettings_v1'
require 'google/apis/admin_directory_v1'
require 'google/apis/groupsmigration_v1'

class GGBServiceAccount

  # store configuration values
  attr_accessor :cf

  # Must add for Google gem: http://stackoverflow.com/questions/32434363/google-oauth-ssl-error-ssl-connect-returned-1-errno-0-state-sslv3-read-server
  ENV['SSL_CERT_FILE'] = Gem.loaded_specs['google-api-client'].full_gem_path+'/lib/cacerts.pem'

  # Uncomment to get logging from Google APIs
  # Google::Apis.logger.level = Logger::DEBUG

  def initialize
    @cf = Hash.new()
    super
  end

  # Read yml configuration file.  Add credential location to env so can use Google code
  # and their default application credentials approach.

  def configure(config_file, api_name)
    cf_load = YAML.load_file(config_file)

    @cf[:CREDENTIALS_DIR] = cf_load['CREDENTIALS']['DIR']
    @cf[:CREDENTIALS_FILE] = cf_load['CREDENTIALS']['FILE']
    @cf['DOMAIN'] = cf_load['DOMAIN']
    @cf['API_NAME'] = cf_load[api_name]

    ENV['GOOGLE_APPLICATION_CREDENTIALS'] = "#{@cf[:CREDENTIALS_DIR]}/#{@cf[:CREDENTIALS_FILE]}"

  end

  # Return an authorized service based on this configuration.  This assumes both
  # a service account and a SUBJECT to impersonate.
  def authorize_service(api_settings, domain)

    # capture the api settings for this setup.
    @api_settings = api_settings

    service_name = api_settings['SERVICE_NAME']
    # load service classes dynamically but don't use eval.
    service = Object.const_get(service_name, true).new
    service.client_options.application_name = api_settings['APPLICATION_NAME']
    service.authorization = Google::Auth.get_application_default(api_settings['SCOPES'])

    client=service.authorization.dup
    client.sub=domain['SUBJECT_EMAIL']
    client.fetch_access_token!
    service.authorization=client

    service
  end

  # bind generic authorization to configuration values.
  def authorize_google_service
    authorize_service(@cf['API_NAME'], @cf['DOMAIN'])
  end

  #####################################################
  ########## Group settings methods ###################
  # The settings value should be a group settings object.  It could be returned
  # from a get settings call or, probably, can be a fresh one created via
  # Google::Apis::GroupssettingsV1::Groupssettings representation.
  def update_group_settings(new_settings)
    service = authorize_google_service
    service.update_group @api_settings['GROUP_EMAIL'], new_settings
  end

  # Find the current settings
  def get_group_settings
    service = authorize_google_service
    service.get_group(@api_settings['GROUP_EMAIL'])
  end

  ####################################################
  ######## Admin Directory queries ###################

  ############ top level group calls #################
  # get the group info for a specific group.  If not found then
  # return nil.
  def get_group_info(key)
    service = authorize_google_service
    begin
      result = service.get_group(key)
    rescue => exp
      result = nil
    end
    result
  end

  # Create a new group with these properties.
  # {
  #     "email": "GGB-CPM-inserted-group@discussions-dev.its.umich.edu",
  #     "name": "CPM group insert test",
  #     "description": "This is a group inserted by CPM testing"
  # }

  def insert_new_group(new_group_settings)
    g = Google::Apis::AdminDirectoryV1::Group.new(new_group_settings)
    service = authorize_google_service
    service.insert_group(g)
  end

  # delete an existing group

  def delete_group groupKey
    service = authorize_google_service
    begin
      result = service.delete_group groupKey
    rescue => exp
      result = nil
    end
    result
  end

  # list the groups. Currently try to list all groups, ignoring any
  # paging information.
  def list_groups(domain=nil)
    domain = @cf['DOMAIN']['DEFAULT_NAME'] if domain.nil?
    service = authorize_google_service
    service.list_groups(domain: domain)
  end

  ############ group membership #################

  # response to group membership query.
  # {
  #     "kind": "admin#directory#members",
  #     "etag": etag,
  #     "members": [
  #         members Resource
  #     ],
  #     "nextPageToken": string
  # }

  #def list_members(group_key, max_results: nil, page_token: nil, roles: nil, fields: nil, quota_user: nil, user_ip: nil, options: nil, &block)
  def list_members groupKey
    service = authorize_google_service
    begin
      result = service.list_members groupKey
    rescue => exp
      #puts "exp: #{exp.inspect}"
      result = nil
    end
    result
  end

  #def get_member(group_key, member_key, fields: nil, quota_user: nil, user_ip: nil, options: nil, &block)
  def get_member group_key, member_key
    service = authorize_google_service
    service.get_member group_key, member_key
  end

  #def insert_member(group_key, member_object = nil, fields: nil, quota_user: nil, user_ip: nil, options: nil, &block)
  def insert_member group_id, member_settings
    #puts "insert_member: group_id: [#{group_id}] member_settings: [#{member_settings}]"
    service = authorize_google_service
    m = Google::Apis::AdminDirectoryV1::Member.new member_settings
    service.insert_member group_id, m
  end

  #def delete_member(group_key, member_key, fields: nil, quota_user: nil, user_ip: nil, options: nil, &block)
  def delete_member group_key, member_key
    service = authorize_google_service
    service.delete_member group_key, member_key
  end

  #def insert_archive(group_id, fields: nil, quota_user: nil, user_ip: nil, upload_source: nil, content_type: nil, options: nil, &block)
  def insert_archive(group_id, source)
    content_type = 'message/rcf822'

    service = authorize_google_service
    service.insert_archive(group_id, upload_source: StringIO.new(source), content_type: 'message/rfc822')
  end

end

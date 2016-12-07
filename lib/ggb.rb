# Demonstrate using Google service account with default application configuration.

# NOTE: This class knows about Google API details and classes, but hides that from the caller.
# Output must be in pure json without reference to Google specific objects.

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
## - raise errors if not appropriate response.
## - pass in configuration file when create API.
## - make it possible to turn on logging and set logging level from configuration file.
## - recommend to NOT use email as id, since it could change.

#require_relative "ggb/version"

require 'json'
require 'yaml'
require 'logger'

require 'googleauth'
require 'google/apis/groupssettings_v1'
require 'google/apis/admin_directory_v1'
require 'google/apis/groupsmigration_v1'

# Add custom error for callers to handle
# Allow passing the error code.
class GGBServiceAccountError < StandardError
  attr_reader :status_code

  def initialize(msg="GGB adaptor error", status_code=400)
    @status_code = status_code
    super(msg)
  end
end

class GGBServiceAccount

  # Add logger that can be overridden.  Sample call below.
  #GGBServiceAccount.logger.debug "initalized"

  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.progname = self.name
      end
    end
  end

  # store configuration values
  attr_accessor :cf

  # Must add for Google gem: http://stackoverflow.com/questions/32434363/google-oauth-ssl-error-ssl-connect-returned-1-errno-0-state-sslv3-read-server
  ENV['SSL_CERT_FILE'] = Gem.loaded_specs['google-api-client'].full_gem_path+'/lib/cacerts.pem'

  # Uncomment to get logging from Google APIs
  # Google::Apis.logger.level = Logger::DEBUG

  def initialize
    @cf = Hash.new()
    super
    self.class.logger.level=Logger::ERROR
    #self.class.logger.level=Logger::INFO
    #self.class.logger.level=Logger::DEBUG
    #self.class.logger = nil
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
  #module Google::Apis::GroupssettingsV1::Groups
  def update_group_settings(new_settings)
    puts "initial new_settings: #{new_settings}"
    service = authorize_google_service
    begin
      #puts "new new_settings: #{new_settings}"

      result = service.update_group @api_settings['GROUP_EMAIL'], new_settings
    rescue => exp
      msg = "update_group_settings: FAILED status_code: #{exp.status_code} message: #{exp.message} new_settings: #{new_settings}"
      puts "update_group_settings: #{exp}"
      self.class.logger.warn msg
      new_exp = GGBServiceAccountError.new(msg, exp.status_code)
      raise new_exp
    end
    result ? result.to_json : nil
  end

  # Find the current settings
  def get_group_settings
    service = authorize_google_service
    begin
      result = service.get_group(@api_settings['GROUP_EMAIL'])
        #puts "get_group_settings: #{result.to_json}"
    rescue => exp
      msg = "get_group_settings: FAILED status_code: #{exp.status_code} message: #{exp.message} key: #{@api_settings['GROUP_EMAIL']}"
      self.class.logger.warn msg
      new_exp = GGBServiceAccountError.new(msg, exp.status_code)
      raise new_exp
    end
    result ? result.to_json : nil
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
      msg = "get_group_info: FAILED status_code: #{exp.status_code} message: #{exp.message} key: #{key}"
      handle_exception(exp, msg)
    end
    result ? result.to_json : nil
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
    begin
      result = service.insert_group(g)
    rescue => exp
      msg = "insert_new_group: FAILED status_code: #{exp.status_code} message: #{exp.message} group_settings: #{new_group_settings.inspect}"
      handle_exception(exp, msg)
    end
    result ? result.to_json : nil
  end

  # delete an existing group

  def delete_group group_id
    service = authorize_google_service
    begin
      result = service.delete_group group_id
    rescue => exp
      msg = "delete_group: FAILED status_code: #{exp.status_code} message: #{exp.message} group_id: #{group_id}"
      handle_exception(exp, msg)
    end
    # puts "delete_group : #{result}"
    result ? result.to_json : nil
  end

  # list the groups. Currently try to list all groups, ignoring any
  # paging information.
  def list_groups(domain=nil)
    domain = @cf['DOMAIN']['DEFAULT_NAME'] if domain.nil?
    service = authorize_google_service
    begin
      result = service.list_groups(domain: domain)
    rescue => exp
      msg = "list_groups: FAILED status_code: #{exp.status_code} message: #{exp.message} domain: #{domain}"
      handle_exception(exp, msg)
    end
    result ? result.to_json : nil
  end

  # standard handling for an exception from Google
  def handle_exception(exp, msg)
    self.class.logger.warn msg
    raise GGBServiceAccountError.new(msg, exp.status_code)
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
  def list_members group_key
    service = authorize_google_service
    begin
      result = service.list_members group_key
    rescue => exp
      msg = "list_members: FAILED status_code: #{exp.status_code} message: #{exp.message} group_key: #{group_key}"
      handle_exception(exp, msg)
    end
    result ? result.to_json : nil
  end

  #def get_member(group_key, member_key, fields: nil, quota_user: nil, user_ip: nil, options: nil, &block)
  def get_member group_key, member_key
    service = authorize_google_service
    begin
      result = service.get_member group_key, member_key
    rescue => exp
      msg = "get_member: FAILED status_code: #{exp.status_code} message: #{exp.message} group_key: [#{group_key}] member_key: [#{member_key}]"
      handle_exception(exp, msg)
    end
    result ? result.to_json : nil
  end

  #def insert_member(group_key, member_object = nil, fields: nil, quota_user: nil, user_ip: nil, options: nil, &block)
  def insert_member group_key, member_settings
    service = authorize_google_service
    m = Google::Apis::AdminDirectoryV1::Member.new member_settings
    begin
      result = service.insert_member group_key, m
    rescue => exp
      msg = "list_member: FAILED status_code: #{exp.status_code} message: #{exp.message} group_key: #{group_key} member_settings: #{member_settings}"
      handle_exception(exp, msg)
    end
    result ? result.to_json : nil
  end

  #def delete_member(group_key, member_key, fields: nil, quota_user: nil, user_ip: nil, options: nil, &block)
  def delete_member group_key, member_key
    service = authorize_google_service
    begin
      result = service.delete_member group_key, member_key
    rescue => exp
      msg = "delete_member: FAILED status_code: #{exp.status_code} message: #{exp.message} group_key: #{group_key} member_key: #{member_key}"
      handle_exception(exp, msg)
    end
    result ? result.to_json : nil
  end

  #def insert_archive(group_id, fields: nil, quota_user: nil, user_ip: nil, upload_source: nil, content_type: nil, options: nil, &block)
  def insert_archive(group_key, source)
    message_type = 'message/rfc822'

    service = authorize_google_service
    begin
      result = service.insert_archive(group_key, upload_source: StringIO.new(source), content_type: message_type)
    rescue => exp
      msg = "insert_archive: FAILED status_code: #{exp.status_code} message: #{exp.message} group_key: #{group_key}"
      handle_exception(exp, msg)
    end
    result ? result.to_json : nil
  end

end

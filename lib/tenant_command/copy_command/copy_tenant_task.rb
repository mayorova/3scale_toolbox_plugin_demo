class CopyTenantTask
  attr_reader :context

  def initialize(context)
    @context = context
  end

  def call
    tenant = source_master_client.show_account source_tenant_id
    users_list = source_master_client.list_users source_tenant_id
    first_user = users_list.shift
    logger.info("Creating new tenant...")

    tenant_create_response = create_tenant tenant, first_user

    sleep(5) # wait until the route is created

    new_tenant = tenant_create_response['signup']['account']
    new_tenant_id = new_tenant['id']
    new_tenant_access_token = tenant_create_response['signup']['access_token']['value']

    logger.info("Created new tenant with ID #{new_tenant_id} and access token #{new_tenant_access_token}")

    # NOTE: the Application name for the tenant will be "API signup" instead of "<provider-name>'s App"

    # Copy users
    copy_tenant_users users_list, first_user, new_tenant_id

    # Get the provider keys for authentication
    target_tenant_client = get_target_tenant_client target_master_client, new_tenant, new_tenant_access_token
    context[:target_tenant_client] = target_tenant_client

    copy_all_products source_tenant_client, target_tenant_client
  end

  private

  def copy_tenant_users(users_list, first_user, new_tenant_id)
    logger.info("Updating first tenant user...")
    new_first_user = target_master_client.list_users(new_tenant_id).first
    update_user new_tenant_id, first_user, new_first_user
    logger.info("Updated first tenant user with ID #{new_first_user['id']}...")

    users_list.each do |user|
      unless user['username'] == '3scaleadmin'
        logger.info("Creating tenant user with username #{user['username']}...")
        new_user = create_user new_tenant_id, user
        update_user new_tenant_id, user, new_user
        logger.info("Created user with id #{new_user['id']}")
      end
    end
  end

  def copy_all_products(source_client, target_client)

    products = source_client.list_services

    product_copy_context = {
      source_remote: source_client,
      target_remote: target_client,
      delete_mapping_rules: true
    }

    products.each do |product|
      system_name = product['system_name']

      logger.info("Copying product system name #{system_name}")

      ThreeScaleToolbox::Commands::ProductCommand::CopySubcommand.workflow(
        { source_service_ref:  system_name }.merge(product_copy_context)
      )

      logger.info("Product created!")
    end
  end

  # DOESN'T WORK: the provider key has some restrictions and can't be used for listing backend usages
  # see: https://issues.redhat.com/browse/THREESCALE-8276
  # def get_tenant_client(remote, tenant)
  #   tenant_apps = remote.list_applications_by_account tenant['id']
  #   provider_key = tenant_apps.first['user_key']
  #   endpoint = tenant['admin_base_url']
  #
  #   # verify_ssl is disabled for the purpose of this script
  #   ThreeScale::API.new(endpoint: endpoint, provider_key: provider_key,
  #                                verify_ssl: false, keep_alive: remote.http_client.keep_alive)
  # end

  def get_target_tenant_client(remote, tenant, access_token)
    endpoint = tenant['admin_base_url']

    # verify_ssl is disabled for the purpose of this script
    ThreeScale::API.new(endpoint: endpoint, provider_key: access_token,
                        verify_ssl: false, keep_alive: remote.http_client.keep_alive)
  end

  def create_tenant(account, user)
    attrs = {
      org_name: account['org_name'],
      username: user['username'],
      email: user['email'],
      password: temp_password
    }
    # TODO: this comand should be added to the 3scale Ruby API
    target_master_client.http_client.post("/master/api/providers", body: attrs)
  end

  def create_user(new_account_id, user)
    attrs = {
      account_id: new_account_id,
      email: user['email'],
      username: user['username'],
      password: temp_password
    }
    target_master_client.create_user(attrs)
  end

  def update_user(account_id, original_user, new_user)
    target_master_client.http_client.put("/admin/api/accounts/#{account_id}/users/#{new_user['id']}", body: original_user)

    # By default the API creates users as "member" with "pending" state, update if required
    # Set the role
    if original_user['role'] == "member"
      target_master_client.http_client.put("/admin/api/accounts/#{account_id}/users/#{new_user['id']}/member")
    elsif original_user['role'] == "admin"
      target_master_client.http_client.put("/admin/api/accounts/#{account_id}/users/#{new_user['id']}/admin")
    end

    # Set the status
    if original_user['state'] == "pending"
      target_master_client.http_client.put("/admin/api/accounts/#{account_id}/users/#{new_user['id']}/suspend")
    elsif original_user['state'] == "active"
      target_master_client.http_client.put("/admin/api/accounts/#{account_id}/users/#{new_user['id']}/activate")
    end
  end

  def copy_account(id)
    source_backend = Entities::Account.new(id: backend_usage.backend_id, remote: source_master_client)
  end

  def source
    context[:source]
  end

  def target
    context[:target]
  end

  def source_master_client
    context[:source_master_client]
  end

  def target_master_client
    @target_master_client ||= context[:target_master_client]
  end

  def source_tenant_id
    @source_tenant_id ||= context[:source_tenant_id]
  end

  def source_tenant_client
    @source_tenant_client ||= context[:source_tenant_client]
  end

  def temp_password
    context[:temp_password]
  end

  def logger
    context[:logger] ||= Logger.new($stdout).tap do |logger|
      logger.formatter = proc { |severity, datetime, progname, msg| "#{msg}\n" }
    end
  end

end
class CopyAccountsApplicationsTask
  attr_reader :context

  def initialize(context)
    @context = context
    @account_ids = Hash.new
  end

  def call

    puts 'Copying accounts and applications'

    find_matching_plans
    delete_default_account
    copy_accounts

    puts 'Copying accounts and applications completed!'
    pp objects_mapping
    puts objects_mapping.to_json

  end

  private

  def delete_default_account
    accounts = target_tenant_client.list_accounts
    accounts.each do |acc|
      target_tenant_client.delete_account acc['id']
      logger.info "Account with id #{acc['id']} and org name #{acc['org_name']} deleted from target"
    end
  end

  def copy_accounts
    source_accounts = source_tenant_client.list_accounts
    source_accounts.each do |acc|
      users_list = source_tenant_client.list_users acc['id']
      first_user = users_list.shift
      logger.info("Creating account with id #{acc['id']}")

      new_account = create_account acc, first_user

      copy_users users_list, first_user, new_account['id']
      copy_account_applications acc['id'], new_account['id']

      objects_mapping[:accounts][acc['id']] = new_account['id']
    end
  end

  def create_account(account, user)
      attrs = {
        email: user['email'],
        password: temp_password,
        name: user['name']
      }
      new_account = target_tenant_client.signup(attrs, name: account['org_name'], username: user['username'])
      logger.info "Created account! source id: #{account['id']}, target id: #{new_account['id']}"
      logger.info "Created user! source id: #{user['id']}, username #{user['username']} password: #{temp_password}"
      new_account
  end

  def copy_users(users_list, first_user, new_account_id)
    logger.info("Updating first account user...")
    new_first_user = target_tenant_client.list_users(new_account_id).first
    update_user new_account_id, first_user, new_first_user
    logger.info("Updated first account user with ID #{new_first_user['id']}...")

    users_list.each do |user|
      new_user = create_user new_account_id, user
      update_user new_account_id, user, new_user
    end
  end

  def update_user(account_id, original_user, new_user)
    target_tenant_client.http_client.put("/admin/api/accounts/#{account_id}/users/#{new_user['id']}", body: original_user)

    # By default the API creates users as "member" with "pending" state, update if required
    # Set the role
    begin
      if original_user['role'] == "member"
        target_tenant_client.http_client.put("/admin/api/accounts/#{account_id}/users/#{new_user['id']}/member")
      elsif original_user['role'] == "admin"
        target_tenant_client.http_client.put("/admin/api/accounts/#{account_id}/users/#{new_user['id']}/admin")
      end

      # Set the status
      if original_user['state'] == "pending"
        target_tenant_client.http_client.put("/admin/api/accounts/#{account_id}/users/#{new_user['id']}/suspend")
      elsif original_user['state'] == "active"
        target_tenant_client.http_client.put("/admin/api/accounts/#{account_id}/users/#{new_user['id']}/activate")
      end
    rescue ThreeScale::API::HttpClient::ForbiddenError => e
      logger.info e
    end
  end

  def copy_account_users account_id
    users_list = source_tenant_client.list_users account_id
  end

  def copy_account_applications source_account_id, target_account_id

    delete_default_application target_account_id

    apps = source_tenant_client.list_applications_by_account source_account_id

    plans = flat_plans_mapping

    apps.each do |app|
      # NOTE: other fields such as redirect_url, first_traffic_at, first_daily_traffic_at and additional_fields are
      # not taken into account
      attrs = {
        name: app['name'],
        description: app['description'],
        user_key: app['user_key'],
        application_id: app['application_id'],
        application_key: app['application_key']
      }
      target_plan_id = plans[app['plan_id']]
      new_app = target_tenant_client.create_application target_account_id, attrs, plan_id: target_plan_id
      logger.info "Created application, source id #{app['id']}, target id #{new_app['id']}"

      add_application_to_mapping(app['service_id'], app['id'], new_app['id'])
    end

  end

  def delete_default_application target_account_id
    apps = target_tenant_client.list_applications_by_account target_account_id
    apps.each do |app|
      target_tenant_client.delete_application target_account_id, app['id']
    end
  end

  def create_user(new_account_id, user)
    attrs = {
      account_id: new_account_id,
      email: user['email'],
      username: user['username'],
      first_name: user['first_name'],
      last_name: user['last_name'],
      password: temp_password
    }
    new_user = target_tenant_client.create_user(attrs)
    logger.info "Created user! source id: #{user['id']}, target id: #{new_user['id']}, password: #{temp_password}"
    new_user
  end

  def find_matching_plans
    # NOTE: the call is not paginated! will only get a maximum of 500 services
    source_services_list = source_tenant_client.list_services
    target_services_list = target_tenant_client.list_services

    source_services_list.each do |service|
      source_service_id = service['id']
      target_service_id = target_services_list.find{ |s| compare_by_system_name s, service }['id']

      logger.info "Matching plans ID: #{source_service_id}, target service ID: #{target_service_id}, system name: #{service['system_name']}"

      source_plans = source_tenant_client.list_service_application_plans source_service_id
      target_plans = target_tenant_client.list_service_application_plans target_service_id

      plans_mapping = {}
      source_plans.each do |plan|
        target_plan = target_plans.find{ |p| compare_by_system_name p, plan }
        plans_mapping[plan['id']] = target_plan['id']
        logger.info "App plan with system name #{plan['system_name']} and id #{plan['id']} matches target plan id #{target_plan['id']}"
      end

      objects_mapping[:services][source_service_id] = {
        target_service_id: target_service_id,
        plans: plans_mapping
      }

    end

  end

  def compare_by_system_name(obj1, obj2)
    obj1['system_name'] == obj2['system_name']
  end

  def source_tenant_client
    @source_tenant_client ||= context[:source_tenant_client]
  end

  def target_tenant_client
    @target_tenant_client ||= context[:target_tenant_client]
  end

  # A hash that keeps the matching ids in the following format
  # {
  #   services: {
  #     '<source service id>' => {
  #       target_service_id: '<target service id>',
  #       plans: {
  #         '<source plan id>' => '<target plan id>'
  #       },
  #       applications: {
  #         '<source app id>' => '<target app id>'
  #       }
  #   },
  #   accounts: {
  #     '<source account id>' => {
  #       target_account_id => '<target account id>',
  #       users: {
  #         '<source user id>' => '<target user id>'
  #       }
  #     }
  #   }
  # }}
  def objects_mapping
    @objects_mapping ||= { services: {}, accounts: {} }
  end

  def flat_plans_mapping
    objects_mapping[:services].values.map{|v| v[:plans]}.reduce(:merge)
  end

  # TODO: remove duplication across the tasks
  def logger
    context[:logger] ||= Logger.new($stdout).tap do |logger|
      logger.formatter = proc { |severity, datetime, progname, msg| "#{msg}\n" }
    end
  end

  def temp_password
    context[:temp_password]
  end

  def add_application_to_mapping(source_service_id, source_app_id, target_app_id)
    objects_mapping[:services][source_service_id][:applications] ||= {}
    objects_mapping[:services][source_service_id][:applications][source_app_id] = target_app_id
  end
end

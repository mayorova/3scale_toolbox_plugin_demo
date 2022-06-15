require 'tenant_command/copy_command/copy_tenant_task'
require 'tenant_command/copy_command/copy_accounts_applications_task'

class TenantCopySubcommand < Cri::CommandRunner
  include ThreeScaleToolbox::Command

  def self.command
    Cri::Command.define do
      name        'copy'
      usage       'copy [options] -s <source-master> -d <target-master> <source-tenant-id>'
      summary     'Copy 3scale tenant'
      description 'Copy 3scale tenant from source master account to target master account'

      option  :s, :source, '3scale source master account. Url or remote name', argument: :required
      option  :d, :destination, '3scale target master account. Url or remote name', argument: :required
      param   :source_tenant_id
      param   :temp_password

      runner TenantCopySubcommand
    end
  end

  def self.workflow(context)
    tasks = []
    tasks << CopyTenantTask.new(context)
    tasks << CopyAccountsApplicationsTask.new(context)
    tasks.each(&:call)
  end

  def run
    puts 'I will copy the tenant!'
    self.class.workflow(context)
  end

  private

  def context
    @context ||= create_context
  end

  def create_context
    tenant_id = arguments[:source_tenant_id]
    {
      source_master_client: threescale_client(fetch_required_option(:source)),
      target_master_client: threescale_client(fetch_required_option(:destination)),
      source_tenant_id: tenant_id,
      temp_password: arguments[:temp_password],
      source_tenant_client: threescale_client("tenant_#{tenant_id}")
    }
  end
end

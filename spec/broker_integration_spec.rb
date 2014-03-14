require 'blue-shell'
require 'cfoundry'

include BlueShell::Matchers

describe 'Broker Registrar command line bin' do
  before(:all) do
    @config = YAML.load_file('spec/config.yml')
  end

  context 'does not receive all the parameters' do
    it 'returns a validation error' do
      BlueShell::Runner.run 'bin/broker-registrar register' do |runner|
        runner.with_timeout(1) do
          runner.should have_output 'Usage: broker-registrar register --cf-address <URL> --cf-username <CF username> --cf-password <CF password> --broker-name <broker name> --broker-url <broker URL> --broker-username <broker username> --broker-password <broker password>'
          runner.should have_output 'missing argument: cf-address'
          runner.should have_exit_code(1)
        end
      end
    end
  end

  context 'does include all the parameters' do
    let(:cf_address) { @config['cloud_foundry']['url'] }
    let(:cf_username) { @config['cloud_foundry']['username'] }
    let(:cf_password) { @config['cloud_foundry']['password'] }
    let(:broker_name) { 'elasticsearch' }
    let(:broker_url) { @config['broker']['url'] }
    let(:broker_username) { @config['broker']['username'] }
    let(:broker_password) { @config['broker']['password'] }
    let(:client) { create_client }
    let(:test_organization) { create_organization(client) }
    let(:test_space) { create_space(client, test_organization) }
    let(:command) do
      "bin/broker-registrar register --cf-address \"#{cf_address}\" " +
        "--cf-username \"#{cf_username}\" " +
        "--cf-password \"#{cf_password}\" " +
        "--broker-name \"#{broker_name}\" " +
        "--broker-url \"#{broker_url}\" " +
        "--broker-username \"#{broker_username}\" " +
        "--broker-password \"#{broker_password}\""
    end

    before do
      clean_environment
      setup_environment(client)
      expect(client.service_brokers.first).to be_nil
      expect(client.services.first).to be_nil
    end

    after do
      clean_environment
    end

    it 'returns a successful exit code' do
      puts BlueShell::Runner.run command do |runner|
        runner.with_timeout(1) do
          runner.should have_exit_code(0)
        end
      end
    end

    it 'registers the service broker with the cloud controller' do
      puts `#{command}`

      expect(client.service_brokers.first.name).to eq(broker_name)
    end

    it 'creates a service that is public and can be created' do
      puts `#{command}`

      service_plan = client.service_plans.first
      expect(is_service_plan_public?(service_plan)).to be_true
    end

    it 'can be run twice successfully' do
      BlueShell::Runner.run command do |runner|
        runner.with_timeout(1) do
          runner.should have_exit_code(0)
        end
      end

      BlueShell::Runner.run command do |runner|
        runner.with_timeout(1) do
          runner.should have_exit_code(0)
        end
      end
    end

    context 'and a non-public service plan already exists' do
      before do
        create_service_broker
        service_plan = client.service_plans.first
        service_plan.public = false
        service_plan.update!
      end

      it 'makes the service plan public' do
        puts `#{command}`

        service_plan = client.service_plans.first
        expect(is_service_plan_public?(service_plan)).to be_true
      end
    end

    context 'and the service broker already exists with different details' do
      before do
        create_service_broker
      end

      let(:new_command) do
        "bin/broker-registrar register --cf-address \"#{cf_address}\" " +
          "--cf-username \"#{cf_username}\" " +
          "--cf-password \"#{cf_password}\" " +
          "--broker-name \"#{broker_name}\" " +
          "--broker-url \"#{new_broker_url}\" " +
          "--broker-username \"#{broker_username}\" " +
          "--broker-password \"#{broker_password}\""
      end
      let(:new_broker_url) { 'http://10.244.3.62' }

      it 'sets the broker details as requested' do
        `#{new_command}`
        broker = client.service_broker_by_name(broker_name)
        expect(broker.broker_url).to eq(new_broker_url)
      end
    end

    def find_service(name)
      client.services.find { |s| s.label == name }
    end

    def create_client
      client = CFoundry::Client.get(cf_address)
      client.login(username: 'admin', password: 'admin')
      client
    end

    def clean_environment
      service_instances = client.service_instances_by_space_guid(test_space.guid)
      service_instances.each { |si| si.delete }

      service = find_service(broker_name)
      if service
        service.service_plans.each { |sp| sp.delete! }
        service.delete!
      end

      service_broker = client.service_broker_by_name(broker_name)
      service_broker.delete if service_broker
    end

    def setup_environment(client)
      client.current_organization = test_organization
      client.current_space = test_space
    end

    def create_organization(client)
      org = client.organization
      org.name = 'test_broker_registrar-org'
      begin
        org.create!
      rescue CFoundry::OrganizationNameTaken
        org = client.organizations.find { |o| o.name == 'test_broker_registrar-org' }
      end
      org
    end

    def create_space(client, org)
      space = client.space
      space.name = 'test_broker_registrar-space'
      space.organization = org
      begin
        space.create!
      rescue CFoundry::SpaceNameTaken
        space = client.spaces.find { |s| s.name == 'test_broker_registrar-space' }
      end
      space
    end

    def create_service_broker
      broker = client.service_broker
      broker.name = broker_name
      broker.broker_url = broker_url
      broker.auth_username = broker_username
      broker.auth_password = broker_password

      broker.create!
      broker
    end

    def is_service_plan_public?(service_plan)
      service = client.managed_service_instance
      service.name = 'test-service-instance'
      service.space = client.current_space
      service.service_plan = service_plan
      begin
        service.create!
        true
      rescue
        false
      end
    end
  end
end

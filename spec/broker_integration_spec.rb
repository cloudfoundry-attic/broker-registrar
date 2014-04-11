require 'blue-shell'
require 'cfoundry'

include BlueShell::Matchers

describe 'Broker Registrar command line bin' do
  before(:all) do
    @config = YAML.load_file('spec/config_defaults.yml')
  end

  describe 'the bin file' do
    context 'does not receive all the parameters' do
      it 'returns a validation error' do
        bad_command = <<-BASH
bin/broker-registrar register \
--cf-address url \
--cf-username user \
--cf-password password \
--broker-name broker-name
        BASH

        BlueShell::Runner.run bad_command do |runner|
          runner.with_timeout(1) do
            runner.should have_output <<-USAGE
Usage: broker-registrar register|delete OPTS

Required options:
--cf-address <URL>
--cf-username <CF username>
--cf-password <CF password>
--broker-name <broker name>
--broker-url <broker URL>
--broker-username <broker username>
--broker-password <broker password>

            USAGE
            runner.should have_output 'missing argument: broker-url'
            runner.should have_exit_code(1)
          end
        end
      end
    end

    context 'with other errors' do
      let(:invalid_url) { 'url' }

      it 'catches them and does not print the usage' do
        command = "bin/broker-registrar register --cf-address #{invalid_url} " +
          "--cf-username user " +
          "--cf-password password " +
          "--broker-name broker_name " +
          "--broker-url broker_url " +
          "--broker-username broker_user " +
          "--broker-password broker_password"

        BlueShell::Runner.run command do |runner|
          expect(runner).to say 'Invalid target URI'
          expect(runner).not_to say 'Usage'
          expect(runner).to have_exit_code(1)
        end
      end
    end
  end

  describe 'registering' do
    let(:cf_address) { @config['cloud_foundry']['url'] }
    let(:cf_username) { @config['cloud_foundry']['username'] }
    let(:cf_password) { @config['cloud_foundry']['password'] }
    let(:broker_name) { 'elasticsearch' }
    let(:broker_url) { @config['broker']['url'] }
    let(:broker_username) { @config['broker']['username'] }
    let(:broker_password) { @config['broker']['password'] }
    let(:new_broker_url) { broker_url.gsub('registrar-broker-1', 'registrar-broker-2') }
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
      BlueShell::Runner.run command do |runner|
        runner.with_timeout(5) do
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
        runner.with_timeout(30) do
          expect(runner).to have_exit_code(0)
        end
      end

      BlueShell::Runner.run command do |runner|
        runner.with_timeout(30) do
          runner.should have_exit_code(0)
        end
      end
    end

    context 'and a non-public service plan already exists' do
      before do
        create_service_broker
        service_plan        = client.service_plans.first
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

      it 'sets the broker details as requested' do
        `#{new_command}`
        broker = client.service_broker_by_name(broker_name)
        expect(broker.broker_url).to eq(new_broker_url)
      end
    end

    def setup_environment(client)
      client.current_organization = test_organization
      client.current_space        = test_space
    end

    def is_service_plan_public?(service_plan)
        service              = client.managed_service_instance
        service.name         = 'test-service-instance'
        service.space        = client.current_space
        service.service_plan = service_plan
        begin
          service.create!
          true
        rescue
          false
        end
      end
  end

  describe 'deleting' do
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
      "bin/broker-registrar delete --cf-address \"#{cf_address}\" " +
        "--cf-username \"#{cf_username}\" " +
        "--cf-password \"#{cf_password}\" " +
        "--broker-name \"#{broker_name}\" " +
        "--broker-url \"#{broker_url}\" " +
        "--broker-username \"#{broker_username}\" " +
        "--broker-password \"#{broker_password}\""
    end

    before do
      clean_environment
      expect(client.service_brokers.first).to be_nil
      expect(client.services.first).to be_nil
      create_service_broker
    end

    after do
      clean_environment
    end

    it 'returns a successful exit code' do
      BlueShell::Runner.run command do |runner|
        runner.with_timeout(10) do
          runner.should have_exit_code(0)
        end
      end
    end

    it 'deletes the broker from the cloud controller' do
      puts `#{command}`

      expect(client.service_broker_by_name(broker_name)).to be_nil
    end

    it 'purges all the services' do
      services = client.services
      plans = services.map(&:service_plans).flatten
      plans.each do |plan|
        plan.public = true
        plan.update!
      end

      si = client.managed_service_instance
      si.space = test_space
      si.service_plan = plans.first
      si.name = 'instance-for-deletion'
      si.create!

      instances = plans.map(&:service_instances).flatten

      expect(services).not_to be_empty
      expect(plans).not_to be_empty
      expect(instances).not_to be_empty

      puts `#{command}`

      expect(client.services).to be_empty
      expect(client.service_plans).to be_empty
      expect(client.service_instances).to be_empty
    end

    context 'and the broker does not exist' do
        it 'succeeds with a message the broker does not exist' do
          BlueShell::Runner.run command do |runner|
            runner.with_timeout(5) do
              expect(runner).to have_exit_code(0)
            end
          end

          BlueShell::Runner.run command do |runner|
            runner.with_timeout(5) do
              expect(runner).to say "Service Broker #{broker_name} does not exist."
              expect(runner).to have_exit_code(0)
            end
          end
        end
      end
  end

  def create_service_broker
    broker               = client.service_broker
    broker.name          = broker_name
    broker.broker_url    = broker_url
    broker.auth_username = broker_username
    broker.auth_password = broker_password

    broker.create!
    broker
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

  def create_organization(client)
    org      = client.organization
    org.name = 'test_broker_registrar-org'
    begin
      org.create!
    rescue CFoundry::OrganizationNameTaken
      org = client.organizations.find { |o| o.name == 'test_broker_registrar-org' }
    end
    org
  end

  def create_space(client, org)
    space              = client.space
    space.name         = 'test_broker_registrar-space'
    space.organization = org
    begin
      space.create!
    rescue CFoundry::SpaceNameTaken
      space = client.spaces.find { |s| s.name == 'test_broker_registrar-space' }
    end
    space
  end

  def find_service(name)
    client.services.find { |s| s.label == name }
  end
end

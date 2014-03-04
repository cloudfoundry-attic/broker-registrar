require 'blue-shell'
require 'cfoundry'

include BlueShell::Matchers

describe 'Broker Registrar command line app' do
  context 'does not receive all the parameters' do
    it 'returns a validation error' do
      BlueShell::Runner.run 'lib/broker-registrar register' do |runner|
        runner.with_timeout(1) do
          runner.should have_output 'Usage: --cf-address <URL> --cf-username <CF username> --cf-password <CF password> --broker-name <broker name> --broker-url <broker URL> --broker-username <broker username> --broker-password <broker password>'
          runner.should have_output 'missing argument: cf-address'
          runner.should have_exit_code(2)
        end
      end
    end
  end

  context 'does include all the parameters' do
    let(:cf_address) { 'https://api.10.244.0.34.xip.io' }
    let(:cf_username) { 'admin' }
    let(:cf_password) { 'admin' }
    let(:broker_name) { 'cassandra' }
    let(:broker_url) { 'http://10.244.3.70' }
    let(:broker_username) { 'mr_broker' }
    let(:broker_password) { 'broker123' }
    let(:client) { create_client }

    it 'returns a successful exit code' do
      command = %Q{lib/broker-registrar register --cf-address "#{cf_address}" --cf-username "#{cf_username}" --cf-password "#{cf_password}" --broker-name "#{broker_name}" --broker-url "#{broker_url}" --broker-username "#{broker_username}" --broker-password "#{broker_password}"}
      BlueShell::Runner.run command do |runner|
        runner.with_timeout(1) do
          runner.should have_exit_code(0)
        end
      end
    end

    context 'the environment is clean' do
      before do
        setup_environment(client)
      end

      after do
        broker = client.service_brokers.find { |sb| sb.name == broker_name }
        broker.delete! if broker
      end

      it 'registers the service broker with the cloud controller' do
        client = create_client
        setup_environment(client)
        expect(client.service_brokers.first).to be_nil

        command = %Q{lib/broker-registrar register --cf-address "#{cf_address}" --cf-username "#{cf_username}" --cf-password "#{cf_password}" --broker-name "#{broker_name}" --broker-url "#{broker_url}" --broker-username "#{broker_username}" --broker-password "#{broker_password}"}
        puts `#{command}`

        expect(client.service_brokers.first.name).to eq(broker_name)
      end
    end

    def create_client
      client = CFoundry::Client.get(cf_address)
      client.login(username: 'admin', password: 'admin')
      client
    end

    def setup_environment(client)
      client.current_organization = create_organization(client)
      client.current_space = create_space(client, client.current_organization)
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
      end
      space
    end

  end
end

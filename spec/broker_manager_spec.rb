require 'spec_helper'
require 'cfoundry'
require_relative '../lib/broker_manager'

describe BrokerManager, :vcr do
  before(:all) do
    @config = YAML.load_file('spec/config_defaults.yml')
  end

  before(:each) do
    # Avoid token expiry when using VCR to record Cloud Foundry API calls
    allow_any_instance_of(CFoundry::AuthToken).to receive(:expiration).and_return(Time.now + 100_000)
  end

  let(:client) do
    client = CFoundry::Client.get(@config['cloud_foundry']['url'])
    client.login(username: @config['cloud_foundry']['username'],
                 password: @config['cloud_foundry']['password'])
    client
  end

  let(:broker_name) { 'elasticsearch' }
  let(:broker_url) { @config['broker']['url'] }
  let(:new_url) { broker_url.gsub('registrar-broker-1', 'registrar-broker-2') }
  let(:broker_username) { @config['broker']['username'] }
  let(:broker_password) { @config['broker']['password'] }

  subject { BrokerManager.new(client, double('logger').as_null_object) }

  describe '#find_or_create_service_broker!' do
    context 'the requested service broker does not exist' do
      after do
        broker = client.service_broker_by_name(broker_name)
        broker.delete!
      end

      it 'creates a new service broker' do
        subject.find_or_create_service_broker!(broker_name, broker_url, broker_username, broker_password)

        broker = client.service_broker_by_name(broker_name)
        expect(broker.name).to eq(broker_name)
        expect(broker.broker_url).to eq(broker_url)
      end
    end

    context 'the requested service broker already exists' do
      before do
        broker = client.service_broker
        broker.name = broker_name
        broker.broker_url = broker_url
        broker.auth_username = broker_username
        broker.auth_password = broker_password
        broker.create!
      end

      after do
        client.service_broker_by_name(broker_name).delete!
      end

      it 'returns the existing service broker' do
        subject.find_or_create_service_broker!(broker_name, broker_url, broker_username, broker_password)

        broker = client.service_broker_by_name(broker_name)
        expect(broker.name).to eq(broker_name)
        expect(broker.broker_url).to eq(broker_url)
      end
    end

    context 'the requested service broker exists but with different details' do
      let(:broker) { client.service_broker }
      before do
        broker.name = broker_name
        broker.broker_url = broker_url
        broker.auth_username = broker_username
        broker.auth_password = broker_password
        broker.create!
      end

      after do
        client.service_broker_by_name(broker_name).delete!
      end

      it 'updates the url, username and password' do
        subject.find_or_create_service_broker!(broker_name, new_url, "admin2", "password2")
        updated_broker = client.service_broker_by_name(broker_name)
        expect(updated_broker.broker_url).to eq new_url
        expect(updated_broker.auth_username).to eq "admin2"
      end
    end

    context 'broker creation fails unexpectedly' do
      before do
        broker = double('broker').as_null_object
        expect(broker).to receive(:create!).and_raise(error)
        expect(client).to receive(:service_broker).and_return(broker)
      end

      context 'due to a general error' do
        let(:error) { StandardError.new }

        it 'raises the error' do
          expect do
            subject.find_or_create_service_broker!(broker_name, broker_url, broker_username, broker_password)
          end.to raise_error(error)
        end
      end

      context 'due to a Cloud Foundry error' do
        let(:error) { CFoundry::APIError.new }

        it 'raises the error' do
          expect do
            subject.find_or_create_service_broker!(broker_name, broker_url, broker_username, broker_password)
          end.to raise_error(error)
        end
      end
    end
  end
end

require 'spec_helper'
require 'cfoundry'
require_relative '../lib/broker_manager'

describe BrokerManager, :vcr do

  let(:client) do
    client = CFoundry::Client.get('https://api.10.244.0.34.xip.io')
    client.login(username: 'admin', password: 'admin')
    client
  end

  let(:broker_name) { 'elasticsearch' }
  let(:broker_url) { 'http://10.244.3.58' }
  let(:broker_username) { 'admin' }
  let(:broker_password) { 'admin' }

  subject { described_class.new(client) }

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
        broker               = client.service_broker
        broker.name          = broker_name
        broker.broker_url    = broker_url
        broker.auth_username = broker_username
        broker.auth_password = broker_password
        broker.create!
      end

      it 'returns the existing service broker' do
        subject.find_or_create_service_broker!(broker_name, broker_url, broker_username, broker_password)

        broker = client.service_broker_by_name(broker_name)
        expect(broker.name).to eq(broker_name)
        expect(broker.broker_url).to eq(broker_url)
      end

      context 'with different details' do
        before do
          requested_broker = double('requested_broker').as_null_object
          expect(requested_broker).to receive(:create!).and_raise(CFoundry::APIError.new(nil, 270_003))
          expect(client).to receive(:service_broker).and_return(requested_broker)
        end

        it 'updates the url, username and password' do
          returned_broker = double('returned_broker')
          expect(client).to receive(:service_broker_by_name).and_return(returned_broker)
          expect(returned_broker).to receive(:broker_url=).with("new_url")
          expect(returned_broker).to receive(:auth_username=).with("new_username")
          expect(returned_broker).to receive(:auth_password=).with("new_password")
          expect(returned_broker).to receive(:update!)

          subject.find_or_create_service_broker!(broker_name, "new_url", "new_username", "new_password")
        end
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

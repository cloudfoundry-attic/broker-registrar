require 'cfoundry'
require_relative 'broker_manager'

class BrokerRegistrar

  def initialize(logger)
    @logger = logger
  end

  def register(args)
    client = CFoundry::V2::Client.new(args[:cf_address])
    client.login(username: args[:cf_username], password: args[:cf_password])

    broker_manager = BrokerManager.new(client, logger)
    broker = broker_manager.find_or_create_service_broker!(args[:broker_name],
                                                           args[:broker_url],
                                                           args[:broker_username],
                                                           args[:broker_password])
    services = broker_manager.get_services_for_broker(broker.broker_url, args[:broker_username], args[:broker_password])
    broker_manager.make_services_plans_public(services)
  end

  def delete(args)
    client = CFoundry::V2::Client.new(args[:cf_address])
    client.login(username: args[:cf_username], password: args[:cf_password])

    broker_manager = BrokerManager.new(client, logger)
    services = broker_manager.get_services_for_broker(args[:broker_url], args[:broker_username], args[:broker_password])

    services.each do |service|
      service_name = service.label
      service.delete!(purge: true)
      logger.info "Purged service offering #{service_name}"
    end

    broker = client.service_broker_by_name(args[:broker_name])
    if broker
      broker.delete!
      logger.info "Deleted service broker #{args[:broker_name]}"
    else
      logger.info "Service Broker #{args[:broker_name]} does not exist."
    end
  end

  private

  attr_reader :logger
end

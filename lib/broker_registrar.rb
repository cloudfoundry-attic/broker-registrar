require 'cfoundry'
require_relative 'broker_manager'

class BrokerRegistrar

  def register(args)
    client = CFoundry::V2::Client.new(args[:cf_address])
    client.login(username: args[:cf_username], password: args[:cf_password])

    broker_manager = BrokerManager.new(client)
    broker = broker_manager.find_or_create_service_broker!(args[:broker_name],
                                                           args[:broker_url],
                                                           args[:broker_username],
                                                           args[:broker_password])
    services = broker_manager.get_services_for_broker(broker.broker_url, args[:broker_username], args[:broker_password])
    puts 'Found services for new broker: ' + services.map(&:label).join(', ')
    broker_manager.make_services_plans_public(services)
  end

end

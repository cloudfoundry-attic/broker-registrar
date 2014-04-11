class BrokerManager

  def initialize(client, logger)
    @client = client
    @logger = logger
  end

  def find_or_create_service_broker!(broker_name, broker_url, broker_username, broker_password)
    if broker = client.service_broker_by_name(broker_name)
      logger.info "Broker already exists. Updating..."
      update_service_broker(broker, broker_url, broker_username, broker_password)
      logger.info "Updated existing service broker [#{broker_name}]"
      return broker
    end

    broker               = client.service_broker
    broker.name          = broker_name
    broker.broker_url    = broker_url
    broker.auth_username = broker_username
    broker.auth_password = broker_password

    broker.create!
    logger.info "Registered service broker [#{broker.name}]"

    broker
  end

  def get_services_for_broker(broker_url, broker_username, broker_password)
    credentials = { username: broker_username, password: broker_password }
    response = HTTParty.get("#{broker_url}/v2/catalog", basic_auth: credentials)
    broker_provided_ids = extract_broker_provided_ids(response)
    client.services.find_all { |s| broker_provided_ids.include?(s.unique_id) }
  end

  def make_services_plans_public(services)
    services.each do |service|
      service.service_plans.each { |sp| make_service_plan_public(sp) }
    end
  end

  def make_service_plan_public(service_plan)
    if service_plan.public
      logger.info "Service plan [#{service_plan.name}] is already public"
    else
      service_plan.public = true
      service_plan.update!
      logger.info "Made service plan [#{service_plan.name}] public"
    end
  end

  private

  attr_reader :client, :logger

  def update_service_broker(broker, new_url, new_username, new_password)
    broker.broker_url = new_url
    broker.auth_username = new_username
    broker.auth_password = new_password
    broker.update!
  end

  def extract_broker_provided_ids(response)
    response['services'].map { |s| s['id'] }
  end
end

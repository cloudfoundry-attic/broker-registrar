class BrokerManager

  def initialize(client)
    @client = client
  end

  SERVICE_BROKER_NAME_IS_TAKEN = 270_002
  SERVICE_BROKER_URL_IS_TAKEN = 270_003

  def find_or_create_service_broker!(broker_name, broker_url, broker_username, broker_password)
    broker               = client.service_broker
    broker.name          = broker_name
    broker.broker_url    = broker_url
    broker.auth_username = broker_username
    broker.auth_password = broker_password
    puts "Adding service broker #{broker.name}"

    begin
      broker.create!
    rescue CFoundry::APIError => e
      case e.error_code
      when SERVICE_BROKER_NAME_IS_TAKEN, SERVICE_BROKER_URL_IS_TAKEN
        broker = client.service_broker_by_name(broker_name)
        update_service_broker(broker, broker_url, broker_username, broker_password)
      else
        raise e
      end
    end

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
    puts "Making service plan #{service_plan.name} public"
    service_plan.public = true
    service_plan.update!
  end

  private

  attr_reader :client

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

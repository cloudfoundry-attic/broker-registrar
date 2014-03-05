class BrokerManager

  def find_or_create_service_broker!(args, client)
    broker               = client.service_broker
    broker.name          = args[:broker_name]
    broker.broker_url    = args[:broker_url]
    broker.auth_username = args[:broker_username]
    broker.auth_password = args[:broker_password]
    puts "Adding service broker #{broker.name}"

    begin
      broker.create!
    rescue CFoundry::APIError => e
      if e.error_code == 270003
        broker = client.service_broker_by_name(args[:broker_name])
      else
        raise e
      end
    end

    broker
  end

  def get_services_for_broker(client, broker_url, broker_username, broker_password)
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

  def extract_broker_provided_ids(response)
    response['services'].map { |s| s['id'] }
  end

end

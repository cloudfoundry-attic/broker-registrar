require 'blue-shell'

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
    it 'returns a successful exit code' do
      command = 'lib/broker-registrar register --cf-address "http://api.cf.com" --cf-username "admin" --cf-password "password" --broker-name "cassandra" --broker-url "http://10.10.10.10" --broker-username "admin" --broker-password "admin"'
      BlueShell::Runner.run command do |runner|
        runner.with_timeout(100) do
          runner.should have_exit_code(0)
        end
      end
    end
  end
end
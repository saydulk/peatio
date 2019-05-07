module Ethereum1
  class Client
    Error = Class.new(StandardError)
    class ConnectionError < Error; end

    class ResponseError < Error
      def initialize(code, msg)
        @code = code
        @msg = msg
      end

      def message
        "#{@msg} (#{@code})"
      end
    end

    extend Memoist

    def initialize(endpoint)
      @json_rpc_endpoint = URI.parse(endpoint)
      @json_rpc_call_id  = 0
    end

    def json_rpc(method, params = [])
      response = connection.post \
        '/',
        { jsonrpc: '2.0', id: rpc_call_id,  method: method, params: params }.to_json,
        { 'Accept'       => 'application/json',
          'Content-Type' => 'application/json' }
      response.assert_success!
      response = JSON.parse(response.body)
      response['error'].tap { |error| raise ResponseError.new(error['code'], error['message']) if error }
      response.fetch('result')
    rescue Faraday::Error => e
      raise ConnectionError, e
    rescue => e
      raise Error, e
    end

    private

    def rpc_call_id
      @json_rpc_call_id += 1
    end

    def connection
      Faraday.new(@json_rpc_endpoint).tap do |connection|
        unless @json_rpc_endpoint.user.blank?
          connection.basic_auth(@json_rpc_endpoint.user, @json_rpc_endpoint.password)
        end
      end
    end
    memoize :connection
  end
end
# frozen_string_literal: true

module Multiwoven
  module Integrations
    module Destination
      module Http
        include Multiwoven::Integrations::Core
        class Client < DestinationConnector # rubocop:disable Metrics/ClassLength
          # prepend Multiwoven::Integrations::Core::RateLimiter
          MAX_CHUNK_SIZE = 10
          def check_connection(connection_config)
            connection_config = connection_config.with_indifferent_access
            destination_url = connection_config[:destination_url]
            request = Multiwoven::Integrations::Core::HttpClient.request(
              destination_url,
              HTTP_OPTIONS,
            )
            if success?(request)
              success_status
            else StandardError => e
              handle_exception("HTTP:CHECK_CONNECTION:EXCEPTION", "error", e)
              failure_status(nil)
            end
          rescue StandardError => e
            handle_exception("HTTP:CHECK_CONNECTION:EXCEPTION", "error", e)
            failure_status(e)
          end

          def write(sync_config, records, _action = "create")
            connection_config = sync_config.destination.connection_specification.with_indifferent_access
            connection_config = connection_config.with_indifferent_access
            url = connection_config[:destination_url]
            write_success = 0
            write_failure = 0
            records.each_slice(MAX_CHUNK_SIZE) do |chunk|
              payload = create_payload(chunk)
              response = Multiwoven::Integrations::Core::HttpClient.request(
                url,
                sync_config.stream.request_method,
                payload: payload,
              )
              if success?(response)
                write_success += chunk.size
              else
                write_failure += chunk.size
              end
            rescue StandardError => e
              handle_exception("HTTP:RECORD:WRITE:EXCEPTION", "error", e)
              write_failure += chunk.size
            end

            tracker = Multiwoven::Integrations::Protocol::TrackingMessage.new(
              success: write_success,
              failed: write_failure
            )
            byebug
            tracker.to_multiwoven_message
          rescue StandardError => e
            handle_exception("HTTP:WRITE:EXCEPTION", "error", e)
          end

          private

          def create_payload(records)
            {
              "records" => records.map do |record|
                {
                  "fields" => record
                }
              end
            }
          end

          def auth_headers(access_token)
            {
              "Accept" => "application/json",
              "Authorization" => "Bearer #{access_token}",
              "Content-Type" => "application/json"
            }
          end

          def extract_body(response)
            response_body = response.body
            JSON.parse(response_body) if response_body
          end
        end
      end
    end
  end
end

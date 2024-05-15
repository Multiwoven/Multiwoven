# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::SyncsController", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { workspace.workspace_users.first.user }
  let(:connectors) do
    [
      create(:connector, workspace:, connector_type: "destination", name: "klavio1", connector_name: "Klaviyo"),
      create(:connector, workspace:, connector_type: "source", name: "redshift", connector_name: "Redshift")
    ]
  end

  let(:model) do
     create(:model, connector: connectors.second, workspace:, name: "model1", query: "SELECT * FROM locations")
  end

  describe "POST /api/v1/syncs - Create sync" do
      let(:request_body) do
        {
          sync: {
            source_id: connectors.second.id,
            destination_id: connectors.first.id,
            model_id: "",
            schedule_type: "manual",
            configuration: {
              "test": "test"
            },
            sync_interval: 10,
            sync_interval_unit: "minutes",
            stream_name: "profile",
            sync_mode: "full_refresh",
            cursor_field: "created_date"
          }
        }
      end

      context "when stream name is not present" do
        it "creates a new sync and returns failure" do
          error_message = "Catalog is missing"
          post "/api/v1/syncs", params: request_body.to_json, headers: { "Content-Type": "application/json" }
            .merge(auth_headers(user))
          result = JSON.parse(response.body)
          expect(result["errors"][0]["source"]["catalog"]).to eq(error_message)
        end
      end
    end

  before do
      create(:catalog, connector: connectors.find { |connector| connector.name == "klavio1" }, workspace:)
      create(:catalog, connector: connectors.find { |connector| connector.name == "redshift" }, workspace:)
  end

  let!(:syncs) do
    [
      create(:sync, workspace:, model:, source: connectors.second, destination: connectors.first)
    ]
  end

  describe "GET /api/v1/syncs" do
    context "when it is an unauthenticated user" do
      it "returns unauthorized" do
        get "/api/v1/syncs"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when it is an authenticated user" do
      it "returns success and get all syncs " do
        get "/api/v1/syncs", headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        response_hash = JSON.parse(response.body).with_indifferent_access

        expect(response_hash[:data].count).to eql(syncs.count)
        expect(response_hash.dig(:data, 0, :type)).to eq("syncs")
        expect(response_hash[:data][0][:attributes][:model_id].present?).to be_truthy
        expect(response_hash[:data][0][:attributes][:model].present?).to be_truthy
        expect(response_hash[:data][0][:attributes][:model].keys).to include("id", "name", "description", "query",
                                                                             "query_type", "primary_key", "created_at",
                                                                             "updated_at", "connector")
        expect(response_hash.dig(:links, :first)).to include("http://www.example.com/api/v1/syncs?page=1")
      end
    end
  end

  describe "GET /api/v1/syncs/id" do
    context "when it is an unauthenticated user" do
      it "returns unauthorized" do
        get "/api/v1/syncs/#{syncs.first.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when it is an authenticated user" do
      it "returns success and fetch sync " do
        get "/api/v1/syncs/#{syncs.first.id}", headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        response_hash = JSON.parse(response.body).with_indifferent_access
        expect(response_hash.dig(:data, :id)).to be_present
        expect(response_hash.dig(:data, :id)).to eq(syncs.first.id.to_s)
        expect(response_hash.dig(:data, :type)).to eq("syncs")
        expect(response_hash.dig(:data, :attributes, :source_id)).to eq(syncs.first.source_id)
        expect(response_hash.dig(:data, :attributes, :destination_id)).to eq(syncs.first.destination_id)
        expect(response_hash.dig(:data, :attributes, :model_id)).to eq(syncs.first.model_id)
        expect(response_hash.dig(:data, :attributes, :configuration)).to eq(syncs.first.configuration)
        expect(response_hash.dig(:data, :attributes, :schedule_type)).to eq(syncs.first.schedule_type)
        expect(response_hash.dig(:data, :attributes, :sync_mode)).to eq(syncs.first.sync_mode)
        expect(response_hash.dig(:data, :attributes, :sync_interval)).to eq(syncs.first.sync_interval)
        expect(response_hash.dig(:data, :attributes, :sync_interval_unit)).to eq(syncs.first.sync_interval_unit)
        expect(response_hash.dig(:data, :attributes, :stream_name)).to eq(syncs.first.stream_name)
        expect(response_hash.dig(:data, :attributes, :status)).to eq(syncs.first.status)
      end

      it "returns an error response while fetch sync" do
        get "/api/v1/syncs/999", headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/syncs - Create sync" do
    let(:request_body) do
      {
        sync: {
          source_id: connectors.second.id,
          destination_id: connectors.first.id,
          model_id: model.id,
          schedule_type: "manual",
          configuration: {
            "test": "test"
          },
          sync_interval: 10,
          sync_interval_unit: "minutes",
          stream_name: "profile",
          sync_mode: "full_refresh",
          cursor_field: "created_date"
        }
      }
    end

    context "when it is an unauthenticated user for create sync" do
      it "returns unauthorized" do
        post "/api/v1/syncs"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when it is an authenticated user and create model" do
      it "creates a new sync and returns success" do
        post "/api/v1/syncs", params: request_body.to_json, headers: { "Content-Type": "application/json" }
          .merge(auth_headers(user))
        expect(response).to have_http_status(:created)
        response_hash = JSON.parse(response.body).with_indifferent_access
        expect(response_hash.dig(:data, :id)).to be_present
        expect(response_hash.dig(:data, :type)).to eq("syncs")
        expect(response_hash.dig(:data, :attributes, :source_id)).to eq(request_body.dig(:sync, :source_id))
        expect(response_hash.dig(:data, :attributes, :destination_id)).to eq(request_body.dig(:sync, :destination_id))
        expect(response_hash.dig(:data, :attributes, :model_id)).to eq(request_body.dig(:sync, :model_id))
        expect(response_hash.dig(:data, :attributes, :schedule_type)).to eq(request_body.dig(:sync, :schedule_type))
        expect(response_hash.dig(:data, :attributes, :stream_name)).to eq(request_body.dig(:sync, :stream_name))
        expect(response_hash.dig(:data, :attributes, :cursor_field)).to eq(request_body.dig(:sync, :cursor_field))
        expect(response_hash.dig(:data, :attributes, :current_cursor_field)).to eq(nil)
        expect(response_hash.dig(:data, :attributes, :sync_interval_unit))
          .to eq(nil)
        expect(response_hash.dig(:data, :attributes, :sync_interval))
          .to eq(nil)
        expect(response_hash.dig(:data, :attributes, :cron_expression))
          .to eq(nil)
        expect(response_hash.dig(:data, :attributes, :status)).to eq("pending")
      end

      it "creates a new sync and returns success with cursor_field nil " do
        request_body[:sync][:cursor_field] = nil
        post "/api/v1/syncs", params: request_body.to_json, headers: { "Content-Type": "application/json" }
          .merge(auth_headers(user))
        expect(response).to have_http_status(:created)
        response_hash = JSON.parse(response.body).with_indifferent_access
        expect(response_hash.dig(:data, :id)).to be_present
        expect(response_hash.dig(:data, :type)).to eq("syncs")
        expect(response_hash.dig(:data, :attributes, :source_id)).to eq(request_body.dig(:sync, :source_id))
        expect(response_hash.dig(:data, :attributes, :destination_id)).to eq(request_body.dig(:sync, :destination_id))
        expect(response_hash.dig(:data, :attributes, :model_id)).to eq(request_body.dig(:sync, :model_id))
        expect(response_hash.dig(:data, :attributes, :schedule_type)).to eq(request_body.dig(:sync, :schedule_type))
        expect(response_hash.dig(:data, :attributes, :stream_name)).to eq(request_body.dig(:sync, :stream_name))
        expect(response_hash.dig(:data, :attributes, :cursor_field)).to eq(nil)
        expect(response_hash.dig(:data, :attributes, :current_cursor_field)).to eq(nil)
        expect(response_hash.dig(:data, :attributes, :status)).to eq("pending")
      end

      it "returns an error response when creation fails" do
        request_body[:sync][:source_id] = "connector_id_wrong"
        post "/api/v1/syncs", params: request_body.to_json, headers: { "Content-Type": "application/json" }
          .merge(auth_headers(user))
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when stream name is not present" do
      it "creates a new sync and returns failure" do
        error_message = "Add a valid stream_name associated with destination connector"
        request_body[:sync][:stream_name] = "random"
        post "/api/v1/syncs", params: request_body.to_json, headers: { "Content-Type": "application/json" }
          .merge(auth_headers(user))
        result = JSON.parse(response.body)
        expect(result["errors"][0]["source"]["stream_name"]).to eq(error_message)
      end
    end

    context "when invalid schedule type" do
      it "creates a new sync and returns success" do
        error_message = ["invalid schedule type"]
        request_body[:sync][:schedule_type] = "autoamted"
        post "/api/v1/syncs", params: request_body.to_json, headers: { "Content-Type": "application/json" }
          .merge(auth_headers(user))
        result = JSON.parse(response.body)
        expect(result["errors"]["sync"]["schedule_type"]).to eq(error_message)
      end
    end
    context "when  schedule type is interval " do
      it "creates a new sync and returns success" do
        request_body[:sync][:schedule_type] = "interval"
        post "/api/v1/syncs", params: request_body.to_json, headers: { "Content-Type": "application/json" }
          .merge(auth_headers(user))
        expect(response).to have_http_status(:created)
        response_hash = JSON.parse(response.body).with_indifferent_access
        expect(response_hash.dig(:data, :attributes, :sync_interval)).to eq(request_body.dig(:sync, :sync_interval))
        expect(response_hash.dig(:data, :attributes,
                                 :sync_interval_unit)).to eq(request_body.dig(:sync, :sync_interval_unit))
      end

      context "when  schedule type is cron expression " do
        it "creates a new sync and returns success" do
          cron_expression = "0 0 */2 * *"
          request_body[:sync][:schedule_type] = "cron_expression"
          request_body[:sync][:cron_expression] = cron_expression
          post "/api/v1/syncs", params: request_body.to_json, headers: { "Content-Type": "application/json" }
            .merge(auth_headers(user))
          expect(response).to have_http_status(:created)
          response_hash = JSON.parse(response.body).with_indifferent_access
          expect(response_hash.dig(:data, :attributes, :cron_expression)).to eq(cron_expression)
          expect(response_hash.dig(:data, :attributes, :sync_interval)).to eq(nil)
          expect(response_hash.dig(:data, :attributes,
                                   :sync_interval_unit)).to eq(nil)
        end
      end
    end
  end

  describe "PUT /api/v1/syncs - Update sync" do
    let(:request_body) do
      {
        sync: {
          source_id: connectors.second.id,
          destination_id: connectors.first.id,
          model_id: model.id,
          schedule_type: "manual",
          configuration: {
            "test": "test"
          },
          sync_interval: 10,
          sync_interval_unit: "minutes",
          stream_name: "profile",
          cursor_field: "cursor_field"
        }
      }
    end

    context "when it is an unauthenticated user for update sync" do
      it "returns unauthorized" do
        put "/api/v1/syncs/#{syncs.first.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when it is an authenticated user and update sync" do
      it "updates the sync and returns success" do
        request_body[:sync][:sync_interval] = 30
        put "/api/v1/syncs/#{syncs.first.id}", params: request_body.to_json, headers:
          { "Content-Type": "application/json" }.merge(auth_headers(user))
        expect(response).to have_http_status(:ok)
        response_hash = JSON.parse(response.body).with_indifferent_access
        expect(response_hash.dig(:data, :id)).to be_present
        expect(response_hash.dig(:data, :id)).to eq(syncs.first.id.to_s)
        expect(response_hash.dig(:data, :attributes, :sync_interval)).to eq(nil)
        expect(response_hash.dig(:data, :attributes, :sync_interval_unit)).to eq(nil)
        expect(response_hash.dig(:data, :attributes, :cron_expression)).to eq(nil)
        expect(response_hash.dig(:data, :attributes, :cursor_field)).to eq(nil)
        expect(response_hash.dig(:data, :attributes, :current_cursor_field)).to eq(nil)
      end

      it "returns an error response when wrong sync_id" do
        put "/api/v1/syncs/99", params: request_body.to_json, headers:
          { "Content-Type": "application/json" }.merge(auth_headers(user))
        expect(response).to have_http_status(:not_found)
      end

      it "returns an error response when update fails" do
        request_body[:sync][:source_id] = "connector_id_wrong"
        put "/api/v1/syncs/#{syncs.first.id}", params: request_body.to_json, headers:
          { "Content-Type": "application/json" }.merge(auth_headers(user))
        expect(response).to have_http_status(:bad_request)
      end
    end
    context "when invalid schedule type" do
      it "creates a new sync and returns success" do
        error_message = ["invalid schedule type"]
        request_body[:sync][:schedule_type] = "autoamted"
        put "/api/v1/syncs/#{syncs.first.id}", params: request_body.to_json, headers:
        { "Content-Type": "application/json" }.merge(auth_headers(user))
        result = JSON.parse(response.body)
        expect(result["errors"]["sync"]["schedule_type"]).to eq(error_message)
      end
    end
    context "when  schedule type is interval " do
      it "creates a new sync and returns success" do
        request_body[:sync][:schedule_type] = "interval"
        put "/api/v1/syncs/#{syncs.first.id}", params: request_body.to_json, headers:
          { "Content-Type": "application/json" }.merge(auth_headers(user))
        expect(response).to have_http_status(:ok)

        response_hash = JSON.parse(response.body).with_indifferent_access
        expect(response_hash.dig(:data, :attributes, :sync_interval)).to eq(request_body.dig(:sync, :sync_interval))
        expect(response_hash.dig(:data, :attributes,
                                 :sync_interval_unit)).to eq(request_body.dig(:sync, :sync_interval_unit))
      end

      context "when  schedule type is cron expression " do
        it "creates a new sync and returns success" do
          cron_expression = "0 0 */2 * *"
          request_body[:sync][:schedule_type] = "cron_expression"
          request_body[:sync][:cron_expression] = cron_expression
          put "/api/v1/syncs/#{syncs.first.id}", params: request_body.to_json, headers:
            { "Content-Type": "application/json" }.merge(auth_headers(user))
          expect(response).to have_http_status(:ok)
          response_hash = JSON.parse(response.body).with_indifferent_access
          expect(response_hash.dig(:data, :attributes, :cron_expression)).to eq(cron_expression)
          expect(response_hash.dig(:data, :attributes, :sync_interval)).to eq(nil)
          expect(response_hash.dig(:data, :attributes,
                                   :sync_interval_unit)).to eq(nil)
        end
      end
    end
  end

  describe "DELETE /api/v1/syncs/id" do
    context "when it is an unauthenticated user" do
      it "returns unauthorized" do
        delete "/api/v1/syncs/#{syncs.first.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when it is an authenticated user" do
      it "returns success and delete sync" do
        delete "/api/v1/syncs/#{syncs.first.id}", headers: auth_headers(user)
        expect(response).to have_http_status(:no_content)
      end

      it "returns an error response while delete wrong sync" do
        delete "/api/v1/syncs/999", headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "#configurations" do
    it "returns the configurations" do
      get "/api/v1/syncs/configurations", headers: auth_headers(user)

      result = JSON.parse(response.body).with_indifferent_access
      expect(result[:data].keys.last).to eq("configurations")
    end
  end
end

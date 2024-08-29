# frozen_string_literal: true

module Api
  module V1
    class ModelsController < ApplicationController
      include Models
      attr_reader :connector, :model

      before_action :set_connector, only: %i[create]
      before_action :set_model, only: %i[show update destroy]
      before_action :validate_catalog, only: %i[create update]
      # TODO: Enable this once we have query validation implemented for all the connectors
      # before_action :validate_query, only: %i[create update]
      after_action :event_logger

      def index
        filter = params[:query_type] || "all"
        @models = current_workspace
                  .models.send(filter).page(params[:page] || 1)
        authorize @models
        render json: @models, status: :ok
      end

      def show
        authorize @model
        render json: @model, status: :ok
      end

      def create
        authorize current_workspace, policy_class: ModelPolicy
        result = CreateModel.call(
          connector:,
          model_params:
        )
        if result.success?
          @model = result.model
          render json: @model, status: :created
        else
          render_error(
            message: "Model creation failed",
            status: :unprocessable_entity,
            details: format_errors(result.model)
          )
        end
      end

      def update
        authorize model
        result = UpdateModel.call(
          model:,
          model_params:
        )

        if result.success?
          @model = result.model
          render json: @model, status: :ok
        else
          render_error(
            message: "Model update failed",
            status: :unprocessable_entity,
            details: format_errors(result.model)
          )
        end
      end

      def destroy
        authorize model
        model.destroy!
        head :no_content
      end

      private

      def set_connector
        @connector = current_workspace.connectors.find(model_params[:connector_id])
      end

      def set_model
        @model = current_workspace.models.find(params[:id])
        @connector = @model.connector
      end

      def validate_catalog
        return if connector.catalog.present?

        render_error(
          message: "Catalog is not present for the connector",
          status: :unprocessable_entity
        )
      end

      def validate_query
        query = params.dig(:model, :query)
        return if query.blank?

        query_type = @model.present? ? @model.connector.connector_query_type : @connector.connector_query_type
        Utils::QueryValidator.validate_query(query_type, query)
      rescue StandardError => e
        render_error(
          message: "Query validation failed: #{e.message}",
          status: :unprocessable_entity
        )
      end

      def model_params
        params.require(:model).permit(
          :connector_id,
          :name,
          :description,
          :query,
          :query_type,
          :primary_key,
          configuration: {}
        ).merge(
          workspace_id: current_workspace.id
        )
      end
    end
  end
end

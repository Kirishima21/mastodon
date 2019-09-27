# frozen_string_literal: true

class Api::V1::AppsController < Api::BaseController
  def create
    
    option = application_options

    if option[:name].downcase.include?("tootdon")
      render json: {},status: 403
    else
      @app = Doorkeeper::Application.create!(application_options)
      render json: @app, serializer: REST::ApplicationSerializer
    end

  end

  private

  def application_options
    {
      name: app_params[:client_name],
      redirect_uri: app_params[:redirect_uris],
      scopes: app_scopes_or_default,
      website: app_params[:website],
    }
  end

  def app_scopes_or_default
    app_params[:scopes] || Doorkeeper.configuration.default_scopes
  end

  def app_params
    params.permit(:client_name, :redirect_uris, :scopes, :website)
  end
end

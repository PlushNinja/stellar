#encoding: utf-8

class Admin::ActivitiesController < ApplicationController

  before_action :authenticate_user!
  before_action :set_activity, only: [:show]

  layout 'admin'

  # GET /activities
  # GET /activities.json
  def index
    authorize_action_for Activity, at: current_store
    query = saved_search_query('activity', 'admin_activity_search')
    @search = ActivitySearch.new(query.merge(search_params))
    @activities = @search.results.page(params[:page])
  end

  # GET /activities/1
  # GET /activities/1.json
  def show
    authorize_action_for Activity, at: current_store
  end

  # GET /activities/context
  def context
    @resource = GlobalID::Locator.locate(params[:gid])
    @context = @resource.activities.page(params[:context_page])

    respond_to :js
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_activity
      @activity = Activity.find(params[:id])
    end

    # Restrict searching to activities in current store.
    def search_params
      {
        store: current_store
      }
    end
end

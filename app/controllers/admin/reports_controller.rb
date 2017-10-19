#encoding: utf-8

class Admin::ReportsController < ApplicationController

  before_action :authenticate_user!
  before_action :set_variant, only: [:sales, :purchases]

  layout 'admin'

  # GET /admin/reports
  def index
  end

  # GET /admin/reports/inventory
  def inventory
    @search = InventoryItemSearch.new(inventory_params)

    respond_to do |format|
      format.html
      format.json {
        @inventory = Reports::Inventory.new(@search)
      }
    end
  end

  # GET /admin/reports/sales
  def sales
    @order_types = current_group.incoming_order_types
    return render nothing: true, status: :bad_request if @order_types.empty?
    @query = saved_search_query('order_report_row', 'admin_order_report_row_search')
    @query.reverse_merge!('order_type_id' => @order_types.first.id)

    respond_to do |format|
      format.html {
        @search = OrderReportRowSearch.new(@query)
      }
      format.js
      format.json {
        search = OrderReportRowSearch.new(
          @query.merge(view_params).merge(tabular_params)
        )
        @sales = Reports::Sales.new(search)
      }
    end
  end

  # GET /admin/reports/purchases
  def purchases
    @order_types = current_group.outgoing_order_types
    return render nothing: true, status: :bad_request if @order_types.empty?
    @query = saved_search_query('order_report_row', 'admin_order_report_row_search')
    @query.reverse_merge!('order_type_id' => @order_types.first.id)

    respond_to do |format|
      format.html {
        @search = OrderReportRowSearch.new(@query)
      }
      format.js
      format.json {
        search = OrderReportRowSearch.new(
          @query.merge(view_params).merge(tabular_params)
        )
        @purchases = Reports::Sales.new(search)
      }
    end
  end

  private
    # Chart views can be requested as variants.
    def set_variant
      request.variant = :chart if params[:variant] == 'chart'
    end

    def inventory_params
      {store: current_store.id}.merge(tabular_params)
    end

    # Params specifying a view but not saved with the search query.
    def view_params
      params.fetch(:view_params) {{}}
    end

    # Params specific to the inherent controls tabular provides.
    def tabular_params
      sort = params[:sort].presence || {name: 'product_title', dir: 'asc'}
      search = params[:q]
      {
        sort: "#{sort[:name]} #{sort[:dir]}",
        keyword: search
      }
    end
end

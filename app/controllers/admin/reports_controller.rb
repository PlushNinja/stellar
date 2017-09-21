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
    @order_types = current_user.incoming_order_types
    return render nothing: true, status: :bad_request if @order_types.empty?
    @query = saved_search_query('order_report_row', 'admin_order_report_row_search')
    @search = OrderReportRowSearch.new(order_report_params)
    @sales = Reports::Sales.new(@search)

    respond_to :html, :js, :json
  end

  # GET /admin/reports/purchases
  def purchases
    @order_types = current_user.outgoing_order_types
    return render nothing: true, status: :bad_request if @order_types.empty?
    @query = saved_search_query('order_report_row', 'admin_order_report_row_search')
    @search = OrderReportRowSearch.new(order_report_params)
    @purchases = Reports::Sales.new(@search)

    respond_to :html, :js, :json
  end

  private
    # Chart views can be requested as variants.
    def set_variant
      request.variant = :chart if params[:variant] == 'chart'
    end

    def order_report_params
      @query.reverse_merge({
        'order_type_id' => @order_types.first.id
      }).merge(tabular_params)
    end

    def inventory_params
      {store: current_store.id}.merge(tabular_params)
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

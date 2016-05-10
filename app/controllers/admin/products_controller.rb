#encoding: utf-8

class Admin::ProductsController < ApplicationController

  include Reorderer
  before_action :authenticate_user!
  authority_actions query: 'read', reorder: 'update'

  layout 'admin'

  authorize_actions_for Product
  before_action :set_product,  only: [:show, :edit, :update, :destroy]

  # GET /admin/products
  # GET /admin/products.json
  def index
    @query = saved_search_query('product', 'admin_product_search')
    @search = ProductSearch.new(search_params)
    @products = @search.results.page(params[:page])
  end

  # GET /admin/products/query.json?q=keyword
  # This method serves selectize widgets populated via Ajax.
  def query
    @query = {keyword: params[:q], live: true}
    @search = ProductSearch.new(search_params)
    @products = @search.results
  end

  # GET /admin/products/1
  # GET /admin/products/1.json
  def show
  end

  # GET /admin/products/new
  def new
    @product = current_store.products.build(available_at: Date.current)
  end

  # GET /admin/products/1/edit
  def edit
  end

  # POST /admin/products
  # POST /admin/products.json
  def create
    @product = current_store.products.build(product_params)

    respond_to do |format|
      if @product.save
        format.html { redirect_to edit_admin_product_path(@product),
          notice: t('.notice', product: @product) }
        format.json { render :show, status: :created, location: admin_product_path(@product) }
      else
        format.html { render :new }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/products/1
  # PATCH/PUT /admin/products/1.json
  def update
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to admin_product_path(@product),
          notice: t('.notice', product: @product) }
        format.json { render :show, status: :ok, location: admin_product_path(@product) }
      else
        format.html { render :edit }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = current_store.products.friendly.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def product_params
      params.require(:product).permit(
        :compound, :virtual, :code, :customer_code, :title, :subtitle,
        :description, :memo, :mass, :dimension_u, :dimension_v, :dimension_w,
        :cost_price, :trade_price, :retail_price,
        :available_at, :deleted_at, category_ids: [], linked_product_ids: []
      )
    end

    # Restrict searching to products in current store.
    def search_params
      @query.merge(store_id: current_store.id)
    end
end

#encoding: utf-8

class Admin::ProductsController < ApplicationController

  include Reorderer
  before_action :authenticate_user!
  authority_actions reorder: 'update'

  layout 'admin'

  authorize_actions_for Product
  before_action :set_product,  only: [:show, :edit, :update, :destroy]
  before_action :set_point,    only: [:show, :edit]

  # GET /admin/products
  # GET /admin/products.json
  def index
    @categories = current_store.categories.ordered
    @categorized = current_store.products.categorized.ordered
    @uncategorized = current_store.products.uncategorized.ordered
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
        format.html { redirect_to admin_product_path(@product),
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
      @product = current_store.products.ordered.find(params[:id])
    end

    def set_point
      @point = if @product.category.present?
        @product.category.products.ordered_at(@product)
      else
        current_store.products.uncategorized.ordered_at(@product)
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def product_params
      params.require(:product).permit(
        :category_id, :virtual, :code, :customer_code, :title, :subtitle,
        :description, :memo, :sales_price,
        :available_at, :deleted_at
      )
    end
end

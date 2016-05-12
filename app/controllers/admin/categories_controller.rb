#encoding: utf-8

class Admin::CategoriesController < ApplicationController

  include Reorderer
  before_action :authenticate_user!
  authority_actions reorder: 'update', reorder_products: 'update'

  layout 'admin'

  authorize_actions_for Category
  before_action :set_category, only: [:show, :edit, :update, :destroy, :reorder_products]

  # GET /admin/categories
  # GET /admin/categories.json
  def index
    @categories = current_store.categories.sorted
  end

  # GET /admin/categories/1
  # GET /admin/categories/1.json
  def show
  end

  # GET /admin/categories/new
  def new
    @category = current_store.categories.build
  end

  # GET /admin/categories/1/edit
  def edit
  end

  # POST /admin/categories
  # POST /admin/categories.json
  def create
    @category = current_store.categories.build(category_params)

    respond_to do |format|
      if @category.save
        format.html { redirect_to edit_admin_category_path(@category),
          notice: t('.notice', category: @category) }
        format.json { render :show, status: :created, location: admin_category_path(@category) }
      else
        format.html { render :new }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/categories/1
  # PATCH/PUT /admin/categories/1.json
  def update
    respond_to do |format|
      if @category.update(category_params)
        format.html { redirect_to admin_category_path(@category),
          notice: t('.notice', category: @category) }
        format.json { render :show, status: :ok, location: admin_category_path(@category) }
      else
        format.html { render :edit }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/categories/1
  # DELETE /admin/categories/1.json
  def destroy
    @category.destroy
    respond_to do |format|
      format.html { redirect_to admin_categories_path,
        notice: t('.notice', category: @category) }
      format.json { head :no_content }
    end
  end

  # GET /admin/categories/1/reorder_products
  def reorder_products
    @products = @category.products.live.sorted(@category.product_scope)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_category
      @category = current_store.categories.friendly.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def category_params
      params.require(:category).permit(
        :parent_category_id, :banner_id, :live, :name, :product_scope
      )
    end
end

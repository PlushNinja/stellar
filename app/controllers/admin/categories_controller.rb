#encoding: utf-8

class Admin::CategoriesController < ApplicationController

  include AwesomeNester
  before_action :authenticate_user!
  before_action :set_category, only: [:show, :edit, :update, :destroy, :reorder_products]

  authority_actions rearrange: 'update', reorder_products: 'update'
  authorize_actions_for Category, except: [:destroy]

  layout 'admin'

  # GET /admin/categories
  # GET /admin/categories.json
  def index
    @categories = current_store.categories.roots
  end

  # GET /admin/categories/1
  def show
    redirect_to edit_admin_category_path(@category)
  end

  # GET /admin/categories/new.js
  def new
    @category = current_store.categories.build
  end

  # GET /admin/categories/1/edit
  # GET /admin/categories/1/edit.js
  def edit
    @categories = current_store.categories.roots

    respond_to :html, :js
  end

  # POST /admin/categories
  # POST /admin/categories.js
  # POST /admin/categories.json
  def create
    @category = current_store.categories.build(category_params)

    respond_to do |format|
      if @category.save
        format.html { redirect_to edit_admin_category_path(@category), notice: t('.notice', category: @category) }
        format.js { flash.now[:notice] = t('.notice', category: @category) }
        format.json { render :edit, status: :created, location: edit_admin_category_path(@category) }
      else
        format.html { render :new }
        format.js { render json: @category.errors, status: :unprocessable_entity }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/categories/1
  # PATCH/PUT /admin/categories/1.js
  # PATCH/PUT /admin/categories/1.json
  def update
    respond_to do |format|
      if @category.update(category_params)
        @categories = current_store.categories.roots

        format.html { redirect_to admin_category_path(@category), notice: t('.notice', category: @category) }
        format.js { flash.now[:notice] = t('.notice', category: @category) }
        format.json { render :show, status: :ok, location: admin_category_path(@category) }
      else
        format.html { render :edit }
        format.js { render json: @category.errors, status: :unprocessable_entity }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/categories/1
  # DELETE /admin/categories/1.json
  def destroy
    authorize_action_for @category
    @category.destroy

    respond_to do |format|
      format.html { redirect_to admin_categories_path,
        notice: t('.notice', category: @category) }
      format.json { head :no_content }
    end
  end

  # GET /admin/categories/1/reorder_products
  def reorder_products
    @products = @category.products.visible.sorted(@category.product_scope)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_category
      @category = current_store.categories.friendly.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def category_params
      params.require(:category).permit(
        :live, :name, :subtitle, :product_scope
      )
    end
end

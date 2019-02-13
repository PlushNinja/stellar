class Pos::ProductsController < ApplicationController

  before_action :authenticate_user!
  before_action :set_product,  only: [:show]

  layout 'point_of_sale'

  # GET /pos/products/1
  # This method supplies product data JSON for UI widgets.
  def show
  end

  # GET /pos/products/query.json?q=keyword
  # This method serves selectize widgets populated via Ajax.
  def query
    query = {'keyword' => params[:q], 'having_variants' => params[:having_variants], live: true}.merge(params)
    @search = ProductSearch.new(query.merge(search_params))
    @products = @search.results
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = current_store.products.friendly.find(params[:id])
    end

    # Restrict searching to products in current store.
    def search_params
      {store: current_store}.tap do |params|
        params.merge!(vendor_id: current_group) if third_party?
        params.merge!(permitted_categories: current_group.available_categories) if current_group.limited_categories?
      end
    end
end

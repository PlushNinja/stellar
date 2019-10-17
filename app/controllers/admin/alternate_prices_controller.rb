class Admin::AlternatePricesController < AdminController

  before_action :set_product
  before_action :set_alternate_price, only: [:update, :destroy]

  # POST /admin/products/1/alternate_prices
  def create
    @group = current_store.groups.find(params[:alternate_price][:group_id])
    @appraiser = Appraiser::Product.new(@group)
    @alternate_price = @product.alternate_prices.find_or_initialize_by(
      group: @group
    )
    @alternate_price.assign_attributes(alternate_price_params)

    respond_to do |format|
      if @alternate_price.save
        track @alternate_price, @product
        format.js { render :create }
      else
        format.js { render :error }
      end
    end
  end

  # PATCH/PUT /admin/products/1/alternate_prices/2
  def update
    @group = @alternate_price.group
    @appraiser = Appraiser::Product.new(@group)
    @alternate_price.assign_attributes(alternate_price_params)

    respond_to do |format|
      if @alternate_price.price.zero?
        @alternate_price.destroy
        track @alternate_price, @product
        format.js { render :update }
      elsif @alternate_price.save
        track @alternate_price, @product
        format.js { render :update }
      else
        format.js { render :error }
      end
    end
  end

  # DELETE /admin/products/1/alternate_prices/2
  def destroy
    track @alternate_price, @product
    @alternate_price.destroy

    respond_to :js
  end

  private

  def set_product
    @product = current_store.products.friendly.find(params[:product_id])
  end

  def set_alternate_price
    @alternate_price = @product.alternate_prices.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def alternate_price_params
    params.require(:alternate_price).permit(
      :group_id, :price
    )
  end
end

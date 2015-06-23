#encoding: utf-8

class Admin::ImagesController < ApplicationController
  before_action :set_product, only: [:new, :create]

  # GET /admin/products/1/images/new
  def new
    @image = @product.images.build
  end

  # POST /admin/products/1/images
  def create
    @image = @product.images.build(image_params)

    respond_to do |format|
      if @image.save
        format.json { render json: {message: 'success'}, status: 200 }
      else
        format.json { render json: {error: @image.errors.full_messages.join(', ')}, status: 400 }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = Product.find(params[:product_id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def image_params
      params.require(:image).permit(
        :image_type_id, :attachment
      )
    end
end

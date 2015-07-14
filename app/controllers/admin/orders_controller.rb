#encoding: utf-8

class Admin::OrdersController < ApplicationController

  layout 'admin'

  authorize_actions_for Order
  before_action :set_order, only: [:show, :edit, :update, :destroy]

  # GET /admin/orders
  # GET /admin/orders.json
  def index
    @orders = current_store.orders
    @approved = current_store.orders.approved
  end

  # GET /admin/orders/1
  # GET /admin/orders/1.json
  def show
  end

  # GET /admin/orders/new
  def new
    @order = current_store.orders.build(ordered_at: Time.current)
  end

  # GET /admin/orders/1/edit
  def edit
  end

  # POST /admin/orders
  # POST /admin/orders.json
  def create
    @order = current_store.orders.build(order_params)

    respond_to do |format|
      if @order.save
        format.html { redirect_to admin_order_path(@order), notice: 'Order was successfully created.' }
        format.json { render :show, status: :created, location: admin_order_path(@order) }
      else
        format.html { render :new }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/orders/1
  # PATCH/PUT /admin/orders/1.json
  def update
    respond_to do |format|
      if @order.update(order_params)
        format.html { redirect_to admin_orders_path, notice: 'Order was successfully updated.' }
        format.json { render :index, status: :ok, location: admin_orders_path }
      else
        format.html { render :edit }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_order
      @order = Order.unscoped.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def order_params
      params.require(:order).permit(
        :user_id, :order_type_id, :ordered_at, :shipping_at, :approval,
        :company_name, :contact_person, :billing_address, :shipping_address,
        :notes
      )
    end
end

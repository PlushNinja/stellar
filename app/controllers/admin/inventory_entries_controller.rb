class Admin::InventoryEntriesController < AdminController

  before_action :set_inventory_item, only: [:create]

  # POST /admin/inventory_items/1/inventory_entries
  def create
    authorize_action_for InventoryEntry, at: current_store
    @inventory_entry = @inventory_item.inventory_entries.build(inventory_entry_params)
    @inventory_entry.source ||= current_user

    respond_to do |format|
      if @inventory_entry.save
        track @inventory_entry, @inventory_item.product
        @inventory_item.reload
        format.js { render :create }
      else
        format.json { render json: @inventory_entry.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    def set_inventory_item
      @inventory_item = current_store.inventory_items.find(params[:inventory_item_id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def inventory_entry_params
      params.require(:inventory_entry).permit(
        :recorded_at, :on_hand, :reserved, :pending, :value, :note
      )
    end
end

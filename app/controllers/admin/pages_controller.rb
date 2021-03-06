class Admin::PagesController < AdminController

  include AwesomeNester

  before_action :set_page, only: [:edit, :update, :destroy, :layout, :duplicate]

  authority_actions rearrange: 'update', layout: 'update', duplicate: 'create'

  # GET /admin/pages
  # GET /admin/pages.json
  def index
    authorize_action_for Page, at: current_store
    @pages = current_store.pages.roots
  end

  # GET /admin/pages/new.js
  def new
    authorize_action_for Page, at: current_store
    @page = current_store.pages.build
  end

  # GET /admin/pages/1/edit
  # GET /admin/pages/1/edit.js
  def edit
    authorize_action_for @page, at: current_store

    respond_to do |format|
      format.html {
        @pages = current_store.pages.roots
        render 'index'
      }
      format.js
    end
  end

  # POST /admin/pages
  # POST /admin/pages.json
  def create
    authorize_action_for Page, at: current_store
    @page = current_store.pages.build(page_params)
    @page.slug = 'front' if @page.route?

    respond_to do |format|
      if @page.save
        track @page

        format.html { redirect_to edit_admin_page_path(@page), notice: t('.notice', page: @page) }
        format.json { render :edit, status: :created, location: edit_admin_page_path(@page) }
      else
        format.html { render :new }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/pages/1
  # PATCH/PUT /admin/pages/1.js
  # PATCH/PUT /admin/pages/1.json
  def update
    authorize_action_for @page, at: current_store

    respond_to do |format|
      if @page.update(page_params)
        track @page

        format.html { redirect_to edit_admin_page_path(@page), notice: t('.notice', page: @page) }
        format.js { flash.now[:notice] = t('.notice', page: @page) }
        format.json { render :edit, status: :ok, location: edit_admin_page_path(@page) }
      else
        format.html { render :edit }
        format.js { render :rollback }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/pages/1
  # DELETE /admin/pages/1.json
  def destroy
    authorize_action_for @page, at: current_store
    track @page
    @page.destroy

    respond_to do |format|
      format.html { redirect_to admin_pages_path,
        notice: t('.notice', page: @page) }
      format.json { head :no_content }
    end
  end

  # GET /admin/pages/1/layout
  def layout
    authorize_action_for @page, at: current_store

    render layout: 'layout_editor'
  end

  # POST /admin/pages/1/duplicate
  def duplicate
    authorize_action_for Page, at: current_store
    original = @page
    @page = original.duplicate!
    @page.save_inline_styles_recursively
    track @page, nil, {action: 'create'}

    redirect_to edit_admin_page_path(@page), notice: t('.notice', page: original)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_page
    @page = current_store.pages.friendly.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def page_params
    params.require(:page).permit(
      :parent_id, :purpose, :resource_type, :resource_id,
      :live, :title, :slug, :url, :description,
      :always_expand, :dynamic_navbar, group_ids: []
    )
  end
end

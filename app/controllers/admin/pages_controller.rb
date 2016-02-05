#encoding: utf-8

class Admin::PagesController < ApplicationController

  include Reorderer
  before_action :authenticate_user!
  authority_actions reorder: 'update'

  layout 'admin'

  authorize_actions_for Page, except: [:edit, :update, :destroy]
  before_action :set_page, only: [:show, :edit, :update, :destroy]

  # GET /admin/pages
  # GET /admin/pages.json
  def index
    @pages = current_store.pages.sorted
  end

  # GET /admin/pages/new
  def new
    @page = current_store.pages.build
  end

  # GET /admin/pages/1/edit
  def edit
    authorize_action_for @page
  end

  # POST /admin/pages
  # POST /admin/pages.json
  def create
    @page = current_store.pages.build(page_params)

    respond_to do |format|
      if @page.save
        format.html { redirect_to edit_admin_page_path(@page),
          notice: t('.notice', page: @page) }
        format.json { render :edit, status: :created, location: edit_admin_page_path(@page) }
      else
        format.html { render :new }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/pages/1
  # PATCH/PUT /admin/pages/1.json
  def update
    authorize_action_for @page

    respond_to do |format|
      if @page.update(page_params)
        format.html { redirect_to edit_admin_page_path(@page),
          notice: t('.notice', page: @page) }
        format.json { render :edit, status: :ok, location: edit_admin_page_path(@page) }
      else
        format.html { render :edit }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/pages/1
  # DELETE /admin/pages/1.json
  def destroy
    authorize_action_for @page
    @page.destroy

    respond_to do |format|
      format.html { redirect_to admin_pages_path,
        notice: t('.notice', page: @page) }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_page
      @page = Page.friendly.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def page_params
      params.require(:page).permit(
        :store_id, :parent_page_id, :navbar, :title, :slug, :content,
        :letterhead, :internal, :wysiwyg, album_ids: []
      )
    end
end

class Comfy::Admin::Cms::PagesController < Comfy::Admin::Cms::BaseController
  before_action :check_for_layouts, :only => [:new, :edit]
  before_action :build_cms_page,    :only => [:new, :create]
  before_action :load_cms_page,     :only => [:edit, :update, :destroy]
  before_action :load_locale_page,  :only => [:update_locale]
  before_action :build_cms_locale_page, only: [:create_locale, :update_locale]
  before_action :authorize
  before_action :preview_cms_page,  :only => [:create, :update]

  def index
    return redirect_to :action => :new if site_has_no_pages?

    return index_for_redactor if params[:source] == 'redactor'

    @pages_by_parent = pages_grouped_by_parent

    if params[:category].present?
      @pages = @site.pages.includes(:categories).for_category(params[:category]).order('label')
    else
      @pages = [@site.pages.root].compact
    end
  end

  def new
    render
  end

  def new_locale_page
    @current_page = @site.pages.find(params[:id])
    @locale_page = @current_page.locale_pages.new(page_params)
    @locale_page.layout ||= @site.layouts.first
    render
  end

  def locale_pages
    @current_page = @site.pages.find(params[:id])
    @locale_pages = @current_page.locale_pages
    render
  end

  def edit_locale
    @current_page = @site.pages.find(params[:page_id])
    @locale_page = @current_page.locale_pages.find(params[:id])
    render
  end

  def edit

    render
  end

  def create
    @page.save!
    flash[:success] = I18n.t('comfy.admin.cms.pages.created')
    redirect_to :action => :edit, :id => @page
  rescue ActiveRecord::RecordInvalid
    flash.now[:danger] = I18n.t('comfy.admin.cms.pages.creation_failure')
    render :action => :new
  end

  def create_locale
    if @page.save
      block = @page.blocks.new(blocks_params["blocks_attributes"]["0"])
      block.save
      flash[:success] = I18n.t('comfy.admin.cms.pages.created')
      redirect_to comfy_admin_cms_site_pages_path(site_id: @page.page.site_id)
    else
      flash[:notice] = @page.errors.full_messages.first

      redirect_to new_locale_page_comfy_admin_cms_site_page_path(id: @page.page_id)
    end
  end

  def update_locale
    if @locale_page.save
      block = @locale_page.blocks.first
      block.attributes = blocks_params["blocks_attributes"]["0"]
      block.save
      flash[:success] = "Page updated"
      redirect_to locale_pages_comfy_admin_cms_site_page_path(site_id: @locale_page.page.site_id)
    else
      flash[:notice] = @page.errors.full_messages.first

      redirect_to new_locale_page_comfy_admin_cms_site_page_path(id: @page.page_id)
    end

  end

  def update
    @page.save!
    flash[:success] = I18n.t('comfy.admin.cms.pages.updated')
    redirect_to :action => :edit, :id => @page
  rescue ActiveRecord::RecordInvalid
    flash.now[:danger] = I18n.t('comfy.admin.cms.pages.update_failure')
    render :action => :edit
  end

  def destroy
    @page.destroy
    flash[:success] = I18n.t('comfy.admin.cms.pages.deleted')
    redirect_to :action => :index
  end

  def destroy_locale
    current_page = @site.pages.find(params[:page_id])
    @locale_page = current_page.locale_pages.find(params[:id])
    @locale_page.destroy
    flash[:success] = "Locale content deleted"
    redirect_to :action => :locale_pages
  end

  def form_blocks
    @page = @site.pages.find_by_id(params[:id]) || @site.pages.new
    @page.layout = @site.layouts.find_by_id(params[:layout_id])
  end

  def toggle_branch
    @pages_by_parent = pages_grouped_by_parent
    @page = @site.pages.find(params[:id])
    s   = (session[:cms_page_tree] ||= [])
    id  = @page.id.to_s
    s.member?(id) ? s.delete(id) : s << id
  rescue ActiveRecord::RecordNotFound
    # do nothing
  end

  def reorder
    (params[:comfy_cms_page] || []).each_with_index do |id, index|
      ::Comfy::Cms::Page.where(:id => id).update_all(:position => index)
    end
    head :ok
  end

protected

  def index_for_redactor
    tree_walker = ->(page, list, offset) do
      return unless page.present?
      label = "#{'. . ' * offset}#{page.label}"
      list << {:name => label, :url => page.url(:relative)}
      page.children.each do |child_page|
        tree_walker.(child_page, list, offset + 1)
      end
      list
    end

    page_select_options = [{
      :name => I18n.t('comfy.admin.cms.pages.form.choose_link'),
      :url  => false
    }] + tree_walker.(@site.pages.root, [ ], 0)

    render :json => page_select_options
  end

  def site_has_no_pages?
    @site.pages.count == 0
  end

  def pages_grouped_by_parent
    @site.pages.includes(:categories).group_by(&:parent_id)
  end

  def check_for_layouts
    if @site.layouts.count == 0
      flash[:danger] = I18n.t('comfy.admin.cms.pages.layout_not_found')
      redirect_to new_comfy_admin_cms_site_layout_path(@site)
    end
  end

  def build_cms_page
    @page = @site.pages.new(page_params)
    @page.parent ||= (@site.pages.find_by_id(params[:parent_id]) || @site.pages.root)
    @page.layout ||= (@page.parent && @page.parent.layout || @site.layouts.first)
  end

  def build_cms_locale_page
    
    current_page = @site.pages.find(params[:page_id])
    @page = current_page.locale_pages.new(locale_page_params)
  #  @page.parent ||= curr || @site.pages.root)
    @page.layout ||= @site.layouts.first
  end

  def load_locale_page
    
    current_page = @site.pages.find(params[:page_id])
    @locale_page = current_page.locale_pages.find(params[:id])

    @locale_page.attributes = locale_page_params
  end

  def load_cms_page
    @page = @site.pages.find(params[:id])
    @page.attributes = page_params
    @page.layout ||= (@page.parent && @page.parent.layout || @site.layouts.first)
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = I18n.t('comfy.admin.cms.pages.not_found')
    redirect_to :action => :index
  end

  def preview_cms_page
    if params[:preview]
      layout = @page.layout.app_layout.blank?? false : @page.layout.app_layout
      @cms_site   = @page.site
      @cms_layout = @page.layout
      @cms_page   = @page

      # Make sure to use the site locale to render the preview becaue it might
      # be different from the admin locale.
      I18n.locale = @cms_site.locale

      # Chrome chokes on content with iframes. Issue #434
      response.headers['X-XSS-Protection'] = '0'

      render :inline => @page.render, :layout => layout, :content_type => 'text/html'
    end
  end

  def locale_page_params
    params.require(:comfy_cms_locale_page).permit(:label, :content_cache, :layout_id, :is_published, :locale)
  end

  def blocks_params
    params.fetch(:locale_page, {}).permit!
  end

  def page_params
    params.fetch(:page, {}).permit!
  end
end

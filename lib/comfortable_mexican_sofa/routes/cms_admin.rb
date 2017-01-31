class ActionDispatch::Routing::Mapper

  def comfy_route_cms_admin(options = {})
    options[:path] ||= 'admin'

    scope :module => :comfy, :as => :comfy do
      scope :module => :admin do
        namespace :cms, :as => :admin_cms, :path => options[:path], :except => :show do
          get '/', :to => 'base#jump'
          resources :sites do
            resources :pages do
              get  :form_blocks,    :on => :member
              get  :toggle_branch,  :on => :member
              put :reorder,         :on => :collection
              get :new_locale_page, :on => :member
              get :locale_pages,    :on => :member
              post :create_locale, :on => :collection

              resources :revisions, :only => [:index, :show, :revert] do
                patch :revert, :on => :member
              end
            end
            resources :files do
              put :reorder, :on => :collection
            end
            resources :layouts do
              put :reorder, :on => :collection
              resources :revisions, :only => [:index, :show, :revert] do
                patch :revert, :on => :member
              end
            end
            resources :snippets do
              put :reorder, :on => :collection
              resources :revisions, :only => [:index, :show, :revert] do
                patch :revert, :on => :member
              end
            end
            resources :categories
          end
          get '/sites/:site_id/pages/:page_id/locale_pages/:id/edit' => 'pages#edit_locale', as: :edit_locale_page
          patch '/sites/:site_id/pages/:page_id/locale_pages/:id/edit' => 'pages#update_locale', as: :update_locale_page
          delete '/sites/:site_id/pages/:page_id/locale_pages/:id/destroy_locale' => 'pages#destroy_locale', as: :destroy_locale_page
        end
      end
    end
  end
end

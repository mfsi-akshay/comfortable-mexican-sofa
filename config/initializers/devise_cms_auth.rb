module DeviseCmsAuth
  def authenticate
    unless current_user.present? && current_user.admin?
      redirect_to new_user_session_path
    end
  end
end

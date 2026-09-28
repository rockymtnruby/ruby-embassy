class Admin::AnnouncementsController < AdminController
  before_action :set_announcement, only: %i[edit update destroy]

  def index
    @announcements = Announcement.visible
  end

  def new
    @announcement = Announcement.new
  end

  def create
    @announcement = Announcement.new(announcement_params)
    if @announcement.save
      redirect_to admin_announcements_path,
                  notice: "Announcement posted."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @announcement.update(announcement_params)
      redirect_to admin_announcements_path,
                  notice: "Announcement updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @announcement.destroy!
    redirect_to admin_announcements_path,
                notice: "Announcement removed."
  end

  private

  def set_announcement
    @announcement = Announcement.find(params[:id])
  end

  def announcement_params
    params.require(:announcement).permit(:title, :body, :pinned)
  end
end

class Announcement < ApplicationRecord
  validates :title, presence: true
  validates :body, presence: true

  scope :visible, -> { order(pinned: :desc, created_at: :desc) }
end

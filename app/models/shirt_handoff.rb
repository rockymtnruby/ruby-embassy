class ShirtHandoff < ApplicationRecord
  belongs_to :user

  enum :status, { pending: 0, given: 1, waitlist: 2, missed: 3 }

  # Must mirror the Tito "What is your t-shirt size?" answers verbatim —
  # the sync stores raw responses and the edit form offers exactly these.
  SIZES = [
    "Small", "Small - Women",
    "Medium", "Medium - Women",
    "Large", "Large - Women",
    "XL", "XL - Women",
    "2XL", "2XL - Women",
    "3XL", "4XL"
  ].freeze

  validates :user_id, uniqueness: true

  scope :for_status, ->(status) {
    statuses.key?(status.to_s) ? where(status: status) : all
  }
  scope :ordered, -> {
    joins(:user).order("users.last_name ASC", "users.first_name ASC")
  }

  def mark_given!
    update!(status: :given, given_at: Time.current)
  end

  def unmark!
    update!(status: :pending, given_at: nil)
  end
end

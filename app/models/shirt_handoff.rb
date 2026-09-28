class ShirtHandoff < ApplicationRecord
  belongs_to :user

  enum :status, { pending: 0, given: 1, waitlist: 2, missed: 3 }

  SIZES = %w[XS S M L XL 2XL 3XL].freeze

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

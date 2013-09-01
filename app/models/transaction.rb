class Transaction < ActiveRecord::Base
  self.inheritance_column = nil

  belongs_to :account

  belongs_to :statement

  has_one :sorted_transaction

  validates :amount, :presence => true

  validates :fit_id, :presence => true

  validates :account, :presence => true
end

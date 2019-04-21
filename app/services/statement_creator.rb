class StatementCreator
  include ActiveModel::Model

  require 'csv'

  attr_accessor :file, :account, :statement, :balance, :file_type

  validates :file, presence: true
  validates :account, presence: true
  # validate :file_can_be_parsed

  def persisted?
    false
  end

  def save
    if valid?
      persist!
      true
    else
      false
    end
  end

  private

  def import(file)
    CSV.foreach(file.path, encoding: "bom|utf-8", headers: :first_row) do |row|
      f_id = generate_transaction_sha(row)
      amount = parse_amount(row)
      new_transaction = Transaction.where(
        amount: amount,
        name: row["Merchant Name"],
        payee: row["Merchant Name"],
        posted_at: parse_transaction_datetime(row),
        fit_id: f_id
      ).first_or_initialize

      if new_transaction.new_record?
        new_transaction.account = account
        new_transaction.statement = statement

        if new_transaction.save!
          sort_transaction(new_transaction)
        end
        new_transaction
      end
    end
  end

  def generate_transaction_sha(row)
    string = row["Merchant Name"]+ row["Date"] + row["Time"] + row["Amount"]
    sha = Digest::SHA256.hexdigest string
    sha[0..31]
  end

  def parse_transaction_datetime(row)
    csv_date = DateTime.strptime(row["Date"] + " " + row["Time"]+" -0400", "%m/%d/%Y %l:%M %p %z")
    if csv_date.between?(Date.new(2019,12,29), Date.new(2019,12,31))
      date = (csv_date - 1.year).in_time_zone('Pacific Time (US & Canada)')
    else
      date = (csv_date).in_time_zone('Pacific Time (US & Canada)')
    end
    date
  end

  def parse_amount(row)
    row["Amount"].to_f*-1
  end


  #
  # def file_can_be_parsed
  #   return unless file.present?
  #
  #   OFX::Parser::Base.new(file)
  # rescue StandardError
  #   errors.add(:file, 'could not be parsed')
  # end

  def persist!
    Statement.transaction do
      create_statement!

      import(file)

      # parser.account.transactions.each do |t|
      #   tr = create_transaction!(t)
      #
      #   sort_transaction(tr) if tr
      # end

      raise ActiveRecord::Rollback if statement.transactions.empty?

      set_statement_dates!

      set_account_balance!

      statement
    end
  end

  def create_transaction!(t)
    new_transaction = Transaction.where(
      amount: t.amount,
      memo: t.memo,
      name: t.name,
      payee: t.payee,
      posted_at: t.posted_at,
      ref_number: t.ref_number,
      type: t.type,
      fit_id: t.fit_id
    ).first_or_initialize

    if new_transaction.new_record?
      new_transaction.account = account
      new_transaction.statement = statement

      new_transaction.save!
      new_transaction
    else
      false
    end
  end

  def create_statement!
    @statement = Statement.create!(
      balance: balance.to_f,
      account: account
    )
  end

  def set_statement_dates!
    from_date = sorted_transactions.first.posted_at
    to_date = sorted_transactions.last.posted_at
    statement.update!(
      from_date: from_date,
      to_date: to_date
    )
  end

  # def parser
  #   @parser ||= OFX::Parser::Base.new(file).parser
  # end

  def sorted_transactions
    statement.transactions.order(:posted_at)
  end

  def set_account_balance!
    return if account.statements.order(:to_date).last != statement

    account.update!(balance: statement.balance)
  end

  def sort_transaction(transaction)
    TransactionSorter.new(transaction).sort
  end
end

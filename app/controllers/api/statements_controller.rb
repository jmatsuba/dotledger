module Api
  class StatementsController < BaseController
    def index
      @statements = Statement.all.order(created_at: :desc)

      @statements = @statements.where(account_id: account_id) if account_id.present?

      @statements = @statements.page(page_number)

      set_pagination_header(@statements)

      respond_with @statements
    end

    def show
      @statement = Statement.find(statement_id)

      respond_with @statement
    end

    def create
      @account = Account.find(account_id)
      if params[:file_type] == 'pc-financial-csv'
        @statement_creator = StatementCreator.new(account: @account, file: file, balance: params[:balance], file_type: params[:file_type] )
      elsif params[:file_type] == 'ofx'
        @statement_creator = OfxStatementCreator.new(account: @account, file: file )
      end

      @statement_creator.save

      respond_with @statement_creator.statement
    end

    def destroy
      @statement = Statement.find(statement_id)

      @statement.destroy

      respond_with @statement
    end

    private

    def statement_id
      params[:id].to_s
    end

    def account_id
      params[:account_id].to_s
    end

    def file
      params[:file]
    end
  end
end

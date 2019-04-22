namespace :dot_ledger do
  desc 'Import transactions from an OFX file'
  task :import, %i[account_id file] => :environment do |_t, args|
    begin
      account = Account.find(args[:account_id])
      ofx_file = File.open(args[:file])

      creator = StatementCreator.new(account: account, file: ofx_file)

      if creator.save
        puts "Imported #{creator.statement.transactions.count} transactions into #{account.name}."
      else
        puts "Error: #{creator.errors.messages.map { |k, v| "#{k} #{v.join(', ')}." }.join}"
      end
    rescue StandardError => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  desc 'Re-run sorting rules on unsorted transactions'
  task sort: :environment do
    count = 0
    Transaction.unsorted.each do |t|
      sorter = TransactionSorter.new(t)
      sorter.sort

      count += 1 if sorter.sorted_transaction.present?
    end

    puts "Sorted #{count} transactions."
  end

  desc 'Export data to a YAML file'
  task :export_yaml, [:file] => :environment do |_t, args|
    file =
      if args[:file].present?
        File.open(args[:file], 'w')
      else
        $stdout
      end

    exporter = DotLedgerExporter.new(file)
    exporter.export

    summary = "Exported\n--------\n\n"
    exporter.data.each do |label, elements|
      summary << "#{label}: #{elements.count}\n"
    end

    $stderr.write(summary)
  end

  desc 'Import data from a YAML file'
  task :import_yaml, [:file] => :environment do |_t, args|
    file =
      if args[:file].present?
        File.open(args[:file], 'r')
      else
        $stdin
      end

    importer = DotLedgerImporter.new(file)
    importer.import

    summary = "Imported\n--------\n\n"
    importer.data.each do |label, elements|
      summary << "#{label}: #{elements.count}\n"
    end

    $stderr.write(summary)
  end

  namespace :seed do
    desc 'Create seed accounts'
    task accounts: :environment do
      Account.create! [
        { name: 'Eftpos', number: '12-1234-1234567-001', type: 'Cheque' },
        { name: 'Savings', number: '12-1234-1234567-002', type: 'Savings' },
        { name: 'Visa', number: '4111-XXXX-XXXX-1111', type: 'Credit Card' },
        { name: 'MasterCard', number: '5500-XXXX-XXXX-0004', type: 'Credit Card' }
      ]
    end

    desc 'Create seed categories'
    task categories: :environment do
      categories = {
        'Flexible' => [
          'Transport - Taxi',
          'Transport - Car Share',
          'Motor Vehicles - Gas (Trips)',
          'Transport - Taxi',
          'Transport - Car Share',
          'Cash Withdrawals',
          'Restaurants - Eating Out',
          'Restaurants - Take Out',
          'Entertainment - Movies',
          'Entertainment - Live Shows',
          'Running - Races and Events',
          'Running - Travel',
          'Skiing/Snowboarding - Gear',
          'Skiing/Snowboarding - Lift Tickets & Passes',
          'Skiing/Snowboarding - Safety Gear',
          'Vacation - Travel',
          'Vacation - Hotels'
        ],
        'Essential' => [
          'Bank Charges',
          'Cell Phone',
          'Bank Fees',
          'Loan Interest',
          'Education',
          'Groceries',
          'House - Cleaning',
          'Housing - Rent',
          'Housing - Furniture',
          'Housing - Maintenance',
          'Medical & Dental',
          'Motor Vehicles - Insurance',
          'Motor Vehicles - Gas (Day to Day)',
          'Transport - Public Transit',
          'Property Tax',
          'Clothing',
          'General/Misc',
          'Gifts',
          'Personal Care & Fitness',
          'Running - Shoes',

        ],
        'Income' => [
          'Interest',
          'Other Income & Deposits',
          'Salary & Wages',
          'Tax Credits'
        ],
        'Transfer' => [
          'Transfer In',
          'Transfer Out'
        ]
      }

      categories.each do |type, names|
        names.each do |name|
          Category.create!(type: type, name: name)
        end
      end
    end
  end

  desc 'Create all seeds'
  task seed: :environment do
    Rake.application.in_namespace('dot_ledger:seed') do |seed|
      seed.tasks.each(&:invoke)
    end
  end
end

require "json"
require "date"

def read_json_from_file(filename)
  
  file_contents = File.read(filename)  
  json = JSON.parse(file_contents)

  rescue Exception => read_error
    puts read_error
  
  return json
end

class Car
  
    attr_reader :id, :price_per_day, :price_per_km
    
    def initialize(id, pricing)
      
      if id.nil? || pricing[:price_per_day].nil? || pricing[:price_per_km].nil? then
        raise "Insufficient info to add car"
      end

      @id = id
      @price_per_day = pricing[:price_per_day]
      @price_per_km = pricing[:price_per_km]
        
      rescue Exception => car_initialize_error
        puts car_initialize_error
    end
    
end

module FinancialFunctions
  CREDIT = "credit"
  DEBIT = "debit"
  
  def debit_or_credit(amount)
    
    @type = CREDIT
    if amount < 0 then
      @type = DEBIT
    end
    
    return @type
    
  end
end

class StatementHistory
  
  include FinancialFunctions
  
  attr_reader :statement_set, :outstanding_amount, :outstanding_type
  
  def initialize()
    
    @statement_set = []
      
  end
  
  def add_statement(statement)
    @calculated_time = Time.new()
    @statement_set << statement
  end

  def issue_payments()
    for statement in @statement_set
      statement.complete
    end
  end
  
  def amount_outstanding()
    @outstanding_amount_raw = 0
    for payment in @statement_set

      multiplier = 1 # Credit
      if payment.paid 
        multiplier = -1 # Debit
      end

      @outstanding_amount_raw += (payment.raw_amount * multiplier)
      @outstanding_type = self.debit_or_credit(@outstanding_amount_raw)

    end
    
    @outstanding_amount = @outstanding_amount_raw.abs.to_i
  end

end

class Statement
  
  include FinancialFunctions
  
  attr_reader :receiver, :raw_amount, :unsigned_amount, :type, :paid
  CREDIT = "credit"
  DEBIT = "debit"
  
  def initialize(receiver, amounts)
    
    @receiver = receiver
    @amounts = []
    @raw_amount = 0
    @unsigned_amount = 0
    @paid = false
    
    if !amounts.nil? then
      for amount in amounts
        self.add_amount(amount)
      end
    end
  end
  
  def add_amount(amount)
    
    @amounts << amount
    if amount[:debit].nil? then
      amount[:debit] = true
    end
    
    multiplier = -1
    if !amount[:debit] then
      multiplier = 1
    end
    
    @raw_amount += amount[:amount] * multiplier
    @unsigned_amount = @raw_amount.abs.to_i
    
    @type = self.debit_or_credit(@raw_amount)
  end
  
  def complete()
    @paid = true
  end
  
end

class Rental
  
  LENGTH_OF_RENTAL_DISCOUNT = [
    {:range => (0..1), :discount => 0.0},
    {:range => (2..4), :discount => 0.1},
    {:range => (5..10), :discount => 0.3},
    {:range => (11..Float::INFINITY), :discount => 0.5}
  ]
  COMMISSION_PERCENTAGE = 0.3
  INSURANCE_PERCENTAGE_OF_COMMISSION = 0.5
  ASSISTANCE_FEE_PER_DAY = 100
  DEDUCTIBLE_REDUCTION_PER_DAY = 400
  PRICE_PROCESS_ORDER = ['price', 'discount', 'commission', 'options', 'payments']
  PAYMENT_ACTORS = [:driver, :owner, :insurance, :assistance, :drivy]
  
  attr_reader :id, :car, :number_of_days, :distance, :projected_price, :deductible_reduction, :payments_by_actor, :total_commission
  attr_accessor :projected_commission_components, :options #, :start_date, :end_date
  
  def initialize(id, rental_car, rental_details)
    
    if id.nil? || rental_car.nil? || rental_details[:start_date].nil? || rental_details[:end_date].nil? || rental_details[:distance].nil? then
      raise "Insufficient rental information"
    end
    
    @id = id
    @car = rental_car
    @start_date = Date.parse(rental_details[:start_date])
    @end_date = Date.parse(rental_details[:end_date])
    self.calculate_number_of_days
    
    @distance = rental_details[:distance]
    
    @payments_by_actor = {}
    for actor in PAYMENT_ACTORS 
      @payments_by_actor[actor] = StatementHistory.new 
    end

    if @distance < 0 then
      raise "Distance can't be negative"
    end

    @options = {}
    if !rental_details[:deductible_reduction].nil? then
      @deductible_reduction = rental_details[:deductible_reduction]
    end
    
    self.price_calculation_process
    
    rescue Exception => msg
      puts msg
  end
  
  def calculate_number_of_days()
    
    if @start_date.nil? || @end_date.nil? 
      raise "Need start and end date to calculate number of days"
    end
    
    @number_of_days = (@end_date-@start_date).to_i

    @number_of_days += 1
    #Note: this calculation seems off to me. e.g. picking up on 2017-12-08 and returning 2017-12-10 seems like it should be 2 days not 3 as it is in the given output.json

    if @number_of_days < 0 then
      raise "End of rental period must be later than the beginning of the period"
    end
    
    rescue Exception => rental_days_calculation_error
      puts rental_days_calculation_error
  end
  
  def price_calculation_process(up_to_index = nil)
    if up_to_index.nil? 
      up_to_index = PRICE_PROCESS_ORDER.length
    end
    
    for process in PRICE_PROCESS_ORDER[0...up_to_index]
      method_name = "calculate_#{process}"
      if defined? method_name 
        self.send(method_name)
      end
    end
  end
  
  def calculate_discount()
    
    if @number_of_days.nil? then
      raise "Insufficient data (number of days) for discount calculation" 
    end
    
    price_per_day = @car.price_per_day
    if price_per_day.nil? then
      raise "Need a price per day to calculate discount"
    end
    
    discount_total = 0.0
    
    for day_number in 1..@number_of_days
     discount = 0.0
     
     for rule in LENGTH_OF_RENTAL_DISCOUNT 
       if !rule[:range].nil? 
         if rule[:range].cover?(day_number)
           discount = rule[:discount]
         end
       end
     end
      
     this_day_discount = price_per_day * discount
     discount_total += this_day_discount
    end
    
    @projected_discount = discount_total.to_i
    
    if @projected_price.nil? then
      raise "Can't calculate price after discount without projected price"
    end
    
    @price_before_discount = @projected_price
    @projected_price -= discount_total.to_i
    
    rescue Exception => discount_error
      puts discount_error
  end
  
  def calculate_commission()
    if @projected_price.nil? then
      commission_rank = PRICE_PROCESS_ORDER.index("commission")
      price_calculation_process(commission_rank)

      if @projected_price.nil? then
        raise "Need projected price to calculate commission"
      end
    end
    
    if @number_of_days.nil? then
      raise "Need number of days to calculate commission"
    end
    
    @total_commission = @projected_price * COMMISSION_PERCENTAGE
    @projected_commission_components = {}
    @projected_commission_components[:insurance_fee] = (total_commission * INSURANCE_PERCENTAGE_OF_COMMISSION).to_i
    @projected_commission_components[:assistance_fee] = (@number_of_days * ASSISTANCE_FEE_PER_DAY).to_i    
    @projected_commission_components[:drivy_fee] = (@total_commission - (@projected_commission_components[:insurance_fee] + @projected_commission_components[:assistance_fee])).to_i
    
  end
  
  def calculate_options()
    
    if @deductible_reduction.nil? then
      @deductible_reduction = false
    end
    
    if @number_of_days.nil? || DEDUCTIBLE_REDUCTION_PER_DAY.nil? then
      raise "Insufficient info to calculate deductible reduction"
    end

    @options["deductible_reduction"] = 0
    if @deductible_reduction then
      @options["deductible_reduction"] = @number_of_days * DEDUCTIBLE_REDUCTION_PER_DAY
    end
    
  end
  
  def calculate_price()
    if @car.price_per_day.nil? || @number_of_days.nil? || @car.price_per_km.nil? || @distance.nil?  then
      raise "Insufficient info to calculate price"
    end
    
    day_price = @car.price_per_day * @number_of_days
    km_price = @car.price_per_km * @distance
    @projected_price = (day_price + km_price).to_i #No fractions of a penny
  end 
  
  def calculate_payments()
    
    if @projected_price.nil? then
      payments_rank = PRICE_PROCESS_ORDER.index("payments")
      price_calculation_process(payments_rank)

      if @projected_price.nil? then
        raise "Need projected price to calculate payments"
      end
    end
    
    if @total_commission.nil? then
      raise "Total commission amount needed to calculate payments" 
    end
    
    insurance_fee = @projected_commission_components[:insurance_fee]
    assistance_fee = @projected_commission_components[:assistance_fee]
    drivy_fee = @projected_commission_components[:drivy_fee]
    if insurance_fee.nil? || assistance_fee.nil? || drivy_fee.nil? then
      raise "Need all commission components to calculate payments"
    end
    
    # Base payments
    statements = {
      :driver => [{:type => "rental_price", :amount => @projected_price, :debit => true}],
      :owner => [{:type => "rental_price", :amount => (@projected_price - @total_commission), :debit => false}],
      :insurance => [{:type => "insurance_fee", :amount => insurance_fee, :debit => false}],
      :assistance =>[{:type => "assistance_fee", :amount => assistance_fee, :debit => false}],
      :drivy => [{:type => "drivy_fee", :amount => drivy_fee, :debit => false}]
    }

    # Conditional payments
    if !@options["deductible_reduction"].nil? then
      statements[:driver] << {:type => "deductible reduction", :amount => @options["deductible_reduction"], :debit => true}
      statements[:drivy] << {:type => "deductible reduction", :amount => @options["deductible_reduction"], :debit => false}
    end
    
    statements.each{ |actor, statement| 
      this_statement = Statement.new(actor, statement)
      @payments_by_actor[actor].add_statement(this_statement)
    }
  
  end

  def adjust_details(new_details)
     
    if !new_details["start_date"].nil? 
      @start_date = Date.parse(new_details["start_date"])
      self.calculate_number_of_days
    end

    if !new_details["end_date"].nil?
      @end_date = Date.parse(new_details["end_date"])
      self.calculate_number_of_days
    end

    if !new_details["distance"].nil? 
     @distance = new_details["distance"]
    end
    
    self.price_calculation_process
    
  end

  def calculate_outstanding_payments
    
    if !@payments_by_actor.nil?     
      @payments_by_actor.each{ |actor, payment| 
        payment.amount_outstanding
      }
    end
  end

end

class RentalOptions
  
  attr_accessor :rentals
  
  def initialize()
    @rentals = {}
  end
  
  def prepare_for_output(style = nil)
        
    if style.nil? 
      style = :level1
    end
    
    if [:level1, :level2, :level3, :level4, :level5].include? style then
      index_name = "rentals"
    end
    
    if [:level6].include? style then
      index_name = "rental_modifications"
    end
    
    # Required items
    case style
      when :level1 || :level2 #backwards compatibility
        required_items = ["id","projected_price"]
      when :level3
        required_items = ["id", "projected_price", "projected_commission_components"]
      when :level4
        required_items = ["id", "projected_price", "projected_commission_components", "options"]
      when :level5
        required_items = ["id", "actions"]
      when :level6
        required_items = ["id", "payments_by_actor"]
      else 
        index_name = "rentals"
        required_items = ["id","projected_price"]
    end

    @output_hash = {}
    @output_hash[index_name] = []
    count = 1
    @rentals.each {|rental_id, rental| 
      begin
        
        if !required_items.nil? then
          for required_item in required_items 
            if rental.instance_variable_get("@#{required_item}").nil? then
              raise "Insufficient info for output"
            end
          end
        end
      
        # Basic additions: id and projected_price
        if [:level1, :level2, :level3, :level4].include? style then
          rental_id = rental.id
          price = rental.projected_price
          this_item = {id: rental_id, price: price}
        elsif [:level5].include? style then
          rental_id = rental.id
          this_item = {id: rental_id}
        end

        # The main output, the meat 
        add_item = false
        case style
          when :level3
            commission = rental.projected_commission_components      
            this_item["commission"] = commission
            add_item = true
          when :level4
            commission = rental.projected_commission_components
            options = rental.options
            this_item["options"] = options
            this_item["commission"] = commission
            add_item = true
          when :level5
            rental_id = rental.id
            actions = rental.actions
            actions_output = []
            actions.each { |actor, action| 
              if !action.unsigned_amount.nil? && !action.type.nil?
                actions_output << {:who => actor, type: action.type, amount: action.unsigned_amount}
                add_item = true
              end
            }
            
            this_item["actions"] = actions_output
          when :level6
            rental_id = rental.id
            actions = rental.payments_by_actor
            actions_output = []
              actions.each { |actor, action|
                if !action.outstanding_amount.nil? && !action.outstanding_type.nil?
                  actions_output << {:who => actor, type: action.outstanding_type, amount: action.outstanding_amount}
                end
              }

            if !actions_output.empty? #if empty no actions to report
              this_item = {id: count, rental_id: rental_id, actions: actions_output}
              add_item = true
              count += 1
            end
          else
        end
        
        if add_item then @output_hash[index_name] << this_item end
      
        rescue Exception => rental_write_error
          puts rental_write_error
      end
    }

  end
  
  def write_json(filename)
    if @output_hash.nil? then
      raise "No output hash to write"
    end

    json = JSON.pretty_generate(@output_hash)

    file = File.open(filename, "w")
    file.write(json)

    rescue Exception => write_error
      puts write_error

    ensure
      file.close unless file.nil?
  end

end

begin

  data_filename = "data.json"
  output_filename = "output.json"
  level_style = :level6
  rental_options = RentalOptions.new

  file_data = read_json_from_file(data_filename)
  if file_data.nil? then
    raise "No file data"
  end

  if file_data["cars"].nil? then
    raise "No Cars found"
  end
  
  if file_data["rentals"].nil? then
    raise "No Rentals found"
  end

  cars_from_file = file_data["cars"]
  cars_list = []
  car_ids_list = []
  for car in cars_from_file
    begin
      
      #The following checks for data necessary to form a rental. 
      #It does not include the car if missing, which seems appropriate for this exercise, but perhaps not for all situations.
      if car["id"].nil? || car["price_per_day"].nil? || car["price_per_km"].nil? then 
        raise "Missing data. Un-rentable car!" 
      end
      
      car_id = car["id"]
      
      if car_ids_list.include? car_id then
        raise "Repeated car id #{car_id}"
      end
      car_ids_list << car_id
      


      pricing = {:price_per_day => car["price_per_day"], :price_per_km => car["price_per_km"]}
      this_car = Car.new(car_id, pricing)
      cars_list[car_id] = this_car
      
      rescue Exception => car_load_error
        puts car_load_error
    end
  end

  rentals_from_file = file_data["rentals"]
  rental_ids_list = []
  for rental in rentals_from_file
    begin
      rental_car_id = rental["car_id"]
      rental_id = rental["id"]
      
      if rental_id.nil? || rental_car_id.nil? || rental["start_date"].nil? || rental["end_date"].nil? || rental["distance"].nil? then
        raise "Insufficient rental information"
      end
      
      if rental_ids_list.include? rental_id then
        raise "Repeated rental id #{rental_id}"
      end
      rental_ids_list << rental_id
      
      if cars_list[rental["car_id"]].nil? then
        raise "Car does not exist"
      end
  
      if rental["deductible_reduction"].nil? then
        rental["deductible_reduction"] = false
      end
      
      this_rental_car = cars_list[rental["car_id"]]
      rental_details = {:start_date => rental["start_date"], :end_date => rental["end_date"], :distance => rental["distance"], :deductible_reduction => rental["deductible_reduction"]}

      this_rental = Rental.new(rental_id, this_rental_car, rental_details)
      rental_options.rentals[rental_id] = this_rental

      rescue Exception => rental_load_error
        puts rental_load_error

    end
  end
  
  # "Paying" based on initial calculations
  if !rental_options.rentals.nil? then
    rental_options.rentals.each {|rental_id, rental|
      if !rental.payments_by_actor.nil? then
        rental.payments_by_actor.each { |actor, payment_set|
         payment_set.issue_payments
        }
      end
    }
  end
  
  # Modifying Rentals
  if !file_data["rental_modifications"].nil? 
    modifications_from_file = file_data["rental_modifications"]
    for modification in modifications_from_file
      begin
        
        #Pulling rental based on rental_id
        if rental_options.rentals[modification["rental_id"]].nil? then
          raise "Rental does not exist"
        end
        this_rental = rental_options.rentals[modification["rental_id"]]
      
        this_rental.adjust_details(modification)
        this_rental.calculate_outstanding_payments
      
        rescue Exception => rental_adjustment_error
          puts rental_adjustment_error
      end
    end
  end

  rental_options.prepare_for_output(level_style)
  rental_options.write_json(output_filename)
  
  rescue Exception => msg  
    puts msg 
end
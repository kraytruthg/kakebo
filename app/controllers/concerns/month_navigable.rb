module MonthNavigable
  extend ActiveSupport::Concern

  YEAR_MIN  = 2000
  YEAR_MAX  = 2099

  included do
    before_action :set_month_params
    helper_method :prev_month, :next_month, :at_lower_bound?, :at_upper_bound?
  end

  private

  def set_month_params
    raw_year  = params[:year]
    raw_month = params[:month]

    year  = raw_year&.to_i
    month = raw_month&.to_i

    if raw_year.blank? && raw_month.blank?
      @year  = Date.today.year
      @month = Date.today.month
      return
    end

    unless year&.between?(YEAR_MIN, YEAR_MAX) && month&.between?(1, 12)
      redirect_to "#{request.path}?#{{ year: Date.today.year, month: Date.today.month }.to_query}" and return
    end

    @year  = year
    @month = month
  end

  def prev_month
    date = Date.new(@year, @month, 1).prev_month
    { year: date.year, month: date.month }
  end

  def next_month
    date = Date.new(@year, @month, 1).next_month
    { year: date.year, month: date.month }
  end

  def at_lower_bound?
    @year == YEAR_MIN && @month == 1
  end

  def at_upper_bound?
    @year == YEAR_MAX && @month == 12
  end

end

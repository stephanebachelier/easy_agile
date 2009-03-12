class Iteration < ActiveRecord::Base
  attr_protected :project_id
  belongs_to :project
  has_many :stories
  validates_presence_of :name, :duration, :project_id

  def validate
    errors.add(:stories, "must be assigned") if stories.empty?
  end

  def name
    if attributes["name"]
      attributes["name"]
    elsif project
      "Iteration #{project.iterations.count + 1}"
    end
  end

  def to_s
    name || 'New Iteration'
  end

  def story_points_remaining
    stories.incomplete.inject(0) do |sum, st|
      sum + st.estimate.to_i
    end
  end

  def start
    unless active?
      self.update_attributes(
        :start_date => Date.today,
        :initial_estimate => story_points_remaining
      )
    end
  end

  def end_date
    start_date + duration
  end

  def days_remaining
    end_date - Date.today
  end

  def active?
    ! self.start_date.nil?
  end

  def burndown
    Burndown.new(self)
  end
end

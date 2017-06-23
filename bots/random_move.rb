class NoPreference < RTanque::Bot::Brain
  NAME = 'random_move'
  include RTanque::Bot::BrainHelper

  class Timer
    def initialize
      @ticks = 0
    end

    def start(amount_of_ticks)
      @ticks = amount_of_ticks
    end

    def tick
      @ticks -= 1
    end

    def end?
      @ticks < 1
    end

    def end
      @ticks = 0
    end
  end


  def initialize(arena)
    @heading_timer = Timer.new()
    @speed_timer = Timer.new()
    @point = RTanque::Point.new(arena.width / 2, arena.height / 2, self.arena)
    @speed = MAX_BOT_SPEED

    super(arena)
  end

  def vary_heading()
    if @heading_timer.end?
      rand = Random.new
      @point = RTanque::Point.new(
        self.arena.width * rand(0.2..0.6),
        self.arena.height * rand(0.2..0.8),
        self.arena
      )
      @heading_timer.start(rand(5..30))
    end

    @heading_timer.tick
  end

  def on_corner?
    pos = self.sensors.position
    pos.on_top_wall? && pos.on_right_wall? ||
    pos.on_top_wall? && pos.on_left_wall? ||
    pos.on_bottom_wall? && pos.on_right_wall? ||
    pos.on_bottom_wall? && pos.on_left_wall?
  end

  def tick!
    @previous_health ||= self.sensors.health
    vary_heading
    command.heading = RTanque::Heading.new_between_points(self.sensors.position, @point)
    command.speed = @speed


    # heading turret & radar at the opposite angle of tank heading
    # command.radar_heading = -heading_to_center
    # command.turret_heading = -heading_to_center



    # target & fire strat: ?
    @target ||= nil
    @target_old = @target

    if @target = get_radar_lock
      point_radar_at_target
      point_turret_at_target
      fire_at_target
    else
      acquire_target
    end

    @my_old_pos = sensors.position
  end

  def acquire_target
    command.radar_heading = sensors.radar_heading + MAX_RADAR_ROTATION
  end

  def get_radar_lock
    # sensors.radar.first
    sensors.radar.min { |a,b| a.distance <=> b.distance }
  end

  def point_radar_at_target
    command.radar_heading = @target.heading
  end

  def point_turret_at_target
    return unless @target_old && @my_old_pos

    # compensate for targets movement
    old_target_point = point_at(@my_old_pos, @target_old)
    new_target_point = point_at(sensors.position, @target)

    target_heading = old_target_point.heading(new_target_point)


    target_speed = RTanque::Point.distance(old_target_point, new_target_point)

    my_shot_pos = sensors.position
    target_pos = new_target_point
    estimated_ticks = 0
    while sensors.position.distance(my_shot_pos) < sensors.position.distance(target_pos)
      estimated_ticks += 1
      target_pos = new_target_point.move(target_heading, target_speed * estimated_ticks)
      my_shot_pos = sensors.position.move(sensors.position.heading(target_pos), 5 + RTanque::Shell.speed(MAX_FIRE_POWER) * estimated_ticks)
      #break if my_shot_pos.on_wall? || target_pos.on_wall?
      break if estimated_ticks > 2000

    end

    # here, I know my_shot_pos is within 3 of estimated target_pos

    # this is inaccurate
    #estimated_ticks = @target.distance / RTanque::Shell.speed(FIRE_POWER)

    new_target_point = new_target_point.move(target_heading, estimated_ticks * target_speed)

    @leading_heading = sensors.position.heading(new_target_point)

    command.turret_heading = @leading_heading
  end

  def fire_at_target
    return unless @leading_heading
    if (@leading_heading.delta(sensors.turret_heading)).abs < RTanque::Heading::ONE_DEGREE
      command.fire(MAX_FIRE_POWER)
    end
  end

  def point_at(from, reflection)
    from.move(reflection.heading, reflection.distance)
  end
end

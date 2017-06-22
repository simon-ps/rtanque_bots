class Blammo < RTanque::Bot::Brain
  NAME = 'blammo'
  include RTanque::Bot::BrainHelper

  INTERVAL = 10000

  TURRET_FIRE_RANGE = RTanque::Heading::ONE_DEGREE * 3

  FIRE_POWER = MAX_FIRE_POWER

  def tick!
    @my_old_health ||= sensors.health
    @jink ||= false
    @side ||= 1
    @destination ||= nil
    @target ||= nil
    @target_old = @target

    if @target = get_radar_lock
      analyse_target
      point_radar_at_target
      point_turret_at_target
      fire_at_target

      get_behind_target
      @old_target_heading = @target_heading
    else
      acquire_target
    end

    if sensors.health != @my_old_health
      @jink = !@jink
    end

    move

    at_tick_interval(200) do
      @side = -@side
      @jink = false
    end

    @my_old_pos = sensors.position
    @my_old_health = sensors.health
  end


  def acquire_target
    heading = sensors.radar_heading + MAX_RADAR_ROTATION
    command.radar_heading, command.turret_heading = heading, heading
  end

  def get_radar_lock
    sensors.radar.first
  end

  def analyse_target
    return unless @target_old && @my_old_pos
    @old_target_point = point_at(@my_old_pos, @target_old)
    @new_target_point = point_at(sensors.position, @target)
    @target_heading = @old_target_point.heading(@new_target_point)
    @target_speed = RTanque::Point.distance(@old_target_point, @new_target_point)
  end

  def point_radar_at_target
    command.radar_heading = @target.heading
  end

  def point_turret_at_target
    return unless @target_old && @my_old_pos
    command.turret_heading = @leading_heading = calculate_leading_heading
  end

  def calculate_leading_heading
    @old_target_heading ||= @target_heading
    my_shot_pos = sensors.position
    target_pos = @new_target_point
    estimated_ticks = 0
    heading_change = @old_target_heading.delta(@target_heading)
    estimated_target_heading = @target_heading

    #puts "old: #{@old_target_heading.to_degrees}, new: #{@target_heading.to_degrees}, change: #{heading_change.to_f}"
    while sensors.position.distance(my_shot_pos) < sensors.position.distance(target_pos)
      estimated_ticks += 1
      estimated_target_heading += heading_change
      target_pos = target_pos.move(estimated_target_heading, @target_speed)
      #puts "  estimated_target_heading: #{estimated_target_heading.to_degrees}, target_pos: #{target_pos.x} #{target_pos.y}"
      my_shot_pos = sensors.position.move(sensors.position.heading(target_pos), RTanque::Shell.speed(FIRE_POWER) * estimated_ticks)
      break if estimated_ticks > 200
    end

    sensors.position.heading(target_pos)
  end

  def fire_at_target
    return unless @leading_heading
    if (@leading_heading.delta(sensors.turret_heading)).abs < TURRET_FIRE_RANGE
      command.fire(FIRE_POWER)
    else
      command.fire(nil)
    end
  end

  def get_behind_target
    return unless @target_heading
    if @jink
      @destination = sensors.position.move(sensors.heading + (RTanque::Heading::EIGHTH_ANGLE * 1.8 * @side), 200)
    else
      @destination = @new_target_point.move(@target_heading + (RTanque::Heading::EIGHTH_ANGLE * 3 * @side), 300)
    end

  end

  def move
    if @destination
      heading = sensors.position.heading(@destination)
      command.heading = heading
      speed = [sensors.position.distance(@destination) / 5, MAX_BOT_SPEED / 2].max
      if (sensors.heading.delta(heading)).abs > RTanque::Heading::EIGHTH_ANGLE * 2
        speed = -speed
      end
    else
      speed = MAX_BOT_SPEED
    end

    if @jink
      speed = -speed
    end

    command.speed = speed
  end

  def point_at(from, reflection)
    from.move(reflection.heading, reflection.distance)
  end

end

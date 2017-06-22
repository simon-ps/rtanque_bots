class MyDeadlyBot < RTanque::Bot::Brain
  NAME = 'my_deadly_bot'
  include RTanque::Bot::BrainHelper

  INTERVAL = 10000

  TURRET_FIRE_RANGE = RTanque::Heading::ONE_DEGREE

  FIRE_POWER = MAX_FIRE_POWER

  def initialize(arena)
    aw = arena.width
    ah = arena.height

    @positions = [[aw*0.2, ah*0.2], [aw*0.2, ah*0.8], [aw*0.8, ah*0.8], [aw*0.8, ah*0.2]]
    @position ||= 0
    super(arena)
  end

  def tick!
    @target ||= nil
    @target_old = @target

    # head right
    command.heading = RTanque::Heading.new(RTanque::Heading::EAST)
    # full speed ahead
    #command.speed = MAX_BOT_SPEED
    if @target = get_radar_lock
      point_radar_at_target
      point_turret_at_target
      fire_at_target
    else
      acquire_target
    end

    point = RTanque::Point.new(*@positions[@position], self.arena)
    move_to(point)

    if self.sensors.position.within_radius?(point, 20)
      @position = (@position + 1) % @positions.size
    end

    # every 100 ticks, log sensor info
    at_tick_interval(INTERVAL) do
      puts "Tick ##{sensors.ticks}!"
      puts " Gun Energy: #{sensors.gun_energy}"
      puts " Health: #{sensors.health}"
      puts " Position: (#{sensors.position.x}, #{sensors.position.y})"
      puts sensors.position.on_wall? ? " On Wall" : " Not on wall"
      puts " Speed: #{sensors.speed}"
      puts " Heading: #{sensors.heading.inspect}"
      puts " Turret Heading: #{sensors.turret_heading.inspect}"
      puts " Radar Heading: #{sensors.radar_heading.inspect}"
      puts " Radar Reflections (#{sensors.radar.count}):"
      puts " Fire speed (#{RTanque::Shell.speed FIRE_POWER}):"
      sensors.radar.each do |reflection|
        puts "  #{reflection.inspect}#{reflection.name} #{reflection.heading.inspect} #{reflection.distance}"
      end
    end

    @my_old_pos = sensors.position
  end

  def move_to(point)
    command.heading = self.sensors.position.heading(point)
    command.speed = [self.sensors.position.distance(point) / 10, 1].max
  end

  def acquire_target
    command.radar_heading = sensors.radar_heading + MAX_RADAR_ROTATION
  end

  def get_radar_lock
    sensors.radar.first
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

    at_tick_interval(INTERVAL) do
      puts "old_target_point: #{old_target_point}, new_target_point: #{new_target_point}"
    end

    target_speed = RTanque::Point.distance(old_target_point, new_target_point)

    my_shot_pos = sensors.position
    target_pos = new_target_point
    estimated_ticks = 0
    while sensors.position.distance(my_shot_pos) < sensors.position.distance(target_pos)
      estimated_ticks += 1
      target_pos = new_target_point.move(target_heading, target_speed * estimated_ticks)
      my_shot_pos = sensors.position.move(sensors.position.heading(target_pos), 5 + RTanque::Shell.speed(FIRE_POWER) * estimated_ticks)
      #break if my_shot_pos.on_wall? || target_pos.on_wall?
      break if estimated_ticks > 2000

      at_tick_interval(INTERVAL) do
        puts "my_shot_pos: #{my_shot_pos}, target_pos: #{target_pos}"
      end
    end

    # here, I know my_shot_pos is within 3 of estimated target_pos

    # this is inaccurate
    #estimated_ticks = @target.distance / RTanque::Shell.speed(FIRE_POWER)

    new_target_point = new_target_point.move(target_heading, estimated_ticks * target_speed)

    @leading_heading = sensors.position.heading(new_target_point)

    at_tick_interval(INTERVAL) do
      puts "Speed: #{target_speed}, Ticks: #{estimated_ticks}, Target heading: #{@target.heading.to_degrees}, New: #{new_target_point}, Leading Heading: #{@leading_heading.to_degrees}"
    end

    command.turret_heading = @leading_heading
  end

  def fire_at_target
    return unless @leading_heading
    if (@leading_heading.delta(sensors.turret_heading)).abs < TURRET_FIRE_RANGE
      command.fire(FIRE_POWER)
    end
  end

  def point_at(from, reflection)
    from.move(reflection.heading, reflection.distance)
  end

  def oldtick!
    ## main logic goes here

    # use self.sensors to detect things
    # See http://rubydoc.info/github/awilliams/RTanque/master/RTanque/Bot/Sensors

    # use self.command to control tank
    # See http://rubydoc.info/github/awilliams/RTanque/master/RTanque/Bot/Command

    # self.arena contains the dimensions of the arena
    # See http://rubydoc.info/github/awilliams/RTanque/master/frames/RTanque/Arena
  end
end

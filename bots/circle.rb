class Circle < RTanque::Bot::Brain
  NAME = 'circle'
  include RTanque::Bot::BrainHelper

  def tick!
    command.heading = sensors.position.heading(RTanque::Point.new(arena.width/2, arena.height/2, arena))
    command.speed = MAX_BOT_SPEED
  end
end

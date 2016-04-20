_ = require 'lodash'

DEFAULT_ACRES = 1000
DEFAULT_BUSHES = 2800

create_game = ()->
  {
  	year : 1,
  	starved : 0,
  	newcomers : 5,
  	population : 100,
  	acres : DEFAULT_ACRES,
  	bushels : DEFAULT_BUSHES,
  	harvest : 3,
  	rats : 200,
  	price : _.random(1, 10) + 16,
  	internal_acres : DEFAULT_ACRES,
  	internal_bushels : DEFAULT_BUSHES,
  	total_starved: 0
  }

has_plague = ()-> _.random(1, 100) <= 15

too_many_people_died = (game)-> game.starved / (game.population + game.starved - game.newcomers) >= 0.45

valid_seed = (game, tick_data)-> 0 <= tick_data.seed and tick_data.seed <= _.min([game.acres, 10 * game.population, game.bushels])
valid_feed = (game, tick_data)-> 0 <= tick_data.feed and tick_data.feed <= game.bushels
valid_acres = (game, tick_data)-> -game.acres <= tick_data.acres and tick_data.acres <= game.acres

is_valid_move = (context)-> _.all([valid_seed, valid_feed, valid_acres], (cb)-> cb(context.game_status, context.game_responses))

tick = (context)->
  game = context.game_status
  tick_data = context.game_responses
  if has_plague
    context.message.send('A horrible plague occured!\nHalf of your population died.')
    game.population = Math.floor(game.population / 2)
  game.year = game.year + 1
  game.starved = Math.max(0, game.population - Math.floor( tick_data.feed / 20))
  game.total_starved = game.total_starved + game.starved
  game.newcomers = Math.floor((20 * game.internal_acres + game.internal_bushels) / (100 * game.population)) + 1
  game.population = game.population - game.starved + game.newcomers;
  game.harvest = _.random(1, 8)
  game.bushels = game.internal_bushels + game.harvest * tick_data.seed
  game.rats = if has_rat_problems(game) then Math.max(0, Math.floor(_.random(1, 3) / 10) * game.bushels) else 0
  game.bushels = game.bushels - game.rats
  game.internal_bushels = game.bushels
  game.price = _.random(1, 10) + 16
  game.acres = game.acres = tick_data.acres
  game.starved = too_many_people_died(game)
  game.ended = game.year is 10

  game.perfomance = {
    avg_starved : game.total_starved / game.year
    acre_person : game.acres / game.population
  }
  return context


module.exports = {
  is_valid_move: is_valid_move
  create_game : create_game
  tick: tick
}

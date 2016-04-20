_ = require 'lodash'

DEFAULT_ACRES = 1000
DEFAULT_BUSHES = 2800

create_game = (base)->
  base ?= {}
  _.assigns(base,{
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
  	totalStarved: 0
  })

has_plague = ()-> _.random(1, 100) <= 15

tick = (context)->
  game = context.game_status
  tick_data = context.game_responses
  if has_plague
    population = Math.floor(game.population / 2)
  bushels = game.internal_bushels + game.harvest * tick_data.seed

# Deliberate game progression, not a claim about emergent learning or physiology.
# Add skills and recipe bindings here; the decision layer consumes forecasts only.
const GAME_SKILL_RULES = Dict(
    "acorn_preparation" => (scale=1.0, experience_scale=4.0, cap=3.0,
        thresholds=(0.7,1.5,2.3), taste_bonus=(-0.20,0.0,0.20,0.40)),
    "fish_cooking" => (scale=1.0, experience_scale=4.0, cap=3.0, thresholds=(0.7,1.5,2.3), taste_bonus=(-0.20,0.0,0.20,0.40)), "fishing" => (scale=1.0, experience_scale=4.0, cap=3.0,
        thresholds=(0.7,1.5,2.3), taste_bonus=(0.0,0.0,0.0,0.0)))
const GAME_RECIPE_SKILLS = Dict(3=>"acorn_preparation",5=>"fish_cooking")
const GAME_QUALITY_LABELS = ("rough","ordinary","good","excellent")
game_skill_mb()=D("type"=>"game_skill_mb","rule"=>"logarithmic-v1","experience"=>0.0,"completed"=>0)
function game_skill_forecast(mb,skill)
    rule=GAME_SKILL_RULES[skill]
    effect=min(rule.cap,rule.scale*log1p(get(mb,"experience",0.0)/rule.experience_scale))
    quality=1+count(t->effect>=t,rule.thresholds)
    (skill=skill,effect=effect,quality=quality,taste_bonus=rule.taste_bonus[quality])
end
function game_skill_complete!(mb,skill;product_quality=true)
    # This product uses pre-completion ability. Experience benefits the next one.
    forecast=game_skill_forecast(mb,skill)
    mb["experience"]+=1.0;mb["completed"]+=1
    product_quality && (mb["last_product_quality"]=forecast.quality)
    forecast
end
game_food_skill(kind)=get(GAME_RECIPE_SKILLS,Int(kind),nothing)
function game_food_bonus(kind,quality)
    kind==RDLBody.SALTED_FISH && return GAME_SKILL_RULES["fish_cooking"].taste_bonus[quality]
    raw=findfirst(k->RDLBody.FOOD_PROCESS_OUTPUT[k]==kind,RDLBody.FOOD_KIND_IDS)
    raw===nothing && return 0.0
    skill=game_food_skill(raw)
    skill===nothing ? 0.0 : GAME_SKILL_RULES[skill].taste_bonus[quality]
end

# 暫定固定: local request vocabulary/production and appearance-to-food grounding.
# Not normal-life policy. Replace authored wording/grounding with learned roles.
const WANT_FISH=(kind=8,word="塩焼き魚",request_word="欲しい",appearance="fish-form",
 utterance_us=3_000_000,trials=32,stock=20,teaching_samples=3)
function want_fish_interest(body,stock,known,words;security=nothing)
 words===nothing && return nothing
 WANT_FISH.request_word in split(words.text) || return nothing
 any(m->m.prediction.appearance==WANT_FISH.appearance,known) || return nothing
 fish_count=stock[WANT_FISH.kind]
 fish_count>0 || return nothing
 need=LW.trade_food_need(body,nothing,stock;security)
 # Own stock and the existing food-security forecast; no caller's hidden state.
 log1p(fish_count)*(1-clamp(need,0.,1.))
end
function want_fish_vocabulary()
 vocabulary=ObservedVocabulary()
 for i in 1:WANT_FISH.teaching_samples
  learn_observed_words!(vocabulary,(id="fish-teaching:$i",text=WANT_FISH.word,
   motion=nothing,appearances=[WANT_FISH.appearance]))
 end
 vocabulary
end

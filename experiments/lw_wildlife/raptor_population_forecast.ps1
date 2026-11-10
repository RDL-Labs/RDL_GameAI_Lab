# Forecast cutoff is fixed before reading later outcomes. Scenario ranges are not confidence intervals.
$root='C:/Users/ken_m/Documents/Codex'
$initial=Get-Content "$root/raptor150-near3-90d-20261110/result.json" -Raw|ConvertFrom-Json
$rows=@($initial.daily)+@(Get-Content "$root/raptor-near3-continue360d-20261110/daily.jsonl"|ForEach-Object {$_|ConvertFrom-Json}|Where-Object {$_.absolute_day -le 232})
$current=$rows|Where-Object {$_.absolute_day -eq 232}
$birdRate=100/($current.raptor.eaten/$current.raptor.captures)
$scenarios=foreach($window in @(30,60,90)){
 $before=$rows|Where-Object {$_.absolute_day -eq (232-$window)}
 $birthRate=($current.births-$before.births)/$window
 $starveRate=($current.starvation-$before.starvation)/$window
 $captures=$current.predators[0].captures-$before.predators[0].captures
 $spent=$current.predators[0].spent-$before.predators[0].spent
 $eaten=$current.predators[0].eaten-$before.predators[0].eaten
 $predatorRate=($spent/$window)/($eaten/$captures)
 $n=[double]$current.rabbits;$birdPresent=$false;$arrival=$null;$departure=$null;$trajectory=@()
 for($day=233;$day -le 450;$day++){
  if(!$birdPresent -and $n -ge 150){$birdPresent=$true;if($null -eq $arrival){$arrival=$day}}
  elseif($birdPresent -and $n -le 100){$birdPresent=$false;if($null -eq $departure){$departure=$day}}
  $n=[math]::Max(0.0,$n+$birthRate-$starveRate-$predatorRate-$(if($birdPresent){$birdRate}else{0}))
  $trajectory+= [ordered]@{day=$day;rabbits=$n;bird=$birdPresent}
 }
 [ordered]@{window=$window;births_per_day=$birthRate;starvation_per_day=$starveRate;predator_spent_per_day=$spent/$window;predator_effective_meal=$eaten/$captures;predator_captures_per_day=$predatorRate;bird_captures_per_day=$birdRate;growth_bird_absent=$birthRate-$starveRate-$predatorRate;growth_bird_present=$birthRate-$starveRate-$predatorRate-$birdRate;first_arrival=$arrival;first_departure=$departure;final_rabbits=$n;trajectory=$trajectory}
}
$report=[ordered]@{cutoff_day=232;initial_rabbits=105;target_day=450;bird_rate=$birdRate;assumptions='Constant window-specific birth/starvation and effective meal yields; one live ground predator; bird daily hysteresis 150/100; deterministic expected counts, not confidence intervals; ignores demographic lag and spatial accessibility.';scenarios=$scenarios}
$report|ConvertTo-Json -Depth 15|Set-Content (Join-Path $PSScriptRoot 'evidence/raptor-forecast-cutoff232.json')
$scenarios|ForEach-Object {[pscustomobject]$_ | Select-Object window,births_per_day,predator_captures_per_day,growth_bird_absent,growth_bird_present,first_arrival,first_departure,final_rabbits|ConvertTo-Json -Compress}
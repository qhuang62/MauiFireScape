; declare patch variables
patches-own [
  city-id
  has-house?
  has-tree?
  has-power-line?
  is-powered?
  power-line-affected?
  has-power-station?
  flammable
  on-fire
  burned-out
]

; declare turtle variables
turtles-own [
  role  ; role: "house", "tree", "power-line", "power-station", "resident"
  evacuation-status ; "safe", "evacuating", "trapped"
  evacuation-speed  ; how quickly the resident moves
  risk-perception   ; individual perception of fire risk
]

; declare global variables
globals [
  setup-done?
  total-houses
  houses-without-power
  total-trees
  total-power-stations
  total-power-lines
  total-burning
  total-burned
  burned-trees
  initial-flammables
  percent-burned-houses
  percent-burned-trees

  ; evacuation-related globals
  total-residents
  evacuation-rate
  trapped-residents-count
  evacuating-residents-count
  successfully-evacuated-residents-count
  wind-speed-value      ;; the speed of the wind (controlled by a slider)
  wind-direction-value  ;; the direction of the wind (angle from 0 to 360 degrees)
]

breed [fires fire]      ;; active fire
breed [embers ember]    ;; fading fire
breed [residents resident] ;; people in houses

to setup
  clear-all
  set setup-done? false
  setup-landscape
  setup-houses
  setup-forest
  setup-power-stations
  setup-power-lines
  setup-residents  ; initialize residents
  calculate-initial-flammables
  update-monitors
  reset-ticks
  set setup-done? true
end

to setup-landscape
  ; divide map into blocks for city zones
  ask patches [
    if pxcor mod 10 = 0 or pycor mod 10 = 0 [
      set pcolor gray  ;; Roads
    ]
    ifelse pxcor < 0 [
      set city-id 1
      set pcolor violet + 1 ;; housing Community
    ] [
      set city-id 2
      set pcolor white  ;; forest Area
    ]
    ; initialize attributes
    set has-house? false
    set has-tree? false
    set has-power-line? false
    set has-power-station? false
    set flammable false  ;; default to non-flammable
    set on-fire false
    set burned-out false
  ]
end

to setup-houses
  ; add houses based on the house-density slider
  let house-patches n-of ((house-density / 100) * count patches with [city-id = 1 and not has-house? and pcolor != gray]) patches with [city-id = 1 and not has-house? and pcolor != gray]
  ask house-patches [
    set has-house? true
    set flammable true  ;; houses are flammable
    sprout 1 [
      set role "house"
      set shape "house"
      set color white
      set size 0.8
    ]
  ]

  ; add scattered trees in the housing community
  let house-trees-patches n-of ((house-density / 200) * count patches with [city-id = 1 and not has-house? and not has-tree? and pcolor != gray]) patches with [city-id = 1 and not has-house? and not has-tree? and pcolor != gray]
  ask house-trees-patches [
    set has-tree? true
    set flammable true  ;; trees are flammable
    sprout 1 [
      set role "tree"
      set shape "tree"
      set color green
      set size 0.7
    ]
  ]
end

to setup-forest
  ; add trees in the forest area based on the forest-density slider
  let forest-patches n-of ((forest-density / 100) * count patches with [city-id = 2 and not has-tree? and pcolor != gray]) patches with [city-id = 2 and not has-tree? and pcolor != gray]
  ask forest-patches [
    set has-tree? true
    set flammable true
    sprout 1 [
      set role "tree"
      set shape "tree"
      set color green
      set size 0.7
    ]
  ]
end

to setup-power-stations
  let housing-patches patches with [city-id = 1 and pxcor mod 10 = 5 and pycor mod 10 = 5]
  let forest-patches patches with [city-id = 2 and pxcor mod 10 = 5 and pycor mod 10 = 5]

  ; total number of power stations
  let total-stations #power-station
  let housing-stations floor (total-stations * 0.6)  ;; 60% for housing area
  let forest-stations total-stations - housing-stations  ;; remaining for forest

  ; design: when there is only 1 power station it will be in the housing area only;
  ; if 2, one on each; if more than 2, there will always be more power stations in urban than forest when not even #
  if (total-stations = 1) [
    set housing-stations max list housing-stations 1
    set forest-stations max list forest-stations 0
  ]

  ; ensure at least one in each area if applicable
  if (total-stations >= 2) [
    set housing-stations max list housing-stations 1
    set forest-stations max list forest-stations 1
  ]

  ; debug: adjust to avoid placing more than total-stations
  if (housing-stations + forest-stations > total-stations) [
    set forest-stations total-stations - housing-stations
  ]

  ; place power stations in the housing area
  let selected-housing-patches n-of housing-stations housing-patches
  ask selected-housing-patches [
    set has-power-station? true
    sprout 1 [
      set role "power-station"
      set shape "circle"
      set color blue
      set size 1.5
    ]
  ]

  ; place power stations in the forest area
  let selected-forest-patches n-of forest-stations forest-patches
  ask selected-forest-patches [
    set has-power-station? true
    sprout 1 [
      set role "power-station"
      set shape "circle"
      set color blue
      set size 1.5
    ]
  ]
end

to setup-power-lines
  ; place power lines in the landscape, typically between houses and power stations
  let valid-patches patches with [city-id = 1 or city-id = 2]
  ask n-of (total-power-lines * count valid-patches / 100) valid-patches [
    set has-power-line? true
    set power-line-affected? false  ; initially, power lines are not affected by fire
    sprout 1 [
      set role "power-line"
      set shape "line"
      set color gray
      set size 0.5
    ]
  ]
end



to setup-residents
  ; create residents in houses
  ask patches with [has-house?] [
    sprout 1 [
      set breed residents
      set role "resident"
      set shape "person"
      set color blue
      set evacuation-status "safe"
      set evacuation-speed (0.5 + random-float 0.5)  ; varied movement speeds
      set risk-perception (0.5 + random-float 0.5)   ; individual risk perception
    ]
  ]
end

to calculate-initial-flammables
  ; count the initial number of flammable patches
  set initial-flammables count patches with [flammable]
  set burned-trees 0
end

to setup-wind
  set wind-speed-value wind-speed  ;; the speed of the wind from the slider
  set wind-direction-value wind-direction  ;; the direction of the wind from the slider
end

to update-monitors
  ; monitor current status of various elements in the simulation
  set total-houses count turtles with [role = "house"]
  set total-trees count turtles with [role = "tree"]
  set total-power-stations count turtles with [role = "power-station"]
  set total-power-lines count turtles with [role = "power-line"]

  ; monitor the patches that are currently burning (on-fire = true)
  set total-burning count patches with [on-fire]

  ; monitor the patches that have burned out (burned-out = true)
  set total-burned count patches with [burned-out]

  ; calculate houses without power
  let houses-with-power count turtles with [
    role = "house" and not (color = gray or burned-out)
  ]
  set houses-without-power total-houses - houses-with-power

  ; calculate percentage of burned houses
  ifelse total-houses > 0 [
    set percent-burned-houses (count turtles with [role = "house" and burned-out] / total-houses) * 100
  ] [
    set percent-burned-houses 0
  ]

  ; calculate percentage of burned trees
  ifelse total-trees > 0 [
    set percent-burned-trees (count turtles with [role = "tree" and burned-out] / total-trees) * 100
  ] [
    set percent-burned-trees 0
  ]

  ; monitor evacuation status
  set total-residents count residents
  let evacuated count residents with [evacuation-status = "evacuating"]
  let trapped count residents with [evacuation-status = "trapped"]
  let evacuated-successfully count residents with [evacuation-status = "evacuated"]  ; count successfully evacuated residents

  ; monitor evacuating residents
  set evacuating-residents-count evacuated  ; Set the value for the monitor

  ; calculate evacuation rate
  ifelse total-residents > 0 [
    set evacuation-rate (evacuated / total-residents) * 100
  ] [
    set evacuation-rate 0
  ]

  ; set the number of successfully evacuated residents in the monitor
  set successfully-evacuated-residents-count evacuated-successfully

  set trapped-residents-count trapped
end



to ignite
  ; determine the area based on the chooser value
  let ignition-patch nobody
  if start-location = "forest" [
    set ignition-patch one-of patches with [city-id = 2 and flammable]
  ]
  if start-location = "house" [
    set ignition-patch one-of patches with [city-id = 1 and flammable]
  ]
  if start-location = "power station" [
    set ignition-patch one-of patches with [has-power-station? and flammable]
  ]

  ; ignite the selected patch if it's valid
  if ignition-patch != nobody [
    ask ignition-patch [
      set on-fire true
      set pcolor red  ;; change patch color to indicate fire
      sprout 1 [
        set breed fires
        set size 2
        set color red
      ]
    ]
  ]
end



; fire spread logic with spread rate and wind speed
to spread-fire
  ; spread fire to neighboring flammable patches with an increased probability depending on wind speed and direction
  ask fires [
    let spread-chance fire-spread-rate  ;; start with the normal spread rate

    ; adjust spread chance based on wind direction
    let fire-direction (towards one-of neighbors4)  ;; fire direction towards neighbors (can be modified as needed)
    let wind-diff (abs (wind-direction - fire-direction))  ;; difference between wind direction and fire direction

    ; wind increases spread rate in the direction of the wind
    ifelse wind-diff < 45 [  ;; if wind is within 45 degrees of fire direction, fire spreads faster
      set spread-chance spread-chance + (wind-speed / 10)
    ]
    [  ;; if wind is opposite direction, fire spreads slower
      set spread-chance spread-chance - (wind-speed / 20)
    ]

    ; limit spread chance to be between 0 and 100
    set spread-chance min list 100 max list 0 spread-chance

    ask neighbors4 with [flammable and not on-fire and not burned-out] [
      if random 100 < spread-chance [
        set on-fire true
        set pcolor red
        sprout-fires 1 [ set color red ]
      ]
    ]

    ; if the fire is at a power station, trigger power outage
    if role = "power-station" [
      cause-power-outage
    ]

    ; mark burned entities
    if role = "house" [
      set burned-out true
      set color black  ; black for burned
    ]
    if role = "tree" [
      set burned-out true
      set color black  ; black for burned
    ]

    ; turn the current fire into embers
    set breed embers
  ]

  ; update the patches with fire
  ask patches with [on-fire] [
    if has-power-line? [
      set power-line-affected? true  ; mark power line as affected
      ask turtles in-radius 1 [
        set color red  ; change color of affected power lines
      ]
    ]
  ]
end


to fade-embers
 ; gradually fade embers and mark patches as burned
 ask embers [
   set color color - 0.3
   if color < red - 3.5 [
     set pcolor black
     set burned-out true
     die
   ]
 ]
end

to update-power-grid
  ; check if power stations or power lines are affected by fire
  let active-power-stations patches with [has-power-station? and not burned-out]

  ; update power status for houses
  ask patches with [has-house?] [
    ifelse any? active-power-stations with [distance myself < 10] ;; adjust range as necessary
    [
      set is-powered? true
    ]
    [
      set is-powered? false
    ]
  ]

  ; update power-line status
  ask patches with [has-power-line?] [
    if on-fire [
      set power-line-affected? true
    ]
  ]
end



to cause-power-outage
  ; identify all houses connected to this power station within a radius of 10 patches
  let connected-houses patches in-radius 10 with [has-house? and has-power-line?]

  ask connected-houses [
    ; mark houses as without power
    ask turtles-here with [role = "house"] [
      set color gray  ; gray for no power
    ]
  ]

  ; update the count of houses without power
  set houses-without-power count turtles with [role = "house" and color = gray]

  ; trigger residents' evacuation or other impacts if affected houses have no power
  ask residents [
    if any? turtles-here with [color = gray] and evacuation-status = "safe" [
      set evacuation-status "evacuating"
      set color yellow  ; change color to indicate evacuation
    ]
  ]

  ; marking residents as trapped
  ask residents with [evacuation-status = "evacuating"] [
    if count fires in-radius 3 > 0 [
      set evacuation-status "trapped"
      set color red  ; visually indicate trapped residents as red
    ]
  ]
end


to evacuate
  ask residents [
    ; trigger evacuation based on proximity to fire and risk perception
    if any? fires in-radius (10 * risk-perception) and evacuation-status = "safe" [
      set evacuation-status "evacuating"
      set color yellow  ; change color to show evacuation
    ]

    ; evacuating residents move towards bottom and randomly in x-direction
    if evacuation-status = "evacuating" [
      let new-x xcor + (random-float (2 * evacuation-speed) - evacuation-speed)  ; random move in x-direction
      let new-y ycor - evacuation-speed  ; move towards the bottom (y-direction)

      ; ensure movement stays within world boundaries
      ifelse (new-x >= min-pxcor and new-x <= max-pxcor) and
             (new-y >= min-pycor and new-y <= max-pycor) [
        move-to patch new-x new-y
      ] [
        ; adjust coordinates to stay within bounds
        let bounded-x max list min-pxcor (min list max-pxcor new-x)
        let bounded-y max list min-pycor (min list max-pycor new-y)
        move-to patch bounded-x bounded-y
      ]
    ]

    ; check if trapped (still near fires)
    if count fires in-radius 3 > 0 [
      set evacuation-status "trapped"
      set color red  ; Visually indicate trapped residents
    ]

    ; check if the resident has successfully evacuated (reached the bottom of the screen)
    if ycor <= min-pycor + 1 and evacuation-status = "evacuating" [
      set evacuation-status "evacuated"
      set color green  ; Color green to indicate successful evacuation
    ]
  ]
end


to go
  if not setup-done? [
    user-message "Please press the SETUP button to initialize the model before pressing GO."
    stop
  ]
  if count patches with [on-fire] = 0 [
    ignite
  ]
  spread-fire
  fade-embers
  evacuate  ; New evacuation step
  update-monitors
  tick
end
@#$#@#$#@
GRAPHICS-WINDOW
351
10
832
492
-1
-1
14.33333333333334
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
162
22
228
55
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
87
22
150
55
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
12
169
137
202
#power-station
#power-station
0
5
2.0
1
1
NIL
HORIZONTAL

MONITOR
165
299
245
344
NIL
total-houses
0
1
11

MONITOR
80
299
156
344
NIL
total-trees
17
1
11

SLIDER
10
90
135
123
forest-density
forest-density
0
100
85.0
1
1
NIL
HORIZONTAL

SLIDER
11
129
136
162
house-density
house-density
0
100
42.0
1
1
NIL
HORIZONTAL

PLOT
856
13
1243
159
Percent Burned
Time (ticks)
%
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Houses" 1.0 0 -10141563 true "" "plot percent-burned-houses"
"Trees" 1.0 0 -15040220 true "" "plot percent-burned-trees"

PLOT
856
171
1245
321
Power Supply & Resident Status
Time (ticks)
Count
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Houses with Power" 1.0 0 -16777216 true "" "plot count turtles with [role = \"house\" and not burned-out and not has-power-line?]"
"Evacuating Residents" 1.0 0 -14730904 true "" "plot count residents with [evacuation-status = \"evacuating\"]"
"Trapped Residents" 1.0 0 -2674135 true "" "plot count residents with [evacuation-status = \"trapped\"]"

MONITOR
240
498
339
543
NIL
evacuation-rate
1
1
11

MONITOR
169
380
338
425
NIL
trapped-residents-count
0
1
11

MONITOR
15
380
154
425
NIL
total-burned
0
1
11

CHOOSER
235
167
343
212
start-location
start-location
"forest" "house" "power station"
0

MONITOR
15
432
154
477
NIL
houses-without-power
17
1
11

SLIDER
182
90
342
123
fire-spread-rate
fire-spread-rate
0
100
85.0
1
1
NIL
HORIZONTAL

SLIDER
12
211
173
244
wind-speed
wind-speed
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
12
252
173
285
wind-direction
wind-direction
0
360
212.0
1
1
NIL
HORIZONTAL

SLIDER
182
128
343
161
fire-spread-speed
fire-spread-speed
0
100
100.0
1
1
NIL
HORIZONTAL

MONITOR
168
433
339
478
NIL
evacuating-residents-count
17
1
11

TEXTBOX
5
73
176
91
Environmental Parameters
12
0.0
1

TEXTBOX
255
73
283
91
Fire
12
0.0
1

TEXTBOX
125
360
202
378
Observations
12
0.0
1

@#$#@#$#@
## WHAT IS IT?

This model simulates the dynamics of wildfire spread, its impact on power infrastructure, and human evacuation behavior. It demonstrates how environmental factors (e.g., wind dynamics), infrastructure vulnerabilities (e.g., power grid disruptions), and human decisions interact during extreme weather events, helping to analyze the resilience of communities under such scenarios.

## HOW IT WORKS

Agents in the model, including houses, residents, trees, power lines, and power stations, interact within a dynamic environment.

Fire Spread: Fires propagate probabilistically based on proximity, wind speed, wind direction, and the flammability of nearby entities.

Power Outages: Fires affecting power stations cause cascading power failures that impact connected houses.

Resident Behavior: Residents evaluate their safety based on proximity to fires, power availability, and risk perception, deciding whether to evacuate. Evacuation behavior adjusts dynamically as conditions change.

## HOW TO USE IT

Inputs (Sliders and Options in the Interface Tab):

Forest Density: Adjusts the density of forested areas (0–100).

House Density: Sets the number of houses (0–100).

Number of Power Stations: Changes the count of power stations (1–5).

Wind Speed and Direction: Determines the intensity (0–100) and angle (0–360°) of wind.

Fire Spread Rate/Speed: Controls how quickly the fire moves and propagates (0–100).

Fire Start Location: Selects where the fire ignites (forest, house, or power station).


Outputs (Monitors and Graphs):

Patches Burned: Displays the percentage of forest and urban areas affected by fire.

Houses Without Power: Tracks power outages.

Evacuation Rate: Monitors the number of residents evacuated or trapped.

Graphs: Show forest/house burning percentages, power supply trends, and resident statuses over time.


## THINGS TO NOTICE

Observe how wind direction and speed influence fire propagation.

Watch the cascading effects when power stations are damaged, and how that impacts evacuation behavior.

Note the interplay between forest density and fire spread rate on the extent of the disaster.

## THINGS TO TRY

Experiment with different forest and house densities to observe the system’s sensitivity to these variables.

Simulate high wind speeds combined with multiple fire start locations to assess worst-case scenarios.

Vary the number of power stations to study how infrastructure distribution affects system resilience.

## EXTENDING THE MODEL

Add dynamic wind changes during the simulation to reflect more realistic weather patterns.

Introduce different evacuation strategies (e.g., shelter-in-place vs. early warning systems).

Incorporate additional agent types, such as emergency responders or vehicles, to simulate rescue efforts.

Enhance the power grid model to include redundancy or alternative energy sources.

## NETLOGO FEATURES

The model uses NetLogo’s turtles and patches to simulate agent interactions in a spatial grid.

Wind dynamics are implemented using patch-based diffusion to influence fire spread directionally.

Cascading power outages are modeled using agent links, connecting houses to power stations.

## RELATED MODELS

Fire Models: Built-in NetLogo library models, such as “Fire” and “Forest Fire.”
Epidemic Models: Related models that simulate spread dynamics over networks.
Urban Dynamics: Models exploring urban growth and disaster interactions.

## CREDITS AND REFERENCES

This model was developed as part of a study on climate adaptation using Agent-Based Models.
Based on foundational work by Wilensky & Rand (2015) in Introduction to Agent-Based Modeling.
URL for the model: housetreesfire.html.
References: Siam et al., 2022; other citations used in the research.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@

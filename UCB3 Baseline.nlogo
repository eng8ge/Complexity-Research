; Developed by Ken Comer to evaluate kinematic activity in the Bay of Biscay
breed [uboats uboat] ; There is only one kind of U-boat
uboats-own [dest speed submerged? status dived? battery transittime lastescape]
breed [s25s s25]
s25s-own [fuel speed nearest patrol? outbound? pathrs contacts]
globals [Brest LOrient SaintNazere Plymouth LaRochelle Bordeaux
  deployed encounters totalpatrolhrs opportunities escapes ttimes s25-arrate
  ports ocean]
patches-own [
  region ; the number of the region that the patch is in, patches outside all regions have region = 0
]



To Setup
  __clear-all-and-reset-ticks
  import-pcolors "Bay_of_Biscay_Short.bmp"
  set Brest patch 418 316
  set LOrient patch 434 280
  set SaintNazere patch 471 256
  set LaRochelle patch 546 201
  set Bordeaux patch 560 171
  set Plymouth patch 435 440
  set-default-shape uboats "suboat"
  set-default-shape s25s "airplane 2"
  set ports (list Brest lorient saintnazere larochelle bordeaux)
  set ocean patches with [pcolor = 9.9]
  set deployed 0
  set encounters 0 ; The number of minute-turns in which a surfaced U-boat is in cone of an S25
  set totalpatrolhrs 0
  set opportunities 0 ; The number of minute-turns in which a U-boat (surfaced or dived) is in cone of an S25
  set escapes 0
  set ttimes []
  set s25-arrate ph-generator / 4000 * 0.013 ; the s.25 arrival rate from slider

End ; setup

To Go
;  ask agents Move
  if ticks < 2 [StartUboat]
  if random-float 1 < 0.0013 [StartUboat]
  if random-float 1 < s25-arrate [StartS25] ; gives about 4K TPH
  ask turtles [move]
  ask s25s [search] ; Search after you turn, submarines set status, check fuel
  Tick
  if ticks = 43204 [stop] ; Each run lasts 30 days
End  ;go

To StartUBoat ; This procedure creates a U-boat at one of the ports and sends it west.
  create-uboats 1 [
    set size 10
    set speed 10  ; Uboats transit from the coast at 10 kts.
    move-to one-of ports ; Randomly start at one of the ports.
    set heading 275 + random 35  ; Fan out randomly.
    set dived? FALSE  ; Surfaced transit.
    set status "egress" ; Ensures it doesn't dive during egress
    set transittime 0 ; I'm going to determine total minutes to transit
    set lastescape 0  ; Used to avoid double-counting escapes.

  ]
End ; Create Uboat

To StartS25
  create-S25s 1 [
    set size 20
    move-to Plymouth
    set heading 200 + random 50
    set fuel 100
    set label-color 10
    set patrol? FALSE    ; Used to measure TPH and limit search subroutine
    set outbound? TRUE   ; Used to transition to patrol on outbound leg
    set pathrs 0
    set contacts []
  ]
End ; StartS25

To Move ;Actual movement in the main command. This depletes fuel and battery.
  if (breed = uboats) [
    fd speed / 60
    set transittime transittime + 1
    if-else dived? [  ; Consume battery for submerged submarines
      set battery battery - .25 ; Battery life 5.2 hrs
      if battery < 20 [surface] ; Battery too low to stay down
    ] [               ; Charge battery for surfaced submarines
      if battery < 100 [set battery battery + .3] ; Recharge in 4.33 hrs
      if maxsubmergence? [
        if battery > 98 [submerge] ; battery full, dive in Max Submgnce
      ]
    ] ; if-else dived?
    checkPosition ; Transition egress to transit or transit to done
  ] ; ask uboats
; Now for the s25s
  if (breed = s25s) [
    fd airspeed / 60
    set fuel fuel - 0.12 ; Gives 10.4 hours operational flight before RTB
    if-else labels? [set label round pathrs] ; For visual debugging
    [set label ""]
    checkStatus          ; Transition to patrol, Maneuver in the box, check fuel, Land
  ]

End ; move

to CheckPosition  ;Uboats look at what its doing
  if xcor < 370 [ ; Check to see if I'm in the op area
    if status = "egress" [ ; if I just entered the op area...
      submerge             ; dive and chamge my status to transit
      set status "transit"
    ] ; a transiting, non-dived uboat
  ]
  if xcor < 100 or ycor > 520 [         ; If I've reached the North Atlantic...
    set deployed deployed + 1   ; Add me to the tally of deployed Uboats
    set ttimes lput transittime ttimes
    die                  ; And remove me from the model
  ]
end ; CheckPosition for Uboats

to CheckStatus ;After S25 moves, check to see if they need to change something
  if outbound? [
    if xcor < 340 [
      set patrol? TRUE
      set outbound? FALSE
      set heading 235
    ]
  ]

  if patrol? [
    if xcor > 360 [ ; Eastern boundary, head West
      set heading 225 + random 90
    ]
    if xcor < 190 [ ; Western boundary, head East
      set heading 45 + random 90
    ]
    if ycor < 200 [ ; Southern boundary, head North
      set heading 295 + random 90
    ]
    if ycor > 430 [ ; Northern boundary, head South
      set heading 135 + random 90
    ]
   if fuel < 25
     [face Plymouth
      set patrol? FALSE
    ] ; RTB Out of gas
    set pathrs pathrs + 1 / 60
  ] ; end of "if on patrol block"



  if ycor > 444 ;arrived at Plymouth
    [set totalpatrolhrs totalpatrolhrs + pathrs
     die]
end ; S25 status

to search ; Executed by every S25 every turn.
  if not patrol? [stop] ; non-patrolling aircraft should not be searching
  if count uboats < 1 [stop] ; No use searching an empty ocean.

  let target-set uboats in-cone S25-vision cone-angle ; Creates the set of all uboats in my cone
  if count target-set > 0 [   ; There's a Uboat in the cone
    let target min-one-of (uboats) [distance myself] ; Don't look for closest unless there's one in the cone.
    set nearest distance target

    if (member? target target-set) [ ; True if target is in my cone, false if nearest uboat is outside cone
;    user-message(word "Target is in the cone. Who is: " who)
      set opportunities opportunities + 1 ; Count number of turns a U-boat is in the cone of an S25
      ask target [

           if-else not dived? [
;        user-message(word "Uboat in cone of: " who "and surfaced. Battery: " round battery)
              if dived? [user-message("I am submerged!")]
              if random-float 1 < 0.1 [ ; S25s attack only 10% of what they CAN see (surfaced, in their cone) per turn.
                 ask myself [attack]
           ]
              set encounters encounters + 1  ; I count all encounters S25 to surfaced U-bot per turn, not all attacks.
          ; Note the above statment may count multiple encounters for the same interaction.
           ] ; end if target is surfaced, now else (target is dived in the cone)
           [ ; Target is selected but is dived, so...
           if (ticks - 1) > lastescape [ ; This target was NOT escaping last run. This UBoat skipped a turn in this loop.
            ; Note: this if condition means escapes are counted only once while opportunities & encounters happen every min.
             set escapes escapes + 1] ; Counts the number a submerged U-boats pass under an S25 detection cone (overall, not per min)
           set lastescape ticks ; Links this minute to the next in case I'm still in the cone.
           ]; target was dived
       ] ; stop asking target to do things
    ] ; Closest uboat in the cone selected.
  ] ; There's a uboat in the cone
  ask uboats in-cone uboatvision 360 [ ; Finds Uboats that can see me out to their vision.
    if not dived? [
;  user-message(word "Uboat crash dives. Battery: " round battery)


    submerge ; and asks them to dive if they are not dived already.
    ] ; This allows half to escape
  ]
end ; search

to submerge
  set shape "uuboat"
  set speed 2
  set dived? TRUE
;  let attacker min-one-of (s25s) [distance myself]  ;these report distance to nearest Sunderland
;  let disttoS25 distance attacker  ;
;  user-message(word "Uboad dived, plane is nm: " disttos25)
end ;

to snort
  set shape "uboat"
  set speed 5
  set dived? FALSE
end

to surface
  set shape "suboat"
  set speed UT-speed
  set dived? FALSE
end

to attack
  watch-me
;  wait 15
  set shape "attacking"
  set patrol? FALSE
  face plymouth
end ; attack

; to-report intvalue [x]
;  set x round x
;  report x
; end
@#$#@#$#@
GRAPHICS-WINDOW
145
10
814
565
-1
-1
1.0
1
10
1
1
1
0
1
1
1
0
660
0
545
0
0
1
ticks
30.0

BUTTON
78
145
141
178
NIL
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
5
144
69
177
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
7
61
64
106
Uboats
count uboats
0
1
11

MONITOR
7
10
64
55
Days
ticks / 1440
2
1
11

MONITOR
8
291
65
336
Gone
deployed
0
1
11

MONITOR
69
360
136
405
Encounters
Encounters
0
1
11

SWITCH
820
13
923
46
Labels?
Labels?
1
1
-1000

MONITOR
76
10
133
55
TPH
totalpatrolhrs
1
1
11

MONITOR
8
359
61
404
Escapes
escapes
0
1
11

MONITOR
8
410
96
455
Opportunities
opportunities
17
1
11

SLIDER
818
345
990
378
UBoatVision
UBoatVision
0
30
8.0
1
1
nm
HORIZONTAL

SWITCH
819
307
978
340
MaxSubmergence?
MaxSubmergence?
0
1
-1000

MONITOR
7
239
120
284
Mean Transit Time
mean ttimes / 60
1
1
11

SLIDER
818
122
990
155
cone-angle
cone-angle
90
360
180.0
1
1
deg
HORIZONTAL

TEXTBOX
864
107
1014
125
RAF Controls
11
0.0
1

TEXTBOX
845
288
995
306
U-Boat Flotte Controls\n
11
0.0
1

SLIDER
818
160
990
193
S25-Vision
S25-Vision
1
100
7.0
1
1
nm
HORIZONTAL

SLIDER
818
198
990
231
Airspeed
Airspeed
100
250
155.0
5
1
kts
HORIZONTAL

SLIDER
819
235
991
268
PH-Generator
PH-Generator
2000
5000
4000.0
100
1
hours
HORIZONTAL

SLIDER
819
386
991
419
UT-Speed
UT-Speed
3
15
6.0
.1
1
kts
HORIZONTAL

@#$#@#$#@
# A Model of the U-boat Campaign in the Bay of Biscay (UCBB)

This is a "baseline" ABM of the Allied campaign to interdict Nazi U-boats as they sortied from the five ports in occupied France to the North Atlantic. It can be adapted to answer any of a large number of questions regarding search theory, especially the many-on-many search for a population of evasive targets. This creates, in NETLOGO, a computational approach to a problem that had been evaluated using mathematical search theory and game theory. 

## Historical Background

The Battle of the Bay of Biscay began in late 1940 and lasted until early 1944. Activity did not begin in earnest until late 1941, and data only becomes available in January 1942. By the spring of 1944 the British had nearly complete dominance of the approaches to the French coast. Submarine deployments after that point were limited to small numbers and transits nearly stopped completely after D-Day (June 1944). 

This model was built around the high-tempo operations of 1942 and 1943. It was a battle between the German submarine force and the Royal Air Force. For the most part these were German Type VIIC submarines and British Short Sunderland (S.25) four-engine ASW aircraft. The British were based in Plymouth and the Germans were evenly spread among the five U-boat bases. U-boats in port were protected by thick concrete "pens" that are so indestructible that they remain in these five ports to this day. The only way to counter a U-Boat was to sink it at sea.

The German mission was to move the U-boats to the North Atlantic where they would attack convoys. The UK mission was to sink as many transiting U-boats as possible, and to delay the others. British operations research co-founder Arthur Waddington referred to the British goal as the creation of an "unclimable fence". The fence would be so wide that a U-boat could not traverse it completely submerged. This years-long operation was seen by both sides as critical to victory. Winston Churchill famously said, "The only thing that ever really frightened me during the war was the U-Boat peril." 

## ASW The Birth of Operations Research

The field of operations research began with the U-boat problem in World War II. In both the US and Britain multidisciplinary teams gathered to analyze and optimize antisubmarine operations. There were no computers -- this was a painstaking mathematical exercise. Scientists, statisticians, and mathematicians together determined the best search patterns, the best tactics, the best flight schedules, and the best use of new technology. 

The shift to simulation in answering ASW questions was slow, mostly because of the mathematical legacy and the prestige of the WWII practitioners. Much later, during the Cold War, the scientists working this issue gave grudging acceptance to computational approaches. In reality, there are so many interacting irregular components of the ASW process that a pure mathematical solution can only be achieved through crippling simplification. 

## The Technological Race

Numerous advances would change the balance of power during the campaign. The British quickly developed enhancements for night time operations: the Leigh Light and various radars. The Germans developed a sequence of radar detecting equipment that allowed the submarine to dive before it was detected. The Germans tried out radar decoys and anti-aircraft guns to limited effect. These detection and counter-detection technologies can be adjusted by adjusting the vision sliders and the S25 cone angle.

For these reasons, it was decided not to distinguish daytime from nighttime in the base model. History shows that the S.25 could be just as deadly at night. 

The most important *submarine* technology advance was the snorkel, developed by the Dutch before the war. A snorkel (or "snort" in this model from the German name) allows a submarine to remain submerged with only a "breathing tube" breaking the surface. Thus, the submarine can recharge batteries and remain nearly undetectable. German submarines were not equipped with snorkels, however, until mid-1944. 

## Operational Choices

The Germans made some radical adjustments to the percent of time their submarines would operate submerged. A fully submerged submarine (as opposed to a snorkeling submarine) is essentially undetectable from the air in 1943. But, their underwater endurance was limited and they were far from able to move across the barrier without surfacing to recharge batteries. The Germans had periods where they adopted a "maximum submergence" policy, and periods when they tried to sprint across on the surface. You can try both methods out. 

## Model Parameters

The grid of patches in this model is approximately one nautical mile per patch. The background map is a conical projection (not a Mercator), so the scale is relatively constant throughout. Each time step is one minute. A day is 1440 time steps. 

Speed seems to work best by dividing real-world speed (in kts) by 100. Thus, a 10-kt U-boat should move across the ocean at the right pace if you set the speed as 0.10. 

During the period of interest, there were about 50 U-boat transits per month or 0.00116 per minute. There were also over 4000 aircraft patrol hours per month. The aircraft departure rate per minute (0.01) in the model was tuned to deliver somewhat over 4000 patrol hours per 30-day period. 

U-boats depart from points near the mouth of bays and estuaries outside of the five ports. Aircraft all depart from southwestern Plymouth. U-Boats move at direction 290. Aircraft have variable patrol patterns (this can be examined experimentally), but when their fuel status reaches 25% they depart for home and stop their patrol status. 

## Model Output

The two key measures of output are "Gone", the number of escaped U-boats (those that arrive in the North Atlantic) and the average transit time. These are both measured for one month of minute-turns. Also counted: "escapes", the number of times a submerged U-boat passes under the cone of an S25; "encounters", the number of turns that an S25 passes over a surfaced U-Boat in its cone, and "opportunities", the number of turns an S25 passes over *any* U-Boat (submerged or surfaced) in its cone.   

## Potential Experiments

This is really just the stub of a model. Much has been written in the OR literature about search patterns and tactics. Numerous historians have suggested "what if" scenarios that are worthy of experimental examination. 

Probably the most fertile area for experimentation is the logic for the S25 agents as they deploy to the Bay of Biscay. In the current version, they just randomly search in the box between cell 190 and cell 375 -- ostensibly a 285 nm wall astride the U-boat transit routes. 

In the current version there are no submarine kills. There are potential interactions (aircraft and U-boat are within range, and U-boat is in the cone of acquisition of the aircraft), but and "encounter" does not get counted unless the U-boat is surfaced. If the U-boat is dived, the "opportunity" is scored as an "escape". In the current construction, opportunities and encounters are counted per minute. Escapes are counted only once when the range and conditions are right. This enables the application of a key element of search theory, "glimpses", to the aircraft search, but helps to understand the operational impact of a submarine escaping under the ASW air fleet.  

Experiments should probably begin by making the attack more robust. In the real world, after detection the aircraft has to classify, localize, and attack. Classify means determining if the detection was real or a false alarm. Localize means determining the position with sufficient certainty to conduct a successful attack. And, of course, attack means significant aircraft maneuver outside of the search pattern. 

The literature suggests that, once an aircraft has conducted an actual attack, the aircraft returns to base. This is the behavior in this model, but it is worth examining if this is the right procedure. The Sunderland is a four-engine airplane and it has the ability to carry several bombs. What would be the impact on the campaign if the airplane continued on its mission (provided there is enough fuel)?

The model is an excellent opprtunity to explore a wide range of proposals about the best search patterns to use. 

Most models, even when they don't seem to hold up to historical accuracy, can be valuable in sensitivity analysis. For this model, the sensitivity of improving detection and counter-detection ranges would be an excellent research thread. Some improvements are likely to make a big difference while others are not.

The model illuminates several variables that can't be assessed in the real world. It also provides system-wide behavioral information that would be known by commanders. As a result, it can help address the hypothesis that one thing measures another. Does the contact and attack rate, for example, affect the total number of U-boats that get through and the transit time? 

Additionally, experiments can be built around weapons technology. Most of these aircraft were carrying bombs. But, an antisubmarine homing torpedo (MK 24 "Fido") sank its first U-boat in May 1943. What would be the impact of introducing such a weapon earlier or faster?

The Germans attempted using decoys and anti-aircraft artillery in the early stages of this fight. Did they give up too soon? How effective do decoys or AAA have to be in order to make their use viable? 

## Extending the Model

This model shows how a map can be imported and used as a substrate for analysis. There are several other areas of the world where the interaction of topography and military maneuver forces can be the basis for computational analysis. The Mediterranean, the Barents, and the western Pacific are good examples.

The overall structure of this model can also be extended to the "main event", the Battle of the Atlantic. There are many unanswered questions about action-reaction strategies in convoy attack and defense that can be evaluated using the basic structure of this model. 

## NETLOGO Considerations

One challenge was the structure of the Netlogo command "in-cone". The "in-cone" formulation is particularly useful for this particular problem. Unfortunately, the statement appears only to be structured to return an agentset, asin "let target-list (uboats) in-cone 5 120". Such a statement returns an agentlist, <b>target-list</b>. This limits the code structure available to move on from there. You can see how that was solved in the "search" procedure.

## ASW in Context: Other ABMs of Military History

The most prominent predecessor to this model was developed by a team at the Air Force Institue of Technology, Lance Champagne, R. Greg Carl, and Raymond Hill (of nearby Wright State University). During the period 2003 to 2009 this team produced a number of scientific articles based on their agent-based model of this problem. The AFIT model was written in Java, and is not available publicly. 

Few other naval campaign scenarios have been subjected to an ABM treatment. This historical example occupies a unique, data-driven "sweet spot". It is not a singular engagement like, for example, Midway or Trafalgar. This is a campaign that takes place over two years, and extensive data sets have been preserved from both sides of the conflict. It is a rare example in which a model and an underlying theory can be tested in real-world data.  

## Credits and References

Churchill, Winston S. <i>The Second World War</i> Vol. II., <i>Their Finest Hour.</i> Boston: Houghton Mifflin, 1949 

McCue, <i> Brian. U-Boats in the Bay of Biscay, An Essay in Operations Analysis. </i>  Newport, RI: Alidade Press, 2008

Washburn, Alan R. <i>Search and Detection</i>. Arlington, VA: Operations Research Society of America, 1981

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)

## Authorship

(C) 2020 This model was created by Dr. Ken Comer as the basis for a series of historical studies, evaluating measures of effectiveness, sensitivity analysis, tradeoffs and parametric experiments. 
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

airplane 2
true
0
Polygon -14835848 true false 150 26 135 30 120 60 120 90 18 105 15 135 120 150 120 165 135 210 135 225 150 285 165 225 165 210 180 165 180 150 285 135 282 105 180 90 180 60 165 30
Line -7500403 true 120 30 180 30
Polygon -14835848 true false 105 255 120 240 180 240 195 255 180 270 120 270

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

attacking
true
0
Polygon -955883 true false 150 26 135 30 120 60 120 90 18 105 15 135 120 150 120 165 135 210 135 225 150 285 165 225 165 210 180 165 180 150 285 135 282 105 180 90 180 60 165 30
Line -7500403 true 120 30 180 30
Polygon -955883 true false 105 255 120 240 180 240 195 255 180 270 120 270
Circle -955883 false false 0 0 300

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

suboat
false
0
Line -2674135 false 0 150 0 150
Line -2674135 false 150 0 0 150
Line -2674135 false 15 150 150 300
Line -2674135 false 150 300 300 150
Line -2674135 false 300 150 150 0
Circle -2674135 true false 108 108 85

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

uboat
false
0
Line -2674135 false 15 150 15 150
Line -2674135 false 15 150 15 150
Line -2674135 false 15 150 150 300
Line -2674135 false 285 150 150 300
Circle -2674135 true false 108 108 85

uuboat
false
0
Polygon -2674135 true false 15 90 285 90 150 300 15 90

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
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="ExperimentSubmTFVis0910_FixAirManSearch3" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>deployed</metric>
    <metric>escapes</metric>
    <metric>encounters</metric>
    <metric>totalpatrolhrs</metric>
    <enumeratedValueSet variable="MaxSubmergence?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="UBoatVision">
      <value value="9"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Labels?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BBB0p25Revalidate" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>Encounters</metric>
    <metric>Mean TTimes / 60</metric>
    <metric>Escapes</metric>
    <metric>Deployed</metric>
    <enumeratedValueSet variable="MaxSubmergence?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="UBoatVision">
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cone-angle">
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ValidShortMapBigValid" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>Deployed</metric>
    <metric>Escapes</metric>
    <metric>Encounters</metric>
    <metric>mean ttimes / 60</metric>
    <metric>totalpatrolhrs</metric>
    <enumeratedValueSet variable="MaxSubmergence?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="UBoatVision">
      <value value="8"/>
      <value value="9"/>
      <value value="10"/>
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cone-angle">
      <value value="90"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="10pct Attacks" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>Deployed</metric>
    <metric>Escapes</metric>
    <metric>Encounters</metric>
    <metric>Opportunities</metric>
    <metric>mean ttimes / 60</metric>
    <metric>totalpatrolhrs</metric>
    <enumeratedValueSet variable="Airspeed">
      <value value="155"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MaxSubmergence?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="UBoatVision">
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="UT-Speed">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="S25-Vision">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PH-Generator">
      <value value="4000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cone-angle">
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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

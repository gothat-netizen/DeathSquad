# data/abilities/

One AbilityData .tres per operative/faction ability (see
core/resources/ability_data.gd). Abilities with unique procedural logic
(e.g. Death Korps Medic's "Medic!", Sapper's Mine Layer, Bomb Squig's
"Boom!") are flagged unique_procedural=true and get an explicit handler
registered in core/rules/effect_resolver.gd rather than forced into the
generic RuleEffect shape.

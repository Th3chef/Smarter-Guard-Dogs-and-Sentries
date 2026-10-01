-- HD2-Addon: mods/chef/smarter_guard_dogs_priority
-- Smarter Guard Dogs & Sentries - Target Prioritization (optional part, chosen under Intelligence).
-- Switches on target prioritization: your dog goes for the closest threat to you first, and your sentries deal with
-- enemies at their feet first, go for Gunships and Stingrays first (the Rocket Sentry only while one hovers), then the
-- armor that suits the gun (Heavy for the Rocket and Autocannon, lighter for the Machine Gun, Gatling and Laser).
-- Leave it out to let the game decide the order; the rest of the mod keeps working.
rawset(_G, 'SmarterGuardDogsPriority', true)

class_name Lore
## One carved stone per level tells a piece of the story; read ones collect in the Journal.

const ENTRIES := {
	1: ["The Keepers", "Every island once had a keeper, and every keeper a monolith. When the light failed, they left their masks by the door and walked into the clouds."],
	2: ["Roads of Wind", "The winds were the keepers' roads. They taught the updrafts to climb the cliffs so that no island would ever be too far from home."],
	3: ["Lanterns", "At night the keepers lit lanterns for those still flying home. Some lanterns are lit even now. No one remembers who tends them."],
	4: ["The Storms", "The storms came after the dimming. The old songs say a storm is only the sky, searching for a light it has lost."],
	5: ["The Spire", "We raised the spire to see the First Beacon from every island. When the beacon dimmed, the spire broke first, as if it could not bear the dark."],
	6: ["Night Gardens", "The gardeners planted flowers that open at night, so that something would still bloom when the sun forgot us."],
	7: ["A Keeper's Note", "The islands drift faster now. If anyone reads this, carry the light beyond the gale. The far reaches still remember."],
	8: ["Frozen Light", "In the north the light froze into the ice. Walk softly: the bridges melt under a careless step, and so does memory."],
	9: ["The Causeways", "The causeways once turned with the sun. We set them to the hour the light went out, and never moved them again."],
	10: ["Glass", "Glass remembers light the longest. Strike a bell here and it sings back every sunrise it has ever seen."],
	11: ["The Hanging Wood", "The forest did not climb into the sky. The ground fell away, and the trees simply refused to let go."],
	12: ["Ember", "Here the keepers tried to make a new light from fire. It burned for a year, then took the island with it."],
	13: ["Mirror Keepers", "Bend the light, the mirror keepers said, and it will go where you cannot. They sent the last of theirs to the First Beacon, and waited."],
	14: ["The View", "From the top of Skyreach you can see where the First Beacon stood. There is no light there. Only a shape, waiting."],
	15: ["Before the Drift", "The oldest ruins sit lowest, nearest the clouds. They were built when the islands were one land and the light needed no beacon."],
	16: ["Chosen by Wind", "Wanderers were chosen by the wind. A child who could ride a gale without fear was given a mask, a scarf, and a road."],
	17: ["Masks", "The masks were never for hiding. They were so the light would not know our faces, and could not refuse to come with us."],
	18: ["Sentinels", "The sentinels were keepers once. They guard the shards still, though they have forgotten whom they guard them for."],
	19: ["Echoes", "Every shard is an echo of the First Light. Gather enough echoes, and the voice returns."],
	20: ["Aurora", "The aurora is the First Beacon, dreaming. It dreams of a wanderer carrying light across the sky."],
	21: ["Home", "It was never lost. The light only waited for someone to carry it home. Welcome home, Wanderer."],
}


static func title_of(id: int) -> String:
	return ENTRIES[id][0] if ENTRIES.has(id) else ""


static func text_of(id: int) -> String:
	return ENTRIES[id][1] if ENTRIES.has(id) else ""

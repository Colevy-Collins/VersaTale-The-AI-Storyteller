/// A grouped map holding all dimension options organized by category.
/// All dimensions are preserved; those that should not be user-selectable
/// will be filtered out on the UI using an excluded dimensions list.
const Map<String, dynamic> groupedDimensionOptions = {
  "Setting": {
    "Time": [
      "Ancient era",
      "Typical modern day time",
      "An unspecified far-future society on the brink of collapse",
      "A timeless realm outside standard chronology",
      "A post-apocalyptic timeline rising from ashes"
    ],
    "Place": [
      "A sprawling metropolis",
      "A remote frontier settlement on the edge of civilization",
      "A labyrinthine underground city beneath ruins",
      "A shifting dreamscape that defies conventional geography",
      "A cosmic spacecraft",
    ],
    "Physical Environment": [
      "Towering desert dunes with occasional hidden oases",
      "Dense, haunted forests",
      "Gravity-defying landscapes where directions shift unexpectedly",
      "Rolling plains frequently hammered by harsh storms",
      "Volcanic terrain scarred by ancient eruptions",
      "Frigid, snowy environment marked with icebergs and hidden caves"
    ],
    "Cultural & Social Context": [
      "Deeply depraved society with strict caste systems",
      "Nomadic tribes competing for scarce resources",
      "A utopian facade hiding a tightly controlled state",
      "Small, insular villages clinging to ancient beliefs",
      "A federation of city-states with unstable alliances"
    ],
    "Technology & Level of Advancement": [
      "Steam-powered gadgets and unsophisticated robotics",
      "Advanced biotechnology overshadowing mechanical inventions",
      "Magical constructs woven into everyday life",
      "Hybrid medieval and arcane technologies",
      "Minimal to no technology",
      "AI-driven society balancing organic and synthetic lifeforms"
    ],
    "Mood & Atmosphere": [
      "Oppressive and claustrophobic",
      "Whimsical and lighthearted",
      "Tense and suspenseful, where trust is scarce",
      "Energetic and adventurous, brimming with discovery",
      "Somber and reflective, hinting at a long-lost glory",
      "Eerie and silent, each sound amplified by emptiness",
      "Chaotic and unpredictable"
    ],
    "World-Building Details": [
      "Portals to alternate dimensions appear sporadically",
      "Celestial bodies influencing magic or fate cycles",
      "Trade routes bridging distant cultures and species",
      "Residual energies from ancient civilizations",
      "Forbidden zones that alter reality in bizarre ways",
      "Relics or runes that spark small-scale miracles"
    ]
  },
  "Narrative": {
    "Genre": [
      "Fantasy",
      "Cyberpunk dystopia",
      "Historical",
      "Sci-fi",
      "Steampunk",
      "Surreal dream-like",
      "Survival",
      "Horror"
    ],
    "Tone": [
      "Light-hearted and comedic",
      "Dark and tragic",
      "Philosophical and introspective, exploring deep themes",
      "Action-packed and heroic",
      "Hopeful yet bittersweet, balancing ups and downs",
      "Mystically eerie with constant uncertainty",
      "Melodramatic and emotionally charged",
    ],
    "Style": [
      "First-person narration",
      "Omniscient third-person",
      "Epistolary format using letters, diaries, or logs",
      "Fragmented storytelling with overlapping timelines",
      "Poetic, dreamlike prose focusing on atmosphere",
      "Concise and minimalistic writing style",
      "Archaic, ornate language reminiscent of classic epics",
    ],
    "Perspective": [
      "Single, intimate viewpoint of the protagonist",
      "Multiple rotating POVs covering different factions",
      "Unreliable narrator with possible hidden motives",
      "Omniscient narrator who reveals subtle details",
      "Observational perspective from a secondary character",
      "Retrospective narration from a distant future",
      "Collective perspective from a group or hive-mind"
    ]
  },
  "Character": {
    "Protagonist Customization": {
      "Protagonist's Background": [
        "Orphan",
        "Disgraced noble stripped of titles",
        "Reincarnated hero from an ancient prophecy",
        "Average individual thrust into extraordinary events",
        "Wandering scholar seeking lost knowledge",
        "Summoned outsider from a parallel reality"
      ],
      "Protagonist's Abilities": [
        "Innate magic that remains largely untapped",
        "Advanced cybernetic implants from experimental tech",
        "Elite combat training from a clandestine order",
        "Natural affinity for stealth and subterfuge",
        "Psionic talents for telepathy or telekinesis",
        "Ingenious tinkerer capable of jury-rigging gadgets",
        "Diplomatic skillset capable of swaying factions"
      ],
      "Protagonist's Personality": [
        "Harsh with a hidden soft side",
        "Cynical but fiercely loyal once trust is earned",
        "Quiet observer",
        "Overly curious",
        "Hot-tempered protector defending the weak",
        "Pragmatic realist who operates in moral gray areas",
        "Playful trickster who challenges the status quo"
      ],
      "Protagonist's Reputation": [
        "Revered champion hailed in legends",
        "Notorious outlaw with a substantial bounty",
        "Enigmatic wanderer whose deeds are whispered about",
        "A public figure overshadowed by a dreaded prophecy",
        "Unknown adventurer starting from obscurity",
        "Trusted advisor or confidante to those in power"
      ]
    },
    "Antagonist Development": [
      "A shadowy mastermind manipulating events behind the scenes",
      "A corrupted former ally consumed by greed or ambition",
      "A primal force of nature indifferent to morality",
      "A tragic figure seeking twisted redemption",
      "A rival with overlapping goals but conflicting methods",
      "A visionary prophet led astray by forbidden knowledge"
    ]
  },
  "Gameplay & Challenges": {
    "Difficulty": [
      "Easy",
      "Normal",
      "Hard",
      "Nightmare",
    ],
    "Encounter Variations": [
      "Diplomatic standoffs requiring tact and persuasion",
      "Stealth infiltrations through heavily guarded sites",
      "Complex puzzles blocking critical paths",
      "Spiritual or psychic showdowns in dreamlike realms",
      "Resource-gathering missions in treacherous zones",
      "Sudden ambushes by unexpected adversaries",
      "Allied raids on fortified strongholds"
    ],
    "Moral Dilemmas": [
      "Sacrificing one group to save another",
      "Using forbidden power at the risk of corruption",
      "Betraying an ally to serve a larger cause",
      "Confronting deeply held biases or illusions",
      "Deciding an enemy’s fate: mercy or execution",
      "Accepting or rejecting a morally gray alliance"
    ],
    "Story Pacing": [
      "Rapid, relentless progression",
      "Slow-burn growth focusing on relationships and depth",
      "Gradual build to a high-intensity finale",
      "Nonlinear timeline with flashbacks and reveals",
    ],
    "Final Objective": [
      "Destroying or sealing a world-altering artifact",
      "Overthrowing an oppressive regime",
      "Uncovering and halting a grand conspiracy",
      "Preventing an imminent apocalyptic threat",
      "Escaping a doomed land before total collapse",
      "Achieving transcendence to a higher plane",
      "Exposing the true puppet master behind all conflicts"
    ],
    "Consequences of Failure": [
      "Complete devastation of a civilization",
      "Permanent corruption twisting the hero or the land",
      "Civil discord breaking society beyond repair",
      "Immediate cosmic or supernatural catastrophe",
      "Hero’s fall into despair or exile",
      "A time-loop restarting the entire sequence"
    ]
  },
  "Extras": {
    "Decision Options": [
      "Multiple branching paths that reshape the available choices going forward",
      "Subtle shifts in outcomes based on moral or ethical stances",
      "Alignment tracking that influences future interactions and opportunities",
      "Major fork-in-the-road decisions leading to distinctly different conclusions",
      "Random or chance-based event triggers adding variability to each playthrough",
      "Return visits to earlier nodes, where prior choices may now have different results"
    ],
    "Fail States": [
      "A growing burden of guilt that steadily erodes resolve, each misstep pushing the hero closer to a tragic breakdown.",
      "Allies becoming disillusioned or turning hostile, leading to isolation and a near-inevitable downfall if trust isn’t rebuilt.",
      "A spiraling series of compromises where each wrong decision darkens the path, eventually locking them into a catastrophic finale.",
      "Escalating corruption that twists the protagonist’s motives, culminating in a self-inflicted collapse or villainous turn.",
      "Key resources or strongholds lost one by one, leaving the hero ill-equipped for the final confrontation and dooming them to failure.",
      "Public outrage or a severe reputation collapse that triggers desperation, increasing the likelihood of irreversible tragedy.",
      "Critical moments turning into permanent setbacks—once a wrong choice is made, the story edges closer to an inevitable bleak end.",
      "Emotional fallout from poor decisions causing alliances to fracture, leaving the hero alone in a final stand they cannot win.",
      "An overarching doom mechanic: each bad call elevates the threat or shortens the timeline, hastening a cataclysmic ending."
    ]
  }
};

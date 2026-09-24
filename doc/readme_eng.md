# Forever Track

> A collection of independent addons for **WoW Forever**.



## Installation

Currently, the addons must be installed **manually**.

1. Download or clone this repository.
2. Open the game's AddOns directory.
3. Copy the addon folders you want to use into the AddOns directory.

For example:

```text
WoW Forever/
└── Interface/
    └── AddOns/
        ├── t0_TrackMCP/
        ├── t1_TrackMap/
        ├── t2_TrackNPC/
        └── t3_TrackRes/
```

You do **not** need to install every addon. Each addon can be installed independently, although some features may require another Track addon to be installed as well.

> **Note:** An automatic installation tool is planned for the future. The goal is to provide a small **C# / WPF utility** that can detect the game installation and copy or update the selected addons automatically.

---

## Usage

After installing the addons, launch the game and enable the corresponding addons from the game's addon management interface.

### Slash Commands

Each addon can be opened using its corresponding slash command:

| Command | Addon         |
| ------- | ------------- |
| `/t0`   | `t0_TrackMCP` |
| `/t1`   | `t1_TrackMap` |
| `/t2`   | `t2_TrackNPC` |
| `/t3`   | `t3_TrackRes` |

For example:

```text
/t1
```

opens the `t1_TrackMap` custom window.

### Keyboard Shortcuts

The addons also support keyboard shortcuts using **Ctrl + Numpad** keys:

| Shortcut          | Addon         |
| ----------------- | ------------- |
| `Ctrl + Numpad 0` | `t0_TrackMCP` |
| `Ctrl + Numpad 1` | `t1_TrackMap` |
| `Ctrl + Numpad 2` | `t2_TrackNPC` |
| `Ctrl + Numpad 3` | `t3_TrackRes` |

For example:

```text
Ctrl + Numpad 1
```

opens the `t1_TrackMap` window without entering a slash command.

> **Note:** The keyboard shortcuts may be changed or expanded as development continues.

---

## Addons

### `t0_TrackMCP`

**Status: Not Started**

An experimental MCP-based AI assistant designed to help players track and understand their current game progress.

The planned features include:

* Mission and quest tracking
* Character progression tracking
* Conversation history
* Context-based suggestions and advice
* Communication with an external MCP-based AI agent

An **AI API token provided by the user will be required** to use the AI functionality.

---

### `t1_TrackMap`

**Status: In Development**

A custom whole-world map designed to work more like a modern **GIS / Web Map** rather than the traditional game-map system.

Instead of dividing the world into many separate regional maps, the goal is to provide a continuous map that allows players to navigate and explore the world as a whole.

The addon is planned to support different map styles and will eventually provide an interface that other Track addons can use to display their own data.

---

### `t2_TrackNPC`

**Status: In Development**

A list-based NPC database designed to help players search for and locate NPCs throughout the game world.

The addon can interact with the game's built-in map window and is planned to support synchronization with the custom `t1_TrackMap` window in the near future.

Current and planned features include:

* NPC database
* NPC search and filtering
* NPC location information
* Interaction with the built-in map
* Data synchronization with `t1_TrackMap`
* Structured data that can be used by other addons

The database is compiled from publicly available community and website resources. Sources and original authors are preserved wherever applicable.

---

### `t3_TrackRes`

**Status: Not Started**

A list-based resource database following a similar concept to `t2_TrackNPC`.

The purpose of this addon is to help players track gathering resources throughout the game world, including:

* Herbs
* Mining veins
* Other collectible resources

The addon is planned to eventually integrate with `t1_TrackMap` so that resource locations can be displayed directly on the custom world map.

---

## Addon Architecture

The addons are intended to remain **independent while still being able to communicate with each other**.

```text
t2_TrackNPC ──────┐
                  │
t3_TrackRes ──────┼──> t1_TrackMap
                  │
t0_TrackMCP ──────┘
```

The purpose of this structure is to avoid creating one large addon that contains every feature.

Instead, each addon has its own responsibility and can provide data or functionality to other addons when necessary.

---

## Development Notes

This project is being developed with significant assistance from **Google Gemini**.

AI assistance is currently used during development for code generation, debugging, research, refactoring, documentation, and exploring possible implementations.

The project is still manually developed, tested, reviewed, and modified throughout the development process.

---

## Release Notes

### `0.0.1`

**Initial project release**

* Repository created
* `t1_TrackMap` is working
* `t2_TrackNPC` is working
* Both addons still require additional testing and tuning
* `t0_TrackMCP` is planned but not started
* `t3_TrackRes` is planned but not started

---

## Usage and Sharing

Feel free to:

* Fork this repository
* Modify the addons
* Publish your own versions
* Share the project on the Internet
* Use the source code or other materials where permitted

If you redistribute or reuse material from this repository, please **preserve the original authors and source information**.

This applies not only to source code, but also to other materials such as:

* Code
* Textures
* Images
* Content and documentation
* URLs and external resources
* Databases and collected data
* Third-party libraries and assets

Please keep the relevant attribution whenever you reuse or redistribute these materials.

---

## Copyright and Sources

This project contains materials collected from various community resources and websites.

The intention is to use materials according to the usage, redistribution, or licensing terms stated by their original authors or sources.

I do not claim ownership of third-party materials included in this project.

If you are an original author or rights holder and believe that any material in this repository should not be included, please leave a message or open an issue so that it can be reviewed and removed or corrected if necessary.

If you have a useful source, database, resource, or other material that could improve this project, you are also welcome to share it or submit a fork.

---

## Project Status

This is an **independent and experimental project** and is still under active development.

The project structure, APIs, data formats, and addon interactions may change as development continues.

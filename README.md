# Brainrot-Logger-V1

# Brainrot Logger

Brainrot Logger is an advanced logging and notification system designed for **Steal a Brainrot**. It continuously monitors every active Brainrot in the game and records detailed information whenever one spawns.

Unlike simple notification scripts, Brainrot Logger provides a complete graphical interface with real-time tracking, categorized logs, customizable notifications, and detailed information for every detected Brainrot.

## Features

* Detects every rarity from **Common** to **Infinity**.
* Separate log pages for each rarity.
* Enable or disable logging for individual rarities.
* Floating notifications when a Brainrot spawns.
* Real-time **Time Left** updates.
* Displays:

  * Name
  * Trait
  * Mutation
  * Level
  * Time Left
  * World Position
  * Spawn Time
  * Elapsed Time
* Detailed information panel for the selected log.
* Scrollable log and details panels.
* Resizable window with multiple resolution presets.
* Draggable interface.
* Minimize and close buttons.
* Automatic popup removal when the Brainrot disappears.
* Supports up to 100 logs per rarity.
* Special rainbow styling for Infinity rarity.

## How it works

The logger continuously monitors the `Workspace.ActiveBrainrots` hierarchy.

Whenever a new `RenderedBrainrot` appears, the script immediately captures its information, including its rarity, name, trait, mutation, level, position, and remaining lifetime.

For the remaining lifetime, the logger reads the value directly from:

`Workspace.ActiveBrainrots.<Rarity>.RenderedBrainrot.Root.TimerGui.TimeLeft.TimeLeft.Text`

This provides the exact countdown shown in-game and updates it in real time.

Each detected Brainrot is stored in its corresponding rarity category while also displaying an optional floating notification.

Selecting a log entry opens a detailed information panel where all available data is displayed and updated live while the Brainrot exists.

The interface was designed to remain responsive across different resolutions, with independent scrolling panels to prevent information from being cut off on smaller window sizes.

## Purpose

Brainrot Logger was built to provide players with an organized and customizable way to monitor Brainrot spawns without relying on simple notifications. It combines logging, live tracking, and an intuitive interface into a single tool that makes monitoring rare Brainrots significantly easier.


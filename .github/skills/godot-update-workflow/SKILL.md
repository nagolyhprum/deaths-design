---
name: godot-update-workflow
description: Guidance for updating the Deaths Design Godot project. Use when working on gameplay, scenes, scripts, content, or design tasks for this 2.5D isometric rage game.
---

# Purpose

Use this skill when helping with the **Deaths Design** project, a **2.5D isometric rage game** inspired by **Final Destination**.

The player controls a hungry character trying to reach a store to buy food. Progress depends on choosing the correct path and avoiding deadly outcomes along the way.

# Project context

- Engine target: **Godot 4.4**
- Rendering setup: **GL Compatibility**
- Genre tone: tense, unfair-but-readable, trial-and-error rage game
- Core loop: move forward, read danger, choose a route, survive long enough to reach food
- Inspiration: chain-reaction deaths, suspense, environmental hazards, and looming inevitability

# Design goals

When proposing or implementing changes, optimize for:

1. **Readable danger.** Hazards should feel threatening and surprising, but still be telegraphed enough that players can learn from failure.
2. **Meaningful path choice.** Route decisions should matter and create tension, not just cosmetic variation.
3. **Cause-and-effect deaths.** Favor setups where the environment, timing, or player decision creates the fatal outcome.
4. **Isometric clarity.** Protect visual readability in a 2.5D isometric view, especially for collisions, traversal, depth cues, and interactables.
5. **Short feedback loops.** Keep failure recovery fast so repeated attempts stay engaging.

# Required workflow

For relevant project-update prompts, follow this sequence:

1. **Start with a plan.** Before making changes, explain what you plan to do in a short, concrete summary.
2. **Wait for approval.** Do not begin the implementation until the user indicates they are happy with the plan.
3. **Create a timestamped task record.** Once approved, create a folder for the task using the format `YYYY-MM-DD-HH-mm-some-related-name`.
4. **Capture the request.** In that folder, add one file containing the original user prompt.
5. **Capture extra written context.** In that folder, add a second file containing related notes, rationale, or other text output that should be preserved even if it is not directly represented by project files.
6. **Implement the requested changes.**
7. **Test the changes and fix any issues.**
8. **Commit and push.** After the task files and project changes are ready, commit the full project state and push it to GitHub.

# Implementation guidance

- Prefer small, coherent Godot changes that keep scenes, scripts, and assets aligned.
- When suggesting mechanics, lean into suspense, pathing, trap logic, and environmental storytelling.
- When uncertainty exists, propose a clear implementation direction instead of offering vague options.
- If a task affects player movement, navigation, collisions, or camera framing, explicitly consider isometric readability.
- If a task introduces danger, think through the trigger, warning signal, consequence, and reset flow.

# Record-keeping guidance

Unless the user asks for a different location, place timestamped task folders in a dedicated repository directory such as `task-records/` so they stay easy to review.

If asked to generate an image asset, use Pillow and save the Python script used to generate the asset in the same related task-record folder for future reference.

Recommended filenames inside each timestamped folder:

- `original-prompt.md`
- `notes.md`

# Example invocation

- `/godot-update-workflow Add a new intersection scene with two dangerous routes and one safer hidden route.`

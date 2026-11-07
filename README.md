This will contain some information for the Team to use , right now its going to be empty 

30/10/26 - Update - For anyone working on the game please make a git branch "<your name>:<Name of branch>" example - Dante-Player_controller
This is to keep things clean and when merging to the main project so others dont work over eachother and when working on a specific part of the game please dont change others work , best to let them finish and then ask them to make a branch and you can work on that branch, once finalised merg but not to the main branch, merg to the current ( testing ) branch. - Dante

## Tuning the game

Most gameplay numbers (speed, health, damage, jellyfish, level order) live in
one file: **`scripts/core/tuning.gd`**. Models and animations are exported
fields you can change in the Godot inspector.

See **`docs/CUSTOMISING.md`** for an “I want to change X — open Y” guide.

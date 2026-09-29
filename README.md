# PenFlick

Physics-based tabletop pen battle for Android.

## V1 gameplay

- Single-player vs AI
- 2-4 player local pass-and-play
- Physics-based pen collisions
- Drag-back aiming and force control
- Pens fall off the table to be eliminated
- Last pen standing wins
- Landscape mobile layout
- Android APK build through GitHub Actions

## Controls

Touch/drag backward from your pen, then release. The farther you pull, the stronger the flick.

## Build

GitHub Actions builds a debug Android APK on pushes to `main`, and can also be started manually from the **Actions** tab.

The project uses Godot 4.4.1 and the `barichello/godot-ci:4.4.1` Android export environment.

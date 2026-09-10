# GlassPad

A private, native macOS floating code notepad. No account, server, or publication required.

## Try it

Open `build/GlassPad.app`. Click the floating **</>** button to show or hide your note. Drag the button to move it. Drag the top of the notepad to move it, and drag a window edge to resize it.

- Change the language menu for basic syntax coloring.
- Kotlin mode colors keywords, built-in types, annotations, numbers, function calls, strings (including triple-quoted strings), and comments.
- Move the Opacity slider to adjust the dark glass background. Text and controls remain fully visible, with a minimum tint for readability over white windows.
- Tab inserts four spaces; Return keeps the current indentation.
- Standard copy, paste, select-all, undo, and redo shortcuts work.
- Escape or Command-W hides the notepad; the floating button remains.
- Use the **</>** menu in the macOS menu bar to quit or recover the floating button.

The note saves automatically to `~/Library/Application Support/GlassPad/note.txt`. Language, opacity, and window size persist. The button starts at the right of the primary screen each time.

## Scope

This prototype edits one note, with basic pattern-based syntax highlighting. It does not execute code, provide autocomplete, or manage a project. It stays above ordinary windows while running and requests availability across Spaces and alongside full-screen apps; macOS system surfaces can still appear above it. macOS accessibility settings such as Reduce Transparency can affect the glass appearance.

## Rebuild

Run `zsh build.sh` from this folder with Apple's Command Line Tools installed. The build is locally signed for private testing and is not notarized or published.

"""
Matchering ReaScript for REAPER
-------------------------------
How to use:
1. Place a TARGET item (your song) on Track 1
2. Place a REFERENCE item (the sound you want) on Track 2
3. Select BOTH items
4. Run this script from Actions > Show action list > Load ReaScript

The mastered result gets placed on a new track.
"""

from __future__ import print_function
import sys
import traceback

# Print to terminal so we can see what's happening
print("=== Matchering ReaScript loading ===", file=sys.stderr)
print(f"Python version: {sys.version}", file=sys.stderr)

try:
    import subprocess
    import os

    # Hardcode the plugin directory since Reaper doesn't set __file__
    SCRIPT_DIR = "/home/bryan/PLUGIN"
    VENV_PYTHON = os.path.join(SCRIPT_DIR, "venv", "bin", "python3")
    PROCESSOR = os.path.join(SCRIPT_DIR, "matchering_process.py")

    print(f"SCRIPT_DIR: {SCRIPT_DIR}", file=sys.stderr)
    print(f"VENV_PYTHON: {VENV_PYTHON} (exists: {os.path.isfile(VENV_PYTHON)})", file=sys.stderr)
    print(f"PROCESSOR: {PROCESSOR} (exists: {os.path.isfile(PROCESSOR)})", file=sys.stderr)


    def get_item_source_file(item):
        """Get the source audio file path from a media item."""
        take = RPR_GetActiveTake(item)
        if not take:
            return None
        source = RPR_GetMediaItemTake_Source(take)
        if not source:
            return None
        filenamebuf = " " * 1024
        result = RPR_GetMediaSourceFileName(source, filenamebuf, 1024)
        return result[1].strip() if result[1].strip() else None


    def msg(text):
        """Show a message box in Reaper."""
        RPR_ShowMessageBox(str(text), "Matchering", 0)


    def main():
        print("=== Matchering main() called ===", file=sys.stderr)

        # Check that venv and processor exist
        if not os.path.isfile(VENV_PYTHON):
            msg(f"Venv Python not found at:\n{VENV_PYTHON}\n\nMake sure the venv is set up.")
            return
        if not os.path.isfile(PROCESSOR):
            msg(f"Processor script not found at:\n{PROCESSOR}")
            return

        # Get selected items
        num_selected = RPR_CountSelectedMediaItems(0)
        if num_selected != 2:
            msg(
                f"Please select exactly 2 items:\n"
                f"- First selected item = TARGET (your song)\n"
                f"- Second selected item = REFERENCE (desired sound)\n\n"
                f"Currently selected: {num_selected}"
            )
            return

        target_item = RPR_GetSelectedMediaItem(0, 0)
        ref_item = RPR_GetSelectedMediaItem(0, 1)

        target_file = get_item_source_file(target_item)
        ref_file = get_item_source_file(ref_item)

        print(f"Target file: {target_file}", file=sys.stderr)
        print(f"Reference file: {ref_file}", file=sys.stderr)

        if not target_file or not os.path.isfile(target_file):
            msg(f"Could not find target audio file:\n{target_file}")
            return
        if not ref_file or not os.path.isfile(ref_file):
            msg(f"Could not find reference audio file:\n{ref_file}")
            return

        # Output file goes next to the target
        target_dir = os.path.dirname(target_file)
        target_name = os.path.splitext(os.path.basename(target_file))[0]
        output_file = os.path.join(target_dir, f"{target_name}_mastered.wav")

        # Run matchering
        RPR_ShowConsoleMsg(f"Matchering: Processing...\nTarget: {target_file}\nReference: {ref_file}\n")
        print(f"Running: {VENV_PYTHON} {PROCESSOR} ...", file=sys.stderr)

        try:
            result = subprocess.run(
                [VENV_PYTHON, PROCESSOR, target_file, ref_file, output_file],
                capture_output=True,
                text=True,
                timeout=300,
            )
        except subprocess.TimeoutExpired:
            msg("Matchering timed out after 5 minutes.")
            return
        except Exception as e:
            msg(f"Error running matchering:\n{e}")
            print(f"subprocess error: {e}", file=sys.stderr)
            traceback.print_exc(file=sys.stderr)
            return

        print(f"Return code: {result.returncode}", file=sys.stderr)
        print(f"STDOUT: {result.stdout}", file=sys.stderr)
        print(f"STDERR: {result.stderr}", file=sys.stderr)

        if result.returncode != 0:
            msg(f"Matchering failed:\n{result.stderr[:500]}")
            RPR_ShowConsoleMsg(f"STDERR:\n{result.stderr}\n")
            return

        RPR_ShowConsoleMsg(result.stdout + "\n")

        if not os.path.isfile(output_file):
            msg("Matchering ran but output file was not created.")
            return

        # Insert the mastered file on a new track
        num_tracks = RPR_CountTracks(0)
        RPR_InsertTrackAtIndex(num_tracks, True)
        new_track = RPR_GetTrack(0, num_tracks)
        RPR_GetSetMediaTrackInfo_String(new_track, "P_NAME", "Mastered", True)

        RPR_SetOnlyTrackSelected(new_track)
        RPR_InsertMedia(output_file, 0)

        RPR_UpdateArrange()

        msg(f"Done! Mastered file placed on new track.\n\nOutput: {output_file}")

    main()

except Exception as e:
    print(f"=== Matchering ReaScript FATAL ERROR ===", file=sys.stderr)
    traceback.print_exc(file=sys.stderr)
    try:
        RPR_ShowMessageBox(f"Script error:\n{e}", "Matchering Error", 0)
    except:
        pass
